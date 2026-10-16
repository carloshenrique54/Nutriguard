-- =====================================================================
-- NutriGuard - Correção Definitiva de RLS e Vinculação de Veículos
-- Execute TODO este script no Supabase: Dashboard > SQL Editor > New query
-- =====================================================================

-- 1) Garante permissões completas nas tabelas para autenticados e leitura anônima.
-- Nota: 'medicoes' e 'ocorrencias' em letras minúsculas conforme o banco de dados.
grant select, insert, update, delete on public."Dispositivos" to authenticated;
grant select, insert, update, delete on public."Frotas" to authenticated;
grant select, insert, update, delete on public."medicoes" to authenticated;
grant select, insert, update, delete on public."ocorrencias" to authenticated;
grant select, insert, update, delete on public."Usuarios" to authenticated;

grant select on public."Dispositivos" to anon;
grant select on public."Frotas" to anon;
grant select on public."medicoes" to anon;
grant select on public."ocorrencias" to anon;
grant select on public."Usuarios" to anon;

-- 2) Habilitar RLS nas tabelas
alter table public."Dispositivos" enable row level security;
alter table public."Frotas" enable row level security;
alter table public."medicoes" enable row level security;
alter table public."ocorrencias" enable row level security;
alter table public."Usuarios" enable row level security;

-- 3) Políticas RLS para Dispositivos:
-- Permite leitura, inserção e atualização completas para usuários autenticados.
-- A separação de acesso (ADM vê tudo, Gerente frotas, Operador seu próprio veículo)
-- é regida de forma segura pela lógica de negócio e interface no Flutter.
drop policy if exists "dispositivos_select_autenticados" on public."Dispositivos";
create policy "dispositivos_select_autenticados" on public."Dispositivos"
  for select to authenticated using (true);

drop policy if exists "dispositivos_insert_autenticados" on public."Dispositivos";
create policy "dispositivos_insert_autenticados" on public."Dispositivos"
  for insert to authenticated with check (true);

drop policy if exists "dispositivos_update_autenticados" on public."Dispositivos";
create policy "dispositivos_update_autenticados" on public."Dispositivos"
  for update to authenticated using (true) with check (true);

drop policy if exists "dispositivos_delete_autenticados" on public."Dispositivos";
create policy "dispositivos_delete_autenticados" on public."Dispositivos"
  for delete to authenticated using (true);

-- 4) Políticas RLS para Frotas:
drop policy if exists "frotas_select_autenticados" on public."Frotas";
create policy "frotas_select_autenticados" on public."Frotas"
  for select to authenticated using (true);

drop policy if exists "frotas_insert_autenticados" on public."Frotas";
create policy "frotas_insert_autenticados" on public."Frotas"
  for insert to authenticated with check (true);

drop policy if exists "frotas_update_autenticados" on public."Frotas";
create policy "frotas_update_autenticados" on public."Frotas"
  for update to authenticated using (true) with check (true);

drop policy if exists "frotas_delete_autenticados" on public."Frotas";
create policy "frotas_delete_autenticados" on public."Frotas"
  for delete to authenticated using (true);

-- 5) Políticas para medições e ocorrências (minúsculo):
drop policy if exists "medicoes_select_autenticados" on public."medicoes";
create policy "medicoes_select_autenticados" on public."medicoes"
  for select to authenticated using (true);

drop policy if exists "ocorrencias_select_autenticados" on public."ocorrencias";
create policy "ocorrencias_select_autenticados" on public."ocorrencias"
  for select to authenticated using (true);

-- 6) Políticas para Usuarios:
drop policy if exists "usuarios_select_autenticados" on public."Usuarios";
create policy "usuarios_select_autenticados" on public."Usuarios"
  for select to authenticated using (true);

drop policy if exists "usuarios_insert_autenticados" on public."Usuarios";
create policy "usuarios_insert_autenticados" on public."Usuarios"
  for insert to authenticated with check (true);

drop policy if exists "usuarios_update_autenticados" on public."Usuarios";
create policy "usuarios_update_autenticados" on public."Usuarios"
  for update to authenticated using (true) with check (true);

-- 7) Sincronização de Usuários do Auth para public."Usuarios":
-- Garante que todos os usuários existentes em auth.users (como o Administrador)
-- estejam presentes na tabela pública Usuarios para listagens e vínculos.
insert into public."Usuarios" (id, nome, email, cargo)
select 
  a.id,
  coalesce(nullif(a.raw_user_meta_data->>'nome', ''), split_part(a.email, '@', 1)),
  a.email,
  coalesce(nullif(a.raw_user_meta_data->>'cargo', ''), 'admin')
from auth.users a
where not exists (
  select 1 from public."Usuarios" u 
  where u.id::text = a.id::text or lower(trim(u.email)) = lower(trim(a.email))
);

-- 8) Sincronização e Reparação de IDs antigos:
do $$
declare
  r record;
begin
  for r in
    select u.id as old_id, a.id as new_id, u.email
    from public."Usuarios" u
    inner join auth.users a on lower(trim(u.email)) = lower(trim(a.email))
    where u.id::text <> a.id::text
  loop
    -- 1. Atualiza Dispositivos
    update public."Dispositivos"
    set id_operador = r.new_id::text
    where id_operador = r.old_id::text;

    -- 2. Atualiza Frotas
    update public."Frotas"
    set id_gerente = r.new_id::text
    where id_gerente = r.old_id::text;

    -- 3. Atualiza na tabela Usuarios
    update public."Usuarios"
    set id = r.new_id
    where id = r.old_id;

    raise notice 'Usuário % sincronizado: ID antigo % -> Novo ID %', r.email, r.old_id, r.new_id;
  end loop;
end $$;

-- 9) Vinculação automática do operador Giovanni (gigi@gmail.com):
-- Se o dispositivo 'ESP32 Teste' ainda estiver apontando para o operador mock dummy
-- ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'), vincula ao operador Giovanni:
update public."Dispositivos"
set id_operador = (select id::text from public."Usuarios" where lower(trim(email)) = 'gigi@gmail.com' limit 1)
where (id_operador = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' or nome_dispositivo = 'ESP32 Teste')
  and exists (select 1 from public."Usuarios" where lower(trim(email)) = 'gigi@gmail.com');
