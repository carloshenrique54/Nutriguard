-- =============================================================================
-- NutriGuard — Remove os dados do teste E2E (empresa "QA Transportes Teste")
-- Executar no SQL Editor do Supabase. APAGA DEFINITIVAMENTE.
--
-- Só age sobre a empresa de teste e sobre contas @nutriguard-teste.com.
-- Aborta sem apagar nada se encontrar na empresa qualquer usuário de outro
-- domínio (proteção contra apagar dados reais).
-- =============================================================================

do $$
declare
  v_empresa uuid;
  v_usuarios uuid[];
  v_disps uuid[];
  n_ocorr int; n_fins int; n_viagens int; n_disp int; n_frotas int; n_auth int; n_med int;
begin
  select id into v_empresa from public."Empresas"
  where id = '16e31a5f-31a9-4491-a60e-9fc3a862a72f';
  if v_empresa is null then
    raise notice 'Empresa de teste não encontrada (já removida?). Removendo só contas @nutriguard-teste.com restantes.';
  end if;

  -- Trava: todos os usuários da empresa precisam ser do domínio de teste.
  if exists (
    select 1 from public."Usuarios"
    where id_empresa = v_empresa and lower(email) not like '%@nutriguard-teste.com'
  ) then
    raise exception 'Abortado: a empresa tem usuários fora de @nutriguard-teste.com. Nada foi apagado.';
  end if;

  select coalesce(array_agg(id), '{}') into v_usuarios
  from auth.users where lower(email) like '%@nutriguard-teste.com';

  select coalesce(array_agg(id), '{}') into v_disps
  from public."Dispositivos" where id_empresa = v_empresa;

  -- Medições são histórico de sensor; o teste não gerou nenhuma. Se houver, apaga também.
  delete from public.medicoes where id_dispositivo = any(v_disps);
  get diagnostics n_med = row_count;

  delete from public.ocorrencias where id_dispositivo = any(v_disps);
  get diagnostics n_ocorr = row_count;

  delete from public.fins_viagem
  where id_dispositivo = any(v_disps) or id_operador = any(v_usuarios);
  get diagnostics n_fins = row_count;

  delete from public.viagens
  where id_dispositivo = any(v_disps) or id_operador = any(v_usuarios);
  get diagnostics n_viagens = row_count;

  delete from public."Dispositivos" where id = any(v_disps);
  get diagnostics n_disp = row_count;

  delete from public."Frotas" where id_empresa = v_empresa;
  get diagnostics n_frotas = row_count;

  -- Contas de login (Usuarios cai em cascata) e convites da empresa.
  delete from auth.users where id = any(v_usuarios);
  get diagnostics n_auth = row_count;
  delete from public."Usuarios" where id = any(v_usuarios) or id_empresa = v_empresa;
  delete from public.convites where id_empresa = v_empresa or lower(email) like '%@nutriguard-teste.com';

  delete from public."Empresas" where id = v_empresa;

  raise notice 'Removidos: % conta(s), % veículo(s), % frota(s), % viagem(ns), % relatório(s) de parada, % alerta(s), % medição(ões), empresa: %',
    n_auth, n_disp, n_frotas, n_viagens, n_fins, n_ocorr, n_med, coalesce(v_empresa::text, '-');
end $$;

-- Conferência: tudo deve dar 0
select
  (select count(*) from auth.users where lower(email) like '%@nutriguard-teste.com') as contas_teste,
  (select count(*) from public."Empresas" where id = '16e31a5f-31a9-4491-a60e-9fc3a862a72f') as empresa_teste,
  (select count(*) from public."Dispositivos" where placa_veiculo in ('QAT1E23', 'QAT2E34')) as veiculos_teste;
