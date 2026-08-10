import os
import requests
import json
import subprocess
import textwrap

# Configuration
# ElevenLabs key used for narration (if valid)
ELEVENLABS_API_KEY = "bc6dedd93508242b913e58ac7f4ca2948e9badee7cd4fd241332b28cbace28ca"
VOICE_ID = "Lcf7zDov5wbd8D9H189V" 
LOGO_PATH = "/mnt/user-uploads/Design_sem_nome_23-4.png"
OUTPUT_DIR = "/mnt/documents"
VIDEO_NAME = "grm-guardiao-apresentacao-premium.mp4"

# Text for the video
SCRIPT_TEXT = (
    "A GRM Guardião é a sua parceira definitiva em segurança privada e patrimonial. "
    "Protegemos sua residência e seu comércio com tecnologia de ponta e uma equipe altamente treinada. "
    "Nossas câmeras e rondas constantes garantem que você durma tranquilo enquanto cuidamos do que é seu. "
    "Segurança de verdade, com monitoramento vinte e quatro horas por dia. "
    "GRM Guardião: a sua segurança é a nossa missão."
)

def generate_audio():
    print("Attempting to generate narration via ElevenLabs...")
    url = f"https://api.elevenlabs.io/v1/text-to-speech/{VOICE_ID}"
    headers = {
        "Accept": "audio/mpeg",
        "Content-Type": "application/json",
        "xi-api-key": ELEVENLABS_API_KEY
    }
    data = {
        "text": SCRIPT_TEXT,
        "model_id": "eleven_multilingual_v2",
        "voice_settings": {"stability": 0.5, "similarity_boost": 0.75}
    }
    try:
        response = requests.post(url, json=data, headers=headers, timeout=30)
        if response.status_code == 200:
            with open("narration.mp3", "wb") as f:
                f.write(response.content)
            return "narration.mp3"
        else:
            print(f"ElevenLabs error (likely key issue): {response.status_code}")
            return None
    except Exception as e:
        print(f"Error: {e}")
        return None

def generate_subtitles():
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

def create_dynamic_backgrounds():
    print("Creating dynamic technical backgrounds...")
    # Scene 1: Technical Grid / Digital pulses
    subprocess.run([
        "ffmpeg", "-y", "-f", "lavfi", "-i", "nullsrc=s=1080x1350:d=7.5",
        "-vf", "geq=lum='random(255)':cb=128:cr=128,format=yuv420p,hue=s=0,boxblur=5,lutyuv=y='val*0.15'",
        "-t", "7.5", "/tmp/sc1.mp4"
    ], check=True)
    
    # Scene 2: Scanning / Radar Sweep (Mandelbrot fallback)
    subprocess.run([
        "ffmpeg", "-y", "-f", "lavfi", "-i", "mandelbrot=s=1080x1350",
        "-vf", "hue=h=210:s=0.3,format=yuv420p,boxblur=15,lutyuv=y='val*0.2'",
        "-t", "7.5", "/tmp/sc2.mp4"
    ], check=True)

    # Scene 3: Connectivity / Network (Life fallback)
    subprocess.run([
        "ffmpeg", "-y", "-f", "lavfi", "-i", "life=s=540x675",
        "-vf", "scale=1080:1350:flags=neighbor,hue=h=220:s=0.2,format=yuv420p,lutyuv=y='val*0.2'",
        "-t", "7.5", "/tmp/sc3.mp4"
    ], check=True)

    # Scene 4: Deep Security / Night Vision feel
    subprocess.run([
        "ffmpeg", "-y", "-f", "lavfi", "-i", "color=c=0x050810:s=1080x1350",
        "-vf", "noise=c0s=20:c0f=t+u,format=yuv420p",
        "-t", "7.5", "/tmp/sc4.mp4"
    ], check=True)

    # Concatenate
    with open("/tmp/concat.txt", "w") as f:
        f.write("file '/tmp/sc1.mp4'\nfile '/tmp/sc2.mp4'\nfile '/tmp/sc3.mp4'\nfile '/tmp/sc4.mp4'\n")
    
    subprocess.run([
        "ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", "/tmp/concat.txt", "-c", "copy", "/tmp/bg_dynamic.mp4"
    ], check=True)

def finalize_video(audio_path=None):
    output_path = os.path.join(OUTPUT_DIR, VIDEO_NAME)
    
    # Filter:
    # 1. Overlay logo at top center
    # 2. Add cinematic vignette and color grading
    # 3. Add technical "overlay" texture
    # 4. Small subtitles at bottom
    
    filter_complex = (
        "[1:v]scale=450:-1[logo]; "
        "[0:v][logo]overlay=(W-w)/2:150[v1]; "
        "[v1]vignette=angle=0.4,eq=contrast=1.2:brightness=-0.05:saturation=1.3[v2]; "
        "[v2]subtitles=subtitles.srt:force_style='Alignment=2,FontSize=18,PrimaryColour=&H00FFFFFF,OutlineColour=&H00000000,BorderStyle=3,MarginV=70'[v]"
    )
    
    cmd = [
        "ffmpeg", "-y",
        "-i", "/tmp/bg_dynamic.mp4",
        "-loop", "1", "-t", "30", "-i", LOGO_PATH
    ]
    
    if audio_path:
        cmd += ["-i", audio_path]
    
    cmd += ["-filter_complex", filter_complex, "-map", "[v]"]
    
    if audio_path:
        cmd += ["-map", "2:a"]
    else:
        # If no narration, add a professional silent audio stream or dummy beat
        cmd += ["-f", "lavfi", "-i", "anullsrc=r=44100:cl=stereo", "-map", "2:a", "-shortest"]

    cmd += ["-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "22", "-preset", "medium", output_path]
    
    print("Rendering final premium video...")
    subprocess.run(cmd, check=True)
    return output_path

if __name__ == "__main__":
    generate_subtitles()
    audio = generate_audio()
    create_dynamic_backgrounds()
    finalize_video(audio)
    print(f"Success: {VIDEO_NAME}")
