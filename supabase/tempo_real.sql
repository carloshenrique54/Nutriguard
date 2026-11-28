-- =============================================================================
-- NutriGuard — Atualização em tempo real (Supabase Realtime)
-- Executar no SQL Editor do Supabase. Pode ser executado de novo sem problemas.
--
-- Publica medicoes, ocorrencias e viagens no canal de Realtime: o app recebe na
-- hora a leitura do ESP32/Wokwi, o alerta novo e o início/fim de viagem, sem
-- recarregar a página. O RLS continua valendo: cada usuário só recebe eventos
-- dos veículos que pode ver.
-- =============================================================================

do $$
declare
  t text;
begin
  foreach t in array array['medicoes', 'ocorrencias', 'viagens'] loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;

-- Conferência: as três tabelas devem aparecer
select tablename from pg_publication_tables
where pubname = 'supabase_realtime' and schemaname = 'public'
  and tablename in ('medicoes', 'ocorrencias', 'viagens');
