import { DownloadConfigError, WINDOWS_DOWNLOAD_UNAVAILABLE } from "./errors";

export const DOWNLOAD_EXPIRES_SECONDS = 300;
export const WINDOWS_DOWNLOAD_FILENAME = "Install_Dragonslair.exe";
export const WINDOWS_DOWNLOAD_REGION = "auto";

export type WindowsPresignRequest = {
  bucket: string;
  key: string;
  expiresIn: number;
  responseContentDisposition: string;
  endpoint: string;
  region: string;
  forcePathStyle: true;
};

function envValue(name: string) {
  return (process.env[name] ?? "").trim();
}

export function r2AccessKeyId() {
  return envValue("R2_ACCESS_KEY_ID");
}

export function r2SecretAccessKey() {
  return envValue("R2_SECRET_ACCESS_KEY");
}

export function r2Endpoint() {
  return envValue("R2_ENDPOINT").replace(/\/+$/, "");
}

export function r2Bucket() {
  return envValue("R2_BUCKET");
}

export function r2WindowsObject() {
  return envValue("R2_WINDOWS_OBJECT");
}

export function isWindowsDownloadConfigured() {
  return Boolean(
    r2AccessKeyId() &&
      r2SecretAccessKey() &&
      r2Endpoint() &&
      r2Bucket() &&
      r2WindowsObject(),
  );
}

export function windowsContentDisposition() {
  return `attachment; filename="${WINDOWS_DOWNLOAD_FILENAME}"`;
}

export function windowsPresignRequest(): WindowsPresignRequest {
  if (!isWindowsDownloadConfigured()) {
    throw new DownloadConfigError(WINDOWS_DOWNLOAD_UNAVAILABLE);
  }
  return {
    bucket: r2Bucket(),
    key: r2WindowsObject(),
    expiresIn: DOWNLOAD_EXPIRES_SECONDS,
    responseContentDisposition: windowsContentDisposition(),
    endpoint: r2Endpoint(),
    region: WINDOWS_DOWNLOAD_REGION,
    forcePathStyle: true,
  };
}
