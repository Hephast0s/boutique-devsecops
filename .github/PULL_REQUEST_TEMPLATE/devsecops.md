# Pull Request (DevSecOps engagement)

## Summary

<!-- What does this change and why? -->

## Type

- [ ] feat
- [ ] fix
- [ ] security
- [ ] docs
- [ ] ci
- [ ] refactor / chore

## Security checklist (required)

- [ ] No secret, token, key, password or kubeconfig is included (gitleaks passes).
- [ ] No change to application business logic unless justified and recorded in `docs/CHANGE_LOG.md`.
- [ ] Images are referenced **by digest**, never by a floating tag.
- [ ] Any new Kubernetes object is scoped to `boutique-*` namespaces (additive-only rule).
- [ ] No existing platform component (Kyverno/ESO/Vault/Harbor/Argo CD/Jenkins/Prometheus) is modified.
- [ ] Manifests pass `kubectl apply --dry-run=server` (or `kubeconform`).
- [ ] Pre-commit hooks pass (run in CI / on demand; not forced locally on constrained hardware).

## Evidence

<!-- Commands run and their real output, or a link to docs/evidence/. -->

## Rollback

<!-- How to revert this change and its blast radius. -->
