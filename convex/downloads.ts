"use node";

import { GetObjectCommand, S3Client } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import { action } from "./_generated/server";
import { internal } from "./_generated/api";
import {
  DownloadConfigError,
  ForbiddenError,
  FULL_GAME_REQUIRED,
  WINDOWS_DOWNLOAD_UNAVAILABLE,
} from "./lib/errors";
import {
  r2AccessKeyId,
  r2SecretAccessKey,
  windowsPresignRequest,
} from "./lib/windowsDownload";

export const createWindowsDownload = action({
  args: {},
  handler: async (ctx): Promise<{ download_url: string }> => {
    const user = await ctx.runQuery(internal.downloadAccess.authedUser, {});
    if (user.access !== "full") {
      throw new ForbiddenError(FULL_GAME_REQUIRED);
    }
    const request = windowsPresignRequest();
    try {
      const client = new S3Client({
        region: request.region,
        endpoint: request.endpoint,
        forcePathStyle: request.forcePathStyle,
        credentials: {
          accessKeyId: r2AccessKeyId(),
          secretAccessKey: r2SecretAccessKey(),
        },
      });
      const download_url = await getSignedUrl(
        client,
        new GetObjectCommand({
          Bucket: request.bucket,
          Key: request.key,
          ResponseContentDisposition: request.responseContentDisposition,
        }),
        { expiresIn: request.expiresIn },
      );
      if (
        typeof download_url !== "string" ||
        (!download_url.startsWith("https://") &&
          !download_url.startsWith("http://"))
      ) {
        throw new DownloadConfigError(WINDOWS_DOWNLOAD_UNAVAILABLE);
      }
      return { download_url };
    } catch (error) {
      if (error instanceof DownloadConfigError) {
        throw error;
      }
      throw new DownloadConfigError(WINDOWS_DOWNLOAD_UNAVAILABLE);
    }
  },
});
