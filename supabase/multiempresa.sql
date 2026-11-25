-- =============================================================================
-- NutriGuard — Empresas separadas, convites e envio de medições do ESP32
-- Executar no SQL Editor do Supabase DEPOIS de fix_security_critical.sql e
-- unicidade_usuarios.sql. Pode ser executado de novo sem problemas.
--
-- Regras:
--   • Cada cadastro público cria uma EMPRESA nova e o seu administrador.
--     Dois administradores de empresas diferentes não veem nada um do outro.
--   • Gerentes e operadores entram numa empresa por CONVITE: o admin (ou o
--     gerente, para operadores) registra o convite com e-mail e cargo antes de
--     criar a conta. A trigger de cadastro aplica o cargo e a empresa do
--     convite — nada disso vem do cliente, então ninguém entra na empresa de
--     outro.
--   • Admin: tudo da própria empresa.
--   • Gerente: a própria frota; cadastra, edita e apaga veículos dela e
--     cadastra/gerencia operadores.
--   • Operador: apenas o próprio veículo.
--   • O ESP32 envia medições pela função enviar_medicao(), identificado pelo
--     token do dispositivo (o banco guarda só o hash do token).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Tabelas
-- -----------------------------------------------------------------------------
create table if not exists public."Empresas" (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  created_at timestamptz not null default now()
);

alter table public."Usuarios"     add column if not exists id_empresa uuid references public."Empresas"(id) on delete cascade;
alter table public."Frotas"       add column if not exists id_empresa uuid references public."Empresas"(id) on delete cascade;
alter table public."Dispositivos" add column if not exists id_empresa uuid references public."Empresas"(id) on delete cascade;

create index if not exists idx_usuarios_empresa     on public."Usuarios"(id_empresa);
create index if not exists idx_frotas_empresa       on public."Frotas"(id_empresa);
create index if not exists idx_dispositivos_empresa on public."Dispositivos"(id_empresa);
create index if not exists idx_dispositivos_frota   on public."Dispositivos"(id_frota);
create index if not exists idx_dispositivos_operador on public."Dispositivos"(id_operador);
create index if not exists idx_medicoes_disp_data   on public.medicoes(id_dispositivo, registrado_em desc);
create index if not exists idx_ocorrencias_disp_data on public.ocorrencias(id_dispositivo, criado_em desc);

create table if not exists public.convites (
  id uuid primary key default gen_random_uuid(),
  email text not null,
  cargo text not null check (cargo in ('gerente', 'operador')),
  id_empresa uuid not null references public."Empresas"(id) on delete cascade,
  criado_por uuid references auth.users(id) on delete set null,
  criado_em timestamptz not null default now(),
  usado_em timestamptz
);
create index if not exists idx_convites_email_pendente
  on public.convites (lower(email)) where usado_em is null;

create table if not exists public.dispositivo_credenciais (
  id_dispositivo uuid primary key references public."Dispositivos"(id) on delete cascade,
  token_hash text not null,
  created_at timestamptz not null default now()
);
create unique index if not exists idx_credenciais_token on public.dispositivo_credenciais(token_hash);

-- Dados antigos sem empresa: agrupa todos numa empresa única (bancos já
-- povoados antes deste script).
do $$
declare
  v_empresa uuid;
begin
  if exists (select 1 from public."Usuarios" where id_empresa is null)
     or exists (select 1 from public."Frotas" where id_empresa is null)
     or exists (select 1 from public."Dispositivos" where id_empresa is null) then
    insert into public."Empresas" (nome) values ('Empresa principal') returning id into v_empresa;
    update public."Usuarios"     set id_empresa = v_empresa where id_empresa is null;
    update public."Frotas"       set id_empresa = v_empresa where id_empresa is null;
    update public."Dispositivos" set id_empresa = v_empresa where id_empresa is null;
  end if;
end $$;

-- -----------------------------------------------------------------------------
-- 2. Funções auxiliares (security definer: leem sem passar pelo RLS)
-- -----------------------------------------------------------------------------
create or replace function public.minha_empresa()
returns uuid
language sql stable security definer set search_path = public
as $$
  select id_empresa from public."Usuarios" where id::text = auth.uid()::text limit 1;
$$;

