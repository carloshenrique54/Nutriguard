-- ==============================================================================
-- NUTRIGUARD - SCRIPT DE RESET E CARGA COMPLETA DE DADOS (PROTÓTIPO / DEMO)
--
-- Como executar:
--   1. Acesse o Supabase: https://supabase.com/dashboard
--   2. Selecione seu projeto > Navegue até "SQL Editor"
--   3. Cole todo o conteúdo deste arquivo e clique em "Run" (Executar)
--
-- O que este script faz:
--   1. Garante que todas as tabelas (Fins de Viagem, Ocorrências, Medições,
--      Dispositivos, Frotas, Usuários) existam com suas estruturas corretas.
--   2. Limpa dados antigos e resíduos de testes anteriores (TRUNCATE CASCADE).
--   3. Cria 5 usuários de demonstração com senha padrão '123456':
--      - admin@nutriguard.com      (ADM Geral)
--      - gerente.sul@nutriguard.com (Gerente de Logística Sul)
--      - gerente.sudeste@nutriguard.com (Gerente Frigorífico Sudeste)
--      - operador.lucas@nutriguard.com (Operador / Motorista)
--      - operadora.juliana@nutriguard.com (Operadora / Motorista)
--   4. Preserva seu usuário atual do app (se já cadastrado) mantendo-o como ADM.
--   5. Cadastra 3 Frotas temáticas com metas e limites térmicos.
--   6. Cadastra 4 Veículos/Dispositivos IoT com sensores calibrados e placas Mercosul.
--   7. Insere histórico realista de telemetria contínua (temperatura, umidade,
--      vibração, portas, bateria e GPS).
--   8. Insere Alertas/Ocorrências em aberto e resolvidas para os dashboards.
--   9. Insere relatórios de finalização de viagens com motivos e comprovantes.
-- ==============================================================================

-- Habilita extensões necessárias para UUID e criptografia
create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

