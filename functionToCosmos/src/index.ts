import { AzureFunction, Context } from "@azure/functions";
import { CosmosClient } from "@azure/cosmos";

const queueTrigger: AzureFunction = async function (context: Context, myQueueItem: any): Promise<void> {
  const databaseId = "db";
  const containerId = "container";

  const connectionString = process.env.COSMOS_DB_CONNECTION_STRING;
  if (!connectionString) {
    context.log("Cosmos DB connection string is not defined in environment variables.");
    return;
  }

  const client = new CosmosClient(connectionString);
  const database = client.database(databaseId);
  const container = database.container(containerId);

  try {
    const { resource: createdItem } = await container.items.create(myQueueItem);
    context.log(`Created item with id: ${createdItem.id}`);
  } catch (error) {
    context.log(`Error creating item: ${error}`);
  }
};

export default queueTrigger;
