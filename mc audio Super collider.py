import time
import os
from datetime import datetime
from pathlib import Path
from typing import Optional

import pygetwindow as gw
from mss import mss
from PIL import Image, ImageStat, ImageChops
from pythonosc import udp_client

# --- KONFIGURACJA ---
TARGET_WINDOW = "Minecraft"
OSC_IP, OSC_PORT = "127.0.0.1", 57120
POLLING_RATE = 0.2


class AdaptiveAudioBridge:
    def __init__(self):
        self.osc_client = udp_client.SimpleUDPClient(OSC_IP, OSC_PORT)
        self.save_dir = self._setup_storage()
        self.sct = mss()
        self.prev_frame = None

        # Pamięć maksymalnej ilości serduszek do kalibracji paska HP
        self.max_health_pixels = 10

    def _setup_storage(self) -> Path:
        pics_path = Path(os.path.join(os.environ['USERPROFILE'], 'Pictures'))
        today = datetime.now().strftime("%Y-%m-%d")
        full_path = pics_path / "AI_Captures_Minecraft" / today
        full_path.mkdir(parents=True, exist_ok=True)
        return full_path

    def _capture_frame(self) -> Optional[Image.Image]:
        try:
            active_win = gw.getActiveWindow()
            if not active_win or TARGET_WINDOW not in active_win.title or active_win.isMinimized:
                return None
            if any(x in active_win.title for x in ["PyCharm", ".py", "Python"]):
                return None

            monitor = {"top": active_win.top, "left": active_win.left, "width": active_win.width,
                       "height": active_win.height}
            sct_img = self.sct.grab(monitor)
            img = Image.frombytes("RGB", sct_img.size, sct_img.bgra, "raw", "BGRX")

            # 200x200 wystarczy do błyskawicznej matematyki
            img.thumbnail((200, 200))
            return img
        except Exception:
            return None

    def _analyze_image_data(self, frame: Image.Image):
        """Kombajn matematyczny: wyciąga wszystkie 7 zmiennych naraz"""
        w, h = frame.size

        # 1. MROK i KOLORY RGB (Biomy)
        stat = ImageStat.Stat(frame)
        r_avg, g_avg, b_avg = stat.mean[:3]
        darkness = 1.0 - (stat.mean[0] / 120.0)  # bazowane na jasności R
        darkness = max(0.0, min(1.0, darkness))

        # Mapowanie RGB na zakres 0.0 - 1.0
        r_val = r_avg / 255.0
        g_val = g_avg / 255.0
        b_val = b_avg / 255.0

        # 2. RUCH (Akcja)
        curr_gray = frame.convert("L")
        if self.prev_frame is None:
            self.prev_frame = curr_gray
            intensity = 0.0
        else:
            diff = ImageChops.difference(curr_gray, self.prev_frame)
            avg_diff = ImageStat.Stat(diff).mean[0]
            self.prev_frame = curr_gray
            intensity = max(0.0, min(1.0, (avg_diff - 2.0) / 30.0))

        # 3. ZAGROŻENIE (Pasek Zdrowia - Serduszka)
        # Skanujemy tylko dolne 30% ekranu w poszukiwaniu czystej czerwieni
        bottom_region = frame.crop((0, int(h * 0.7), w, h))
        pixels = bottom_region.getdata()

        red_count = sum(1 for r, g, b in pixels if r > 150 and g < 60 and b < 60)

        # Auto-kalibracja (zapamiętuje, ile czerwieni to "pełne zdrowie")
        if red_count > self.max_health_pixels:
            self.max_health_pixels = red_count

        danger = 1.0 - (red_count / self.max_health_pixels)
        danger = max(0.0, min(1.0, danger))

        # 4. HORYZONT (Niebo vs Ziemia)
        top_half = frame.crop((0, 0, w, int(h * 0.5)))
        bot_half = frame.crop((0, int(h * 0.5), w, h))

        top_bright = ImageStat.Stat(top_half.convert("L")).mean[0]
        bot_bright = ImageStat.Stat(bot_half.convert("L")).mean[0]

        # Jeśli góra jest o 30 punktów jaśniejsza od dołu, patrzymy w horyzont/niebo
        sky_focus = max(0.0, min(1.0, (top_bright - bot_bright) / 30.0))

        return [darkness, intensity, danger, r_val, g_val, b_val, sky_focus]

    def run(self):
        print(f"🚀 Silnik V31 (7 Zmiennych Wizyjnych) Start.")
        print("-" * 50)

        last_report_time = time.time()

        while True:
            frame = self._capture_frame()
            if frame:
                vector = self._analyze_image_data(frame)

                # Szybka wysyłka (7 parametrów!)
                self.osc_client.send_message("/engine/state", vector)

                # Raport co 5 sekund dla podglądu
                current_time = time.time()
                if current_time - last_report_time >= 5.0:
                    print(
                        f"\n[📊 RAPORT] Mrok: {vector[0]:.2f} | Akcja: {vector[1]:.2f} | Zagrożenie (HP): {vector[2]:.2f}")
                    print(
                        f"   [Biom RGB] R:{vector[3]:.2f} G:{vector[4]:.2f} B:{vector[5]:.2f} | Horyzont: {vector[6]:.2f}")
                    last_report_time = current_time
            else:
                print("⏳ Czekam na aktywne okno Minecrafta...       ", end="\r")

            time.sleep(POLLING_RATE)


if __name__ == "__main__":
    AdaptiveAudioBridge().run()