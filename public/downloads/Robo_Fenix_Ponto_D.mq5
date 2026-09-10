//+------------------------------------------------------------------+
//|                 Robo_FenixTrader_2.7_Multi3_Margem.mq5            |
//|   EA de Padroes Harmonicos (XABCD) - Gartley / Morcego /          |
//|   Borboleta / Caranguejo / Tubarao                                |
//|   Gestao diaria: STOP 2% | ALVO 4% | ate 3 entradas por dia       |
//|   Referencia de proporcoes: LiteFinance - Padroes Harmonicos      |
//+------------------------------------------------------------------+
//| v2.70 - Operacao em 3 ativos com gestao somada da conta:          |
//|  - Stop diario 2.1% e meta diaria 4.2% (o dobro), somando os      |
//|    resultados dos 3 ativos                                        |
//|  - Risco 0.70% e alvo 1.40% por operacao (3 x 0.70 = 2.10)        |
//|  - Maximo 3 posicoes abertas na conta (1 por ativo)               |
//|  - Parcial no 1:1 + stop no zero a zero mantidos                  |
//|  - Lote reduzido pela margem livre (fim do "not enough money")    |
//+------------------------------------------------------------------+
//| v2.00 - Entrada imediata no ponto D:                              |
//|  - Deteccao roda a cada tick (nao espera fechar a vela)           |
//|  - O ponto D pode ser a vela em formacao (sem esperar as velas    |
//|    de confirmacao do fractal) -> entra na hora do sinal           |
//|  - Entrada disparada logo apos detectar a figura                  |
//+------------------------------------------------------------------+
//| v1.90 - Melhorias:                                                |
//|  - Corrigida chamada dupla de TentarEntrada() no OnTick (risco    |
//|    de abrir 2 posicoes no mesmo sinal)                            |
//|  - Sinal operado persistido em GlobalVariable: reiniciar o EA no  |
//|    meio do dia nao reentra no mesmo padrao                        |
//|  - Saldo inicial do dia recalculado pelo historico fechado:       |
//|    percentual do dia correto mesmo apos reiniciar o EA            |
//|  - Lote minimo nao forca mais entrada com risco acima do plano    |
//|    (novo input InpPularEntradaLoteMinimo)                         |
//|  - Filtro de spread maximo para bloquear entradas em horarios     |
//|    ruins (InpUsarSpreadMaximo / InpSpreadMaximoPontos)            |
//|  - Breakeven automatico: move o stop para a entrada + folga       |
//|    quando o preco anda InpGatilhoBE x o risco a favor             |
//|  - Botoes manuais agora respeitam bloqueio e limite de entradas   |
//|  - Precisao do lote calculada pelo SYMBOL_VOLUME_STEP             |
//+------------------------------------------------------------------+
#property copyright "Robo Gartley Harmonico"
#property version   "2.70"

#include <Trade\Trade.mqh>

//======================= ENTRADAS ==================================
input group "=== PADROES HARMONICOS ==="
input ENUM_TIMEFRAMES InpTFSinal        = PERIOD_H1;   // Timeframe do sinal (padrao H1)
input int    InpFractalDepth            = 2;           // Profundidade do pivo (velas de cada lado)
input int    InpBarrasBusca             = 600;         // Barras analisadas para achar XABCD
input double InpTolerancia              = 0.12;        // Tolerancia dos niveis Fibonacci (0.12)
input int    InpMaxPivos                = 40;          // Quantidade de pivos analisados
input bool   InpUsarFiltroCD            = false;       // Exigir projecao CD dentro da faixa
input bool   InpAceitarGenerico         = true;        // Aceitar padrao harmonico generico (ABCD)
input bool   InpLogDiagnostico          = true;        // Imprimir diagnostico no Especialistas
input bool   InpUsarGartley             = true;        // Gartley (B 0.618 | D 0.786)
input bool   InpUsarMorcego             = true;        // Morcego (B 0.382-0.50 | D 0.886)
input bool   InpUsarBorboleta           = true;        // Borboleta (B 0.786 | D 1.272)
input bool   InpUsarCaranguejo          = true;        // Caranguejo (B 0.382-0.618 | D 1.618)
input bool   InpUsarTubarao             = true;        // Tubarao (B 0.382-0.618 | D 0.886-1.13)
input bool   InpConfirmarVela           = false;       // Exigir vela de confirmacao no PRZ
input double InpCorpoMinimo             = 0.30;        // Forca minima do corpo da vela (0-1)
input double InpDistanciaPRZ            = 2.0;         // Distancia maxima do preco ao ponto D (x ATR)

input group "=== GESTAO DIARIA (percentual do saldo) ==="
input double InpStopDiarioPct           = 0.2;         // Stop maximo diario (%) - conta toda
input double InpAlvoDiarioPct           = 0.4;         // Alvo maximo diario (%) - o dobro do stop
input int    InpMaxEntradasDia          = 2;           // Maximo de entradas por dia (1 a 2)
input int    InpMaxPosicoesAbertas      = 1;           // Maximo de posicoes abertas no MESMO ativo
input bool   InpGestaoGlobal            = true;        // Gestao somada da conta (3 ativos juntos)
input int    InpMaxPosicoesGlobal       = 3;           // Maximo de posicoes abertas na conta (3 ativos)
input bool   InpAjustarLotePorMargem    = true;        // Reduzir o lote conforme a margem livre
input double InpMargemLivreUsoPct       = 30.0;        // Usar no maximo X% da margem livre por ordem
input double InpLoteMaximo              = 0.0;         // Limite de lote (0 = sem limite)
input double InpRRMinimo                = 1.2;         // Razao risco/retorno minima aceita
input bool   InpUsarRiscoFixo           = true;        // Usar risco/alvo fixos por operacao (abaixo)
input double InpRiscoPorEntradaPct      = 0.10;        // Stop por operacao (% do saldo) - 2 x 0,10 = 0,20
input double InpAlvoPorEntradaPct       = 0.20;        // Take profit por operacao (% do saldo) - o dobro

input group "=== EXECUCAO ==="
input double InpFolgaStopATR            = 0.5;         // Folga do stop (x ATR) alem do ponto X
input int    InpATRPeriodo              = 14;          // Periodo do ATR
input int    InpSlippage                = 30;          // Desvio maximo (pontos)
input ulong  InpMagic                   = 20260902;    // Numero magico
input bool   InpFecharTudoNaMeta        = true;        // Fechar posicoes ao bater meta/stop diario
input bool   InpUsarSpreadMaximo        = true;        // Bloquear entrada com spread alto
input int    InpSpreadMaximoPontos      = 50;          // Spread maximo permitido (pontos)
input bool   InpPularEntradaLoteMinimo  = true;        // Nao entrar se o lote de risco < lote minimo
input bool   InpMoverBreakeven          = true;        // Mover stop para o breakeven
input double InpGatilhoBE               = 1.0;         // Gatilho do BE (x risco inicial a favor)
input double InpOffsetBE                = 0.1;         // Folga do BE alem da entrada (x risco)
input bool   InpSaidaParcial            = true;        // Realizar parcial e travar no zero a zero
input double InpGatilhoParcial          = 1.0;         // Gatilho da parcial (x risco a favor)
input double InpPercentualParcial       = 50.0;        // Quanto fechar na parcial (% do volume)

