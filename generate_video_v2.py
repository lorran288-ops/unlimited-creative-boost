import os
import requests
import json
import subprocess
import textwrap

# Configuration
# Note: The user provided an ElevenLabs Key ID, but we'll try it again. 
# If it fails, I'll need to use a fallback or explain.
# In the previous turn, the agent claimed success, so maybe it worked or was mocked.
ELEVENLABS_API_KEY = "bc6dedd93508242b913e58ac7f4ca2948e9badee7cd4fd241332b28cbace28ca"
VOICE_ID = "Lcf7zDov5wbd8D9H189V" # Standard voice
LOGO_PATH = "/mnt/user-uploads/Design_sem_nome_23-4.png"
OUTPUT_DIR = "/mnt/documents"
VIDEO_NAME = "grm-guardiao-promocional-v2.mp4"

# Text for the video - expanded to ~25-30 seconds
SCRIPT_TEXT = (
    "A GRM Guardião é a sua parceira definitiva em segurança privada e patrimonial. "
    "Protegemos sua residência e seu comércio com tecnologia de ponta e uma equipe altamente treinada. "
    "Nossas câmeras e rondas constantes garantem que você durma tranquilo enquanto cuidamos do que é seu. "
    "Segurança de verdade, com monitoramento vinte e quatro horas por dia. "
    "GRM Guardião: a sua segurança é a nossa missão."
)

def generate_audio():
    print("Generating audio via ElevenLabs...")
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
    try:
        response = requests.post(url, json=data, headers=headers, timeout=30)
        if response.status_code == 200:
            with open("narration.mp3", "wb") as f:
                f.write(response.content)
            print("Audio generated successfully.")
            return "narration.mp3"
        else:
            print(f"ElevenLabs error: {response.status_code} - {response.text}")
            return None
    except Exception as e:
        print(f"Error calling ElevenLabs: {e}")
        return None

def generate_subtitles():
    # Split script into timed chunks for roughly 25-30 seconds
    chunks = [
        ("A GRM Guardião é a sua parceira definitiva", 0, 4),
        ("em segurança privada e patrimonial.", 4, 8),
        ("Protegemos sua residência e seu comércio", 8, 12),
        ("com tecnologia de ponta e equipe treinada.", 12, 16),
        ("Nossas câmeras e rondas garantem sua paz", 16, 20),
        ("enquanto cuidamos do que é seu.", 20, 24),
        ("GRM Guardião: sua segurança é nossa missão.", 24, 30)
    ]
    srt = ""
    for i, (text, s, e) in enumerate(chunks):
        t = lambda x: f"{int(x//3600):02}:{int((x%3600)//60):02}:{int(x%60):02},{int((x%1)*1000):03}"
        srt += f"{i+1}\n{t(s)} --> {t(e)}\n{text}\n\n"
    with open("subtitles.srt", "w") as f:
        f.write(srt)
    return "subtitles.srt"

def create_video(audio_path=None):
    output_path = os.path.join(OUTPUT_DIR, VIDEO_NAME)
    
    # Visual specs: 1080x1350 (4:5)
    # Background: A professional dark gradient or deep blue
    # Logo: Centered and slightly moved up
    # Subtitles: Bottom, smaller, clean font
    
    # Fallback to silent video if no audio
    duration = 30
    if audio_path:
        # Get duration of audio
        try:
            res = subprocess.run(
                ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "default=noprint_wrappers=1:nokey=1", audio_path],
                capture_output=True, text=True
            )
            duration = float(res.stdout.strip())
        except:
            duration = 30

    # ffmpeg command
    # 1. Background color
    # 2. Logo image loop
    # 3. Audio (if available)
    
    cmd = [
        "ffmpeg", "-y",
        "-f", "lavfi", "-i", f"color=c=0x0F172A:s=1080x1350:d={duration}", # Dark navy
        "-loop", "1", "-t", str(duration), "-i", LOGO_PATH
    ]
    
    if audio_path:
        cmd += ["-i", audio_path]

    # Filter complex:
    # - Scale logo to 600px width
    # - Overlay logo in upper-middle
    # - Apply subtitles at the bottom (MarginV control)
    
    # Style: FontSize=18 (smaller), Alignment=2 (Bottom Center), MarginV=50 (lower down)
    filter_complex = (
        "[1:v]scale=600:-1[logo]; "
        "[0:v][logo]overlay=(W-w)/2:(H-h)/2-150[bg]; "
        "[bg]subtitles=subtitles.srt:force_style='Alignment=2,FontSize=18,PrimaryColour=&H00FFFFFF,OutlineColour=&H00000000,BorderStyle=3,MarginV=60'[v]"
    )
    
    cmd += ["-filter_complex", filter_complex, "-map", "[v]"]
    
    if audio_path:
        cmd += ["-map", "2:a"]
        
    cmd += ["-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "23", "-preset", "medium", output_path]
    
    print(f"Running ffmpeg command for {duration} seconds...")
    subprocess.run(cmd, check=True)
    return output_path

if __name__ == "__main__":
    generate_subtitles()
    audio = generate_audio()
    if not audio:
        print("Warning: Proceeding without narration due to API error.")
    create_video(audio)
    print(f"Video created: {VIDEO_NAME}")
