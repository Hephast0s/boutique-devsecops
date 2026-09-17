# PHASE-12/13 REPORT — Portal Integration, Documentation & Packaging

Date: 2026-09-16 · Branch: `phase-12-13-docs`

## 12 — Backstage

- `catalog-info.yaml` defines a System, a gRPC API, and a Component per service (11 + redis-cart + the
  excluded assistant), with owners, lifecycle, Kubernetes annotations and `dependsOn` edges.
- `mkdocs.yml` configures TechDocs.
- **Registration not performed:** the Backstage portal location config is shared config and no portal token
  was provided → CR-WEB-1. Existing entries untouched.

## 13 — Documentation & packaging

Delivered (root + `docs/`):

| Artefact | Purpose |
|---|---|
| `README.md` | portfolio entry point, architecture + pipeline, live URLs, honest limitations |
| `docs/ARCHITECTURE.md` | as-built topology |
| `docs/SECURITY.md` | control catalogue mapped to threat IDs + verification |
| `docs/EVIDENCE.md` | indexed evidence bundle |
| `docs/METRICS.md` | measured outcomes |
| `docs/COMPARISON.md` | honest comparison with the previous project |
| `docs/DEMO.md` | 10-minute walkthrough |
| `docs/INTERVIEW-NOTES.md` | 20 grounded Q&A |
| `docs/runbooks/` | failed-deploy, rollback, secret-leak |
| `docs/adr/README.md` | ADR index + open decisions |
| `docs/STATE.md`, `CHANGE_LOG.md`, `ROLLBACK.md`, `CHANGE_REQUESTS.md`, `ISSUES` | governance |

## Definition of Done

| Item | Status |
|---|---|
| Reader can understand/reproduce from docs alone | ✅ (with documented gaps) |
| Every claim backed by an artefact | ✅ (`docs/EVIDENCE.md`) |
| Catalog files delivered | ✅; registration pending CR-WEB-1 |

## Final branch

The operator asked for a **final integrated branch**. `devsecops` is the integration branch; it contains
all phases. (A `final` tag/branch can be cut by the operator once the open change requests are decided.)
