import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { contractNames, validateContract, type ContractName } from "../src/contracts.ts";

const demo = join(import.meta.dirname, "../../../data/demo");
const bundleFiles: ContractName[] = [
  "courses",
  "edges",
  "landmarks",
  "manifest",
  "nodes",
  "regions",
  "sources",
];

function load(name: string): unknown {
  return JSON.parse(readFileSync(join(demo, `${name}.json`), "utf8"));
}

describe("contract validation over data/demo", () => {
  it("covers every schema in contracts/schemas", () => {
    expect(contractNames).toHaveLength(9);
  });

  it.each(bundleFiles)("%s.json validates against its schema", (name) => {
    const result = validateContract(name, load(name));
    expect(result.ok ? [] : result.errors).toEqual([]);
  });

  it("rejects a node that carries neither expectation_codes nor source_ref (negative control, I8)", () => {
    const data = load("nodes") as { nodes: Record<string, unknown>[] };
    const first = data.nodes[0];
    expect(first).toBeDefined();
    delete first?.["expectation_codes"];
    delete first?.["source_ref"];
    expect(validateContract("nodes", data).ok).toBe(false);
  });
});
