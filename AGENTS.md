# Instructions for AI agents

This repo is the GitOps source of truth for the k3s cluster. Everything here is applied by Argo CD.

## Read first
- The handbook: https://github.com/ssaav5-ai-labs/handbook (a sibling folder under `~/code/github.com/ssaav5-ai-labs/`).
- The playbook protocol: `playbooks/RUNNING.md` in the handbook.
- Decisions: `docs/decisions/` in the handbook; open questions: `docs/open-questions/`.
- The playbook 07 run review (identifier-deny, cluster-write-guard and scratch-work rules).

## Rules
- Never commit secrets, tokens, real public IPs or hostnames. Use placeholders.
- Never commit a plain `kind: Secret` — encrypt values with SOPS (`*.enc.yaml`); CI fails otherwise.
- Never print or read the age key (`$SOPS_AGE_KEY_FILE`) or run `sops decrypt`. Use `sops edit` in your own terminal.
- Never push to `main`; open a PR. Merging to `main` changes the cluster.
- If reality differs from the playbook, fix the run, then propose a playbook edit in the same PR.
- Never render, exec into or print anything that decrypts secrets (KSOPS, sops, the Argo CD repo-server). Debug sync failures from the Application status only. You may merge your own PRs with `gh pr merge --squash` once all required checks are green; never merge with failing or pending checks.
- Scratch work (chart renders, pulled charts, test files) goes in /tmp/agent/, never directly in /tmp.
