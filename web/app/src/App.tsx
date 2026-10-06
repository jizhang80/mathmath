import { validateContract } from "@mathmath/core";
import nodes from "../../../data/demo/nodes.json";

// Toolchain shell only: proves the app ↔ Core seam (the demo bundle is validated by Core before use).
// The Demo EPICs replace this with the map.
export function App() {
  const result = validateContract("nodes", nodes);
  return (
    <main>
      <h1>mathmath</h1>
      <p data-testid="bundle-status">
        {result.ok ? `Demo bundle: ${String(result.value.nodes.length)} nodes` : "Demo bundle invalid"}
      </p>
    </main>
  );
}
