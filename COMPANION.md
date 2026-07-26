# Melodize Companion — Installation Guide

The companion is a small Python HTTP service that runs alongside Navidrome and
gives the Melodize app file-management and audio-analysis capabilities that the
Subsonic/Navidrome API does not expose.

| Capability | Description |
|------------|-------------|
| Delete songs from server | Removes the file from disk |
| Download songs to server | Deezer FLAC via deemix; any URL via yt-dlp |
| Audio analysis | Detects BPM, Camelot wheel key, energy, spectral centroid, trailing silence, and phrase positions per song |
| Smart shuffle data | Real BPM, key, and energy values feed the app's DJ-arc planner (vs genre estimates without companion) |
| Transition mixing | Server-side time-stretched crossfade mixes. Not used by the app (client-side mixing removed in [2h](docs/pass-2/2h-playback-architecture.md)). |

**Requirements**
- Linux server with systemd
- Python 3.10+
- Navidrome on the same machine
- A reverse proxy (nginx, Caddy, NPM) or direct port access

---

## 1. Download the service script

```bash
curl -fsSL https://raw.githubusercontent.com/Catgirl-meow/melodize/main/companion/melodize-companion \
  -o /usr/local/bin/melodize-companion
chmod +x /usr/local/bin/melodize-companion
```

The single `melodize-companion` script contains the HTTP server, download
orchestration, analysis cache, and transition mixing. Two supporting modules
(`audio_analysis.py` and `analysis_cache.py`) are bundled at the top of the
same file.

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
  "api_key":             "PASTE_YOUR_GENERATED_KEY_HERE",
  "port":                8765,
  "music_dir":           "/opt/navidrome/music",
  "navidrome_db":        "/var/lib/navidrome/navidrome.db",
  "download_format":     "flac",
  "deezer_arl":          "",
  "analysis_threads":    2,
  "analysis_cache_path": "/var/lib/melodize-companion/analysis_cache.db",
  "mix_cache_dir":       "/var/lib/melodize-companion/mix_cache",
  "ytdlp_path":          "/usr/local/bin/yt-dlp",
  "deemix_path":         "deemix",
  "deezer_proxy":        ""
}
```

| Key | Description |
|-----|-------------|
| `api_key` | Secret the app sends with every request. Must match the key in app Settings. |
| `port` | Companion listen port. Default `8765`. |
| `music_dir` | Absolute path to Navidrome's music folder. |
| `navidrome_db` | Path to Navidrome's SQLite database. |
| `download_format` | Format for non-Deezer downloads: `flac`, `opus`, `mp3`. |
| `deezer_arl` | Optional Deezer ARL for HiFi FLAC. The app can also send this per-request. |
| `analysis_threads` | Max concurrent analysis workers. Default `2`. Increase for large libraries. |
| `analysis_cache_path` | Path to the SQLite analysis cache DB. Created automatically. |
| `mix_cache_dir` | Directory for cached transition WAV files. Created automatically. |
| `ytdlp_path` | Path to yt-dlp binary. Default searches `$PATH`. |
| `deemix_path` | Path to deemix binary. Default searches `$PATH`. |
| `deezer_proxy` | Optional SOCKS5/HTTP proxy URL for Deezer requests. Required if the server is in a country where Deezer is geo-blocked (e.g. Russia). Supports `socks5h://`, `socks5://`, `http://`, `https://`. See [Deezer geo-restrictions](#deezer-geo-restrictions) below. |

### Deezer geo-restrictions

If your server is in a country where Deezer is blocked (e.g. Russia), Deezer
API requests will fail even with a valid ARL. The companion validates the ARL
before every download, and if Deezer returns an error or empty response, the
download is rejected with a clear message.

**Fix:** set `deezer_proxy` in your config to route Deezer traffic through a
proxy in an unblocked country (e.g. a VPN, Clash, V2Ray, or Tailscale exit
node):

```json
{
  "deezer_proxy": "socks5h://192.168.1.100:7890"
}
```

The `socks5h://` scheme sends DNS resolution through the proxy (prevents DNS
leaks). For HTTP proxies use `http://` or `https://`. Both the ARL validation
and deemix download are routed through the proxy.

Only Deezer traffic is proxied — Navidrome, yt-dlp, and other requests go
direct.

> **Restart required** after changing this setting:
> ```bash
> systemctl restart melodize-companion
> ```

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
> is the companion's state directory (used for deemix config and analysis cache) — it must also be writable.

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

### Audio analysis dependencies (optional)

Required for BPM/key detection and trailing-silence measurement:

```bash
python3 -m pip install librosa numpy soundfile
```

If these are not installed, analysis jobs fail gracefully and the companion
reports `"analysis not available"`. The health endpoint shows the analysis status.

> `pyrubberband` is only needed for the server-side `/api/audio/mix-transition`
> endpoint. The app no longer uses it.

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
   machine running the companion (e.g. `192.0.2.50` or `203.0.113.1`).

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
    server YOUR_NAVIDROME_HOST:4533;   # e.g. 203.0.113.1:4533
    keepalive 32;
}

