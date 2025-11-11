## AGENTS.md — AI coding agent quick guide

Purpose: help an AI coding agent be productive in this FluxCD + Kustomize GitOps repo.

Quick files to open first

- `.github/copilot-instructions.md` — authoritative, repo-specific rules and patterns.
- `README.md` (repo root) — bootstrap & SOPS notes.
- `repositories/README.md` — examples for co-located repository files.
- `bootstrap/`, `clusters/*/vars/` — cluster bootstrap and SOPS-encrypted secrets.
- `common/*/*/install.yaml` and corresponding `common/*/*/app/` — app install kustomizations and app resources.
- `get_secret.sh` — helper script the repo ships.

Core conventions (short)

- This is a FluxCD-driven GitOps repo. Changes are intended to be declarative and applied via Flux.
- Co-located repository pattern: every app places `app/helmrepository.yaml` or `app/ocirepository.yaml` next to `app/helmrelease.yaml` and `app/kustomization.yaml`.
- `install.yaml` CRs under `common/<category>/<app>/install.yaml` MUST use `spec.path: ./common/<category>/<app>/app` (relative to repo root).
- Secrets use SOPS (`*.sops.yaml`) and cluster keys live in `clusters/<type>/vars/cluster-secrets.yaml`. Never commit plaintext secrets.

Most-used commands (copy/paste)

```bash
# Bootstrap Flux system
kubectl apply --kustomize bootstrap

# Apply a cluster overlay (replace k3d/kind/etc.)
kubectl apply --kustomize clusters/k3d

# Flux troubleshooting / status
flux get kustomizations
flux get helmreleases
flux reconcile kustomization <name>
kubectl describe helmrelease <app> -n <namespace>
kubectl logs -n flux-system deployment/kustomize-controller
```

Common tasks & troubleshooting notes

- To add an app: create `common/<category>/<app>/app/{kustomization.yaml,helmrelease.yaml,helmrepository.yaml}` and `common/<category>/<app>/install.yaml`, then update the category `kustomization.yaml` to include the new `install.yaml`.
- If a HelmRelease fails, inspect `kubectl describe helmrelease ...` then `kubectl logs` for the helm-controller in `flux-system`.
- Kustomize postBuild substitutes values from `clusters/*/vars/cluster-settings.yaml` and `cluster-secrets.yaml` — missing SOPS keys will break applies.

Secrets & access

- SOPS + age is required: do not attempt to edit or decrypt secrets without the repo's age key. If a change needs secrets or a deploy key, stop and request the key.
- `.gitattributes` contains SOPS rules (look for `*.sops.*`) — follow repo's encryption patterns.

PR / validation checklist (small)

- Does `install.yaml` use `./common/<category>/<app>/app`? If not, fix and update parent kustomization.
- Avoid adding plaintext secrets; create/modify `.sops.yaml` encrypted files or update `clusters/*/vars/cluster-secrets.yaml`.
- Include the Flux/`kubectl` commands you ran to validate runtime behavior in the PR description (e.g., `flux reconcile ...`, `kubectl describe helmrelease ...`).

Example app layout to reference

- `common/observability/grafana/app/{kustomization.yaml,ocirepository.yaml,helmrelease.yaml}` and `common/observability/grafana/install.yaml`.

If anything in this guide is unclear or you want policy/verbosity changes, tell me what to expand or contract and I will iterate.
