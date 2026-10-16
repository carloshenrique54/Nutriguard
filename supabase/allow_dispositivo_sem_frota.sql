-- =====================================================================
-- NutriGuard - Permitir cadastro de dispositivos sem frota vinculada
-- e desvinculação de veículos ao excluir frotas.
--
-- Execute TODO este script no Supabase: Dashboard > SQL Editor > New query
-- =====================================================================

-- 1. Remove a restrição NOT NULL da coluna id_frota na tabela Dispositivos
alter table public."Dispositivos" alter column id_frota drop not null;
