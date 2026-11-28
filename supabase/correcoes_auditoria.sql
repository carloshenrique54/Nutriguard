-- =============================================================================
-- NutriGuard — Correções da auditoria de regras (RLS x funcionalidades do app)
-- Executar no SQL Editor do Supabase DEPOIS de multiempresa.sql.
-- Pode ser executado de novo sem problemas.
--
-- 1. view_viagens_completas ignorava o RLS e era legível por visitantes
--    (viagens, nomes e e-mails de operadores de TODAS as empresas).
-- 2. Excluir veículo com histórico falhava: medicoes/ocorrencias apontam para o
--    veículo com ON DELETE RESTRICT e medicoes é imutável. Agora: sem histórico
--    o veículo é apagado; com histórico ele é DESATIVADO (some do app, histórico
--    preservado).
-- 3. Valores padrão perigosos: Frotas.id_gerente e Dispositivos.id_operador
--    tinham default auth.uid() (quem cadastra virava gerente/operador).
-- 4. Funções administrativas executáveis por visitantes (sem efeito, mas
--    desnecessário) e anexos de viagem alteráveis por admin de outra empresa.
-- 5. Frotas.id_gerente obrigatório impedia excluir um gerente.
-- =============================================================================

-- 1. View de viagens passa a respeitar o RLS das tabelas -----------------------
do $$
begin
  if to_regclass('public.view_viagens_completas') is not null then
    execute 'alter view public.view_viagens_completas set (security_invoker = true)';
    execute 'revoke all on public.view_viagens_completas from anon';
  end if;
  if to_regclass('public.dispositivos_status') is not null then
    execute 'alter view public.dispositivos_status set (security_invoker = true)';
    execute 'revoke all on public.dispositivos_status from anon';
  end if;
end $$;

-- 3. Sem valores padrão que atribuem quem cadastra ---------------------------
alter table public."Frotas"       alter column id_gerente  drop default;
alter table public."Dispositivos" alter column id_operador drop default;

-- 5. Excluir um gerente deixa a frota dele "Sem Gerente" (o app já mostra esse
--    estado e o admin escolhe outro gerente editando a frota). Com id_gerente
--    obrigatório, excluir gerente falhava.
alter table public."Frotas" alter column id_gerente drop not null;

-- 2. Exclusão de veículo: apaga ou desativa ---------------------------------
alter table public."Dispositivos" add column if not exists excluido_em timestamptz;

create or replace function public.excluir_dispositivo(p_dispositivo uuid)
returns text
language plpgsql security definer set search_path = public
as $$
declare
  v_disp record;
begin
  select * into v_disp from public."Dispositivos" where id = p_dispositivo and excluido_em is null;
  if not found then
    raise exception 'Dispositivo não encontrado.' using errcode = 'P0002';
  end if;
  if not (public.admin_da_empresa(v_disp.id_empresa) or public.gerencia_frota(v_disp.id_frota)) then
    raise exception 'Você não tem permissão para excluir este dispositivo.' using errcode = '42501';
  end if;

  delete from public.dispositivo_credenciais where id_dispositivo = p_dispositivo;

  if exists (select 1 from public.medicoes where id_dispositivo = p_dispositivo)
     or exists (select 1 from public.ocorrencias where id_dispositivo = p_dispositivo) then
    -- Histórico é imutável: desativa o veículo e o desvincula
    update public.viagens
       set status = 'cancelada', finalizado_em = now(), atualizado_em = now()
     where id_dispositivo = p_dispositivo and status = 'em_andamento';
    update public."Dispositivos"
       set excluido_em = now(), id_operador = null, id_frota = null
     where id = p_dispositivo;
    return 'desativado';
  end if;

  delete from public."Dispositivos" where id = p_dispositivo;
  return 'excluido';
end;
$$;

-- Veículos desativados somem do app (o histórico continua no banco)
drop policy if exists "dispositivos_select_por_perfil" on public."Dispositivos";
create policy "dispositivos_select_por_perfil" on public."Dispositivos"
  for select to authenticated
  using (
    excluido_em is null
    and (
      public.admin_da_empresa(id_empresa)
      or id_operador::text = auth.uid()::text
      or public.gerencia_frota(id_frota)
    )
  );

