using System.Text;
using Azure.Identity;
using Azure.Security.KeyVault.Secrets;
using Azure.Storage.Blobs;

var builder = WebApplication.CreateBuilder(args);

var app = builder.Build();

app.UseHttpsRedirection();

app.MapPost("upload", async (string value, IConfiguration config) =>
{
    var keyVaultUri = new Uri(config["KeyVaultUri"] ?? throw new ApplicationException("KeyVaultUri missing"));
    var kvClient = new SecretClient(keyVaultUri, new DefaultAzureCredential());
    var blobStorageConnectionString = (await kvClient.GetSecretAsync("StorageAccountConnectionString")).Value.Value;

    var blobContainerClient = new BlobContainerClient(blobStorageConnectionString, "items");
    await blobContainerClient.CreateIfNotExistsAsync();

    var blobClient = blobContainerClient.GetBlobClient(Guid.NewGuid().ToString());
    await blobClient.UploadAsync(new MemoryStream(Encoding.UTF8.GetBytes(value)), false);
});

app.Run();