-- ==============================================================================
-- 1. GARANTIR A TABELA fins_viagem
-- ==============================================================================
create table if not exists public.fins_viagem (
    id uuid primary key default gen_random_uuid(),
    id_operador uuid references auth.users(id) on delete set null,
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

-- Garante bucket de fotos de viagem
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
    'anexos-viagem',
    'anexos-viagem',
    true,
    10485760,
    array['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'application/pdf']
)
on conflict (id) do update set public = true;

-- ==============================================================================
-- 2. LIMPEZA SEGURA DE DADOS ANTERIORES (TRUNCATE DAS OPERAÇÕES)
-- ==============================================================================
truncate table public.fins_viagem cascade;
truncate table public."ocorrencias" cascade;
truncate table public."medicoes" cascade;
truncate table public."Dispositivos" cascade;
truncate table public."Frotas" cascade;

-- ==============================================================================
-- 3. CRIAÇÃO DE USUÁRIOS DE DEMO NO AUTH E EM public."Usuarios"
-- ==============================================================================
do $$
declare
  v_admin_id uuid := '11111111-1111-1111-1111-111111111111';
  v_gerente1_id uuid := '22222222-2222-2222-2222-222222222222';
  v_gerente2_id uuid := '33333333-3333-3333-3333-333333333333';
  v_operador1_id uuid := '44444444-4444-4444-4444-444444444444';
  v_operador2_id uuid := '55555555-5555-5555-5555-555555555555';
  v_senha_hash text := crypt('123456', gen_salt('bf'));
begin
  -- 3.1. Admin Geral
  if exists (select 1 from auth.users where email = 'admin@nutriguard.com') then
    select id into v_admin_id from auth.users where email = 'admin@nutriguard.com';
    update auth.users set encrypted_password = v_senha_hash, raw_user_meta_data = '{"nome":"Carlos Henrique (ADM)","cargo":"admin"}' where id = v_admin_id;
  else
    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at
    ) values (
      '00000000-0000-0000-0000-000000000000', v_admin_id, 'authenticated', 'authenticated',
      'admin@nutriguard.com', v_senha_hash, now(),
      '{"provider":"email","providers":["email"]}',
      '{"nome":"Carlos Henrique (ADM)","cargo":"admin"}',
      now(), now()
    );
  end if;

  -- 3.2. Gerente Sul
  if exists (select 1 from auth.users where email = 'gerente.sul@nutriguard.com') then
    select id into v_gerente1_id from auth.users where email = 'gerente.sul@nutriguard.com';
    update auth.users set encrypted_password = v_senha_hash, raw_user_meta_data = '{"nome":"Mariana Silveira","cargo":"gerente"}' where id = v_gerente1_id;
  else
    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at
    ) values (
      '00000000-0000-0000-0000-000000000000', v_gerente1_id, 'authenticated', 'authenticated',
      'gerente.sul@nutriguard.com', v_senha_hash, now(),
      '{"provider":"email","providers":["email"]}',
      '{"nome":"Mariana Silveira","cargo":"gerente"}',
      now(), now()
    );
  end if;

  -- 3.3. Gerente Sudeste
  if exists (select 1 from auth.users where email = 'gerente.sudeste@nutriguard.com') then
    select id into v_gerente2_id from auth.users where email = 'gerente.sudeste@nutriguard.com';
    update auth.users set encrypted_password = v_senha_hash, raw_user_meta_data = '{"nome":"Roberto Costa","cargo":"gerente"}' where id = v_gerente2_id;
  else
    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at
    ) values (
      '00000000-0000-0000-0000-000000000000', v_gerente2_id, 'authenticated', 'authenticated',
      'gerente.sudeste@nutriguard.com', v_senha_hash, now(),
      '{"provider":"email","providers":["email"]}',
      '{"nome":"Roberto Costa","cargo":"gerente"}',
      now(), now()
    );
  end if;

  -- 3.4. Operador Lucas
  if exists (select 1 from auth.users where email = 'operador.lucas@nutriguard.com') then
    select id into v_operador1_id from auth.users where email = 'operador.lucas@nutriguard.com';
    update auth.users set encrypted_password = v_senha_hash, raw_user_meta_data = '{"nome":"Lucas Mendes","cargo":"operador"}' where id = v_operador1_id;
  else
    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at
    ) values (
      '00000000-0000-0000-0000-000000000000', v_operador1_id, 'authenticated', 'authenticated',
      'operador.lucas@nutriguard.com', v_senha_hash, now(),
      '{"provider":"email","providers":["email"]}',
      '{"nome":"Lucas Mendes","cargo":"operador"}',
      now(), now()
    );
  end if;

  -- 3.5. Operadora Juliana
  if exists (select 1 from auth.users where email = 'operadora.juliana@nutriguard.com') then
    select id into v_operador2_id from auth.users where email = 'operadora.juliana@nutriguard.com';
    update auth.users set encrypted_password = v_senha_hash, raw_user_meta_data = '{"nome":"Juliana Oliveira","cargo":"operador"}' where id = v_operador2_id;
  else
    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at
    ) values (
      '00000000-0000-0000-0000-000000000000', v_operador2_id, 'authenticated', 'authenticated',
      'operadora.juliana@nutriguard.com', v_senha_hash, now(),
      '{"provider":"email","providers":["email"]}',
      '{"nome":"Juliana Oliveira","cargo":"operador"}',
      now(), now()
    );
  end if;

  -- 3.6. Upsert na tabela public."Usuarios" com dados cadastrais completos
  insert into public."Usuarios" (
    id, nome, email, cpf, telefone, cargo, data_nascimento, numero_cnh, validade_cnh, updated_at
  ) values
  (v_admin_id, 'Carlos Henrique', 'admin@nutriguard.com', '123.456.789-00', '(11) 98765-4321', 'admin', '1988-04-12', '12345678900', '2030-12-31', now()),
  (v_gerente1_id, 'Mariana Silveira', 'gerente.sul@nutriguard.com', '234.567.890-11', '(41) 99876-5432', 'gerente', '1990-08-23', '23456789011', '2028-10-15', now()),
  (v_gerente2_id, 'Roberto Costa', 'gerente.sudeste@nutriguard.com', '345.678.901-22', '(19) 98123-4567', 'gerente', '1985-02-17', '34567890122', '2027-05-20', now()),
  (v_operador1_id, 'Lucas Mendes', 'operador.lucas@nutriguard.com', '456.789.012-33', '(11) 97654-3210', 'operador', '1995-11-05', '45678901233', '2029-08-10', now()),
  (v_operador2_id, 'Juliana Oliveira', 'operadora.juliana@nutriguard.com', '567.890.123-44', '(41) 99123-8877', 'operador', '1997-03-30', '56789012344', '2031-01-25', now())
  on conflict (id) do update set
    nome = excluded.nome,
    cargo = excluded.cargo,
    cpf = excluded.cpf,
    telefone = excluded.telefone,
    data_nascimento = excluded.data_nascimento,
    numero_cnh = excluded.numero_cnh,
    validade_cnh = excluded.validade_cnh,
    updated_at = now();

  -- Garante que o usuário atualmente logado (caso exista outro) seja mantido como admin
  update public."Usuarios" set cargo = 'admin' where cargo is null or cargo = '';
