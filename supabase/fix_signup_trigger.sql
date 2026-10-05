-- =====================================================================
-- NutriGuard - Correção do erro 500 "Database error saving new user"
-- Execute TODO este script no Supabase: Dashboard > SQL Editor > New query
-- =====================================================================

-- 1) Remove QUALQUER trigger customizada em auth.users (a causa do erro 500).
--    Triggers internas do Postgres não são afetadas.
do $$
declare r record;
begin
  for r in
    select tgname from pg_trigger
    where tgrelid = 'auth.users'::regclass and not tgisinternal
  loop
    execute format('drop trigger if exists %I on auth.users', r.tgname);
    raise notice 'Trigger removida: %', r.tgname;
  end loop;
end $$;

-- 2) Campos que o formulário de cadastro NÃO envia não podem ser NOT NULL.
alter table public."Usuarios" alter column data_nascimento drop not null;
alter table public."Usuarios" alter column numero_cnh      drop not null;
alter table public."Usuarios" alter column validade_cnh    drop not null;
alter table public."Usuarios" alter column cpf             drop not null;
alter table public."Usuarios" alter column telefone        drop not null;
alter table public."Usuarios" alter column created_at set default now();
alter table public."Usuarios" alter column updated_at set default now();

-- 3) Função robusta: cria o perfil em public."Usuarios" a partir do metadata
--    enviado pelo app. SECURITY DEFINER ignora RLS; o bloco EXCEPTION garante
--    que uma falha no perfil NUNCA impeça a criação da conta no Auth.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  begin
    insert into public."Usuarios" (id, nome, email, cpf, telefone, cargo, created_at, updated_at)
    values (
      new.id,
      coalesce(nullif(new.raw_user_meta_data->>'nome', ''), split_part(new.email, '@', 1)),
      new.email,
      nullif(new.raw_user_meta_data->>'cpf', ''),
      nullif(new.raw_user_meta_data->>'telefone', ''),
      coalesce(nullif(new.raw_user_meta_data->>'cargo', ''), 'operador'),
      now(),
      now()
    )
    on conflict (id) do update set
      nome       = excluded.nome,
      email      = excluded.email,
      cpf        = coalesce(excluded.cpf, public."Usuarios".cpf),
      telefone   = coalesce(excluded.telefone, public."Usuarios".telefone),
      cargo      = excluded.cargo,
      updated_at = now();
  exception when others then
    raise warning 'handle_new_user: falha ao criar perfil de %: %', new.email, sqlerrm;
  end;
  return new;
end;
$$;

-- 4) Trigger AFTER INSERT (BEFORE INSERT quebraria a FK Usuarios.id -> auth.users.id).
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 5) RLS para acesso direto do app à tabela Usuarios.
alter table public."Usuarios" enable row level security;

drop policy if exists "usuarios_select_autenticados" on public."Usuarios";
create policy "usuarios_select_autenticados" on public."Usuarios"
  for select to authenticated using (true);

drop policy if exists "usuarios_insert_proprio" on public."Usuarios";
create policy "usuarios_insert_proprio" on public."Usuarios"
  for insert to authenticated with check (auth.uid() = id);

drop policy if exists "usuarios_update_proprio" on public."Usuarios";
create policy "usuarios_update_proprio" on public."Usuarios"
  for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);

-- 6) (Opcional) Limpa contas "órfãs" de tentativas anteriores, sem perfil.
-- delete from auth.users u where not exists (select 1 from public."Usuarios" p where p.id = u.id);
