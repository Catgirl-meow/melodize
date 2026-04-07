# Melodize Companion — Installation Guide

The companion is a small Python HTTP service that runs alongside Navidrome and
gives the Melodize app file-management capabilities that the Subsonic/Navidrome
API does not expose: deleting songs from the server and downloading songs from
the Deezer catalog directly onto the server.

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
  "deezer_arl":   ""
}
```

| Key | Description |
|-----|-------------|
| `api_key` | Secret that the app sends with every request. Must match the key entered in app Settings. |
| `port` | Port the companion listens on. Default `8765`. |
| `music_dir` | **Absolute path** to the folder Navidrome scans for music. Find it in `/etc/navidrome/navidrome.toml` (`MusicFolder =`). |
| `navidrome_db` | Path to Navidrome's SQLite database. Usually `/var/lib/navidrome/navidrome.db`. |
| `download_format` | Audio format for non-Deezer downloads. `flac`, `opus`, `mp3`. |
| `deezer_arl` | Optional Deezer ARL cookie for FLAC downloads (HiFi subscription required). The app can also send this per-request from Settings. |

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
ReadWritePaths=/var/lib/melodize-companion
ReadOnlyPaths=/var/lib/navidrome
ProtectHome=true
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
```

> **Important:** `ReadWritePaths` must match your `music_dir`. `/var/lib/melodize-companion`
> is the companion's state directory (used for deemix config) — it must also be writable.

Create the state directory and enable the service:

```bash
mkdir -p /var/lib/melodize-companion
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

## 5. Install download backends

Two tools are required for server-side downloads. **deemix** handles Deezer
URLs (including HiFi FLAC via ARL). **yt-dlp** handles all other URLs.

### deemix (required for Deezer downloads)

```bash
# Install pip if not already present
curl -sS https://bootstrap.pypa.io/get-pip.py | python3

# Install deemix
python3 -m pip install deemix

# Verify
deemix --help
```

### yt-dlp (required for non-Deezer downloads)

```bash
# Recommended: standalone binary (no Python deps)
curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp \
  -o /usr/local/bin/yt-dlp
chmod +x /usr/local/bin/yt-dlp

# Verify
yt-dlp --version
```

yt-dlp also requires **ffmpeg** for audio format conversion:

```bash
apt install ffmpeg -y
```

If either tool is at a non-standard path, set it in config:

```json
"ytdlp_path":  "/usr/local/bin/yt-dlp",
"deemix_path": "/usr/local/bin/deemix"
```

---

## 6. Expose via reverse proxy (recommended)

Running behind your existing reverse proxy gives you HTTPS for free and avoids
opening extra ports. Choose the option that matches your setup.

> **URL format depends on your proxy option:**
> - Options A / B (sub-path) and C / Caddy (sub-path): Companion URL in the app is `https://music.your-domain.com/companion`
> - Option E (SafeLine + nginx mux) and dedicated subdomain setups: Companion URL = the bare Navidrome/site URL, **no `/companion` suffix**

### Option A — Nginx Proxy Manager (GUI)

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

### Option E — SafeLine WAF + nginx mux (recommended for SafeLine users)

