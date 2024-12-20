using Azure.Storage.Blobs;

public class BlobClient {
    public BlobClient(IConfiguration config)
    {
        const string connectionStringKey = "BlobStorage:ConnectionString";
        var connectionString = config[connectionStringKey] ?? throw new ArgumentNullException(connectionStringKey);
        
        var client = new BlobServiceClient(connectionString);

    }
}