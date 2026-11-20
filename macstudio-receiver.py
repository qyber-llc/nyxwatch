#!/usr/bin/env python3
"""
NyxWatch - Mac Studio Geolocation & Alert Receiver (Zero Cloud)
Run on your Mac Studio: python3 macstudio-receiver.py
"""
import base64
import json
import os
import subprocess
from http.server import BaseHTTPRequestHandler, HTTPServer

SAVE_DIR = os.path.expanduser("~/Pictures/NyxWatch-Studio")
os.makedirs(SAVE_DIR, exist_ok=True)


class NyxWatchReceiver(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        raw = self.rfile.read(length)
        try:
            data = json.loads(raw.decode("utf-8"))
        except Exception:
            self.send_response(400)
            self.end_headers()
            return

        host = data.get("host", "MacBook")
        reason = data.get("reason", "Intrusion")
        ts = data.get("timestamp", "")
        maps_url = data.get("maps_url", "")
        lat = data.get("latitude")
        lon = data.get("longitude")
        net = data.get("network", "")

        print(f"\n🚨 [{ts}] ALERTE NYXWATCH ({host}) : {reason} | NET: {net}")
        if lat is not None and lon is not None:
            print(f"📍 Position : {lat}, {lon} -> {maps_url}")
            msg = f"{host}: {reason} | GPS: {lat:.5f}, {lon:.5f}"
        else:
            msg = f"{host}: {reason}"

        for b64_key, name_key in [("busted_image_b64", "busted_filename"), ("face_image_b64", "face_filename")]:
            if b64_key in data:
                fname = os.path.basename(data.get(name_key, f"{b64_key}.jpg"))
                out_path = os.path.join(SAVE_DIR, fname)
                with open(out_path, "wb") as f:
                    f.write(base64.b64decode(data[b64_key]))
                print(f"🖼️  Sauvegardé : {out_path}")

        subprocess.run([
            "osascript",
            "-e",
            f'display notification "{msg}" with title "🚨 NyxWatch Alert" sound name "Sosumi"'
        ], check=False)

        self.send_response(200)
        self.end_headers()
        self.wfile.write(b'{"ok":true}')


if __name__ == "__main__":
    server = HTTPServer(("0.0.0.0", 8787), NyxWatchReceiver)
    print("🛡️ NyxWatch Mac Studio Receiver listening on http://0.0.0.0:8787/alert")
    server.serve_forever()
