
import crypto from "crypto";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import type { Role } from "../domain/types";

export interface StoredFile {
  id: string;
  name: string;
  mimeType: string;
  size: number;
  path: string;
  uploadedAt: string;
  uploadedByUserId: string;
}

export class FileStorageService {
  private readonly rootDir = path.join(process.cwd(), "data", "files");
  private readonly metadataPath = path.join(this.rootDir, "metadata.json");

  private async readMetadata(): Promise<StoredFile[]> {
    try {
      const data = await readFile(this.metadataPath, "utf8");
      return JSON.parse(data) as StoredFile[];
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code === "ENOENT") {
        return [];
      }
      throw error;
    }
  }

  private async writeMetadata(files: StoredFile[]): Promise<void> {
    await mkdir(this.rootDir, { recursive: true });
    await writeFile(this.metadataPath, JSON.stringify(files, null, 2), "utf8");
  }

  async saveFile(input: {
    name: string;
    mimeType: string;
    contentBase64: string;
    uploadedByUserId: string;
  }): Promise<StoredFile> {
    await mkdir(this.rootDir, { recursive: true });

    const id = crypto.randomUUID();
    const safeName = input.name.replace(/[^a-zA-Z0-9._-]/g, "_");
    const fileName = `${id}-${safeName}`;
    const filePath = path.join(this.rootDir, fileName);
    const buffer = Buffer.from(input.contentBase64, "base64");

    if (buffer.length === 0) {
      throw new Error("Uploaded file is empty or invalid.");
    }

    await writeFile(filePath, buffer);

    const file: StoredFile = {
      id,
      name: input.name,
      mimeType: input.mimeType,
      size: buffer.length,
      path: filePath,
      uploadedAt: new Date().toISOString(),
      uploadedByUserId: input.uploadedByUserId
    };

    const files = await this.readMetadata();
    files.push(file);
    await this.writeMetadata(files);

    return file;
  }

  async upload(input: {
    name: string;
    mimeType: string;
    contentBase64: string;
    uploadedByUserId: string;
  }): Promise<StoredFile> {
    return this.saveFile(input);
  }

  listFiles(userId: string, role: Role): StoredFile[] {
    // Admins can list all files; other users see only their own uploads.
    // This is a synchronous compatibility method; metadata is loaded separately
    // by listFilesAsync when asynchronous storage is required.
    if (role === "admin") {
      return this.cachedFiles;
    }
    return this.cachedFiles.filter((file) => file.uploadedByUserId === userId);
  }

  private cachedFiles: StoredFile[] = [];

  async listFilesAsync(userId: string, role: Role): Promise<StoredFile[]> {
    const files = await this.readMetadata();
    this.cachedFiles = files;

    if (role === "admin") {
      return files;
    }

    return files.filter((file) => file.uploadedByUserId === userId);
  }

  async readFile(filePath: string): Promise<Buffer> {
    return readFile(filePath);
  }
}
