# Organize Projects Cleanup Hub

This folder captures the cleanup, project inventory, retention audit, and restore workflow created during the May 29, 2026 PC reset/deep-clean session.

## Cleanup outcome

- Free space after cleanup: 170.51 GB
- Used space after cleanup: 52.09 GB
- Starting free space before the deeper cleanup was about 7.6 GB.

## What this preserves

- Project inventory across the local Windows profile, OneDrive, Codex workspace, and discovered Git repositories.
- Project completion estimates from markdown checklists.
- Dirty/clean Git status by project.
- Retention guidance before local deletion.
- Cleanup scripts used to reclaim space.
- Notion-ready project audit reports.

## Key reports

- `reports/project-context-detailed.md`
- `reports/project-audit-notion.md`

## Scripts

- `scripts/build-project-catalog.ps1`
- `scripts/build-project-audit-report.ps1`
- `scripts/deep-clean.ps1`
- `scripts/preserve-project-bundles.ps1`
- `scripts/publish-organize-hub.ps1`

## Current audit summary

- Total scanned projects: 18
- Dirty repos: 4
- Projects with no remote configured: 0
- Cleanup candidates: 7
- Critical repos not to delete yet: Nominatim, bitnet_cpp, llama_cpp, archivebox

## Notion

A Notion Projects database page named `Organize Projects Cleanup Hub` was created for this cleanup and preservation record.
