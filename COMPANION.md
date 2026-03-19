# Melodize Companion — Installation Guide

The companion is a small Python HTTP service that runs alongside Navidrome and
gives the Melodize app file-management capabilities that the Subsonic/Navidrome
API intentionally does not expose: deleting songs from the server, and
(future) downloading songs from external sources directly onto the server.

**Requirements**
- Linux server with systemd (Debian 12+ / Ubuntu 22.04+ / any modern distro)
- Python 3.10 or newer (check with `python3 --version`)
- Navidrome running on the same machine
- A reverse proxy (nginx, Caddy, Nginx Proxy Manager) **or** direct port access

---

## 1. Download the service script

```bash
curl -fsSL https://raw.githubusercontent.com/Catgirl-meow/melodize/main/companion/melodize-companion \
  -o /usr/local/bin/melodize-companion
chmod +x /usr/local/bin/melodize-companion
```

---

## 2. Generate an API key

```bash
python3 -c "import secrets; print(secrets.token_hex(32))"
```

Save the output — you will paste it into the Melodize app later.

---

## 3. Create the config file

```bash
mkdir -p /etc/melodize-companion
```

Create `/etc/melodize-companion/config.json`:

```json
{
  "api_key":      "PASTE_YOUR_GENERATED_KEY_HERE",
  "port":         8765,
  "music_dir":    "/opt/navidrome/music",
  "navidrome_db": "/var/lib/navidrome/navidrome.db",
  "download_format": "flac",
  "ytdlp_path":   "yt-dlp"
}
```

| Key | Description |
|-----|-------------|
| `api_key` | Secret that the app sends with every request. Must match the key entered in app Settings. |
| `port` | Port the companion listens on. Default `8765`. Only relevant if you expose it directly — behind a reverse proxy any port works. |
| `music_dir` | **Absolute path** to the folder Navidrome scans for music. Find it in `/etc/navidrome/navidrome.toml` (`MusicFolder =`). |
| `navidrome_db` | Path to Navidrome's SQLite database. Usually `/var/lib/navidrome/navidrome.db`. |
| `download_format` | Audio format for server-side downloads (future feature). `flac`, `opus`, `mp3`. |
| `ytdlp_path` | Path or command name for yt-dlp. Install it with `pip install yt-dlp` or `pipx install yt-dlp`. Only required for the download feature. |

### Finding your paths

```bash
# Navidrome config
cat /etc/navidrome/navidrome.toml

# Locate the database if the default path doesn't exist
find / -name 'navidrome.db' 2>/dev/null
```

---

## 4. Install the systemd service

Create `/etc/systemd/system/melodize-companion.service`:

```ini
[Unit]
Description=Melodize Companion — Navidrome file management sidecar
Documentation=https://github.com/Catgirl-meow/melodize
After=network.target navidrome.service
Wants=navidrome.service

[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/bin/melodize-companion
Restart=on-failure
RestartSec=5s
StandardOutput=journal
StandardError=journal
SyslogIdentifier=melodize-companion

# Security hardening
ProtectSystem=strict
ReadWritePaths=/opt/navidrome/music
ReadOnlyPaths=/var/lib/navidrome
ProtectHome=true
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
```

> **Important:** `ReadWritePaths` must match your `music_dir`. If they differ,
> the service will fail with a permission error when trying to delete files.

Enable and start:

```bash
systemctl daemon-reload
systemctl enable --now melodize-companion

# Verify it started
systemctl status melodize-companion
```

Check the live log:

```bash
journalctl -u melodize-companion -f
```

---

## 5. Expose via reverse proxy (recommended)

Running behind your existing reverse proxy gives you HTTPS for free and avoids
opening extra ports. Choose the option that matches your setup.

### Option A — Nginx Proxy Manager (GUI)

The easiest option if you already use NPM.

NPM supports custom nginx snippets per-host without touching the database.
The file is included at the bottom of every server block for that host.

1. Create the custom config directory if it doesn't exist:
   ```bash
   mkdir -p /data/nginx/custom
   ```

2. Create `/data/nginx/custom/server_proxy.conf`:
   ```nginx
   location /companion/ {
       proxy_pass http://YOUR_NAVIDROME_SERVER_IP:8765/;
       proxy_http_version 1.1;
       proxy_read_timeout 600s;
       proxy_send_timeout 600s;
       client_max_body_size 0;
   }
   ```
   Replace `YOUR_NAVIDROME_SERVER_IP` with the LAN or Tailscale IP of the
   machine running the companion (e.g. `192.168.1.50` or `100.73.73.73`).

3. Test and reload:
   ```bash
   nginx -t && nginx -s reload
   ```

4. The companion is now reachable at:
   ```
   https://music.your-domain.com/companion/
   ```

> This file is **not managed by NPM** and survives NPM upgrades and
> configuration regenerations.

---

### Option B — Plain nginx (conf.d)

Add a `location` block inside your existing Navidrome server block, or create
a dedicated server block.

**Sub-path on the same domain** (simplest):

```nginx
# Inside your existing Navidrome server block
location /companion/ {
    proxy_pass         http://127.0.0.1:8765/;
    proxy_http_version 1.1;
    proxy_read_timeout 600s;
    proxy_send_timeout 600s;
    client_max_body_size 0;
}
```

**Dedicated subdomain** (cleaner separation):

