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
    <main className="min-h-screen bg-[#030712] text-slate-100 flex flex-col items-center px-6 py-20 md:py-28">
      <div className="w-full max-w-5xl flex flex-col items-center gap-12 md:gap-16">
        <header className="text-center space-y-6">
          <h1 className="text-5xl md:text-7xl font-black tracking-tighter text-transparent bg-gradient-to-b from-amber-300 via-amber-100 to-amber-600 bg-clip-text drop-shadow-sm">
            GRM Guardião
          </h1>
          <p className="text-xl md:text-2xl text-amber-50/90 max-w-3xl mx-auto leading-relaxed font-light">
            Segurança de elite para seu patrimônio. Proteção e tranquilidade para sua empresa e residência.
          </p>
        </header>

        <section className="w-full">
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
            {advantages.map((a) => (
              <Card key={a.title} className="bg-[#060b17]/80 border-amber-500/10 backdrop-blur-xl shadow-xl shadow-amber-900/5 hover:-translate-y-1 transition-transform">
                <CardHeader className="pb-3">
                  <div className="mb-3">{a.icon}</div>
                  <CardTitle className="text-amber-200 text-xl">{a.title}</CardTitle>
                </CardHeader>
                <CardContent>
                  <CardDescription className="text-amber-50/80 text-base leading-relaxed">{a.description}</CardDescription>
                </CardContent>
              </Card>
            ))}
          </div>
        </section>

        <section id="operacao-assertiva" className="w-full">
          <div className="rounded-3xl border border-amber-500/10 bg-[#060b17]/80 backdrop-blur-2xl p-8 md:p-14 shadow-2xl shadow-amber-900/5">
            <h2 className="text-3xl md:text-5xl font-black tracking-tight text-amber-200 mb-6 text-center">
              Segurança com Tecnologia de Ponta
            </h2>
            <p className="text-amber-100/90 max-w-2xl mx-auto mb-8 text-lg leading-relaxed font-light text-center">
              Monitoramento 24h, equipes qualificadas e resposta rápida para qualquer eventualidade. Nossa prioridade é a proteção contínua do que é importante para você.
            </p>
            <div className="flex justify-center">
              <InteractiveVideo />
            </div>
            <div className="mt-10 w-full flex justify-center">
              <div className="w-full max-w-3xl mx-auto flex flex-col items-center justify-center">
                <StrategyChart />
              </div>
            </div>
          </div>
        </section>

        <section className="w-full max-w-2xl">
          <h3 className="text-2xl font-black text-amber-200 mb-4 tracking-tight">Dicas de Segurança</h3>
          <ul className="space-y-3">
            {safetyTips.map((tip) => (
              <li key={tip} className="flex items-start gap-3 text-amber-50/90 text-base leading-relaxed">
                <ShieldCheck className="h-6 w-6 text-amber-400 shrink-0 mt-0.5" />
                <span>{tip}</span>
              </li>
            ))}
          </ul>
        </section>

        <div className="flex flex-wrap justify-center gap-4">
          <a href="#contato" className="inline-flex items-center gap-3 rounded-full bg-gradient-to-r from-amber-300 to-amber-600 text-[#030712] px-10 py-5 font-extrabold text-xl shadow-2xl shadow-amber-500/20 hover:shadow-amber-400/40 transition-all hover:-translate-y-1 hover:scale-[1.02]">
            <Phone className="h-6 w-6" /> Solicitar Proposta
          </a>
        </div>
        <Toaster />
      </div>
    </main>
  );
}