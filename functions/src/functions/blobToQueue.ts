import { app, HttpResponseInit, InvocationContext } from "@azure/functions";
import { QueueServiceClient } from "@azure/storage-queue";

export async function PushToQueue(blob: Buffer, context: InvocationContext): Promise<HttpResponseInit> {
  const queueName = "outqueue";
  const connection = process.env.StorageAccountConnectionString;
  try {
    if (!connection) {
      context.log("Storage account connection string is not defined in environment variables.");
      return { status: 500, body: "Internal Server Error" };
    }

    console.log("Creating queue service client");
    const queueServiceClient = QueueServiceClient.fromConnectionString(connection);
    console.log("Creating queue client");
    const queueClient = queueServiceClient.getQueueClient(queueName);
    console.log("Creating queue if not exists");
    await queueClient.createIfNotExists();

    console.log(`Sending message to queue: ${blob.toString()}`);
    await queueClient.sendMessage(blob.toString());
    return { status: 200, body: "Message added to queue" };
  } catch (error) {
    context.log(`Error: ${error}`);
    return { status: 500, body: "Internal Server Error" };
  }
}

app.storageBlob("PushToQueue", {
  path: "items/{name}",
  connection: "StorageAccountConnectionString",
  handler: PushToQueue,
});
