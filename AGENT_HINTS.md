# collab-services-hive — Agent Context

## Project Overview

collab-services-hive provides the Matrix homeserver (Continuwuity) and messaging bridges (Signal, WhatsApp, Discord, iMessage) for the *-hive portfolio. It also hosts the wsproxy that relays iMessage from a macOS satellite node.

Repo: `~/Workspaces/UnixLike/collab-services-hive`

Read in this order:

1. `AGENT_HINTS.md` — this file; operating context, work rules, repo map
2. `ARCHITECTURE.md` — service topology, port assignments, deployment roles
3. queen-hive `docs/planning/COLLAB_SERVICES_PLAN.md` — bootstrap phases and future roadmap

## Portfolio Siblings

| Repo | Local Path | Purpose |
|---|---|---|
| queen-hive | `../queen-hive` | Control plane, integration registry, port governance |
| private-network-hive | `../private-network-hive` | ZeroTier mesh, Traefik, DNS — must be up first |
| agent-services-hive | `../agent-services-hive` | MCP servers; hosts MCP Matrix server adjacent |
| smart-home-hive | `../smart-home-hive` | HA, Matter, voice |
| media-manager-hive | `../media-manager-hive` | Plex, *arr, Stash |

## Work Rules

- GitHub Issues for any task > 30 min, > 3 files, or spanning repos.
- Quick fixes (< 30 min, 1–2 files, no design decisions) can be done directly.
- All inter-hive configuration changes must update queen-hive's integration registry (`docs/integration-registry/collab-services.md`).
- Satellite setup (iMessage bridge on macOS) is documented procedure only — never attempt to automate macOS satellite config from this hive.
- **Database volumes must be named volumes** — never virtiofs bind mounts for RocksDB or bridge state. See queen-hive's virtiofs DB policy.

## Key Architecture Constraints

- Continuwuity uses RocksDB; **never binary-swap** database files between Continuwuity, Tuwunel, or Conduit forks — database schemas diverge and swapping causes corruption.
- The iMessage bridge is a hardware-locked satellite: it must run on a macOS machine with active iMessage credentials. It connects **outbound** to wsproxy — no inbound ports needed on the Mac.
- Continuwuity and wsproxy run on the **Gandi VPS** (static public IP); bridges run on the primary node (Colima). Caddy on the VPS handles TLS for ports 8448 and 443. Traefik is not involved in Matrix routing.
- Bridges connect to homeserver via ZeroTier appservice API: `homeserver.url = http://${COLLAB_VPS_ZT_IP}:6167`. Homeserver callbacks to bridges use `COLLAB_PRIMARY_ZT_IP`.
- Port 8448 (Matrix federation) must be registered in queen-hive's `CONFLICT_ANALYSIS.md`.

## Package Manager Baseline

- **macOS (primary node)**: Colima Docker, MacPorts
- **Containerized**: Docker via Colima (profile `default`, same as portfolio-wide)
- **Shell**: `/usr/bin/env bash`

## GitHub Projects

collab-services-hive issues link to the `hive-portfolio` project (#5) in the `eejd` org for cross-repo coordination. Per-repo board: TBD (seed after Phase 0 bootstrap is complete).

## Three-Server Model

All three servers are independent and permanent — Matrix server names are embedded in user/room IDs forever.

| Server | Domain | Host | Federation | Purpose |
|---|---|---|---|---|
| Private | `home.zt` | Primary node (Colima) | No | Personal sandbox; ZeroTier-only; AI/MCP experimentation |
| Invite-only | `sibeling.net` | Primary node (Colima) | No | Trusted users; staging before sibeling.org changes |
| Public | `sibeling.org` | Gandi VPS | Yes | Federated; bridges; production communication platform |

## Phase Status

| Phase | Focus | Status |
|---|---|---|
| 0 | Bootstrap (docs, repo, compose skeleton, cshive CLI) | ✅ Complete |
| 1a | Private homeserver (home.zt) on primary node | 🔄 Scaffold done — needs .env + `cshive private-setup` |
| 1b | Public homeserver (sibeling.org) on VPS + Caddy TLS | 🔄 Scaffold done — needs .env + operational deploy |
| 2 | Core bridges (WhatsApp, Signal, Discord) → sibeling.org | 🔲 Not started |
| 3 | iMessage relay (wsproxy + macOS satellite) | 🔲 Not started |
| 3.5 | Invite-only homeserver (sibeling.net) on primary node | 🔲 Not started |
| 4 | AI agent integration (MCP Matrix server) | 🔲 Not started |
| 5 | Future: S3 media offload, MAS/OIDC, LiveKit | 🔲 Not started |
