using System.Text;
using Azure.Identity;
using Azure.Security.KeyVault.Secrets;
using Azure.Storage.Blobs;
using Microsoft.Azure.Cosmos;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddApplicationInsightsTelemetry(c => {
    c.ConnectionString = "InstrumentationKey=8ca27c43-c3bf-4ca4-ba86-ea582a062804;IngestionEndpoint=https://northeurope-2.in.applicationinsights.azure.com/;LiveEndpoint=https://northeurope.livediagnostics.monitor.azure.com/;ApplicationId=f18c8067-2223-478b-bc88-2edcdbd8a50e";
});

builder.Logging.AddApplicationInsights();
builder.Logging.AddConsole();
builder.Logging.AddDebug();

var app = builder.Build();

app.UseHttpsRedirection();

app.MapPost("upload", async (string value, IConfiguration config, ILogger logger) =>
{
    try 
    {
        var keyVaultUri = new Uri(config["KeyVaultUri"] ?? throw new ApplicationException("KeyVaultUri missing"));
        var kvClient = new SecretClient(keyVaultUri, new DefaultAzureCredential());
        var blobStorageConnectionString = (await kvClient.GetSecretAsync("StorageAccountConnectionString")).Value.Value;

        var blobContainerClient = new BlobContainerClient(blobStorageConnectionString, "items");
        await blobContainerClient.CreateIfNotExistsAsync();

        var blobClient = blobContainerClient.GetBlobClient(Guid.NewGuid().ToString());
        await blobClient.UploadAsync(new MemoryStream(Encoding.UTF8.GetBytes(value)), false);

        return Results.Ok($"Uploaded to blob");
    }
    catch (Exception ex)
    {
        logger.LogError("Exception: {message}, {innerMessage}", ex.Message, ex.InnerException?.Message);
        return Results.StatusCode(500);
    }
});

app.MapGet("list", async (IConfiguration config, ILogger logger) =>
{
    try 
    {
        logger.LogInformation("Getting items from Cosmos DB");
        
        var cosmosConnectionString = config["CosmosConnectionString"] ?? throw new ApplicationException("CosmosConnectionString missing");
        logger.LogInformation($"Cosmos Connection String: {cosmosConnectionString[0..10]}...");
        
        var cosmosClient = new CosmosClient(accountEndpoint: cosmosConnectionString, tokenCredential: new DefaultAzureCredential());
        var db = cosmosClient.GetDatabase("db");

        var container = db.GetContainer("container");
        logger.LogInformation($"Container: {container.Id}");

        var query = container.GetItemQueryIterator<dynamic>("SELECT * FROM c");
        var items = new List<dynamic>();
        
        while (query.HasMoreResults)
        {
            var response = await query.ReadNextAsync();
            logger.LogInformation("Reading next batch with length {count}", response.Count);
            
            items.AddRange(response);
        }
        
        logger.LogInformation("Items retrieved: {count}", items.Count);

        return Results.Ok(items);
    }
    catch (Exception ex)
    {
        logger.LogError("Exception: {message}, {innerMessage}", ex.Message, ex.InnerException?.Message);
        return Results.StatusCode(500);
    }
});

app.Run();