input group "=== PAINEL ==="
input bool   InpMostrarPainel           = true;        // Mostrar painel
input bool   InpMostrarBotoes           = true;        // Mostrar botoes
input bool   InpDesenharPadrao          = true;        // Desenhar as figuras no grafico
input int    InpMaxFiguras              = 3;           // Quantas figuras desenhar (1 a 5)
input bool   InpDesenharSempre          = true;        // Desenhar mesmo sem operar
input bool   InpDesenharPivos           = true;        // Desenhar os pivos (zigzag) sempre
input int    InpLarguraLinha            = 2;           // Espessura das linhas da figura

input group "=== ENTRADAS AUTOMATICAS ==="
input bool   InpEntradasAutomaticas     = true;        // Entradas automaticas LIGADAS: opera ao formar o ponto D
input bool   InpAlertaPadrao            = true;        // Alerta quando achar padrao
input bool   InpEntrarAoFecharFigura    = true;        // Entrar assim que a figura fechar no ponto D
input bool   InpIgnorarDistanciaPRZ     = true;        // Ignorar limite de distancia do preco ao D
input bool   InpIgnorarRRMinimo         = true;        // Ignorar filtro de RR minimo
input bool   InpDNaVelaAtual            = true;        // Aceitar ponto D na vela em formacao (entrada imediata)
input int    InpScanSegundos            = 1;           // Reavaliar as figuras a cada X segundos (0 = todo tick)

//======================= GLOBAIS ===================================
CTrade   trade;
int      hATR = INVALID_HANDLE;

double   gSaldoInicioDia = 0.0;
int      gDiaAtual       = -1;
int      gEntradasHoje   = 0;
bool     gBloqueadoDia   = false;
string   gMotivoBloqueio = "";
datetime gUltimaBarraSinal = 0;
datetime gUltimoScan       = 0;

string   PFX = "GH_";

//--- estrutura do padrao encontrado
struct Harmonico
{
   bool     valido;
   bool     compra;      // true = padrao taurino (compra em D)
   string   nome;
   double   X, A, B, C, D;
   datetime tX, tA, tB, tC, tD;
};
Harmonico gPad;
Harmonico gPads[8];
int       gQtdPadroes = 0;
string    gUltimoAlerta = "";
datetime  gSinalOperadoTD = 0;   // tempo do ponto D do ultimo sinal operado (persistente)
int       gQtdPivos    = 0;
double    gPvPreco[];
datetime  gPvTempo[];
int       gPvTipo[];

//======================= UTILITARIOS ===============================
double Saldo() { return AccountInfoDouble(ACCOUNT_BALANCE); }
double Equity(){ return AccountInfoDouble(ACCOUNT_EQUITY); }

double ATRVal()
{
   double b[];
   if(hATR == INVALID_HANDLE) return 0.0;
   if(CopyBuffer(hATR, 0, 1, 1, b) != 1) return 0.0;
   return b[0];
}

bool DentroTol(double valor, double alvo, double tol)
{
   return (MathAbs(valor - alvo) <= tol);
}

bool DentroFaixa(double valor, double min, double max, double tol)
{
   return (valor >= min - tol && valor <= max + tol);
}

//--- chave da GlobalVariable usada para lembrar o sinal ja operado
string GVChaveSinal()
{
   return "GH_SINAL_" + _Symbol + "_" + (string)InpMagic;
}

void MarcarSinalOperado(datetime tD)
{
   gSinalOperadoTD = tD;
   GlobalVariableSet(GVChaveSinal(), (double)tD);
}

void CarregarSinalOperado()
{
   string gv = GVChaveSinal();
   if(GlobalVariableCheck(gv))
      gSinalOperadoTD = (datetime)GlobalVariableGet(gv);
   else
      gSinalOperadoTD = 0;
}

int PosicoesEA()
{
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!PositionSelectByTicket(PositionGetTicket(i))) continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagic) continue;
      if(!InpGestaoGlobal && PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      n++;
   }
   return n;
}

double ResultadoAbertoEA()
{
   double r = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!PositionSelectByTicket(PositionGetTicket(i))) continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagic) continue;
      r += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   return r;
}

double ResultadoFechadoHoje()
{
   datetime ini = iTime(_Symbol, PERIOD_D1, 0);
   if(!HistorySelect(ini, TimeCurrent() + 60)) return 0.0;
   double soma = 0.0;
   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong t = HistoryDealGetTicket(i);
      if(t == 0) continue;
      if(HistoryDealGetInteger(t, DEAL_MAGIC) != (long)InpMagic) continue;
      if(!InpGestaoGlobal && HistoryDealGetString(t, DEAL_SYMBOL) != _Symbol) continue;
      long entry = HistoryDealGetInteger(t, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_INOUT) continue;
      soma += HistoryDealGetDouble(t, DEAL_PROFIT)
            + HistoryDealGetDouble(t, DEAL_SWAP)
            + HistoryDealGetDouble(t, DEAL_COMMISSION);
   }
   return soma;
}

double ResultadoDiaPct()
{
   if(gSaldoInicioDia <= 0.0) return 0.0;
   return (ResultadoFechadoHoje() + ResultadoAbertoEA()) / gSaldoInicioDia * 100.0;
}

int EntradasHojeHistorico()
{
   datetime ini = iTime(_Symbol, PERIOD_D1, 0);
   if(!HistorySelect(ini, TimeCurrent() + 60)) return 0;
   int n = 0, total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong t = HistoryDealGetTicket(i);
      if(t == 0) continue;
      if(HistoryDealGetInteger(t, DEAL_MAGIC) != (long)InpMagic) continue;
      if(!InpGestaoGlobal && HistoryDealGetString(t, DEAL_SYMBOL) != _Symbol) continue;
      if(HistoryDealGetInteger(t, DEAL_ENTRY) == DEAL_ENTRY_IN) n++;
   }
   return n;
}

void FecharTodasEA(bool somenteSimbolo)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(!PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagic) continue;
      if(somenteSimbolo && PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      trade.PositionClose(tk);
   }
}

//======================= CONTROLE DE DIA ===========================
void AtualizarDia()
{
   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
   if(dt.day != gDiaAtual)
   {
      gDiaAtual        = dt.day;
      // Saldo do inicio do dia calculado pelo historico: correto mesmo
      // quando o EA e reiniciado no meio do dia
      gSaldoInicioDia  = Saldo() - ResultadoFechadoHoje();
      if(gSaldoInicioDia <= 0.0) gSaldoInicioDia = Saldo();
      gEntradasHoje    = EntradasHojeHistorico();
      gBloqueadoDia    = false;
      gMotivoBloqueio  = "";
      CarregarSinalOperado();
   }
}

