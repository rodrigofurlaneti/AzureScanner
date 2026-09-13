-- ============================================================
-- BANCO DE DADOS: Azure Server Manager
-- Descrição: Gerenciamento de VMs Azure com histórico de custos
-- ============================================================

-- Criar banco de dados
CREATE DATABASE IF NOT EXISTS [AzureServerManager]
GO

USE [AzureServerManager]
GO

-- ============================================================
-- TABELA 1: Dados estáticos de SKU e Preços
-- ============================================================
CREATE TABLE [dbo].[SKU_PRECOS] (
    [SKU_ID] INT PRIMARY KEY IDENTITY(1,1),
    [Nome_SKU] VARCHAR(50) NOT NULL UNIQUE,
    [Tipo] VARCHAR(20) NOT NULL,  -- 'General', 'Memory', 'Compute'
    [vCPUs] INT NOT NULL,
    [RAM_GB] DECIMAL(10,2) NOT NULL,
    [Armazenamento_GB] INT NOT NULL,
    [Regioes] VARCHAR(255) NOT NULL,  -- 'brazilsouth, eastus, westus'
    [Preço_Horario_Regular_USD] DECIMAL(10,4) NOT NULL,
    [Preço_Horario_Spot_USD] DECIMAL(10,4) NOT NULL,
    [Desconto_Spot_Percentual] INT GENERATED ALWAYS AS
        (CAST((1 - [Preço_Horario_Spot_USD] / [Preço_Horario_Regular_USD]) * 100 AS INT)) STORED,
    [Data_Atualizacao] DATETIME DEFAULT GETDATE(),
    [Ativo] BIT DEFAULT 1
)
GO

-- ============================================================
-- TABELA 2: VMs Criadas pelo usuário
-- ============================================================
CREATE TABLE [dbo].[VMS_CRIADAS] (
    [VM_ID] INT PRIMARY KEY IDENTITY(1,1),
    [Nome_VM] VARCHAR(100) NOT NULL,
    [Resource_Group] VARCHAR(100) NOT NULL,
    [Regiao] VARCHAR(50) NOT NULL,
    [SKU_ID] INT NOT NULL,
    [Prioridade] VARCHAR(20) NOT NULL,  -- 'Regular' ou 'Spot'
    [Status] VARCHAR(20) NOT NULL,  -- 'Running', 'Stopped', 'Deallocated', 'Deleted'
    [IP_Publico] VARCHAR(15),
    [Username_SSH] VARCHAR(100),
    [Data_Criacao] DATETIME DEFAULT GETDATE(),
    [Data_Ultima_Atualizacao] DATETIME DEFAULT GETDATE(),
    [Ativa] BIT DEFAULT 1,
    FOREIGN KEY ([SKU_ID]) REFERENCES [SKU_PRECOS]([SKU_ID])
)
GO

-- ============================================================
-- TABELA 3: Histórico de Custos
-- ============================================================
CREATE TABLE [dbo].[HISTORICO_CUSTOS] (
    [Custo_ID] INT PRIMARY KEY IDENTITY(1,1),
    [VM_ID] INT NOT NULL,
    [Data_Custo] DATE NOT NULL,
    [Horas_Rodada] DECIMAL(5,2) DEFAULT 24.0,
    [Tipo_Cobranca] VARCHAR(20) NOT NULL,  -- 'Regular' ou 'Spot'
    [Custo_USD] DECIMAL(10,4) NOT NULL,
    [Economia_vs_Regular_USD] DECIMAL(10,4),
    [Data_Insercao] DATETIME DEFAULT GETDATE(),
    FOREIGN KEY ([VM_ID]) REFERENCES [VMS_CRIADAS]([VM_ID])
)
GO

-- ============================================================
-- TABELA 4: Configurações do Usuário
-- ============================================================
CREATE TABLE [dbo].[CONFIGURACOES] (
    [Config_ID] INT PRIMARY KEY IDENTITY(1,1),
    [Usuario_Nome] VARCHAR(100) DEFAULT 'Rodrigo',
    [Email] VARCHAR(100),
    [Regioes_Preferidas] VARCHAR(255),  -- 'brazilsouth;eastus'
    [Preferir_Spot] BIT DEFAULT 1,
    [Ativar_Alertas_Custo] BIT DEFAULT 1,
    [Limte_Custo_Mensal_USD] DECIMAL(10,2),
    [Horario_Worker_Madrugada] VARCHAR(10) DEFAULT '03:00',  -- Horário para rodar worker
    [Data_Atualizacao] DATETIME DEFAULT GETDATE()
)
GO

-- ============================================================
-- TABELA 5: Ranking Diário (criado pelo Worker)
-- ============================================================
CREATE TABLE [dbo].[RANKING_DIARIO] (
    [Ranking_ID] INT PRIMARY KEY IDENTITY(1,1),
    [Data_Ranking] DATE NOT NULL,
    [SKU_ID] INT NOT NULL,
    [Regiao] VARCHAR(50) NOT NULL,
    [Posicao] INT NOT NULL,  -- 1º mais barato, 2º, etc
    [Custo_Horario_Regular_USD] DECIMAL(10,4),
    [Custo_Horario_Spot_USD] DECIMAL(10,4),
    [Economia_USD] DECIMAL(10,4),
    [Economia_Percentual] INT,
    [Recomendacao] VARCHAR(255),
    [Data_Insercao] DATETIME DEFAULT GETDATE(),
    FOREIGN KEY ([SKU_ID]) REFERENCES [SKU_PRECOS]([SKU_ID])
)
GO

