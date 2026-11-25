-- =============================================================================
-- NutriGuard — Dados de demonstração (1 empresa)
-- APAGA TODOS OS DADOS DO BANCO e cria:
--   1 empresa "NutriGuard Logística" com 1 administrador
--   5 gerentes, cada um responsável por uma frota
--   50 operadores (10 por frota), cada um com seu veículo
--   6 a 12 viagens por veículo nos últimos 30 dias, em dias e horários
--   diferentes, com medições a cada 10 min; ~1/3 dos veículos em viagem agora
-- Requer multiempresa.sql já aplicado. Tudo ou nada: se falhar, nada muda.
--
-- ANTES DE EXECUTAR: troque DIGITE_A_SENHA_AQUI (linha abaixo) pela senha das
-- contas (mínimo 8 caracteres). Depois de executar, apague a senha do editor.
-- =============================================================================
do $seed$
declare
  v_senha text := 'DIGITE_A_SENHA_AQUI';
  v_hash text;
  v_empresa uuid;
  v_admin uuid := gen_random_uuid();
  v_token text;
  r record;
begin
  if position('DIGITE_' in v_senha) = 1 or length(v_senha) < 8 then
    raise exception 'Defina a senha (mínimo 8 caracteres) em v_senha antes de executar.';
  end if;
  perform setseed(0.42);
  v_hash := extensions.crypt(v_senha, extensions.gen_salt('bf'));

  -- 1. Limpa tudo
  truncate table public.medicoes, public.ocorrencias, public.fins_viagem, public.viagens,
    public.dispositivo_credenciais, public."Dispositivos", public."Frotas", public.convites,
    public."Usuarios", public."Empresas" cascade;
  delete from auth.users;

  -- 2. Administrador: cadastro sem convite cria a empresa
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, recovery_token, email_change_token_new, email_change_token_current,
    email_change, reauthentication_token, phone_change, phone_change_token
  ) values (
    '00000000-0000-0000-0000-000000000000', v_admin, 'authenticated', 'authenticated',
    'admin@nutriguard.com', v_hash, now() - interval '200 days',
    '{"provider":"email","providers":["email"]}'::jsonb,
    jsonb_build_object('nome', 'Carlos Henrique', 'cpf', '317.784.864-52', 'telefone', '(11) 99980-9223', 'empresa', 'NutriGuard Logística'),
    now() - interval '200 days', now(), '', '', '', '', '', '', '', ''
  );
  select id_empresa into v_empresa from public."Usuarios" where id = v_admin;
  update public."Empresas" set created_at = now() - interval '200 days' where id = v_empresa;

  -- 3. Gerentes e operadores: convite (cargo + empresa) e conta
  create temporary table _g (n int, nome text, email text, cpf text, telefone text, dias int, id uuid default gen_random_uuid()) on commit drop;
  insert into _g (n, nome, email, cpf, telefone, dias) values
    (1, 'Mariana Silveira', 'gerente.mariana.silveira@nutriguard.com', '766.344.002-10', '(11) 98507-9567', 151),
    (2, 'Roberto Costa', 'gerente.roberto.costa@nutriguard.com', '347.787.680-60', '(19) 95752-6188', 149),
    (3, 'Fernanda Ribeiro', 'gerente.fernanda.ribeiro@nutriguard.com', '784.726.714-45', '(41) 99166-7064', 126),
    (4, 'Paulo Henrique Alves', 'gerente.paulo.alves@nutriguard.com', '627.010.798-96', '(31) 92360-4257', 135),
    (5, 'Camila Duarte', 'gerente.camila.duarte@nutriguard.com', '908.452.059-94', '(21) 99060-3209', 154);
  create temporary table _o (n int, frota int, nome text, email text, cpf text, telefone text, nasc text, cnh text, validade text, dias int, id uuid default gen_random_uuid()) on commit drop;
  insert into _o (n, frota, nome, email, cpf, telefone, nasc, cnh, validade, dias) values
    (1, 1, 'Luana Lima', 'operador.luana.lima@nutriguard.com', '836.016.105-40', '(11) 96790-1422', '1987-10-05', '41622948662', '2031-12-17', 8),
    (2, 1, 'Renata Teixeira', 'operador.renata.teixeira@nutriguard.com', '208.073.702-31', '(11) 99682-4583', '1997-03-05', '69579318603', '2031-09-07', 71),
    (3, 1, 'Simone Carvalho', 'operador.simone.carvalho@nutriguard.com', '841.330.175-01', '(11) 97684-9930', '1981-03-12', '76472587718', '2028-05-15', 90),
    (4, 1, 'Vinícius Souza', 'operador.vinicius.souza@nutriguard.com', '210.521.854-79', '(11) 92047-5768', '1991-12-09', '39494821416', '2031-10-24', 45),
    (5, 1, 'Gustavo Araújo', 'operador.gustavo.araujo@nutriguard.com', '397.615.846-15', '(11) 95782-6837', '1975-04-01', '89557990659', '2029-02-04', 12),
    (6, 1, 'Amanda Silva', 'operador.amanda.silva@nutriguard.com', '406.925.666-00', '(11) 94920-7897', '1990-01-18', '01291102859', '2029-04-18', 89),
    (7, 1, 'Bruno Cardoso', 'operador.bruno.cardoso@nutriguard.com', '808.458.500-24', '(11) 94978-8709', '2000-05-26', '04876452912', '2028-04-01', 12),
    (8, 1, 'Fábio Pinto', 'operador.fabio.pinto@nutriguard.com', '586.021.458-88', '(11) 95342-3260', '1982-04-12', '78794326270', '2029-08-21', 96),
    (9, 1, 'Henrique Moura', 'operador.henrique.moura@nutriguard.com', '324.484.526-60', '(11) 94091-1154', '1984-09-17', '81126584409', '2032-11-06', 82),
    (10, 1, 'Diego Reis', 'operador.diego.reis@nutriguard.com', '215.711.649-44', '(11) 95939-2925', '1976-03-01', '05154382993', '2027-09-22', 49),
    (11, 2, 'Daniela Ferreira', 'operador.daniela.ferreira@nutriguard.com', '652.373.556-76', '(19) 97252-4487', '1983-02-03', '44325688557', '2027-08-25', 24),
    (12, 2, 'Priscila Carvalho', 'operador.priscila.carvalho@nutriguard.com', '608.565.178-36', '(19) 99465-4439', '1980-08-09', '43528144976', '2028-09-21', 59),
    (13, 2, 'Juliana Nascimento', 'operador.juliana.nascimento@nutriguard.com', '378.495.183-06', '(19) 99830-1186', '1980-03-11', '67750031450', '2031-11-20', 17),
    (14, 2, 'Renan Nunes', 'operador.renan.nunes@nutriguard.com', '755.559.747-01', '(19) 96358-5097', '1990-07-23', '82104602883', '2031-11-19', 9),
    (15, 2, 'Tatiane Monteiro', 'operador.tatiane.monteiro@nutriguard.com', '957.555.218-08', '(19) 93856-5218', '1988-12-13', '06188479188', '2029-04-19', 72),
    (16, 2, 'Rafael Reis', 'operador.rafael.reis@nutriguard.com', '298.222.900-55', '(19) 95593-5904', '1988-09-05', '47285568983', '2031-04-26', 27),
    (17, 2, 'Wesley Correia', 'operador.wesley.correia@nutriguard.com', '625.280.700-12', '(19) 92550-6783', '1973-03-22', '97804385817', '2028-07-21', 80),
    (18, 2, 'Leonardo Silva', 'operador.leonardo.silva@nutriguard.com', '897.133.115-15', '(19) 93589-2886', '1978-03-08', '35286675347', '2028-11-16', 27),
    (19, 2, 'Letícia Moura', 'operador.leticia.moura@nutriguard.com', '357.699.085-21', '(19) 95175-2291', '1997-05-10', '07874572128', '2032-06-13', 64),
    (20, 2, 'Marcos Araújo', 'operador.marcos.araujo@nutriguard.com', '016.128.400-00', '(19) 92165-9533', '1990-01-03', '16979780252', '2031-08-19', 20),
    (21, 3, 'Felipe Vieira', 'operador.felipe.vieira@nutriguard.com', '678.073.608-28', '(41) 98625-3298', '1979-07-08', '07392731979', '2031-06-14', 42),
    (22, 3, 'Otávio Nascimento', 'operador.otavio.nascimento@nutriguard.com', '033.042.845-40', '(41) 92385-5183', '1977-09-04', '39182761166', '2031-06-26', 26),
    (23, 3, 'Gabriel Cruz', 'operador.gabriel.cruz@nutriguard.com', '074.182.889-80', '(41) 99850-4899', '1998-09-21', '70412143049', '2027-04-21', 68),
    (24, 3, 'Carolina Reis', 'operador.carolina.reis@nutriguard.com', '271.051.298-08', '(41) 94984-8771', '1972-07-13', '92232838564', '2031-02-15', 93),
    (25, 3, 'Igor Carvalho', 'operador.igor.carvalho@nutriguard.com', '349.992.480-34', '(41) 91467-6612', '1974-12-16', '95851904316', '2032-07-22', 99),
    (26, 3, 'Natália Cardoso', 'operador.natalia.cardoso@nutriguard.com', '260.791.135-46', '(41) 98271-2118', '2001-11-16', '09842640794', '2027-02-05', 54),
    (27, 3, 'Elaine Vieira', 'operador.elaine.vieira@nutriguard.com', '629.586.398-19', '(41) 95962-9895', '1999-06-27', '80334635213', '2028-02-20', 73),
    (28, 3, 'Kelly Moura', 'operador.kelly.moura@nutriguard.com', '858.463.884-93', '(41) 99290-6737', '1995-10-27', '69276709409', '2028-05-06', 49),
    (29, 3, 'Bruna Nascimento', 'operador.bruna.nascimento@nutriguard.com', '835.081.113-77', '(41) 97513-3017', '1999-04-18', '01332796726', '2031-07-12', 63),
    (30, 3, 'Michele Nascimento', 'operador.michele.nascimento@nutriguard.com', '153.277.186-03', '(41) 93145-2493', '1975-02-25', '76113875921', '2029-11-05', 7),
    (31, 4, 'Patrícia Nunes', 'operador.patricia.nunes@nutriguard.com', '944.613.516-88', '(31) 92356-5328', '1973-07-06', '48836152029', '2030-11-03', 45),
    (32, 4, 'Yasmin Mendes', 'operador.yasmin.mendes@nutriguard.com', '441.930.399-94', '(31) 96531-6213', '1980-01-18', '74643972584', '2031-05-17', 98),
    (33, 4, 'Larissa Cardoso', 'operador.larissa.cardoso@nutriguard.com', '056.709.048-50', '(31) 99924-1895', '1993-02-12', '95965056547', '2030-11-15', 19),
    (34, 4, 'Lucas Barbosa', 'operador.lucas.barbosa@nutriguard.com', '216.311.119-90', '(31) 97359-1602', '1973-02-08', '59871988904', '2028-01-23', 22),
    (35, 4, 'Vanessa Monteiro', 'operador.vanessa.monteiro@nutriguard.com', '204.126.347-40', '(31) 99582-3469', '2001-01-14', '82960179677', '2029-03-09', 31),
    (36, 4, 'Pedro Santos', 'operador.pedro.santos@nutriguard.com', '181.378.522-80', '(31) 93452-4181', '1984-02-28', '14833541488', '2027-06-19', 75),
    (37, 4, 'Jéssica Ramos', 'operador.jessica.ramos@nutriguard.com', '042.476.134-30', '(31) 93024-5234', '1996-03-12', '92948085347', '2030-02-21', 91),
    (38, 4, 'André Oliveira', 'operador.andre.oliveira@nutriguard.com', '658.930.597-86', '(31) 99005-8027', '1981-07-03', '80053051478', '2028-11-07', 12),
    (39, 4, 'João Lopes', 'operador.joao.lopes@nutriguard.com', '413.633.437-00', '(31) 91146-2986', '1999-02-21', '70907276151', '2032-01-14', 9),
    (40, 4, 'Matheus Nascimento', 'operador.matheus.nascimento@nutriguard.com', '997.453.581-69', '(31) 94187-5390', '1977-05-25', '68631665398', '2030-05-14', 28),
    (41, 5, 'Débora Silva', 'operador.debora.silva@nutriguard.com', '611.410.823-06', '(21) 96335-6203', '1973-05-28', '10475168865', '2032-05-23', 33),
    (42, 5, 'Raquel Freitas', 'operador.raquel.freitas@nutriguard.com', '680.801.000-55', '(21) 96136-3147', '1980-08-17', '82446026195', '2032-12-03', 7),
    (43, 5, 'Murilo Ferreira', 'operador.murilo.ferreira@nutriguard.com', '661.146.351-83', '(21) 92313-1082', '1976-08-07', '70304887781', '2028-01-12', 28),
    (44, 5, 'Rodrigo Lopes', 'operador.rodrigo.lopes@nutriguard.com', '126.708.129-53', '(21) 98360-8774', '1972-01-10', '71671552930', '2028-07-07', 7),
    (45, 5, 'Thiago Correia', 'operador.thiago.correia@nutriguard.com', '299.914.706-62', '(21) 98713-6583', '1999-09-03', '70271861581', '2032-04-07', 45),
    (46, 5, 'Sabrina Carvalho', 'operador.sabrina.carvalho@nutriguard.com', '264.366.282-23', '(21) 91407-3848', '1987-07-26', '59734812417', '2031-03-27', 6),
    (47, 5, 'Viviane Moura', 'operador.viviane.moura@nutriguard.com', '041.517.801-06', '(21) 94822-4785', '1977-09-08', '95060188987', '2030-12-01', 100),
    (48, 5, 'Caio Santos', 'operador.caio.santos@nutriguard.com', '607.002.238-60', '(21) 97628-7432', '1988-03-15', '82196121385', '2030-12-02', 81),
    (49, 5, 'Eduardo Moura', 'operador.eduardo.moura@nutriguard.com', '335.165.850-80', '(21) 97658-9935', '1973-02-07', '00637171124', '2032-06-04', 7),
    (50, 5, 'Aline Silva', 'operador.aline.silva@nutriguard.com', '941.834.190-50', '(21) 99662-3183', '2001-01-05', '21520511482', '2028-06-01', 32);

  insert into public.convites (email, cargo, id_empresa, criado_por, criado_em)
  select email, 'gerente', v_empresa, v_admin, now() - make_interval(days => dias) from _g
  union all
  select email, 'operador', v_empresa, v_admin, now() - make_interval(days => dias) from _o;
  -- convites antigos (dias) ainda precisam valer para a trigger: marca como recentes
  update public.convites set criado_em = now() where usado_em is null;

  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, recovery_token, email_change_token_new, email_change_token_current,
    email_change, reauthentication_token, phone_change, phone_change_token
  )
  select '00000000-0000-0000-0000-000000000000', x.id, 'authenticated', 'authenticated', x.email, v_hash,
         now() - make_interval(days => x.dias),
         '{"provider":"email","providers":["email"]}'::jsonb, x.meta,
         now() - make_interval(days => x.dias) - make_interval(mins => (random() * 600)::int), now(),
         '', '', '', '', '', '', '', ''
  from (
    select id, email, dias, jsonb_build_object('nome', nome, 'cpf', cpf, 'telefone', telefone) meta from _g
    union all
    select id, email, dias, jsonb_build_object('nome', nome, 'cpf', cpf, 'telefone', telefone,
           'data_nascimento', nasc, 'numero_cnh', cnh, 'validade_cnh', validade) from _o
  ) x
  order by x.dias desc;

  insert into auth.identities (id, user_id, provider_id, provider, identity_data, last_sign_in_at, created_at, updated_at)
  select gen_random_uuid(), u.id, u.id::text, 'email',
         jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true),
         now(), u.created_at, now()
  from auth.users u;

  -- 4. Frotas (uma por gerente) e destinos de cada frota
  create temporary table _f (n int, nome text, base text, lat float8, lng float8, dias int, id uuid default gen_random_uuid()) on commit drop;
  insert into _f (n, nome, base, lat, lng, dias) values
    (1, 'Frota Grande São Paulo', 'CD São Paulo (Vila Leopoldina)', -23.5275, -46.73, 133),
    (2, 'Frota Campinas', 'CD Campinas (Viracopos)', -23.0074, -47.1345, 116),
    (3, 'Frota Curitiba', 'CD Curitiba (CIC)', -25.48, -49.345, 122),
    (4, 'Frota Belo Horizonte', 'CD Contagem', -19.932, -44.0539, 117),
    (5, 'Frota Rio de Janeiro', 'CD Duque de Caxias', -22.7856, -43.3117, 124);
  create temporary table _dest (frota int, nome text, lat float8, lng float8) on commit drop;
  insert into _dest values
    (1, 'Santos', -23.9608, -46.3336),
    (1, 'Guarulhos', -23.4543, -46.5337),
    (1, 'São Bernardo do Campo', -23.6914, -46.5646),
    (1, 'Mogi das Cruzes', -23.5208, -46.1854),
    (2, 'Ribeirão Preto', -21.1775, -47.8103),
    (2, 'Piracicaba', -22.7253, -47.6492),
    (2, 'Jundiaí', -23.1857, -46.8978),
    (2, 'Sorocaba', -23.5015, -47.4526),
    (3, 'Ponta Grossa', -25.0945, -50.1633),
    (3, 'Joinville', -26.3045, -48.8487),
    (3, 'Paranaguá', -25.5163, -48.5225),
    (3, 'Londrina', -23.3045, -51.1696),
    (4, 'Juiz de Fora', -21.7642, -43.3496),
    (4, 'Ipatinga', -19.4703, -42.5476),
    (4, 'Sete Lagoas', -19.4658, -44.2468),
    (4, 'Divinópolis', -20.1446, -44.8912),
    (5, 'Niterói', -22.8833, -43.1036),
    (5, 'Petrópolis', -22.505, -43.1786),
    (5, 'Volta Redonda', -22.5231, -44.1042),
    (5, 'Cabo Frio', -22.8894, -42.0286);

  insert into public."Frotas" (id, nome, id_gerente, id_empresa, created_at, updated_at)
  select f.id, f.nome, g.id, v_empresa, now() - make_interval(days => f.dias), now()
  from _f f join _g g on g.n = f.n;

  -- 5. Veículos (um por operador)
  create temporary table _v (n int, frota int, nome text, serie text, modelo_disp text, modelo_veic text, placa text, tmin numeric, tmax numeric, dias int, id uuid default gen_random_uuid()) on commit drop;
  insert into _v (n, frota, nome, serie, modelo_disp, modelo_veic, placa, tmin, tmax, dias) values
    (1, 1, 'Veículo 01 — Grande São Paulo', 'NG-260000', 'NG-ESP32 Cold v3', 'Ford Cargo 816 (Carnes)', 'RLD7R83', -2, 4, 82),
    (2, 1, 'Veículo 02 — Grande São Paulo', 'NG-260037', 'NG-ESP32 Cold v2', 'Iveco Daily 35-150 (Congelados)', 'NJP8P20', -18, -12, 52),
    (3, 1, 'Veículo 03 — Grande São Paulo', 'NG-260074', 'NG-ESP32 Cold v2', 'Volvo VM 270 (Congelados)', 'FMU9U37', -18, -12, 17),
    (4, 1, 'Veículo 04 — Grande São Paulo', 'NG-260111', 'NG-ESP32 Cold v3', 'Ford Cargo 816 (Congelados)', 'CAP4P11', -18, -12, 10),
    (5, 1, 'Veículo 05 — Grande São Paulo', 'NG-260148', 'NG-ESP32 Cold v2', 'Ford Cargo 816 (Congelados)', 'ZLK1K63', -20, -15, 43),
    (6, 1, 'Veículo 06 — Grande São Paulo', 'NG-260185', 'NG-ESP32 Cold v2', 'Iveco Daily 35-150 (Laticínios)', 'UAY8Y81', 0, 4, 53),
    (7, 1, 'Veículo 07 — Grande São Paulo', 'NG-260222', 'NG-ESP32 Track', 'Hyundai HR (Laticínios)', 'ENZ5H81', 0, 4, 38),
    (8, 1, 'Veículo 08 — Grande São Paulo', 'NG-260259', 'NG-ESP32 Cold v2', 'Hyundai HR (Resfriados)', 'GZV4V15', 2, 8, 53),
    (9, 1, 'Veículo 09 — Grande São Paulo', 'NG-260296', 'NG-ESP32 Cold v3', 'Volvo VM 270 (Carnes)', 'UFT0F50', -2, 4, 72),
    (10, 1, 'Veículo 10 — Grande São Paulo', 'NG-260333', 'NG-ESP32 Cold v3', 'Volkswagen Delivery 11.180 (Carnes)', 'UTH5Y68', -2, 4, 77),
    (11, 2, 'Veículo 01 — Campinas', 'NG-260370', 'NG-ESP32 Track', 'Mercedes-Benz Sprinter (Carnes)', 'YEP4L25', -2, 4, 43),
    (12, 2, 'Veículo 02 — Campinas', 'NG-260407', 'NG-ESP32 Track', 'Volvo VM 270 (Vacinas)', 'BNF0J81', 2, 8, 92),
    (13, 2, 'Veículo 03 — Campinas', 'NG-260444', 'NG-ESP32 Cold v3', 'Fiat Ducato Cargo (Congelados)', 'RGW2Z49', -18, -12, 13),
    (14, 2, 'Veículo 04 — Campinas', 'NG-260481', 'NG-ESP32 Cold v2', 'Mercedes-Benz Accelo 1016 (Carnes)', 'SMJ7G57', -2, 4, 38),
    (15, 2, 'Veículo 05 — Campinas', 'NG-260518', 'NG-ESP32 Track', 'Volkswagen Delivery 11.180 (Congelados)', 'WGA7H36', -20, -15, 57),
    (16, 2, 'Veículo 06 — Campinas', 'NG-260555', 'NG-ESP32 Cold v3', 'Hyundai HR (Congelados)', 'ZME7F33', -18, -12, 91),
    (17, 2, 'Veículo 07 — Campinas', 'NG-260592', 'NG-ESP32 Cold v3', 'Mercedes-Benz Accelo 1016 (Hortifrúti)', 'FTG1P94', 8, 15, 58),
    (18, 2, 'Veículo 08 — Campinas', 'NG-260629', 'NG-ESP32 Track', 'Renault Master (Laticínios)', 'GPA8E92', 0, 4, 84),
    (19, 2, 'Veículo 09 — Campinas', 'NG-260666', 'NG-ESP32 Cold v3', 'Hyundai HR (Carnes)', 'TTD4K14', -2, 4, 13),
    (20, 2, 'Veículo 10 — Campinas', 'NG-260703', 'NG-ESP32 Track', 'Iveco Daily 35-150 (Vacinas)', 'KSH5Z69', 2, 8, 91),
    (21, 3, 'Veículo 01 — Curitiba', 'NG-260740', 'NG-ESP32 Track', 'Volvo VM 270 (Laticínios)', 'JPV0M87', 0, 4, 69),
    (22, 3, 'Veículo 02 — Curitiba', 'NG-260777', 'NG-ESP32 Cold v2', 'Hyundai HR (Resfriados)', 'DRU0M98', 2, 8, 62),
    (23, 3, 'Veículo 03 — Curitiba', 'NG-260814', 'NG-ESP32 Track', 'Volvo VM 270 (Resfriados)', 'HUN7C41', 2, 8, 7),
    (24, 3, 'Veículo 04 — Curitiba', 'NG-260851', 'NG-ESP32 Track', 'Volvo VM 270 (Congelados)', 'FSU1E10', -18, -12, 51),
    (25, 3, 'Veículo 05 — Curitiba', 'NG-260888', 'NG-ESP32 Track', 'Scania P 250 (Congelados)', 'VDH7F87', -18, -12, 67),
    (26, 3, 'Veículo 06 — Curitiba', 'NG-260925', 'NG-ESP32 Cold v3', 'Scania P 250 (Hortifrúti)', 'KJR9P70', 8, 15, 40),
    (27, 3, 'Veículo 07 — Curitiba', 'NG-260962', 'NG-ESP32 Track', 'Ford Cargo 816 (Congelados)', 'MRH2T48', -20, -15, 7),
    (28, 3, 'Veículo 08 — Curitiba', 'NG-260999', 'NG-ESP32 Track', 'Fiat Ducato Cargo (Congelados)', 'APT6N89', -20, -15, 49),
    (29, 3, 'Veículo 09 — Curitiba', 'NG-261036', 'NG-ESP32 Track', 'Hyundai HR (Vacinas)', 'XDP3L49', 2, 8, 3),
    (30, 3, 'Veículo 10 — Curitiba', 'NG-261073', 'NG-ESP32 Cold v3', 'Volkswagen Delivery 11.180 (Carnes)', 'RSB7S54', -2, 4, 15),
    (31, 4, 'Veículo 01 — Belo Horizonte', 'NG-261110', 'NG-ESP32 Track', 'Mercedes-Benz Sprinter (Congelados)', 'KHW8F77', -20, -15, 56),
    (32, 4, 'Veículo 02 — Belo Horizonte', 'NG-261147', 'NG-ESP32 Track', 'Volvo VM 270 (Resfriados)', 'NXP9R87', 2, 8, 51),
    (33, 4, 'Veículo 03 — Belo Horizonte', 'NG-261184', 'NG-ESP32 Cold v3', 'Ford Cargo 816 (Vacinas)', 'NKZ4A36', 2, 8, 30),
    (34, 4, 'Veículo 04 — Belo Horizonte', 'NG-261221', 'NG-ESP32 Track', 'Mercedes-Benz Accelo 1016 (Carnes)', 'KPM8Y66', -2, 4, 27),
    (35, 4, 'Veículo 05 — Belo Horizonte', 'NG-261258', 'NG-ESP32 Cold v2', 'Ford Cargo 816 (Vacinas)', 'ADG7N19', 2, 8, 49),
    (36, 4, 'Veículo 06 — Belo Horizonte', 'NG-261295', 'NG-ESP32 Track', 'Volkswagen Delivery 11.180 (Hortifrúti)', 'NJV7M34', 8, 15, 27),
    (37, 4, 'Veículo 07 — Belo Horizonte', 'NG-261332', 'NG-ESP32 Cold v2', 'Scania P 250 (Congelados)', 'LKK2Z16', -20, -15, 11),
    (38, 4, 'Veículo 08 — Belo Horizonte', 'NG-261369', 'NG-ESP32 Cold v3', 'Fiat Ducato Cargo (Vacinas)', 'UJU8M61', 2, 8, 71),
    (39, 4, 'Veículo 09 — Belo Horizonte', 'NG-261406', 'NG-ESP32 Cold v3', 'Iveco Daily 35-150 (Carnes)', 'NXE3Z87', -2, 4, 41),
    (40, 4, 'Veículo 10 — Belo Horizonte', 'NG-261443', 'NG-ESP32 Cold v3', 'Iveco Daily 35-150 (Resfriados)', 'HHK9P69', 2, 8, 61),
    (41, 5, 'Veículo 01 — Rio de Janeiro', 'NG-261480', 'NG-ESP32 Track', 'Ford Cargo 816 (Hortifrúti)', 'AYK2V45', 8, 15, 64),
    (42, 5, 'Veículo 02 — Rio de Janeiro', 'NG-261517', 'NG-ESP32 Cold v3', 'Mercedes-Benz Accelo 1016 (Resfriados)', 'AVD7B35', 2, 8, 79),
    (43, 5, 'Veículo 03 — Rio de Janeiro', 'NG-261554', 'NG-ESP32 Cold v2', 'Hyundai HR (Resfriados)', 'HBB4A90', 2, 8, 29),
    (44, 5, 'Veículo 04 — Rio de Janeiro', 'NG-261591', 'NG-ESP32 Cold v3', 'Mercedes-Benz Sprinter (Vacinas)', 'FVZ9F36', 2, 8, 79),
    (45, 5, 'Veículo 05 — Rio de Janeiro', 'NG-261628', 'NG-ESP32 Track', 'Volvo VM 270 (Hortifrúti)', 'BPN3L22', 8, 15, 53),
    (46, 5, 'Veículo 06 — Rio de Janeiro', 'NG-261665', 'NG-ESP32 Track', 'Ford Cargo 816 (Congelados)', 'EXE0K27', -18, -12, 54),
    (47, 5, 'Veículo 07 — Rio de Janeiro', 'NG-261702', 'NG-ESP32 Cold v3', 'Iveco Daily 35-150 (Congelados)', 'NVM6G92', -18, -12, 63),
    (48, 5, 'Veículo 08 — Rio de Janeiro', 'NG-261739', 'NG-ESP32 Cold v2', 'Ford Cargo 816 (Vacinas)', 'HES4N50', 2, 8, 44),
    (49, 5, 'Veículo 09 — Rio de Janeiro', 'NG-261776', 'NG-ESP32 Cold v3', 'Ford Cargo 816 (Resfriados)', 'GDN1B34', 2, 8, 83),
    (50, 5, 'Veículo 10 — Rio de Janeiro', 'NG-261813', 'NG-ESP32 Track', 'Volkswagen Delivery 11.180 (Congelados)', 'HME1E33', -20, -15, 25);

  insert into public."Dispositivos" (
    id, nome_dispositivo, numero_serie, modelo_dispositivo, modelo_veiculo, placa_veiculo,
    id_frota, id_operador, temperatura_minima, temperatura_maxima, umidade_minima, umidade_maxima,
    sensibilidade_vibracao, limite_vibracao, intervalo_dados, bateria_minima, created_at, updated_at
  )
  select v.id, v.nome, v.serie, v.modelo_disp, v.modelo_veic, v.placa,
         f.id, o.id, v.tmin, v.tmax, 35, 80,
         2, 6, 10, 20, now() - make_interval(days => v.dias), now()
  from _v v join _f f on f.n = v.frota join _o o on o.n = v.n;

  -- 6. Viagens: 6 a 12 por veículo nos últimos 30 dias, sem sobreposição
  create temporary table _trip on commit drop as
  select v.id as id_dispositivo, o.id as id_operador, f.id as id_frota,
         f.base as origem, f.lat as olat, f.lng as olng,
         d.nome as destino, d.lat as dlat, d.lng as dlng,
         date_trunc('minute', now()) - make_interval(days => k * 2 + 1 + (random())::int)
           + make_interval(hours => 4 + (random() * 14)::int, mins => (random() * 59)::int) as inicio,
         (90 + random() * 330)::int as dur_min
  from _v v
  join _f f on f.n = v.frota
  join _o o on o.n = v.n
  cross join lateral generate_series(1, 6 + (random() * 6 + length(v.placa) * 0)::int) k   -- sorteio por veículo
  cross join lateral (select * from _dest where frota = v.frota order by random() + k * 0 + length(v.placa) * 0 limit 1) d;

  insert into public.viagens (
    id_dispositivo, id_operador, id_frota, origem, origem_latitude, origem_longitude,
    destino, destino_latitude, destino_longitude, status, iniciado_em, finalizado_em,
    duracao_minutos, distancia_km, criado_em, atualizado_em
  )
  select id_dispositivo, id_operador, id_frota, origem, olat, olng, destino, dlat, dlng,
         'finalizada', inicio, inicio + make_interval(mins => dur_min), dur_min,
         round((111 * sqrt(power(dlat - olat, 2) + power(dlng - olng, 2)))::numeric, 1),
         inicio, inicio + make_interval(mins => dur_min)
  from _trip;

  -- viagens em andamento agora (1 em cada 3 veículos)
  insert into public.viagens (
    id_dispositivo, id_operador, id_frota, origem, origem_latitude, origem_longitude,
    destino, destino_latitude, destino_longitude, status, iniciado_em, criado_em, atualizado_em
  )
  select v.id, o.id, f.id, f.base, f.lat, f.lng, d.nome, d.lat, d.lng, 'em_andamento',
         date_trunc('minute', now()) - make_interval(mins => 30 + (random() * 270)::int), now(), now()
  from _v v
  join _f f on f.n = v.frota
  join _o o on o.n = v.n
  cross join lateral (select * from _dest where frota = v.frota order by random() + length(v.placa) * 0 limit 1) d
  where v.n % 3 = 1;

  -- 7. Medições a cada 10 min durante as viagens (geram alertas pela trigger)
  insert into public.medicoes (
    id_dispositivo, temperatura, umidade, vibracao, porta_aberta, latitude, longitude, bateria, registrado_em
  )
  select vg.id_dispositivo,
         round((case when random() < 0.015 then dp.temperatura_maxima + 1.5 + random() * 3
                     else (dp.temperatura_minima + dp.temperatura_maxima) / 2.0
                          + (random() - 0.5) * (dp.temperatura_maxima - dp.temperatura_minima) * 0.7 end)::numeric, 1),
         round((45 + random() * 25)::numeric, 1),
         round((case when random() < 0.006 then 6.5 + random() * 3 else random() * 3 end)::numeric, 2),
         (t.passo = 0 and random() < 0.08),
         round((vg.origem_latitude + (vg.destino_latitude - vg.origem_latitude) * t.frac + (random() - 0.5) * 0.004)::numeric, 6),
         round((vg.origem_longitude + (vg.destino_longitude - vg.origem_longitude) * t.frac + (random() - 0.5) * 0.004)::numeric, 6),
         round(greatest(97 - t.frac * 50 - random() * 4, 4)::numeric, 1),
         t.instante
  from public.viagens vg
  join public."Dispositivos" dp on dp.id = vg.id_dispositivo
  cross join lateral (
    select s.instante,
           row_number() over (order by s.instante) - 1 as passo,
           least(extract(epoch from s.instante - vg.iniciado_em)
                 / greatest(extract(epoch from coalesce(vg.finalizado_em, now() + interval '2 hours') - vg.iniciado_em), 1), 1) as frac
    from generate_series(vg.iniciado_em, coalesce(vg.finalizado_em, now()), interval '10 minutes') s(instante)
  ) t;

  -- o alerta recebe o horário da medição que o gerou (a trigger grava now())
  update public.ocorrencias o set criado_em = m.registrado_em
  from public.medicoes m where m.id = o.id_medicao;

  -- alertas antigos já tratados
  update public.ocorrencias set status = 'Resolvido'
  where criado_em < now() - interval '2 days' and random() < 0.75;

  -- 8. Registro de parada para cada viagem encerrada
  insert into public.fins_viagem (id_operador, id_dispositivo, id_viagem, motivo, rua, bairro, cidade, cep, anexos, criado_em, atualizado_em)
  select vg.id_operador, vg.id_dispositivo, vg.id,
         (array['Entrega concluída no cliente', 'Entrega concluída; doca liberada', 'Descarga parcial, retorno ao CD',
                'Entrega concluída com conferência de temperatura', 'Cliente ausente, carga devolvida ao CD'])[1 + (random() * 4)::int],
         (array['Av. Brasil', 'Rua das Indústrias', 'Rod. Anhanguera, km 98', 'Av. Industrial', 'Rua do Comércio'])[1 + (random() * 4)::int]
           || ', ' || (100 + (random() * 2000)::int),
         (array['Centro', 'Distrito Industrial', 'Jardim América', 'Vila Nova'])[1 + (random() * 3)::int],
         vg.destino, null, '{}'::text[], vg.finalizado_em, vg.finalizado_em
  from public.viagens vg
  where vg.status = 'finalizada';

  -- 9. Token do ESP32 do primeiro veículo (para o Wokwi)
  v_token := 'ng_' || encode(extensions.gen_random_bytes(18), 'hex');
  insert into public.dispositivo_credenciais (id_dispositivo, token_hash)
  select id, encode(extensions.digest(v_token, 'sha256'), 'hex') from _v where n = 1;
  create temporary table if not exists _seed_token (veiculo text, token text);
  delete from _seed_token;
  insert into _seed_token select placa || ' — ' || nome, v_token from _v where n = 1;
end $seed$;

-- Conferência e token do ESP32 (copie para o Wokwi; ele não fica salvo em texto)
select 'Empresas' as item, count(*)::text as total from public."Empresas"
union all select 'Usuarios', string_agg(cargo || '=' || n, ', ') from (select cargo, count(*) n from public."Usuarios" group by 1 order by 1) c
union all select 'Frotas (com gerente)', count(*)::text || ' (' || count(id_gerente) || ')' from public."Frotas"
union all select 'Veículos (com operador)', count(*)::text || ' (' || count(id_operador) || ')' from public."Dispositivos"
union all select 'Viagens (em andamento)', count(*)::text || ' (' || count(*) filter (where status = 'em_andamento') || ')' from public.viagens
union all select 'Medições', count(*)::text from public.medicoes
union all select 'Ocorrências (abertas)', count(*)::text || ' (' || count(*) filter (where status is distinct from 'Resolvido') || ')' from public.ocorrencias
union all select 'Paradas registradas', count(*)::text from public.fins_viagem
union all select 'TOKEN ESP32 ' || veiculo, token from _seed_token;
