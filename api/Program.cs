using System.Text;
using Azure.Identity;
using Azure.Security.KeyVault.Secrets;
using Azure.Storage.Blobs;
using Microsoft.Azure.Cosmos;

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

app.MapGet("list", async (IConfiguration config) =>
{
    var cosmosConnectionString = config["CosmosConnectionString"] ?? throw new ApplicationException("CosmosConnectionString missing");

    var cosmosClient = new CosmosClient(accountEndpoint: cosmosConnectionString, tokenCredential: new DefaultAzureCredential());
    var db = cosmosClient.GetDatabase("db");
    var container = db.GetContainer("container");
    // Read all items from Cosmos DB
    var query = container.GetItemQueryIterator<dynamic>("SELECT * FROM c");
    var items = new List<dynamic>();
    
    while (query.HasMoreResults)
    {
        var response = await query.ReadNextAsync();
        items.AddRange(response);
    }
    
    return items;
});

app.Run();