-- ============================================================
-- TABELA 6: Logs de Operações (Auditoria)
-- ============================================================
CREATE TABLE [dbo].[LOGS_OPERACOES] (
    [Log_ID] INT PRIMARY KEY IDENTITY(1,1),
    [Operacao] VARCHAR(100) NOT NULL,  -- 'Criar VM', 'Parar VM', 'Converter Spot'
    [VM_ID] INT,
    [Usuario] VARCHAR(100),
    [Status] VARCHAR(20) NOT NULL,  -- 'Sucesso', 'Erro', 'Aviso'
    [Mensagem] VARCHAR(500),
    [Data_Operacao] DATETIME DEFAULT GETDATE()
)
GO

-- ============================================================
-- ÍNDICES PARA PERFORMANCE
-- ============================================================
CREATE INDEX idx_vm_status ON [VMS_CRIADAS]([Status])
CREATE INDEX idx_vm_regiao ON [VMS_CRIADAS]([Regiao])
CREATE INDEX idx_custos_data ON [HISTORICO_CUSTOS]([Data_Custo])
CREATE INDEX idx_ranking_data ON [RANKING_DIARIO]([Data_Ranking])
GO

-- ============================================================
-- INSERIR DADOS ESTÁTICOS - SKU PREÇOS (BRASIL)
-- ============================================================
INSERT INTO [SKU_PRECOS]
([Nome_SKU], [Tipo], [vCPUs], [RAM_GB], [Armazenamento_GB], [Regioes], [Preço_Horario_Regular_USD], [Preço_Horario_Spot_USD])
VALUES
-- General Purpose (mais baratos)
('Standard_B1s', 'General', 1, 1.0, 30, 'brazilsouth;eastus', 0.0120, 0.0030),
('Standard_B1ms', 'General', 1, 2.0, 30, 'brazilsouth;eastus', 0.0244, 0.0049),
('Standard_B2s', 'General', 2, 4.0, 30, 'brazilsouth;eastus', 0.0488, 0.0098),
('Standard_D2as_v4', 'General', 2, 8.0, 75, 'brazilsouth;eastus', 0.1203, 0.0180),
('Standard_D4as_v4', 'General', 4, 16.0, 150, 'brazilsouth;eastus', 0.2406, 0.0361),
-- Memory Optimized
('Standard_E2s_v3', 'Memory', 2, 16.0, 32, 'brazilsouth;eastus', 0.1606, 0.0481),
('Standard_E4s_v3', 'Memory', 4, 32.0, 64, 'brazilsouth;eastus', 0.3211, 0.0963),
-- Compute Optimized
('Standard_F2s_v2', 'Compute', 2, 4.0, 32, 'brazilsouth;eastus', 0.0871, 0.0262)
GO

-- ============================================================
-- INSERIR CONFIGURAÇÃO PADRÃO DO USUÁRIO
-- ============================================================
INSERT INTO [CONFIGURACOES]
([Usuario_Nome], [Email], [Regioes_Preferidas], [Preferir_Spot], [Ativar_Alertas_Custo], [Limte_Custo_Mensal_USD], [Horario_Worker_Madrugada])
VALUES
('Rodrigo Furlaneti', 'rodrigofurlaneti31@gmail.com', 'brazilsouth;eastus', 1, 1, 500.00, '03:00')
GO

-- ============================================================
-- VIEW: Resumo de Custos Atuais
-- ============================================================
CREATE VIEW [vw_Resumo_Custos_Atuais] AS
SELECT
    v.Nome_VM,
    s.Nome_SKU,
    v.Prioridade,
    v.Status,
    s.Preço_Horario_Regular_USD * 24 AS Custo_Diario_Regular_USD,
    s.Preço_Horario_Spot_USD * 24 AS Custo_Diario_Spot_USD,
    ROUND((s.Preço_Horario_Regular_USD - s.Preço_Horario_Spot_USD) * 24, 4) AS Economia_Diaria_USD,
    ROUND((s.Preço_Horario_Regular_USD - s.Preço_Horario_Spot_USD) * 24 * 30, 2) AS Economia_Mensal_USD
FROM [VMS_CRIADAS] v
INNER JOIN [SKU_PRECOS] s ON v.SKU_ID = s.SKU_ID
WHERE v.Ativa = 1
GO

-- ============================================================
-- VIEW: Ranking de SKUs mais Baratos por Região
-- ============================================================
CREATE VIEW [vw_Ranking_SKUs_Baratos] AS
SELECT
    s.Nome_SKU,
    s.vCPUs,
    s.RAM_GB,
    s.Preço_Horario_Regular_USD * 24 AS Custo_Diario_Regular,
    s.Preço_Horario_Spot_USD * 24 AS Custo_Diario_Spot,
    s.Desconto_Spot_Percentual AS Desconto_Percentual,
    ROW_NUMBER() OVER (ORDER BY s.Preço_Horario_Spot_USD) AS Posicao_Barato
FROM [SKU_PRECOS] s
WHERE s.Ativo = 1
GO

PRINT '✅ Banco de dados criado com sucesso!'
PRINT '✅ Tabelas criadas: 6'
PRINT '✅ Índices criados: 4'
PRINT '✅ Views criadas: 2'
PRINT '✅ Dados estáticos inseridos'
