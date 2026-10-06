// Boundary validation (D32 constraint b): every bundle file and the stored student state is validated
// against its JSON Schema in contracts/schemas/ before Core uses it.
import { Ajv2020, type ErrorObject, type ValidateFunction } from "ajv/dist/2020.js";
import courses from "../../../contracts/schemas/courses.schema.json" with { type: "json" };
import edges from "../../../contracts/schemas/edges.schema.json" with { type: "json" };
import landmarks from "../../../contracts/schemas/landmarks.schema.json" with { type: "json" };
import manifest from "../../../contracts/schemas/manifest.schema.json" with { type: "json" };
import nodes from "../../../contracts/schemas/nodes.schema.json" with { type: "json" };
import regions from "../../../contracts/schemas/regions.schema.json" with { type: "json" };
import sources from "../../../contracts/schemas/sources.schema.json" with { type: "json" };
import studentState from "../../../contracts/schemas/student-state.schema.json" with { type: "json" };
import telemetryBatch from "../../../contracts/schemas/telemetry-batch.schema.json" with { type: "json" };
import type * as Contract from "./generated/contracts.ts";

export interface ContractTypes {
  courses: Contract.Courses;
  edges: Contract.Edges;
  landmarks: Contract.Landmarks;
  manifest: Contract.Manifest;
  nodes: Contract.Nodes;
  regions: Contract.Regions;
  sources: Contract.Sources;
  "student-state": Contract.StudentState;
  "telemetry-batch": Contract.TelemetryBatch;
}
export type ContractName = keyof ContractTypes;

const schemas: Record<ContractName, object> = {
  courses,
  edges,
  landmarks,
  manifest,
  nodes,
  regions,
  sources,
  "student-state": studentState,
  "telemetry-batch": telemetryBatch,
};

export const contractNames = Object.keys(schemas) as ContractName[];

// strictRequired is off: the contracts use `anyOf: [{ required: [...] }, ...]` (a node carries
// expectation_codes or source_ref, I8), which is valid JSON Schema but trips Ajv's extra strictness.
const ajv = new Ajv2020({ allErrors: true, strict: true, strictRequired: false });
const validators = new Map<ContractName, ValidateFunction>();

export type Validation<T> = { ok: true; value: T } | { ok: false; errors: readonly ErrorObject[] };

export function validateContract<N extends ContractName>(
  name: N,
  data: unknown,
): Validation<ContractTypes[N]> {
  let validate = validators.get(name);
  if (validate === undefined) {
    validate = ajv.compile(schemas[name]);
    validators.set(name, validate);
  }
  if (validate(data)) return { ok: true, value: data as ContractTypes[N] };
  return { ok: false, errors: validate.errors ?? [] };
}
