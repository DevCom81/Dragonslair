import { afterEach, describe, expect, test } from "vitest";
import {
  DOWNLOAD_EXPIRES_SECONDS,
  WINDOWS_DOWNLOAD_FILENAME,
  isWindowsDownloadConfigured,
  windowsContentDisposition,
  windowsPresignRequest,
} from "./windowsDownload";
import { DownloadConfigError, WINDOWS_DOWNLOAD_UNAVAILABLE } from "./errors";

const ENV = {
  R2_ACCESS_KEY_ID: "test-access-key",
  R2_SECRET_ACCESS_KEY: "test-secret-key",
  R2_ENDPOINT: "https://example.r2.cloudflarestorage.com/",
  R2_BUCKET: "dragonslair-release",
  R2_WINDOWS_OBJECT: "windows/Install_Dragonslair.exe",
};

function setR2Env() {
  process.env.R2_ACCESS_KEY_ID = ENV.R2_ACCESS_KEY_ID;
  process.env.R2_SECRET_ACCESS_KEY = ENV.R2_SECRET_ACCESS_KEY;
  process.env.R2_ENDPOINT = ENV.R2_ENDPOINT;
  process.env.R2_BUCKET = ENV.R2_BUCKET;
  process.env.R2_WINDOWS_OBJECT = ENV.R2_WINDOWS_OBJECT;
}

afterEach(() => {
  for (const key of Object.keys(ENV)) {
    delete process.env[key];
  }
});

describe("windows download helper", () => {
  test("15 missing config is a safe error", () => {
    expect(isWindowsDownloadConfigured()).toBe(false);
    expect(() => windowsPresignRequest()).toThrow(DownloadConfigError);
    expect(() => windowsPresignRequest()).toThrow(WINDOWS_DOWNLOAD_UNAVAILABLE);
  });

  test("11-14 server-owned bucket key GET expiry and filename", () => {
    setR2Env();
    const request = windowsPresignRequest();
    expect(request.bucket).toBe("dragonslair-release");
    expect(request.key).toBe("windows/Install_Dragonslair.exe");
    expect(request.expiresIn).toBe(DOWNLOAD_EXPIRES_SECONDS);
    expect(request.expiresIn).toBe(300);
    expect(request.endpoint).toBe("https://example.r2.cloudflarestorage.com");
    expect(request.forcePathStyle).toBe(true);
    expect(request.responseContentDisposition).toContain("attachment");
    expect(request.responseContentDisposition).toContain(
      WINDOWS_DOWNLOAD_FILENAME,
    );
    expect(windowsContentDisposition()).toBe(
      `attachment; filename="${WINDOWS_DOWNLOAD_FILENAME}"`,
    );
  });
});
