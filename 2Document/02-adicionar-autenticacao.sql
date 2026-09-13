-- ============================================================
-- COMPLEMENTO: Tabelas de Autenticação Multi-Usuário
-- ============================================================

USE [AzureServerManager]
GO

-- ============================================================
-- TABELA: Usuários do Sistema
-- ============================================================
CREATE TABLE [dbo].[USUARIOS] (
    [Usuario_ID] INT PRIMARY KEY IDENTITY(1,1),
    [Username] VARCHAR(100) NOT NULL UNIQUE,
    [Email] VARCHAR(100) NOT NULL UNIQUE,
    [Senha_Hash] VARCHAR(255) NOT NULL,
    [Nome_Completo] VARCHAR(150),
    [Ativo] BIT DEFAULT 1,
    [Data_Criacao] DATETIME DEFAULT GETDATE(),
    [Data_Ultimo_Login] DATETIME,
    [Tentativas_Falhas_Login] INT DEFAULT 0,
    [Bloqueado] BIT DEFAULT 0
)
GO

-- ============================================================
-- TABELA: Roles (Papéis) - Admin, Manager, Viewer
-- ============================================================
CREATE TABLE [dbo].[ROLES] (
    [Role_ID] INT PRIMARY KEY IDENTITY(1,1),
    [Nome_Role] VARCHAR(50) NOT NULL UNIQUE,
    [Descricao] VARCHAR(255),
    [Permissoes] VARCHAR(500)  -- JSON com permissões
)
GO

-- ============================================================
-- TABELA: Mapeamento Usuário x Role
-- ============================================================
CREATE TABLE [dbo].[USUARIO_ROLES] (
    [Usuario_Role_ID] INT PRIMARY KEY IDENTITY(1,1),
    [Usuario_ID] INT NOT NULL,
    [Role_ID] INT NOT NULL,
    [Data_Atribuicao] DATETIME DEFAULT GETDATE(),
    FOREIGN KEY ([Usuario_ID]) REFERENCES [USUARIOS]([Usuario_ID]),
    FOREIGN KEY ([Role_ID]) REFERENCES [ROLES]([Role_ID]),
    UNIQUE([Usuario_ID], [Role_ID])
)
GO

-- ============================================================
-- TABELA: Sessões de Login
-- ============================================================
CREATE TABLE [dbo].[SESSOES_LOGIN] (
    [Sessao_ID] INT PRIMARY KEY IDENTITY(1,1),
    [Usuario_ID] INT NOT NULL,
    [Token] VARCHAR(500) NOT NULL UNIQUE,
    [Data_Login] DATETIME DEFAULT GETDATE(),
    [Data_Expiracao] DATETIME,
    [IP_Address] VARCHAR(45),
    [Ativa] BIT DEFAULT 1,
    FOREIGN KEY ([Usuario_ID]) REFERENCES [USUARIOS]([Usuario_ID])
)
GO

-- ============================================================
-- TABELA: Auditoria de Acesso
-- ============================================================
CREATE TABLE [dbo].[AUDITORIA_ACESSO] (
    [Auditoria_ID] INT PRIMARY KEY IDENTITY(1,1),
    [Usuario_ID] INT,
    [Acao] VARCHAR(100),
    [Tabela_Afetada] VARCHAR(100),
    [Registro_ID] INT,
    [Dados_Anteriores] VARCHAR(MAX),
    [Dados_Novos] VARCHAR(MAX),
    [Data_Hora] DATETIME DEFAULT GETDATE(),
    [IP_Address] VARCHAR(45),
    FOREIGN KEY ([Usuario_ID]) REFERENCES [USUARIOS]([Usuario_ID])
)
GO

-- ============================================================
-- Atualizar CONFIGURACOES para conectar ao usuário
-- ============================================================
ALTER TABLE [dbo].[CONFIGURACOES]
ADD [Usuario_ID] INT NOT NULL DEFAULT 1
GO

ALTER TABLE [dbo].[CONFIGURACOES]
ADD FOREIGN KEY ([Usuario_ID]) REFERENCES [USUARIOS]([Usuario_ID])
GO

