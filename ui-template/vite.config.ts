import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { resolve } from "path";

// Build the module UI as a single ES module bundle.
//
// React, ReactDOM, i18next and react-i18next are NOT bundled — Core's own
// frontend exposes its own instances via window.__MODULAB_HOST__ (set in
// modulab-core/frontend/src/main.tsx), and this config aliases each package
// to a local shim file (src/host-shims/*.ts) that just re-exports from that
// object.
//
// This is required, not optional: ModulePage.tsx renders your exported
// component directly inside Core's own React tree (no iframe). If your
// bundle brings its own copy of React instead of reusing the host's, you end
// up with two separate React instances in the same tree. Hooks break
// silently in that situation (dispatcher mismatch) — no error, just a blank
// page. Aliasing to the host-shims is what prevents that.
export default defineConfig({
  plugins: [react()],
  define: {
    "process.env.NODE_ENV": JSON.stringify("production"),
  },
  resolve: {
    alias: {
      "react/jsx-runtime": resolve(__dirname, "src/host-shims/react-jsx-runtime.ts"),
      "react-dom":         resolve(__dirname, "src/host-shims/react-dom.ts"),
      "react":             resolve(__dirname, "src/host-shims/react.ts"),
      "react-i18next":     resolve(__dirname, "src/host-shims/react-i18next.ts"),
      "i18next":           resolve(__dirname, "src/host-shims/i18next.ts"),
    },
  },
  build: {
    lib: {
      entry: "src/main.tsx",
      // Rename to your own module, e.g. "MyModule" — used only as the UMD/
      // global fallback name, harmless to leave as-is for the "es" format.
      name: "ModuleUI",
      fileName: () => "bundle.js",
      formats: ["es"],
    },
    // Core loads DataDir/{module}/bundle/bundle.js — build output must land
    // in ../bundle relative to this ui/ directory, not alongside src/.
    outDir: "../bundle",
    emptyOutDir: true,
  },
});