-- Admin da empresa informada (ou da própria, se nula)?
create or replace function public.admin_da_empresa(p_empresa uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select public.is_admin() and p_empresa is not null and p_empresa = public.minha_empresa();
$$;

create or replace function public.pode_ver_dispositivo(p_dispositivo uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public."Dispositivos" d
    where d.id::text = p_dispositivo::text
      and (
        public.admin_da_empresa(d.id_empresa)
        or d.id_operador::text = auth.uid()::text
        or public.gerencia_frota(d.id_frota)
      )
  );
$$;

-- Gerente gerencia este operador? (mesma empresa; sem veículo ou com veículo
-- na frota do gerente)
create or replace function public.gerencia_operador(p_usuario uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select public.is_gerente()
    and exists (
      select 1 from public."Usuarios" u
      where u.id::text = p_usuario::text
        and lower(trim(u.cargo::text)) = 'operador'
        and u.id_empresa = public.minha_empresa()
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

create or replace function public.pode_ver_usuario(p_usuario uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select p_usuario::text = auth.uid()::text
    or exists (
      select 1 from public."Usuarios" u
      where u.id::text = p_usuario::text
        and public.admin_da_empresa(u.id_empresa)
    )
    or public.gerencia_operador(p_usuario)
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
  foreach fn in array array['minha_empresa()', 'admin_da_empresa(uuid)'] loop
    execute format('revoke all on function public.%s from public', fn);
    execute format('grant execute on function public.%s to authenticated', fn);
  end loop;
end $$;

-- -----------------------------------------------------------------------------
-- 3. Convites e cadastro
-- -----------------------------------------------------------------------------
-- Chamado pelo app ANTES de criar a conta do funcionário.
create or replace function public.criar_convite(p_email text, p_cargo text)
returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  v_cargo text := lower(trim(coalesce(p_cargo, '')));
  v_email text := lower(trim(coalesce(p_email, '')));
  v_empresa uuid := public.minha_empresa();
  v_id uuid;
begin
  if v_email = '' then
    raise exception 'Informe o e-mail do funcionário.' using errcode = '22023';
  end if;
  if v_cargo not in ('gerente', 'operador') then
    raise exception 'Cargo inválido para convite: %', p_cargo using errcode = '22023';
  end if;
  if v_empresa is null
     or not (public.is_admin() or (public.is_gerente() and v_cargo = 'operador')) then
    raise exception 'Você não tem permissão para cadastrar este cargo.' using errcode = '42501';
  end if;
  if exists (select 1 from auth.users where lower(email) = v_email) then
    raise exception 'Este e-mail já está cadastrado no sistema.' using errcode = '23505';
  end if;

  delete from public.convites where lower(email) = v_email and usado_em is null;
  insert into public.convites (email, cargo, id_empresa, criado_por)
  values (v_email, v_cargo, v_empresa, auth.uid())
  returning id into v_id;
  return v_id;
end;
$$;

-- Perfil criado a partir do convite; sem convite, nasce uma empresa nova.
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
  v_empresa uuid;
  v_convite record;
  v_data_nascimento date;
  v_numero_cnh text;
  v_validade_cnh date;
begin
  v_nome := coalesce(nullif(new.raw_user_meta_data->>'nome', ''), split_part(new.email, '@', 1));
  v_cpf := nullif(new.raw_user_meta_data->>'cpf', '');
  v_telefone := nullif(new.raw_user_meta_data->>'telefone', '');

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

  select * into v_convite
  from public.convites
  where lower(email) = lower(new.email)
    and usado_em is null
    and criado_em > now() - interval '7 days'
  order by criado_em desc
  limit 1
  for update;

  if found then
    v_cargo := v_convite.cargo;
    v_empresa := v_convite.id_empresa;
    update public.convites set usado_em = now() where id = v_convite.id;
  else
    v_cargo := 'admin';
    insert into public."Empresas" (nome)
    values (coalesce(nullif(trim(new.raw_user_meta_data->>'empresa'), ''), 'Empresa de ' || v_nome))
    returning id into v_empresa;
  end if;

  insert into public."Usuarios" (
    id, nome, email, cpf, telefone, cargo, id_empresa,
    data_nascimento, numero_cnh, validade_cnh, created_at, updated_at
  )
  values (
    new.id, v_nome, new.email, v_cpf, v_telefone, v_cargo, v_empresa,
    v_data_nascimento, v_numero_cnh, v_validade_cnh, coalesce(new.created_at, now()), now()
  );

  return new;
exception
  when unique_violation then
    raise exception 'CPF, e-mail ou telefone já cadastrado para outro usuário'
      using errcode = '23505';
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Exclui o funcionário de verdade (login + perfil), desvinculando frota/veículo.
create or replace function public.excluir_funcionario(p_usuario uuid)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_alvo record;
begin
  select * into v_alvo from public."Usuarios" where id = p_usuario;
  if not found then
    raise exception 'Funcionário não encontrado.' using errcode = 'P0002';
  end if;
  if p_usuario::text = auth.uid()::text then
    raise exception 'Você não pode excluir a própria conta por aqui.' using errcode = '42501';
  end if;
  if not (
    (public.admin_da_empresa(v_alvo.id_empresa) and lower(v_alvo.cargo) <> 'admin')
    or public.gerencia_operador(p_usuario)
  ) then
    raise exception 'Você não tem permissão para excluir este funcionário.' using errcode = '42501';
  end if;

  update public."Dispositivos" set id_operador = null where id_operador::text = p_usuario::text;
  update public."Frotas" set id_gerente = null where id_gerente::text = p_usuario::text;
  delete from auth.users where id = p_usuario;   -- o perfil sai em cascata
end;
$$;

-- -----------------------------------------------------------------------------
-- 4. Proteções por trigger
-- -----------------------------------------------------------------------------
-- Usuarios: cargo e empresa só mudam por admin da mesma empresa; id nunca.
create or replace function public.trg_proteger_cargo_usuario()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if auth.uid() is null then
    return new;
  end if;

  if tg_op = 'INSERT' then
    if lower(trim(coalesce(new.cargo::text, 'operador'))) <> 'operador' and not public.is_admin() then
      raise exception 'Somente administradores podem definir o cargo de um usuário' using errcode = '42501';
    end if;
    return new;
  end if;

  if new.id is distinct from old.id then
    raise exception 'O id de um usuário não pode ser alterado' using errcode = '42501';
  end if;
  if new.id_empresa is distinct from old.id_empresa then
    raise exception 'A empresa de um usuário não pode ser alterada' using errcode = '42501';
  end if;
  if new.cargo is distinct from old.cargo and not public.admin_da_empresa(old.id_empresa) then
    raise exception 'Somente administradores podem alterar o cargo de um usuário' using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists proteger_cargo_usuario on public."Usuarios";
create trigger proteger_cargo_usuario
  before insert or update on public."Usuarios"
  for each row execute function public.trg_proteger_cargo_usuario();

-- Frotas: empresa definida pelo banco; gerente precisa ser da mesma empresa.
create or replace function public.trg_frota_empresa()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    if auth.uid() is not null then
      new.id_empresa := public.minha_empresa();
    end if;
  else
    new.id_empresa := old.id_empresa;
  end if;

  if new.id_gerente is not null and not exists (
    select 1 from public."Usuarios" u
    where u.id::text = new.id_gerente::text
      and lower(trim(u.cargo::text)) = 'gerente'
      and u.id_empresa = new.id_empresa
  ) then
    raise exception 'O responsável pela frota precisa ser um gerente da mesma empresa' using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists frota_empresa on public."Frotas";
create trigger frota_empresa
  before insert or update on public."Frotas"
  for each row execute function public.trg_frota_empresa();

-- Dispositivos: empresa vem da frota; frota e operador precisam ser da
-- mesma empresa. (Substitui a regra antiga que limitava o gerente a trocar
-- apenas o operador.)
drop trigger if exists proteger_dispositivo on public."Dispositivos";
drop function if exists public.trg_proteger_dispositivo();

create or replace function public.trg_dispositivo_empresa()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if tg_op = 'UPDATE' then
    new.id_empresa := old.id_empresa;
  elsif new.id_frota is not null then
    select id_empresa into new.id_empresa from public."Frotas" where id = new.id_frota;
  elsif auth.uid() is not null then
    new.id_empresa := public.minha_empresa();
  end if;

  if new.id_empresa is null then
    raise exception 'Não foi possível identificar a empresa do dispositivo' using errcode = '23502';
  end if;

  if new.id_frota is not null and not exists (
    select 1 from public."Frotas" f where f.id = new.id_frota and f.id_empresa = new.id_empresa
  ) then
    raise exception 'A frota escolhida não pertence à sua empresa' using errcode = '42501';
  end if;

  if new.id_operador is not null and not exists (
    select 1 from public."Usuarios" u
    where u.id::text = new.id_operador::text
      and lower(trim(u.cargo::text)) = 'operador'
      and u.id_empresa = new.id_empresa
  ) then
    raise exception 'O veículo só pode ser vinculado a um operador da mesma empresa' using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists dispositivo_empresa on public."Dispositivos";
create trigger dispositivo_empresa
  before insert or update on public."Dispositivos"
  for each row execute function public.trg_dispositivo_empresa();

-- -----------------------------------------------------------------------------
-- 5. ESP32: token do dispositivo e envio de medições
-- -----------------------------------------------------------------------------
drop function if exists public.gerar_token_dispositivo(uuid);
create or replace function public.gerar_token_dispositivo(p_id_dispositivo uuid)
returns text
language plpgsql security definer set search_path = public
as $$
declare
  v_disp record;
  v_token text;
begin
  select * into v_disp from public."Dispositivos" where id = p_id_dispositivo;
  if not found then
    raise exception 'Dispositivo não encontrado.' using errcode = 'P0002';
  end if;
  if not (public.admin_da_empresa(v_disp.id_empresa) or public.gerencia_frota(v_disp.id_frota)) then
    raise exception 'Você não tem permissão para gerar o token deste dispositivo.' using errcode = '42501';
  end if;

  v_token := 'ng_' || encode(extensions.gen_random_bytes(18), 'hex');
  insert into public.dispositivo_credenciais (id_dispositivo, token_hash)
  values (p_id_dispositivo, encode(extensions.digest(v_token, 'sha256'), 'hex'))
  on conflict (id_dispositivo) do update
    set token_hash = excluded.token_hash, created_at = now();
  return v_token;   -- mostrado uma única vez; o banco guarda só o hash
end;
$$;

revoke all on function public.gerar_token_dispositivo(uuid) from public;
grant execute on function public.gerar_token_dispositivo(uuid) to authenticated;

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
  where c.token_hash = encode(extensions.digest(coalesce(p_token, ''), 'sha256'), 'hex');

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

revoke all on function public.enviar_medicao(text, numeric, numeric, numeric, boolean, numeric, numeric, numeric) from public;
grant execute on function public.enviar_medicao(text, numeric, numeric, numeric, boolean, numeric, numeric, numeric) to anon, authenticated;

revoke all on function public.criar_convite(text, text) from public;
grant execute on function public.criar_convite(text, text) to authenticated;
revoke all on function public.excluir_funcionario(uuid) from public;
grant execute on function public.excluir_funcionario(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 6. Políticas: recria todas do zero, sempre limitadas à empresa
-- -----------------------------------------------------------------------------
do $$
declare
  r record;
begin
  for r in
    select policyname, tablename
    from pg_policies
    where schemaname = 'public'
      and tablename in ('Empresas', 'Usuarios', 'Frotas', 'Dispositivos', 'medicoes', 'ocorrencias',
                        'fins_viagem', 'viagens', 'convites', 'dispositivo_credenciais')
  loop
    execute format('drop policy if exists %I on public.%I', r.policyname, r.tablename);
  end loop;
end $$;

alter table public."Empresas"             enable row level security;
alter table public."Usuarios"             enable row level security;
alter table public."Frotas"               enable row level security;
alter table public."Dispositivos"         enable row level security;
alter table public.medicoes               enable row level security;
alter table public.ocorrencias            enable row level security;
alter table public.convites               enable row level security;   -- só via funções
alter table public.dispositivo_credenciais enable row level security;  -- só via funções

grant select, update on public."Empresas" to authenticated;

-- Empresas
create policy "empresas_select_propria" on public."Empresas"
  for select to authenticated using (id = public.minha_empresa());
create policy "empresas_update_admin" on public."Empresas"
  for update to authenticated
  using (public.admin_da_empresa(id)) with check (public.admin_da_empresa(id));

-- Usuarios
create policy "usuarios_select_por_perfil" on public."Usuarios"
  for select to authenticated using (public.pode_ver_usuario(id));
create policy "usuarios_insert_proprio" on public."Usuarios"
  for insert to authenticated with check (id::text = auth.uid()::text);
create policy "usuarios_update_por_perfil" on public."Usuarios"
  for update to authenticated
  using (id::text = auth.uid()::text or public.admin_da_empresa(id_empresa) or public.gerencia_operador(id))
  with check (id::text = auth.uid()::text or public.admin_da_empresa(id_empresa) or public.gerencia_operador(id));
-- (exclusão de funcionário: função excluir_funcionario)

-- Frotas
create policy "frotas_select_por_perfil" on public."Frotas"
  for select to authenticated
  using (public.admin_da_empresa(id_empresa) or public.gerencia_frota(id) or public.opera_na_frota(id));
create policy "frotas_insert_admin" on public."Frotas"
  for insert to authenticated with check (public.admin_da_empresa(id_empresa));
create policy "frotas_update_admin" on public."Frotas"
  for update to authenticated
  using (public.admin_da_empresa(id_empresa)) with check (public.admin_da_empresa(id_empresa));
create policy "frotas_delete_admin" on public."Frotas"
  for delete to authenticated using (public.admin_da_empresa(id_empresa));

-- Dispositivos: admin da empresa ou gerente da frota (cadastrar, editar, apagar)
create policy "dispositivos_select_por_perfil" on public."Dispositivos"
  for select to authenticated
  using (
    public.admin_da_empresa(id_empresa)
    or id_operador::text = auth.uid()::text
    or public.gerencia_frota(id_frota)
  );
create policy "dispositivos_insert_admin_ou_gerente" on public."Dispositivos"
  for insert to authenticated
  with check (public.admin_da_empresa(id_empresa) or public.gerencia_frota(id_frota));
create policy "dispositivos_update_admin_ou_gerente" on public."Dispositivos"
  for update to authenticated
  using (public.admin_da_empresa(id_empresa) or public.gerencia_frota(id_frota))
  with check (public.admin_da_empresa(id_empresa) or public.gerencia_frota(id_frota));
create policy "dispositivos_delete_admin_ou_gerente" on public."Dispositivos"
  for delete to authenticated
  using (public.admin_da_empresa(id_empresa) or public.gerencia_frota(id_frota));

-- Medições: leitura conforme o dispositivo; gravação só pelo ESP32 (enviar_medicao)
create policy "medicoes_select_por_perfil" on public.medicoes
  for select to authenticated using (public.pode_ver_dispositivo(id_dispositivo));

-- Ocorrências: leitura conforme o dispositivo; admin/gerente atualizam o status
create policy "ocorrencias_select_por_perfil" on public.ocorrencias
  for select to authenticated using (public.pode_ver_dispositivo(id_dispositivo));
create policy "ocorrencias_update_admin_ou_gerente" on public.ocorrencias
  for update to authenticated
  using ((public.is_admin() or public.is_gerente()) and public.pode_ver_dispositivo(id_dispositivo))
  with check ((public.is_admin() or public.is_gerente()) and public.pode_ver_dispositivo(id_dispositivo));

-- Fins de viagem e viagens
do $$
begin
  if to_regclass('public.fins_viagem') is not null then
    execute 'alter table public.fins_viagem enable row level security';
    execute $p$ create policy "fins_viagem_select_por_perfil" on public.fins_viagem
      for select to authenticated
      using (id_operador::text = auth.uid()::text or public.pode_ver_dispositivo(id_dispositivo)) $p$;
    execute $p$ create policy "fins_viagem_insert_operador" on public.fins_viagem
      for insert to authenticated
      with check (id_operador::text = auth.uid()::text
                  and (id_dispositivo is null or public.pode_ver_dispositivo(id_dispositivo))) $p$;
    execute $p$ create policy "fins_viagem_update_operador" on public.fins_viagem
      for update to authenticated
      using (id_operador::text = auth.uid()::text) with check (id_operador::text = auth.uid()::text) $p$;
    execute $p$ create policy "fins_viagem_delete_admin" on public.fins_viagem
      for delete to authenticated
      using (public.is_admin() and public.pode_ver_dispositivo(id_dispositivo)) $p$;
  end if;

  if to_regclass('public.viagens') is not null then
    execute 'alter table public.viagens enable row level security';
    execute $p$ create policy "viagens_select_por_perfil" on public.viagens
      for select to authenticated
      using (id_operador::text = auth.uid()::text or public.pode_ver_dispositivo(id_dispositivo)) $p$;
    execute $p$ create policy "viagens_insert_por_perfil" on public.viagens
      for insert to authenticated with check (public.pode_ver_dispositivo(id_dispositivo)) $p$;
    execute $p$ create policy "viagens_update_por_perfil" on public.viagens
      for update to authenticated
      using (public.pode_ver_dispositivo(id_dispositivo)) with check (public.pode_ver_dispositivo(id_dispositivo)) $p$;
    execute $p$ create policy "viagens_delete_admin" on public.viagens
      for delete to authenticated
      using (public.is_admin() and public.pode_ver_dispositivo(id_dispositivo)) $p$;
  end if;
end $$;

notify pgrst, 'reload schema';

select tablename, count(*) as politicas
from pg_policies where schemaname = 'public'
group by 1 order by 1;
