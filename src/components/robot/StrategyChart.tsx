import React from "react";
import {
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  ReferenceLine,
  ComposedChart,
  Legend,
  Area,
} from "recharts";
import { TrendingUp, ShieldCheck, Target, Zap } from "lucide-react";

const gbpData = [
  { time: "08:00", price: 1.2345, signal: null },
  { time: "09:00", price: 1.2360, signal: null },
  { time: "10:00", price: 1.2382, signal: null },
  { time: "11:00", price: 1.2395, signal: null },
  { time: "12:00", price: 1.2378, signal: "COMPRA" },
  { time: "13:00", price: 1.2410, signal: null },
  { time: "14:00", price: 1.2435, signal: null },
  { time: "15:00", price: 1.2450, signal: null },
  { time: "16:00", price: 1.2420, signal: "PARCIAL" },
  { time: "17:00", price: 1.2405, signal: null },
];

const xauData = [
  { time: "08:00", price: 2385.20, signal: null },
  { time: "09:00", price: 2382.50, signal: null },
  { time: "10:00", price: 2378.00, signal: null },
  { time: "11:00", price: 2380.10, signal: null },
  { time: "12:00", price: 2375.40, signal: "VENDA" },
  { time: "13:00", price: 2368.20, signal: null },
  { time: "14:00", price: 2362.80, signal: null },
  { time: "15:00", price: 2355.10, signal: "BE" },
  { time: "16:00", price: 2348.50, signal: "PARCIAL" },
  { time: "17:00", price: 2352.00, signal: null },
];

