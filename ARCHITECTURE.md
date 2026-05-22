# collab-services-hive — Architecture

## Role

collab-services-hive is the real-time communication layer of the *-hive portfolio. It operates three Matrix homeservers with distinct purposes, plus messaging bridges. AI agents interact with Matrix rooms via the Model Context Protocol (MCP), hosted adjacent in agent-services-hive.

## Three-Server Model

All three servers are intended as permanent, independent deployments with separate databases and user namespaces.

| Server | Domain | Host | Federation | Purpose |
|---|---|---|---|---|
| **Private** | `home.zt` | Primary node (Colima) | No | Personal sandbox; ZeroTier-only; AI/MCP experimentation |
| **Invite-only** | `sibeling.net` | Primary node (Colima) | No | Trusted users; accessible via Matrix clients; staging before sibeling.org changes |
| **Public** | `sibeling.org` | Gandi VPS | Yes | Federated; bridges (Signal, WhatsApp, Discord, iMessage); production comms |

Matrix server names are permanent — every user ID and room ID embeds the server name forever. The three servers share no data and require no migration between them.

## Deployment Topology

```
[ Gandi VPS ]                              [ M4 Mac Mini / Colima ]
  Continuwuity (sibeling.org) ←── ZT ───→  Continuwuity (home.zt)    ← personal
  mautrix-wsproxy                            Continuwuity (sibeling.net) ← invite-only (future)
  Caddy (TLS)                                mautrix-whatsapp (appservice → sibeling.org)
       ▲                                     mautrix-signal   (appservice → sibeling.org)
       │ outbound TLS over ZeroTier          mautrix-discord  (appservice → sibeling.org)
       │
[ M4 Mac Mini — native macOS (main user session) ]
  mautrix-imessage binary (user LaunchAgent)
  └── reads ~/Library/Messages/chat.db
```

Bridges connect to the **public** homeserver (VPS) via the Matrix appservice protocol over ZeroTier. Bridge `homeserver.url` points to the VPS ZeroTier IP on port 6167. The homeserver posts appservice events back to bridge listeners on the primary node's ZeroTier IP.

## Service Ports

| Service | Port | Host | Exposure | Notes |
|---|---|---|---|---|
| Continuwuity (sibeling.org) federation | 8448 | VPS (via Caddy) | Public | Matrix server-to-server API |
| Continuwuity (sibeling.org) client-server | 443 | VPS (via Caddy) | Public | Client API + .well-known delegation |
| Continuwuity (sibeling.org) client-server | 6167 | VPS | ZeroTier only | Bridges and MCP server reach this |
| mautrix-wsproxy | internal | VPS | ZeroTier only | iMessage relay WebSocket |
| Continuwuity (home.zt) client-server | 6168 | Primary (Colima) | ZeroTier only | HTTP via Traefik; TLS deferred to PNH Phase 4 |
| Continuwuity (sibeling.net) client-server | 6169 | Primary (Colima) | ZeroTier + public | Future; TLS required before inviting users |
| Bridge appservice listeners | internal | Primary (Colima) | ZeroTier only | sibeling.org homeserver posts events here |

## Network

- VPS services attach to a Docker bridge on the VPS; Caddy terminates public TLS
- Primary node bridges attach to the shared `hive-net` Docker bridge (external, created by private-network-hive)
- ZeroTier mesh is the transport between VPS and primary node
- `COLLAB_VPS_ZT_IP` and `COLLAB_PRIMARY_ZT_IP` are set in `.env` and templated into appservice registration YAMLs

## Storage Policy

All stateful data uses **named Docker volumes** — never virtiofs bind mounts. RocksDB and bridge session state are high-churn and will corrupt on virtiofs. See queen-hive's [virtiofs DB policy](https://github.com/eejd/queen-hive/blob/main/docs/VIRTIOFS_DB_POLICY.md).

| Volume | Host | Service | Notes |
|---|---|---|---|
| `collab_continuwuity_data` | VPS | Continuwuity (sibeling.org) | RocksDB; backed up via `cshive backup` |
| `collab_private_data` | Primary | Continuwuity (home.zt) | RocksDB; personal sandbox |
| `collab_inviteonly_data` | Primary | Continuwuity (sibeling.net) | RocksDB; future |
| `collab_signal_data` | Primary | mautrix-signal | Signal session state |
| `collab_whatsapp_data` | Primary | mautrix-whatsapp | WhatsApp session state |
| `collab_discord_data` | Primary | mautrix-discord | Discord session state |

## Compose Stacks

| File | Target | Services | Profile |
|---|---|---|---|
| `docker-compose.vps.yml` | Gandi VPS (via SSH) | Continuwuity (sibeling.org), Caddy, mautrix-wsproxy | — |
| `docker-compose.yml` | Primary node (Colima) | mautrix-{signal,whatsapp,discord} | (default) |
| `docker-compose.yml` | Primary node (Colima) | Continuwuity (home.zt) | `private` |
| `docker-compose.yml` | Primary node (Colima) | Continuwuity (sibeling.net) | `inviteonly` (future) |

Both stacks are managed by the `cshive` CLI. Private and invite-only servers use Docker Compose profiles to start independently of the bridges.

## Homeserver Selection

Continuwuity is selected for all three instances: ~50–100MB idle RAM each, Rust implementation, RocksDB storage. Three instances on the M4 Mac Mini add ~150–300MB total — well within available headroom.

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
