# 09 — Network Security

Network segmentation is implemented by the shared `boutique-network` component, applied to every
environment. It replaces the upstream per-service policies (which had wide-open egress `- {}`) with
**explicit egress** and always-on DNS.

## Policies (14 per environment)

| Policy | Purpose |
|---|---|
| `default-deny` | deny all ingress+egress for every pod |
| `allow-dns` | egress to CoreDNS (UDP+TCP 53) — always, from every pod |
| `frontend` | ingress only from the ingress controller (kube-system); egress to its 7 backends |
| `checkoutservice` | ingress from frontend; egress to catalog/currency/cart/shipping/payment/email |
| `recommendationservice` | ingress from frontend; egress to catalog |
| `cartservice` | ingress from frontend+checkout; egress to redis |
| `redis-cart` | ingress only from cartservice |
| `productcatalogservice` | ingress from frontend+checkout+recommendation |
| `currencyservice` | ingress from frontend+checkout |
| `shippingservice` | ingress from frontend+checkout |
| `paymentservice` | ingress only from checkout |
| `emailservice` | ingress from checkout; egress to Mailpit:1025 **and internet:587** (Gmail) |
| `adservice` | ingress only from frontend |
| `mailpit` | ingress from emailservice:1025 and the ingress controller:8025 |

## Enforcement proven (real) — `docs/evidence/phase9/netpol-tests.txt`

```
(1) full checkout succeeds with default-deny active:  cart=302, checkout=200
(2) ALLOWED  emailservice -> mailpit:1025                 connected
(3) BLOCKED  emailservice -> redis-cart:6379              ConnectionRefusedError
(4) BLOCKED  emailservice -> productcatalogservice:3550   ConnectionRefusedError
(5) BLOCKED  emailservice -> 1.1.1.1:443                  ConnectionRefusedError
(6) ALLOWED  emailservice -> smtp.gmail.com:587           delivered
```
This confirms the k3s network-policy controller is enforcing policy (the Phase-1 open question).

## Notes / limitations

- The ingress-controller rule matches `namespaceSelector: kube-system`; it could be narrowed to the
  Traefik pod labels.
- Intra-policy addressing is by pod label (`app:`), matching the upstream manifests.
- The `generate default-deny` Kyverno rule from Phase 8 was intentionally deferred to this phase so the
  environment was never deny-all without allows; it is now redundant with the `default-deny`
  NetworkPolicy here and can be added later for *new* namespaces.
