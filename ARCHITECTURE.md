# collab-services-hive — Architecture

## Role

collab-services-hive is the real-time communication layer of the *-hive portfolio. It provides a Matrix federation homeserver and messaging bridges that unify Signal, WhatsApp, Discord, and iMessage into a single Matrix interface. AI agents interact with Matrix rooms via the Model Context Protocol (MCP), hosted adjacent in agent-services-hive.

## Deployment Topology

```
[ Primary Node — M4 Mac Mini / Colima ]
  ├── Continuwuity (Matrix homeserver)
  ├── mautrix-signal (bridge)
  ├── mautrix-whatsapp (bridge)
  ├── mautrix-discord (bridge)
  └── mautrix-wsproxy (iMessage relay WebSocket proxy)
          ▲
          │ Outbound TLS (ZeroTier or internet)
          │
[ Satellite — macOS Node (laptop or dedicated Mac) ]
  └── mautrix-imessage binary
        └── Reads chat.db; connects outbound to wsproxy

[ Cloud Node (optional future) ]
  └── Continuwuity can be relocated to VPS; bridges may follow
        └── ZeroTier mesh remains the transport
```

## Service Ports

| Service | Port | Exposure | Notes |
|---|---|---|---|
| Continuwuity federation | 8448 | Public via Traefik | Matrix server-to-server API |
| Continuwuity client-server | 6167 | Internal via Traefik | Non-standard; avoids common conflicts |
| mautrix-wsproxy | internal | hive-net only | iMessage relay WebSocket |
| All bridges | internal | hive-net only | Registered as Matrix appservices |

## Network

All services attach to the shared `hive-net` Docker bridge (external, created by private-network-hive). Traefik (private-network-hive) routes external Matrix traffic to Continuwuity.

## Storage Policy

All stateful data uses **named Docker volumes** — never virtiofs bind mounts. RocksDB and bridge session state are high-churn and will corrupt on virtiofs. See queen-hive's [virtiofs DB policy](https://github.com/eejd/queen-hive/blob/main/docs/VIRTIOFS_DB_POLICY.md).

| Volume | Service | Notes |
|---|---|---|
| `collab_continuwuity_data` | Continuwuity | RocksDB homeserver state |
| `collab_signal_data` | mautrix-signal | Signal session state |
| `collab_whatsapp_data` | mautrix-whatsapp | WhatsApp session state |
| `collab_discord_data` | mautrix-discord | Discord session state |

## Homeserver Selection

Continuwuity is selected for resource-constrained home lab use: ~50–100MB idle RAM, Rust implementation, RocksDB storage.

**Migration warnings:**
- Never binary-swap database files between Continuwuity, Tuwunel, or Conduit forks — their RocksDB schemas diverge
- Migration to Synapse requires PostgreSQL and full account/room recreation

## Dependencies

| Dependency | Hive | What it provides |
|---|---|---|
| ZeroTier mesh + Traefik | private-network-hive | Network transport, federation routing, hive-net bridge |
| hive-net Docker bridge | private-network-hive | Inter-service communication |
| MCP Matrix server | agent-services-hive (adjacent) | AI agent tooling for Matrix rooms |

## Integration Registry

Canonical port, network, and volume declarations: [queen-hive/docs/integration-registry/collab-services.md](https://github.com/eejd/queen-hive/blob/main/docs/integration-registry/collab-services.md)

Full planning and bootstrap phases: [queen-hive/docs/planning/COLLAB_SERVICES_PLAN.md](https://github.com/eejd/queen-hive/blob/main/docs/planning/COLLAB_SERVICES_PLAN.md)