upstream companion {
    server YOUR_COMPANION_HOST:8765;   # e.g. 203.0.113.1:8765
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
# Expected: {"status": "ok", "version": "1.2.0"}
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

## 9. Data flow: companion → smart shuffle

When the companion is connected, the Melodize app periodically polls
`GET /api/audio/analysis` to sync all cached analysis results. These
real BPM, key, energy, and spectral-centroid values are fed into the
Smart Shuffle engine, which replaces genre-based estimates with actual
audio measurements. The engine uses three quality tiers:

| Tier | Data source | Features |
|------|-------------|----------|
| 1 — Full DJ | Companion (real BPM, key, energy) | Tight beatmatching (±3 %), harmonic key mixing (Camelot wheel), energy-curve DJ arc planning, spectral-timbre matching |
| 2 — Partial | Deezer metadata + genre estimates | Real BPM only, wider genre-based tolerances |
| 3 — Offline | Genre estimates only | Simple BPM proximity, genre compatibility |

Auto-detection: if ≥30 % of songs in the queue have companion-derived
BPM or energy, tier 1 is used automatically.

---

## 10. Updating the companion

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

The analysis cache is stored in a SQLite database (default:
`/var/lib/melodize-companion/analysis_cache.db`) and survives restarts.
No database migrations or config changes are needed between versions unless
the changelog says otherwise.

---

## 11. Troubleshooting

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

### Download fails: "Deezer unreachable from server"

The companion cannot reach Deezer's API. This usually means the server is in a
country where Deezer is geo-blocked (e.g. Russia). Check the companion log for
details:

```bash
journalctl -u melodize-companion -n 50 --no-pager | grep -i deezer
```

**Fix:** set `deezer_proxy` in your config to route Deezer traffic through a
proxy in an unblocked country. See [Deezer geo-restrictions](#deezer-geo-restrictions)
above.

### Download fails: "Deezer session expired"

The ARL is invalid or expired. Verify it in the app (Settings → Deezer) —the app validates from your phone's network; if the server is in a country where
Deezer is blocked, the same ARL will fail server-side — see
[Deezer geo-restrictions](#deezer-geo-restrictions).

Update your ARL by logging into [deezer.com](https://www.deezer.com), copying
the `arl` cookie from DevTools → Application → Cookies, and pasting it in
Settings.

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

### Analysis results not appearing in the app

The Melodize app polls `GET /api/audio/analysis` automatically. If results
are missing:

1. Check analysis has run: `curl -H "X-API-Key: YOUR_KEY" $BASE_URL/api/audio/analysis`
2. If the results list is empty, start a batch analysis from the app or
   send a `POST` to `/api/audio/analyze-batch` with an empty body
3. Verify librosa is installed: `python3 -c "import librosa; print(librosa.__version__)"`
4. Check the companion log for per-song analysis errors — bad audio files
   are skipped silently

### Song reappears after deletion

Navidrome takes a moment to rescan and remove the song from its database. The
app filters the deleted song locally while the scan completes. If the song
keeps reappearing after a library refresh, the scan may not have triggered —
initiate one manually from the Navidrome web UI under **Settings → Scan Library**.

---

## API reference

All endpoints require the `X-API-Key` header except `/health`.

### General

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/health` | Liveness probe. Returns `{"status":"ok","version":"1.2.0"}` |

### Song management

| Method | Path | Description |
|--------|------|-------------|
| `DELETE` | `/api/songs/{id}` | Delete a song by its Navidrome ID. Removes the file from disk. |
| `POST` | `/api/songs/download` | Start a background download job. Body: `{"url":"...", "deezer_arl":"..."}`. Returns `{"job_id":"..."}` |
| `GET` | `/api/songs/download/{job_id}` | Poll a download job. Returns `{"status":"queued|downloading|done|error", ...}` |

### Audio analysis

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/audio/analyze-batch` | Start batch analysis. Body: `{"song_ids":["..."]}` (omit for all songs). Returns `{"job_id":"...","status":"in_progress","total":...,"analyzed":0,"skipped":...,"failed":0}` |
| `GET` | `/api/audio/analyze-batch/{job_id}` | Poll analysis job progress. Returns `{"status":"in_progress|done","total":...,"analyzed":...,"skipped":...,"failed":...,"results":[...]}` |
| `GET` | `/api/audio/analysis` | All cached analysis results. Returns `{"results":[{song_id, bpm, key, energy, spectral_centroid, duration, tail_silence, data_version, phrase_positions}, ...]}` |
| `GET` | `/api/audio/analysis/{song_id}` | Single song's cached analysis |

### Transition mixing (server-side only)

> The app no longer consumes these endpoints. They remain server-side for direct
> API use or future re-integration.

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/audio/mix-transition` | Request a mix. Body: `{"song_a_id":"...", "song_b_id":"...", "mix_duration":10}`. Returns `{"job_id":"...","status":"mixing","quality":"perfect|good|acceptable|skip"}` |
| `GET` | `/api/audio/mix-transition/{job_id}` | Poll mix job. When done: `{"status":"done","url":"/api/audio/transition/{id}.wav"}` |
| `GET` | `/api/audio/transition/{filename}` | Download a completed WAV mix |

### Response format

Responses are always JSON. Non-2xx responses include an `"error"` field.

### Download routing

| URL pattern | Tool used | Notes |
|-------------|-----------|-------|
| `deezer.com/*` | deemix | Requires ARL for FLAC; falls back to error without ARL |
| anything else | yt-dlp | Requires yt-dlp + ffmpeg on the server |

### Analysis fields

| Field | Type | Description |
|-------|------|-------------|
| `bpm` | float (nullable) | Beats per minute — detected via librosa beat tracking |
| `key` | string (nullable) | Camelot wheel key (e.g. `8A`, `12B`) — Krumhansl–Schmuckler profile correlation |
| `energy` | float | Mean RMS energy of the signal |
| `spectral_centroid` | float | Spectral centroid (brightness proxy) in Hz |
| `duration` | float | Total file duration in seconds |
| `tail_silence` | float | Seconds of trailing silence at end of track — detected by scanning backward from file end; used by crossfade and transition mixing to avoid fading during silence |
| `phrase_positions` | array of float (nullable) | Timestamps of 16-bar phrase boundaries in seconds; used by future mixing features |
| `data_version` | integer | Schema version for cache-invalidation logic (currently `3`) |
