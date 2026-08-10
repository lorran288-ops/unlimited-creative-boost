import { createFileRoute } from "@tanstack/react-router";
import logoAsset from "@/assets/logo-grm.png.asset.json";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Shield, ShieldCheck, UserCheck, Clock, CheckCircle2, Phone, Video } from "lucide-react";
import { InteractiveVideo } from "@/components/video/InteractiveVideo";
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
    <div className="min-h-screen bg-background text-foreground font-sans">
      {/* Hero Section */}
      <header className="relative py-20 px-6 bg-linear-to-b from-primary/10 to-background overflow-hidden">
        <div className="container mx-auto max-w-6xl flex flex-col items-center text-center">
          <img 
            src={logoAsset.url} 
            alt="GRM Guardião Logo" 
            className="w-48 md:w-64 mb-8 drop-shadow-2xl animate-in fade-in zoom-in duration-700" 
          />
          <h1 className="text-4xl md:text-6xl font-extrabold tracking-tight mb-6 text-primary">
            GRM GUARDIÃO
          </h1>
          <p className="text-xl md:text-2xl font-medium max-w-2xl text-muted-foreground mb-10 leading-relaxed">
            Especialistas em Segurança Privada e Patrimonial. Protegendo o que é mais importante para você com excelência e compromisso.
          </p>
          <div className="flex flex-col sm:flex-row gap-4">
            <Button size="lg" className="text-lg px-8 py-6 rounded-full shadow-lg hover:shadow-primary/20 transition-all">
              Conhecer Serviços
            </Button>
            <Button size="lg" variant="outline" className="text-lg px-8 py-6 rounded-full border-2">
              <Phone className="mr-2 h-5 w-5" /> Falar com Especialista
            </Button>
          </div>
        </div>
      </header>

      {/* Advantages Section */}
      <section className="py-24 px-6 container mx-auto max-w-6xl">
        <div className="text-center mb-16">
          <h2 className="text-3xl md:text-4xl font-bold mb-4">Vantagens de Contratar</h2>
          <div className="w-20 h-1.5 bg-primary mx-auto rounded-full"></div>
        </div>
        
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-8">
          {advantages.map((adv, index) => (
            <Card key={index} className="border-none shadow-md hover:shadow-xl transition-shadow bg-card/50 backdrop-blur-sm">
              <CardHeader className="items-center text-center">
                <div className="mb-4 p-4 bg-primary/5 rounded-2xl">
                  {adv.icon}
                </div>
                <CardTitle className="text-xl">{adv.title}</CardTitle>
              </CardHeader>
              <CardContent className="text-center text-muted-foreground">
                <p>{adv.description}</p>
              </CardContent>
            </Card>
          ))}
        </div>
      </section>

      {/* Safety Tips & Branding */}
      <section className="py-24 px-6 bg-primary text-primary-foreground">
        <div className="container mx-auto max-w-6xl grid grid-cols-1 lg:grid-cols-2 gap-16 items-center">
          <div>
            <h2 className="text-3xl md:text-4xl font-bold mb-8 flex items-center gap-3">
              <Shield className="h-10 w-10" /> Dicas de Segurança
            </h2>
            <ul className="space-y-6">
              {safetyTips.map((tip, index) => (
                <li key={index} className="flex items-start gap-4 text-lg md:text-xl font-light opacity-90">
                  <span className="flex-shrink-0 w-8 h-8 rounded-full bg-primary-foreground/20 flex items-center justify-center font-bold">
                    {index + 1}
                  </span>
                  {tip}
                </li>
              ))}
            </ul>
          </div>
          <div className="flex flex-col items-center">
            <InteractiveVideo />
            <div className="mt-8 text-center max-w-sm">
              <h3 className="text-2xl font-bold mb-4">Vídeo Interativo GRM</h3>
              <p className="text-lg font-light opacity-70">
                Veja a importância da segurança privada em ação com nossa demonstração interativa.
              </p>
            </div>
          </div>
        </div>
        <Toaster position="top-center" />
      </section>

      {/* Footer / CTA */}
      <footer className="py-12 px-6 text-center border-t border-border">
        <p className="text-muted-foreground text-sm uppercase tracking-widest mb-4">
          © 2026 GRM Guardião Segurança Privada
        </p>
        <div className="flex justify-center gap-6">
          <a href="#" className="hover:text-primary transition-colors font-medium">Privacidade</a>
          <a href="#" className="hover:text-primary transition-colors font-medium">Termos</a>
          <a href="#" className="hover:text-primary transition-colors font-medium">Contato</a>
        </div>
      </footer>
    </div>
  );
}