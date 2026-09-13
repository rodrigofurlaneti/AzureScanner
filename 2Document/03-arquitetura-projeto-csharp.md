# 🏗️ Arquitetura - Azure Server Manager

## 📋 Visão Geral do Projeto

Sistema completo de gerenciamento de servidores Azure com:
- ✅ Multi-usuário com autenticação
- ✅ Gerenciamento de VMs (criar, parar, deletar, redimensionar)
- ✅ Otimização de custos (Spot vs Regular)
- ✅ Worker que executa madrugada com ranking de servidores
- ✅ Relatórios e análise de custos

---

## 📁 Estrutura de Pastas Recomendada

```
AzureServerManager/
├── 1ProofOfConcept/
│   └── AzureScannerPoc/          (Seu projeto atual)
│
├── AzureServerManager/           (Novo projeto principal)
│   ├── Core/
│   │   ├── Models/
│   │   │   ├── Usuario.cs
│   │   │   ├── VM.cs
│   │   │   ├── SKU.cs
│   │   │   └── HistoricoCusto.cs
│   │   │
│   │   ├── Services/
│   │   │   ├── AutenticacaoService.cs
│   │   │   ├── VMService.cs
│   │   │   ├── CustoService.cs
│   │   │   └── RankingService.cs
│   │   │
│   │   ├── Data/
│   │   │   ├── AppDbContext.cs
│   │   │   └── DataInitializer.cs
│   │   │
│   │   └── Utils/
│   │       ├── TokenUtil.cs
│   │       ├── PasswordHasher.cs
│   │       └── Logger.cs
│   │
│   ├── UI/
│   │   ├── Menu.cs              (Menu interativo)
│   │   └── ConsoleHelper.cs     (Formatação de console)
│   │
│   ├── Worker/
│   │   ├── RankingWorker.cs     (Executa madrugada)
│   │   └── CustoWorker.cs       (Calcula custos diários)
│   │
│   ├── Program.cs               (Ponto de entrada)
│   ├── appsettings.json         (Configuração)
│   └── AzureServerManager.csproj
│
└── Database/
    ├── 01-criar-banco.sql
    ├── 02-autenticacao.sql
    └── 03-dados-iniciais.sql
```

---

## 🔄 Fluxo de Arquitetura

```
┌─────────────────────┐
│   USER INTERFACE    │  (Menu.cs)
│  (Console Interativo)│
└──────────┬──────────┘
           │
┌──────────▼──────────────────────┐
│    AUTHENTICATION SERVICE       │  (Validar usuário)
│  - Login                        │
│  - Verificar permissões         │
│  - Gerar token                  │
└──────────┬──────────────────────┘
           │
┌──────────▼──────────────────────┐
│    BUSINESS LOGIC LAYER         │
│  - VMService (CRUD)             │
│  - CustoService (Análise)       │
│  - RankingService (Cálculos)    │
└──────────┬──────────────────────┘
           │
┌──────────▼──────────────────────┐
│    DATA ACCESS LAYER            │
│  - Entity Framework             │
│  - AppDbContext                 │
│  - SQL Server                   │
└─────────────────────────────────┘
           │
┌──────────▼──────────────────────┐
│    EXTERNAL SERVICES            │
│  - Azure SDK (criar/deletar VMs)│
│  - Azure CLI (operações)        │
└─────────────────────────────────┘
```

---

## 🗄️ Entity Framework Models

### Usuario.cs
```csharp
public class Usuario
{
    public int UsuarioID { get; set; }
    public string Username { get; set; }
    public string Email { get; set; }
    public string SenhaHash { get; set; }
    public string NomeCompleto { get; set; }
    public bool Ativo { get; set; }
    public DateTime DataCriacao { get; set; }
    public DateTime? DataUltimoLogin { get; set; }
    
    // Relacionamentos
    public ICollection<UsuarioRole> UsuarioRoles { get; set; }
    public ICollection<VM> VMsCriadas { get; set; }
}
```

### VM.cs
```csharp
public class VM
{
    public int VMID { get; set; }
    public string NomeVM { get; set; }
    public string ResourceGroup { get; set; }
    public string Regiao { get; set; }
    public int SKUID { get; set; }
    public string Prioridade { get; set; }  // Regular / Spot
    public string Status { get; set; }      // Running / Stopped / Deleted
    public string IPPublico { get; set; }
    public DateTime DataCriacao { get; set; }
    
    // Foreign Keys
    public int UsuarioIDCriador { get; set; }
    public Usuario UsuarioCriador { get; set; }
    public SKU SKU { get; set; }
    
    // Relacionamentos
    public ICollection<HistoricoCusto> HistoricoCustos { get; set; }
}
```

### SKU.cs
```csharp
public class SKU
{
    public int SKUID { get; set; }
    public string NomeSKU { get; set; }
    public int vCPUs { get; set; }
    public decimal RAMGiB { get; set; }
    public decimal PrecoRegularHora { get; set; }
    public decimal PrecoSpotHora { get; set; }
    
    // Calculated
    public int DescontoSpotPercentual => 
        (int)((1 - PrecoSpotHora / PrecoRegularHora) * 100);
}
```

---

## 🔐 Autenticação - Fluxo

