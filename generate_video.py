import os
import requests
import json
import subprocess
import textwrap

# Configuration
ELEVENLABS_API_KEY = "bc6dedd93508242b913e58ac7f4ca2948e9badee7cd4fd241332b28cbace28ca"
VOICE_ID = "Lcf7zDov5wbd8D9H189V"
LOGO_PATH = "/mnt/user-uploads/Design_sem_nome_23-4.png"
OUTPUT_DIR = "/mnt/documents"
VIDEO_NAME = "grm-guardiao-promocional.mp4"

SCRIPT_TEXT = (
    "A GRM Guardião oferece a melhor segurança privada e patrimonial para sua casa e comércio. "
    "Com monitoramento profissional vinte e quatro horas, câmeras de alta tecnologia e rondas constantes, "
    "garantimos a sua tranquilidade e a proteção do seu patrimônio."
)

def generate_audio():
    print("Generating audio...")
    url = f"https://api.elevenlabs.io/v1/text-to-speech/{VOICE_ID}"
    headers = {"Accept": "audio/mpeg", "Content-Type": "application/json", "xi-api-key": ELEVENLABS_API_KEY}
    data = {"text": SCRIPT_TEXT, "model_id": "eleven_multilingual_v2"}
    response = requests.post(url, json=data, headers=headers)
    if response.status_code == 200:
        with open("narration.mp3", "wb") as f: f.write(response.content)
        return "narration.mp3"
    return None

def generate_subtitles():
    chunks = [
        ("A GRM Guardião oferece a melhor segurança privada e patrimonial.", 0, 7),
        ("Com monitoramento profissional 24h e câmeras de alta tecnologia.", 7, 15),
        ("Garantimos a sua tranquilidade e a proteção do seu patrimônio.", 15, 23)
    ]
    srt = ""
    for i, (text, s, e) in enumerate(chunks):
        t = lambda x: f"{int(x//3600):02}:{int((x%3600)//60):02}:{int(x%60):02},{int((x%1)*1000):03}"
        srt += f"{i+1}\n{t(s)} --> {t(e)}\n{text}\n\n"
    with open("subtitles.srt", "w") as f: f.write(srt)
    return "subtitles.srt"

def create_video(audio=None):
    output_path = os.path.join(OUTPUT_DIR, VIDEO_NAME)
    # Simple color background using lavfi
    cmd = [
        "ffmpeg", "-y",
        "-f", "lavfi", "-i", "color=c=0x0F172A:s=1080x1350:d=30",
        "-loop", "1", "-i", LOGO_PATH,
    ]
    if audio: cmd += ["-i", audio]
    
    filter_complex = "[1:v]scale=800:-1[logo];[0:v][logo]overlay=(W-w)/2:(H-h)/2-100[bg];"
    filter_complex += "[bg]subtitles=subtitles.srt:force_style='FontSize=26,PrimaryColour=&H00FFFFFF,OutlineColour=&H00000000,BorderStyle=3,MarginV=120'[v]"
    
    cmd += ["-filter_complex", filter_complex, "-map", "[v]"]
    if audio: cmd += ["-map", "2:a"]
    
    cmd += ["-c:v", "libx264", "-pix_fmt", "yuv420p", "-t", "30", output_path]
    subprocess.run(cmd, check=True)
    return output_path

if __name__ == "__main__":
    generate_subtitles()
    audio = generate_audio()
    create_video(audio)