export function StrategyChart() {
  return (
    <div className="w-full bg-gradient-to-br from-[#030712] via-[#060b17] to-[#030712] rounded-3xl border border-amber-500/10 overflow-hidden shadow-2xl shadow-amber-900/5">
      {/* Header assertivo */}
      <div className="relative overflow-hidden px-8 py-8 md:px-12 md:py-10">
        <div className="absolute top-0 right-0 w-96 h-96 bg-primary/10 rounded-full blur-[120px] -translate-y-1/3 translate-x-1/3" />
        <div className="absolute bottom-0 left-0 w-72 h-72 bg-amber-500/10 rounded-full blur-[100px] translate-y-1/3 -translate-x-1/3" />

        <div className="relative z-10 max-w-6xl mx-auto">
          <div className="flex items-center gap-3 mb-4">
            <span className="inline-flex items-center gap-2 rounded-full bg-amber-500/10 text-amber-300 border border-amber-500/15 px-3 py-1 text-[10px] font-extrabold uppercase tracking-[0.15em]">
              <Zap className="w-3 h-3" /> Robô Assertivo
            </span>
            <span className="inline-flex items-center gap-2 rounded-full bg-emerald-400/10 text-emerald-300 border border-emerald-400/15 px-3 py-1 text-[10px] font-extrabold uppercase tracking-[0.15em]">
              <ShieldCheck className="w-3.5 h-3.5" /> Estratégia Combinada
            </span>
          </div>

          <h2 className="text-3xl md:text-5xl font-black tracking-tight text-white mb-4 leading-tight">
            Padrões Harmônicos + Gestão Diária <br className="hidden md:block" />
            <span className="text-transparent bg-clip-text bg-gradient-to-r from-amber-200 via-amber-100 to-amber-300">
              Assertiva em Tempo Real
            </span>
          </h2>
          <p className="text-slate-300/90 max-w-2xl text-base md:text-lg leading-relaxed mb-8 font-light">
            Mescla do EA Robô Fênix (padrões Gartley, Morcego, Borboleta, Caranguejo e Tubarão) com filtro de spread, breakeven automático e saída parcial no 1:1 + zero a zero. Aplicado a <strong className="text-white">GBP/USD H30</strong> e <strong className="text-white">XAU/USD</strong>.
          </p>

          {/* Cards de estratégia */}
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-10">
            {[
              {
                label: "Entrada no Ponto D",
                desc: "Detecção imediata na vela em formação — sem esperar fechamento.",
                icon: <Target className="w-5 h-5 text-amber-400" />,
                meta: "AUTO LIGADO",
              },
              {
                label: "Gestão Diária",
                desc: "Stop 2.1% · Meta 4.2% · Máximo 3 posições globais · Risco 0.70%/entrada.",
                icon: <ShieldCheck className="w-5 h-5 text-emerald-400" />,
                meta: "SOMA 3 ATIVOS",
              },
              {
                label: "Saída Inteligente",
                desc: "Parcial 50% no 1:1 + breakeven no zero a zero + travamento no BE.",
                icon: <TrendingUp className="w-5 h-5 text-sky-400" />,
                meta: "BE + PARCIAL",
              },
            ].map((item) => (
              <div
                key={item.label}
                className="group relative rounded-2xl bg-[#0a0f1a]/70 border border-amber-500/10 hover:border-amber-400/20 hover:bg-[#0a0f1a]/90 transition-all p-5 backdrop-blur-md"
              >
                <div className="flex items-center justify-between mb-3">
                  <div className="p-2 rounded-xl bg-amber-500/5 border border-amber-500/10 group-hover:border-amber-400/20 transition-colors">
                    {item.icon}
                  </div>
                  <span className="text-[10px] font-black uppercase tracking-[0.12em] text-slate-400">
                    {item.meta}
                  </span>
                </div>
                <h3 className="font-bold text-white mb-1 tracking-tight">{item.label}</h3>
                <p className="text-xs text-slate-400 leading-relaxed">{item.desc}</p>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Gráficos */}
      <div className="px-6 md:px-10 pb-12">
        <div className="max-w-6xl mx-auto grid grid-cols-1 lg:grid-cols-2 gap-8">
          {/* GBP/USD H30 */}
          <div className="rounded-2xl border border-amber-500/10 bg-gradient-to-br from-[#0a0f1a] via-[#060b17] to-[#030712] p-5 shadow-[inset_0_1px_30px_rgba(245,158,11,0.05)]">
            <div className="flex items-center justify-between mb-4">
              <div>
                <h3 className="text-xl font-black text-amber-300 tracking-tight">GBP/USD — H30</h3>
                <p className="text-xs text-amber-200/60 font-medium">Timeframe H1 · Robô Fênix · Padronizado</p>
              </div>
              <span className="rounded-lg bg-amber-500/15 text-amber-300 border border-amber-500/20 px-2.5 py-1 text-xs font-extrabold uppercase tracking-wide">
                COMPRA
              </span>
            </div>
            <div className="h-72">
              <ResponsiveContainer width="100%" height="100%">
                <ComposedChart data={gbpData} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                  <CartesianGrid strokeDasharray="3 3" stroke="rgba(245,158,11,0.06)" />
                  <XAxis dataKey="time" tick={{ fill: "#cbd5e1", fontSize: 11 }} axisLine={{ stroke: "rgba(245,158,11,0.2)" }} />
                  <YAxis domain={["auto", "auto"]} tick={{ fill: "#cbd5e1", fontSize: 11 }} axisLine={{ stroke: "rgba(245,158,11,0.2)" }} tickFormatter={(v: number) => v.toFixed(4)} />
                  <Tooltip
                    contentStyle={{
                      backgroundColor: "#0f172a",
                      border: "1px solid rgba(255,255,255,0.1)",
                      borderRadius: 12,
                      color: "#fff",
                      fontSize: 12,
                    }}
                    labelStyle={{ color: "#f59e0b" }}
                    formatter={(v: number) => [v.toFixed(4), "Preço"]}
                  />
                  <Area type="monotone" dataKey="price" stroke="#f59e0b" fill="url(#gradGbp)" strokeWidth={2} dot={{ r: 0 }} activeDot={{ r: 6, fill: "#f59e0b", strokeWidth: 0 }} />
                  <ReferenceLine y={1.2378} label={{ value: "ENTRADA D", position: "insideTopRight", fill: "#f59e0b", fontSize: 10, fontWeight: 900 }} stroke="#f59e0b" strokeDasharray="4 4" />
                  <ReferenceLine y={1.2435} label={{ value: "TP", position: "insideTopRight", fill: "#10b981", fontSize: 10, fontWeight: 900 }} stroke="#10b981" strokeDasharray="4 4" />
                  <ReferenceLine y={1.2355} label={{ value: "SL", position: "insideBottomRight", fill: "#ef4444", fontSize: 10, fontWeight: 900 }} stroke="#ef4444" strokeDasharray="4 4" />
                  <defs>
                    <linearGradient id="gradGbp" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="#f59e0b" stopOpacity={0.35} />
                      <stop offset="95%" stopColor="#f59e0b" stopOpacity={0.05} />
                    </linearGradient>
                  </defs>
                  <Legend
                    payload={[
                      { value: "GBP/USD H30", type: "line", color: "#f59e0b" },
                      { value: "Entrada Automática", type: "circle", color: "#10b981" },
                    ]}
                    wrapperStyle={{ fontSize: 11, color: "#94a3b8" }}
                  />
                </ComposedChart>
              </ResponsiveContainer>
            </div>
            <div className="mt-4 flex flex-wrap gap-2 text-xs font-medium text-slate-400">
              <span className="rounded-md bg-amber-500/10 text-amber-300 px-2 py-0.5 border border-amber-500/10">Padrão: GARTLEY</span>
              <span className="rounded-md bg-amber-500/10 text-amber-300 px-2 py-0.5 border border-amber-500/10">Entrada no D</span>
              <span className="rounded-md bg-amber-500/10 text-amber-300 px-2 py-0.5 border border-amber-500/10">RR ≈ 2.0</span>
              <span className="rounded-md bg-amber-500/10 text-amber-300 px-2 py-0.5 border border-amber-500/10">BE Ativo</span>
            </div>
          </div>

          {/* XAU/USD */}
          <div className="rounded-2xl border border-emerald-400/10 bg-gradient-to-br from-[#0a1810] via-[#060b17] to-[#030712] p-5 shadow-[inset_0_1px_30px_rgba(16,185,129,0.05)]">
            <div className="flex items-center justify-between mb-4">
              <div>
                <h3 className="text-xl font-black text-emerald-200 tracking-tight">XAU/USD — H30</h3>
                <p className="text-xs text-emerald-200/50 font-medium">Timeframe H1 · Robô Fênix · Padronizado</p>
              </div>
              <span className="rounded-lg bg-emerald-400/10 text-emerald-200 border border-emerald-400/15 px-2.5 py-1 text-xs font-extrabold uppercase tracking-wide">
                VENDA
              </span>
            </div>
            <div className="h-72">
              <ResponsiveContainer width="100%" height="100%">
                <ComposedChart data={xauData} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                  <CartesianGrid strokeDasharray="3 3" stroke="rgba(16,185,129,0.06)" />
                  <XAxis dataKey="time" tick={{ fill: "#cbd5e1", fontSize: 11 }} axisLine={{ stroke: "rgba(16,185,129,0.2)" }} />
                  <YAxis domain={["auto", "auto"]} tick={{ fill: "#cbd5e1", fontSize: 11 }} axisLine={{ stroke: "rgba(16,185,129,0.2)" }} tickFormatter={(v: number) => v.toFixed(2)} />
                  <Tooltip
                    contentStyle={{
                      backgroundColor: "#0f172a",
                      border: "1px solid rgba(255,255,255,0.1)",
                      borderRadius: 12,
                      color: "#fff",
                      fontSize: 12,
                    }}
                    labelStyle={{ color: "#34d399" }}
                    formatter={(v: number) => [v.toFixed(2), "Preço"]}
                  />
                  <Area type="monotone" dataKey="price" stroke="#10b981" fill="url(#gradXau)" strokeWidth={2} dot={{ r: 0 }} activeDot={{ r: 6, fill: "#10b981", strokeWidth: 0 }} />
                  <ReferenceLine y={2375.4} label={{ value: "ENTRADA D", position: "insideTopRight", fill: "#10b981", fontSize: 10, fontWeight: 900 }} stroke="#10b981" strokeDasharray="4 4" />
                  <ReferenceLine y={2355.1} label={{ value: "TP", position: "insideBottomRight", fill: "#34d399", fontSize: 10, fontWeight: 900 }} stroke="#34d399" strokeDasharray="4 4" />
                  <ReferenceLine y={2378.0} label={{ value: "SL", position: "insideTopRight", fill: "#f87171", fontSize: 10, fontWeight: 900 }} stroke="#f87171" strokeDasharray="4 4" />
                  <defs>
                    <linearGradient id="gradXau" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="#10b981" stopOpacity={0.35} />
                      <stop offset="95%" stopColor="#10b981" stopOpacity={0.05} />
                    </linearGradient>
                  </defs>
                  <Legend
                    payload={[
                      { value: "XAU/USD H30", type: "line", color: "#10b981" },
                      { value: "Entrada Automática", type: "circle", color: "#34d399" },
                    ]}
                    wrapperStyle={{ fontSize: 11, color: "#94a3b8" }}
                  />
                </ComposedChart>
              </ResponsiveContainer>
            </div>
            <div className="mt-4 flex flex-wrap gap-2 text-xs font-medium text-slate-400">
              <span className="rounded-md bg-emerald-400/10 text-emerald-200 px-2 py-0.5 border border-emerald-400/10">Padrão: MORCEGO</span>
              <span className="rounded-md bg-emerald-400/10 text-emerald-200 px-2 py-0.5 border border-emerald-400/10">Entrada no D</span>
              <span className="rounded-md bg-emerald-400/10 text-emerald-200 px-2 py-0.5 border border-emerald-400/10">RR ≈ 2.0</span>
              <span className="rounded-md bg-emerald-400/10 text-emerald-200 px-2 py-0.5 border border-emerald-400/10">BE Ativo</span>
            </div>
          </div>
        </div>

        {/* Resumo assertivo */}
        <div className="max-w-6xl mx-auto mt-8 rounded-2xl bg-[#060b17]/90 border border-amber-500/10 p-6 md:p-8 shadow-[inset_0_1px_20px_rgba(245,158,11,0.03)]">
          <h4 className="text-lg font-black text-amber-100 mb-4 tracking-tight">Resumo da Estratégia Mesclada</h4>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm text-slate-300/90 leading-relaxed">
            <p>
              <strong className="text-amber-300">Entrada no Ponto D:</strong> detecta padrões harmônicos na vela em formação (Gartley, Morcego, Borboleta, Caranguejo, Tubarão) sem esperar fechamento. Filtro de spread ativo bloqueia entradas em horários ruins. Entrada automática respeita limite de 3 posições globais.
            </p>
            <p>
              <strong className="text-emerald-300">Gestão Diária + Parcial:</strong> risco fixo 0.70% por operação, alvo 1.40%. Stop diário 2.1% e meta 4.2%. Breakeven automático no 1x risco. Saída parcial de 50% no 1:1 com travamento no zero a zero, protegendo o capital imediatamente.
            </p>
          </div>
          <div className="mt-6 pt-6 border-t border-amber-500/10 flex items-center gap-3">
            <div className="w-3 h-3 rounded-full bg-emerald-300 animate-pulse" />
            <span className="text-xs font-extrabold uppercase tracking-[0.15em] text-emerald-300">Operando — 24 horas</span>
            <div className="h-4 w-px bg-amber-500/20 mx-2" />
            <span className="text-xs text-slate-500">H30 GBP/USD · XAU/USD · EA Fênix v2.90</span>
          </div>
        </div>
      </div>
    </div>
  );
}
