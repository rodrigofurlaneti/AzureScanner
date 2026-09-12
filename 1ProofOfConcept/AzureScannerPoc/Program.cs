using System;
using System.Linq;
using System.Diagnostics;
using System.Threading.Tasks;
using Azure.Core;
using Azure.Identity;
using Azure.ResourceManager;
using Azure.ResourceManager.Compute;
using Azure.ResourceManager.Resources;

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
// FASE 2: PROVISIONAMENTO AUTOMATIZADO DA VM E REDE VIA C#
// =======================================================
string rgName = $"RG-App-Furlaneti-{regiaoEncontrada}-Prod";
string vmName = $"VMFurlaneti-{regiaoEncontrada}-Prod";
string vnetName = $"vnet-furlaneti-{regiaoEncontrada}-prod";
string subnetName = $"subnet-furlaneti-{regiaoEncontrada}-prod";
string nsgName = $"{vmName}-NSG-PROD";
string ipName = $"{vmName}-PublicIP-Prod";

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

    Console.WriteLine($"==> [3/4] Criando a Máquina Virtual ({tamanhoEncontrado})...");
    ExecutarComandoAz($"vm create -g {rgName} -n {vmName} -l {regiaoEncontrada} --size {tamanhoEncontrado} --image Ubuntu2204 --admin-username {adminUser} --admin-password {adminPass} --vnet-name {vnetName} --subnet {subnetName} --nsg {nsgName} --public-ip-address {ipName}");

    Console.ForegroundColor = ConsoleColor.Green;
    Console.WriteLine("\n🎉 AMBIENTE PRONTO COM SUCESSO!");
    Console.ResetColor();
    Console.WriteLine($"🌐 VM Criada: {vmName}");
    Console.WriteLine($"📍 Região: {regiaoEncontrada}");
    Console.WriteLine($"👤 Usuário SSH: {adminUser}");
    Console.WriteLine($"🔑 Senha SSH: {adminPass}");
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

// =======================================================
// MÉTODO AUXILIAR: Executa os comandos do Azure CLI direto do C#
// =======================================================
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