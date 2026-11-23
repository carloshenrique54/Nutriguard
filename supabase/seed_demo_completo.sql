-- =============================================================================
-- NutriGuard — Dados de demonstração completos
-- 1 administrador, 10 gerentes (cada um com sua frota), 10 operadores (cada um
-- com um veículo da frota correspondente) e 24h de medições por veículo.
-- Dados fictícios: CPFs com dígitos verificadores válidos, e-mails, telefones e
-- CPFs sem repetição.
--
-- ANTES DE EXECUTAR: troque DIGITE_A_SENHA_AQUI pela senha das contas
-- (mínimo 8 caracteres). Depois de executar, apague a senha do editor.
-- Requer fix_security_critical.sql e unicidade_usuarios.sql já aplicados.
-- =============================================================================
do $seed$
declare
  v_senha text := 'DIGITE_A_SENHA_AQUI';
  v_hash text;
  v_id uuid;
  v_gerente uuid[] := array[]::uuid[];
  v_operador uuid[] := array[]::uuid[];
  v_frota uuid[] := array[]::uuid[];
  v_lat float8[] := array[]::float8[];
  v_lng float8[] := array[]::float8[];
  r record;
  d record;
  i int;
  t timestamptz;
  v_temp numeric;
begin
  if v_senha = 'DIGITE_A_SENHA_AQUI' or length(v_senha) < 8 then
    raise exception 'Troque DIGITE_A_SENHA_AQUI por uma senha de pelo menos 8 caracteres.';
  end if;
  if exists (select 1 from auth.users where email like '%@nutriguard.com') then
    raise exception 'Já existem contas @nutriguard.com. Este script é para um banco limpo.';
  end if;
  v_hash := extensions.crypt(v_senha, extensions.gen_salt('bf'));

  -- Cria conta de login + identidade; o perfil em Usuarios vem da trigger handle_new_user
  create temporary table _contas (ordem serial, id uuid, email text, meta jsonb) on commit drop;

  insert into _contas (id, email, meta) values
    (gen_random_uuid(), 'admin@nutriguard.com', jsonb_build_object('nome', 'Carlos Henrique', 'cargo', 'admin', 'cpf', '104.332.181-00', 'telefone', '(11) 97912-1520'));

  for r in select * from (values
    (1, 'Mariana Silveira', 'gerente.mariana.silveira@nutriguard.com', '013.389.083-08', '(11) 99928-7873'),
    (2, 'Roberto Costa', 'gerente.roberto.costa@nutriguard.com', '379.402.654-31', '(19) 93547-4527'),
    (3, 'Fernanda Ribeiro', 'gerente.fernanda.ribeiro@nutriguard.com', '511.615.594-34', '(21) 91711-8527'),
    (4, 'Paulo Henrique Alves', 'gerente.paulo.alves@nutriguard.com', '816.184.959-50', '(31) 94150-2139'),
    (5, 'Juliana Martins', 'gerente.juliana.martins@nutriguard.com', '034.131.647-40', '(41) 96977-3664'),
    (6, 'Ricardo Nogueira', 'gerente.ricardo.nogueira@nutriguard.com', '553.419.283-69', '(51) 93677-8573'),
    (7, 'Camila Duarte', 'gerente.camila.duarte@nutriguard.com', '648.350.305-91', '(48) 97572-5386'),
    (8, 'André Carvalho', 'gerente.andre.carvalho@nutriguard.com', '139.537.672-75', '(71) 95339-3287'),
    (9, 'Beatriz Lima', 'gerente.beatriz.lima@nutriguard.com', '388.496.965-07', '(81) 94593-3266'),
    (10, 'Gustavo Moreira', 'gerente.gustavo.moreira@nutriguard.com', '871.012.269-90', '(62) 92040-7304')
  ) as g(n, nome, email, cpf, telefone) loop
    v_id := gen_random_uuid();
    v_gerente := v_gerente || v_id;
    insert into _contas (id, email, meta) values
      (v_id, r.email, jsonb_build_object('nome', r.nome, 'cargo', 'gerente', 'cpf', r.cpf, 'telefone', r.telefone));
  end loop;

  for r in select * from (values
    (1, 'Lucas Mendes', 'operador.lucas.mendes@nutriguard.com', '482.814.893-08', '(11) 93504-7126', '1987-10-15', '01845146270', '2031-05-18'),
    (2, 'Juliana Oliveira', 'operador.juliana.oliveira@nutriguard.com', '824.896.383-78', '(19) 96107-7537', '1990-01-04', '03911718227', '2029-05-08'),
    (3, 'Rafael Souza', 'operador.rafael.souza@nutriguard.com', '518.347.382-02', '(21) 98744-4981', '1978-04-08', '98393010310', '2027-06-01'),
    (4, 'Bruna Ferreira', 'operador.bruna.ferreira@nutriguard.com', '262.473.178-40', '(31) 92604-1828', '1988-06-14', '01065133387', '2030-08-28'),
    (5, 'Diego Santos', 'operador.diego.santos@nutriguard.com', '343.098.050-00', '(41) 91821-8811', '1988-08-16', '26064746872', '2028-07-02'),
    (6, 'Larissa Rocha', 'operador.larissa.rocha@nutriguard.com', '998.543.534-60', '(51) 97484-3144', '1980-02-20', '36193990916', '2027-11-28'),
    (7, 'Thiago Pereira', 'operador.thiago.pereira@nutriguard.com', '784.980.841-05', '(48) 93200-5333', '1975-08-20', '83842513542', '2031-02-03'),
    (8, 'Aline Barbosa', 'operador.aline.barbosa@nutriguard.com', '242.786.801-98', '(71) 92232-3442', '1994-04-23', '48740164005', '2029-04-22'),
    (9, 'Marcos Vinícius Cruz', 'operador.marcos.cruz@nutriguard.com', '226.025.634-12', '(81) 93608-2771', '1988-03-02', '05331586923', '2029-06-26'),
    (10, 'Patrícia Gomes', 'operador.patricia.gomes@nutriguard.com', '014.294.019-40', '(62) 98119-6663', '1986-05-27', '36541458685', '2028-04-01')
  ) as o(n, nome, email, cpf, telefone, nasc, cnh, validade) loop
    v_id := gen_random_uuid();
    v_operador := v_operador || v_id;
    insert into _contas (id, email, meta) values
      (v_id, r.email, jsonb_build_object('nome', r.nome, 'cargo', 'operador', 'cpf', r.cpf, 'telefone', r.telefone,
        'data_nascimento', r.nasc, 'numero_cnh', r.cnh, 'validade_cnh', r.validade));
  end loop;

  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, recovery_token, email_change_token_new, email_change_token_current,
    email_change, reauthentication_token, phone_change, phone_change_token
  )
  select '00000000-0000-0000-0000-000000000000', c.id, 'authenticated', 'authenticated', c.email, v_hash, now(),
         '{"provider":"email","providers":["email"]}'::jsonb, c.meta, now() - interval '30 days', now(),
         '', '', '', '', '', '', '', ''
  from _contas c order by c.ordem;

  insert into auth.identities (id, user_id, provider_id, provider, identity_data, last_sign_in_at, created_at, updated_at)
  select gen_random_uuid(), c.id, c.id::text, 'email',
         jsonb_build_object('sub', c.id::text, 'email', c.email, 'email_verified', true),
         now(), now(), now()
  from _contas c;

  -- Frotas: uma por gerente
  for r in select * from (values
    (1, 'Frota Grande São Paulo', -23.5505, -46.6333),
    (2, 'Frota Campinas', -22.9056, -47.0608),
    (3, 'Frota Rio de Janeiro', -22.9068, -43.1729),
    (4, 'Frota Belo Horizonte', -19.9167, -43.9345),
    (5, 'Frota Curitiba', -25.4284, -49.2733),
    (6, 'Frota Porto Alegre', -30.0346, -51.2177),
    (7, 'Frota Florianópolis', -27.5954, -48.548),
    (8, 'Frota Salvador', -12.9777, -38.5016),
    (9, 'Frota Recife', -8.0476, -34.877),
    (10, 'Frota Goiânia', -16.6869, -49.2648)
  ) as f(n, nome, lat, lng) order by n loop
    insert into public."Frotas" (nome, id_gerente) values (r.nome, v_gerente[r.n]) returning id into v_id;
    v_frota := v_frota || v_id;
    v_lat := v_lat || r.lat::float8;
    v_lng := v_lng || r.lng::float8;
  end loop;

  -- Veículos: um por frota, cada um com seu operador
  for r in select * from (values
    (1, 'Veículo 01 — São Paulo', 'NG-2026000', 'NG-ESP32 Cold v2', 'Mercedes-Benz Accelo 1016 (Refrigerado baú)', 'FUT0W51', 2, 8),
    (2, 'Veículo 02 — Campinas', 'NG-2026137', 'NG-ESP32 Cold v2', 'Volkswagen Delivery 11.180 (Refrigerado baú)', 'YXM7T67', 2, 8),
    (3, 'Veículo 03 — Rio de Janeiro', 'NG-2026274', 'NG-ESP32 Cold v3', 'Iveco Daily 35-150 (Furgão isotérmico)', 'SPG1D94', -18, -12),
    (4, 'Veículo 04 — Belo Horizonte', 'NG-2026411', 'NG-ESP32 Cold v3', 'Fiat Ducato Cargo (Furgão refrigerado)', 'XUA1H31', 0, 4),
    (5, 'Veículo 05 — Curitiba', 'NG-2026548', 'NG-ESP32 Track', 'Ford Cargo 816 (Refrigerado baú)', 'TTF0T20', 2, 8),
    (6, 'Veículo 06 — Porto Alegre', 'NG-2026685', 'NG-ESP32 Cold v2', 'Volvo VM 270 (Câmara fria)', 'YXK7L19', -20, -15),
    (7, 'Veículo 07 — Florianópolis', 'NG-2026822', 'NG-ESP32 Cold v3', 'Renault Master (Furgão refrigerado)', 'DDU2J46', 2, 8),
    (8, 'Veículo 08 — Salvador', 'NG-2026959', 'NG-ESP32 Track', 'Scania P 250 (Câmara fria)', 'UBM9U28', -25, -18),
    (9, 'Veículo 09 — Recife', 'NG-2027096', 'NG-ESP32 Cold v2', 'Hyundai HR (Baú isotérmico)', 'NBS3G68', 8, 15),
    (10, 'Veículo 10 — Goiânia', 'NG-2027233', 'NG-ESP32 Cold v3', 'Mercedes-Benz Sprinter (Furgão refrigerado)', 'LPW8D59', 2, 8)
  ) as v(n, nome, serie, modelo_disp, modelo_veic, placa, tmin, tmax) order by n loop
    insert into public."Dispositivos" (
      nome_dispositivo, numero_serie, modelo_dispositivo, modelo_veiculo, placa_veiculo,
      id_frota, id_operador,
      temperatura_minima, temperatura_maxima, umidade_minima, umidade_maxima,
      sensibilidade_vibracao, limite_vibracao, intervalo_dados, bateria_minima
    ) values (
      r.nome, r.serie, r.modelo_disp, r.modelo_veic, r.placa,
      v_frota[r.n], v_operador[r.n],
      r.tmin, r.tmax, 35, 75,
      2, 6, 30, 20
    );
  end loop;

  -- Medições: a cada 30 min nas últimas 24h; o veículo se desloca a partir da
  -- base da frota. Algumas leituras fora do limite geram alertas automaticamente
  -- (trigger gerar_ocorrencias).
  for d in
    select dp.id, dp.temperatura_minima tmin, dp.temperatura_maxima tmax,
           array_position(v_frota, dp.id_frota) n
    from public."Dispositivos" dp
  loop
    for i in 0..47 loop
      t := date_trunc('minute', now()) - make_interval(mins => (47 - i) * 30);
      v_temp := round(((d.tmin + d.tmax) / 2.0 + (random() - 0.5) * (d.tmax - d.tmin) * 0.8)::numeric, 1);
      -- excursão de temperatura em 2 veículos, e porta aberta pontual
      if (d.n in (3, 7) and i between 30 and 32) then v_temp := d.tmax + 3.5; end if;
      insert into public.medicoes (
        id_dispositivo, temperatura, umidade, vibracao, porta_aberta,
        latitude, longitude, bateria, registrado_em
      ) values (
        d.id,
        v_temp,
        round((45 + random() * 20)::numeric, 1),
        round(case when d.n = 5 and i = 40 then 8.2 else random() * 3 end::numeric, 2),
        (d.n = 9 and i = 44),
        round((v_lat[d.n] + 0.004 * i * cos(d.n) + (random() - 0.5) * 0.002)::numeric, 6),
        round((v_lng[d.n] + 0.004 * i * sin(d.n) + (random() - 0.5) * 0.002)::numeric, 6),
        round(greatest(100 - i * 1.3 - (case when d.n = 2 then 25 else 0 end), 5)::numeric, 1),
        t
      );
    end loop;
  end loop;
end $seed$;

-- Conferência
select 'Usuarios' as tabela, count(*) as total, string_agg(distinct cargo, ', ') as detalhe from public."Usuarios"
union all select 'Frotas', count(*), count(id_gerente)::text || ' com gerente' from public."Frotas"
union all select 'Dispositivos', count(*), count(id_operador)::text || ' com operador' from public."Dispositivos"
union all select 'medicoes', count(*), null from public.medicoes
union all select 'ocorrencias', count(*), string_agg(distinct tipo, ', ') from public.ocorrencias;
