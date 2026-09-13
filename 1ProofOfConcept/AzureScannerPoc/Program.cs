using System;
using System.Linq;
using System.Diagnostics;
using System.Threading.Tasks;
using Azure.Core;
using Azure.Identity;
using Azure.ResourceManager;
using Azure.ResourceManager.Compute;
using Azure.ResourceManager.Resources;

// =======================================================
// DEFINIÇÃO DOS MÉTODOS (ANTES DO CÓDIGO PRINCIPAL)
// =======================================================

// Método: Confirmar Azure Spot
static async Task ConverterVMParaSpot(ArmClient armClient, string rgName, string vmName)
{
    Console.ForegroundColor = ConsoleColor.Green;
    Console.WriteLine("\n🎉 ===== RESUMO DO PROVISIONAMENTO =====");
    Console.ResetColor();
    Console.WriteLine($"\n✅ Máquina Virtual: {vmName}");
    Console.WriteLine($"📍 Grupo de Recursos: {rgName}");
    Console.WriteLine($"⭐ Prioridade: Azure Spot (ATIVO)");
    Console.WriteLine($"🛡️ Política de Despejo: Deallocate");
    Console.WriteLine($"💰 Economia Estimada: até 85% de desconto");
    Console.WriteLine($"💵 Você economizará SIGNIFICATIVAMENTE no custo mensal!\n");

    Console.ForegroundColor = ConsoleColor.Yellow;
    Console.WriteLine("⚠️ Nota importante:");
    Console.WriteLine("   - A VM pode ser pausada pelo Azure se houver necessidade");
    Console.WriteLine("   - Você será notificado com 30 segundos de antecedência");
    Console.WriteLine("   - Ideal para cargas de trabalho tolerantes a interrupções\n");
    Console.ResetColor();
}

// Método: Calcular economia do Azure Spot
static int CalcularEconomiaSpot(string tamanho)
{
    return tamanho switch
    {
        "Standard_B1s" => 85,
        "Standard_B1ms" => 80,
        "Standard_B2s" => 80,
        "Standard_D2as_v4" => 85,
        "Standard_D2s_v3" => 80,
        "Standard_A1_v2" => 75,
        "Standard_A2_v2" => 75,
        _ => 80
    };
}

// Método: Obter custo mensal estimado da VM
static decimal ObterCustoMensal(string tamanho)
{
    return tamanho switch
    {
        "Standard_B1s" => 12.42m,
        "Standard_B1ms" => 24.84m,
        "Standard_B2s" => 49.69m,
        "Standard_D2as_v4" => 120.30m,
        "Standard_D2s_v3" => 97.50m,
        "Standard_A1_v2" => 58.44m,
        "Standard_A2_v2" => 116.88m,
        _ => 100m
    };
}

// Método AUXILIAR: Executa os comandos do Azure CLI direto do C#
static void ExecutarComandoAz(string argumentos)
{
    Process process = new Process();
    process.StartInfo.FileName = "cmd.exe";
    process.StartInfo.Arguments = $"/c az {argumentos}";
    process.StartInfo.UseShellExecute = false;
    process.StartInfo.RedirectStandardError = true;
    process.StartInfo.CreateNoWindow = true;

    process.Start();
    string erro = process.StandardError.ReadToEnd();
    process.WaitForExit();

    if (process.ExitCode != 0)
    {
        throw new Exception(erro);
    }
}

// =======================================================
// CÓDIGO PRINCIPAL (APÓS A DEFINIÇÃO DOS MÉTODOS)
// =======================================================

Console.WriteLine("==> [POC Azure] Iniciando varredura e provisionamento automatizado...");

var credential = new AzureCliCredential();
var armClient = new ArmClient(credential);
SubscriptionResource subscription = await armClient.GetDefaultSubscriptionAsync();
Console.WriteLine($"✅ Conectado na assinatura: {subscription.Data.DisplayName}\n");

string[] regioesAlvo = { "brazilsouth", "eastus", "eastus2", "southcentralus", "centralus" };
string[] tamanhosBaratos = {
    "Standard_B1s", "Standard_B1ms", "Standard_B2s", "Standard_A1_v2",
    "Standard_A2_v2", "Standard_D2as_v4", "Standard_D2s_v3"
};

string regiaoEncontrada = "";
string tamanhoEncontrado = "";

foreach (var regiao in regioesAlvo)
{
    Console.WriteLine($"🔍 Consultando datacenter: {regiao}...");
    var skus = subscription.GetComputeResourceSkusAsync($"location eq '{regiao}'");

    await foreach (var sku in skus)
    {
        if (tamanhosBaratos.Contains(sku.Name) && !sku.Restrictions.Any())
        {
            regiaoEncontrada = regiao;
            tamanhoEncontrado = sku.Name;
            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine($"\n✅ SUCESSO! Capacidade confirmada para {tamanhoEncontrado} em {regiaoEncontrada}.");
            Console.ResetColor();
            break;
        }
    }
    if (!string.IsNullOrEmpty(regiaoEncontrada)) break;
}

