# ADR-0002 — Image builder: Kaniko (daemonless)

Status: **Accepted** · Date: 2026-09-16

## Context

The Jenkins controller's **default** agent template mounts the host Docker socket into agent pods. That is
a privilege-escalation path (any build can control the node's Docker daemon) and is explicitly forbidden by
the engagement (`do not mount the host Docker socket`). We need to build container images inside Kubernetes
pods without a Docker daemon.

## Options

| Option | Pros | Cons |
|---|---|---|
| **Kaniko** | runs as a normal pod, no daemon, no privileges; reads a local build context from the shared workspace; pushes by digest; simple CLI | upstream is deprecated (archived 2024); large debug image; slower than BuildKit; no multi-arch |
| **BuildKit (rootless)** | faster, cache mounts, actively maintained | rootless needs specific seccomp/`securityContext` tuning; some setups need privileged; more moving parts |
| **Buildah** | mature | generally needs privileged or specific storage drivers; less friendly in-cluster |
| **Docker-in-Docker** | familiar | needs privileged or a docker socket → rejected |

## Decision

Use **Kaniko** for this phase. It is daemonless, needs no privileged mode, and integrates cleanly with the
Jenkins Kubernetes agent by reading the build context from the shared workspace
(`--context=dir://$WORKSPACE/<ctx>`). It pushes directly to Harbor using a mounted docker config.

## Consequences

- The Docker socket is not mounted in our agent pods (verified).
- **Migration path:** because Kaniko is deprecated, ADR-0002 is revisited if the homelab moves to
  BuildKit rootless or `buildx` with a remote driver. The pipeline isolates building in one stage, so the
  swap is localized.
- Multi-arch builds are out of scope (the cluster is amd64-only).
- Cold builds are not cached (`--cache=false`); caching arrives with the Nexus-less PVC cache plan in a
  later phase.
