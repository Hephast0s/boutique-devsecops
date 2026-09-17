# 12 — Developer Portal Integration (Backstage)

Backstage (`sentinel-portal`) already exists in the cluster (`backstage` namespace, ingress
`backstage.192.168.1.8.nip.io`).

## Deliverable

`catalog-info.yaml` at the repo root defines:

- a **System** `online-boutique`,
- an **API** `online-boutique-grpc` (the `protos/demo.proto` contract),
- a **Component** per service (11 deployable + `redis-cart` + the excluded `shoppingassistantservice`),
  each with `owner`, `lifecycle`, Kubernetes annotations, and `dependsOn` edges mirroring the call graph.

TechDocs is configured via `mkdocs.yml` (`backstage.io/techdocs-ref: dir:.`).

## Registration (additive)

Register the catalog by adding a **new location** in the existing portal pointing at this repo's
`catalog-info.yaml`. If the portal's configuration does **not** support adding a location without editing
shared config, this is a change request (it must not disturb existing portal entries).

**Status:** catalog files are delivered; the location entry itself was **not added**, because the
Backstage instance's location configuration is shared config and no Backstage admin token was provided
(CR-WEB-1). Existing portal entries are untouched.

## Evidence

- Files committed on `devsecops`; visible reasoning: `catalog-info.yaml`, `mkdocs.yml`.
- A screenshot of the registered system is pending registration (CR-WEB-1).
