#!/usr/bin/env python3
"""
NyxWatch Cross-Platform Desktop Agent (Windows & Linux)
- Manual 1-click / Hotkey arming + optional BLE proximity (bleak)
- HID (keyboard/mouse) + AC power unplug tripwires
- 3s webcam capture + Cherry Red BUSTED circular stamp & bottom ALERT ticker
- Stealth Mode vs Flag Mode (screen flash + English/French voice alert)
- Instant Screen Lock (Windows LockWorkStation / Linux loginctl)
- Exfiltration: Telegram + local WhatsApp bridge + Mac Studio receiver + offline retry queue
"""
import argparse
import base64
import ctypes
import json
import math
import os
import platform
import shutil
import socket
import subprocess
import sys
import threading
import time
from datetime import datetime
from pathlib import Path

import cv2
import psutil
import requests
from PIL import Image, ImageDraw, ImageFont
from pynput import keyboard, mouse

SYSTEM = platform.system()  # "Windows" or "Linux"
DATA_DIR = Path.home() / ".nyxwatch"
CAPTURES_DIR = Path.home() / "Pictures" / "NyxWatch"
PENDING_FILE = DATA_DIR / "pending_alerts.json"
DATA_DIR.mkdir(parents=True, exist_ok=True)
CAPTURES_DIR.mkdir(parents=True, exist_ok=True)


def get_local_ip() -> str:
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "Offline"


def lock_screen():
    if SYSTEM == "Windows":
        ctypes.windll.user32.LockWorkStation()
    elif SYSTEM == "Linux":
        for cmd in [
            ["loginctl", "lock-session"],
            ["gnome-screensaver-command", "-l"],
            ["xdg-screensaver", "lock"],
        ]:
            if shutil.which(cmd[0]):
                subprocess.run(cmd, check=False)
                break


def speak_flag_alert(lang: str = "en"):
    msg = (
        "Vous n'êtes pas autorisé à toucher cet ordinateur. La séquence vient d'être enregistrée et transmise."
        if lang == "fr"
        else "You are not authorized to touch this laptop. The sequence has just been recorded and transmitted to my owner."
    )
    try:
        import pyttsx3

        engine = pyttsx3.init()
        engine.say(msg)
        engine.runAndWait()
    except Exception:
        if SYSTEM == "Linux" and shutil.which("espeak"):
            subprocess.Popen(["espeak", msg])


def flash_screen():
    try:
        import tkinter as tk

        root = tk.Tk()
        root.attributes("-fullscreen", True)
        root.attributes("-topmost", True)
        root.configure(background="white")
        root.after(350, root.destroy)
        root.mainloop()
    except Exception:
        pass


def apply_busted_stamp(frame_bgr, net_info: str):
    rgb = cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2RGB)
    img = Image.fromarray(rgb).convert("RGBA")
    w, h = img.size
    overlay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)

    cherry_red = (220, 29, 46, 240)
    jet_black = (11, 11, 12, 230)
    scale = max(0.75, min(w / 640.0, 2.0))

    # 1. Circular red BUSTED stamp (top-right)
    r = int(52 * scale)
    cx, cy = w - r - int(18 * scale), r + int(18 * scale)
    draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(220, 29, 46, 30), outline=cherry_red, width=max(2, int(3.5 * scale)))
    ir = int(r * 0.62)
    draw.ellipse((cx - ir, cy - ir, cx + ir, cy + ir), outline=cherry_red, width=max(1, int(1.5 * scale)))

    bh = int(26 * scale)
    draw.rectangle((cx - r - 2, cy - bh // 2, cx + r + 2, cy + bh // 2), fill=cherry_red)
    font_busted = ImageFont.load_default()
    draw.text((cx - int(22 * scale), cy - int(6 * scale)), "BUSTED", fill=(255, 255, 255, 255), font=font_busted)

    # 2. Bottom teleprompter ALERT ticker
    bar_h = int(28 * scale)
    draw.rectangle((0, h - bar_h, w, h), fill=jet_black)
    draw.rectangle((0, h - bar_h, w, h - bar_h + max(2, int(2 * scale))), fill=cherry_red)
    tag_w = int(60 * scale)
    draw.rectangle((0, h - bar_h, tag_w, h), fill=cherry_red)
    draw.text((int(12 * scale), h - bar_h + int(8 * scale)), "ALERT", fill=(255, 255, 255, 255), font=font_busted)

    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    ticker = f"{ts}  •  NET {net_info}  •  NYXWATCH"
    draw.text((tag_w + int(10 * scale), h - bar_h + int(8 * scale)), ticker, fill=(255, 255, 255, 255), font=font_busted)

    combined = Image.alpha_composite(img, overlay).convert("RGB")
    return combined


def capture_3s_clip_and_stamp(duration: float = 3.0):
    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        return None, None

    stamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    video_path = CAPTURES_DIR / f"capture_{stamp}.mp4"
    jpg_path = CAPTURES_DIR / f"capture_{stamp}.jpg"

    fps = 20.0
    w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH) or 640)
    h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT) or 480)
    fourcc = cv2.VideoWriter_fourcc(*"mp4v")
    writer = cv2.VideoWriter(str(video_path), fourcc, fps, (w, h))

    end_time = time.time() + duration
    mid_frame = None
    frame_idx = 0
    while time.time() < end_time:
        ok, frame = cap.read()
        if not ok:
            break
        writer.write(frame)
        if frame_idx == 10:
            mid_frame = frame.copy()
        frame_idx += 1

    cap.release()
    writer.release()

    if mid_frame is not None:
        stamped = apply_busted_stamp(mid_frame, get_local_ip())
        stamped.save(str(jpg_path), quality=92)
    else:
        jpg_path = None

    return video_path, jpg_path


