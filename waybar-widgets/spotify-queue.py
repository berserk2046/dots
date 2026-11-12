#!/usr/bin/env python3
"""Prints the song played before and the one coming up next in Spotify, as JSON, for PlayerCard.qml.

Uses the Spotify Web API with read-only access (user-read-playback-state, user-read-recently-played).
One-time setup: create an app at https://developer.spotify.com/dashboard with the Redirect URI
http://127.0.0.1:8888/callback and "Web API" ticked, then run:

    spotify-queue.py login <Client ID>

and approve in the browser. The login is kept in ~/.local/state/waybar-widgets/spotify.json (mode 600);
revoke it any time at spotify.com → Account → Apps.

Usage: spotify-queue.py            -> {"previous": {...} | null, "next": {...} | null}  or  {"error": "..."}
       spotify-queue.py login <Client ID>
"""

import base64
import hashlib
import http.server
import json
import os
import secrets
import sys
import time
import urllib.parse
import urllib.request
import webbrowser

STATE = os.path.join(os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"),
                     "waybar-widgets", "spotify.json")
REDIRECT = "http://127.0.0.1:8888/callback"
SCOPES = "user-read-playback-state user-read-recently-played"


def save(data):
    os.makedirs(os.path.dirname(STATE), mode=0o700, exist_ok=True)
    fd = os.open(STATE + ".tmp", os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        json.dump(data, f)
    os.replace(STATE + ".tmp", STATE)


def request(url, data=None, token=None):
    req = urllib.request.Request(url, data=urllib.parse.urlencode(data).encode() if data else None)
    if token:
        req.add_header("Authorization", "Bearer " + token)
    with urllib.request.urlopen(req, timeout=8) as res:
        body = res.read()
        return json.loads(body) if body else {}


def token_request(state, data):
    res = request("https://accounts.spotify.com/api/token", dict(data, client_id=state["client_id"]))
    state["access_token"] = res["access_token"]
    state["expires"] = time.time() + res.get("expires_in", 3600) - 60
    # Spotify rotates refresh tokens with PKCE: keep the newest one
    state["refresh_token"] = res.get("refresh_token", state.get("refresh_token"))
    save(state)


# PKCE login: no client secret; the browser sends the code back to a one-shot local server.
def login(client_id):
    verifier = secrets.token_urlsafe(64)
    challenge = base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).rstrip(b"=").decode()
    nonce = secrets.token_urlsafe(16)
    result = {}

    class Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            query = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
            if query.get("state", [""])[0] == nonce:
                result.update({k: v[0] for k, v in query.items()})
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.end_headers()
            self.wfile.write("Done, you can close this tab.".encode() if "code" in result
                             else "Login failed, see the terminal.".encode())

        def log_message(self, *args):
            pass

    server = http.server.HTTPServer(("127.0.0.1", 8888), Handler)
    url = "https://accounts.spotify.com/authorize?" + urllib.parse.urlencode({
        "client_id": client_id, "response_type": "code", "redirect_uri": REDIRECT, "scope": SCOPES,
        "code_challenge_method": "S256", "code_challenge": challenge, "state": nonce,
    })
    print("Opening the Spotify login in your browser. If it doesn't open, visit:\n" + url)
    webbrowser.open(url)
    server.handle_request()
    server.server_close()
    if "code" not in result:
        sys.exit("Login failed: " + result.get("error", "no code received"))
    state = {"client_id": client_id}
    token_request(state, {"grant_type": "authorization_code", "code": result["code"],
                          "redirect_uri": REDIRECT, "code_verifier": verifier})
    print("Logged in. Saved to " + STATE)


def track(item):
    if not item:
        return None
    images = item.get("album", {}).get("images") or [{}]
    return {
        "title": item.get("name", ""),
        "artist": ", ".join(a["name"] for a in item.get("artists", [])),
        "art": images[-1].get("url", ""),  # smallest
        "uri": item.get("uri", ""),
    }


def main():
    if len(sys.argv) == 3 and sys.argv[1] == "login":
        return login(sys.argv[2])
    try:
        with open(STATE) as f:
            state = json.load(f)
    except (OSError, ValueError):
        return print(json.dumps({"error": "not logged in"}))
    try:
        if time.time() > state.get("expires", 0):
            token_request(state, {"grant_type": "refresh_token", "refresh_token": state["refresh_token"]})
        token = state["access_token"]
        queue = request("https://api.spotify.com/v1/me/player/queue", token=token)
        recent = request("https://api.spotify.com/v1/me/player/recently-played?limit=1", token=token)
        print(json.dumps({
            "previous": track((recent.get("items") or [{}])[0].get("track")),
            "next": track((queue.get("queue") or [None])[0]),
        }))
    except Exception as e:  # offline, revoked, rate limited…
        print(json.dumps({"error": str(e)}))


main()
