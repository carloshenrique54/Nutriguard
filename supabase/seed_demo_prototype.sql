-- ==============================================================================
-- NUTRIGUARD - SCRIPT DE RESET E CARGA COMPLETA (PROTÓTIPO / DEMONSTRAÇÃO)
-- ==============================================================================
-- Como executar no Supabase:
--   1. Acesse o painel do seu projeto no Supabase (https://supabase.com/dashboard)
--   2. No menu lateral esquerdo, clique em "SQL Editor"
--   3. Cole todo o conteúdo deste arquivo e clique no botão verde "Run"
-- ==============================================================================

-- Habilita extensões para geração de UUID e criptografia de senhas
create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

-- ==============================================================================
-- 1. GARANTE A ESTRUTURA DAS TABELAS CONFORME O DIAGRAMA
-- ==============================================================================

create table if not exists public."Usuarios" (
    id uuid primary key references auth.users(id) on delete cascade,
    nome text not null,
    email text,
    cpf text not null,
    telefone text,
    cargo varchar(50) default 'operador',
    data_nascimento date,
    numero_cnh text,
    validade_cnh date,
    foto_url text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public."Frotas" (
    id uuid primary key default gen_random_uuid(),
    id_gerente uuid references public."Usuarios"(id) on delete set null,
    nome text not null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public."Dispositivos" (
    id uuid primary key default gen_random_uuid(),
    id_operador uuid references public."Usuarios"(id) on delete set null,
    id_frota uuid references public."Frotas"(id) on delete set null,
    nome_dispositivo text not null,
    numero_serie text,
    modelo_dispositivo text,
    modelo_veiculo text,
    placa_veiculo text,
    temperatura_minima numeric default 2.0,
    temperatura_maxima numeric default 8.0,
    umidade_minima numeric default 30.0,
    umidade_maxima numeric default 60.0,
    sensibilidade_vibracao int8 default 2,
    limite_vibracao int8 default 2,
    intervalo_dados float8 default 30.0,
    bateria_minima numeric default 20.0,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.dispositivo_credenciais (
    id_dispositivo uuid primary key references public."Dispositivos"(id) on delete cascade,
    token_hash text not null,
    created_at timestamptz not null default now()
);

create table if not exists public."medicoes" (
    id uuid primary key default gen_random_uuid(),
    id_dispositivo uuid references public."Dispositivos"(id) on delete cascade,
    temperatura numeric,
    umidade numeric,
    vibracao numeric,
    porta_aberta boolean default false,
    latitude numeric,
    longitude numeric,
    bateria numeric,
    registrado_em timestamptz not null default now()
);

create table if not exists public."ocorrencias" (
    id uuid primary key default gen_random_uuid(),
    id_dispositivo uuid references public."Dispositivos"(id) on delete cascade,
    id_medicao uuid references public."medicoes"(id) on delete set null,
    tipo text not null,
    valor_registrado numeric,
    limite_configurado numeric,
    status text default 'Pendente',
    criado_em timestamptz not null default now()
);

create table if not exists public.fins_viagem (
    id uuid primary key default gen_random_uuid(),
    id_operador uuid references public."Usuarios"(id) on delete set null,
    id_dispositivo uuid references public."Dispositivos"(id) on delete set null,
    motivo text not null,
    rua text not null,
    bairro text,
    cidade text not null,
    cep text,
    anexos text[] default '{}'::text[],
    criado_em timestamptz not null default now(),
    atualizado_em timestamptz not null default now()
);

-- Remove quaisquer constraints restritivas antigas em ocorrencias (status, tipo, etc.)
alter table public."ocorrencias" drop constraint if exists ocorrencias_status_check;
alter table public."ocorrencias" drop constraint if exists ocorrencias_tipo_check;

do $$
declare
  r record;
begin
  for r in (
    select conname
    from pg_constraint con
    join pg_class rel on rel.oid = con.conrelid
    join pg_namespace nsp on nsp.oid = rel.relnamespace
    where nsp.nspname = 'public'
      and rel.relname = 'ocorrencias'
      and con.contype = 'c'
  ) loop
    execute format('alter table public."ocorrencias" drop constraint if exists %I', r.conname);
  end loop;
end $$;

-- ==============================================================================
-- 2. LIMPEZA TOTAL IMEDIATA DAS TABELAS OPERACIONAIS (TRUNCATE PRIMEIRO)
-- ==============================================================================
truncate table public.fins_viagem cascade;
truncate table public."ocorrencias" cascade;
truncate table public."medicoes" cascade;
truncate table public.dispositivo_credenciais cascade;
truncate table public."Dispositivos" cascade;
truncate table public."Frotas" cascade;

-- ==============================================================================
-- 3. BLINDAGEM DA TRIGGER handle_new_user
-- ==============================================================================
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
  v_data_nascimento date;
  v_numero_cnh text;
  v_validade_cnh date;
begin
  v_nome := coalesce(nullif(new.raw_user_meta_data->>'nome', ''), split_part(new.email, '@', 1));
  v_cpf := coalesce(nullif(new.raw_user_meta_data->>'cpf', ''), '000.000.000-00');
  v_telefone := nullif(new.raw_user_meta_data->>'telefone', '');
  v_cargo := coalesce(nullif(new.raw_user_meta_data->>'cargo', ''), 'operador');

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
    id, nome, email, cpf, telefone, cargo, data_nascimento, numero_cnh, validade_cnh, created_at, updated_at
  ) values (
    new.id, v_nome, new.email, v_cpf, v_telefone, v_cargo, v_data_nascimento, v_numero_cnh, v_validade_cnh, now(), now()
  )
  on conflict (id) do update set
    nome = excluded.nome,
    cpf = coalesce(excluded.cpf, public."Usuarios".cpf),
    telefone = coalesce(excluded.telefone, public."Usuarios".telefone),
    cargo = excluded.cargo,
    data_nascimento = coalesce(excluded.data_nascimento, public."Usuarios".data_nascimento),
    numero_cnh = coalesce(excluded.numero_cnh, public."Usuarios".numero_cnh),
    validade_cnh = coalesce(excluded.validade_cnh, public."Usuarios".validade_cnh),
    updated_at = now();

  return new;
exception when others then
  return new;
end;
$$;

-- Bucket de fotos e anexos
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
    'anexos-viagem', 'anexos-viagem', true, 10485760,
    array['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'application/pdf']
)
on conflict (id) do update set public = true;

-- Funções auxiliares para RLS (garantidas caso ainda não existam no banco)
do $$
begin
  if not exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'meu_cargo'
  ) then
    create function public.meu_cargo()
    returns text
    language sql
    stable
    security definer
    set search_path = public
    as 'select coalesce(cargo::text, ''operador'') from public."Usuarios" where id = auth.uid() limit 1;';
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'sou_gerente_da_frota'
  ) then
    create function public.sou_gerente_da_frota(p_frota uuid)
    returns boolean
    language sql
    stable
    security definer
    set search_path = public
    as 'select exists (select 1 from public."Frotas" where id = p_frota and id_gerente = auth.uid());';
  end if;
end $$;

-- Habilita RLS em todas as tabelas
alter table public."Usuarios" enable row level security;
alter table public."Frotas" enable row level security;
alter table public."Dispositivos" enable row level security;
alter table public.dispositivo_credenciais enable row level security;
alter table public."medicoes" enable row level security;
alter table public."ocorrencias" enable row level security;
alter table public.fins_viagem enable row level security;

-- Remove políticas temporárias permissivas caso tenham sido criadas anteriormente
drop policy if exists "usuarios_all_auth" on public."Usuarios";
drop policy if exists "frotas_all_auth" on public."Frotas";
drop policy if exists "dispositivos_all_auth" on public."Dispositivos";
drop policy if exists "dispositivo_credenciais_all_auth" on public.dispositivo_credenciais;
drop policy if exists "medicoes_all_auth" on public."medicoes";
drop policy if exists "ocorrencias_all_auth" on public."ocorrencias";
drop policy if exists "fins_viagem_all_auth" on public.fins_viagem;

-- Garante que se faltar alguma política essencial de exclusão de usuário por admin, seja criada
do $$
begin
  if not exists (
    select 1 from pg_policies 
    where schemaname = 'public' and tablename = 'Usuarios' and policyname = 'usuarios_delete_admin'
  ) then
    create policy usuarios_delete_admin on public."Usuarios" 
      for delete to authenticated 
      using (((select public.meu_cargo()) = 'admin'::text));
  end if;
end $$;

-- Permissões gerais de schema
grant usage on schema public to authenticated;
grant usage on schema public to anon;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant select on all tables in schema public to anon;

-- ==============================================================================
-- 4. INSERÇÃO COM UUIDs ALEATÓRIOS E RELAÇÕES CONECTADAS
-- ==============================================================================
do $$
declare
  -- UUIDs aleatórios para usuários
  v_admin_id uuid := gen_random_uuid();
  v_gerente1_id uuid := gen_random_uuid();
  v_gerente2_id uuid := gen_random_uuid();
  v_operador1_id uuid := gen_random_uuid();
  v_operador2_id uuid := gen_random_uuid();

  -- UUIDs aleatórios para Frotas
  v_frota_sul_id uuid := gen_random_uuid();
  v_frota_sudeste_id uuid := gen_random_uuid();
  v_frota_urbana_id uuid := gen_random_uuid();

  -- UUIDs aleatórios para Dispositivos
  v_disp1_id uuid := gen_random_uuid();
  v_disp2_id uuid := gen_random_uuid();
  v_disp3_id uuid := gen_random_uuid();
  v_disp4_id uuid := gen_random_uuid();

  -- UUIDs aleatórios para medições que geram ocorrências
  v_med1_alerta_temp uuid := gen_random_uuid();
  v_med1_alerta_porta uuid := gen_random_uuid();
  v_med2_alerta_vib uuid := gen_random_uuid();
  v_med4_alerta_bat uuid := gen_random_uuid();

  -- Senha padrão para todos: '123456'
  v_senha_hash text := crypt('123456', gen_salt('bf'));
begin
  -- 4.1. Usuários no Auth do Supabase com CPF no metadata
  if exists (select 1 from auth.users where email = 'admin@nutriguard.com') then
    select id into v_admin_id from auth.users where email = 'admin@nutriguard.com';
    update auth.users set
      encrypted_password = v_senha_hash,
      raw_user_meta_data = jsonb_build_object(
        'nome', 'Carlos Henrique (ADM)', 'cargo', 'admin', 'cpf', '123.456.789-00', 'telefone', '(11) 98765-4321', 'numero_cnh', '12345678900'
      )
    where id = v_admin_id;
  else
    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at
    ) values (
      '00000000-0000-0000-0000-000000000000', v_admin_id, 'authenticated', 'authenticated',
      'admin@nutriguard.com', v_senha_hash, now(),
      '{"provider":"email","providers":["email"]}',
      jsonb_build_object(
        'nome', 'Carlos Henrique (ADM)', 'cargo', 'admin', 'cpf', '123.456.789-00', 'telefone', '(11) 98765-4321', 'numero_cnh', '12345678900'
      ),
      now(), now()
    );
  end if;

  if exists (select 1 from auth.users where email = 'gerente.sul@nutriguard.com') then
    select id into v_gerente1_id from auth.users where email = 'gerente.sul@nutriguard.com';
    update auth.users set
      encrypted_password = v_senha_hash,
      raw_user_meta_data = jsonb_build_object(
        'nome', 'Mariana Silveira', 'cargo', 'gerente', 'cpf', '234.567.890-11', 'telefone', '(41) 99876-5432', 'numero_cnh', '23456789011'
      )
    where id = v_gerente1_id;
  else
    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at
    ) values (
      '00000000-0000-0000-0000-000000000000', v_gerente1_id, 'authenticated', 'authenticated',
      'gerente.sul@nutriguard.com', v_senha_hash, now(),
      '{"provider":"email","providers":["email"]}',
      jsonb_build_object(
        'nome', 'Mariana Silveira', 'cargo', 'gerente', 'cpf', '234.567.890-11', 'telefone', '(41) 99876-5432', 'numero_cnh', '23456789011'
      ),
      now(), now()
    );
  end if;

  if exists (select 1 from auth.users where email = 'gerente.sudeste@nutriguard.com') then
    select id into v_gerente2_id from auth.users where email = 'gerente.sudeste@nutriguard.com';
    update auth.users set
      encrypted_password = v_senha_hash,
      raw_user_meta_data = jsonb_build_object(
        'nome', 'Roberto Costa', 'cargo', 'gerente', 'cpf', '345.678.901-22', 'telefone', '(19) 98123-4567', 'numero_cnh', '34567890122'
      )
    where id = v_gerente2_id;
  else
    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at
    ) values (
      '00000000-0000-0000-0000-000000000000', v_gerente2_id, 'authenticated', 'authenticated',
      'gerente.sudeste@nutriguard.com', v_senha_hash, now(),
      '{"provider":"email","providers":["email"]}',
      jsonb_build_object(
        'nome', 'Roberto Costa', 'cargo', 'gerente', 'cpf', '345.678.901-22', 'telefone', '(19) 98123-4567', 'numero_cnh', '34567890122'
      ),
      now(), now()
    );
  end if;

  if exists (select 1 from auth.users where email = 'operador.lucas@nutriguard.com') then
    select id into v_operador1_id from auth.users where email = 'operador.lucas@nutriguard.com';
    update auth.users set
      encrypted_password = v_senha_hash,
      raw_user_meta_data = jsonb_build_object(
        'nome', 'Lucas Mendes', 'cargo', 'operador', 'cpf', '456.789.012-33', 'telefone', '(11) 97654-3210', 'numero_cnh', '45678901233'
      )
    where id = v_operador1_id;
  else
    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at
    ) values (
      '00000000-0000-0000-0000-000000000000', v_operador1_id, 'authenticated', 'authenticated',
      'operador.lucas@nutriguard.com', v_senha_hash, now(),
      '{"provider":"email","providers":["email"]}',
      jsonb_build_object(
        'nome', 'Lucas Mendes', 'cargo', 'operador', 'cpf', '456.789.012-33', 'telefone', '(11) 97654-3210', 'numero_cnh', '45678901233'
      ),
      now(), now()
    );
  end if;

  if exists (select 1 from auth.users where email = 'operadora.juliana@nutriguard.com') then
    select id into v_operador2_id from auth.users where email = 'operadora.juliana@nutriguard.com';
    update auth.users set
      encrypted_password = v_senha_hash,
      raw_user_meta_data = jsonb_build_object(
        'nome', 'Juliana Oliveira', 'cargo', 'operador', 'cpf', '567.890.123-44', 'telefone', '(41) 99123-8877', 'numero_cnh', '56789012344'
      )
    where id = v_operador2_id;
  else
    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at
    ) values (
      '00000000-0000-0000-0000-000000000000', v_operador2_id, 'authenticated', 'authenticated',
      'operadora.juliana@nutriguard.com', v_senha_hash, now(),
      '{"provider":"email","providers":["email"]}',
      jsonb_build_object(
        'nome', 'Juliana Oliveira', 'cargo', 'operador', 'cpf', '567.890.123-44', 'telefone', '(41) 99123-8877', 'numero_cnh', '56789012344'
      ),
      now(), now()
    );
  end if;

  -- 4.2. Preenchimento de Usuarios (cpf como texto formatado independente)
  insert into public."Usuarios" (
    id, nome, email, cpf, telefone, cargo, data_nascimento, numero_cnh, validade_cnh, foto_url, created_at, updated_at
  ) values
  (
    v_admin_id, 'Carlos Henrique', 'admin@nutriguard.com', '123.456.789-00', '(11) 98765-4321',
    'admin', '1988-04-12', '12345678900', '2030-12-31',
    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150', now() - interval '60 days', now()
  ),
  (
    v_gerente1_id, 'Mariana Silveira', 'gerente.sul@nutriguard.com', '234.567.890-11', '(41) 99876-5432',
    'gerente', '1990-08-23', '23456789011', '2028-10-15',
    'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=150', now() - interval '45 days', now()
  ),
  (
    v_gerente2_id, 'Roberto Costa', 'gerente.sudeste@nutriguard.com', '345.678.901-22', '(19) 98123-4567',
    'gerente', '1985-02-17', '34567890122', '2027-05-20',
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150', now() - interval '40 days', now()
  ),
  (
    v_operador1_id, 'Lucas Mendes', 'operador.lucas@nutriguard.com', '456.789.012-33', '(11) 97654-3210',
    'operador', '1995-11-05', '45678901233', '2029-08-10',
    'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150', now() - interval '30 days', now()
  ),
  (
    v_operador2_id, 'Juliana Oliveira', 'operadora.juliana@nutriguard.com', '567.890.123-44', '(41) 99123-8877',
    'operador', '1997-03-30', '56789012344', '2031-01-25',
    'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150', now() - interval '25 days', now()
  )
  on conflict (id) do update set
    nome = excluded.nome, cargo = excluded.cargo, cpf = excluded.cpf,
    telefone = excluded.telefone, data_nascimento = excluded.data_nascimento,
    numero_cnh = excluded.numero_cnh, validade_cnh = excluded.validade_cnh,
    foto_url = excluded.foto_url, updated_at = now();

  update public."Usuarios" set cargo = 'admin' where cargo is null or cargo = '';

  -- 4.3. Frotas (id_gerente -> Usuarios.id)
  insert into public."Frotas" (id, nome, id_gerente, created_at, updated_at)
  values
    (v_frota_sul_id, 'Frota Sul - Refrigerados Lácteos', v_gerente1_id, now() - interval '60 days', now()),
    (v_frota_sudeste_id, 'Frota Sudeste - Cargas Congeladas', v_gerente2_id, now() - interval '45 days', now()),
    (v_frota_urbana_id, 'Frota Urbana - Distribuição e Medicamentos', v_gerente2_id, now() - interval '30 days', now());

  -- 4.4. Dispositivos (sensibilidade_vibracao e limite_vibracao como int8 inteiros)
  insert into public."Dispositivos" (
    id, id_frota, id_operador, nome_dispositivo, numero_serie, modelo_dispositivo,
    modelo_veiculo, placa_veiculo, temperatura_minima, temperatura_maxima,
    umidade_minima, umidade_maxima, sensibilidade_vibracao, limite_vibracao,
    intervalo_dados, bateria_minima, created_at, updated_at
  ) values
    (
      v_disp1_id, v_frota_sul_id, v_operador1_id,
      'Sensor IoT TermoGuard #01', 'TG-SUL-4019', 'NutriSensor Pro v2',
      'Mercedes-Benz Sprinter 416 CDI', 'BRA-2E19', 2.0, 6.0, 30.0, 50.0,
      2, 2, 30.0, 20.0, now() - interval '30 days', now()
    ),
    (
      v_disp2_id, v_frota_sul_id, v_operador2_id,
      'Sensor IoT TermoGuard #02', 'TG-SUL-4020', 'NutriSensor Pro v2',
      'Volkswagen Delivery 11.180', 'SUL-8K42', 2.0, 6.0, 30.0, 50.0,
      2, 2, 30.0, 20.0, now() - interval '25 days', now()
    ),
    (
      v_disp3_id, v_frota_sudeste_id, v_operador1_id,
      'Sensor IoT TermoGuard #03', 'TG-SUD-9011', 'NutriSensor Cryo v3',
      'Volvo FH 540 Globetrotter', 'RIO-4A20', -18.0, -12.0, 20.0, 40.0,
      3, 3, 15.0, 25.0, now() - interval '20 days', now()
    ),
    (
      v_disp4_id, v_frota_urbana_id, v_operador2_id,
      'Sensor IoT TermoGuard #04', 'TG-URB-1104', 'NutriSensor Pharma v1',
      'Iveco Daily 35S15', 'SPK-9F33', 2.0, 8.0, 35.0, 55.0,
      1, 2, 30.0, 20.0, now() - interval '15 days', now()
    );

  -- 4.5. Credenciais dos Sensores IoT
  insert into public.dispositivo_credenciais (id_dispositivo, token_hash, created_at)
  values
    (v_disp1_id, encode(digest('token_iot_disp_01_secret', 'sha256'), 'hex'), now() - interval '30 days'),
    (v_disp2_id, encode(digest('token_iot_disp_02_secret', 'sha256'), 'hex'), now() - interval '25 days'),
    (v_disp3_id, encode(digest('token_iot_disp_03_secret', 'sha256'), 'hex'), now() - interval '20 days'),
    (v_disp4_id, encode(digest('token_iot_disp_04_secret', 'sha256'), 'hex'), now() - interval '15 days');

  -- 4.6. Medições de Telemetria (medicoes)
  insert into public."medicoes" (
    id, id_dispositivo, temperatura, umidade, vibracao, porta_aberta,
    latitude, longitude, bateria, registrado_em
  ) values
    -- Histórico Sprinter (BRA-2E19)
    (gen_random_uuid(), v_disp1_id, 4.2, 36.0, 0.22, false, -23.5505, -46.6333, 98.0, now() - interval '6 hours'),
    (gen_random_uuid(), v_disp1_id, 4.5, 35.5, 0.28, false, -23.5560, -46.6380, 96.0, now() - interval '5 hours'),
    (gen_random_uuid(), v_disp1_id, 4.8, 38.0, 0.35, false, -23.5650, -46.6450, 95.0, now() - interval '4 hours'),
    (gen_random_uuid(), v_disp1_id, 5.1, 39.0, 0.42, false, -23.5800, -46.6600, 93.0, now() - interval '3 hours'),
    (gen_random_uuid(), v_disp1_id, 5.6, 41.0, 0.38, false, -23.6000, -46.6800, 90.0, now() - interval '2 hours'),
    (v_med1_alerta_temp, v_disp1_id, 6.4, 44.0, 0.55, true,  -23.6200, -46.7000, 88.0, now() - interval '1 hour'),
    (v_med1_alerta_porta, v_disp1_id, 5.8, 39.0, 0.31, true, -23.6300, -46.7100, 86.0, now() - interval '55 minutes'),
    (gen_random_uuid(), v_disp1_id, 4.9, 36.5, 0.25, false, -23.6400, -46.7150, 85.0, now() - interval '5 minutes'),

    -- Histórico Delivery (SUL-8K42)
    (gen_random_uuid(), v_disp2_id, 3.8, 34.0, 0.20, false, -25.4284, -49.2733, 94.0, now() - interval '4 hours'),
    (gen_random_uuid(), v_disp2_id, 4.0, 35.0, 0.24, false, -25.4400, -49.2800, 92.0, now() - interval '3 hours'),
    (v_med2_alerta_vib,  v_disp2_id, 4.2, 33.0, 1.85, false, -25.4600, -49.3000, 90.0, now() - interval '1 hour'),
    (gen_random_uuid(), v_disp2_id, 3.9, 32.0, 0.30, false, -25.4800, -49.3100, 88.0, now() - interval '10 minutes'),

    -- Histórico Volvo FH (RIO-4A20 Congelados)
    (gen_random_uuid(), v_disp3_id, -16.5, 25.0, 0.40, false, -22.9068, -43.1729, 99.0, now() - interval '6 hours'),
    (gen_random_uuid(), v_disp3_id, -15.8, 26.0, 0.45, false, -22.8800, -43.2500, 97.0, now() - interval '3 hours'),
    (gen_random_uuid(), v_disp3_id, -15.2, 28.0, 0.38, false, -22.8500, -43.3000, 95.0, now() - interval '15 minutes'),

    -- Histórico Iveco Daily (SPK-9F33 Medicamentos)
    (gen_random_uuid(), v_disp4_id, 5.2, 42.0, 0.18, false, -23.5489, -46.6388, 89.0, now() - interval '2 hours'),
    (v_med4_alerta_bat,  v_disp4_id, 5.5, 43.0, 0.22, false, -23.5600, -46.6500, 19.5, now() - interval '20 minutes');

  -- 4.7. Ocorrências (status 'Resolvido' e 'Pendente' compatíveis com o Flutter)
  insert into public."ocorrencias" (
    id, id_dispositivo, id_medicao, tipo, valor_registrado, limite_configurado, status, criado_em
  ) values
    (
      gen_random_uuid(), v_disp1_id, v_med1_alerta_temp,
      'Alerta Térmico: Temperatura acima do limite máximo', 6.4, 6.0, 'Resolvido', now() - interval '1 hour'
    ),
    (
      gen_random_uuid(), v_disp1_id, v_med1_alerta_porta,
      'Porta aberta detectada por mais de 3 minutos', 1.0, 0.0, 'Resolvido', now() - interval '55 minutes'
    ),
    (
      gen_random_uuid(), v_disp2_id, v_med2_alerta_vib,
      'Pico de vibração em pista irregular (Trecho Serra)', 1.85, 2.00, 'Pendente', now() - interval '1 hour'
    ),
    (
      gen_random_uuid(), v_disp4_id, v_med4_alerta_bat,
      'Sensor IoT com nível de bateria baixo (19.5%)', 19.5, 20.0, 'Pendente', now() - interval '20 minutes'
    );

  -- 4.8. Fins de Viagem / Relatórios de Parada (id_operador -> Usuarios.id, id_dispositivo -> Dispositivos.id)
  insert into public.fins_viagem (
    id, id_operador, id_dispositivo, motivo, rua, bairro, cidade, cep, anexos, criado_em, atualizado_em
  ) values
    (
      gen_random_uuid(), v_operador1_id, v_disp1_id,
      'Entrega finalizada com sucesso no Centro de Distribuição. Lote de laticínios conferido e sem nenhuma violação térmica.',
      'Av. das Nações Unidas, 14401', 'Chácara Santo Antônio', 'São Paulo', '04794-000',
      array['comprovante_entrega_assinado.png', 'termometro_doca.png'], now() - interval '1 day', now() - interval '1 day'
    ),
    (
      gen_random_uuid(), v_operador2_id, v_disp2_id,
      'Pausa regulamentar de descanso e almoço do motorista no posto de serviços da rodovia.',
      'Rodovia Régis Bittencourt, KM 348', 'Zona Rural', 'Miracatu', '11850-000',
      array['foto_patio_graal.png'], now() - interval '3 hours', now() - interval '3 hours'
    );

end $$;

-- ==============================================================================
-- 5. VERIFICAÇÃO RESUMIDA DOS DADOS CARREGADOS
-- ==============================================================================
select
  'RESET E CARGA CONCLUÍDOS COM SUCESSO!' as status,
  (select count(*) from public."Usuarios") as total_usuarios,
  (select count(*) from public."Frotas") as total_frotas,
  (select count(*) from public."Dispositivos") as total_dispositivos,
  (select count(*) from public.dispositivo_credenciais) as total_credenciais,
  (select count(*) from public."medicoes") as total_medicoes,
  (select count(*) from public."ocorrencias") as total_ocorrencias,
  (select count(*) from public.fins_viagem) as total_fins_viagem;
