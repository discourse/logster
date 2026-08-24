import assert from "node:assert/strict";
import { chmodSync, mkdirSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { mkdtemp, rm } from "node:fs/promises";
import {
  dependenciesAreCurrent,
  packageLockDigest,
} from "./ensure-dependencies.mjs";

async function fixture() {
  const directory = await mkdtemp(join(tmpdir(), "logster-dependencies-"));
  const lockfile = join(directory, "package-lock.json");
  const stamp = join(directory, "node_modules/.logster-package-lock.sha256");
  const ember = join(directory, "node_modules/.bin/ember");
  mkdirSync(join(directory, "node_modules/.bin"), { recursive: true });
  writeFileSync(lockfile, '{"lockfileVersion":3}\n');
  writeFileSync(ember, "#!/bin/sh\n");
  chmodSync(ember, 0o755);
  return { directory, lockfile, stamp, ember };
}

test("dependencies are current only when the lock digest and Ember executable match", async (t) => {
  const paths = await fixture();
  t.after(() => rm(paths.directory, { recursive: true, force: true }));

  assert.equal(await dependenciesAreCurrent(paths), false, "a missing stamp installs");

  writeFileSync(paths.stamp, `${packageLockDigest(paths.lockfile)}\n`);
  assert.equal(await dependenciesAreCurrent(paths), true, "a matching install is reused");

  writeFileSync(paths.lockfile, '{"lockfileVersion":4}\n');
  assert.equal(await dependenciesAreCurrent(paths), false, "a changed lockfile installs");
});
