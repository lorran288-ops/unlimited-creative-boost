import { createFileRoute } from "@tanstack/react-router";
import logoAsset from "@/assets/logo-grm.png.asset.json";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Shield, ShieldCheck, UserCheck, Clock, CheckCircle2, Phone, Video, Download } from "lucide-react";
import { InteractiveVideo } from "@/components/video/InteractiveVideo";
import { StrategyChart } from "@/components/robot/StrategyChart";
import { Toaster } from "@/components/ui/sonner";

export const Route = createFileRoute("/")({
  component: Index,
  head: () => ({
    title: "GRM Guardião - Segurança Privada e Patrimonial",
    meta: [
      {
        property: "og:title",
        content: "GRM Guardião - Segurança Privada e Patrimonial",
      },
      {
        property: "og:description",
        content: "Segurança de elite para seu patrimônio. Conheça as vantagens de contratar a GRM Guardião.",
      },
    ],
  }),
});

function Index() {
  const advantages = [
    {
      title: "Profissionais Qualificados",
      description: "Equipe treinada rigorosamente para situações críticas.",
      icon: <UserCheck className="h-8 w-8 text-primary" />,
    },
    {
      title: "Monitoramento 24h",
      description: "Sua segurança não dorme. Vigilância constante e atenta.",
      icon: <Clock className="h-8 w-8 text-primary" />,
    },
    {
      title: "Tecnologia de Ponta",
      description: "Equipamentos modernos para detecção e prevenção.",
      icon: <ShieldCheck className="h-8 w-8 text-primary" />,
    },
    {
      title: "Resposta Rápida",
      description: "Prontidão total para agir em qualquer eventualidade.",
      icon: <CheckCircle2 className="h-8 w-8 text-primary" />,
    },
  ];

  const safetyTips = [
    "Mantenha áreas externas bem iluminadas durante a noite.",
    "Certifique-se de que todas as entradas estão devidamente trancadas.",
    "Nunca informe sua rotina para estranhos ou em redes sociais.",
    "Invista em um sistema de monitoramento profissional.",
  ];

  return (
    <main className="min-h-screen bg-slate-950 text-white flex flex-col items-center px-6 py-16 md:py-24">
      <div className="w-full max-w-5xl flex flex-col items-center gap-12 md:gap-16">
        <header className="text-center space-y-6">
          <h1 className="text-6xl md:text-8xl font-black tracking-tighter text-transparent bg-gradient-to-b from-cyan-300 via-white to-amber-300 bg-clip-text drop-shadow-sm">
            NOVO ROBÔ
          </h1>
          <p className="text-xl md:text-2xl text-slate-300 max-w-3xl mx-auto leading-relaxed font-light">
            O Robô Fênix Ponto D opera automaticamente em pares como GBP/USD e XAU/USD. 
            Uma estratégia híbrida que une lógica avançada com análise técnica de alta precisão.
          </p>
        </header>

        <section id="operacao-assertiva" className="w-full">
          <div className="rounded-3xl border border-slate-800 bg-slate-900/70 backdrop-blur-xl p-8 md:p-12 shadow-2xl shadow-cyan-500/10">
            <h2 className="text-3xl md:text-5xl font-black tracking-tight text-white mb-6">
              Estratégia e Funcionamento
            </h2>
            <p className="text-slate-300 max-w-2xl mx-auto mb-8 text-lg leading-relaxed">
              O robô combina a lógica do "EA Fênix" com análise técnica avançada para momentos de entrada e saída. 
              O objetivo é executar operações com agilidade e controle rigoroso de risco.
            </p>
            <div className="flex justify-center">
              <StrategyChart />
            </div>
            <p className="mt-8 text-sm text-slate-400 text-center">
              A assertividade é demonstrada nos gráficos históricos. Taxa de acerto média (win rate) variável por período e condição de mercado.
            </p>
          </div>
        </section>

        <a
          href="/downloads/Robo_Fenix_Ponto_D.mq5"
          download
          className="inline-flex items-center gap-3 rounded-full bg-gradient-to-r from-cyan-400 to-amber-300 text-slate-950 px-10 py-5 font-extrabold text-xl shadow-2xl hover:shadow-cyan-300/50 transition-all hover:-translate-y-1"
        >
          <Download className="h-6 w-6" /> Baixar Robô Fênix Ponto D
        </a>
      </div>
    </main>
  );
}