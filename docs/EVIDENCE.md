# EVIDENCE — indexed bundle

Every claim maps to an artefact. Paths are relative to the repo; screenshots are under `docs/evidence/`.

| Area | Claim | Evidence |
|---|---|---|
| Application analysis | 12 services documented | `docs/00-application-analysis.md`, `ci/services.yaml` |
| Threat model | 20 application-specific risks mapped to controls | `docs/00-threat-model.md` |
| Infrastructure | read-only inventory; pre-engagement export | `docs/01-infrastructure-inventory.md`, `docs/evidence/pre-engagement/` |
| Egress | cluster egress verified in-cluster | `docs/01-agent-capabilities.md` |
| Git controls | protected branches, signed commits, pre-commit | `docs/phases/PHASE-2-REPORT.md` |
| Baseline (dev) | 11/11 ready + full checkout | `docs/phases/PHASE-3-REPORT.md`, `docs/evidence/phase3/` |
| CI | Jenkins build #5 SUCCESS; Kaniko; no docker socket | `docs/evidence/phase4/console-build5.txt` |
| Supply chain | SBOM + cosign verify for 2 services; gate blocked shippingservice | `docs/evidence/phase5/` (console-build11, cosign-verify, zaps) |
| Secrets | Vault+ESO rotation + cross-ns denial | `docs/phases/PHASE-6-REPORT.md` |
| GitOps | dev/staging/prod Synced; drift self-heal; Git rollback | `docs/phases/PHASE-7-REPORT.md`, `docs/evidence/` |
| Policy | rejection transcripts (foreign image, `:latest`, privileged, no-limits) | `docs/evidence/phase8/rejection-tests.txt` |
| Network | allowed/blocked connectivity transcript | `docs/evidence/phase9/netpol-tests.txt` |
| Dynamic testing | smoke 7/7; ZAP FAIL-NEW=0 + triage; latency baseline | `docs/evidence/phase10/` (ZAP html/json) |
| Observability | dashboard imported; alerts loaded; data present | `docs/11-observability.md` |

## Screenshots to attach manually (operator)

1. Jenkins `boutique-app-ci` build #11 console + blue/green state.
2. Argo CD UI: `boutique-dev/staging/prod` Synced/Healthy.
3. Harbor `boutique` project with signatures/attestations.
4. Grafana dashboard `Boutique — Runtime & Health`.
5. Gmail inbox with the order confirmation.