```
1. Login
   ├─ Usuário digita username/senha
   ├─ AutenticacaoService verifica hash
   ├─ Se OK: Gera JWT Token
   └─ Armazena sessão no banco

2. Cada operação
   ├─ Verifica token
   ├─ Busca usuário pelo token
   ├─ Verifica Role/Permissões
   └─ Executa se autorizado

3. Logout
   └─ Invalida token no banco
```

---

## 🌙 Worker - Agendador Madrugada

Arquivo: `Worker/RankingWorker.cs`

```csharp
public class RankingWorker
{
    // Executa todos os dias às 03:00 da manhã
    public async Task CriarRankingDiario()
    {
        var dataAtual = DateTime.Now.Date;
        
        // 1. Buscar todos os SKUs
        var skus = await _dbContext.SKUs.ToListAsync();
        
        // 2. Para cada SKU, calcular:
        //    - Custo Regular por hora
        //    - Custo Spot por hora
        //    - Economia
        //    - Ranking (ordenar por mais barato)
        
        var rankings = skus
            .Select((sku, index) => new RankingDiario
            {
                DataRanking = dataAtual,
                SKUID = sku.SKUID,
                Posicao = index + 1,  // 1º mais barato
                EconomiaUSD = sku.PrecoRegularHora - sku.PrecoSpotHora,
                EconomiaPercentual = sku.DescontoSpotPercentual,
                Recomendacao = "Use Spot para máxima economia"
            })
            .OrderBy(r => r.EconomiaUSD)
            .ToList();
        
        // 3. Salvar no banco
        await _dbContext.RankingDiarios.AddRangeAsync(rankings);
        await _dbContext.SaveChangesAsync();
        
        // 4. Enviar email com recomendações
        await _emailService.EnviarRankingDiario();
    }
}
```

---

## 💰 Cálculo de Custos

### CustoService.cs
```csharp
public class CustoService
{
    // Custo mensal de uma VM
    public decimal CalcularCustoMensal(VM vm)
    {
        var sku = vm.SKU;
        var horasPorMes = 24 * 30;
        
        decimal precoHora = vm.Prioridade == "Spot" 
            ? sku.PrecoSpotHora 
            : sku.PrecoRegularHora;
        
        return precoHora * horasPorMes;
    }
    
    // Economia ao usar Spot
    public decimal CalcularEconomiaMensal(SKU sku)
    {
        var economia_hora = sku.PrecoRegularHora - sku.PrecoSpotHora;
        return economia_hora * 24 * 30;
    }
    
    // Registrar custo diário
    public async Task RegistrarCustoDiario(VM vm)
    {
        var custo = new HistoricoCusto
        {
            VMID = vm.VMID,
            DataCusto = DateTime.Now.Date,
            TipoCobranca = vm.Prioridade,
            CustoUSD = CalcularCustoMensal(vm) / 30,
            Data Insercao = DateTime.Now
        };
        
        await _dbContext.HistoricoCustos.AddAsync(custo);
        await _dbContext.SaveChangesAsync();
    }
}
```

---

## 🎯 Principais Features

### 1. Menu Principal
```
┌─────────────────────────────────┐
│ 🔷 GERENCIADOR AZURE SERVERS    │
├─────────────────────────────────┤
│ 1. Criar Nova VM                │
│ 2. Listar VMs                   │
│ 3. Parar VM                     │
│ 4. Deletar VM                   │
│ 5. Ranking Custos               │
│ 6. Ver Relatório                │
│ 0. Sair                         │
└─────────────────────────────────┘
```

### 2. Criar VM com Menu
```
Qual tamanho? (B1s, D2as_v4, E4s_v3)
Qual região? (brazilsouth, eastus, westus)
Usar Azure Spot? (S/N)
→ Criar automaticamente via Azure CLI
```

### 3. Ranking Diário
```
🏆 RANKING DE SERVIDORES - 13/09/2026

Posição │ SKU            │ Custo Dia │ Economia
─────────┼────────────────┼───────────┼─────────
   1º    │ Standard_B1s   │ $0.36    │ 75% off
   2º    │ Standard_B1ms  │ $0.59    │ 80% off
   3º    │ Standard_B2s   │ $1.19    │ 80% off
```

---

## 🚀 Próximos Passos

1. **Criar Projeto C# com EF Core**
   ```
   dotnet new console -n AzureServerManager
   dotnet add package Microsoft.EntityFrameworkCore.SqlServer
   dotnet add package Azure.Identity
   dotnet add package Azure.ResourceManager.Compute
   ```

2. **Implementar Models** (usuário, VM, SKU, etc)

3. **Criar DbContext** (AppDbContext.cs)

4. **Implementar Serviços** (Autenticação, VM, Custo)

5. **Criar Menu Interativo** (Program.cs)

6. **Implementar Worker** (Executa madrugada)

7. **Adicionar Relatórios** (Excel, PDF)

---

## 📊 Resumo do Projeto

| Aspecto | Detalhe |
|---------|---------|
| **Linguagem** | C# .NET 9.0 |
| **Banco** | SQL Server |
| **Arquitetura** | N-Camadas (UI, Service, Data) |
| **Autenticação** | JWT + Roles |
| **Escalabilidade** | Multi-usuário |
| **Automação** | Worker madrugada |
| **Custo** | Economia até 85% com Spot |

---

**Quer que eu comece a implementar estes Services em C#?** 🚀
