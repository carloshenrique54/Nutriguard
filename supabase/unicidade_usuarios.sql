-- =============================================================================
-- NutriGuard — E-mail, CPF e telefone únicos em public."Usuarios"
-- Executar no SQL Editor do Supabase DEPOIS de fix_security_critical.sql.
--
-- A comparação ignora formatação: "123.456.789-00" e "12345678900" são o
-- mesmo CPF; "(11) 98765-4321" e "11987654321" são o mesmo telefone; e-mails
-- são comparados sem diferenciar maiúsculas/minúsculas e espaços.
-- =============================================================================

-- 1) Antes de criar os índices, verifica se já existem repetições.
--    Se houver, o script para e mostra quais são, para você corrigir antes.
do $$
declare
  v_relatorio text;
begin
  select string_agg(format('%s "%s" (%s cadastros: %s)', campo, valor, qtd, emails), E'\n')
    into v_relatorio
  from (
    select 'E-mail' as campo, lower(trim(email)) as valor, count(*) as qtd,
           string_agg(coalesce(nome, id::text), ', ') as emails
    from public."Usuarios"
    where nullif(trim(email), '') is not null
    group by lower(trim(email)) having count(*) > 1
    union all
    select 'CPF', regexp_replace(cpf, '\D', '', 'g'), count(*),
           string_agg(coalesce(email, id::text), ', ')
    from public."Usuarios"
    where regexp_replace(coalesce(cpf, ''), '\D', '', 'g') <> ''
    group by regexp_replace(cpf, '\D', '', 'g') having count(*) > 1
    union all
    select 'Telefone', regexp_replace(telefone, '\D', '', 'g'), count(*),
           string_agg(coalesce(email, id::text), ', ')
    from public."Usuarios"
    where regexp_replace(coalesce(telefone, ''), '\D', '', 'g') <> ''
    group by regexp_replace(telefone, '\D', '', 'g') having count(*) > 1
  ) d;

  if v_relatorio is not null then
    raise exception E'Existem dados repetidos em Usuarios. Corrija-os e execute o script de novo:\n%', v_relatorio;
  end if;
end $$;

-- 2) Índices únicos (o nome do índice indica o campo, usado nas mensagens do app)
create unique index if not exists usuarios_email_unico
  on public."Usuarios" (lower(trim(email)))
  where nullif(trim(email), '') is not null;

create unique index if not exists usuarios_cpf_unico
  on public."Usuarios" (regexp_replace(cpf, '\D', '', 'g'))
  where regexp_replace(coalesce(cpf, ''), '\D', '', 'g') <> '';

create unique index if not exists usuarios_telefone_unico
  on public."Usuarios" (regexp_replace(telefone, '\D', '', 'g'))
  where regexp_replace(coalesce(telefone, ''), '\D', '', 'g') <> '';

-- 3) Verificação usada pelo app ANTES do cadastro, para mostrar uma mensagem
--    clara. Responde apenas se cada dado já está em uso (sem expor de quem),
--    e funciona também na tela de cadastro público (usuário ainda deslogado).
--    Contas no Auth sem perfil também contam para o e-mail.
create or replace function public.verificar_dados_em_uso(
  p_email text default null,
  p_cpf text default null,
  p_telefone text default null,
  p_ignorar_id uuid default null
)
returns table (email_em_uso boolean, cpf_em_uso boolean, telefone_em_uso boolean)
language sql
stable
security definer
set search_path = public
as $$
  select
    nullif(trim(coalesce(p_email, '')), '') is not null and (
      exists (
        select 1 from public."Usuarios" u
        where lower(trim(u.email)) = lower(trim(p_email))
          and (p_ignorar_id is null or u.id <> p_ignorar_id)
      )
      or exists (
        select 1 from auth.users a
        where lower(trim(a.email)) = lower(trim(p_email))
          and (p_ignorar_id is null or a.id <> p_ignorar_id)
      )
    ),
    regexp_replace(coalesce(p_cpf, ''), '\D', '', 'g') <> '' and exists (
      select 1 from public."Usuarios" u
      where regexp_replace(coalesce(u.cpf, ''), '\D', '', 'g') = regexp_replace(p_cpf, '\D', '', 'g')
        and (p_ignorar_id is null or u.id <> p_ignorar_id)
    ),
    regexp_replace(coalesce(p_telefone, ''), '\D', '', 'g') <> '' and exists (
      select 1 from public."Usuarios" u
      where regexp_replace(coalesce(u.telefone, ''), '\D', '', 'g') = regexp_replace(p_telefone, '\D', '', 'g')
        and (p_ignorar_id is null or u.id <> p_ignorar_id)
    );
$$;

revoke all on function public.verificar_dados_em_uso(text, text, text, uuid) from public;
grant execute on function public.verificar_dados_em_uso(text, text, text, uuid) to anon, authenticated;

-- Atualiza o cache do PostgREST para a função aparecer na API imediatamente
notify pgrst, 'reload schema';
