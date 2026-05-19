-- ============================================================
-- SCHEMA COMPLETO - Formação de Voluntários
-- Supabase SQL Editor
-- ============================================================

-- ------------------------------------------------------------
-- EXTENSÕES
-- ------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- TABELA: leads
-- ============================================================
CREATE TABLE IF NOT EXISTS public.leads (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nome            TEXT NOT NULL CHECK (char_length(nome) BETWEEN 2 AND 150),
    email           TEXT NOT NULL CHECK (email ~* '^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$'),
    telefone        TEXT CHECK (telefone IS NULL OR char_length(telefone) BETWEEN 8 AND 20),
    origem          TEXT NOT NULL DEFAULT 'site'
                         CHECK (origem IN ('site', 'whatsapp', 'indicacao', 'redes_sociais', 'outro')),
    curso_interesse TEXT,
    mensagem        TEXT CHECK (mensagem IS NULL OR char_length(mensagem) <= 1000),
    status          TEXT NOT NULL DEFAULT 'novo'
                         CHECK (status IN ('novo', 'contatado', 'matriculado', 'descartado')),
    ip_address      INET,
    user_agent      TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ------------------------------------------------------------
-- TABELA: usuarios
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.usuarios (
    id              UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    nome            TEXT NOT NULL CHECK (char_length(nome) BETWEEN 2 AND 150),
    email           TEXT NOT NULL UNIQUE CHECK (email ~* '^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$'),
    avatar_url      TEXT CHECK (avatar_url IS NULL OR avatar_url ~* '^https?://'),
    bio             TEXT CHECK (bio IS NULL OR char_length(bio) <= 500),
    role            TEXT NOT NULL DEFAULT 'aluno'
                         CHECK (role IN ('admin', 'instrutor', 'aluno', 'voluntario')),
    ativo           BOOLEAN NOT NULL DEFAULT TRUE,
    telefone        TEXT CHECK (telefone IS NULL OR char_length(telefone) BETWEEN 8 AND 20),
    data_nascimento DATE CHECK (data_nascimento IS NULL OR data_nascimento < CURRENT_DATE),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ------------------------------------------------------------
-- TABELA: posts
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.posts (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    autor_id        UUID NOT NULL REFERENCES public.usuarios(id) ON DELETE RESTRICT,
    titulo          TEXT NOT NULL CHECK (char_length(titulo) BETWEEN 3 AND 255),
    slug            TEXT NOT NULL UNIQUE CHECK (slug ~* '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
    resumo          TEXT CHECK (resumo IS NULL OR char_length(resumo) <= 500),
    conteudo        TEXT NOT NULL CHECK (char_length(conteudo) >= 10),
    capa_url        TEXT CHECK (capa_url IS NULL OR capa_url ~* '^https?://'),
    categoria       TEXT NOT NULL DEFAULT 'geral'
                         CHECK (categoria IN ('geral', 'curso', 'noticia', 'devocional', 'tutorial', 'evento')),
    tags            TEXT[] DEFAULT '{}',
    status          TEXT NOT NULL DEFAULT 'rascunho'
                         CHECK (status IN ('rascunho', 'revisao', 'publicado', 'arquivado')),
    publicado_em    TIMESTAMPTZ,
    visualizacoes   INTEGER NOT NULL DEFAULT 0 CHECK (visualizacoes >= 0),
    destaque        BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    -- Garante que publicado_em seja preenchido quando status = publicado
    CONSTRAINT chk_publicado_em CHECK (
        (status = 'publicado' AND publicado_em IS NOT NULL) OR
        (status <> 'publicado')
    )
);

-- ------------------------------------------------------------
-- TABELA: configuracoes
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.configuracoes (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    chave           TEXT NOT NULL UNIQUE CHECK (char_length(chave) BETWEEN 2 AND 100),
    valor           TEXT,
    descricao       TEXT CHECK (descricao IS NULL OR char_length(descricao) <= 500),
    tipo            TEXT NOT NULL DEFAULT 'texto'
                         CHECK (tipo IN ('texto', 'numero', 'booleano', 'json', 'cor', 'url')),
    publica         BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ------------------------------------------------------------
-- TABELA: arquivos
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.arquivos (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    usuario_id      UUID REFERENCES public.usuarios(id) ON DELETE SET NULL,
    nome_original   TEXT NOT NULL CHECK (char_length(nome_original) BETWEEN 1 AND 255),
    nome_storage    TEXT NOT NULL UNIQUE CHECK (char_length(nome_storage) >= 1),
    bucket          TEXT NOT NULL DEFAULT 'arquivos' CHECK (char_length(bucket) >= 1),
    caminho         TEXT NOT NULL CHECK (char_length(caminho) >= 1),
    url_publica     TEXT CHECK (url_publica IS NULL OR url_publica ~* '^https?://'),
    mime_type       TEXT NOT NULL CHECK (char_length(mime_type) >= 3),
    tamanho_bytes   BIGINT NOT NULL CHECK (tamanho_bytes > 0),
    tipo            TEXT NOT NULL DEFAULT 'documento'
                         CHECK (tipo IN ('imagem', 'video', 'audio', 'documento', 'outro')),
    referencia_tipo TEXT CHECK (referencia_tipo IN ('post', 'usuario', 'curso', 'lead', NULL)),
    referencia_id   UUID,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- ÍNDICES
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_leads_email       ON public.leads(email);
CREATE INDEX IF NOT EXISTS idx_leads_status      ON public.leads(status);
CREATE INDEX IF NOT EXISTS idx_leads_created_at  ON public.leads(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_usuarios_email    ON public.usuarios(email);
CREATE INDEX IF NOT EXISTS idx_usuarios_role     ON public.usuarios(role);

CREATE INDEX IF NOT EXISTS idx_posts_slug        ON public.posts(slug);
CREATE INDEX IF NOT EXISTS idx_posts_status      ON public.posts(status);
CREATE INDEX IF NOT EXISTS idx_posts_autor_id    ON public.posts(autor_id);
CREATE INDEX IF NOT EXISTS idx_posts_publicado   ON public.posts(publicado_em DESC) WHERE status = 'publicado';
CREATE INDEX IF NOT EXISTS idx_posts_categoria   ON public.posts(categoria);

CREATE INDEX IF NOT EXISTS idx_configuracoes_chave ON public.configuracoes(chave);

CREATE INDEX IF NOT EXISTS idx_arquivos_usuario  ON public.arquivos(usuario_id);
CREATE INDEX IF NOT EXISTS idx_arquivos_tipo     ON public.arquivos(tipo);
CREATE INDEX IF NOT EXISTS idx_arquivos_ref      ON public.arquivos(referencia_tipo, referencia_id);

-- ============================================================
-- FUNÇÕES AUXILIARES
-- ============================================================

-- Função genérica para atualizar updated_at
CREATE OR REPLACE FUNCTION public.fn_set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

-- ============================================================
-- FUNÇÃO: handle_new_user
-- Cria registro em public.usuarios ao criar usuário em auth.users
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_nome  TEXT;
    v_role  TEXT;
BEGIN
    -- Extrai nome dos metadados ou usa parte do e-mail
    v_nome := COALESCE(
        NEW.raw_user_meta_data->>'nome',
        NEW.raw_user_meta_data->>'full_name',
        NEW.raw_user_meta_data->>'name',
        split_part(NEW.email, '@', 1)
    );

    -- Extrai role dos metadados ou usa 'aluno' como padrão
    v_role := COALESCE(
        NEW.raw_user_meta_data->>'role',
        'aluno'
    );

    -- Garante que role seja válido
    IF v_role NOT IN ('admin', 'instrutor', 'aluno', 'voluntario') THEN
        v_role := 'aluno';
    END IF;

    INSERT INTO public.usuarios (
        id,
        nome,
        email,
        avatar_url,
        role,
        created_at,
        updated_at
    ) VALUES (
        NEW.id,
        v_nome,
        NEW.email,
        NEW.raw_user_meta_data->>'avatar_url',
        v_role,
        NOW(),
        NOW()
    )
    ON CONFLICT (id) DO NOTHING;

    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        -- Log do erro sem interromper o cadastro
        RAISE WARNING 'handle_new_user error for user %: %', NEW.id, SQLERRM;
        RETURN NEW;
END;
$$;

-- ============================================================
-- FUNÇÃO: set_publicado_em
-- Define publicado_em automaticamente ao publicar post
-- ============================================================
CREATE OR REPLACE FUNCTION public.fn_set_publicado_em()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NEW.status = 'publicado' AND OLD.status <> 'publicado' THEN
        NEW.publicado_em = COALESCE(NEW.publicado_em, NOW());
    END IF;

    IF NEW.status <> 'publicado' THEN
        NEW.publicado_em = NULL;
    END IF;

    RETURN NEW;
END;
$$;

-- ============================================================
-- TRIGGERS
-- ============================================================

-- Trigger: novo usuário auth → public.usuarios
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- Trigger: updated_at em leads
DROP TRIGGER IF EXISTS trg_leads_updated_at ON public.leads;
CREATE TRIGGER trg_leads_updated_at
    BEFORE UPDATE ON public.leads
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_set_updated_at();

-- Trigger: updated_at em usuarios
DROP TRIGGER IF EXISTS trg_usuarios_updated_at ON public.usuarios;
CREATE TRIGGER trg_usuarios_updated_at
    BEFORE UPDATE ON public.usuarios
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_set_updated_at();

-- Trigger: updated_at + publicado_em em posts
DROP TRIGGER IF EXISTS trg_posts_updated_at ON public.posts;
CREATE TRIGGER trg_posts_updated_at
    BEFORE UPDATE ON public.posts
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_posts_publicado_em ON public.posts;
CREATE TRIGGER trg_posts_publicado_em
    BEFORE INSERT OR UPDATE ON public.posts
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_set_publicado_em();

-- Trigger: updated_at em configuracoes
DROP TRIGGER IF EXISTS trg_configuracoes_updated_at ON public.configuracoes;
CREATE TRIGGER trg_configuracoes_updated_at
    BEFORE UPDATE ON public.configuracoes
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_set_updated_at();

-- Trigger: updated_at em arquivos
DROP TRIGGER IF EXISTS trg_arquivos_updated_at ON public.arquivos;
CREATE TRIGGER trg_arquivos_updated_at
    BEFORE UPDATE ON public.arquivos
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_set_updated_at();

-- ============================================================
-- ROW LEVEL SECURITY - HABILITAR
-- ============================================================
ALTER TABLE public.leads          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.usuarios       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.posts          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.configuracoes  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.arquivos       ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- FUNÇÃO AUXILIAR RLS: verifica se usuário é admin
-- ============================================================
CREATE OR REPLACE FUNCTION public.fn_is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.usuarios
        WHERE id = auth.uid()
          AND role = 'admin'
          AND ativo = TRUE
    );
$$;

-- ============================================================
-- POLÍTICAS RLS - leads
-- ============================================================

-- Anônimo e autenticado podem inserir leads
CREATE POLICY "leads_insert_anonimo"
    ON public.leads
    FOR INSERT
    TO anon, authenticated
    WITH CHECK (TRUE);

-- Somente admin pode ler todos os leads
CREATE POLICY "leads_select_admin"
    ON public.leads
    FOR SELECT
    TO authenticated
    USING (public.fn_is_admin());

-- Somente admin pode atualizar leads
CREATE POLICY "leads_update_admin"
    ON public.leads
    FOR UPDATE
    TO authenticated
    USING (public.fn_is_admin())
    WITH CHECK (public.fn_is_admin());

-- Somente admin pode deletar leads
CREATE POLICY "leads_delete_admin"
    ON public.leads
    FOR DELETE
    TO authenticated
    USING (public.fn_is_admin());

-- ============================================================
-- POLÍTICAS RLS - usuarios
-- ============================================================

-- Usuário vê seu próprio perfil
CREATE POLICY "usuarios_select_proprio"
    ON public.usuarios
    FOR SELECT
    TO authenticated
    USING (id = auth.uid());

-- Admin vê todos os usuários
CREATE POLICY "usuarios_select_admin"
    ON public.usuarios
    FOR SELECT
    TO authenticated
    USING (public.fn_is_admin());

-- Usuário atualiza seu próprio perfil
CREATE POLICY "usuarios_update_proprio"
    ON public.usuarios
    FOR UPDATE
    TO authenticated
    USING (id = auth.uid())
    WITH CHECK (
        id = auth.uid()
        -- Impede que o próprio usuário altere seu role
        AND role = (SELECT role FROM public.usuarios WHERE id = auth.uid())
    );

-- Admin atualiza qualquer usuário
CREATE POLICY "usuarios_update_admin"
    ON public.usuarios
    FOR UPDATE
    TO authenticated
    USING (public.fn_is_admin())
    WITH CHECK (public.fn_is_admin());

-- Admin deleta usuários
CREATE POLICY "usuarios_delete_admin"
    ON public.usuarios
    FOR DELETE
    TO authenticated
    USING (public.fn_is_admin());

-- INSERT é feito pelo trigger (service_role), mas permite ao próprio user
CREATE POLICY "usuarios_insert_proprio"
    ON public.usuarios
    FOR INSERT
    TO authenticated
    WITH CHECK (id = auth.uid());

-- ============================================================
-- POLÍTICAS RLS - posts
-- ============================================================

-- Qualquer pessoa (anon + autenticado) lê posts publicados
CREATE POLICY "posts_select_publicado"
    ON public.posts
    FOR SELECT
    TO anon, authenticated
    USING (status = 'publicado');

-- Autor lê seus próprios posts (qualquer status)
CREATE POLICY "posts_select_autor"
    ON public.posts
    FOR SELECT
    TO authenticated
    USING (autor_id = auth.uid());

-- Admin lê todos os posts
CREATE POLICY "posts_select_admin"
    ON public.posts
    FOR SELECT
    TO authenticated
    USING (public.fn_is_admin());

-- Instrutor e admin criam posts
CREATE POLICY "posts_insert_instrutor_admin"
    ON public.posts
    FOR INSERT
    TO authenticated
    WITH CHECK (
        autor_id = auth.uid()
        AND EXISTS (
            SELECT 1 FROM public.usuarios
            WHERE id = auth.uid()
              AND role IN ('admin', 'instrutor')
              AND ativo = TRUE
        )
    );

-- Autor edita seu próprio post
CREATE POLICY "posts_update_autor"
    ON public.posts
    FOR UPDATE
    TO authenticated
    USING (autor_id = auth.uid())
    WITH CHECK (autor_id = auth.uid());

-- Admin edita qualquer post
CREATE POLICY "posts_update_admin"
    ON public.posts
    FOR UPDATE
    TO authenticated
    USING (public.fn_is_admin())
    WITH CHECK (public.fn_is_admin());

-- Admin deleta posts
CREATE POLICY "posts_delete_admin"
    ON public.posts
    FOR DELETE
    TO authenticated
    USING (public.fn_is_admin());

-- ============================================================
-- POLÍTICAS RLS - configuracoes
-- ============================================================

-- Qualquer um lê configurações públicas
CREATE POLICY "configuracoes_select_publico"
    ON public.configuracoes
    FOR SELECT
    TO anon, authenticated
    USING (publica = TRUE);

-- Admin lê todas as configurações
CREATE POLICY "configuracoes_select_admin"
    ON public.configuracoes
    FOR SELECT
    TO authenticated
    USING (public.fn_is_admin());

-- Admin insere configurações
CREATE POLICY "configuracoes_insert_admin"
    ON public.configuracoes
    FOR INSERT
    TO authenticated
    WITH CHECK (public.fn_is_admin());

-- Admin atualiza configurações
CREATE POLICY "configuracoes_update_admin"
    ON public.configuracoes
    FOR UPDATE
    TO authenticated
    USING (public.fn_is_admin())
    WITH CHECK (public.fn_is_admin());

-- Admin deleta configurações
CREATE POLICY "configuracoes_delete_admin"
    ON public.configuracoes
    FOR DELETE
    TO authenticated
    USING (public.fn_is_admin());

-- ============================================================
-- POLÍTICAS RLS - arquivos
-- ============================================================

-- Qualquer um vê arquivos com URL pública
CREATE POLICY "arquivos_select_publico"
    ON public.arquivos
    FOR SELECT
    TO anon, authenticated
    USING (url_publica IS NOT NULL);

-- Usuário vê seus próprios arquivos
CREATE POLICY "arquivos_select_proprio"
    ON public.arquivos
    FOR SELECT
    TO authenticated
    USING (usuario_id = auth.uid());

-- Admin vê todos os arquivos
CREATE POLICY "arquivos_select_admin"
    ON public.arquivos
    FOR SELECT
    TO authenticated
    USING (public.fn_is_admin());

-- Usuário autenticado faz upload (insert)
CREATE POLICY "arquivos_insert_autenticado"
    ON public.arquivos
    FOR INSERT
    TO authenticated
    WITH CHECK (usuario_id = auth.uid());

-- Usuário deleta seus próprios arquivos
CREATE POLICY "arquivos_delete_proprio"
    ON public.arquivos
    FOR DELETE
    TO authenticated
    USING (usuario_id = auth.uid());

-- Admin deleta qualquer arquivo
CREATE POLICY "arquivos_delete_admin"
    ON public.arquivos
    FOR DELETE
    TO authenticated
    USING (public.fn_is_admin());

-- Admin atualiza qualquer arquivo
CREATE POLICY "arquivos_update_admin"
    ON public.arquivos
    FOR UPDATE
    TO authenticated
    USING (public.fn_is_admin())
    WITH CHECK (public.fn_is_admin());

-- ============================================================
-- INSERT INICIAL - configuracoes
-- ============================================================
INSERT INTO public.configuracoes (chave, valor, descricao, tipo, publica) VALUES
    ('nome_empresa',       'Formação de Voluntários',  'Nome da organização',                    'texto',   TRUE),
    ('cor_primaria',       '#2563eb',                  'Cor primária da identidade visual',      'cor',     TRUE),
    ('cor_secundaria',     '#1e40af',                  'Cor secundária da identidade visual',    'cor',     TRUE),
    ('whatsapp',           '+5511999999999',            'Número de WhatsApp para contato',        'texto',   TRUE),
    ('email_contato',      'contato@exemplo.com',       'E-mail principal de contato',            'texto',   TRUE),
    ('descricao_site',     'Plataforma de cursos online para formação de voluntários cristãos.',
                                                        'Descrição curta do site (SEO)',          'texto',   TRUE),
    ('manutencao',         'false',                    'Modo manutenção ativo',                  'booleano',FALSE),
    ('max_upload_mb',      '10',                       'Tamanho máximo de upload em MB',         'numero',  FALSE),
    ('redes_sociais',      '{"instagram":"","youtube":"","facebook":""}',
                                                        'Links das redes sociais (JSON)',         'json',    TRUE)
ON CONFLICT (chave) DO UPDATE
    SET valor      = EXCLUDED.valor,
        descricao  = EXCLUDED.descricao,
        updated_at = NOW();

-- ============================================================
-- COMENTÁRIOS NAS TABELAS
-- ============================================================
COMMENT ON TABLE  public.leads         IS 'Captura de leads e contatos interessados nos cursos';
COMMENT ON TABLE  public.usuarios      IS 'Perfis dos usuários vinculados ao auth.users do Supabase';
COMMENT ON TABLE  public.posts         IS 'Artigos, notícias e conteúdos publicados na plataforma';
COMMENT ON TABLE  public.configuracoes IS 'Configurações gerais da plataforma (chave-valor)';
COMMENT ON TABLE  public.arquivos      IS 'Registro de arquivos enviados para o Supabase Storage';

COMMENT ON COLUMN public.usuarios.role IS 'admin | instrutor | aluno | voluntario';
COMMENT ON COLUMN public.posts.status  IS 'rascunho | revisao | publicado | arquivado';
COMMENT ON COLUMN public.leads.status  IS 'novo | contatado | matriculado | descartado';

-- ============================================================
-- FIM DO SCHEMA
-- ============================================================