void ChecarLimitesDiarios()
{
   double pct = ResultadoDiaPct();
   if(!gBloqueadoDia)
   {
      if(pct <= -InpStopDiarioPct)
      {
         gBloqueadoDia = true;
         gMotivoBloqueio = "STOP DIARIO ATINGIDO (" + DoubleToString(pct, 2) + "%)";
         if(InpFecharTudoNaMeta) FecharTodasEA(false);
         Print("[GESTAO] ", gMotivoBloqueio);
      }
      else if(pct >= InpAlvoDiarioPct)
      {
         gBloqueadoDia = true;
         gMotivoBloqueio = "META DIARIA BATIDA (+" + DoubleToString(pct, 2) + "%)";
         if(InpFecharTudoNaMeta) FecharTodasEA(false);
         Print("[GESTAO] ", gMotivoBloqueio);
      }
   }
   if(!gBloqueadoDia && gEntradasHoje >= InpMaxEntradasDia)
   {
      gMotivoBloqueio = "LIMITE DE " + (string)InpMaxEntradasDia + " ENTRADAS/DIA";
   }
}

//======================= DETECCAO DE PIVOS =========================
// Preenche arrays com os ultimos pivos alternados (mais recente = indice 0)
bool ColetarPivos(double &preco[], datetime &tempo[], int &tipo[], int maxPivos)
{
   ArrayResize(preco, 0); ArrayResize(tempo, 0); ArrayResize(tipo, 0);

   int d = MathMax(1, InpFractalDepth);
   int bars = MathMin(InpBarrasBusca, iBars(_Symbol, InpTFSinal) - d - 2);
   if(bars < 30) return false;

   int ultimoTipo = 0;
   // Com InpDNaVelaAtual o scan comeca na vela em formacao (i = 0): o ponto D
   // e reconhecido no momento em que o preco chega, sem esperar as velas de
   // confirmacao do fractal a direita.
   int iInicial = InpDNaVelaAtual ? 0 : (d + 1);
   for(int i = iInicial; i <= bars; i++)
   {
      double hi = iHigh(_Symbol, InpTFSinal, i);
      double lo = iLow (_Symbol, InpTFSinal, i);
      bool topo = true, fundo = true;
      for(int k = 1; k <= d; k++)
      {
         // lado esquerdo (velas mais antigas) sempre existe
         if(iHigh(_Symbol, InpTFSinal, i + k) > hi) topo  = false;
         if(iLow (_Symbol, InpTFSinal, i + k) < lo) fundo = false;
         // lado direito so e checado quando a vela ja existe
         if(i - k >= 0)
         {
            if(iHigh(_Symbol, InpTFSinal, i - k) > hi) topo  = false;
            if(iLow (_Symbol, InpTFSinal, i - k) < lo) fundo = false;
         }
         if(!topo && !fundo) break;
      }
      int t = topo ? 1 : (fundo ? -1 : 0);
      if(t == 0) continue;
      if(t == ultimoTipo)
      {
         // mesmo tipo: mantem o extremo mais relevante
         int last = ArraySize(preco) - 1;
         if(last >= 0)
         {
            double pr = (t == 1 ? hi : lo);
            if((t == 1 && pr > preco[last]) || (t == -1 && pr < preco[last]))
            { preco[last] = pr; tempo[last] = iTime(_Symbol, InpTFSinal, i); }
         }
         continue;
      }

      int n = ArraySize(preco);
      ArrayResize(preco, n + 1); ArrayResize(tempo, n + 1); ArrayResize(tipo, n + 1);
      preco[n] = (t == 1 ? hi : lo);
      tempo[n] = iTime(_Symbol, InpTFSinal, i);
      tipo[n]  = t;
      ultimoTipo = t;
      if(ArraySize(preco) >= maxPivos) break;
   }
   return (ArraySize(preco) >= 5);
}

//======================= VALIDACAO DO PADRAO =======================
bool ClassificarPadrao(double retB, double retC, double projCD, double retD, string &nome)
{
   double tol = InpTolerancia;
   bool   cd  = !InpUsarFiltroCD;   // quando o filtro CD esta desligado, sempre passa

   if(InpUsarGartley && DentroTol(retB, 0.618, tol) &&
      DentroFaixa(retC, 0.382, 0.886, tol) &&
      (cd || DentroFaixa(projCD, 1.272, 2.618, tol)) &&
      DentroTol(retD, 0.786, tol)) { nome = "GARTLEY"; return true; }

   if(InpUsarMorcego && DentroFaixa(retB, 0.382, 0.50, tol) &&
      DentroFaixa(retC, 0.382, 0.886, tol) &&
      (cd || DentroFaixa(projCD, 1.618, 3.618, tol)) &&
      DentroTol(retD, 0.886, tol)) { nome = "MORCEGO"; return true; }

   if(InpUsarBorboleta && DentroTol(retB, 0.786, tol) &&
      DentroFaixa(retC, 0.382, 0.886, tol) &&
      (cd || DentroFaixa(projCD, 1.618, 3.618, tol)) &&
      DentroTol(retD, 1.272, tol)) { nome = "BORBOLETA"; return true; }

   if(InpUsarCaranguejo && DentroFaixa(retB, 0.382, 0.618, tol) &&
      DentroFaixa(retC, 0.382, 0.886, tol) &&
      (cd || DentroFaixa(projCD, 2.24, 4.618, tol)) &&
      DentroTol(retD, 1.618, tol)) { nome = "CARANGUEJO"; return true; }

   if(InpUsarTubarao && DentroFaixa(retB, 0.382, 0.618, tol) &&
      DentroFaixa(retC, 1.13, 1.618, tol) &&
      (cd || DentroFaixa(projCD, 1.618, 3.618, tol)) &&
      DentroFaixa(retD, 0.886, 1.13, tol)) { nome = "TUBARAO"; return true; }

   // padrao harmonico generico: estrutura XABCD valida com D em zona de reversao
   if(InpAceitarGenerico &&
      DentroFaixa(retB, 0.30, 0.90, tol) &&
      DentroFaixa(retC, 0.30, 1.00, tol) &&
      DentroFaixa(retD, 0.55, 1.70, tol)) { nome = "HARMONICO"; return true; }

   return false;
}

//======================= LOTE / ORDEM ==============================
// Precisao do lote a partir do SYMBOL_VOLUME_STEP (ex.: 0.01 -> 2 casas)
int DigitosLote()
{
   double stepL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(stepL <= 0) return 2;
   int dig = 0;
   double s = stepL;
   while(dig < 8 && MathAbs(s - MathRound(s)) > 1e-9) { s *= 10.0; dig++; }
   return dig;
}

//======================= GESTAO POR OPERACAO ========================
double RiscoPorEntradaPct()
{
   if(InpUsarRiscoFixo && InpRiscoPorEntradaPct > 0) return InpRiscoPorEntradaPct;
   return InpStopDiarioPct / MathMax(1, InpMaxEntradasDia);
}

