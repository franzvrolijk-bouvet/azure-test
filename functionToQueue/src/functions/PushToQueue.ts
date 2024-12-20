import {
    app,
    output,
    HttpResponseInit,
    InvocationContext,
    StorageQueueOutput,
  } from '@azure/functions';
  
  const sendToQueue: StorageQueueOutput = output.storageQueue({
    queueName: 'outqueue',
    connection: 'OutputQueue',
  });
  
  export async function PushToQueue(blob: Buffer, context: InvocationContext): Promise<HttpResponseInit> {
    try {  
    // Read string content from the blob
    const content = blob.toString();
    context.log(`Received content: ${content}`);

      if (content) {
        context.extraOutputs.set(sendToQueue, [content]);
        context.log('Data sent to the queue');
        return { body: content };
      } else {
        context.log('Missing required data');
        return { status: 404, body: 'Missing required data' };
      }
    } catch (error) {
      context.log(`Error: ${error}`);
      return { status: 500, body: 'Internal Server Error' };
    }
  }
  
 app.storageBlob('PushToQueue', {
    path: 'items/{name}',
    connection: 'AzureWebJobsStorage',
    handler: PushToQueue
});

