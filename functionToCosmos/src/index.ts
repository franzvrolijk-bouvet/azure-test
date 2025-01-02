import { AzureFunction, Context } from "@azure/functions";
import { CosmosClient } from "@azure/cosmos";

const queueTrigger: AzureFunction = async function (context: Context, myQueueItem: any): Promise<void> {
  const endpoint = process.env.COSMOS_DB_ENDPOINT;
  const key = process.env.COSMOS_DB_KEY;
  const databaseId = process.env.COSMOS_DB_DATABASE_ID;
  const containerId = process.env.COSMOS_DB_CONTAINER_ID;

  const client = new CosmosClient({ endpoint, key });
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
