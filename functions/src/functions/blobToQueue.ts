import { app, HttpResponseInit, InvocationContext } from "@azure/functions";
import { QueueServiceClient } from "@azure/storage-queue";

export async function pushToQueue(blob: Buffer, context: InvocationContext): Promise<HttpResponseInit> {
  const blobData = blob.toString();
  context.log("Received blob: ", blobData);

  const base64EncodedData = Buffer.from(blobData).toString("base64");
  context.log("Base64 encoded data: ", base64EncodedData);

  const queueName = "outqueue";
  const connection = process.env.AzureWebJobsStorage;

  if (!connection) {
    context.log("Storage account connection string is not defined in environment variables.");
    return { status: 500, body: "Internal Server Error" };
  }

  try {
    const queueServiceClient = QueueServiceClient.fromConnectionString(connection);
    const queueClient = queueServiceClient.getQueueClient(queueName);
    await queueClient.createIfNotExists();

    console.log(`Sending message to queue: ${base64EncodedData}`);
    await queueClient.sendMessage(base64EncodedData);
    return { status: 200, body: "Message added to queue" };
  } catch (error) {
    context.log(`Error: ${error}`);
    return { status: 500, body: "Internal Server Error" };
  }
}

app.storageBlob("pushToQueue", {
  path: "items/{name}",
  connection: "AzureWebJobsStorage",
  handler: pushToQueue,
});
