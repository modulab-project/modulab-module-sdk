// Minimal example — rename to App.tsx and build out your own UI from here.
//
// Import react/react-dom/i18next/react-i18next normally; vite.config.ts's
// aliases route them to src/host-shims/* at build time, so you always get
// Core's own shared instances instead of a bundled copy. See the comment
// in vite.config.ts for why that matters.
import { useEffect, useState } from "react";
import { useTranslation } from "react-i18next";
import type { ModuleComponentProps } from "./types";

// Namespace Core preloaded your locales under — see
// modulab-core/frontend/src/pages/ModulePage.tsx. Must match your
// manifest's module name.
const NS = "mod_example";

export default function ExampleModule({ apiBase, token }: ModuleComponentProps) {
  const { t } = useTranslation(NS);
  const [data, setData] = useState<unknown>(null);

  useEffect(() => {
    fetch(`${apiBase}/example`, { headers: { Authorization: `Bearer ${token}` } })
      .then((res) => res.json())
      .then(setData)
      .catch(console.error);
  }, [apiBase, token]);

  return (
    <div style={{ padding: 16 }}>
      <h1>{t("title")}</h1>
      <pre>{JSON.stringify(data, null, 2)}</pre>
    </div>
  );
}
