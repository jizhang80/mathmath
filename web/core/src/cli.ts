#!/usr/bin/env node
// Core's command-line entry point (D42): the Python pipeline invokes this; it never reimplements Core.
// Usage: node web/core/src/cli.ts schema <bundle-dir>
import { readdirSync, readFileSync } from "node:fs";
import { basename, join } from "node:path";
import { contractNames, validateContract, type ContractName } from "./contracts.ts";

function isContractName(name: string): name is ContractName {
  return (contractNames as string[]).includes(name);
}

function schemaCommand(dir: string): number {
  const files = readdirSync(dir).filter((f) => f.endsWith(".json"));
  if (files.length === 0) {
    console.error(`no JSON files in ${dir}`);
    return 1;
  }
  let failed = 0;
  for (const file of files) {
    const name = basename(file, ".json");
    if (!isContractName(name)) {
      console.error(`${file}: no contract schema named ${name}`);
      failed++;
      continue;
    }
    const result = validateContract(name, JSON.parse(readFileSync(join(dir, file), "utf8")));
    if (result.ok) {
      console.log(`${file}: ok`);
    } else {
      failed++;
      for (const e of result.errors) console.error(`${file}: ${e.instancePath || "/"} ${e.message ?? ""}`);
    }
  }
  return failed === 0 ? 0 : 1;
}

const [command, arg] = process.argv.slice(2);
if (command === "schema" && arg !== undefined) {
  process.exit(schemaCommand(arg));
}
console.error("usage: cli.ts schema <bundle-dir>");
process.exit(2);
