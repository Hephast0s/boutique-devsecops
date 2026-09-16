# 03 — Image Provenance (baseline)

Every runtime image is mirrored from upstream into Harbor `boutique` and pinned by digest.
Source registry: `us-central1-docker.pkg.dev/online-boutique-ci/microservices-demo/<svc>:v0.10.6`
(verified anonymously pullable during Phase 3).

Mirror procedure (per image): `docker pull <src>` → `docker tag` → `docker push 192.168.1.8:30082/boutique/<svc>:v0.10.6`.
Raw digests captured at `docs/evidence/phase3/image-digests.txt`.

| Service | Harbor image | Digest (sha256) | Size (bytes) |
|---|---|---|---|
| adservice | `192.168.1.8:30082/boutique/adservice` | `f580c4853e896dd2083f0c270c4b7aa5feda6dd56058a93b87d0c88334a4c07d` | 109542757 |
| cartservice | `192.168.1.8:30082/boutique/cartservice` | `b5c29ddb3238474ea8d1842f07004fedeeae47f660627ab111a613a681cd0356` | 17870221 |
| checkoutservice | `192.168.1.8:30082/boutique/checkoutservice` | `ab40699b6d9e45c9a93b5427008f327fbe912465361e2ff7a1a1be7111e36134` | 7444601 |
| currencyservice | `192.168.1.8:30082/boutique/currencyservice` | `7b2f3f804555c926861d67cd22c1b7c9e32d46b81cf1a64dd3089ae424d73be9` | 52621184 |
| emailservice | `192.168.1.8:30082/boutique/emailservice` | `77fd45d411b3550cbd39e30bda83ed6ea23d87fd6e58e69cf9fa2808e003984d` | 40686104 |
| frontend | `192.168.1.8:30082/boutique/frontend` | `c06df08eccd78568a37292cfbe889df42fac48691b7fb05f2deeba0ae8d669ef` | 12138803 |
| loadgenerator | `192.168.1.8:30082/boutique/loadgenerator` | `9bed9dec88ae439b9c10e3689dee57201aad47c9abb9faf04add562481482421` | 45592857 |
| paymentservice | `192.168.1.8:30082/boutique/paymentservice` | `735b6d3255e2c74b0135a95cfc2337987e492f24e163c0bb9a853635876993c4` | 50988805 |
| productcatalogservice | `192.168.1.8:30082/boutique/productcatalogservice` | `fb8568ecfc948717eb07746a6ce360fb8e5f906ae8a874cbad666891f0d21790` | 9779283 |
| recommendationservice | `192.168.1.8:30082/boutique/recommendationservice` | `5d8321f2d24132889f654f75308e541b0626e6ae0cbacf81b170e5eb0921b415` | 40031253 |
| shippingservice | `192.168.1.8:30082/boutique/shippingservice` | `8527bafff8c8776e345f2dca0641f6e8595b053ce67f9a5af66f5a85d9eaca9d` | 7167231 |
| redis-cart | `192.168.1.8:30082/boutique/redis` | `9c3ecc609a8087c0f11c494fefaf37a8f7bf9a967631d4a0da8967a9810be354` | 39015929 |

## Notes

- Source digest capture gotcha: for `redis:alpine` (a multi-source re-tagged image),
  `docker inspect .RepoDigests[0]` returned the **Docker Hub** digest, not the Harbor one. The correct
  Harbor digest was read from the Harbor API. All other entries were Harbor digests and pulled successfully.
- These are **unsigned** images (upstream, before Phase 5). Signature verification is enforced starting
  Phase 8, by which time CI-built, cosign-signed images replace these mirrors.
- The Harbor project `boutique` was created for this engagement (no collision; pre-existing projects
  `apps`, `hephastos`, `library` untouched).
