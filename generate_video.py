import os
import requests
import json
import subprocess
import textwrap

# Using a generic voice or skipping audio if key fails
VOICE_ID = "Lcf7zDov5wbd8D9H189V"
LOGO_PATH = "/mnt/user-uploads/Design_sem_nome_23-4.png"
OUTPUT_DIR = "/mnt/documents"
VIDEO_NAME = "grm-guardiao-promocional.mp4"

def generate_subtitles():
    chunks = [
        ("A GRM Guardião oferece a melhor segurança privada e patrimonial.", 0, 7),
        ("Com monitoramento profissional 24h e câmeras de alta tecnologia.", 7, 15),
        ("Garantimos a sua tranquilidade e a proteção do seu patrimônio.", 15, 23),
        ("Sua segurança é nossa missão. GRM Guardião.", 23, 30)
    ]
    srt_content = ""
    for i, (text, start, end) in enumerate(chunks):
        def format_time(seconds):
            h = int(seconds // 3600)
            m = int((seconds % 3600) // 60)
            s = int(seconds % 60)
            ms = int((seconds % 1) * 1000)
            return f"{h:02}:{m:02}:{s:02},{ms:03}"
        srt_content += f"{i+1}\n{format_time(start)} --> {format_time(end)}\n{textwrap.fill(text, 40)}\n\n"
    with open("subtitles.srt", "w") as f:
        f.write(srt_content)
    return "subtitles.srt"

def create_video():
    output_path = os.path.join(OUTPUT_DIR, VIDEO_NAME)
    # Generate silent video if no audio
    cmd = [
        "ffmpeg", "-y",
        "-loop", "1", "-t", "30", "-f", "lavfi", "-i", "color=c=0x0F172A:s=1080x1350",
        "-i", LOGO_PATH,
        "-filter_complex", (
            "[1:v]scale=800:-1[logo];"
            "[0:v][logo]overlay=(W-w)/2:(H-h)/2-100[bg];"
            "[bg]subtitles=subtitles.srt:force_style='FontSize=26,PrimaryColour=&H00FFFFFF,OutlineColour=&H00000000,BorderStyle=3,MarginV=120'[v]"
        ),
        "-map", "[v]",
        "-c:v", "libx264", "-tune", "stillimage", "-crf", "18", "-pix_fmt", "yuv420p",
        output_path
    ]
    subprocess.run(cmd, check=True)
    return output_path

if __name__ == "__main__":
    generate_subtitles()
    create_video()
