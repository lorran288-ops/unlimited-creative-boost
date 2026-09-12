import { createFileRoute } from "@tanstack/react-router";
import { Button } from "@/components/ui/button";
import { Download } from "lucide-react";
import { InteractiveVideo } from "@/components/video/InteractiveVideo";
import { StrategyChart } from "@/components/robot/StrategyChart";
import { Toaster } from "@/components/ui/sonner";

export const Route = createFileRoute("/")({
  component: Index,
  head: () => ({
    title: "Robô - Download da Ferramenta",
    meta: [
      {
        property: "og:title",
        content: "Robô - Download da Ferramenta",
      },
      {
        property: "og:description",
        content: "Baixe a ferramenta do robô e comece a usar agora.",
      },
    ],
  }),
});

function Index() {
  return (
    <main className="min-h-screen bg-[#030712] text-slate-100 flex flex-col items-center px-6 py-20 md:py-28">
      <div className="w-full max-w-5xl flex flex-col items-center gap-12 md:gap-16">
        <header className="text-center space-y-6">
          <h1 className="text-5xl md:text-7xl font-black tracking-tighter text-transparent bg-gradient-to-b from-amber-300 via-amber-100 to-amber-600 bg-clip-text drop-shadow-sm">
            Robô
          </h1>
          <p className="text-xl md:text-2xl text-amber-50/90 max-w-3xl mx-auto leading-relaxed font-light">
            Acesse a ferramenta do robô. Veja abaixo o funcionamento e faça o download para começar.
          </p>
        </header>

        <section className="w-full">
          <div className="rounded-3xl border border-amber-500/10 bg-[#060b17]/80 backdrop-blur-2xl p-8 md:p-14 shadow-2xl shadow-amber-900/5">
            <div className="flex justify-center">
              <InteractiveVideo />
            </div>
            <div className="mt-10 w-full flex justify-center">
              <div className="w-full max-w-3xl mx-auto flex flex-col items-center justify-center">
                <StrategyChart />
              </div>
            </div>
            <div className="mt-12 flex justify-center">
              <Button asChild size="lg" className="rounded-full bg-gradient-to-r from-amber-300 to-amber-600 text-[#030712] px-10 py-7 font-extrabold text-xl shadow-2xl shadow-amber-500/20 hover:shadow-amber-400/40 transition-all hover:-translate-y-1 hover:scale-[1.02] h-auto">
                <a href="/download/ferramenta.zip" download>
                  <Download className="h-6 w-6" /> Baixar Ferramenta
                </a>
              </Button>
            </div>
          </div>
        </section>

        <Toaster />
      </div>
    </main>
  );
}