-- ESP32 de veículo desativado não envia mais (a credencial já é removida,
-- isto é só uma garantia extra)
create or replace function public.enviar_medicao(
  p_token text,
  p_temperatura numeric default null,
  p_umidade numeric default null,
  p_vibracao numeric default null,
  p_porta_aberta boolean default false,
  p_bateria numeric default null,
  p_latitude numeric default null,
  p_longitude numeric default null
)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_disp record;
  v_medicao uuid;
  v_alertas jsonb;
  v_em_viagem boolean;
begin
  select d.* into v_disp
  from public.dispositivo_credenciais c
  join public."Dispositivos" d on d.id = c.id_dispositivo
  where c.token_hash = encode(extensions.digest(coalesce(p_token, ''), 'sha256'), 'hex')
    and d.excluido_em is null;

  if not found then
    return jsonb_build_object('ok', false, 'erro', 'token inválido');
  end if;

  insert into public.medicoes (
    id_dispositivo, temperatura, umidade, vibracao, porta_aberta,
    latitude, longitude, bateria, registrado_em
  ) values (
    v_disp.id, p_temperatura, p_umidade, p_vibracao, coalesce(p_porta_aberta, false),
    p_latitude, p_longitude, p_bateria, now()
  ) returning id into v_medicao;

  select coalesce(jsonb_agg(tipo), '[]'::jsonb) into v_alertas
  from public.ocorrencias where id_medicao = v_medicao;

  select exists (
    select 1 from public.viagens
    where id_dispositivo = v_disp.id and status = 'em_andamento'
  ) into v_em_viagem;

  return jsonb_build_object(
    'ok', true,
    'veiculo', coalesce(v_disp.placa_veiculo, v_disp.nome_dispositivo),
    'em_viagem', v_em_viagem,
    'temperatura_minima', v_disp.temperatura_minima,
    'temperatura_maxima', v_disp.temperatura_maxima,
    'umidade_maxima', v_disp.umidade_maxima,
    'limite_vibracao', v_disp.limite_vibracao,
    'bateria_minima', v_disp.bateria_minima,
    'alertas', v_alertas
  );
end;
$$;

-- 4. Quem pode executar cada função -----------------------------------------
do $$
declare
  fn text;
begin
  -- só usuários logados
  foreach fn in array array[
    'criar_convite(text, text)', 'excluir_funcionario(uuid)', 'excluir_dispositivo(uuid)',
    'gerar_token_dispositivo(uuid)', 'minha_empresa()', 'admin_da_empresa(uuid)',
    'meu_cargo_normalizado()', 'is_admin()', 'is_gerente()', 'gerencia_frota(uuid)',
    'opera_na_frota(uuid)', 'pode_ver_dispositivo(uuid)', 'gerencia_operador(uuid)',
    'pode_ver_usuario(uuid)'
  ] loop
    execute format('revoke all on function public.%s from public, anon', fn);
    execute format('grant execute on function public.%s to authenticated', fn);
  end loop;
  -- também visitantes: cadastro público e ESP32
  execute 'grant execute on function public.verificar_dados_em_uso(text, text, text, uuid) to anon, authenticated';
  execute 'grant execute on function public.enviar_medicao(text, numeric, numeric, numeric, boolean, numeric, numeric, numeric) to anon, authenticated';
end $$;

-- Anexos de viagem: só quem enviou altera ou apaga (antes: admin de qualquer empresa)
drop policy if exists "Atualizacao de anexos pelo proprietario ou admin" on storage.objects;
create policy "Atualizacao de anexos pelo proprietario ou admin" on storage.objects
  for update to authenticated
  using (bucket_id = 'anexos-viagem' and auth.uid() = owner)
  with check (bucket_id = 'anexos-viagem' and auth.uid() = owner);
drop policy if exists "Exclusao de anexos pelo proprietario ou admin" on storage.objects;
create policy "Exclusao de anexos pelo proprietario ou admin" on storage.objects
  for delete to authenticated
  using (bucket_id = 'anexos-viagem' and auth.uid() = owner);

notify pgrst, 'reload schema';
