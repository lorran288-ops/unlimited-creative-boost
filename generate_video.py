import os
import requests
import json
import subprocess
import textwrap

# Configuration
ELEVENLABS_API_KEY = os.environ.get("ELEVENLABS_API_KEY")
VOICE_ID = "Lcf7zDov5wbd8D9H189V" # Daniel - Professional
LOGO_PATH = "/mnt/user-uploads/Design_sem_nome_23-4.png"
OUTPUT_DIR = "/mnt/documents"
VIDEO_NAME = "grm-guardiao-promocional.mp4"

# Text in Portuguese
SCRIPT_TEXT = (
    "A GRM Guardião oferece a melhor segurança privada e patrimonial para sua casa e comércio. "
    "Com monitoramento profissional vinte e quatro horas, câmeras de alta tecnologia e rondas constantes, "
    "garantimos a sua tranquilidade e a proteção do seu patrimônio. "
    "Não deixe sua segurança ao acaso. Contrate a GRM Guardião e viva com a certeza de estar protegido por especialistas. "
    "Sua segurança é nossa missão."
)

def generate_audio():
    if not ELEVENLABS_API_KEY:
        print("ELEVENLABS_API_KEY not found in environment.")
        return None
        
    print("Generating audio with ElevenLabs...")
    url = f"https://api.elevenlabs.io/v1/text-to-speech/{VOICE_ID}"
    headers = {
        "Accept": "audio/mpeg",
        "Content-Type": "application/json",
        "xi-api-key": ELEVENLABS_API_KEY
    }
    data = {
        "text": SCRIPT_TEXT,
        "model_id": "eleven_multilingual_v2",
        "voice_settings": {
            "stability": 0.5,
            "similarity_boost": 0.75
        }
    }
    response = requests.post(url, json=data, headers=headers)
    if response.status_code == 200:
        with open("narration.mp3", "wb") as f:
            f.write(response.content)
        print("Audio generated: narration.mp3")
        return "narration.mp3"
    else:
        print(f"Error generating audio: {response.status_code} - {response.text}")
        return None

def generate_subtitles():
    print("Generating subtitles...")
    chunks = [
        ("A GRM Guardião oferece a melhor segurança privada e patrimonial para sua casa e comércio.", 0, 7),
        ("Com monitoramento profissional 24h, câmeras de alta tecnologia e rondas constantes.", 7, 15),
        ("Garantimos a sua tranquilidade e a proteção do seu patrimônio. Não deixe sua segurança ao acaso.", 15, 23),
        ("Contrate a GRM Guardião e viva com a certeza de estar protegido por especialistas. Sua segurança é nossa missão.", 23, 30)
    ]
    
    srt_content = ""
    for i, (text, start, end) in enumerate(chunks):
        def format_time(seconds):
            h = int(seconds // 3600)
            m = int((seconds % 3600) // 60)
            s = int(seconds % 60)
            ms = int((seconds % 1) * 1000)
            return f"{h:02}:{m:02}:{s:02},{ms:03}"
            
        srt_content += f"{i+1}\n"
        srt_content += f"{format_time(start)} --> {format_time(end)}\n"
        srt_content += f"{textwrap.fill(text, 40)}\n\n"
        
    with open("subtitles.srt", "w") as f:
        f.write(srt_content)
    return "subtitles.srt"

def create_video(audio_file, srt_file):
    print("Creating video with FFmpeg...")
    output_path = os.path.join(OUTPUT_DIR, VIDEO_NAME)
    
    # We create a dark blue background and place the logo on top
    # 4:5 aspect ratio is 1080x1350
    
    cmd = [
        "ffmpeg", "-y",
        "-loop", "1", "-t", "30", "-f", "lavfi", "-i", "color=c=0x0F172A:s=1080x1350", # Navy background
        "-i", LOGO_PATH,
        "-i", audio_file,
        "-filter_complex", (
            "[1:v]scale=800:-1[logo];" # Scale logo
            "[0:v][logo]overlay=(W-w)/2:(H-h)/2-100[bg];" # Overlay logo slightly above center
            "[bg]subtitles=subtitles.srt:force_style='FontSize=26,PrimaryColour=&H00FFFFFF,OutlineColour=&H00000000,BorderStyle=3,MarginV=120'[v]"
        ),
        "-map", "[v]", "-map", "2:a",
        "-c:v", "libx264", "-tune", "stillimage", "-crf", "18", "-pix_fmt", "yuv420p",
        "-c:a", "aac", "-b:a", "192k",
        "-shortest",
        output_path
    ]
    
    try:
        subprocess.run(cmd, check=True)
        print(f"Video created successfully: {output_path}")
        return output_path
    except subprocess.CalledProcessError as e:
        print(f"Error creating video: {e}")
        return None

if __name__ == "__main__":
    audio = generate_audio()
    if audio:
        srt = generate_subtitles()
        create_video(audio, srt)
    else:
        print("Failed to generate audio, skipping video creation.")
