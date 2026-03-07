# Workflow control plane (note)

Narativni poznamka k novemu diagramovemu SSOT (`docs_control/workflow_control_plane.json`).

Aktualni stav:

- D1-D6 baseline hotovy (schema + canonical model + coverage validator +
  observed manifests + alignment validator + generator/stale-check + verify/CI
  integrace).
- Model je stale `DRAFT`, ale uz pokryva take self-hosting diagram subsystem
  (observed manifests, alignment, diagram generator/stale-check, claim=evidence
  guard, fast runtime checks) a je napojen do gate.
- Novy `Capability audit gate` (tools + sources) je uz soucast verify/CI poradi
  a je propsany do canonical graphu pred `preflight` krokem.
- Generator umi deterministicky vytvorit Mermaid/DOT/Markdown a realne SVG pres
  Graphviz `dot` (s fallback placeholder SVG v prostredi bez Graphviz).

Zamer:

- 1 canonical full graph z JSON SSOT
- vice generated view (Mermaid/DOT/SVG/MD)
- blocking validace: schema + integrita + coverage + alignment + stale-check

Poznamka:

- `workflow-steps.json` je legacy reference a nema byt dal pouzivan jako SSOT pro novy system diagramu.
- Dalsi krok: pripadne formalne povysit model z `DRAFT` na `APPROVED` po lidskem schvaleni a doplnit renderer version pinning policy do schema/modelu.
