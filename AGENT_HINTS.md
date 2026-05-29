# collab-services-hive — Agent Context

## Project Overview

collab-services-hive provides the Matrix homeserver (Continuwuity) and messaging bridges (Signal, WhatsApp, Discord, iMessage) for the *-hive portfolio. It also hosts the wsproxy that relays iMessage from a macOS satellite node.

Repo: `~/Workspaces/UnixLike/collab-services-hive`

## Session Start — Memory Protocol

Before reading local docs, retrieve shared context from the common agent-memory store:

1. `retrieve_memory("coding preferences and principles", tags=["ns:preferences"])`
2. `retrieve_memory("recent decisions and context for collab-services-hive", tags=["ns:coding", "project:collab-services-hive"])`

Apply retrieved context, then read local docs in this order:

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

## Backup

Two backup targets — both covered by `cshive backup`:

1. **VPS RocksDB** (continuwuity_data on heimdallr): rsync-cold over SSH → `$COLLAB_BACKUP_ROOT` (default `/zfs/Backup/hive/collab/`)
2. **Local bridge volumes** (colima VM): `collab_signal_data`, `collab_whatsapp_data`, `collab_discord_data`, `collab_private_data` → `$COLLAB_LOCAL_BACKUP_ROOT` (default `/zfs/Backup/hive/collab-local/`), alpine tar.gz, 7 retained

```bash
cshive backup [--dry-run]    # VPS rsync + local bridge volume export
cshive backup-status         # VPS backup age + local volume freshness (48h threshold)
```

VPS backup requires SSH to `$COLLAB_VPS_SSH_HOST` and the target continuwuity container to be stopped. Local bridge volume export works with containers running. `cshive backup` is invoked nightly at 04:00 by `com.qhive.backup`.

## Key Architecture Constraints

- Continuwuity uses RocksDB; **never binary-swap** database files between Continuwuity, Tuwunel, or Conduit forks — database schemas diverge and swapping causes corruption.
- The iMessage bridge is a hardware-locked satellite: it must run on a macOS machine with active iMessage credentials. It connects **outbound** to wsproxy — no inbound ports needed on the Mac.
- Continuwuity and wsproxy run on the **Gandi VPS** (static public IP); bridges run on the primary node (Colima). Caddy on the VPS handles TLS for ports 8448 and 443. Traefik is not involved in Matrix routing.
- Bridges connect to homeserver via ZeroTier appservice API: `homeserver.url = http://${COLLAB_VPS_ZT_IP}:6167`. Homeserver callbacks to bridges use `COLLAB_PRIMARY_ZT_IP`.
- Port 8448 (Matrix federation) must be registered in queen-hive's `CONFLICT_ANALYSIS.md`.

## Package Manager Baseline

- **macOS (primary node)**: Colima Docker, MacPorts (`/opt/local/bin/port`)
  - Local ports tree (dev): `~/Workspaces/Apple/macOS/macports-ports-local/` — author Portfiles here
  - Local ports tree (deploy): `/opt/macports-ports-local/` — pull-only; MacPorts install source
- **Containerized**: Docker via Colima (profile `default`, same as portfolio-wide)
- **Shell**: `/usr/bin/env bash` (use `/opt/local/bin/bash` for features beyond bash 3.2)

## Token Compression (RTK)

RTK v0.42.0 is installed and active. The Claude Code PreToolUse hook rewrites every Bash call through `rtk` automatically — no manual prefixing needed.

**Key rules:**
- Run full commands and let RTK compress; don't pre-truncate with `| head` / `| tail`
- Use `docker logs <container>` (not `docker logs ... | tail -50`) — RTK gets 85-99% savings on log output
- Use the `Read` tool for file reads, not `cat`/`head` in Bash
- Run `rtk discover` to find missed optimization opportunities
- Run `rtk gain` to check token savings for the current session

See `~/.claude/RTK.md` for full agent guidance.

## Task Tracking Policy (GitHub First)

collab-services-hive issues link to the `hive-portfolio` project (#5) in the `eejd` org for cross-repo coordination. Per-repo board: TBD (seed after Phase 0 bootstrap is complete).

Useful commands:
```bash
gh issue list --repo eejd/collab-services-hive
gh issue create --repo eejd/collab-services-hive --title "..." --body "..."
gh project item-add 5 --owner eejd --url <issue-url>
```

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
| 1a | Private homeserver (home.zt) on primary node | ✅ Complete — running on primary node, `cshive private-setup` done 2026-05-25 |
| 1b | Public homeserver (sibeling.org) on VPS + Caddy TLS | 🔄 Scaffold done — needs .env + operational deploy |
| 2 | Core bridges (WhatsApp, Signal, Discord) → sibeling.org | 🔲 Not started |
| 3 | iMessage relay (wsproxy + macOS satellite) | 🔲 Not started |
| 3.5 | Invite-only homeserver (sibeling.net) on primary node | 🔲 Not started |
| 4 | AI agent integration (MCP Matrix server) | 🔲 Not started |
| 5 | Future: S3 media offload, MAS/OIDC, LiveKit | 🔲 Not started |

## Known Open Items

- Phase 1b (public homeserver): VPS (heimdallr.home.zt) runs **native apt installs — no Docker**. The `docker-compose.vps.yml` / compose-over-SSH approach will not work; Phase 1b needs a native systemd deployment plan before proceeding.
- Phase 1b (public homeserver): `.env` population and operational VPS deploy not yet run.
- Per-repo GitHub project board not yet seeded — create after Phase 0 issues are confirmed closed.
- Integration registry entry (`queen-hive/docs/integration-registry/collab-services.md`) scaffolded but not yet populated.