end $$;

-- ==============================================================================
-- 4. CADASTRO DE FROTAS
-- ==============================================================================
insert into public."Frotas" (id, nome, id_gerente, created_at, updated_at)
values
  (
    'f0000000-0000-0000-0000-000000000001',
    'Frota Sul - Refrigerados Lácteos',
    '22222222-2222-2222-2222-222222222222', -- Mariana Silveira
    now() - interval '60 days',
    now()
  ),
  (
    'f0000000-0000-0000-0000-000000000002',
    'Frota Sudeste - Cargas Congeladas',
    '33333333-3333-3333-3333-333333333333', -- Roberto Costa
    now() - interval '45 days',
    now()
  ),
  (
    'f0000000-0000-0000-0000-000000000003',
    'Frota Urbana - Distribuição e Medicamentos',
    '33333333-3333-3333-3333-333333333333', -- Roberto Costa
    now() - interval '30 days',
    now()
  );

-- ==============================================================================
-- 5. CADASTRO DE DISPOSITIVOS E VEÍCULOS IOT
-- ==============================================================================
insert into public."Dispositivos" (
  id, id_frota, id_operador, nome_dispositivo, numero_serie, modelo_dispositivo,
  modelo_veiculo, placa_veiculo, temperatura_minima, temperatura_maxima,
  umidade_minima, umidade_maxima, sensibilidade_vibracao, limite_vibracao,
  intervalo_dados, bateria_minima, created_at, updated_at
) values
  -- Veículo 1 (Frota Sul) - Operador Lucas Mendes
  (
    'd0000000-0000-0000-0000-000000000001',
    'f0000000-0000-0000-0000-000000000001',
    '44444444-4444-4444-4444-444444444444',
    'Sensor IoT TermoGuard #01',
    'TG-SUL-4019',
    'NutriSensor Pro v2',
    'Mercedes-Benz Sprinter 416 CDI',
    'BRA-2E19',
    2.0,
    6.0,
    30.0,
    50.0,
    2,
    2,
    30,
    20.0,
    now() - interval '30 days',
    now()
  ),
  -- Veículo 2 (Frota Sul) - Operadora Juliana Oliveira
  (
    'd0000000-0000-0000-0000-000000000002',
    'f0000000-0000-0000-0000-000000000001',
    '55555555-5555-5555-5555-555555555555',
    'Sensor IoT TermoGuard #02',
    'TG-SUL-4020',
    'NutriSensor Pro v2',
    'Volkswagen Delivery 11.180',
    'SUL-8K42',
    2.0,
    6.0,
    30.0,
    50.0,
    2,
    2,
    30,
    20.0,
    now() - interval '25 days',
    now()
  ),
  -- Veículo 3 (Frota Sudeste - Congelados) - Operador Lucas Mendes
  (
    'd0000000-0000-0000-0000-000000000003',
    'f0000000-0000-0000-0000-000000000002',
    '44444444-4444-4444-4444-444444444444',
    'Sensor IoT TermoGuard #03',
    'TG-SUD-9011',
    'NutriSensor Cryo v3',
    'Volvo FH 540 Globetrotter',
    'RIO-4A20',
    -18.0,
    -12.0,
    20.0,
    40.0,
    3,
    3,
    15,
    25.0,
    now() - interval '20 days',
    now()
  ),
  -- Veículo 4 (Frota Urbana - Distribuição) - Operadora Juliana Oliveira
  (
    'd0000000-0000-0000-0000-000000000004',
    'f0000000-0000-0000-0000-000000000003',
    '55555555-5555-5555-5555-555555555555',
    'Sensor IoT TermoGuard #04',
    'TG-URB-1104',
    'NutriSensor Pharma v1',
    'Iveco Daily 35S15',
    'SPK-9F33',
    2.0,
    8.0,
    35.0,
    55.0,
    1,
    2,
    30,
    20.0,
    now() - interval '15 days',
    now()
  );

