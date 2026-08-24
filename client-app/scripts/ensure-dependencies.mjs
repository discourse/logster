#!/usr/bin/env node

import { createHash } from "node:crypto";
import { constants, existsSync, readFileSync, writeFileSync } from "node:fs";
import { access } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath, pathToFileURL } from "node:url";

export function packageLockDigest(lockfile) {
  return createHash("sha256").update(readFileSync(lockfile)).digest("hex");
}

export async function dependenciesAreCurrent({ lockfile, stamp, ember }) {
  if (!existsSync(stamp)) {
    return false;
  }

  try {
    await access(ember, constants.X_OK);
  } catch {
    return false;
  }

  return readFileSync(stamp, "utf8").trim() === packageLockDigest(lockfile);
}

export async function ensureDependencies(clientDirectory) {
  const lockfile = resolve(clientDirectory, "package-lock.json");
  const stamp = resolve(clientDirectory, "node_modules/.logster-package-lock.sha256");
  const ember = resolve(clientDirectory, "node_modules/.bin/ember");

  if (await dependenciesAreCurrent({ lockfile, stamp, ember })) {
    console.log("✓ Frontend dependencies are current");
    return;
  }

  console.log("Installing frontend dependencies...");
  const result = spawnSync("npm", ["ci"], {
    cwd: clientDirectory,
    shell: process.platform === "win32",
    stdio: "inherit",
  });
  if (result.error) {
    throw result.error;
  }
  if (result.status !== 0) {
    throw new Error(`npm ci failed with status ${result.status}`);
  }

  writeFileSync(stamp, `${packageLockDigest(lockfile)}\n`);
  console.log("✓ Frontend dependencies are current");
}

async function main() {
  const scriptDirectory = dirname(fileURLToPath(import.meta.url));
  await ensureDependencies(resolve(scriptDirectory, ".."));
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  });
}
