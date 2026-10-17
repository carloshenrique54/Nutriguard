-- ==============================================================================
-- NUTRIGUARD - SUPABASE MIGRATION: FINS DE VIAGEM, BUCKET & RLS
-- Descrição:
--   1. Cria a tabela `fins_viagem` para armazenar o formulário de encerramento
--      preenchido pelo operador (motivo, endereço completo, anexos).
--   2. Cria o bucket de armazenamento `anexos-viagem` no Supabase Storage.
--   3. Configura todas as políticas de Row Level Security (RLS) para tabela e Storage.
-- ==============================================================================

-- 1. Habilita extensões necessárias
create extension if not exists "uuid-ossp";

-- ==============================================================================
-- PARTE 1: TABELA fins_viagem
-- ==============================================================================

create table if not exists public.fins_viagem (
    id uuid primary key default gen_random_uuid(),
    id_operador uuid references auth.users(id) on delete set null,
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

-- Comentários da tabela e colunas
comment on table public.fins_viagem is 'Registros e justificativas de parada ou encerramento de viagem preenchidos pelos operadores.';
comment on column public.fins_viagem.motivo is 'Descrição detalhada do motivo da parada ou finalização da rota.';
comment on column public.fins_viagem.anexos is 'Lista de nomes ou caminhos/URLs de arquivos anexados (fotos, comprovantes).';

-- Índices para buscas rápidas
create index if not exists idx_fins_viagem_operador on public.fins_viagem(id_operador);
create index if not exists idx_fins_viagem_dispositivo on public.fins_viagem(id_dispositivo);
create index if not exists idx_fins_viagem_criado_em on public.fins_viagem(criado_em desc);

-- ==============================================================================
-- PARTE 2: BUCKET DE STORAGE (anexos-viagem)
-- ==============================================================================

-- Registra o bucket 'anexos-viagem' caso não exista
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
    'anexos-viagem',
    'anexos-viagem',
    true, -- Leitura pública para acesso das fotos nos dashboards e relatórios
    10485760, -- Limite de 10 MB por arquivo
    array['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'application/pdf']
)
on conflict (id) do update set
    public = true,
    file_size_limit = 10485760,
    allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'application/pdf'];

-- ==============================================================================
-- PARTE 3: ROW LEVEL SECURITY (RLS) - TABELA fins_viagem
-- ==============================================================================

alter table public.fins_viagem enable row level security;

-- Política de Leitura (SELECT):
-- - Operadores autenticados podem ver seus próprios fins de viagem.
-- - Usuários com cargo 'gerente' ou 'admin' na tabela Usuarios podem visualizar todos os registros.
drop policy if exists "Permitir leitura de fins de viagem" on public.fins_viagem;
create policy "Permitir leitura de fins de viagem"
    on public.fins_viagem
    for select
    using (
        auth.role() = 'authenticated' and (
            id_operador = auth.uid()
            or exists (
                select 1 from public."Usuarios" u
                where u.id = auth.uid()
                  and u.cargo in ('gerente', 'admin')
            )
        )
    );

-- Política de Inserção (INSERT):
-- - Qualquer operador autenticado pode registrar o fim da sua própria viagem.
drop policy if exists "Permitir insercao pelo operador responsavel" on public.fins_viagem;
create policy "Permitir insercao pelo operador responsavel"
    on public.fins_viagem
    for insert
    with check (
        auth.role() = 'authenticated' and (
            id_operador is null
            or id_operador = auth.uid()
        )
    );

-- Política de Atualização (UPDATE):
-- - O criador do registro ou administradores podem atualizar informações.
drop policy if exists "Permitir atualizacao por criador ou admin" on public.fins_viagem;
create policy "Permitir atualizacao por criador ou admin"
    on public.fins_viagem
    for update
    using (
        auth.role() = 'authenticated' and (
            id_operador = auth.uid()
            or exists (
                select 1 from public."Usuarios" u
                where u.id = auth.uid()
                  and u.cargo = 'admin'
            )
        )
    );

-- Política de Exclusão (DELETE):
-- - Apenas administradores do sistema têm permissão para deletar relatórios de parada.
drop policy if exists "Permitir exclusao apenas por admin" on public.fins_viagem;
create policy "Permitir exclusao apenas por admin"
    on public.fins_viagem
    for delete
    using (
        auth.role() = 'authenticated' and exists (
            select 1 from public."Usuarios" u
            where u.id = auth.uid()
              and u.cargo = 'admin'
        )
    );

-- ==============================================================================
-- PARTE 4: ROW LEVEL SECURITY (RLS) - STORAGE BUCKET (storage.objects)
-- ==============================================================================

-- 1. Leitura: Qualquer pessoa ou usuário autenticado pode ler arquivos do bucket 'anexos-viagem'
drop policy if exists "Leitura publica de anexos de viagem" on storage.objects;
create policy "Leitura publica de anexos de viagem"
    on storage.objects
    for select
    using (bucket_id = 'anexos-viagem');

-- 2. Upload (INSERT): Apenas usuários autenticados podem fazer upload de novos arquivos
drop policy if exists "Upload de anexos por usuarios autenticados" on storage.objects;
create policy "Upload de anexos por usuarios autenticados"
    on storage.objects
    for insert
    with check (
        bucket_id = 'anexos-viagem'
        and auth.role() = 'authenticated'
    );

-- 3. Edição (UPDATE): Apenas o proprietário do arquivo ou administradores
drop policy if exists "Atualizacao de anexos pelo proprietario ou admin" on storage.objects;
create policy "Atualizacao de anexos pelo proprietario ou admin"
    on storage.objects
    for update
    using (
        bucket_id = 'anexos-viagem'
        and (
            auth.uid() = owner
            or exists (
                select 1 from public."Usuarios" u
                where u.id = auth.uid()
                  and u.cargo = 'admin'
            )
        )
    );

-- 4. Exclusão (DELETE): Apenas o proprietário do arquivo ou administradores
drop policy if exists "Exclusao de anexos pelo proprietario ou admin" on storage.objects;
create policy "Exclusao de anexos pelo proprietario ou admin"
    on storage.objects
    for delete
    using (
        bucket_id = 'anexos-viagem'
        and (
            auth.uid() = owner
            or exists (
                select 1 from public."Usuarios" u
                where u.id = auth.uid()
                  and u.cargo = 'admin'
            )
        )
    );