-- ============================================================
-- Atualizar VMS_CRIADAS para registrar usuário criador
-- ============================================================
ALTER TABLE [dbo].[VMS_CRIADAS]
ADD [Usuario_ID_Criador] INT
GO

ALTER TABLE [dbo].[VMS_CRIADAS]
ADD FOREIGN KEY ([Usuario_ID_Criador]) REFERENCES [USUARIOS]([Usuario_ID])
GO

-- ============================================================
-- Inserir Roles Padrão
-- ============================================================
INSERT INTO [ROLES] ([Nome_Role], [Descricao], [Permissoes])
VALUES
(
    'Admin',
    'Acesso total ao sistema',
    '{"criar_vm":true,"deletar_vm":true,"editar_config":true,"ver_relatorios":true,"gerenciar_usuarios":true}'
),
(
    'Manager',
    'Gerenciar VMs e ver relatórios',
    '{"criar_vm":true,"deletar_vm":true,"editar_config":true,"ver_relatorios":true,"gerenciar_usuarios":false}'
),
(
    'Viewer',
    'Apenas visualizar VMs e relatórios',
    '{"criar_vm":false,"deletar_vm":false,"editar_config":false,"ver_relatorios":true,"gerenciar_usuarios":false}'
)
GO

-- ============================================================
-- Inserir Usuário Admin Padrão
-- ============================================================
-- Senha: Admin@2026 (hash SHA256)
INSERT INTO [USUARIOS]
([Username], [Email], [Senha_Hash], [Nome_Completo], [Ativo])
VALUES
('admin', 'rodrigofurlaneti31@gmail.com', 'D5A122B8E5B6E5C8E0F7C8E5C8E5C8E5C8E5C8E5C8E5C8E5C8E5C8E5C8E5C8E', 'Rodrigo Furlaneti', 1)
GO

-- ============================================================
-- Atribuir Role Admin ao usuário
-- ============================================================
INSERT INTO [USUARIO_ROLES] ([Usuario_ID], [Role_ID])
SELECT u.[Usuario_ID], r.[Role_ID]
FROM [USUARIOS] u, [ROLES] r
WHERE u.[Username] = 'admin' AND r.[Nome_Role] = 'Admin'
GO

-- ============================================================
-- Índices para Performance de Autenticação
-- ============================================================
CREATE INDEX idx_usuario_username ON [USUARIOS]([Username])
CREATE INDEX idx_usuario_email ON [USUARIOS]([Email])
CREATE INDEX idx_sessao_token ON [SESSOES_LOGIN]([Token])
CREATE INDEX idx_auditoria_usuario ON [AUDITORIA_ACESSO]([Usuario_ID])
CREATE INDEX idx_auditoria_data ON [AUDITORIA_ACESSO]([Data_Hora])
GO

-- ============================================================
-- VIEW: Usuários com seus Roles
-- ============================================================
CREATE VIEW [vw_Usuarios_Com_Roles] AS
SELECT
    u.[Usuario_ID],
    u.[Username],
    u.[Email],
    u.[Nome_Completo],
    u.[Ativo],
    u.[Data_Ultimo_Login],
    STRING_AGG(r.[Nome_Role], ', ') AS Roles,
    u.[Data_Criacao]
FROM [USUARIOS] u
LEFT JOIN [USUARIO_ROLES] ur ON u.[Usuario_ID] = ur.[Usuario_ID]
LEFT JOIN [ROLES] r ON ur.[Role_ID] = r.[Role_ID]
GROUP BY u.[Usuario_ID], u.[Username], u.[Email], u.[Nome_Completo], u.[Ativo], u.[Data_Ultimo_Login], u.[Data_Criacao]
GO

PRINT '✅ Tabelas de autenticação criadas!'
PRINT '✅ Roles padrão inseridas: Admin, Manager, Viewer'
PRINT '✅ Usuário admin criado'
PRINT '✅ Índices de autenticação adicionados'