double AlvoPorEntradaPct()
{
   if(InpUsarRiscoFixo && InpAlvoPorEntradaPct > 0) return InpAlvoPorEntradaPct;
   return InpAlvoDiarioPct / MathMax(1, InpMaxEntradasDia);
}

double CalcularLote(double distanciaStop, double riscoPct)
{
   if(distanciaStop <= 0.0) return 0.0;
   double risco = gSaldoInicioDia * riscoPct / 100.0;

   double tick  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickV = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tick <= 0 || tickV <= 0) return 0.0;

   double perdaPorLote = (distanciaStop / tick) * tickV;
   if(perdaPorLote <= 0) return 0.0;

   double lote = risco / perdaPorLote;
   double minL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepL= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(stepL <= 0) stepL = 0.01;

   lote = MathFloor(lote / stepL) * stepL;
   if(lote < minL)
   {
      // antes o EA entrava com o lote minimo mesmo com risco acima do plano
      if(InpPularEntradaLoteMinimo)
      {
         PrintFormat("[RISCO] Lote calculado %.4f abaixo do minimo %.2f - entrada pulada para nao estourar o risco",
                     lote, minL);
         return 0.0;
      }
      lote = minL;
   }
   if(lote > maxL) lote = maxL;
   return NormalizeDouble(lote, DigitosLote());
}

// Reduz o lote para caber na margem livre da conta. Evita o erro
// "not enough money" quando o robo roda em varios ativos ao mesmo tempo.
double LimitarLotePorMargem(double lote, const bool compra, const double preco)
{
   if(lote <= 0.0) return 0.0;

   double minL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double stepL= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(stepL <= 0) stepL = 0.01;

   if(InpLoteMaximo > 0.0 && lote > InpLoteMaximo)
      lote = MathFloor(InpLoteMaximo / stepL) * stepL;

   if(!InpAjustarLotePorMargem)
      return NormalizeDouble(lote, DigitosLote());

   double livre = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double limite = livre * MathMax(1.0, InpMargemLivreUsoPct) / 100.0;
   if(limite <= 0.0) return 0.0;

   ENUM_ORDER_TYPE tipo = compra ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   double margem = 0.0;
   if(!OrderCalcMargin(tipo, _Symbol, lote, preco, margem) || margem <= 0.0)
      return NormalizeDouble(lote, DigitosLote());

   if(margem > limite)
   {
      double fator = limite / margem;
      double novo  = MathFloor((lote * fator) / stepL) * stepL;
      PrintFormat("[MARGEM] Lote %.2f exige %.2f de margem (limite %.2f) - reduzido para %.2f",
                  lote, margem, limite, novo);
      lote = novo;
   }

   if(lote < minL)
   {
      PrintFormat("[MARGEM] Margem livre insuficiente (%.2f) - entrada pulada", livre);
      return 0.0;
   }
   return NormalizeDouble(lote, DigitosLote());
}

bool SpreadOk()
{
   if(!InpUsarSpreadMaximo) return true;
   long sp = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(sp > InpSpreadMaximoPontos)
   {
      if(InpLogDiagnostico)
         PrintFormat("[DIAG] Entrada bloqueada: spread %d pts acima do maximo %d",
                     (int)sp, InpSpreadMaximoPontos);
      return false;
   }
   return true;
}

bool VelaConfirma(bool compra)
{
   if(!InpConfirmarVela) return true;
   double o = iOpen (_Symbol, InpTFSinal, 1);
   double c = iClose(_Symbol, InpTFSinal, 1);
   double h = iHigh (_Symbol, InpTFSinal, 1);
   double l = iLow  (_Symbol, InpTFSinal, 1);
   double range = h - l;
   if(range <= 0) return false;
   double forca = MathAbs(c - o) / range;
   if(forca < InpCorpoMinimo) return false;
   return (compra ? (c > o) : (c < o));
}

