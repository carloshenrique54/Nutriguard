-- =============================================================================
-- NutriGuard — Segurança e isolamento de dados por perfil
-- Executar no SQL Editor do Supabase (DEPOIS dos demais scripts).
--
-- Implementa as regras da especificação (Diagrama de Usuários):
--   • ADM: cadastro público pela tela normal; acesso a todo o sistema.
--   • Gerente: criado pelo ADM; vê apenas a própria frota e seus veículos;
--     pode cadastrar operadores e vinculá-los aos veículos da sua frota.
--   • Operador: criado pelo ADM ou gerente; vê apenas o próprio veículo.
--   • O controle é aplicado no banco (RLS), não só na interface: alterar
--     parâmetros da requisição não dá acesso a dados de outros perfis.
--
-- Também corrige:
--   • Sequestro de perfil: em conflito de CPF a trigger antiga trocava o id do
--     perfil existente pelo id da conta nova.
--   • Usuário alterando o próprio cargo (operador → admin).
--   • Usuarios sem política de DELETE (exclusão "silenciosa" sem efeito).
--   • Tabela viagens sem RLS (aberta inclusive para visitantes anônimos).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Funções auxiliares (security definer: leem as tabelas sem passar pelo RLS,
-- o que evita recursão entre as políticas de Frotas, Dispositivos e Usuarios)
-- -----------------------------------------------------------------------------
create or replace function public.meu_cargo_normalizado()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select case
           when lower(trim(cargo::text)) in ('admin', 'adm', 'administrador') then 'admin'
           when lower(trim(cargo::text)) = 'gerente' then 'gerente'
           when lower(trim(cargo::text)) = 'operador' then 'operador'
         end
  from public."Usuarios"
  where id::text = auth.uid()::text
  limit 1;
$$;

create or replace function public.is_admin()
returns boolean
language sql stable security definer set search_path = public
as $$ select coalesce(public.meu_cargo_normalizado() = 'admin', false); $$;

create or replace function public.is_gerente()
returns boolean
language sql stable security definer set search_path = public
as $$ select coalesce(public.meu_cargo_normalizado() = 'gerente', false); $$;

