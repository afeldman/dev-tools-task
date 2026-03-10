# dev-tools-task

A modular [Task](https://taskfile.dev/) setup for common dev operations — AWS, Kubernetes, Helm, Terraform, Git, Security, and Diagnostics. Curl-installable into any project.

## Installation

```sh
curl -sL https://raw.githubusercontent.com/afeldman/dev-tools-task/main/scripts/install.sh | sh
```

The script guides you interactively through the setup. It reads your AWS profiles from `~/.aws/config` and Kubernetes contexts from `$KUBECONFIG` to generate a project-specific `.taskfile.env`.

### Non-interactive / CI

```sh
curl -sL https://raw.githubusercontent.com/afeldman/dev-tools-task/main/scripts/install.sh \
  | NAMESPACE=myapp \
    AWS_REGION=eu-central-1 \
    AWS_PROFILE_DEV=my-dev-profile \
    AWS_PROFILE_PLAY=my-play-profile \
    KUBE_CONTEXT=my-cluster \
    sh
```

## Update

Pull the latest `tasks/` without touching your `.taskfile.env`:

```sh
curl -sL https://raw.githubusercontent.com/afeldman/dev-tools-task/main/scripts/update.sh | sh
```

## Uninstall

```sh
curl -sL https://raw.githubusercontent.com/afeldman/dev-tools-task/main/scripts/uninstall.sh | sh
```

Or locally:

```sh
sh scripts/uninstall.sh
```

## Usage

```sh
task          # list all available tasks
task setup    # AWS SSO login + Kubernetes login + terraform init
```

## Modules

| Module | Prefix | Key tasks |
|---|---|---|
| AWS | `aws:` | `aws:login:dev`, `aws:login:play`, `aws:whoami` |
| Kubernetes | `kube:` | `kube:login`, `kube:pods`, `kube:logs`, `kube:exec` |
| Helm | `helm:` | `helm:list`, `helm:diff`, `helm:upgrade`, `helm:rollback` |
| Terraform | `terraform:` | `terraform:init`, `terraform:plan`, `terraform:apply` |
| Git | `git:` | `git:sync`, `git:log`, `git:prune`, `git:stash` |
| Security | `security:` | `security:scan:image`, `security:secrets`, `security:checkov` |
| Diagnostics | `diagnostics:` | `diagnostics:collect:all`, `diagnostics:kube:failing-pods` |

See `CLAUDE.md` for the full task reference.

## Configuration

All settings live in `.taskfile.env` (gitignored). Use `.taskfile.env.example` as a template:

```sh
cp .taskfile.env.example .taskfile.env
```

| Variable | Description | Default |
|---|---|---|
| `NAMESPACE` | Kubernetes namespace / project name | `my-project` |
| `AWS_REGION` | AWS region | `eu-central-1` |
| `AWS_PROFILE_DEV` | AWS SSO profile for dev | — |
| `AWS_PROFILE_PLAY` | AWS SSO profile for playground | — |
| `KUBE_CONTEXT` | kubectl context (empty = current) | — |
| `OUTPUT_DIR` | Diagnostics output directory | `.diagnostics` |

## Prerequisites

| Module | Required tools |
|---|---|
| aws | `aws` CLI |
| kube | `kubectl`, `az` (AKS), `aws` (EKS) |
| helm | `helm` ≥ 3, `helm-diff` plugin |
| terraform | `terraform` |
| git | `git` |
| security | `trivy`, `gitleaks`, `checkov` |
| diagnostics | `kubectl`, `aws`, `jq` |

## Adding a module

1. Create `tasks/<module>/Taskfile.yml`
2. Add it under `includes:` in root `Taskfile.yml` with `optional: true`
3. Reference `.taskfile.env` values as shell `$VAR` — no re-declaration needed

## Development

Run the installer smoke test (fully offline):

```sh
sh scripts/test-install.sh
```