-- ==============================================================================
-- 6. MEDIÇÕES DE TELEMETRIA HISTÓRICAS E EM TEMPO REAL
-- ==============================================================================
-- Inserindo séries temporais ricas para alimentar os gráficos do app
insert into public."medicoes" (
  id, id_dispositivo, temperatura, umidade, vibracao, porta_aberta,
  latitude, longitude, bateria, registrado_em
) values
  -- Série Veículo 1 (BRA-2E19) - Foco em transporte com pico recente
  (gen_random_uuid(), 'd0000000-0000-0000-0000-000000000001', 4.2, 36.0, 0.22, false, -23.5505, -46.6333, 98.0, now() - interval '6 hours'),
  (gen_random_uuid(), 'd0000000-0000-0000-0000-000000000001', 4.5, 35.5, 0.28, false, -23.5560, -46.6380, 96.0, now() - interval '5 hours'),
  (gen_random_uuid(), 'd0000000-0000-0000-0000-000000000001', 4.8, 38.0, 0.35, false, -23.5650, -46.6450, 95.0, now() - interval '4 hours'),
  (gen_random_uuid(), 'd0000000-0000-0000-0000-000000000001', 5.1, 39.0, 0.42, false, -23.5800, -46.6600, 93.0, now() - interval '3 hours'),
  (gen_random_uuid(), 'd0000000-0000-0000-0000-000000000001', 5.6, 41.0, 0.38, false, -23.6000, -46.6800, 90.0, now() - interval '2 hours'),
  (gen_random_uuid(), 'd0000000-0000-0000-0000-000000000001', 6.4, 44.0, 0.55, true,  -23.6200, -46.7000, 88.0, now() - interval '1 hour'),   -- Porta aberta descarga
  (gen_random_uuid(), 'd0000000-0000-0000-0000-000000000001', 5.8, 39.0, 0.31, false, -23.6300, -46.7100, 86.0, now() - interval '30 minutes'),
  (gen_random_uuid(), 'd0000000-0000-0000-0000-000000000001', 4.9, 36.5, 0.25, false, -23.6400, -46.7150, 85.0, now() - interval '5 minutes'),  -- Leitura atual perfeita

  -- Série Veículo 2 (SUL-8K42)
  (gen_random_uuid(), 'd0000000-0000-0000-0000-000000000002', 3.8, 34.0, 0.20, false, -25.4284, -49.2733, 94.0, now() - interval '4 hours'),
  (gen_random_uuid(), 'd0000000-0000-0000-0000-000000000002', 4.0, 35.0, 0.24, false, -25.4400, -49.2800, 92.0, now() - interval '3 hours'),
  (gen_random_uuid(), 'd0000000-0000-0000-0000-000000000002', 4.2, 33.0, 1.85, false, -25.4600, -49.3000, 90.0, now() - interval '1 hour'),   -- Vibração elevada na serra
  (gen_random_uuid(), 'd0000000-0000-0000-0000-000000000002', 3.9, 32.0, 0.30, false, -25.4800, -49.3100, 88.0, now() - interval '10 minutes'),

  -- Série Veículo 3 (RIO-4A20 - Congelados)
  (gen_random_uuid(), 'd0000000-0000-0000-0000-000000000003', -16.5, 25.0, 0.40, false, -22.9068, -43.1729, 99.0, now() - interval '6 hours'),
  (gen_random_uuid(), 'd0000000-0000-0000-0000-000000000003', -15.8, 26.0, 0.45, false, -22.8800, -43.2500, 97.0, now() - interval '3 hours'),
  (gen_random_uuid(), 'd0000000-0000-0000-0000-000000000003', -15.2, 28.0, 0.38, false, -22.8500, -43.3000, 95.0, now() - interval '15 minutes'),

  -- Série Veículo 4 (SPK-9F33 - Medicamentos Urbana)
  (gen_random_uuid(), 'd0000000-0000-0000-0000-000000000004', 5.2, 42.0, 0.18, false, -23.5489, -46.6388, 89.0, now() - interval '2 hours'),
  (gen_random_uuid(), 'd0000000-0000-0000-0000-000000000004', 5.5, 43.0, 0.22, false, -23.5600, -46.6500, 87.0, now() - interval '20 minutes');

