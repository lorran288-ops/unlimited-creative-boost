
import React, { useState, useRef } from 'react';
import { useServerFn } from '@tanstack/react-start';
import { generateVideoContent } from '@/lib/video.functions';
import { Button } from '@/components/ui/button';
import { Play, Pause, Volume2, Shield, Video, RotateCcw } from 'lucide-react';
import { toast } from 'sonner';

export function InteractiveVideo() {
  const [isPlaying, setIsPlaying] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [videoData, setVideoData] = useState<any>(null);
  const videoRef = useRef<HTMLVideoElement>(null);
  
  const generate = useServerFn(generateVideoContent);

  const handleGenerate = async () => {
    setIsLoading(true);
    try {
      const result = await generate({ 
        text: "Segurança privada, câmeras e ronda para casa e comércio.",
        duration: 30 
      });
      setVideoData(result);
      toast.success("Vídeo gerado com sucesso!");
    } catch (error) {
      toast.error("Erro ao gerar o vídeo.");
    } finally {
      setIsLoading(false);
    }
  };

  const togglePlay = () => {
    if (videoRef.current) {
      if (isPlaying) {
        videoRef.current.pause();
      } else {
        videoRef.current.play();
      }
      setIsPlaying(!isPlaying);
    }
  };

  return (
    <div className="w-full max-w-[400px] mx-auto aspect-[4/5] bg-black rounded-3xl overflow-hidden shadow-2xl relative group">
      {!videoData ? (
        <div className="absolute inset-0 flex flex-col items-center justify-center p-8 text-center bg-linear-to-br from-slate-900 to-black text-white">
          <div className="mb-6 p-4 bg-primary/20 rounded-full animate-pulse">
            <Video className="w-12 h-12 text-primary" />
          </div>
          <h3 className="text-xl font-bold mb-2">Vídeo Interativo GRM</h3>
          <p className="text-sm text-slate-400 mb-8">
            Gere uma apresentação de 30 segundos sobre nossa segurança com narração ElevenLabs e legendas.
          </p>
          <Button 
            onClick={handleGenerate} 
            disabled={isLoading}
            className="rounded-full px-8 py-6 h-auto text-lg"
          >
            {isLoading ? "Gerando..." : "Criar Vídeo Agora"}
          </Button>
        </div>
      ) : (
        <>
          <video 
            ref={videoRef}
            src={videoData.videoUrl}
            className="w-full h-full object-cover"
            onEnded={() => setIsPlaying(false)}
            playsInline
          />
          
          {/* Subtitles Overlay */}
          <div className="absolute bottom-20 left-0 right-0 px-6 text-center pointer-events-none">
            <div className="bg-black/60 backdrop-blur-md px-4 py-2 rounded-lg inline-block border border-white/10">
              <p className="text-white text-sm font-medium">
                {videoData.subtitles[0].text}
              </p>
            </div>
          </div>

          {/* Controls Overlay */}
          <div className="absolute inset-0 bg-linear-to-t from-black/80 via-transparent to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300 flex flex-col justify-between p-6">
            <div className="flex justify-between items-center">
              <div className="bg-primary/20 backdrop-blur-sm px-3 py-1 rounded-full border border-primary/30 flex items-center gap-2">
                <Shield className="w-4 h-4 text-primary" />
                <span className="text-[10px] font-bold text-primary uppercase tracking-wider">Segurança Real</span>
              </div>
              <Button variant="ghost" size="icon" className="text-white hover:bg-white/10" onClick={() => setVideoData(null)}>
                <RotateCcw className="w-5 h-5" />
              </Button>
            </div>

            <div className="flex items-center gap-4">
              <Button 
                variant="secondary" 
                size="icon" 
                className="w-12 h-12 rounded-full bg-white text-black hover:bg-white/90"
                onClick={togglePlay}
              >
                {isPlaying ? <Pause className="w-6 h-6" /> : <Play className="w-6 h-6 fill-current" />}
              </Button>
              <div className="flex-1">
                <div className="h-1 bg-white/20 rounded-full overflow-hidden">
                  <div className="h-full bg-primary w-1/3"></div>
                </div>
              </div>
              <Volume2 className="w-5 h-5 text-white" />
            </div>
          </div>
        </>
      )}
    </div>
  );
}
