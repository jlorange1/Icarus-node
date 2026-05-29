# Project Audit and Retention Report

Generated: 2026-05-29 14:54:30

## Executive Summary

- Total scanned projects: 18
- Dirty repos: 4
- Projects with no remote configured: 0
- Cleanup candidates: 7
- Total repository payload after cleanup, excluding `.git`: 706.66 MB
- Machine free space after cleanup: 170.51 GB
- Machine used space after cleanup: 52.09 GB

## Completion Profile

- High: 1
- Medium: 1
- Low: 6
- No metadata: 10

## Staleness Profile

- Active: 15
- Warm: 1
- Dormant: 2
- Unknown: 0

## Risk Bucket

- Critical: 4
- Moderate: 4
- Active: 1
- Low: 9

## Critical Repos

These should not be deleted until their uncommitted changes are preserved or reviewed.

- `Nominatim`: Python, dirty, 0% completion from task markers, remote `https://github.com/osm-search/Nominatim.git`.
- `bitnet_cpp`: Python/C++/CMake, dirty, 88.73% completion, remote `https://github.com/microsoft/BitNet.git`.
- `llama_cpp`: Python/C++/CMake, dirty, 96.25% completion, remote `https://github.com/ggerganov/llama.cpp.git`.
- `archivebox`: Python/Container, dirty, 38.98% completion, remote `https://github.com/ArchiveBox/ArchiveBox.git`.

## Active But Clean

- `tileserver-gl`: Node.js/Container, clean, no checklist metadata, keep locally or archive after current sprint.

## Low-Risk Cleanup Candidates

These have remotes configured and clean local working trees. They can be deleted locally after confirming the remote is authoritative.

- `gnss_sdr`: C++/CMake, clean, active, remote `https://github.com/gnss-sdr/gnss-sdr.git`.
- `rtl-sdr`: C++/CMake, clean, dormant, remote `https://github.com/rtlsdrblog/rtl-sdr.git`.
- `SoapySDR`: C++/CMake, clean, warm, remote `https://github.com/pothosware/SoapySDR.git`.
- `openmaptiles`: Container, clean, active, remote `https://github.com/openmaptiles/openmaptiles.git`.
- `photon`: Java/Kotlin, clean, active, remote `https://github.com/komoot/photon.git`.
- `planetiler`: Java/Kotlin, clean, active, remote `https://github.com/onthegomap/planetiler.git`.
- `gps_sdr_sim`: unidentified type, clean, dormant, remote `https://github.com/osqzss/gps-sdr-sim.git`.
- `kiwix_tools`: unidentified type, clean, active, remote `https://github.com/kiwix/kiwix-tools.git`.
- `yacy`: unidentified type, clean, active, remote `https://github.com/yacy/yacy_search_server.git`.

## Moderate-Risk Completion Work

These are clean but have low completion/task markers and should be evaluated before deletion.

- `gnuradio`: C++/CMake, clean, 0% task completion, remote `https://github.com/gnuradio/gnuradio.git`.
- `open-webui`: Node.js/Python/Container, clean, 0% task completion, remote `https://github.com/open-webui/open-webui.git`.
- `open_interpreter`: Python/Container, clean, 10.42% task completion, remote `https://github.com/openinterpreter/open-interpreter.git`.
- `OpenHands`: Python/Container, clean, 0% task completion, remote `https://github.com/All-Hands-AI/OpenHands.git`.

## Cleanup Actions Already Completed

- Removed WSL Ubuntu distro with empty `/home` and mostly system/package content.
- Removed Docker WSL distro and stale Docker WSL disk.
- Removed local Ollama models and local Ollama program folder.
- Removed Chrome generated on-device model cache.
- Removed old offline-system generated `dist`, `work`, and model assets.
- Removed old offline-system `.git` directory after Git reported no commits and all source files were untracked.
- Removed `C:\swarm-apk`, user `.cache`, old Codex scratch folders, and temp/cache folders.
- Disabled hibernation with `powercfg /hibernate off`.
- Ran Windows component cleanup with `DISM /StartComponentCleanup`.

## Runbook

- Rebuild inventory with `scripts/build-project-catalog.ps1`.
- Rebuild audit with `scripts/build-project-audit-report.ps1`.
- Preserve bundles with `scripts/preserve-project-bundles.ps1` before deleting project folders.
- Use `scripts/deep-clean.ps1 -Aggressive` for cache cleanup.
