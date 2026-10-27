# Melodize companion

A single Python script that runs on the Navidrome host and adds what the Subsonic API can't do.
Melodize works without it; with it you get:

| Feature | Without | With |
|---|---|---|
| Smart shuffle data | Deezer BPM or genre estimates | Real BPM, Camelot key, energy, phrases, trailing silence |
| DJ transitions | Volume crossfade | Server-rendered, beat-matched mix for compatible pairs |
| Delete a song from the server | no | yes |
| Download a Deezer track (FLAC) or any yt-dlp URL into the library | no | yes |

Needs Linux with systemd, Python 3.10+, and Navidrome on the same machine (the companion reads
Navidrome's database and writes to its music folder).

## Install

```sh
# 1. The script
curl -fsSL https://raw.githubusercontent.com/Catgirl-meow/melodize/main/companion/melodize-companion \
  -o /usr/local/bin/melodize-companion
chmod +x /usr/local/bin/melodize-companion

# 2. Analysis (optional, but smart shuffle and DJ transitions need it)
python3 -m pip install librosa numpy soundfile pyrubberband

# 3. Downloads (optional): deemix for Deezer, yt-dlp + ffmpeg for everything else
python3 -m pip install deemix
curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp
chmod +x /usr/local/bin/yt-dlp
apt install ffmpeg

# 4. An API key; you paste it into the app later
python3 -c "import secrets; print(secrets.token_hex(32))"
mkdir -p /etc/melodize-companion /var/lib/melodize-companion
```

Create `/etc/melodize-companion/config.json`:

```json
{
  "api_key":      "PASTE_THE_KEY_HERE",
  "port":         8765,
  "music_dir":    "/opt/navidrome/music",
  "navidrome_db": "/var/lib/navidrome/navidrome.db"
}
```

| Key | Default | Meaning |
|---|---|---|
| `api_key` | (required) | Sent by the app as `X-API-Key`. |
| `port` / `bind` | `8765` / `0.0.0.0` | Listen address. Use `127.0.0.1` behind a proxy on the same host. |
| `music_dir` | (required) | Navidrome's music folder. |
| `navidrome_db` | (required) | Navidrome's `navidrome.db`. |
| `download_format` | `flac` | yt-dlp output: `flac`, `opus` or `mp3`. |
| `deezer_arl` | empty | Fallback ARL; the app normally sends its own. |
| `deezer_proxy` | empty | `socks5h://`, `socks5://` or `http(s)://` proxy for Deezer traffic only, for servers in countries where Deezer is blocked. SOCKS needs `pip install PySocks`. |
| `analysis_threads` | `2` | Parallel analysis workers. |
| `analysis_cache_path` | `/var/lib/melodize-companion/analysis_cache.db` | Analysis results (SQLite). |
| `mix_cache_dir` | `/var/lib/melodize-companion/mix_cache` | Rendered transitions. |
| `ytdlp_path` / `deemix_path` | from `$PATH` | Tool locations. |

Create `/etc/systemd/system/melodize-companion.service`, with `ReadWritePaths` matching your
`music_dir`:

```ini
[Unit]
Description=Melodize companion
After=network.target navidrome.service
Wants=navidrome.service

[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/melodize-companion
Restart=on-failure
ProtectSystem=strict
ReadWritePaths=/opt/navidrome/music /var/lib/melodize-companion
ReadOnlyPaths=/var/lib/navidrome
ProtectHome=true
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
```

```sh
systemctl daemon-reload
systemctl enable --now melodize-companion
curl http://localhost:8765/health        # {"status": "ok", "version": "1.3.0"}
```

To update, download the script again and `systemctl restart melodize-companion`. The analysis
cache survives updates.

## Expose it

The app needs one URL for the companion. Put it behind your reverse proxy for HTTPS; plain HTTP
is fine only on a LAN or VPN (the app accepts self-signed certificates only for private
addresses).

**Sub-path** (nginx; Nginx Proxy Manager takes the same block in
`/data/nginx/custom/server_proxy.conf`). App URL: `https://music.example.com/companion`

```nginx
location /companion/ {
    proxy_pass http://127.0.0.1:8765/;
    proxy_http_version 1.1;
    proxy_read_timeout 600s;
    client_max_body_size 0;
}
```

**Caddy**: `handle_path /companion/* { reverse_proxy localhost:8765 }` inside the site block
(same app URL), or a subdomain with `reverse_proxy localhost:8765` (app URL
`https://companion.example.com`).

**Same paths as Navidrome** (for example behind SafeLine WAF, where one upstream serves the
site): route the companion's paths before the Navidrome catch-all. App URL: the Navidrome URL
itself, with no `/companion`.

```nginx
location = /health    { proxy_pass http://COMPANION_HOST:8765; }
location /api/songs   { proxy_pass http://COMPANION_HOST:8765; client_max_body_size 0; }
location /api/audio   { proxy_pass http://COMPANION_HOST:8765; proxy_read_timeout 600s; }
location /            { proxy_pass http://NAVIDROME_HOST:4533; }
```

**Direct**: open port 8765 and use `http://SERVER_IP:8765`.

Then in the app, open **Settings → Melodize Companion**, enter the URL and the API key, and
refresh: the status turns green. The app then sends every song that has no analysis yet to the
companion and picks up the results as they come in.

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| Won't start | `journalctl -u melodize-companion -n 50`. Usually a wrong `music_dir`/`navidrome_db`, port 8765 taken, or `/var/lib/melodize-companion` missing. |
| Delete or download gives 405 | The URL's path prefix is wrong, so requests reach Navidrome. `curl URL/health` must return JSON, not HTML. |
| "Song not found in database" | `navidrome_db` points to the wrong file, or the library in the app is stale (pull to refresh). |
| Deleted song comes back | Navidrome hasn't rescanned yet; start a scan in Navidrome's web UI. |
| "DRM protection" | yt-dlp got a Deezer URL: install deemix and restart the companion. |
| "Deezer unreachable from server" | Deezer is blocked where the server is. Set `deezer_proxy`. |
| "Deezer session expired" | Replace the ARL in **Settings → Deezer**. If it works in the app but not on the server, see the line above. |
| No analysis data | `python3 -c "import librosa"` on the server; then refresh the companion status in the app to retry. Unreadable files are skipped. |

## API

All endpoints except `/health` need the `X-API-Key` header. Responses are JSON; errors carry an
`error` field.

| Method and path | Purpose |
|---|---|
| `GET /health` | Liveness and version. |
| `DELETE /api/songs/{id}` | Delete a song file by its Navidrome id. |
| `POST /api/songs/download` | `{"url", "deezer_arl"?}` starts a download job (deemix for `deezer.com` URLs, yt-dlp otherwise); returns `job_id`. |
| `GET /api/songs/download/{job_id}` | Job status: `queued`, `downloading`, `done` or `error`. |
| `POST /api/audio/analyze-batch` | `{"song_ids"?}` analyzes the given songs, or all; returns `job_id`. |
| `GET /api/audio/analyze-batch/{job_id}` | Progress: `total`, `analyzed`, `skipped`, `failed`. |
| `GET /api/audio/analysis[/{song_id}]` | Cached analysis: `bpm`, `key` (Camelot), `energy`, `spectral_centroid`, `duration`, `tail_silence`, `phrase_positions`, `data_version`. |
| `POST /api/audio/mix-transition` | `{"song_a_id", "song_b_id", "mix_duration"}` renders a transition; returns `job_id` and `quality`. |
| `GET /api/audio/mix-transition/{job_id}` | Status; when done, the WAV's `url`. |
| `GET /api/audio/transition/{file}.wav` | The rendered transition. |