void TentarEntrada()
{
   if(!InpEntradasAutomaticas)
   {
      if(InpLogDiagnostico) Print("[AUTO] Entrada nao enviada: automatico DESLIGADO nos parametros.");
      return;
   }
   if(gBloqueadoDia)
   {
      if(InpLogDiagnostico) Print("[AUTO] Entrada bloqueada pela gestao: ", gMotivoBloqueio);
      return;
   }
   if(gEntradasHoje >= InpMaxEntradasDia)
   {
      if(InpLogDiagnostico) Print("[AUTO] Entrada bloqueada: limite diario de entradas atingido.");
      return;
   }
   if(PosicoesEA() >= (InpGestaoGlobal ? InpMaxPosicoesGlobal : InpMaxPosicoesAbertas))
   {
      if(InpLogDiagnostico) Print("[AUTO] Entrada bloqueada: ja existe posicao aberta deste robo no simbolo.");
      return;
   }

   Harmonico p = gPad;
   if(!p.valido) return;

   if(!VelaConfirma(p.compra))
   {
      if(InpLogDiagnostico) Print("[AUTO] Entrada aguardando confirmacao da vela no ponto D.");
      return;
   }

   double atr = ATRVal();
   double folga = atr * InpFolgaStopATR;
   if(folga <= 0) folga = 10 * _Point;

   // ENTRADA NO FECHAMENTO DA FIGURA: cada padrao novo gera uma entrada unica.
   // O tempo do ponto D fica salvo em GlobalVariable, entao reiniciar o EA
   // no meio do dia nao dispara o mesmo sinal de novo.
   if(InpEntrarAoFecharFigura)
   {
      if(p.tD != 0 && p.tD == gSinalOperadoTD) return;   // esse padrao ja foi operado
   }
   else if(!InpIgnorarDistanciaPRZ)
   {
      // modo antigo: o preco precisa estar perto do ponto D (zona PRZ)
      double refPreco = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double limitePRZ = (atr > 0 ? atr : 20 * _Point) * MathMax(0.5, InpDistanciaPRZ);
      if(MathAbs(refPreco - p.D) > limitePRZ)
      {
         if(InpLogDiagnostico)
            PrintFormat("[DIAG] Padrao %s aguardando: preco a %.2f do ponto D (limite %.2f)",
                        p.nome, MathAbs(refPreco - p.D), limitePRZ);
         return;
      }
   }

   if(!SpreadOk()) return;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double preco = p.compra ? ask : bid;

   // Stop alem do ponto X (SLZ) com folga por ATR
   double sl = p.compra ? MathMin(p.D, p.X) - folga : MathMax(p.D, p.X) + folga;
   double dist = MathAbs(preco - sl);
   if(dist <= 0)
   {
      if(InpLogDiagnostico) Print("[AUTO] Entrada cancelada: distancia do stop invalida.");
      return;
   }

   // Alvos harmonicos: 0.618 da perna AD projetada a partir de D
   double AD = MathAbs(p.A - p.D);
   double alvoHarm = p.compra ? p.D + AD * 0.618 : p.D - AD * 0.618;

   double riscoPct = RiscoPorEntradaPct();             // 1.00% no padrao
   double alvoPct  = AlvoPorEntradaPct();              // 2.00% no padrao
   double rrGestao = alvoPct / MathMax(0.01, riscoPct); // = 2.0 no padrao
   double tpGestao = p.compra ? preco + dist * rrGestao : preco - dist * rrGestao;

   // usa o menor entre alvo harmonico e alvo de gestao (mais conservador)
   double tp = p.compra ? MathMin(alvoHarm, tpGestao) : MathMax(alvoHarm, tpGestao);
   double rrFinal = MathAbs(tp - preco) / dist;
   if(!InpIgnorarRRMinimo && rrFinal < InpRRMinimo)
   {
      if(InpLogDiagnostico)
         PrintFormat("[DIAG] Padrao %s descartado: RR %.2f abaixo do minimo %.2f",
                     p.nome, rrFinal, InpRRMinimo);
      return;
   }

   double lote = CalcularLote(dist, riscoPct);
   if(lote <= 0)
   {
      if(InpLogDiagnostico) Print("[AUTO] Entrada cancelada: lote calculado invalido ou abaixo do minimo permitido.");
      return;
   }

   int dig = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   AjustarStops(p.compra, preco, sl, tp);
   dist = MathAbs(preco - sl);
   lote = CalcularLote(dist, riscoPct);
   lote = LimitarLotePorMargem(lote, p.compra, preco);
   if(lote <= 0)
   {
      Print("[AUTO] Entrada cancelada: lote invalido apos ajuste de stops/margem.");
      return;
   }

   string com = p.nome + " " + (p.compra ? "BUY" : "SELL") + " RR" + DoubleToString(rrFinal, 2);
   bool enviado = p.compra ? trade.Buy(lote, _Symbol, 0.0, sl, tp, com)
                            : trade.Sell(lote, _Symbol, 0.0, sl, tp, com);
   uint retorno = trade.ResultRetcode();
   bool executado = enviado && (retorno == TRADE_RETCODE_DONE ||
                                retorno == TRADE_RETCODE_DONE_PARTIAL ||
                                retorno == TRADE_RETCODE_PLACED);
   if(executado)
   {
      gEntradasHoje++;
      MarcarSinalOperado(p.tD);   // marca somente depois de a corretora aceitar a ordem
      PrintFormat("[ENTRADA AUTOMATICA %d/%d] PONTO D | %s %s | lote=%.*f SL=%.*f TP=%.*f risco=%.2f%% | ordem=%I64u",
                  gEntradasHoje, InpMaxEntradasDia, p.nome, p.compra ? "COMPRA" : "VENDA",
                  DigitosLote(), lote, dig, sl, dig, tp, riscoPct, trade.ResultOrder());
      Alert("ENTRADA AUTOMATICA NO D: ", p.nome, " ", p.compra ? "COMPRA" : "VENDA",
            " | ", _Symbol, " | lote ", DoubleToString(lote, DigitosLote()));
   }
   else
   {
      PrintFormat("[ERRO ORDEM NO D] %s %s | retcode=%u | %s | lote=%.*f SL=%.*f TP=%.*f",
                  p.nome, p.compra ? "COMPRA" : "VENDA", retorno,
                  trade.ResultRetcodeDescription(), DigitosLote(), lote, dig, sl, dig, tp);
      Alert("ORDEM NO D RECUSADA: ", trade.ResultRetcodeDescription(), " | veja a aba Especialistas");
   }
}

//=================== VALIDACAO DE STOPS ============================
// Ajusta SL/TP para respeitar a distancia minima exigida pela corretora
// (SYMBOL_TRADE_STOPS_LEVEL + spread) e garante que fiquem do lado certo
// do preco. Evita o erro "invalid stops".
void AjustarStops(const bool compra, const double preco, double &sl, double &tp)
{
   int    dig   = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double pt    = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   long   stopL = (long)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double spr   = MathMax(0.0, ask - bid);
   double minD  = (double)stopL * pt + spr;
   if(minD < 10 * pt) minD = 10 * pt;   // folga de seguranca

   if(compra)
   {
      if(sl > preco - minD) sl = preco - minD;
      if(tp < preco + minD) tp = preco + minD;
   }
   else
   {
      if(sl < preco + minD) sl = preco + minD;
      if(tp > preco - minD) tp = preco - minD;
   }
   sl = NormalizeDouble(sl, dig);
   tp = NormalizeDouble(tp, dig);
}

//======================= BREAKEVEN =================================
// Move o stop para a entrada (+ folga) quando o preco anda
// InpGatilhoBE x o risco inicial a favor da posicao.
void GerenciarBreakeven()
{
   if(!InpMoverBreakeven) return;

   int dig = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(!PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      long   tipo = PositionGetInteger(POSITION_TYPE);
      double ab   = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl   = PositionGetDouble(POSITION_SL);
      double tp   = PositionGetDouble(POSITION_TP);
      if(sl == 0.0) continue;   // sem stop inicial nao ha como medir o risco

      double risco = MathAbs(ab - sl);
      if(risco <= 0) continue;

      if(tipo == POSITION_TYPE_BUY)
      {
         if(sl >= ab) continue;   // ja protegido
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid >= ab + risco * InpGatilhoBE)
         {
            double novoSL = NormalizeDouble(ab + risco * InpOffsetBE, dig);
            if(trade.PositionModify(tk, novoSL, tp))
               PrintFormat("[BE] Ticket %I64u: stop movido para %.*f", tk, dig, novoSL);
         }
      }
      else if(tipo == POSITION_TYPE_SELL)
      {
         if(sl <= ab) continue;   // ja protegido
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(ask <= ab - risco * InpGatilhoBE)
         {
            double novoSL = NormalizeDouble(ab - risco * InpOffsetBE, dig);
            if(trade.PositionModify(tk, novoSL, tp))
               PrintFormat("[BE] Ticket %I64u: stop movido para %.*f", tk, dig, novoSL);
         }
      }
   }
}

//=================== SAIDA PARCIAL + ZERO A ZERO ==================
// Ao atingir InpGatilhoParcial x o risco a favor, fecha InpPercentualParcial
// do volume e move o stop para o preco de entrada (zero a zero).
ulong gParcialFeita[64];
int   gQtdParcial = 0;

bool ParcialJaFeita(ulong tk)
{
   for(int i = 0; i < gQtdParcial; i++)
      if(gParcialFeita[i] == tk) return true;
   return false;
}

void MarcarParcial(ulong tk)
{
   if(gQtdParcial < 64) gParcialFeita[gQtdParcial++] = tk;
   else { gParcialFeita[0] = tk; gQtdParcial = 1; }
}

