# Changelog

All notable changes to this project will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
This project uses [Semantic Versioning](https://semver.org/).

---

## [Unreleased]

## [0.1.0] - 2026-03-10

### Added
- Initial modular Taskfile setup with modules: `aws`, `kube`, `helm`, `terraform`, `git`, `security`, `diagnostics`
- `scripts/install.sh` — curl-installable, interactive or env-var driven
- `scripts/update.sh` — update `tasks/` from remote without touching `.taskfile.env`
- `scripts/uninstall.sh` — remove installed artefacts
- `scripts/test-install.sh` — offline smoke test for the installer
- `tasks/_common/vars.yml` — shared variable documentation
- `.taskfile.env.example` — template for project-specific configuration
- `VERSION` file for release tracking
