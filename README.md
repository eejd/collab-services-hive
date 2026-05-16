# collab-services-hive

**Matrix homeserver, messaging bridges, and collaboration infrastructure for the *-hive portfolio.**

collab-services-hive provides real-time communication services: a Matrix federation homeserver (Continuwuity), messaging bridges (Signal, WhatsApp, Discord, iMessage), and the integration layer for AI agents to participate in collaborative rooms via the Model Context Protocol (MCP).

## Services

| Service | Purpose | Status |
|---|---|---|
| Continuwuity | Matrix homeserver (Rust, ~100MB idle RAM, RocksDB) | Planned |
| mautrix-signal | Signal bridge (puppet users) | Planned |
| mautrix-whatsapp | WhatsApp bridge (QR code auth) | Planned |
| mautrix-discord | Discord bridge (bot + puppet mode) | Planned |
| mautrix-wsproxy | WebSocket proxy for iMessage relay | Planned |

### Satellite Service (Not Docker-managed)

| Service | Platform | Notes |
|---|---|---|
| mautrix-imessage | macOS (separate machine) | iMessage relay; connects outbound to wsproxy |

## Architecture

This hive is part of the *-hive portfolio. It requires:
- `private-network-hive` — provides ZeroTier mesh, Traefik reverse proxy, and the shared `hive-net` Docker bridge
- `agent-services-hive` — hosts the MCP Matrix server adjacent to agent runtimes

See [ARCHITECTURE.md](ARCHITECTURE.md) for full topology and integration details.

## Portfolio Context

This hive is coordinated by [queen-hive](https://github.com/eejd/queen-hive), which maintains the integration registry, port allocation, and deployment ordering for all *-hive repos.

| Repo | Purpose |
|---|---|
| [queen-hive](https://github.com/eejd/queen-hive) | Control plane, integration registry |
| [private-network-hive](https://github.com/eejd/private-network-hive) | ZeroTier mesh, DNS, Traefik |
| [agent-services-hive](https://github.com/eejd/agent-services-hive) | MCP servers, Edgee LLM proxy, Qdrant |
| [smart-home-hive](https://github.com/eejd/smart-home-hive) | Home Assistant, Matter/Thread |
| [media-manager-hive](https://github.com/eejd/media-manager-hive) | Plex, *arr stack, Stash |

## Planning

Architecture and bootstrap plan: [queen-hive/docs/planning/COLLAB_SERVICES_PLAN.md](https://github.com/eejd/queen-hive/blob/main/docs/planning/COLLAB_SERVICES_PLAN.md)

Agent operating context: [AGENT_HINTS.md](AGENT_HINTS.md)
