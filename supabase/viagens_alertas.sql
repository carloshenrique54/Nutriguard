-- =============================================================================
-- NutriGuard — Viagens no banco + alerta de fim de viagem para gerente e ADM
-- Executar no SQL Editor do Supabase DEPOIS de multiempresa.sql.
-- Pode ser executado de novo sem problemas.
--
-- O app passou a gravar as viagens em public.viagens (antes ficavam só no
-- navegador do operador). Este script:
--   1. Garante no máximo UMA viagem em andamento por veículo e por operador.
--   2. Ao finalizar uma viagem, cria uma ocorrência para gerente e ADM:
--        viagem_finalizada               -> operador preencheu "Parar viagem"
--        viagem_encerrada_sem_relatorio  -> encerrou sem o formulário (ex.: logout)
--      (valor_registrado = duração em minutos)
--   3. O operador não vê esses avisos (só gerente e ADM).
--   4. Operador só abre viagem em seu próprio nome.
-- =============================================================================

-- 1. Uma viagem em andamento por veículo / por operador ------------------------
-- Fecha duplicatas antigas (mantém a mais recente) antes de criar os índices.
with dup as (
  select id, row_number() over (partition by id_dispositivo order by iniciado_em desc) as n
  from public.viagens where status = 'em_andamento'
)
update public.viagens v
   set status = 'finalizada', finalizado_em = coalesce(v.finalizado_em, now())
  from dup where dup.id = v.id and dup.n > 1;

with dup as (
  select id, row_number() over (partition by id_operador order by iniciado_em desc) as n
  from public.viagens where status = 'em_andamento' and id_operador is not null
)
update public.viagens v
   set status = 'finalizada', finalizado_em = coalesce(v.finalizado_em, now())
  from dup where dup.id = v.id and dup.n > 1;

create unique index if not exists viagens_uma_ativa_por_dispositivo
  on public.viagens (id_dispositivo) where status = 'em_andamento';
create unique index if not exists viagens_uma_ativa_por_operador
  on public.viagens (id_operador) where status = 'em_andamento' and id_operador is not null;

-- 2. Tipos livres em ocorrencias (remove CHECK antigo que limite o tipo) -------
do $$
declare r record;
begin
  for r in
    select conname from pg_constraint
    where conrelid = 'public.ocorrencias'::regclass and contype = 'c'
      and pg_get_constraintdef(oid) ilike '%tipo%'
  loop
    execute format('alter table public.ocorrencias drop constraint %I', r.conname);
  end loop;
end $$;

-- 3a. Relatório de parada encerra a viagem ---------------------------------------
-- (substitui a versão de create_viagens_e_refatoracao_fins_viagem.sql). Roda
-- ANTES de gravar o fins_viagem; por isso marca na transação que esta viagem
-- terminou COM relatório, para o alerta abaixo saber disso.
create or replace function public.trg_sincronizar_fim_viagem()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  v_viagem_id uuid;
begin
  if new.id_viagem is not null then
    v_viagem_id := new.id_viagem;
  else
    select id into v_viagem_id
    from public.viagens
    where (id_dispositivo = new.id_dispositivo or id_operador = new.id_operador)
      and status = 'em_andamento'
    order by iniciado_em desc
    limit 1;
    if v_viagem_id is not null then
      new.id_viagem := v_viagem_id;
    end if;
  end if;

  if v_viagem_id is not null then
    perform set_config('nutriguard.viagem_com_relatorio', v_viagem_id::text, true);
    update public.viagens
       set status = 'finalizada',
           finalizado_em = coalesce(new.criado_em, now()),
           duracao_minutos = greatest(1, round(extract(epoch from (coalesce(new.criado_em, now()) - iniciado_em)) / 60)::integer),
           observacoes = coalesce(observacoes, new.motivo),
           atualizado_em = now()
     where id = v_viagem_id
       and status = 'em_andamento';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_auto_finalizar_viagem on public.fins_viagem;
create trigger trg_auto_finalizar_viagem
  before insert on public.fins_viagem
  for each row execute function public.trg_sincronizar_fim_viagem();

-- 3b. Gatilho: fim de viagem vira ocorrência ----------------------------------
create or replace function public.alerta_fim_viagem()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  v_relatorio boolean;
  v_minutos integer;
begin
  if new.status = 'finalizada' and old.status is distinct from 'finalizada' then
    -- Com relatório: encerrada pelo formulário "Parar viagem" (marca da
    -- transação, ver 3a) ou já existe fins_viagem desta viagem.
    select coalesce(current_setting('nutriguard.viagem_com_relatorio', true), '') = new.id::text
        or exists (
      select 1 from public.fins_viagem f
      where f.id_viagem = new.id
         or (f.id_viagem is null
             and f.id_dispositivo = new.id_dispositivo
             and (new.id_operador is null or f.id_operador = new.id_operador)
             and f.criado_em >= new.iniciado_em)
    ) into v_relatorio;

    v_minutos := coalesce(
      new.duracao_minutos,
      (extract(epoch from (coalesce(new.finalizado_em, now()) - new.iniciado_em)) / 60)::integer
    );

    insert into public.ocorrencias (id_dispositivo, tipo, valor_registrado, status)
    values (
      new.id_dispositivo,
      case when v_relatorio then 'viagem_finalizada' else 'viagem_encerrada_sem_relatorio' end,
      v_minutos,
      'aberta'
    );
  end if;
  return new;
end;
$$;

revoke all on function public.alerta_fim_viagem() from public, anon, authenticated;

drop trigger if exists trg_alerta_fim_viagem on public.viagens;
create trigger trg_alerta_fim_viagem
  after update of status on public.viagens
  for each row execute function public.alerta_fim_viagem();

-- 4. Operador não vê avisos de viagem (só gerente e ADM) -----------------------
drop policy if exists "ocorrencias_select_por_perfil" on public.ocorrencias;
create policy "ocorrencias_select_por_perfil" on public.ocorrencias
  for select to authenticated
  using (
    public.pode_ver_dispositivo(id_dispositivo)
    and (tipo not like 'viagem\_%' or public.is_admin() or public.is_gerente())
  );

-- 5. Operador só abre viagem em seu próprio nome -------------------------------
drop policy if exists "viagens_insert_por_perfil" on public.viagens;
create policy "viagens_insert_por_perfil" on public.viagens
  for insert to authenticated
  with check (
    public.pode_ver_dispositivo(id_dispositivo)
    and (public.is_admin() or public.is_gerente() or id_operador::text = auth.uid()::text)
  );

notify pgrst, 'reload schema';

-- Conferência
select indexname from pg_indexes where tablename = 'viagens' and indexname like 'viagens_uma_ativa%';
select tgname from pg_trigger where tgname in ('trg_alerta_fim_viagem', 'trg_auto_finalizar_viagem');
