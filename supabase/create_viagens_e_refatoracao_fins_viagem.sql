-- ==============================================================================
-- NUTRIGUARD - SUPABASE MIGRATION: TABELA DE VIAGENS E REFATORAÇÃO DE FINS DE VIAGEM
-- ==============================================================================
-- Descrição:
--   1. Cria funções auxiliares de segurança se não existirem (meu_cargo, sou_gerente_da_frota).
--   2. Cria a tabela oficial `public.viagens` referenciando `"Dispositivos"`, `"Usuarios"` e `"Frotas"`.
--   3. Refatora `public.fins_viagem` para incluir `id_viagem` vinculado à viagem.
--   4. Trigger automático que finaliza a viagem e calcula duração ao registrar parada.
--   5. View consolidada `public.view_viagens_completas`.
--   6. Políticas RLS para isolamento seguro por papel (Admin, Gerente, Operador).
--   7. Carga de exemplo demo coerente com veículos parados.
-- ==============================================================================

-- 1. Extensão para UUIDs
create extension if not exists "uuid-ossp";

-- 2. Funções auxiliares para RLS
create or replace function public.meu_cargo()
returns text
language sql
stable
security definer
set search_path = public
as $$
    select coalesce(cargo::text, 'operador') 
    from public."Usuarios" 
    where id::text = auth.uid()::text 
    limit 1;
$$;