```nginx
server {
    listen 443 ssl http2;
    server_name companion.your-domain.com;

    ssl_certificate     /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;

    location / {
        proxy_pass         http://127.0.0.1:8765/;
        proxy_http_version 1.1;
        proxy_read_timeout 600s;
        proxy_send_timeout 600s;
        client_max_body_size 0;
    }
}
```

Reload nginx: `nginx -t && systemctl reload nginx`

---

### Option C — Caddy

```caddy
music.your-domain.com {
    # Existing Navidrome proxy ...
    handle_path /companion/* {
        reverse_proxy localhost:8765
    }
}
```

Or a dedicated subdomain:

```caddy
companion.your-domain.com {
    reverse_proxy localhost:8765
}
```

Caddy handles HTTPS certificates automatically.

---

### Option D — Direct port access (no reverse proxy)

If the server is directly reachable and you don't use a reverse proxy, open
port 8765 in your firewall:

```bash
# ufw
ufw allow 8765/tcp

# iptables
iptables -A INPUT -p tcp --dport 8765 -j ACCEPT
```

The app companion URL would then be `http://YOUR_SERVER_IP:8765`.

> **Note:** This uses plain HTTP. Only use this inside a private network or
> over a VPN (Tailscale, WireGuard).

---

## 6. Configure the Melodize app

In the app: **Settings → Melodize Companion**

| Field | Value |
|-------|-------|
| Companion URL | `https://music.your-domain.com/companion` (no trailing slash) |
| API Key | The key you generated in Step 2 |

Tap the refresh icon next to the status indicator. It should turn green and
show **"Server management available"**.

---

## 7. Verify the installation

From any machine:

```bash
curl https://music.your-domain.com/companion/health
# Expected: {"status": "ok", "version": "1.1.0"}
```

Test authentication:

```bash
# Should succeed
curl -X DELETE https://music.your-domain.com/companion/api/songs/nonexistent \
  -H "X-API-Key: YOUR_KEY"
# Expected: {"error": "song not found in database"}

# Should be rejected
curl -X DELETE https://music.your-domain.com/companion/api/songs/nonexistent \
  -H "X-API-Key: wrongkey"
# Expected: {"error": "invalid or missing API key"}
```

---

## 8. Install yt-dlp (for future download feature)

When the in-app "Download to server" feature ships, you will need yt-dlp on
the server.

```bash
# Recommended: pipx (isolated, easy to update)
apt install pipx -y
pipx install yt-dlp
pipx ensurepath

# Or directly with pip
pip install yt-dlp

# Verify
yt-dlp --version
```

Update yt-dlp periodically (sites change their APIs):

```bash
yt-dlp -U
# or
pipx upgrade yt-dlp
```

If yt-dlp is not at `/usr/local/bin/yt-dlp`, set the full path in config:

```json
"ytdlp_path": "/root/.local/bin/yt-dlp"
```

ffmpeg is required by yt-dlp for audio conversion:

```bash
apt install ffmpeg -y
```

---

## 9. Updating the companion

```bash
# Download the new version
curl -fsSL https://raw.githubusercontent.com/Catgirl-meow/melodize/main/companion/melodize-companion \
  -o /usr/local/bin/melodize-companion
chmod +x /usr/local/bin/melodize-companion

# Restart
systemctl restart melodize-companion

# Confirm the new version
curl http://localhost:8765/health
```

No database migrations or config changes are needed between versions unless
the changelog says otherwise.

---

## 10. Troubleshooting

### Companion won't start

```bash
journalctl -u melodize-companion -n 50 --no-pager
```

Common causes:
- `music_dir` or `navidrome_db` path is wrong → check with `ls` first
- Port 8765 already in use → change `port` in config or kill the other process
- Python version too old → `python3 --version` must be 3.10+

### "Song not found in database" on delete

The Navidrome song ID the app sends doesn't match any row in `media_file`.
This can happen if:
- The app's local cache is stale — pull to refresh the library
- The navidrome_db path in config points to the wrong file

### "Permission denied" when deleting

The service runs as root by default, so this shouldn't happen. If you changed
the `User=` in the systemd unit to a non-root user, that user must have write
permission on `music_dir`:

```bash
chown -R melodize:melodize /opt/navidrome/music
```

### App shows "Cannot reach companion"

1. Check the companion is running: `systemctl status melodize-companion`
2. Verify the URL with curl from another device (see Section 7)
3. Check for typo in the URL — no trailing slash, correct path prefix
4. If using Nginx Proxy Manager, run `nginx -t` on the NPM host to confirm
   the custom config loaded without errors

### Song reappears after deletion

Navidrome takes a moment to rescan and remove the song from its database. The
app filters the deleted song locally while the scan completes. If the song
keeps reappearing after a library refresh, the scan may not have triggered —
initiate one manually from the Navidrome web UI under **Settings → Scan Library**.

---

## API reference

All endpoints require the `X-API-Key` header except `/health`.

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/health` | Liveness probe. Returns `{"status":"ok","version":"..."}` |
| `DELETE` | `/api/songs/{id}` | Delete a song by its Navidrome ID. Removes the file from disk. |
| `POST` | `/api/songs/download` | Start a background download job. Body: `{"url":"..."}`. Returns `{"job_id":"..."}` |
| `GET` | `/api/songs/download/{job_id}` | Poll a download job. Returns `{"status":"queued\|downloading\|done\|error", ...}` |

Responses are always JSON. Non-2xx responses include an `"error"` field.
