import { app, InvocationContext } from "@azure/functions";
import { CosmosClient } from "@azure/cosmos";
import { randomUUID } from "crypto";

export async function queueToCosmos(queueItem: unknown, context: InvocationContext): Promise<void> {
  console.log("Received queue item: ", queueItem);
  context.log("Received queue item: ", queueItem);
  const dbName = "db";
  const containerName = "container";

  const connectionString = process.env.CosmosDbConnectionString;
  if (!connectionString) {
    console.log("Cosmos DB connection string is not defined in environment variables.");
    return;
  }

  const client = new CosmosClient(connectionString);
  const database = client.database(dbName);
  const container = database.container(containerName);

  try {
    const { resource: createdItem } = await container.items.create({ id: randomUUID(), data: queueItem });
    console.log(`Created item with id: ${createdItem.id}`);
  } catch (error) {
    console.log(`Error creating item: ${error}`);
  }
}

app.storageQueue("queueToCosmos", {
  queueName: "outqueue",
  connection: "StorageAccountConnectionString",
  handler: queueToCosmos,
});