void GerenciarParcial()
{
   if(!InpSaidaParcial) return;

   int    dig     = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double loteMin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double passo   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(passo <= 0) passo = loteMin;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(!PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(ParcialJaFeita(tk)) continue;

      long   tipo = PositionGetInteger(POSITION_TYPE);
      double ab   = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl   = PositionGetDouble(POSITION_SL);
      double tp   = PositionGetDouble(POSITION_TP);
      double vol  = PositionGetDouble(POSITION_VOLUME);
      if(sl == 0.0) continue;

      double risco = MathAbs(ab - sl);
      if(risco <= 0) continue;

      bool gatilho = false;
      if(tipo == POSITION_TYPE_BUY)
      {
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         gatilho = (bid >= ab + risco * InpGatilhoParcial);
      }
      else if(tipo == POSITION_TYPE_SELL)
      {
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         gatilho = (ask <= ab - risco * InpGatilhoParcial);
      }
      if(!gatilho) continue;

      // volume a fechar, normalizado ao passo da corretora
      double fechar = vol * InpPercentualParcial / 100.0;
      fechar = MathFloor(fechar / passo) * passo;
      fechar = NormalizeDouble(fechar, DigitosLote());

      if(fechar >= loteMin && (vol - fechar) >= loteMin)
      {
         if(trade.PositionClosePartial(tk, fechar))
            PrintFormat("[PARCIAL] Ticket %I64u: fechado %.*f de %.*f no 1:1",
                        tk, DigitosLote(), fechar, DigitosLote(), vol);
      }

      // trava o restante no zero a zero
      if(PositionSelectByTicket(tk))
      {
         double novoSL = NormalizeDouble(ab, dig);
         bool precisa = (tipo == POSITION_TYPE_BUY) ? (sl < novoSL) : (sl > novoSL);
         if(precisa && trade.PositionModify(tk, novoSL, tp))
            PrintFormat("[ZERO A ZERO] Ticket %I64u: stop na entrada %.*f", tk, dig, novoSL);
      }
      MarcarParcial(tk);
   }
}

//======================= DETECCAO MULTIPLA =========================
// Coleta ate InpMaxFiguras padroes validos (o mais recente primeiro)
void DetectarPadroes()
{
   gQtdPadroes = 0;
   gPad.valido = false;

   int maxFig = MathMin(8, MathMax(1, InpMaxFiguras));

   double pv[]; datetime tv[]; int tp[];
   if(!ColetarPivos(pv, tv, tp, MathMax(10, InpMaxPivos)))
   {
      gQtdPivos = 0;
      if(InpLogDiagnostico) Print("[DIAG] Pivos insuficientes no timeframe do sinal.");
      return;
   }

   ArrayCopy(gPvPreco, pv); ArrayCopy(gPvTempo, tv); ArrayCopy(gPvTipo, tp);
   gQtdPivos = ArraySize(pv);

   int n = ArraySize(pv);
   int testados = 0;
   for(int start = 0; start + 4 < n && gQtdPadroes < maxFig; start++)
   {
      double D = pv[start],   C = pv[start+1], B = pv[start+2];
      double A = pv[start+3], X = pv[start+4];
      int tipoD = tp[start];

      bool taurino = (tipoD == -1 && tp[start+1] == 1 && tp[start+2] == -1 &&
                      tp[start+3] == 1 && tp[start+4] == -1);
      bool ursino  = (tipoD == 1 && tp[start+1] == -1 && tp[start+2] == 1 &&
                      tp[start+3] == -1 && tp[start+4] == 1);
      if(!taurino && !ursino) continue;

      double XA = MathAbs(A - X);
      double AB = MathAbs(B - A);
      double BC = MathAbs(C - B);
      double CD = MathAbs(D - C);
      double AD = MathAbs(D - A);
      if(XA <= 0 || AB <= 0 || BC <= 0 || CD <= 0) continue;
      if(AB >= XA * 1.05) continue;
      testados++;

      double retB   = AB / XA;
      double retC   = BC / AB;
      double projCD = CD / BC;
      double retD   = AD / XA;

      string nome = "";
      if(!ClassificarPadrao(retB, retC, projCD, retD, nome)) continue;

      Harmonico p;
      p.valido = true; p.compra = taurino; p.nome = nome;
      p.X = X; p.A = A; p.B = B; p.C = C; p.D = D;
      p.tX = tv[start+4]; p.tA = tv[start+3]; p.tB = tv[start+2];
      p.tC = tv[start+1]; p.tD = tv[start];

      gPads[gQtdPadroes] = p;
      if(gQtdPadroes == 0) gPad = p;   // padrao mais recente = sinal operacional
      gQtdPadroes++;
   }

   if(InpLogDiagnostico)
      PrintFormat("[DIAG] Pivos=%d | estruturas XABCD testadas=%d | padroes validos=%d",
                  gQtdPivos, testados, gQtdPadroes);

   if(InpAlertaPadrao && gPad.valido)
   {
      string chave = gPad.nome + (string)gPad.tD;
      if(chave != gUltimoAlerta)
      {
         gUltimoAlerta = chave;
         Alert("Padrao ", gPad.nome, " ", gPad.compra ? "COMPRA" : "VENDA", " em ", _Symbol);
         Print("[PADRAO] ", gPad.nome, " ", gPad.compra ? "COMPRA" : "VENDA",
               " | X=", gPad.X, " A=", gPad.A, " B=", gPad.B, " C=", gPad.C, " D=", gPad.D);
      }
   }
}

//======================= DESENHO DAS FIGURAS =======================
void LimparDesenho()
{
   ObjectsDeleteAll(0, PFX + "pat");
}

