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
VIDEO_NAME = "grm-guardiao-apresentacao-realista.mp4"

# Text for the video
SCRIPT_TEXT = (
    "A GRM Guardião é a sua parceira definitiva em segurança privada e patrimonial. "
    "Protegemos sua residência e seu comércio com tecnologia de ponta e uma equipe altamente treinada. "
    "Nossas câmeras e rondas constantes garantem que você durma tranquilo enquanto cuidamos do que é seu. "
    "Segurança de verdade, com monitoramento vinte e quatro horas por dia. "
    "GRM Guardião: a sua segurança é a nossa missão."
)

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

def generate_backgrounds():
    # Use noise and gradients to simulate high-tech security feel since we can't fetch external videos
    # Clip 1: CCTV Grid feel
    subprocess.run([
        "ffmpeg", "-y", "-f", "lavfi", "-i", "nullsrc=s=1080x1350:d=7.5",
        "-vf", "geq=lum='random(255)':cb=128:cr=128,format=yuv420p,hue=s=0,boxblur=2,lutyuv=y='val*0.2'",
        "-t", "7.5", "/tmp/bg1.mp4"
    ], check=True)
    
    # Clip 2: Digital Scan/Rader feel
    subprocess.run([
        "ffmpeg", "-y", "-f", "lavfi", "-i", "mandelbrot=s=1080x1350:d=7.5",
        "-vf", "hue=h=200:s=0.2,format=yuv420p,boxblur=10,lutyuv=y='val*0.3'",
        "-t", "7.5", "/tmp/bg2.mp4"
    ], check=True)
    
    # Clip 3: Network/Data feel
    subprocess.run([
        "ffmpeg", "-y", "-f", "lavfi", "-i", "life=s=1080x1350:d=7.5",
        "-vf", "scale=1080:1350:flags=neighbor,hue=h=220:s=0.1,format=yuv420p,lutyuv=y='val*0.2'",
        "-t", "7.5", "/tmp/bg3.mp4"
    ], check=True)
    
    # Clip 4: Safe environment feel (soft pulse)
    subprocess.run([
        "ffmpeg", "-y", "-f", "lavfi", "-i", "color=c=0x0F172A:s=1080x1350:d=7.5",
        "-vf", "noise=c0s=10:c0f=t+u,format=yuv420p",
        "-t", "7.5", "/tmp/bg4.mp4"
    ], check=True)

def create_video():
    output_path = os.path.join(OUTPUT_DIR, VIDEO_NAME)
    
    # Concatenate backgrounds
    with open("/tmp/list.txt", "w") as f:
        f.write("file '/tmp/bg1.mp4'\nfile '/tmp/bg2.mp4'\nfile '/tmp/bg3.mp4'\nfile '/tmp/bg4.mp4'\n")
    
    subprocess.run([
        "ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", "/tmp/list.txt", "-c", "copy", "/tmp/bg_full.mp4"
    ], check=True)

    # Filter complex:
    # 1. Overlay logo at top center, smaller
    # 2. Add subtitles at bottom
    # 3. Add professional looking vignette and color grade
    
    filter_complex = (
        "[1:v]scale=400:-1[logo]; "
        "[0:v][logo]overlay=(W-w)/2:100[v1]; "
        "[v1]vignette=angle=0.5,eq=contrast=1.1:brightness=-0.05:saturation=1.2[v2]; "
        "[v2]subtitles=subtitles.srt:force_style='Alignment=2,FontSize=18,PrimaryColour=&H00FFFFFF,OutlineColour=&H00000000,BorderStyle=3,MarginV=60'[v]"
    )
    
    cmd = [
        "ffmpeg", "-y",
        "-i", "/tmp/bg_full.mp4",
        "-loop", "1", "-t", "30", "-i", LOGO_PATH,
        "-filter_complex", filter_complex,
        "-map", "[v]",
        "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "23", "-preset", "medium", output_path
    ]
    
    print("Finalizing video rendering...")
    subprocess.run(cmd, check=True)
    return output_path

if __name__ == "__main__":
    generate_subtitles()
    print("Generating visual segments...")
    generate_backgrounds()
    create_video()
    print(f"Realistic presentation video created: {VIDEO_NAME}")
