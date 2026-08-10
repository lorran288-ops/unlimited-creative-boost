import os
import requests
import json
import subprocess
import textwrap

# Configuration
ELEVENLABS_API_KEY = "bc6dedd93508242b913e58ac7f4ca2948e9badee7cd4fd241332b28cbace28ca"
VOICE_ID = "Lcf7zDov5wbd8D9H189V" # Daniel - Professional
LOGO_PATH = "/mnt/user-uploads/Design_sem_nome_23-4.png"
OUTPUT_DIR = "/mnt/documents"
VIDEO_NAME = "grm-guardiao-seguranca.mp4"
SCRIPT_TEXT = (
    "A GRM Guardião oferece a melhor segurança privada e patrimonial para sua casa e comércio. "
    "Com monitoramento profissional vinte e quatro horas, câmeras de alta tecnologia e rondas constantes, "
    "garantimos a sua tranquilidade e a proteção do seu patrimônio. "
    "Não deixe sua segurança ao acaso. Contrate a GRM Guardião e viva com a certeza de estar protegido por especialistas. "
    "Sua segurança é nossa missão."
)

# 1. Generate Audio with ElevenLabs
def generate_audio():
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

# 2. Create Subtitles (Simple timing estimation)
def generate_subtitles():
    print("Generating subtitles...")
    # Split script into 4 chunks for 30 seconds
    chunks = [
        "A GRM Guardião oferece a melhor segurança privada e patrimonial para sua casa e comércio.",
        "Com monitoramento profissional 24h, câmeras de tecnologia e rondas constantes.",
        "Garantimos a sua tranquilidade e a proteção do seu patrimônio. Não deixe sua segurança ao acaso.",
        "Contrate a GRM Guardião e viva com a certeza de estar protegido por especialistas. Sua segurança é nossa missão."
    ]
    
    srt_content = ""
    duration_per_chunk = 30 / len(chunks)
    for i, chunk in enumerate(chunks):
        start_time = i * duration_per_chunk
        end_time = (i + 1) * duration_per_chunk
        
        def format_time(seconds):
            h = int(seconds // 3600)
            m = int((seconds % 3600) // 60)
            s = int(seconds % 60)
            ms = int((seconds % 1) * 1000)
            return f"{h:02}:{m:02}:{s:02},{ms:03}"
            
        srt_content += f"{i+1}\n"
        srt_content += f"{format_time(start_time)} --> {format_time(end_time)}\n"
        srt_content += f"{textwrap.fill(chunk, 40)}\n\n"
        
    with open("subtitles.srt", "w") as f:
        f.write(srt_content)
    print("Subtitles generated: subtitles.srt")
    return "subtitles.srt"

# 3. Use FFmpeg to create the video
def create_video(audio_file, srt_file):
    print("Creating video with FFmpeg...")
    output_path = os.path.join(OUTPUT_DIR, VIDEO_NAME)
    
    # FFmpeg command:
    # - Loop the logo image
    # - Scale to 1080x1350 (4:5)
    # - Add narration audio
    # - Add subtitles burned into the video
    # - Set duration to 30s or audio length
    
    cmd = [
        "ffmpeg", "-y",
        "-loop", "1", "-i", LOGO_PATH,
        "-i", audio_file,
        "-filter_complex", (
            "[0:v]scale=1080:1350:force_original_aspect_ratio=decrease,pad=1080:1350:(ow-iw)/2:(oh-ih)/2,format=yuv420p,"
            "subtitles=subtitles.srt:force_style='FontSize=24,PrimaryColour=&H00FFFFFF,OutlineColour=&H00000000,BorderStyle=3,MarginV=100'[v]"
        ),
        "-map", "[v]", "-map", "1:a",
        "-c:v", "libx264", "-tune", "stillimage", "-crf", "18", "-pix_fmt", "yuv420p",
        "-c:a", "aac", "-b:a", "192k",
        "-shortest",
        "-t", "30",
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
