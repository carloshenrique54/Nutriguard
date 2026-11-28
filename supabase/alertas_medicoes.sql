-- =============================================================================
-- NutriGuard — Alertas gerados a partir das medições do ESP32
-- Executar no SQL Editor do Supabase DEPOIS de multiempresa.sql.
-- Pode ser executado de novo sem problemas.
--
-- enviar_medicao (ESP32/Wokwi) grava a medição e devolve as ocorrências ligadas
-- a ela, mas nenhum gatilho as criava: leituras fora do limite não viravam
-- alerta no app. Este gatilho compara cada medição com os limites do veículo.
--
-- Para não gerar um alerta a cada envio (o ESP32 manda a cada 5 s), o alerta
-- só nasce quando a condição COMEÇA: a medição anterior do veículo estava
-- normal para aquele tipo, ou é antiga (mais de 30 min sem leitura).
--
-- Tipos (os mesmos que o app já formata):
--   temperatura_alta / temperatura_baixa  -> fora de temperatura_minima..maxima
--   umidade_alta / umidade_baixa          -> fora de umidade_minima..maxima
--   vibracao_excessiva                    -> acima de limite_vibracao (m/s²)
--   bateria_baixa                         -> abaixo de bateria_minima (%)
--   porta_aberta                          -> porta do baú aberta
-- =============================================================================

create or replace function public.alertas_da_medicao()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  d record;
  ant record;
  ant_recente boolean;
begin
  select temperatura_minima, temperatura_maxima, umidade_minima, umidade_maxima,
         limite_vibracao, bateria_minima
    into d
    from public."Dispositivos" where id = new.id_dispositivo;
  if not found then
    return new;
  end if;

  select temperatura, umidade, vibracao, bateria, porta_aberta, registrado_em
    into ant
    from public.medicoes
   where id_dispositivo = new.id_dispositivo
     and id <> new.id
     and registrado_em <= new.registrado_em
   order by registrado_em desc
   limit 1;
  ant_recente := found and ant.registrado_em > new.registrado_em - interval '30 minutes';

  -- Temperatura
  if new.temperatura is not null and d.temperatura_maxima is not null
     and new.temperatura > d.temperatura_maxima
     and not (ant_recente and ant.temperatura is not null and ant.temperatura > d.temperatura_maxima) then
    insert into public.ocorrencias (id_dispositivo, id_medicao, tipo, valor_registrado, limite_configurado, status)
    values (new.id_dispositivo, new.id, 'temperatura_alta', new.temperatura, d.temperatura_maxima, 'aberta');
  end if;
  if new.temperatura is not null and d.temperatura_minima is not null
     and new.temperatura < d.temperatura_minima
     and not (ant_recente and ant.temperatura is not null and ant.temperatura < d.temperatura_minima) then
    insert into public.ocorrencias (id_dispositivo, id_medicao, tipo, valor_registrado, limite_configurado, status)
    values (new.id_dispositivo, new.id, 'temperatura_baixa', new.temperatura, d.temperatura_minima, 'aberta');
  end if;

  -- Umidade
  if new.umidade is not null and d.umidade_maxima is not null
     and new.umidade > d.umidade_maxima
     and not (ant_recente and ant.umidade is not null and ant.umidade > d.umidade_maxima) then
    insert into public.ocorrencias (id_dispositivo, id_medicao, tipo, valor_registrado, limite_configurado, status)
    values (new.id_dispositivo, new.id, 'umidade_alta', new.umidade, d.umidade_maxima, 'aberta');
  end if;
  if new.umidade is not null and d.umidade_minima is not null
     and new.umidade < d.umidade_minima
     and not (ant_recente and ant.umidade is not null and ant.umidade < d.umidade_minima) then
    insert into public.ocorrencias (id_dispositivo, id_medicao, tipo, valor_registrado, limite_configurado, status)
    values (new.id_dispositivo, new.id, 'umidade_baixa', new.umidade, d.umidade_minima, 'aberta');
  end if;

  -- Vibração
  if new.vibracao is not null and d.limite_vibracao is not null
     and new.vibracao > d.limite_vibracao
     and not (ant_recente and ant.vibracao is not null and ant.vibracao > d.limite_vibracao) then
    insert into public.ocorrencias (id_dispositivo, id_medicao, tipo, valor_registrado, limite_configurado, status)
    values (new.id_dispositivo, new.id, 'vibracao_excessiva', new.vibracao, d.limite_vibracao, 'aberta');
  end if;

  -- Bateria do dispositivo
  if new.bateria is not null and d.bateria_minima is not null
     and new.bateria < d.bateria_minima
     and not (ant_recente and ant.bateria is not null and ant.bateria < d.bateria_minima) then
    insert into public.ocorrencias (id_dispositivo, id_medicao, tipo, valor_registrado, limite_configurado, status)
    values (new.id_dispositivo, new.id, 'bateria_baixa', new.bateria, d.bateria_minima, 'aberta');
  end if;

  -- Porta do baú
  if coalesce(new.porta_aberta, false)
     and not (ant_recente and coalesce(ant.porta_aberta, false)) then
    insert into public.ocorrencias (id_dispositivo, id_medicao, tipo, status)
    values (new.id_dispositivo, new.id, 'porta_aberta', 'aberta');
  end if;

  return new;
end;
$$;

revoke all on function public.alertas_da_medicao() from public, anon, authenticated;

drop trigger if exists trg_alertas_da_medicao on public.medicoes;
create trigger trg_alertas_da_medicao
  after insert on public.medicoes
  for each row execute function public.alertas_da_medicao();

notify pgrst, 'reload schema';

-- Conferência
select tgname from pg_trigger where tgname = 'trg_alertas_da_medicao';
