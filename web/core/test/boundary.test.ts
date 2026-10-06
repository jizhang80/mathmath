// I14: Core is renderer-free. The compile-time half is web/core/tsconfig.json (no DOM lib, no node
// types); this test is the import half: Core's library modules import only relative modules, the
// contract schemas and Ajv. cli.ts is the Node entry point and is exempt.
import { readdirSync, readFileSync } from "node:fs";
import { join, relative } from "node:path";
import { describe, expect, it } from "vitest";

const src = join(import.meta.dirname, "../src");

function sourceFiles(dir: string): string[] {
  return readdirSync(dir, { withFileTypes: true }).flatMap((e) =>
    e.isDirectory() ? sourceFiles(join(dir, e.name)) : e.name.endsWith(".ts") ? [join(dir, e.name)] : [],
  );
}

const allowed = (spec: string): boolean =>
  spec.startsWith("./") || spec.startsWith("../../../contracts/schemas/") || spec === "ajv/dist/2020.js";

describe("Core import boundary (I14)", () => {
  const files = sourceFiles(src).filter((f) => relative(src, f) !== "cli.ts");

  it("scans a non-empty set of library modules (empty = FAIL)", () => {
    expect(files.length).toBeGreaterThan(0);
  });

  it("imports nothing outside the allowlist", () => {
    const violations = files.flatMap((f) =>
      [...readFileSync(f, "utf8").matchAll(/\bfrom\s+"([^"]+)"/g)]
        .map((m) => m[1] ?? "")
        .filter((spec) => !allowed(spec))
        .map((spec) => `${relative(src, f)}: ${spec}`),
    );
    expect(violations).toEqual([]);
  });

  it("flags a forbidden import (negative control)", () => {
    expect(allowed("react")).toBe(false);
    expect(allowed("node:fs")).toBe(false);
  });
});
