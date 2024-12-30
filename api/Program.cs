using System.Text;
using System.Threading.RateLimiting;
using api;
using Azure.Storage.Blobs;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.Azure.Cosmos;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddSingleton<AppConfig>();

builder.Services.AddSingleton<CosmosClient>(sp =>
{
    var config = sp.GetRequiredService<AppConfig>();
    return new CosmosClient(config.CosmosDbConnectionString);
});

builder.Services.AddSingleton<BlobContainerClient>(sp =>
{
    var config = sp.GetRequiredService<AppConfig>();
    
    var client = new BlobContainerClient(config.BlobStorageConnectionString, "items");
    client.CreateIfNotExists();

    return client;
});

builder.Services.AddLogging(b => {
    b.AddConsole();
});

builder.Services.AddRateLimiter(o =>
{
    o.AddFixedWindowLimiter(policyName: "fixed", options =>
    {
        options.PermitLimit = 1;
        options.QueueLimit = 1;
        options.Window = TimeSpan.FromSeconds(5);
        options.QueueProcessingOrder = QueueProcessingOrder.OldestFirst;
    });
});

var app = builder.Build();

app.UseHttpsRedirection();

app.UseRateLimiter();

app.MapPost("upload", async ([FromQuery]string value, BlobContainerClient blobContainerClient, ILogger<Program> logger) =>
{
    try 
    {
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

app.MapGet("list", async (CosmosClient cosmosClient, ILogger<Program> logger) =>
{
    try 
    {
        var db = cosmosClient.GetDatabase("db");

        var container = db.GetContainer("container");

        var query = container.GetItemQueryIterator<dynamic>("SELECT * FROM c");
        var items = new List<dynamic>();
        
        while (query.HasMoreResults)
        {
            var response = await query.ReadNextAsync();
            
            items.AddRange(response);
        }
        
        return Results.Ok(items);
    }
    catch (Exception ex)
    {
        logger.LogError("Exception: {message}, {innerMessage}", ex.Message, ex.InnerException?.Message);
        return Results.StatusCode(500);
    }
});

app.Run();