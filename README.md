# homelab-gitops

The source of truth for everything running on the k3s cluster, applied by [Argo CD](https://argoproj.github.io/cd/) (app-of-apps). Secrets live here too, encrypted with SOPS and an age key, and are decrypted in-cluster by KSOPS.

Read the handbook first: https://github.com/ssaav5-ai-labs/handbook — decisions live in `docs/decisions/`, open questions in `docs/open-questions/`, and the playbook that builds this repo is `playbooks/04-argocd/PLAYBOOK.md`.

## Layout

```
bootstrap/   versions.env, argocd/values.yaml, install.sh, root.yaml, project.yaml
apps/        one Argo CD Application per file (the root app watches this folder)
platform/    what the apps deploy: sops-canary/ now, monitoring in playbook 05
scripts/     checks used by CI
.sops.yaml   which files SOPS encrypts, for which age key
```

- `bootstrap/install.sh` installs Argo CD with Helm exactly once; after that Argo CD manages itself from `apps/argocd.yaml`.
- `apps/` is watched by the `root` Application — a new file here becomes a new app.
- Files named `*.enc.yaml` are SOPS-encrypted (values only); KSOPS decrypts them while Argo CD renders manifests.

## Local workflow

- Work in the dev container (`devpod up .`); `kubectl`, `helm`, `sops`, `age` and the Argo CD CLI are there.
- Never commit a plain `kind: Secret` — CI fails on it. Encrypt with `sops edit`.
- Never push to `main`; open a PR. Merging to `main` changes the cluster within ~3 minutes.