-- O usuário logado é o gerente responsável pela frota?
create or replace function public.gerencia_frota(p_frota uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select p_frota is not null and exists (
    select 1 from public."Frotas"
    where id::text = p_frota::text
      and id_gerente::text = auth.uid()::text
  );
$$;

-- O usuário logado opera algum veículo desta frota?
create or replace function public.opera_na_frota(p_frota uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select p_frota is not null and exists (
    select 1 from public."Dispositivos"
    where id_frota::text = p_frota::text
      and id_operador::text = auth.uid()::text
  );
$$;

-- O usuário logado pode ver este dispositivo (e suas medições/ocorrências)?
create or replace function public.pode_ver_dispositivo(p_dispositivo uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select public.is_admin() or exists (
    select 1 from public."Dispositivos" d
    where d.id::text = p_dispositivo::text
      and (
        d.id_operador::text = auth.uid()::text
        or public.gerencia_frota(d.id_frota)
      )
  );
$$;

-- O usuário logado (gerente) gerencia este operador?
-- Operadores ainda sem veículo ficam visíveis aos gerentes para que possam
-- ser vinculados a um veículo da frota.
create or replace function public.gerencia_operador(p_usuario uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select public.is_gerente()
    and exists (
      select 1 from public."Usuarios" u
      where u.id::text = p_usuario::text
        and lower(trim(u.cargo::text)) = 'operador'
    )
    and (
      not exists (
        select 1 from public."Dispositivos" d
        where d.id_operador::text = p_usuario::text
      )
      or exists (
        select 1 from public."Dispositivos" d
        where d.id_operador::text = p_usuario::text
          and public.gerencia_frota(d.id_frota)
      )
    );
$$;

-- O usuário logado pode ver este perfil?
create or replace function public.pode_ver_usuario(p_usuario uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select p_usuario::text = auth.uid()::text
    or public.is_admin()
    or public.gerencia_operador(p_usuario)
    -- operador enxerga o gerente responsável pela frota do seu veículo
    or exists (
      select 1 from public."Frotas" f
      where f.id_gerente::text = p_usuario::text
        and public.opera_na_frota(f.id)
    );
$$;

do $$
declare
  fn text;
begin
  foreach fn in array array[
    'meu_cargo_normalizado()', 'is_admin()', 'is_gerente()',
    'gerencia_frota(uuid)', 'opera_na_frota(uuid)', 'pode_ver_dispositivo(uuid)',
    'gerencia_operador(uuid)', 'pode_ver_usuario(uuid)'
  ] loop
    execute format('revoke all on function public.%s from public', fn);
    execute format('grant execute on function public.%s to authenticated', fn);
  end loop;
end $$;

-- -----------------------------------------------------------------------------
-- Trigger de criação de perfil
--   • Cadastro público (sem cargo ou cargo 'admin') → 'admin', conforme a
--     especificação.
--   • Contas criadas pelo ADM/gerente pedem 'gerente' ou 'operador' no
--     metadata. Pedir um cargo MENOR que o do cadastro público não concede
--     privilégio algum, então é seguro aceitar.
--   • Conflito de CPF/e-mail aborta o cadastro (antes: sequestrava o perfil).
-- -----------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_nome text;
  v_cpf text;
  v_telefone text;
  v_cargo text;
  v_cargo_pedido text;
  v_data_nascimento date;
  v_numero_cnh text;
  v_validade_cnh date;
begin
  v_nome := coalesce(nullif(new.raw_user_meta_data->>'nome', ''), split_part(new.email, '@', 1));
  v_cpf := nullif(new.raw_user_meta_data->>'cpf', '');
  v_telefone := nullif(new.raw_user_meta_data->>'telefone', '');

  v_cargo_pedido := lower(trim(coalesce(new.raw_user_meta_data->>'cargo', '')));
  v_cargo := case
               when v_cargo_pedido in ('gerente', 'operador') then v_cargo_pedido
               else 'admin'
             end;

  begin
    v_data_nascimento := nullif(new.raw_user_meta_data->>'data_nascimento', '')::date;
  exception when others then
    v_data_nascimento := null;
  end;

  v_numero_cnh := nullif(new.raw_user_meta_data->>'numero_cnh', '');

  begin
    v_validade_cnh := nullif(new.raw_user_meta_data->>'validade_cnh', '')::date;
  exception when others then
    v_validade_cnh := null;
  end;

  insert into public."Usuarios" (
    id, nome, email, cpf, telefone, cargo,
    data_nascimento, numero_cnh, validade_cnh,
    created_at, updated_at
  )
  values (
    new.id, v_nome, new.email, v_cpf, v_telefone, v_cargo,
    v_data_nascimento, v_numero_cnh, v_validade_cnh,
    now(), now()
  )
  on conflict (id) do update set
    nome            = excluded.nome,
    email           = excluded.email,
    cpf             = coalesce(excluded.cpf, public."Usuarios".cpf),
    telefone        = coalesce(excluded.telefone, public."Usuarios".telefone),
    data_nascimento = coalesce(excluded.data_nascimento, public."Usuarios".data_nascimento),
    numero_cnh      = coalesce(excluded.numero_cnh, public."Usuarios".numero_cnh),
    validade_cnh    = coalesce(excluded.validade_cnh, public."Usuarios".validade_cnh),
    updated_at      = now();
    -- cargo de perfil já existente NÃO é alterado aqui.

  return new;
exception
  when unique_violation then
    -- O Auth devolve "Database error saving new user", já tratado no app.
    raise exception 'CPF ou e-mail já cadastrado para outro usuário'
      using errcode = '23505';
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- -----------------------------------------------------------------------------
-- Usuarios: somente ADM altera cargo ou id
-- (auth.uid() nulo = SQL Editor, service_role ou triggers do Auth)
-- -----------------------------------------------------------------------------
create or replace function public.trg_proteger_cargo_usuario()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or public.is_admin() then
    return new;
  end if;

  if tg_op = 'INSERT' then
    if lower(trim(coalesce(new.cargo::text, 'operador'))) <> 'operador' then
      raise exception 'Somente administradores podem definir o cargo de um usuário'
        using errcode = '42501';
    end if;
  elsif tg_op = 'UPDATE' then
    if new.cargo is distinct from old.cargo then
      raise exception 'Somente administradores podem alterar o cargo de um usuário'
        using errcode = '42501';
    end if;
    if new.id is distinct from old.id then
      raise exception 'Somente administradores podem alterar o id de um usuário'
        using errcode = '42501';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists proteger_cargo_usuario on public."Usuarios";
create trigger proteger_cargo_usuario
  before insert or update on public."Usuarios"
  for each row execute function public.trg_proteger_cargo_usuario();

-- -----------------------------------------------------------------------------
-- Dispositivos: o gerente só pode trocar o operador vinculado (id_operador)
-- dos veículos da sua frota, e somente para um usuário com cargo 'operador'.
-- -----------------------------------------------------------------------------
create or replace function public.trg_proteger_dispositivo()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or public.is_admin() then
    return new;
  end if;

  if (to_jsonb(new) - 'id_operador' - 'updated_at')
     is distinct from (to_jsonb(old) - 'id_operador' - 'updated_at') then
    raise exception 'Gerentes podem alterar apenas o operador vinculado ao veículo'
      using errcode = '42501';
  end if;

  if new.id_operador is not null and not exists (
    select 1 from public."Usuarios" u
    where u.id::text = new.id_operador::text
      and lower(trim(u.cargo::text)) = 'operador'
  ) then
    raise exception 'O veículo só pode ser vinculado a um usuário com cargo operador'
      using errcode = '42501';
  end if;

  return new;
end;
$$;

drop trigger if exists proteger_dispositivo on public."Dispositivos";
create trigger proteger_dispositivo
  before update on public."Dispositivos"
  for each row execute function public.trg_proteger_dispositivo();

-- -----------------------------------------------------------------------------
-- Recria as políticas do zero. Políticas permissivas se somam (OR): qualquer
-- política antiga "using (true)" que sobrar anularia o isolamento.
-- Em medicoes/ocorrencias só as de SELECT são trocadas, para não interferir
-- na gravação feita pelos dispositivos.
-- -----------------------------------------------------------------------------
do $$
declare
  r record;
begin
  for r in
    select policyname, tablename
    from pg_policies
    where schemaname = 'public'
      and (
        tablename in ('Usuarios', 'Frotas', 'Dispositivos', 'viagens')
        or (tablename in ('medicoes', 'ocorrencias', 'fins_viagem') and cmd in ('SELECT', 'ALL'))
      )
  loop
    execute format('drop policy if exists %I on public.%I', r.policyname, r.tablename);
  end loop;
end $$;

alter table public."Usuarios"     enable row level security;
alter table public."Frotas"       enable row level security;
alter table public."Dispositivos" enable row level security;
alter table public."medicoes"     enable row level security;
alter table public."ocorrencias"  enable row level security;

-- Visitantes não autenticados não escrevem perfis
revoke insert, update, delete on public."Usuarios" from anon;

-- Usuarios ---------------------------------------------------------------------
create policy "usuarios_select_por_perfil" on public."Usuarios"
  for select to authenticated using (public.pode_ver_usuario(id));

create policy "usuarios_insert_proprio_ou_admin" on public."Usuarios"
  for insert to authenticated
  with check (id::text = auth.uid()::text or public.is_admin());

-- Próprio perfil, ADM, ou gerente editando operadores que gerencia
create policy "usuarios_update_por_perfil" on public."Usuarios"
  for update to authenticated
  using (id::text = auth.uid()::text or public.is_admin() or public.gerencia_operador(id))
  with check (id::text = auth.uid()::text or public.is_admin() or public.gerencia_operador(id));

create policy "usuarios_delete_admin" on public."Usuarios"
  for delete to authenticated using (public.is_admin());

-- Frotas -----------------------------------------------------------------------
create policy "frotas_select_por_perfil" on public."Frotas"
  for select to authenticated
  using (public.is_admin() or public.gerencia_frota(id) or public.opera_na_frota(id));

create policy "frotas_insert_admin" on public."Frotas"
  for insert to authenticated with check (public.is_admin());

create policy "frotas_update_admin" on public."Frotas"
  for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy "frotas_delete_admin" on public."Frotas"
  for delete to authenticated using (public.is_admin());

-- Dispositivos -----------------------------------------------------------------
create policy "dispositivos_select_por_perfil" on public."Dispositivos"
  for select to authenticated
  using (
    public.is_admin()
    or id_operador::text = auth.uid()::text
    or public.gerencia_frota(id_frota)
  );

create policy "dispositivos_insert_admin" on public."Dispositivos"
  for insert to authenticated with check (public.is_admin());

-- Gerente: apenas veículos da sua frota (o trigger limita a troca de operador)
create policy "dispositivos_update_admin_ou_gerente" on public."Dispositivos"
  for update to authenticated
  using (public.is_admin() or public.gerencia_frota(id_frota))
  with check (public.is_admin() or public.gerencia_frota(id_frota));

create policy "dispositivos_delete_admin" on public."Dispositivos"
  for delete to authenticated using (public.is_admin());

-- Medições e ocorrências: mesma visibilidade do dispositivo ------------------
create policy "medicoes_select_por_perfil" on public."medicoes"
  for select to authenticated using (public.pode_ver_dispositivo(id_dispositivo));

create policy "ocorrencias_select_por_perfil" on public."ocorrencias"
  for select to authenticated using (public.pode_ver_dispositivo(id_dispositivo));

-- fins_viagem e viagens (se existirem) ----------------------------------------
do $$
begin
  if to_regclass('public.fins_viagem') is not null then
    execute 'alter table public.fins_viagem enable row level security';
    execute $p$
      create policy "fins_viagem_select_por_perfil" on public.fins_viagem
        for select to authenticated
        using (
          id_operador::text = auth.uid()::text
          or public.is_admin()
          or public.pode_ver_dispositivo(id_dispositivo)
        )
    $p$;
  end if;

  if to_regclass('public.viagens') is not null then
    execute 'alter table public.viagens enable row level security';
    execute $p$
      create policy "viagens_select_por_perfil" on public.viagens
        for select to authenticated
        using (
          id_operador::text = auth.uid()::text
          or public.pode_ver_dispositivo(id_dispositivo)
        )
    $p$;
    execute $p$
      create policy "viagens_insert_operador_ou_admin" on public.viagens
        for insert to authenticated
        with check (
          public.is_admin()
          or (id_operador::text = auth.uid()::text and public.pode_ver_dispositivo(id_dispositivo))
        )
    $p$;
    execute $p$
      create policy "viagens_update_operador_ou_admin" on public.viagens
        for update to authenticated
        using (public.is_admin() or id_operador::text = auth.uid()::text)
        with check (public.is_admin() or id_operador::text = auth.uid()::text)
    $p$;
    execute $p$
      create policy "viagens_delete_admin" on public.viagens
        for delete to authenticated using (public.is_admin())
    $p$;
  end if;
end $$;

-- -----------------------------------------------------------------------------
-- Conferência: lista ADMs e gerentes atuais. Se alguém tiver se promovido
-- pela falha antiga, rebaixe com:
--   update public."Usuarios" set cargo = 'operador' where email = '...';
-- -----------------------------------------------------------------------------
select id, nome, email, cargo, created_at
from public."Usuarios"
where lower(trim(cargo::text)) in ('admin', 'adm', 'administrador', 'gerente')
order by cargo, created_at;