If you run [SafeLine](https://github.com/chaitin/safeline) WAF, the cleanest
approach is a single nginx "mux" that sits between SafeLine's tengine and both
Navidrome and the companion. SafeLine's backend points at the nginx mux; the
mux routes companion paths internally. **No extra port or subdomain needed.**

#### 1. Create the nginx mux config

On the **reverse proxy host** (the machine running SafeLine), create
`/etc/nginx/conf.d/melodize-mux.conf`:

```nginx
# Melodize mux — routes Navidrome and companion under one upstream.
# SafeLine backend points here (127.0.0.1:PORT_BELOW).
# Adjust IPs/ports to match your Tailscale or LAN addresses.

upstream navidrome {
    server YOUR_NAVIDROME_HOST:4533;   # e.g. 100.73.73.73:4533
    keepalive 32;
}

upstream companion {
    server YOUR_COMPANION_HOST:8765;   # e.g. 100.73.73.73:8765
    keepalive 8;
}

server {
    listen 127.0.0.1:4534;            # SafeLine backend points here

    # Pass real client IP forwarded by SafeLine tengine
    set_real_ip_from 127.0.0.0/8;
    real_ip_header X-Forwarded-For;

    proxy_http_version 1.1;
    proxy_set_header Connection "";
    proxy_set_header Host $http_host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $http_x_forwarded_proto;

    # Companion: liveness probe
    location = /health {
        proxy_pass http://companion;
    }

    # Companion: song management API
    location /api/songs {
        proxy_pass http://companion;
        client_max_body_size 0;
    }

    # Everything else → Navidrome
    location / {
        proxy_pass http://navidrome;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $http_upgrade;
        client_max_body_size 0;
        proxy_read_timeout 600s;
    }
}
```

```bash
nginx -t && systemctl reload nginx
```

#### 2. Point SafeLine backend at the mux

In the SafeLine management panel, add or update the site backend to
`127.0.0.1:4534` (or whatever port you chose in the config above).

#### 3. App companion URL

Because the mux routes companion paths at the **root level** (no `/companion`
prefix), the Companion URL in the app is the **same as your Navidrome URL**:

```
https://music.your-domain.com
```

> **Do NOT** append `/companion` — the mux routes `/health` and `/api/songs`
> directly; adding a prefix will route those requests to Navidrome instead,
> causing 405 errors on delete/download.

---

## 7. Configure the Melodize app

In the app: **Settings → Melodize Companion**

| Proxy option | Companion URL |
|---|---|
| Option A / B (sub-path `/companion/`) | `https://music.your-domain.com/companion` |
| Option C Caddy (sub-path) | `https://music.your-domain.com/companion` |
| Option C Caddy (subdomain) | `https://companion.your-domain.com` |
| Option D (direct port) | `http://YOUR_SERVER_IP:8765` |
| **Option E (SafeLine mux)** | `https://music.your-domain.com` (same as Navidrome URL) |

Also set the **API Key** to the value generated in Step 2.

Tap the refresh icon next to the status indicator. It should turn green and
show **"Server management available"**.

For Deezer FLAC downloads, also configure your ARL in **Settings → Deezer → Connect account**.

---

## 8. Verify the installation

Replace `BASE_URL` with your companion URL from the table in Section 7
(e.g. `https://music.your-domain.com/companion` or `https://music.your-domain.com`).

```bash
curl $BASE_URL/health
# Expected: {"status": "ok", "version": "1.1.0"}
```

Test authentication:

```bash
# Should succeed
curl -X DELETE $BASE_URL/api/songs/nonexistent \
  -H "X-API-Key: YOUR_KEY"
# Expected: {"error": "song not found in database"}

# Should be rejected
curl -X DELETE $BASE_URL/api/songs/nonexistent \
  -H "X-API-Key: wrongkey"
# Expected: {"error": "invalid or missing API key"}
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

# Confirm
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
- `/var/lib/melodize-companion` doesn't exist → run `mkdir -p /var/lib/melodize-companion`

### Download fails: "DRM protection"

This means yt-dlp was used for a Deezer URL. Ensure deemix is installed
(`deemix --help`) and the companion was restarted after installation.

### Download fails: "Deezer ARL not configured"

Set your ARL in **Settings → Deezer → Connect account** in the app, or add
`"deezer_arl": "YOUR_ARL"` to the config file.

### Download job stuck, no error shown

Check the companion log for thread exceptions:

```bash
journalctl -u melodize-companion -n 100 --no-pager | grep -E "error|Error|Exception"
```

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

### Delete / download returns "405 Method Not Allowed"

The companion URL has a wrong path prefix. Navidrome returns 302→200 for
unknown GETs (which fools the health check), but rejects DELETE/POST with 405.

**Fix:** check the Companion URL in Settings matches the table in Section 7.
For SafeLine (Option E) and dedicated subdomains, the URL must NOT include
a `/companion` suffix. Remove it.

### App shows "Cannot reach companion"

1. Check companion running: `systemctl status melodize-companion`
2. Verify URL with curl (see Section 8) — health endpoint must return `{"status":"ok"}` not HTML
3. Check for typo in URL — no trailing slash, correct path prefix per Section 7
4. If using Nginx Proxy Manager, run `nginx -t` on the NPM host to confirm
   the custom config loaded without errors
5. If the status indicator was green but delete/download still failed: update
   the app to v1.7.8+ which validates the health response body instead of
   just checking the HTTP status code

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
| `POST` | `/api/songs/download` | Start a background download job. Body: `{"url":"...", "deezer_arl":"..."}`. Returns `{"job_id":"..."}` |
| `GET` | `/api/songs/download/{job_id}` | Poll a download job. Returns `{"status":"queued\|downloading\|done\|error", ...}` |

Responses are always JSON. Non-2xx responses include an `"error"` field.

### Download routing

| URL pattern | Tool used | Notes |
|-------------|-----------|-------|
| `deezer.com/*` | deemix | Requires ARL for FLAC; falls back to error without ARL |
| anything else | yt-dlp | Requires yt-dlp + ffmpeg on the server |
