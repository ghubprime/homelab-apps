# homelab-apps

Tenant application repository for the `k8s-scots-lab` homelab cluster. Contains all self-hosted application Kustomize overlays, Helm values, and CI-generated manifests consumed by ArgoCD.

## Architecture

This repository is part of a three-repo GitOps model:

| Repository | Role |
|------------|------|
| [`k8s-cluster`](https://github.com/ghubprime/k8s-cluster) | **Platform** — Omni template, bootstrap chain, ArgoCD, core infrastructure, monitoring, security |
| **`homelab-apps`** (this repo) | **Tenant** — All self-hosted applications (26 apps) |
| [`omni-infra`](https://github.com/ghubprime/omni-infra) | Machine-specific network patches and machine class definitions |

## How It Works

1. Application manifests live under `kustomize/` (base + overlays) and `helm/` (values)
2. On push to `main`, GitHub Actions runs `generate-manifests.sh` to render raw manifests into `manifests/scots-lab/apps/<name>/_bootstrap.yaml`
3. ArgoCD Application objects in `k8s-cluster` point to this repo's `manifests/` output via `repoURL` overrides
4. ArgoCD auto-syncs with `prune: true` and `selfHeal: true`

## Directory Structure

```
homelab-apps/
├── .github/workflows/     # CI: Kustomize build + kubeconform validation
├── charts/                 # Offline Helm chart cache (if needed)
├── kustomize/
│   ├── base/apps/          # Shared base resources (namespace, network policies)
│   └── overlays/scots-lab/apps/  # Environment-specific overlays
├── helm/
│   ├── base/apps/          # Helm chart base configs
│   └── overlays/scots-lab/apps/  # Helm values overrides
├── manifests/              # CI-generated output (ArgoCD reads from here)
├── generate-manifests.sh   # Manifest generation script
└── renovate.json           # Dependency management
```

## Applications

| Category | Apps |
|----------|------|
| **Stateless** | drawio, it-tools, vert, openspeedtest, stirling-pdf, homepage |
| **Light State** | rackula, changedetection, healthchecks, homebox, ntfy, uptime-kuma, adguard-home, netbootxyz, onetimesecret, gdrive-backup |
| **Heavy State** | nextcloud, paperless, photoprism, immich, outline, linkwarden, romm, guacamole, znuny, umami |

## CI Pipeline

The GitHub Actions workflow (`generate.yml`) installs Helm, Kustomize, and kubeconform on Ubuntu, then:
1. Runs `generate-manifests.sh --force` to render all overlays
2. Validates every `_bootstrap.yaml` is non-empty (>10 bytes) to prevent 0-byte deletion traps
3. Runs `kubeconform` schema validation against K8s v1.36.1
4. Auto-commits generated manifests with `[skip ci]` to prevent infinite loops

> ⚠️ **Do NOT run `generate-manifests.sh` natively on Windows** — Kustomize's Helm inflation has a known bug that silently deletes manifest directories. Always push to GitHub and let CI handle generation.
