# Cleanup Summary

Generated from the May 29, 2026 reset/deep-clean session.

## Final Disk State

- Free space: 170.34 GB at final check
- Used space: about 52 GB
- Starting free space before the deeper cleanup was about 7.6 GB

## Major Space Reclaimed

- Removed Ubuntu-24.04 WSL distro after confirming `/home` was effectively empty and most disk use was `/nix` and system packages.
- Removed docker-desktop WSL distro and stale Docker WSL disk remnants.
- Removed all local Ollama models and local Ollama program files.
- Removed Chrome generated on-device model cache.
- Removed old offline-system generated outputs: `dist`, `work`, and local model assets.
- Removed old offline-system `.git` directory after Git reported no commits and source files were untracked.
- Removed user `.cache`, `C:\swarm-apk`, old Codex scratch folders, temp folders, browser caches, Windows logs/cache, OneDrive logs, and Windows Defender scan cache.
- Disabled hibernation with `powercfg /hibernate off`.
- Ran Windows component cleanup with `DISM /Online /Cleanup-Image /StartComponentCleanup`.

## Preservation Notes

- Notion page created in the `Projects` database: `Organize Projects Cleanup Hub`.
- GitHub copy saved under `jlorange1/Icarus-node/organize-projects`.
- Four dirty repos remain marked critical: `Nominatim`, `bitnet_cpp`, `llama_cpp`, and `archivebox`.
