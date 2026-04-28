// Azure Function App - Blob Trigger Example
// File: src/functions/processImage.ts
// This function processes images uploaded to blob storage (e.g., resizing)

import { app, InvocationContext } from "@azure/functions";
import { BlobClient, BlobServiceClient } from "@azure/storage-blob";
import sharp from "sharp";

export async function processImage(
  blob: Buffer,
  context: InvocationContext
): Promise<void> {
  context.log("Image processing triggered for blob:", context.triggerMetadata.name);

  try {
    // Extract blob name
    const blobName = context.triggerMetadata.name;
    const blobPath = blobName.split("/");
    const fileName = blobPath[blobPath.length - 1];
    const folder = blobPath.length > 1 ? blobPath[0] : "images";

    context.log(`Processing image: ${fileName} from folder: ${folder}`);

    // Validate it's an image
    if (!fileName.match(/\.(jpg|jpeg|png|gif)$/i)) {
      context.log("File is not an image, skipping processing");
      return;
    }

    // Create multiple versions of the image
    const sizes = [
      { width: 200, height: 200, suffix: "-thumb" },
      { width: 500, height: 500, suffix: "-small" },
      { width: 1000, height: 1000, suffix: "-medium" },
    ];

    const blobServiceClient = BlobServiceClient.fromConnectionString(
      process.env.AzureWebJobsStorage!
    );
    const containerClient = blobServiceClient.getContainerClient("app-blobs");

    for (const size of sizes) {
      try {
        // Resize image using sharp
        const resizedImage = await sharp(blob)
          .resize(size.width, size.height, {
            fit: "contain",
            background: { r: 255, g: 255, b: 255, alpha: 1 },
          })
          .toBuffer();

        // Generate new filename
        const nameParts = fileName.split(".");
        const extension = nameParts.pop();
        const baseName = nameParts.join(".");
        const resizedFileName = `${baseName}${size.suffix}.${extension}`;
        const resizedBlobName = `${folder}/${resizedFileName}`;

        // Upload resized image
        const blockBlobClient = containerClient.getBlockBlobClient(resizedBlobName);
        await blockBlobClient.upload(resizedImage, resizedImage.length, {
          blobHTTPHeaders: {
            blobContentType: getMimeType(extension),
            blobCacheControl: "public, max-age=86400", // 1 day cache
          },
          metadata: {
            "original-name": fileName,
            "processed-at": new Date().toISOString(),
            "size": `${size.width}x${size.height}`,
          },
        });

        context.log(`Created resized image: ${resizedBlobName}`);
      } catch (sizeError) {
        context.error(`Error creating ${size.width}x${size.height} version:`, sizeError);
      }
    }

    context.log(`Image processing completed for: ${fileName}`);
  } catch (error) {
    context.error("Error processing image:", error);
    throw error;
  }
}

// Timer trigger for scheduled image cleanup (optional)
export async function cleanupOldImages(
  myTimer: any,
  context: InvocationContext
): Promise<void> {
  context.log("Image cleanup triggered by timer");

  try {
    const blobServiceClient = BlobServiceClient.fromConnectionString(
      process.env.AzureWebJobsStorage!
    );
    const containerClient = blobServiceClient.getContainerClient("app-blobs");

    // Get blobs older than 30 days
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    let deletedCount = 0;

    for await (const blob of containerClient.listBlobsFlat()) {
      if (blob.properties.createdOn && blob.properties.createdOn < thirtyDaysAgo) {
        try {
          await containerClient.deleteBlob(blob.name);
          deletedCount++;
          context.log(`Deleted old blob: ${blob.name}`);
        } catch (deleteError) {
          context.error(`Error deleting blob ${blob.name}:`, deleteError);
        }
      }
    }

    context.log(`Cleanup completed: ${deletedCount} blobs deleted`);
  } catch (error) {
    context.error("Error during cleanup:", error);
    throw error;
  }
}

// Helper function to get MIME type
function getMimeType(extension: string | undefined): string {
  const mimeTypes: Record<string, string> = {
    jpg: "image/jpeg",
    jpeg: "image/jpeg",
    png: "image/png",
    gif: "image/gif",
  };
  return mimeTypes[extension?.toLowerCase() || ""] || "application/octet-stream";
}

// Register blob trigger
app.storageBlob("processImage", {
  path: "app-blobs/{name}",
  connection: "AzureWebJobsStorage",
  handler: processImage,
});

// Register timer trigger (runs daily at 2 AM UTC)
app.timer("cleanupOldImages", {
  schedule: "0 0 2 * * *", // Cron format: 2 AM every day
  handler: cleanupOldImages,
});