-- ==============================================================================
-- 7. OCORRÊNCIAS E ALERTAS
-- ==============================================================================
insert into public."ocorrencias" (
  id, id_dispositivo, tipo, valor_registrado, limite_configurado, status, criado_em
) values
  -- Alerta 1: Temperatura acima do limite (Crítico)
  (
    gen_random_uuid(),
    'd0000000-0000-0000-0000-000000000001',
    'Alerta Crítico: Temperatura acima do limite máximo',
    6.4,
    6.0,
    'resolvido',
    now() - interval '1 hour'
  ),
  -- Alerta 2: Porta aberta durante trânsito (Advertência)
  (
    gen_random_uuid(),
    'd0000000-0000-0000-0000-000000000001',
    'Porta aberta detectada por mais de 3 minutos',
    1.0,
    0.0,
    'resolvido',
    now() - interval '55 minutes'
  ),
  -- Alerta 3: Pico de Vibração (Pendente / Em monitoramento)
  (
    gen_random_uuid(),
    'd0000000-0000-0000-0000-000000000002',
    'Pico de vibração em pista irregular (Trecho Serra)',
    1.85,
    2.00,
    'pendente',
    now() - interval '1 hour'
  ),
  -- Alerta 4: Manutenção de Bateria do Sensor (Informativo)
  (
    gen_random_uuid(),
    'd0000000-0000-0000-0000-000000000004',
    'Sensor IoT com nível de bateria estável (87%)',
    87.0,
    20.0,
    'resolvido',
    now() - interval '20 minutes'
  );

-- ==============================================================================
-- 8. FINS DE VIAGEM / HISTÓRICO DE PARADAS
-- ==============================================================================
insert into public.fins_viagem (
  id, id_operador, id_dispositivo, motivo, rua, bairro, cidade, cep, anexos, criado_em
) values
  (
    gen_random_uuid(),
    '44444444-4444-4444-4444-444444444444', -- Lucas Mendes
    'd0000000-0000-0000-0000-000000000001',
    'Entrega finalizada com sucesso no Centro de Distribuição. Lote de laticínios conferido e sem nenhuma violação térmica.',
    'Av. das Nações Unidas, 14401',
    'Chácara Santo Antônio',
    'São Paulo',
    '04794-000',
    array['comprovante_entrega_assinado.png', 'termometro_doca.png'],
    now() - interval '1 day'
  ),
  (
    gen_random_uuid(),
    '55555555-5555-5555-5555-555555555555', -- Juliana Oliveira
    'd0000000-0000-0000-0000-000000000002',
    'Pausa regulamentar de descanso e almoço do motorista no posto de serviços da rodovia.',
    'Rodovia Régis Bittencourt, KM 348',
    'Zona Rural',
    'Miracatu',
    '11850-000',
    array['foto_patio_graal.png'],
    now() - interval '3 hours'
  );

-- ==============================================================================
-- 9. MENSAGEM FINAL DE CONFIRMAÇÃO
-- ==============================================================================
select
  'RESET E CARGA CONCLUÍDOS COM SUCESSO!' as resultado,
  (select count(*) from public."Usuarios") as total_usuarios,
  (select count(*) from public."Frotas") as total_frotas,
  (select count(*) from public."Dispositivos") as total_dispositivos,
  (select count(*) from public."medicoes") as total_medicoes,
  (select count(*) from public."ocorrencias") as total_ocorrencias,
  (select count(*) from public.fins_viagem) as total_fins_viagem;
