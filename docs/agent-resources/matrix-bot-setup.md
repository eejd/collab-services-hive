# Matrix Bot User Setup — home.zt

Procedure for registering the hive agent bot users on the `home.zt` private homeserver.
Run after `cshive private-setup` and `cshive start private` complete.

---

## Pre-requisites

- home.zt Continuwuity running: `cshive status private` shows healthy
- Admin account already created on home.zt
- `COLLAB_PRIMARY_ZT_IP` set in `.env`

---

## Bot Users to Register

| Bot User | Room | Gatekeeping |
|---|---|---|
| `@media-agent:home.zt` | `#media` | Soft |
| `@home-agent:home.zt` | `#home` | Soft |
| `@infra-agent:home.zt` | `#infra` | Soft |
| `@stash-agent:home.zt` | `#stash` | Hard (invite-only room, separate identity) |
| `@hive-agent:home.zt` | admin/dispatch | Service account for HTTP dispatch endpoint |

---

## Register Users via Admin API

Continuwuity exposes the Synapse-compatible admin API. Replace `<admin_token>` with your admin access token.

```bash
BASE="http://${COLLAB_PRIMARY_ZT_IP}:6167"
ADMIN_TOKEN="<your-admin-token>"

for BOT in media-agent home-agent infra-agent stash-agent hive-agent; do
    curl -s -X POST "${BASE}/_synapse/admin/v1/register" \
      -H "Authorization: Bearer ${ADMIN_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{
        \"username\": \"${BOT}\",
        \"password\": \"$(openssl rand -hex 32)\",
        \"admin\": false,
        \"displayname\": \"${BOT}\"
      }"
    echo "Registered @${BOT}:home.zt"
done
```

Save the generated passwords in a secrets file (gitignored). You'll exchange them for
access tokens using the login endpoint.

---

## Get Access Tokens

```bash
for BOT in media-agent home-agent infra-agent stash-agent hive-agent; do
    RESP=$(curl -s -X POST "${BASE}/_matrix/client/v3/login" \
      -H "Content-Type: application/json" \
      -d "{
        \"type\": \"m.login.password\",
        \"user\": \"${BOT}\",
        \"password\": \"<password-for-${BOT}>\"
      }")
    echo "${BOT}: $(echo $RESP | python3 -c 'import sys,json; print(json.load(sys.stdin)[\"access_token\"])')"
done
```

Store access tokens in `agent-services-hive/matrix-agent/.secrets` (gitignored), one per line:
```
MATRIX_ACCESS_TOKEN=<token-for-hive-agent>
MEDIA_AGENT_TOKEN=<token-for-media-agent>
...
```

---

## Create Rooms

```bash
# Using the admin/hive-agent account
TOKEN="<hive-agent-access-token>"

# Standard rooms (public within home.zt)
for ROOM in media home infra code; do
    curl -s -X POST "${BASE}/_matrix/client/v3/createRoom" \
      -H "Authorization: Bearer ${TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{
        \"room_alias_name\": \"${ROOM}\",
        \"name\": \"#${ROOM}\",
        \"preset\": \"private_chat\",
        \"visibility\": \"private\"
      }"
    echo "Created #${ROOM}:home.zt"
done

# Stash room — invite-only, no history for new members
curl -s -X POST "${BASE}/_matrix/client/v3/createRoom" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "room_alias_name": "stash",
    "name": "#stash",
    "preset": "private_chat",
    "visibility": "private",
    "initial_state": [
      {
        "type": "m.room.history_visibility",
        "content": {"history_visibility": "invited"}
      }
    ]
  }'
```

---

## Invite Bot Users to Their Rooms

```bash
# Get room IDs from alias
MEDIA_ID=$(curl -s "${BASE}/_matrix/client/v3/directory/room/%23media%3Ahome.zt" | python3 -c 'import sys,json; print(json.load(sys.stdin)["room_id"])')

# Invite each bot to its room
curl -s -X POST "${BASE}/_matrix/client/v3/rooms/${MEDIA_ID}/invite" \
  -H "Authorization: Bearer ${TOKEN}" \
  -d '{"user_id": "@media-agent:home.zt"}'

# Repeat for home-agent → #home, infra-agent → #infra, stash-agent → #stash
```

---

## Update config.yaml

After creating rooms, populate `agent-services-hive/matrix-agent/config.yaml` `rooms:` section
with the actual room IDs (`!<id>:home.zt` format).

---

## Verify

```bash
# Each bot should be able to sync
curl -s "${BASE}/_matrix/client/v3/sync?timeout=0" \
  -H "Authorization: Bearer <media-agent-token>" | python3 -m json.tool | grep '"joined_rooms"'
```