void DesenharUmPadrao(const Harmonico &p, int idx)
{
   datetime tt[5]; double pp[5];
   tt[0]=p.tX; tt[1]=p.tA; tt[2]=p.tB; tt[3]=p.tC; tt[4]=p.tD;
   pp[0]=p.X;  pp[1]=p.A;  pp[2]=p.B;  pp[3]=p.C;  pp[4]=p.D;
   string lb[5] = {"X","A","B","C","D"};

   color cor = p.compra ? clrDodgerBlue : clrOrangeRed;
   if(idx > 0) cor = p.compra ? clrSteelBlue : clrIndianRed;
   int larg = MathMax(1, InpLarguraLinha);
   if(idx > 0) larg = 1;
   string pre = PFX + "pat" + (string)idx + "_";

   // pernas XA AB BC CD
   for(int i = 0; i < 4; i++)
   {
      string nm = pre + "l" + (string)i;
      if(ObjectFind(0, nm) < 0) ObjectCreate(0, nm, OBJ_TREND, 0, tt[i], pp[i], tt[i+1], pp[i+1]);
      ObjectMove(0, nm, 0, tt[i], pp[i]);
      ObjectMove(0, nm, 1, tt[i+1], pp[i+1]);
      ObjectSetInteger(0, nm, OBJPROP_COLOR, cor);
      ObjectSetInteger(0, nm, OBJPROP_WIDTH, larg);
      ObjectSetInteger(0, nm, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, nm, OBJPROP_BACK, false);
   }

   // triangulos que formam a figura harmonica (X-B-D e A-C-D)
   string t1 = pre + "tri1";
   if(ObjectFind(0, t1) < 0) ObjectCreate(0, t1, OBJ_TRIANGLE, 0, tt[0], pp[0], tt[2], pp[2], tt[4], pp[4]);
   ObjectMove(0, t1, 0, tt[0], pp[0]); ObjectMove(0, t1, 1, tt[2], pp[2]); ObjectMove(0, t1, 2, tt[4], pp[4]);
   ObjectSetInteger(0, t1, OBJPROP_COLOR, cor);
   ObjectSetInteger(0, t1, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, t1, OBJPROP_FILL, false);
   ObjectSetInteger(0, t1, OBJPROP_BACK, true);

   string t2 = pre + "tri2";
   if(ObjectFind(0, t2) < 0) ObjectCreate(0, t2, OBJ_TRIANGLE, 0, tt[1], pp[1], tt[3], pp[3], tt[4], pp[4]);
   ObjectMove(0, t2, 0, tt[1], pp[1]); ObjectMove(0, t2, 1, tt[3], pp[3]); ObjectMove(0, t2, 2, tt[4], pp[4]);
   ObjectSetInteger(0, t2, OBJPROP_COLOR, cor);
   ObjectSetInteger(0, t2, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, t2, OBJPROP_FILL, false);
   ObjectSetInteger(0, t2, OBJPROP_BACK, true);

   // rotulos dos pontos
   for(int i = 0; i < 5; i++)
   {
      string nm = pre + "t" + (string)i;
      if(ObjectFind(0, nm) < 0) ObjectCreate(0, nm, OBJ_TEXT, 0, tt[i], pp[i]);
      ObjectMove(0, nm, 0, tt[i], pp[i]);
      ObjectSetString (0, nm, OBJPROP_TEXT, lb[i]);
      ObjectSetInteger(0, nm, OBJPROP_COLOR, idx == 0 ? clrWhite : clrSilver);
      ObjectSetInteger(0, nm, OBJPROP_FONTSIZE, idx == 0 ? 11 : 9);
      ObjectSetString (0, nm, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, nm, OBJPROP_ANCHOR, (i % 2 == 0) ? ANCHOR_UPPER : ANCHOR_LOWER);
   }

   // nome do padrao no ponto D
   string nn = pre + "nome";
   if(ObjectFind(0, nn) < 0) ObjectCreate(0, nn, OBJ_TEXT, 0, tt[4], pp[4]);
   ObjectMove(0, nn, 0, tt[4], pp[4]);
   ObjectSetString (0, nn, OBJPROP_TEXT, "  " + p.nome + (p.compra ? " (COMPRA)" : " (VENDA)"));
   ObjectSetInteger(0, nn, OBJPROP_COLOR, p.compra ? clrLime : clrTomato);
   ObjectSetInteger(0, nn, OBJPROP_FONTSIZE, idx == 0 ? 10 : 8);
   ObjectSetString (0, nn, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, nn, OBJPROP_ANCHOR, p.compra ? ANCHOR_LEFT_UPPER : ANCHOR_LEFT_LOWER);

   // zona PRZ (retangulo em torno de D)
   double atr = ATRVal();
   if(atr <= 0) atr = 10 * _Point;
   string rz = pre + "prz";
   datetime t2f = tt[4] + PeriodSeconds(InpTFSinal) * 6;
   if(ObjectFind(0, rz) < 0) ObjectCreate(0, rz, OBJ_RECTANGLE, 0, tt[4], pp[4] - atr * 0.5, t2f, pp[4] + atr * 0.5);
   ObjectMove(0, rz, 0, tt[4], pp[4] - atr * 0.5);
   ObjectMove(0, rz, 1, t2f,   pp[4] + atr * 0.5);
   ObjectSetInteger(0, rz, OBJPROP_COLOR, p.compra ? clrSeaGreen : clrMaroon);
   ObjectSetInteger(0, rz, OBJPROP_FILL, true);
   ObjectSetInteger(0, rz, OBJPROP_BACK, true);
}

void DesenharPivos()
{
   ObjectsDeleteAll(0, PFX + "pv");
   if(!InpDesenharPivos) return;
   int n = MathMin(gQtdPivos, MathMax(10, InpMaxPivos));
   for(int i = 0; i + 1 < n; i++)
   {
      string nm = PFX + "pv" + (string)i;
      if(ObjectFind(0, nm) < 0)
         ObjectCreate(0, nm, OBJ_TREND, 0, gPvTempo[i+1], gPvPreco[i+1], gPvTempo[i], gPvPreco[i]);
      ObjectMove(0, nm, 0, gPvTempo[i+1], gPvPreco[i+1]);
      ObjectMove(0, nm, 1, gPvTempo[i],   gPvPreco[i]);
      ObjectSetInteger(0, nm, OBJPROP_COLOR, C'70,70,110');
      ObjectSetInteger(0, nm, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, nm, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, nm, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, nm, OBJPROP_BACK, true);
   }
}

void DesenharPadrao()
{
   if(!InpDesenharPadrao) return;
   LimparDesenho();
   DesenharPivos();
   for(int i = 0; i < gQtdPadroes; i++)
      DesenharUmPadrao(gPads[i], i);
   ChartRedraw();
}

//======================= PAINEL ====================================
void Lbl(string nome, int x, int y, string txt, color cor, int fs = 9, string fonte = "Arial Bold")
{
   string n = PFX + nome;
   if(ObjectFind(0, n) < 0)
   {
      ObjectCreate(0, n, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   }
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetString (0, n, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, n, OBJPROP_COLOR, cor);
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE, fs);
   ObjectSetString (0, n, OBJPROP_FONT, fonte);
}

void Btn(string nome, int x, int y, int w, int h, string txt, color bg, color fg)
{
   string n = PFX + nome;
   if(ObjectFind(0, n) < 0)
   {
      ObjectCreate(0, n, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_LOWER);
   }
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, n, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, n, OBJPROP_YSIZE, h);
   ObjectSetString (0, n, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, n, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, n, OBJPROP_COLOR, fg);
   ObjectSetInteger(0, n, OBJPROP_BORDER_COLOR, clrBlack);
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE, 9);
   ObjectSetString (0, n, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, n, OBJPROP_STATE, false);
}