create or replace function public.sou_gerente_da_frota(p_frota uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select exists (
        select 1 
        from public."Frotas" 
        where id = p_frota and id_gerente::text = auth.uid()::text
    );
$$;

-- ==============================================================================
-- PARTE 1: TABELA OFICIAL `public.viagens`
-- ==============================================================================

create table if not exists public.viagens (
    id uuid primary key default gen_random_uuid(),
    id_dispositivo uuid not null references public."Dispositivos"(id) on delete cascade,
    id_operador uuid references public."Usuarios"(id) on delete set null,
    id_frota uuid references public."Frotas"(id) on delete set null,
    
    -- Dados da Rota
    origem text default 'Ponto de Partida',
    origem_latitude double precision,
    origem_longitude double precision,
    destino text not null,
    destino_latitude double precision,
    destino_longitude double precision,
    
    -- Estado e Cronologia
    status text not null default 'em_andamento'
        check (status in ('em_andamento', 'finalizada', 'cancelada', 'pausada')),
    iniciado_em timestamptz not null default now(),
    finalizado_em timestamptz,
    duracao_minutos integer,
    
    -- Métricas e Auditoria
    quilometragem_inicial numeric(10, 2),
    quilometragem_final numeric(10, 2),
    distancia_km numeric(10, 2),
    observacoes text,
    
    criado_em timestamptz not null default now(),
    atualizado_em timestamptz not null default now()
);

-- Comentários descritivos
comment on table public.viagens is 'Registro mestre de viagens e rotas executadas pela frota Nutriguard.';
comment on column public.viagens.status is 'Estado da viagem: em_andamento, finalizada, cancelada ou pausada.';
comment on column public.viagens.duracao_minutos is 'Duração total da viagem em minutos (calculado na finalização).';

-- Índices de Performance
create index if not exists idx_viagens_dispositivo on public.viagens(id_dispositivo);
create index if not exists idx_viagens_operador on public.viagens(id_operador);
create index if not exists idx_viagens_frota on public.viagens(id_frota);
create index if not exists idx_viagens_status on public.viagens(status);
create index if not exists idx_viagens_iniciado_em on public.viagens(iniciado_em desc);

-- ==============================================================================
-- PARTE 2: REFATORAÇÃO DA TABELA `public.fins_viagem`
-- ==============================================================================

-- Cria a tabela fins_viagem se ainda não existir
create table if not exists public.fins_viagem (
    id uuid primary key default gen_random_uuid(),
    id_operador uuid references public."Usuarios"(id) on delete set null,
    id_dispositivo uuid references public."Dispositivos"(id) on delete set null,
    motivo text not null,
    rua text not null,
    bairro text,
    cidade text not null,
    cep text,
    anexos text[] default '{}'::text[],
    criado_em timestamptz not null default now(),
    atualizado_em timestamptz not null default now()
);

-- Adiciona coluna id_viagem se não existir
do $$
begin
    if not exists (
        select 1 from information_schema.columns 
        where table_schema = 'public' 
          and table_name = 'fins_viagem' 
          and column_name = 'id_viagem'
    ) then
        alter table public.fins_viagem 
            add column id_viagem uuid references public.viagens(id) on delete cascade;
    end if;
end $$;

-- Índice para relacionamento
create index if not exists idx_fins_viagem_id_viagem on public.fins_viagem(id_viagem);

-- ==============================================================================
-- PARTE 3: TRIGGER DE ENCERRAMENTO AUTOMÁTICO DE VIAGEM
-- ==============================================================================

-- Função disparada quando um formulário de fim de viagem é registrado
create or replace function public.trg_sincronizar_fim_viagem()
returns trigger as $$
declare
    v_viagem_id uuid;
begin
    -- 1. Se id_viagem foi informado, usa diretamente
    if new.id_viagem is not null then
        v_viagem_id := new.id_viagem;
    else
        -- 2. Senão, localiza a viagem mais recente 'em_andamento' do mesmo dispositivo ou operador
        select id into v_viagem_id
        from public.viagens
        where (id_dispositivo = new.id_dispositivo or id_operador = new.id_operador)
          and status = 'em_andamento'
        order by iniciado_em desc
        limit 1;
        
        -- Vincula o id_viagem no registro de fins_viagem
        if v_viagem_id is not null then
            new.id_viagem := v_viagem_id;
        end if;
    end if;

    -- 3. Atualiza a viagem para finalizada calculando a duração
    if v_viagem_id is not null then
        update public.viagens
        set status = 'finalizada',
            finalizado_em = coalesce(new.criado_em, now()),
            duracao_minutos = greatest(1, round(extract(epoch from (coalesce(new.criado_em, now()) - iniciado_em)) / 60)::integer),
            atualizado_em = now()
        where id = v_viagem_id
          and status = 'em_andamento';
    end if;

    return new;
end;
$$ language plpgsql security definer;

-- Trigger disparado antes da inserção em fins_viagem
drop trigger if exists trg_auto_finalizar_viagem on public.fins_viagem;
create trigger trg_auto_finalizar_viagem
before insert on public.fins_viagem
for each row
execute function public.trg_sincronizar_fim_viagem();

-- ==============================================================================
-- PARTE 4: VIEW CONSOLIDADA DE VIAGENS (`view_viagens_completas`)
-- ==============================================================================

create or replace view public.view_viagens_completas as
select
    v.id as id_viagem,
    v.status,
    v.iniciado_em,
    v.finalizado_em,
    v.duracao_minutos,
    v.origem,
    v.destino,
    v.destino_latitude,
    v.destino_longitude,
    
    -- Dados do Dispositivo / Veículo
    d.id as id_dispositivo,
    d.nome_dispositivo,
    d.modelo_veiculo,
    d.placa_veiculo,
    d.numero_serie,
    
    -- Dados da Frota
    f.id as id_frota,
    f.nome as nome_frota,
    
    -- Dados do Operador
    u.id as id_operador,
    u.nome as nome_operador,
    u.email as email_operador,
    
    -- Dados do Fim de Viagem (se houver)
    fv.id as id_fim_viagem,
    fv.motivo as motivo_parada,
    fv.rua as rua_parada,
    fv.bairro as bairro_parada,
    fv.cidade as cidade_parada,
    fv.anexos as anexos_parada
from public.viagens v
left join public."Dispositivos" d on d.id = v.id_dispositivo
left join public."Frotas" f on f.id = coalesce(v.id_frota, d.id_frota)
left join public."Usuarios" u on u.id = coalesce(v.id_operador, d.id_operador)
left join public.fins_viagem fv on fv.id_viagem = v.id;

-- ==============================================================================
-- PARTE 5: ROW LEVEL SECURITY (RLS)
-- ==============================================================================

alter table public.viagens enable row level security;

-- 1. Leitura de Viagens
drop policy if exists "viagens_select_policy" on public.viagens;
create policy "viagens_select_policy"
    on public.viagens
    for select
    to authenticated
    using (
        -- Admins têm acesso irrestrito
        ((select public.meu_cargo()) = 'admin')
        -- Gerente acessa viagens da sua frota
        or (id_frota is not null and public.sou_gerente_da_frota(id_frota))
        -- Operador acessa viagens que ele próprio realizou
        or (id_operador::text = auth.uid()::text)
        -- Fallback seguro para operadores com dispositivo vinculado
        or (exists (
            select 1 from public."Dispositivos" d 
            where d.id = viagens.id_dispositivo and d.id_operador::text = auth.uid()::text
        ))
    );

-- 2. Inserção de Viagens (Operadores e Admins)
drop policy if exists "viagens_insert_policy" on public.viagens;
create policy "viagens_insert_policy"
    on public.viagens
    for insert
    to authenticated
    with check (
        ((select public.meu_cargo()) = 'admin')
        or (id_operador::text = auth.uid()::text)
        or (id_operador is null)
    );

-- 3. Atualização de Viagens (Operador responsável, Gerente ou Admin)
drop policy if exists "viagens_update_policy" on public.viagens;
create policy "viagens_update_policy"
    on public.viagens
    for update
    to authenticated
    using (
        ((select public.meu_cargo()) = 'admin')
        or (id_frota is not null and public.sou_gerente_da_frota(id_frota))
        or (id_operador::text = auth.uid()::text)
    )
    with check (
        ((select public.meu_cargo()) = 'admin')
        or (id_frota is not null and public.sou_gerente_da_frota(id_frota))
        or (id_operador::text = auth.uid()::text)
    );

-- 4. Exclusão de Viagens (Apenas Admins)
drop policy if exists "viagens_delete_policy" on public.viagens;
create policy "viagens_delete_policy"
    on public.viagens
    for delete
    to authenticated
    using (((select public.meu_cargo()) = 'admin'));

-- ==============================================================================
-- PARTE 6: CARGA DEMO DE VIAGENS (Consistente com Veículos Parados / Offline)
-- ==============================================================================

-- Insere viagens históricas finalizadas de exemplo (nenhuma ativa para refletir veículos parados)
do $$
declare
    v_disp1 uuid;
    v_disp2 uuid;
    v_op1 uuid;
    v_op2 uuid;
    v_frota uuid;
begin
    select id into v_disp1 from public."Dispositivos" limit 1;
    select id into v_disp2 from public."Dispositivos" offset 1 limit 1;
    select id into v_op1 from public."Usuarios" where cargo = 'operador' limit 1;
    select id into v_op2 from public."Usuarios" where cargo = 'operador' offset 1 limit 1;
    select id into v_frota from public."Frotas" limit 1;

    if v_disp1 is not null then
        -- Viagem 1 (Finalizada ontem)
        insert into public.viagens (
            id_dispositivo, id_operador, id_frota,
            origem, destino, status,
            iniciado_em, finalizado_em, duracao_minutos,
            observacoes
        ) values (
            v_disp1, v_op1, v_frota,
            'CD Central - São Paulo', 'Campinas - SP', 'finalizada',
            now() - interval '1 day 4 hours', now() - interval '1 day 1 hour', 180,
            'Entrega concluída sem intercorrências'
        );
    end if;

    if v_disp2 is not null then
        -- Viagem 2 (Finalizada hoje cedo)
        insert into public.viagens (
            id_dispositivo, id_operador, id_frota,
            origem, destino, status,
            iniciado_em, finalizado_em, duracao_minutos,
            observacoes
        ) values (
            v_disp2, v_op2, v_frota,
            'Porto de Santos', 'São José dos Campos - SP', 'finalizada',
            now() - interval '8 hours', now() - interval '5 hours', 180,
            'Rota realizada e veículo estacionado no pátio'
        );
    end if;
end $$;
