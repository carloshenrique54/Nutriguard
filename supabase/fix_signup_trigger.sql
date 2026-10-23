-- =====================================================================
-- NutriGuard - Correção do erro 500 "Database error saving new user"
-- Execute TODO este script no Supabase: Dashboard > SQL Editor > New query
-- =====================================================================

-- 1) Garante permissões na tabela Usuarios para os papéis do Supabase.
grant select, insert, update, delete on public."Usuarios" to authenticated;
grant select, insert on public."Usuarios" to anon;

-- 2) Remove QUALQUER trigger customizada anterior em auth.users.
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

-- 3) Campos que o formulário de cadastro não envia não podem ser NOT NULL.
alter table public."Usuarios" alter column data_nascimento drop not null;
alter table public."Usuarios" alter column numero_cnh      drop not null;
alter table public."Usuarios" alter column validade_cnh    drop not null;
alter table public."Usuarios" alter column cpf             drop not null;
alter table public."Usuarios" alter column telefone        drop not null;
alter table public."Usuarios" alter column created_at set default now();
alter table public."Usuarios" alter column updated_at set default now();

-- 4) Função robusta de criação e sincronização em public."Usuarios".
--    SECURITY DEFINER ignora RLS; os blocos de exceção garantem que
--    nenhum conflito (ex: CPF já existente) aborte a transação do Auth.
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
  v_cpf := nullif(new.raw_user_meta_data->>'cpf', '');
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

  begin
    insert into public."Usuarios" (
      id, nome, email, cpf, telefone, cargo,
      data_nascimento, numero_cnh, validade_cnh,
      created_at, updated_at
    )
    values (
      new.id,
      v_nome,
      new.email,
      v_cpf,
      v_telefone,
      v_cargo,
      v_data_nascimento,
      v_numero_cnh,
      v_validade_cnh,
      now(),
      now()
    )
    on conflict (id) do update set
      nome            = excluded.nome,
      email           = excluded.email,
      cpf             = coalesce(excluded.cpf, public."Usuarios".cpf),
      telefone        = coalesce(excluded.telefone, public."Usuarios".telefone),
      cargo           = excluded.cargo,
      data_nascimento = coalesce(excluded.data_nascimento, public."Usuarios".data_nascimento),
      numero_cnh      = coalesce(excluded.numero_cnh, public."Usuarios".numero_cnh),
      validade_cnh    = coalesce(excluded.validade_cnh, public."Usuarios".validade_cnh),
      updated_at      = now();
  exception
    when unique_violation then
      -- Se houver conflito de chave única (ex: CPF), atualiza o registro com o novo ID
      if v_cpf is not null then
        update public."Usuarios"
        set id              = new.id,
            nome            = v_nome,
            email           = new.email,
            telefone        = coalesce(v_telefone, public."Usuarios".telefone),
            cargo           = v_cargo,
            data_nascimento = coalesce(v_data_nascimento, public."Usuarios".data_nascimento),
            numero_cnh      = coalesce(v_numero_cnh, public."Usuarios".numero_cnh),
            validade_cnh    = coalesce(v_validade_cnh, public."Usuarios".validade_cnh),
            updated_at      = now()
        where cpf = v_cpf;
      end if;
    when others then
      raise warning 'handle_new_user: falha ao criar perfil de %: %', new.email, sqlerrm;
  end;

  return new;
end;
$$;

-- 5) Trigger AFTER INSERT em auth.users
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 6) RLS para acesso direto do app à tabela Usuarios.
alter table public."Usuarios" enable row level security;

drop policy if exists "usuarios_select_autenticados" on public."Usuarios";
create policy "usuarios_select_autenticados" on public."Usuarios"
  for select to authenticated using (true);

drop policy if exists "usuarios_insert_proprio" on public."Usuarios";
drop policy if exists "usuarios_insert_autenticados" on public."Usuarios";
create policy "usuarios_insert_autenticados" on public."Usuarios"
  for insert to authenticated with check (
    auth.uid() = id or
    (select cargo from public."Usuarios" where id = auth.uid()) = 'admin'
  );

drop policy if exists "usuarios_update_proprio" on public."Usuarios";
drop policy if exists "usuarios_update_autenticados" on public."Usuarios";
create policy "usuarios_update_autenticados" on public."Usuarios"
  for update to authenticated using (
    auth.uid() = id or
    (select cargo from public."Usuarios" where id = auth.uid()) = 'admin'
  ) with check (
    auth.uid() = id or
    (select cargo from public."Usuarios" where id = auth.uid()) = 'admin'
  );
