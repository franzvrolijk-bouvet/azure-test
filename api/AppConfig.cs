using Azure.Identity;
using Azure.Security.KeyVault.Secrets;

namespace api;

public class AppConfig
{
    public string BlobStorageConnectionString { get; }
    public string CosmosDbConnectionString { get; }

    public AppConfig(IConfiguration config)
    {
        var keyVaultUri = new Uri(config["KeyVaultUri"] ?? throw new ApplicationException("KeyVaultUri missing"));
        var kvClient = new SecretClient(keyVaultUri, new DefaultAzureCredential());
        
        BlobStorageConnectionString = kvClient.GetSecret("StorageAccountConnectionString").Value.Value;
        CosmosDbConnectionString = kvClient.GetSecret("CosmosDbConnectionString").Value.Value;

        if (string.IsNullOrEmpty(BlobStorageConnectionString) || string.IsNullOrEmpty(CosmosDbConnectionString))
        {
            throw new ApplicationException("Missing KeyVault values");
        }
    }
}