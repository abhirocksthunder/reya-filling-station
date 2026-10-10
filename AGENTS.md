# Reya Filling Station Agent Architecture & Governance Rules

This repository follows AIPCC Project Guardian standards:
- Maintain `config/roadmap_phases.json` as the canonical roadmap.
- For every code change (even small changes), add a change entry at the top of `config/roadmap_phases.json` with project name and IST timestamp (`30 Aug 2026 5:03 am`), mirrored into `progress.md` under `## Recent Changes (IST)`.
- Update `README.md` whenever implementation, setup instructions, APIs, or project capabilities change.
- Run `python D:/AI operating system/scripts/sync_project_guardian_docs.py --project reya-filling-station` before pushing.
- Pre-push hook blocks pushes if documentation, README, or change logs are missing.
