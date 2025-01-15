using System.Text;
using api;
using Azure.Storage.Blobs;
using Microsoft.AspNetCore.Mvc;
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
    const string containerName = "items";
    var config = sp.GetRequiredService<AppConfig>();
    
    var client = new BlobContainerClient(config.BlobStorageConnectionString, containerName);
    client.CreateIfNotExists();

    return client;
});

builder.Services.AddLogging(b => {
    b.AddConsole();
});

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c => 
{
    c.SwaggerDoc("v1", new() { Title = "My API", Version = "v1" });
});

var app = builder.Build();

app.UseHttpsRedirection();

app.UseMiddleware<RateLimitingMiddleware>();

app.UseSwagger();

app.UseSwaggerUI(c => 
{
    c.SwaggerEndpoint("/swagger/v1/swagger.json", "My API V1");
    c.RoutePrefix = string.Empty;
});

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

        var query = container.GetItemQueryIterator<Model>("SELECT * FROM c");
        var items = new List<Model>();
        
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