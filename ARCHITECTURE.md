# collab-services-hive — Architecture

## Role

collab-services-hive is the real-time communication layer of the *-hive portfolio. It provides a Matrix federation homeserver and messaging bridges that unify Signal, WhatsApp, Discord, and iMessage into a single Matrix interface. AI agents interact with Matrix rooms via the Model Context Protocol (MCP), hosted adjacent in agent-services-hive.

## Deployment Topology

**Hybrid deployment:** homeserver and wsproxy on the Gandi VPS (static public IP); bridges on the primary node (Colima); iMessage satellite as a native macOS process on the Mac Mini.

```
[ Gandi VPS ]                              [ M4 Mac Mini / Colima ]
  Continuwuity ←──── ZeroTier mesh ──────→  mautrix-whatsapp (appservice)
  mautrix-wsproxy    (appservice API)        mautrix-signal   (appservice)
  Caddy (TLS)                                mautrix-discord  (appservice)
       ▲
       │ outbound TLS over ZeroTier
       │
[ M4 Mac Mini — native macOS (main user session) ]
  mautrix-imessage binary (user LaunchAgent)
  └── reads ~/Library/Messages/chat.db
```

Bridges connect to the homeserver via the Matrix appservice protocol over ZeroTier. Bridge `homeserver.url` points to the VPS ZeroTier IP on port 6167. The homeserver posts appservice events back to bridge listeners on the primary node's ZeroTier IP.

## Service Ports

| Service | Port | Host | Exposure | Notes |
|---|---|---|---|---|
| Continuwuity federation | 8448 | VPS (via Caddy) | Public | Matrix server-to-server API |
| Continuwuity client-server | 443 | VPS (via Caddy) | Public | Client API + .well-known delegation |
| Continuwuity client-server | 6167 | VPS | ZeroTier only | Bridges and MCP server reach this directly |
| mautrix-wsproxy | internal | VPS | ZeroTier only | iMessage relay WebSocket |
| Bridge appservice listeners | internal | Primary (Colima) | ZeroTier only | Homeserver posts events to these |

## Network

- VPS services attach to a Docker bridge on the VPS; Caddy terminates public TLS
- Primary node bridges attach to the shared `hive-net` Docker bridge (external, created by private-network-hive)
- ZeroTier mesh is the transport between VPS and primary node
- `COLLAB_VPS_ZT_IP` and `COLLAB_PRIMARY_ZT_IP` are set in `.env` and templated into appservice registration YAMLs

## Storage Policy

All stateful data uses **named Docker volumes** — never virtiofs bind mounts. RocksDB and bridge session state are high-churn and will corrupt on virtiofs. See queen-hive's [virtiofs DB policy](https://github.com/eejd/queen-hive/blob/main/docs/VIRTIOFS_DB_POLICY.md).

| Volume | Host | Service | Notes |
|---|---|---|---|
| `collab_continuwuity_data` | VPS | Continuwuity | RocksDB homeserver state; backed up via `cshive backup` |
| `collab_signal_data` | Primary | mautrix-signal | Signal session state |
| `collab_whatsapp_data` | Primary | mautrix-whatsapp | WhatsApp session state |
| `collab_discord_data` | Primary | mautrix-discord | Discord session state |

## Compose Stacks

| File | Target | Services |
|---|---|---|
| `docker-compose.vps.yml` | Gandi VPS (deployed via SSH) | Continuwuity, Caddy, mautrix-wsproxy |
| `docker-compose.yml` | Primary node (Colima) | mautrix-{signal,whatsapp,discord} |

Both stacks are managed by the `cshive` CLI.

## Homeserver Selection

Continuwuity is selected for resource-constrained VPS deployment: ~50–100MB idle RAM, Rust implementation, RocksDB storage.

**Migration warnings:**
- Never binary-swap database files between Continuwuity, Tuwunel, or Conduit forks — their RocksDB schemas diverge
- Migration to Synapse requires PostgreSQL and full account/room recreation

## Dependencies

| Dependency | Hive | What it provides |
|---|---|---|
| ZeroTier mesh | private-network-hive | Transport between VPS and primary node |
| hive-net Docker bridge | private-network-hive | Inter-service communication on primary node |
| MCP Matrix server | agent-services-hive (adjacent) | AI agent tooling for Matrix rooms |

## Integration Registry

Canonical port, network, and volume declarations: [queen-hive/docs/integration-registry/collab-services.md](https://github.com/eejd/queen-hive/blob/main/docs/integration-registry/collab-services.md)

Full planning and bootstrap phases: [queen-hive/docs/planning/COLLAB_SERVICES_PLAN.md](https://github.com/eejd/queen-hive/blob/main/docs/planning/COLLAB_SERVICES_PLAN.md)