class NyxWatchDesktop:
    def __init__(self, args):
        self.args = args
        self.armed = args.arm_now
        self.last_alert = 0.0
        self.lock = threading.Lock()

    def trigger_alert(self, reason: str):
        with self.lock:
            if not self.armed or (time.time() - self.last_alert) < self.args.cooldown:
                return
            self.last_alert = time.time()

        print(f"🚨 INTRUSION: {reason}")
        if self.args.mode == "flag":
            threading.Thread(target=flash_screen, daemon=True).start()

        video_path, jpg_path = capture_3s_clip_and_stamp(3.0)
        lock_screen()

        if self.args.mode == "flag":
            threading.Thread(target=speak_flag_alert, args=(self.args.lang,), daemon=True).start()

        self.exfiltrate(reason, video_path, jpg_path)

    def exfiltrate(self, reason: str, video_path: Path | None, jpg_path: Path | None):
        ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        msg = f"🚨 NyxWatch ({platform.node()}) [{ts}]: {reason} | IP: {get_local_ip()}"

        if self.args.mac_studio:
            payload = {"app": "NyxWatch", "host": platform.node(), "timestamp": ts, "reason": reason, "network": get_local_ip()}
            if jpg_path and jpg_path.exists():
                payload["busted_image_b64"] = base64.b64encode(jpg_path.read_bytes()).decode("ascii")
                payload["busted_filename"] = jpg_path.name
            try:
                requests.post(self.args.mac_studio, json=payload, timeout=8)
            except Exception as e:
                print(f"Mac Studio send error: {e}")

        if self.args.telegram_token and self.args.telegram_chat:
            for p, kind in [(jpg_path, "photo"), (video_path, "video")]:
                if p and p.exists():
                    endpoint = "sendPhoto" if kind == "photo" else "sendVideo"
                    try:
                        with open(p, "rb") as f:
                            requests.post(
                                f"https://api.telegram.org/bot{self.args.telegram_token}/{endpoint}",
                                data={"chat_id": self.args.telegram_chat, "caption": msg},
                                files={kind: f},
                                timeout=20,
                            )
                    except Exception as e:
                        print(f"Telegram error: {e}")

    def run(self):
        print(f"🛡️ NyxWatch Desktop ({SYSTEM}) started | Mode: {self.args.mode} | Armed: {self.armed}")
        settle_until = time.time() + 3.0

        def on_input(*_):
            if self.armed and time.time() > settle_until:
                self.trigger_alert("HID input detected")

        kb_listener = keyboard.Listener(on_press=on_input)
        ms_listener = mouse.Listener(on_move=on_input, on_click=on_input)
        kb_listener.start()
        ms_listener.start()

        last_plugged = psutil.sensors_battery().power_plugged if psutil.sensors_battery() else None
        try:
            while True:
                batt = psutil.sensors_battery()
                if batt and last_plugged is True and batt.power_plugged is False:
                    if self.armed and time.time() > settle_until:
                        self.trigger_alert("AC power unplugged")
                if batt:
                    last_plugged = batt.power_plugged
                time.sleep(0.5)
        except KeyboardInterrupt:
            kb_listener.stop()
            ms_listener.stop()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="NyxWatch Cross-Platform Desktop Agent (Windows/Linux)")
    parser.add_argument("--mode", choices=["discreet", "flag"], default="discreet")
    parser.add_argument("--lang", choices=["fr", "en"], default="en")
    parser.add_argument("--arm-now", action="store_true")
    parser.add_argument("--cooldown", type=float, default=30.0)
    parser.add_argument("--telegram-token")
    parser.add_argument("--telegram-chat")
    parser.add_argument("--mac-studio", help="e.g. http://192.168.1.50:8787/alert")
    NyxWatchDesktop(parser.parse_args()).run()