if (string.IsNullOrEmpty(regiaoEncontrada))
{
    Console.ForegroundColor = ConsoleColor.Red;
    Console.WriteLine("❌ Sem capacidade disponível. Abortando.");
    Console.ResetColor();
    return;
}

// =======================================================
// FASE 2: PROVISIONAMENTO AUTOMATIZADO DA VM E REDE
// =======================================================
string rgName = $"RG-App-Furlaneti-{regiaoEncontrada}-Spot-Prod";
string vmName = $"VMFurlaneti-{regiaoEncontrada}-Spot-Prod";
string vnetName = $"vnet-furlaneti-{regiaoEncontrada}-spot-prod";
string subnetName = $"subnet-furlaneti-{regiaoEncontrada}-spot-prod";
string nsgName = $"{vmName}-NSG-SPOT-PROD";
string ipName = $"{vmName}-PublicIP-Spot-Prod";

string adminUser = "azureadmin";
string adminPass = "SenhaForte@2026!";

Console.WriteLine("\n⚙️ INICIANDO CRIAÇÃO DE INFRAESTRUTURA...");

try
{
    Console.WriteLine($"==> [1/4] Criando Grupo de Recursos ({rgName})...");
    ExecutarComandoAz($"group create --name {rgName} --location {regiaoEncontrada}");

    Console.WriteLine("==> [2/4] Criando Rede, IP Público e Regras de Segurança...");
    ExecutarComandoAz($"network vnet create -g {rgName} -n {vnetName} -l {regiaoEncontrada} --address-prefix 172.16.0.0/16 --subnet-name {subnetName} --subnet-prefix 172.16.0.0/24");
    ExecutarComandoAz($"network nsg create -g {rgName} -n {nsgName} -l {regiaoEncontrada}");
    ExecutarComandoAz($"network nsg rule create -g {rgName} --nsg-name {nsgName} -n Allow_APIs_80_85 --protocol Tcp --priority 100 --destination-port-ranges 80-85 --source-address-prefixes * --access Allow --direction Inbound");
    ExecutarComandoAz($"network public-ip create -g {rgName} -n {ipName} -l {regiaoEncontrada} --allocation-method Static --sku Standard");

    Console.WriteLine($"==> [3/4] Criando a Máquina Virtual ({tamanhoEncontrado}) como AZURE SPOT...");
    ExecutarComandoAz($"vm create -g {rgName} -n {vmName} -l {regiaoEncontrada} --size {tamanhoEncontrado} --image Ubuntu2204 --admin-username {adminUser} --admin-password {adminPass} --vnet-name {vnetName} --subnet {subnetName} --nsg {nsgName} --public-ip-address {ipName} --priority Spot --eviction-policy Deallocate");

    Console.ForegroundColor = ConsoleColor.Green;
    Console.WriteLine("\n🎉 AMBIENTE PRONTO COM SUCESSO!");
    Console.ResetColor();
    Console.WriteLine($"🌐 VM Criada: {vmName}");
    Console.WriteLine($"📍 Região: {regiaoEncontrada}");
    Console.WriteLine($"👤 Usuário SSH: {adminUser}");
    Console.WriteLine($"🔑 Senha SSH: {adminPass}");

    Console.WriteLine("\n\n💡 Sua VM foi criada como Azure Spot!");
    Console.WriteLine("   (Isso significa economia de até 85%)");
    Console.Write("Deseja ver o resumo? [S] ou [N]: ");
    string resposta = Console.ReadLine()?.ToUpper() ?? "N";

    if (resposta == "S")
    {
        await ConverterVMParaSpot(armClient, rgName, vmName);
    }
}
catch (Exception ex)
{
    Console.ForegroundColor = ConsoleColor.Red;
    Console.WriteLine($"\n⚠️ FALHA NO PROVISIONAMENTO: {ex.Message}");
    Console.ForegroundColor = ConsoleColor.Yellow;
    Console.WriteLine($"🗑️ Acionando Rollback: Deletando {rgName}...");
    ExecutarComandoAz($"group delete --name {rgName} --yes --no-wait");
    Console.ResetColor();
}

Console.WriteLine("\n\n═══════════════════════════════════════════════════════");
Console.ForegroundColor = ConsoleColor.Cyan;
Console.WriteLine("⏸️  PRESSIONE ENTER PARA FECHAR O PROGRAMA...");
Console.ResetColor();
Console.WriteLine("═══════════════════════════════════════════════════════");
Console.ReadLine();