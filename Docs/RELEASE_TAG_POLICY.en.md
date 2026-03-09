# Release Tag Policy

This policy defines how release tags are created and protected in this repository.

## Purpose

- Unique, immutable release tags
- Consistent semantic versioning
- Protection against accidental overwrite or deletion

## Tag Naming Scheme

Allowed release tags:

- `vMAJOR.MINOR.PATCH` (example: `v3.1.0`)

Allowed pre-release tags:

- `vMAJOR.MINOR.PATCH-rc.N` (example: `v3.2.0-rc.1`)
- `vMAJOR.MINOR.PATCH-beta.N` (example: `v3.2.0-beta.1`)
- `vMAJOR.MINOR.PATCH-alpha.N` (example: `v3.2.0-alpha.1`)

Do not use:

- Tags without the `v` prefix (example: `3.1.0`)
- Ambiguous tags such as `latest`, `stable`, `final`

## Branch Mapping

- `v3.*` tags are created on commits from the `V3` branch
- `v2.*` tags are created on commits from the `V2-LEGACY` branch
- `main` is the development branch and does not receive stable release tags
