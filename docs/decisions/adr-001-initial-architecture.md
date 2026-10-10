# ADR-001 - Initial Architecture for Reya Filling Station

## Status

Accepted (Governed by Project Guardian)

## Context

Project `reya-filling-station` is created as a linked component of AIPCC with standard governance rules enforced from day one.

## Decision

Adopt standard Project Guardian architecture rules, maintaining `config/roadmap_phases.json` with reverse-chronological IST change logs, technical specifications in `docs/`, and pre-push hook validation.

## Consequences

- **Positive:** Immediate consistency across AIPCC dashboard, search, and guardrails.
- **Negative / Trade-offs:** Every code change requires a top-level IST change entry.
