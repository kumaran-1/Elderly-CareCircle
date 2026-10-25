import crypto from "crypto";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";

export interface StoredFile {
  id: string;
  name: string;
  mimeType: string;
  size: number;
  path: string;
  uploadedAt: string;
}

export class FileStorageService {
  private readonly rootDir = path.join(process.cwd(), "data", "files");

  async saveFile(input: { name: string; mimeType: string; contentBase64: string }): Promise<StoredFile> {
    await mkdir(this.rootDir, { recursive: true });
    const id = crypto.randomUUID();
    const safeName = input.name.replace(/[^a-zA-Z0-9._-]/g, "_");
    const fileName = `${id}-${safeName}`;
    const filePath = path.join(this.rootDir, fileName);
    const buffer = Buffer.from(input.contentBase64, "base64");
    await writeFile(filePath, buffer);
    return {
      id,
      name: input.name,
      mimeType: input.mimeType,
      size: buffer.length,
      path: filePath,
      uploadedAt: new Date().toISOString()
    };
  }

  async readFile(filePath: string): Promise<Buffer> {
    return readFile(filePath);
  }
}
