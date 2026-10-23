-- ==============================================================================
-- NUTRIGUARD - CORREÇÃO COMPLETA DE ERRO 500 ("Database error querying schema")
-- ==============================================================================
-- Execute este script no SQL Editor do Supabase para corrigir auth.users e auth.identities
-- ==============================================================================

-- 1. Garante a extensão pgcrypto
create extension if not exists "pgcrypto";

-- 2. Normaliza TODAS as colunas de tokens e textos em auth.users (evita Scan Error do GoTrue)
update auth.users
set 
  confirmation_token         = coalesce(confirmation_token, ''),
  recovery_token             = coalesce(recovery_token, ''),
  email_change_token_new     = coalesce(email_change_token_new, ''),
  email_change_token_current = coalesce(email_change_token_current, ''),
  email_change               = coalesce(email_change, ''),
  reauthentication_token     = coalesce(reauthentication_token, ''),
  phone_change_token         = coalesce(phone_change_token, ''),
  phone_change               = coalesce(phone_change, ''),
  email_confirmed_at         = coalesce(email_confirmed_at, now()),
  encrypted_password         = crypt('123456', gen_salt('bf'))
where email in (
  'admin@nutriguard.com',
  'gerente.sudeste@nutriguard.com',
  'gerente.sul@nutriguard.com',
  'operador.lucas@nutriguard.com',
  'operadora.juliana@nutriguard.com'
);

-- Também normaliza para qualquer outro usuário existente
update auth.users
set 
  confirmation_token         = coalesce(confirmation_token, ''),
  recovery_token             = coalesce(recovery_token, ''),
  email_change_token_new     = coalesce(email_change_token_new, ''),
  email_change_token_current = coalesce(email_change_token_current, ''),
  email_change               = coalesce(email_change, ''),
  reauthentication_token     = coalesce(reauthentication_token, ''),
  phone_change_token         = coalesce(phone_change_token, ''),
  phone_change               = coalesce(phone_change, '');

-- 3. Cria as identidades faltantes em auth.identities (GoTrue exige para autenticar)
do $$
declare
  v_id_type text;
begin
  select data_type into v_id_type
  from information_schema.columns
  where table_schema = 'auth' and table_name = 'identities' and column_name = 'id';

  if v_id_type = 'uuid' then
    execute '
      insert into auth.identities (
        id, user_id, provider_id, provider, identity_data, last_sign_in_at, created_at, updated_at
      )
      select 
        u.id,
        u.id,
        u.id::text,
        ''email'',
        jsonb_build_object(''sub'', u.id::text, ''email'', u.email),
        now(),
        now(),
        now()
      from auth.users u
      where not exists (select 1 from auth.identities i where i.user_id = u.id)
      on conflict do nothing;
    ';
  else
    execute '
      insert into auth.identities (
        id, user_id, provider_id, provider, identity_data, last_sign_in_at, created_at, updated_at
      )
      select 
        u.id::text,
        u.id,
        u.id::text,
        ''email'',
        jsonb_build_object(''sub'', u.id::text, ''email'', u.email),
        now(),
        now(),
        now()
      from auth.users u
      where not exists (select 1 from auth.identities i where i.user_id = u.id)
      on conflict do nothing;
    ';
  end if;

  -- Atualiza identity_data caso exista alguma linha vazia
  update auth.identities
  set identity_data = jsonb_build_object('sub', user_id::text, 'email', (select email from auth.users where id = auth.identities.user_id))
  where identity_data is null or identity_data = '{}'::jsonb;

end $$;