void AtualizarPainel()
{
   if(!InpMostrarPainel) return;

   double pct = ResultadoDiaPct();
   double res = ResultadoFechadoHoje() + ResultadoAbertoEA();
   color  cRes = (pct > 0 ? clrLime : (pct < 0 ? clrTomato : clrSilver));

   int x = 12, y = 250;

   Lbl("t0", x, y,      "ROBO FENIXTRADER v2.20", clrGold, 11);
   Lbl("t1", x, y - 20, "Sinal: " + EnumToString(InpTFSinal) + "  |  Grafico: " + EnumToString((ENUM_TIMEFRAMES)Period()) +
       "  |  Spread: " + (string)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) + " pts", clrSkyBlue);
   Lbl("t2", x, y - 38, "Padrao atual: " + (gPad.valido ? gPad.nome + (gPad.compra ? " (COMPRA)" : " (VENDA)") : "procurando..."),
       gPad.valido ? (gPad.compra ? clrLime : clrTomato) : clrSilver);
   Lbl("t3", x, y - 56, "Saldo inicio do dia: " + DoubleToString(gSaldoInicioDia, 2), clrWhite);
   Lbl("t4", x, y - 74, "Resultado do dia: " + DoubleToString(res, 2) + "  (" + DoubleToString(pct, 2) + "%)", cRes);
   Lbl("t5", x, y - 92, "Stop diario: -" + DoubleToString(InpStopDiarioPct, 2) + "%   |   Meta diaria: +" + DoubleToString(InpAlvoDiarioPct, 2) + "%", clrKhaki);
   Lbl("t6", x, y - 110, "Risco/entrada: " + DoubleToString(RiscoPorEntradaPct(), 2) +
       "%   |   Alvo/entrada: " + DoubleToString(AlvoPorEntradaPct(), 2) + "%", clrKhaki);
   Lbl("t9", x, y - 128, "Pivos: " + (string)gQtdPivos + "  |  Figuras: " + (string)gQtdPadroes + "/" + (string)MathMax(1, InpMaxFiguras) +
       "   |   Auto: " + (InpEntradasAutomaticas ? "LIGADO" : "DESLIGADO") +
       "   |   BE: " + (InpMoverBreakeven ? "LIGADO" : "DESLIGADO"),
       InpEntradasAutomaticas ? clrLime : clrOrange);
   Lbl("t7", x, y - 146, "Entradas hoje: " + (string)gEntradasHoje + "/" + (string)InpMaxEntradasDia +
       "   |   Abertas: " + (string)PosicoesEA(), clrWhite);

   string aviso = gBloqueadoDia ? gMotivoBloqueio
                : (gEntradasHoje >= InpMaxEntradasDia ? "LIMITE DE ENTRADAS DO DIA" : "OPERANDO - 24 HORAS");
   color cAviso = gBloqueadoDia ? (pct >= 0 ? clrLime : clrRed)
                : (gEntradasHoje >= InpMaxEntradasDia ? clrOrange : clrLime);
   Lbl("t8", x, y - 168, ">> " + aviso, cAviso, 10);

   if(InpMostrarBotoes)
   {
      Btn("bBuy",   x, y - 200, 180, 30, "COMPRA MANUAL",  clrGreen,        clrWhite);
      Btn("bSell",  x, y - 234, 180, 30, "VENDA MANUAL",   clrFireBrick,    clrWhite);
      Btn("bCloseS",x, y - 268, 180, 30, "FECHAR SIMBOLO", C'40,40,40',     clrWhite);
      Btn("bCloseA",x, y - 302, 180, 30, "FECHAR TUDO",    C'90,90,90',     clrWhite);
   }
   ChartRedraw();
}

void AbrirManual(bool compra)
{
   // botoes manuais agora respeitam os mesmos limites da gestao diaria
   if(gBloqueadoDia)
   {
      Print("[MANUAL] Entrada bloqueada: ", gMotivoBloqueio);
      return;
   }
   if(gEntradasHoje >= InpMaxEntradasDia)
   {
      Print("[MANUAL] Limite de ", InpMaxEntradasDia, " entradas/dia atingido");
      return;
   }
   if(PosicoesEA() >= (InpGestaoGlobal ? InpMaxPosicoesGlobal : InpMaxPosicoesAbertas))
   {
      Print("[MANUAL] Limite de posicoes abertas atingido");
      return;
   }

   double atr = ATRVal();
   double folga = atr > 0 ? atr : 20 * _Point;
   double preco = compra ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double dist  = folga * 2.0;
   double sl = compra ? preco - dist : preco + dist;
   double rr = AlvoPorEntradaPct() / MathMax(0.01, RiscoPorEntradaPct());
   double tp = compra ? preco + dist * rr : preco - dist * rr;
   double lote = CalcularLote(dist, RiscoPorEntradaPct());
   lote = LimitarLotePorMargem(lote, compra, preco);
   if(lote <= 0) return;
   AjustarStops(compra, preco, sl, tp);
   bool ok;
   if(compra) ok = trade.Buy (lote, _Symbol, 0.0, sl, tp, "MANUAL BUY");
   else       ok = trade.Sell(lote, _Symbol, 0.0, sl, tp, "MANUAL SELL");
   if(ok) gEntradasHoje++;
   else   Print("[ERRO] Manual falhou: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
}

//======================= EVENTOS ===================================
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpSlippage);
   trade.SetTypeFillingBySymbol(_Symbol);

   hATR = iATR(_Symbol, InpTFSinal, InpATRPeriodo);
   if(hATR == INVALID_HANDLE)
   {
      Print("[ERRO] Nao foi possivel criar o ATR");
      return INIT_FAILED;
   }

   gDiaAtual = -1;
   AtualizarDia();
   DetectarPadroes();
   DesenharPadrao();
   AtualizarPainel();
   Print("Robo FenixTrader v2.20 iniciado | AUTO ", (InpEntradasAutomaticas ? "LIGADO" : "DESLIGADO"),
          " | Entrada no D ", (InpEntrarAoFecharFigura ? "LIGADA" : "DESLIGADA"), " | Stop diario ", InpStopDiarioPct,
         "% | Meta diaria ", InpAlvoDiarioPct, "% | Entradas/dia ", InpMaxEntradasDia,
         " | Breakeven ", (InpMoverBreakeven ? "ON" : "OFF"));
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, PFX);
   if(hATR != INVALID_HANDLE) IndicatorRelease(hATR);
   ChartRedraw();
}

void OnTick()
{
   AtualizarDia();
   ChecarLimitesDiarios();

   // Reavalia as figuras continuamente (nao espera a vela fechar), assim o
   // ponto D e reconhecido no instante do sinal e a ordem sai na hora.
   datetime barra = iTime(_Symbol, InpTFSinal, 0);
   datetime agora = TimeCurrent();
   bool novaBarra = (barra != gUltimaBarraSinal);
   bool naHora    = (InpScanSegundos <= 0) || (agora - gUltimoScan >= InpScanSegundos);
   if(novaBarra || naHora)
   {
      gUltimaBarraSinal = barra;
      gUltimoScan       = agora;
      DetectarPadroes();            // sempre procura e desenha as figuras
      DesenharPadrao();
      TentarEntrada();              // entra imediatamente ao detectar o ponto D
   }
   TentarEntrada();                 // rede de seguranca (respeita PRZ e limites)
   GerenciarParcial();              // parcial no 1:1 + stop no zero a zero
   GerenciarBreakeven();            // protege posicoes que andaram a favor
   AtualizarPainel();
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id != CHARTEVENT_OBJECT_CLICK) return;

   if(sparam == PFX + "bBuy")    { AbrirManual(true);  }
   if(sparam == PFX + "bSell")   { AbrirManual(false); }
   if(sparam == PFX + "bCloseS") { FecharTodasEA(true);  }
   if(sparam == PFX + "bCloseA") { FecharTodasEA(false); }

   ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
   AtualizarPainel();
}
//+------------------------------------------------------------------+
