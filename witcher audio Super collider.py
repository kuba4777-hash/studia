import time
import threading
import base64
import requests
from io import BytesIO
import pygetwindow as gw
from mss import mss
from PIL import Image, ImageStat, ImageChops
from pythonosc import udp_client

# --- KONFIGURACJA ---
TARGET_WINDOW = "The Witcher 3"
OSC_IP, OSC_PORT = "127.0.0.1", 57120
POLLING_RATE = 0.1
OLLAMA_URL = "http://localhost:11434/api/generate"


class AdaptivePhonkBridge:
    def __init__(self):
        self.osc_client = udp_client.SimpleUDPClient(OSC_IP, OSC_PORT)
        self.sct = mss()
        self.prev_frame = None
        self.max_health_pixels = 1

        # Zmienne AI
        self.ai_vibe_combat = 0.0  # 0.0 do 1.0 (im wyżej, tym brutalniejszy phonk)
        self.ai_vibe_dark = 0.0
        self.last_ai_check = 0

    def _get_ai_description(self, img):
        """Asynchroniczne zapytanie do Moondream przez Ollama"""
        buffered = BytesIO()
        img.save(buffered, format="JPEG")
        img_str = base64.b64encode(buffered.getvalue()).decode('utf-8')

        payload = {
            "model": "moondream",
            "prompt": "Is this scene peaceful, a dark forest, or a violent combat? Answer in one or two words only, like 'peaceful', 'dark forest', 'combat'.",
            "stream": False,
            "images": [img_str]
        }
        try:
            response = requests.post(OLLAMA_URL, json=payload, timeout=5)
            res_text = response.json().get('response', '').lower()
            print(f"👁️ AI Moondream widzi: {res_text.strip()}")

            # Interpretacja odpowiedzi AI
            if "combat" in res_text or "fight" in res_text or "blood" in res_text:
                self.ai_vibe_combat = 1.0
                self.ai_vibe_dark = 0.5
            elif "dark" in res_text or "night" in res_text:
                self.ai_vibe_combat = 0.2
                self.ai_vibe_dark = 1.0
            else:
                self.ai_vibe_combat = 0.0
                self.ai_vibe_dark = 0.0
        except Exception as e:
            # Ignoruj błędy, jeśli Ollama nie nadąża
            pass

    def _capture_frame(self):
        try:
            active_win = gw.getActiveWindow()
            if not active_win or TARGET_WINDOW not in active_win.title: return None
            monitor = {"top": active_win.top, "left": active_win.left, "width": active_win.width,
                       "height": active_win.height}
            sct_img = self.sct.grab(monitor)
            img = Image.frombytes("RGB", sct_img.size, sct_img.bgra, "raw", "BGRX")
            img.thumbnail((300, 300))
            return img
        except:
            return None

    def _analyze_image_data(self, frame):
        w, h = frame.size

        # 1. RUCH (Intensity)
        curr_gray = frame.convert("L")
        if self.prev_frame is None:
            self.prev_frame = curr_gray
            intensity = 0.0
        else:
            diff = ImageChops.difference(curr_gray, self.prev_frame)
            intensity = max(0.0, min(1.0, (ImageStat.Stat(diff).mean[0] - 1.5) / 25.0))
            self.prev_frame = curr_gray

        # 2. HP GERALTA (Danger)
        top_left_hp = frame.crop((int(w * 0.05), int(h * 0.05), int(w * 0.35), int(h * 0.15)))
        red_count = sum(1 for r, g, b in top_left_hp.getdata() if r > 140 and g < 50 and b < 50)
        if red_count > self.max_health_pixels: self.max_health_pixels = red_count
        danger = max(0.0, min(1.0, 1.0 - (red_count / (self.max_health_pixels + 1))))

        # 3. WALKA (Czerwony pasek wroga)
        top_center = frame.crop((int(w * 0.3), 0, int(w * 0.7), int(h * 0.1)))
        enemy_red = sum(1 for r, g, b in top_center.getdata() if r > 160 and g < 40 and b < 40)
        combat_mode = max(0.0, min(1.0, enemy_red / 10.0))

        # 4. DIALOGI
        choice_region = frame.crop((int(w * 0.5), int(h * 0.3), int(w * 0.9), int(h * 0.7)))
        gold_pixels = sum(1 for r, g, b in choice_region.getdata() if r > 180 and g > 150 and b < 100)
        dialogue_mode = 1.0 if gold_pixels > 10 else 0.0

        # Zaktualizowany wektor na potrzeby silnika Phonk (8 wartości)
        return [intensity, danger, combat_mode, dialogue_mode, self.ai_vibe_combat, self.ai_vibe_dark, 0.0, 0.0]

    def run(self):
        print("🔥 Witcher Phonk AI Bridge (Moondream) Active.")
        while True:
            frame = self._capture_frame()
            if frame:
                # Szybka analiza CV
                vector = self._analyze_image_data(frame)
                self.osc_client.send_message("/engine/state", vector)

                # Wolna analiza AI (co 3 sekundy)
                if time.time() - self.last_ai_check > 3.0:
                    threading.Thread(target=self._get_ai_description, args=(frame,), daemon=True).start()
                    self.last_ai_check = time.time()

            time.sleep(POLLING_RATE)


if __name__ == "__main__":
    AdaptivePhonkBridge().run()