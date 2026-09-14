//+------------------------------------------------------------------+
//|                 Robo_FenixTrader_2.1_Entrada_Automatica_D.mq5     |
//|   EA de Padroes Harmonicos (XABCD) - Gartley / Morcego /          |
//|   Borboleta / Caranguejo / Tubarao                                |
//|   Gestao diaria: STOP 1% | ALVO 2% | ate 2 entradas por dia       |
//|   Referencia de proporcoes: LiteFinance - Padroes Harmonicos      |
//+------------------------------------------------------------------+
//| v2.50 - Gestao por operacao definida pelo usuario:                |
//|  - Risco fixo de 1.00% e alvo de 2.00% por operacao (RR 1:2)      |
//|  - Mantem stop diario 2%, meta diaria 4%, 3 entradas/dia e        |
//|    apenas 1 posicao aberta por vez                                |
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
//| v3.20 - FIGURA TRAVADA E FIBONACCI ESTRITO                        |
//|  - O ponto D NUNCA usa a vela em formacao: so pivo confirmado     |
//|  - Deteccao roda apenas quando fecha a vela do timeframe do sinal |
//|  - Proporcoes Fibonacci estritas (tolerancia 0.05) e projecao CD  |
//|    obrigatoria: a figura para de "andar" junto com o preco        |
//|  - Padrao generico desligado (somente Gartley/Morcego/Borboleta/  |
//|    Caranguejo/Tubarao com Fibonacci valido)                       |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| v4.00 - PRECISAO CIRURGICA NO PONTO D                             |
//|  Reestruturacao completa da logica de ENTRADA e RISCO:            |
//|  1) Entrada SOMENTE no ponto D estrutural confirmado, com o preco |
//|     ainda DENTRO da zona de reversao (PRZ). Se o preco ja se      |
//|     afastou (InpMaxDistPRZ_ATR x ATR), o sinal e descartado.      |
//|  2) Filtro de gatilho no D com 3 confirmacoes independentes:      |
//|     - Pin Bar / rejeicao de preco na zona                        |
//|     - Divergencia de RSI no tempo grafico menor                   |
//|     - Exaustao de volume (clima de fluxo)                         |
//|     Exija 1, 2 ou 3 confirmacoes em InpMinConfirmacoes.           |
//|  3) Stop tecnico OBRIGATORIO atras do extremo do ponto X ou do    |
//|     pivo anterior (o que estiver mais protegido) + folga ATR.     |
//|  4) Take profit dinamico com RR minimo 1:2 e parciais nos niveis  |
//|     de Fibonacci do impulso CD (38.2% e 61.8%) + zero a zero.     |
//|  5) Execucao no fechamento do candle de referencia (sem ruido de  |
//|     processamento tick a tick).                                   |
//|  AJUSTE DE SENSIBILIDADE POR ATIVO: veja o grupo                  |
//|  "=== GATILHO CIRURGICO NO PONTO D ===" (distancia da PRZ, pavio  |
//|  do pin bar, RSI e volume) e "InpTolerancia" nos harmonicos.      |
//+------------------------------------------------------------------+
#property copyright "Robo Gartley Harmonico"
#property version   "4.00"

#include <Trade\Trade.mqh>

//======================= ENTRADAS ==================================
input group "=== PADROES HARMONICOS ==="
input ENUM_TIMEFRAMES InpTFSinal        = PERIOD_M30;  // Timeframe do sinal (padrao)
input int    InpFractalDepth            = 2;           // Profundidade do pivo (velas de cada lado)
input int    InpBarrasBusca             = 600;         // Barras analisadas para achar XABCD
input double InpTolerancia              = 0.05;        // Tolerancia dos niveis Fibonacci (estrito 0.05)
input int    InpMaxPivos                = 40;          // Quantidade de pivos analisados
input bool   InpUsarFiltroCD            = true;        // Exigir projecao CD dentro da faixa Fibonacci
input bool   InpAceitarGenerico         = false;       // Aceitar padrao harmonico generico (ABCD)
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
input double InpStopDiarioPct           = 1.0;         // Stop maximo diario (%)
input double InpAlvoDiarioPct           = 2.0;         // Alvo maximo diario (%)
input int    InpMaxEntradasDia          = 2;           // Maximo de entradas por dia (1 a 3)
input int    InpMaxPosicoesAbertas      = 1;           // Maximo de posicoes abertas ao mesmo tempo
input double InpRRMinimo                = 1.2;         // Razao risco/retorno minima aceita
input bool   InpUsarRiscoFixo           = true;        // Usar risco/alvo fixos por operacao (abaixo)
input double InpRiscoPorEntradaPct      = 0.50;        // Stop por operacao (% do saldo)
input double InpAlvoPorEntradaPct       = 1.00;        // Take profit por operacao (% do saldo)

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
input bool   InpDNaVelaAtual            = false;       // NAO usar a vela em formacao: ponto D fixo (pivo confirmado)
input int    InpScanSegundos            = 0;           // (nao usado na v3.20: analise so no fechamento da vela)

input group "=== ROMPIMENTO COMO ESTRATEGIA SEPARADA (DESLIGADO NA v3.10) ==="
input bool   InpUsarORB                 = false;       // DESLIGADO: o rompimento agora e apenas confirmacao (fusao)
input ENUM_TIMEFRAMES InpTFSinalORB     = PERIOD_M30;  // Timeframe do sinal de rompimento
input int    InpORBLookback             = 6;           // Barras do range analisado
input double InpORBFatorRompimento      = 0.15;        // Margem minima de rompimento (% do range)
input double InpORBForcaCorpoMin        = 0.65;        // Forca minima do corpo da vela (0-1)
input bool   InpORBFiltroEMA            = true;        // Filtro de tendencia EMA
input int    InpORBEmaPeriodo           = 200;         // Periodo da EMA de tendencia
input double InpORBStopATRMult          = 1.5;         // Stop do rompimento (x ATR)
input bool   InpPrioridadeHarmonico     = true;        // Harmonico tem prioridade sobre o rompimento

input group "=== FUSAO: HARMONICO CONFIRMADO POR FORCA/ROMPIMENTO ==="
input bool   InpUsarFusao                = true;        // Exigir confirmacao de forca/rompimento no ponto D
input double InpFusaoCorpoMin            = 0.45;        // Forca minima do corpo da vela de confirmacao (0-1)
input int    InpFusaoLookback            = 3;           // Barras do micro-range para o rompimento de gatilho
input bool   InpFusaoExigirRompimento    = true;        // Exigir rompimento do micro-range na direcao do padrao
input bool   InpFusaoFiltroEMA           = false;       // Exigir preco a favor da EMA rapida
input int    InpFusaoEmaPeriodo          = 50;          // Periodo da EMA rapida da fusao

input group "=== GATILHO CIRURGICO NO PONTO D ==="
// ---- AJUSTE DE SENSIBILIDADE POR ATIVO: comece por estes parametros ----
input bool   InpGatilhoCirurgico          = true;        // Exigir gatilho cirurgico no ponto D
input double InpMaxDistPRZ_ATR            = 0.60;        // Distancia MAXIMA do preco ao ponto D (x ATR) - menor = mais cirurgico
input int    InpMinConfirmacoes           = 1;           // Confirmacoes minimas exigidas (1 a 3)
input bool   InpUsarPinBar                = true;        // Confirmacao 1: rejeicao de preco (pin bar) na zona
input double InpPinBarPavioMin            = 0.50;        // Pavio de rejeicao minimo (fracao do range da vela)
input double InpPinBarCorpoMax            = 0.45;        // Corpo maximo da vela de rejeicao (fracao do range)
input bool   InpUsarRSIDiv                = true;        // Confirmacao 2: divergencia de RSI no tempo menor
input ENUM_TIMEFRAMES InpTFGatilho        = PERIOD_M5;   // Tempo grafico menor do gatilho
input int    InpRSIPeriodo                = 14;          // Periodo do RSI
input int    InpDivLookback               = 12;          // Barras analisadas na divergencia
input bool   InpUsarExaustaoVolume        = true;        // Confirmacao 3: exaustao de volume/fluxo
input int    InpVolMedia                  = 20;          // Barras da media de volume
input double InpVolFator                  = 1.20;        // Volume da vela do D / media (climax)

input group "=== ALVOS DINAMICOS (RR 1:2 + PARCIAIS FIBONACCI) ==="
input double InpRRObrigatorio             = 2.0;         // Risco/Retorno minimo obrigatorio do alvo final
input bool   InpParciaisFibonacci         = true;        // Fracionar parciais nos Fibos do impulso CD
input double InpFibParcial1               = 38.2;        // Nivel 1 do impulso CD (%) - parcial 1
input double InpFibParcial2               = 61.8;        // Nivel 2 do impulso CD (%) - parcial 2
input double InpPercFibParcial1           = 40.0;        // Volume fechado na parcial 1 (%)
input double InpPercFibParcial2           = 30.0;        // Volume fechado na parcial 2 (%)

//======================= GLOBAIS ===================================
CTrade   trade;
int      hATR = INVALID_HANDLE;
int      hEMA_ORB = INVALID_HANDLE;
int      hEMA_FUS = INVALID_HANDLE;
datetime gUltimaBarraORB = 0;
string   gUltimoSinalTexto = "";

double   gSaldoInicioDia = 0.0;
int      gDiaAtual       = -1;
int      gEntradasHoje   = 0;
bool     gBloqueadoDia   = false;
string   gMotivoBloqueio = "";
datetime gUltimaBarraSinal = 0;
datetime gUltimoScan       = 0;

string   PFX = "GH_";

//--- v4.00: handles e memoria dos alvos parciais Fibonacci
int      hRSI = INVALID_HANDLE;
double   gAlvoFib1 = 0.0;      // nivel 38.2% do impulso CD (parcial 1)
double   gAlvoFib2 = 0.0;      // nivel 61.8% do impulso CD (parcial 2)

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
      if(PositionGetInteger(POSITION_MAGIC) == (long)InpMagic &&
         PositionGetString(POSITION_SYMBOL) == _Symbol) n++;
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
      if(HistoryDealGetString(t, DEAL_SYMBOL) != _Symbol) continue;
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
      if(HistoryDealGetString(t, DEAL_SYMBOL) != _Symbol) continue;
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
   // v3.20: com InpDNaVelaAtual = false o scan comeca depois das velas de
   // confirmacao do fractal (i = d + 1). O pivo D so entra na figura quando
   // esta confirmado por velas fechadas dos dois lados -> a figura nao muda.
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
   // v3.20: tolerancia estrita aplicada a todos os niveis Fibonacci
   double tol = MathMin(0.08, MathMax(0.01, InpTolerancia));
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

//============ v4.00 - GATILHO CIRURGICO NO PONTO D =================
// Cada funcao abaixo e uma confirmacao INDEPENDENTE. O robo soma quantas
// confirmaram e compara com InpMinConfirmacoes. Para deixar o robo mais
// cirurgico, aumente InpMinConfirmacoes; para mais sinais, reduza para 1.

// CONFIRMACAO 1 - Pin Bar / rejeicao de preco: a vela de referencia precisa
// ter pavio longo do lado contrario ao trade (o preco testou a zona e foi
// rejeitado) e corpo pequeno.
bool ConfPinBar(const bool compra)
{
   double o = iOpen (_Symbol, InpTFSinal, 1);
   double c = iClose(_Symbol, InpTFSinal, 1);
   double h = iHigh (_Symbol, InpTFSinal, 1);
   double l = iLow  (_Symbol, InpTFSinal, 1);
   double range = h - l;
   if(range <= 0) return false;

   double corpo      = MathAbs(c - o) / range;
   double pavioBaixo = (MathMin(o, c) - l) / range;   // rejeicao de fundo
   double pavioAlto  = (h - MathMax(o, c)) / range;   // rejeicao de topo
   if(corpo > InpPinBarCorpoMax) return false;

   return compra ? (pavioBaixo >= InpPinBarPavioMin)
                 : (pavioAlto  >= InpPinBarPavioMin);
}

// CONFIRMACAO 2 - Divergencia de RSI no tempo grafico menor:
// compra -> preco faz fundo mais baixo e o RSI faz fundo mais alto;
// venda  -> preco faz topo mais alto e o RSI faz topo mais baixo.
bool ConfDivergenciaRSI(const bool compra)
{
   if(hRSI == INVALID_HANDLE) return false;
   int n = MathMax(4, InpDivLookback);

   double rsi[];
   ArraySetAsSeries(rsi, true);
   if(CopyBuffer(hRSI, 0, 0, n + 2, rsi) < n + 2) return false;

   int    idxExtremo = 1;
   double extremo    = compra ? iLow(_Symbol, InpTFGatilho, 1)
                              : iHigh(_Symbol, InpTFGatilho, 1);
   int    idxAnterior = -1;
   double anterior    = 0.0;

   // procura o extremo anterior de preco na janela analisada
   for(int i = 2; i <= n; i++)
   {
      double v = compra ? iLow(_Symbol, InpTFGatilho, i)
                        : iHigh(_Symbol, InpTFGatilho, i);
      if(idxAnterior < 0 || (compra ? (v < anterior) : (v > anterior)))
      {
         anterior    = v;
         idxAnterior = i;
      }
   }
   if(idxAnterior < 0) return false;

   bool precoRompeu = compra ? (extremo <= anterior) : (extremo >= anterior);
   bool rsiDiverge  = compra ? (rsi[idxExtremo] > rsi[idxAnterior])
                             : (rsi[idxExtremo] < rsi[idxAnterior]);
   bool zonaOk      = compra ? (rsi[idxExtremo] < 50.0) : (rsi[idxExtremo] > 50.0);

   return (precoRompeu && rsiDiverge && zonaOk);
}

// CONFIRMACAO 3 - Exaustao de volume/fluxo: volume da vela do ponto D acima
// da media (climax de venda no fundo / de compra no topo).
bool ConfExaustaoVolume()
{
   int n = MathMax(3, InpVolMedia);
   long soma = 0;
   for(int i = 2; i <= n + 1; i++) soma += iTickVolume(_Symbol, InpTFSinal, i);
   if(soma <= 0) return false;
   double media = (double)soma / (double)n;
   long   volD  = iTickVolume(_Symbol, InpTFSinal, 1);
   return ((double)volD >= media * InpVolFator);
}

// Valida o ponto D: preco AINDA na zona de reversao + confirmacoes de gatilho.
// Nenhuma entrada antecipada (padrao nao fechado) nem atrasada (preco longe).
bool GatilhoCirurgicoOk(const Harmonico &p)
{
   if(!InpGatilhoCirurgico) return true;

   double atr = ATRVal();
   if(atr <= 0) atr = 20 * _Point;

   // 1) o preco precisa estar dentro da zona do ponto D
   double refPreco = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double limite   = atr * MathMax(0.05, InpMaxDistPRZ_ATR);
   double dist     = MathAbs(refPreco - p.D);
   if(dist > limite)
   {
      if(InpLogDiagnostico)
         PrintFormat("[GATILHO] %s descartado: preco a %.*f do ponto D (limite %.*f) - entrada tardia evitada",
                     p.nome, _Digits, dist, _Digits, limite);
      return false;
   }

   // 2) confirmacoes independentes
   int    conf   = 0;
   string quais  = "";
   if(InpUsarPinBar          && ConfPinBar(p.compra))   { conf++; quais += "PinBar "; }
   if(InpUsarRSIDiv          && ConfDivergenciaRSI(p.compra)) { conf++; quais += "RSI-Div "; }
   if(InpUsarExaustaoVolume  && ConfExaustaoVolume())   { conf++; quais += "Volume "; }

   int minimo = MathMax(1, MathMin(3, InpMinConfirmacoes));
   if(conf < minimo)
   {
      if(InpLogDiagnostico)
         PrintFormat("[GATILHO] %s aguardando: %d de %d confirmacoes no ponto D (%s)",
                     p.nome, conf, minimo, (quais == "" ? "nenhuma" : quais));
      return false;
   }

   if(InpLogDiagnostico)
      PrintFormat("[GATILHO] %s VALIDADO no ponto D com %d confirmacao(oes): %s",
                  p.nome, conf, quais);
   return true;
}

// Stop tecnico: sempre atras do extremo estrutural do ponto X OU do pivo
// anterior mais protetivo, com folga de ATR para ruido de spread/mecha.
double StopTecnico(const Harmonico &p, const double folga)
{
   double extremo = p.compra ? MathMin(p.D, p.X) : MathMax(p.D, p.X);

   // pivo anterior (mais recente antes do D) como protecao adicional
   for(int i = 0; i < gQtdPivos; i++)
   {
      if(gPvTempo[i] >= p.tD) continue;
      if(p.compra && gPvTipo[i] < 0 && gPvPreco[i] < extremo) extremo = gPvPreco[i];
      if(!p.compra && gPvTipo[i] > 0 && gPvPreco[i] > extremo) extremo = gPvPreco[i];
      break;   // apenas o pivo imediatamente anterior
   }
   return p.compra ? extremo - folga : extremo + folga;
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
   if(PosicoesEA() >= InpMaxPosicoesAbertas)
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

   // FUSAO: o gatilho de rompimento/forca precisa concordar com o padrao
   if(!ConfirmacaoFusao(p.compra)) return;

   // v4.00: gatilho cirurgico no ponto D (zona + pin bar / RSI / volume)
   if(!GatilhoCirurgicoOk(p)) return;

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

   // v4.00 - STOP TECNICO: atras do extremo do X ou do pivo anterior + folga ATR
   double sl = StopTecnico(p, folga);
   double dist = MathAbs(preco - sl);
   if(dist <= 0)
   {
      if(InpLogDiagnostico) Print("[AUTO] Entrada cancelada: distancia do stop invalida.");
      return;
   }

   // v4.00 - ALVO DINAMICO: RR minimo obrigatorio 1:2 sobre o stop tecnico
   double riscoPct = RiscoPorEntradaPct();
   double alvoPct  = AlvoPorEntradaPct();
   double rrGestao = alvoPct / MathMax(0.01, riscoPct);
   double rrAlvo   = MathMax(InpRRObrigatorio, rrGestao);   // nunca abaixo de 1:2
   double tp = p.compra ? preco + dist * rrAlvo : preco - dist * rrAlvo;

   // Parciais nos niveis de Fibonacci do impulso CD (38.2% e 61.8%)
   double CD = MathAbs(p.C - p.D);
   gAlvoFib1 = 0.0; gAlvoFib2 = 0.0;
   if(InpParciaisFibonacci && CD > 0)
   {
      gAlvoFib1 = p.compra ? p.D + CD * (InpFibParcial1 / 100.0)
                           : p.D - CD * (InpFibParcial1 / 100.0);
      gAlvoFib2 = p.compra ? p.D + CD * (InpFibParcial2 / 100.0)
                           : p.D - CD * (InpFibParcial2 / 100.0);
   }
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
   if(lote <= 0)
   {
      Print("[AUTO] Entrada cancelada: lote invalido apos ajuste de stops.");
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

//======= v4.00 - PARCIAIS FIBONACCI (38.2% / 61.8% do CD) + ZERO A ZERO =====
// Parcial 1 no primeiro nivel de Fibonacci do impulso CD (ou no 1:1 caso as
// parciais Fibonacci estejam desligadas): fecha InpPercFibParcial1 do volume
// e joga o stop para o preco de entrada (zero a zero).
// Parcial 2 no segundo nivel: fecha InpPercFibParcial2 do que restou.
// O saldo restante segue para o alvo final (RR 1:2 ou melhor).
ulong gParcial2Feita[64];
int   gQtdParcial2 = 0;

bool Parcial2JaFeita(ulong tk)
{
   for(int i = 0; i < gQtdParcial2; i++)
      if(gParcial2Feita[i] == tk) return true;
   return false;
}

void MarcarParcial2(ulong tk)
{
   if(gQtdParcial2 < 64) gParcial2Feita[gQtdParcial2++] = tk;
   else { gParcial2Feita[0] = tk; gQtdParcial2 = 1; }
}

// fecha o percentual pedido respeitando lote minimo e passo da corretora
bool FecharPercentual(ulong tk, double vol, double perc, string etiqueta)
{
   double loteMin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double passo   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(passo <= 0) passo = loteMin;

   double fechar = vol * perc / 100.0;
   fechar = MathFloor(fechar / passo) * passo;
   fechar = NormalizeDouble(fechar, DigitosLote());
   if(fechar < loteMin || (vol - fechar) < loteMin) return false;

   if(trade.PositionClosePartial(tk, fechar))
   {
      PrintFormat("[%s] Ticket %I64u: fechado %.*f de %.*f",
                  etiqueta, tk, DigitosLote(), fechar, DigitosLote(), vol);
      return true;
   }
   return false;
}

void GerenciarParcial()
{
   if(!InpSaidaParcial) return;

   int dig = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(!PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      long   tipo = PositionGetInteger(POSITION_TYPE);
      bool   compra = (tipo == POSITION_TYPE_BUY);
      double ab   = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl   = PositionGetDouble(POSITION_SL);
      double tp   = PositionGetDouble(POSITION_TP);
      double vol  = PositionGetDouble(POSITION_VOLUME);
      if(sl == 0.0) continue;

      double risco = MathAbs(ab - sl);
      if(risco <= 0) continue;

      double atual = compra ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                            : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      // ---- niveis de gatilho das parciais ----
      double nivel1 = (InpParciaisFibonacci && gAlvoFib1 != 0.0)
                      ? gAlvoFib1
                      : (compra ? ab + risco * InpGatilhoParcial : ab - risco * InpGatilhoParcial);
      double nivel2 = (InpParciaisFibonacci && gAlvoFib2 != 0.0) ? gAlvoFib2 : 0.0;

      bool bateu1 = compra ? (atual >= nivel1) : (atual <= nivel1);
      bool bateu2 = (nivel2 != 0.0) && (compra ? (atual >= nivel2) : (atual <= nivel2));

      // ---- PARCIAL 1 + ZERO A ZERO ----
      if(!ParcialJaFeita(tk) && bateu1)
      {
         double perc1 = InpParciaisFibonacci ? InpPercFibParcial1 : InpPercentualParcial;
         FecharPercentual(tk, vol, perc1, "PARCIAL 1 FIB");

         if(PositionSelectByTicket(tk))
         {
            double novoSL = NormalizeDouble(ab, dig);
            bool precisa = compra ? (sl < novoSL) : (sl > novoSL);
            if(precisa && trade.PositionModify(tk, novoSL, tp))
               PrintFormat("[ZERO A ZERO] Ticket %I64u: stop na entrada %.*f", tk, dig, novoSL);
         }
         MarcarParcial(tk);
         continue;
      }

      // ---- PARCIAL 2 (segundo nivel de Fibonacci do CD) ----
      if(InpParciaisFibonacci && ParcialJaFeita(tk) && !Parcial2JaFeita(tk) && bateu2)
      {
         FecharPercentual(tk, vol, InpPercFibParcial2, "PARCIAL 2 FIB");
         MarcarParcial2(tk);
      }
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

   Lbl("t0", x, y,      "ROBO FENIX HIBRIDO v3.00 (HARMONICO + ROMPIMENTO)", clrGold, 11);
   Lbl("t1", x, y - 20, "Sinal: " + EnumToString(InpTFSinal) + "  |  Grafico: " + EnumToString((ENUM_TIMEFRAMES)Period()) +
       "  |  Spread: " + (string)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) + " pts", clrSkyBlue);
   Lbl("t2", x, y - 38, "Estrategia unica FUSAO " + (InpEntradasAutomaticas ? "ON" : "OFF") + "  |  Gatilho " + (InpUsarFusao ? "ROMPIMENTO+FORCA" : "SO PADRAO") + "  |  Padrao: " + (gPad.valido ? gPad.nome + (gPad.compra ? " (COMPRA)" : " (VENDA)") : "procurando..."),
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
   if(PosicoesEA() >= InpMaxPosicoesAbertas)
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
   if(lote <= 0) return;
   AjustarStops(compra, preco, sl, tp);
   bool ok;
   if(compra) ok = trade.Buy (lote, _Symbol, 0.0, sl, tp, "MANUAL BUY");
   else       ok = trade.Sell(lote, _Symbol, 0.0, sl, tp, "MANUAL SELL");
   if(ok) gEntradasHoje++;
   else   Print("[ERRO] Manual falhou: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
}

//=============== ESTRATEGIA 2: ROMPIMENTO DE RANGE (ORB) ===========
// Logica herdada do Robo Fenix XAUUSD v7.8: rompimento confirmado pelo
// fechamento da vela do timeframe do sinal, com corpo forte e filtro EMA.
int VerificarSinalORB()
{
   if(!InpUsarORB) return 0;

   double maiorHigh = iHigh(_Symbol, InpTFSinalORB, 2);
   double menorLow  = iLow (_Symbol, InpTFSinalORB, 2);
   for(int i = 3; i <= InpORBLookback + 2; i++)
   {
      double h = iHigh(_Symbol, InpTFSinalORB, i);
      double l = iLow (_Symbol, InpTFSinalORB, i);
      if(h > maiorHigh) maiorHigh = h;
      if(l < menorLow)  menorLow  = l;
   }
   double range = maiorHigh - menorLow;
   if(range <= 0) return 0;

   double open1  = iOpen (_Symbol, InpTFSinalORB, 1);
   double close1 = iClose(_Symbol, InpTFSinalORB, 1);
   double high1  = iHigh (_Symbol, InpTFSinalORB, 1);
   double low1   = iLow  (_Symbol, InpTFSinalORB, 1);
   double amp = high1 - low1;
   if(amp <= 0) return 0;

   double forca = MathAbs(close1 - open1) / amp;
   if(forca < InpORBForcaCorpoMin) return 0;

   double margem = range * InpORBFatorRompimento;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(close1 > maiorHigh + margem && close1 > open1 && bid > maiorHigh) return 1;
   if(close1 < menorLow  - margem && close1 < open1 && bid < menorLow)  return -1;
   return 0;
}

bool FiltroEMAOrb(int sinal)
{
   if(!InpORBFiltroEMA) return true;
   if(hEMA_ORB == INVALID_HANDLE) return true;
   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(hEMA_ORB, 0, 0, 2, buf) < 2) return false;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(sinal == 1  && bid < buf[0]) return false;
   if(sinal == -1 && bid > buf[0]) return false;
   return true;
}

//=============== FUSAO: CONFIRMACAO DE FORCA + ROMPIMENTO =========
// O padrao harmonico define ONDE operar (ponto D). O motor de rompimento
// define QUANDO: a vela precisa ter corpo forte na direcao do padrao e
// romper o micro-range das ultimas barras. Uma estrategia unica, cruzando
// as duas leituras.
bool ConfirmacaoFusao(bool compra)
{
   if(!InpUsarFusao) return true;

   double open1  = iOpen (_Symbol, InpTFSinal, 1);
   double close1 = iClose(_Symbol, InpTFSinal, 1);
   double high1  = iHigh (_Symbol, InpTFSinal, 1);
   double low1   = iLow  (_Symbol, InpTFSinal, 1);
   double faixa  = high1 - low1;
   if(faixa <= 0) return false;

   double forca = MathAbs(close1 - open1) / faixa;
   bool direcao = compra ? (close1 > open1) : (close1 < open1);
   if(!direcao || forca < InpFusaoCorpoMin)
   {
      if(InpLogDiagnostico)
         PrintFormat("[FUSAO] Aguardando forca: corpo %.2f (minimo %.2f) direcao %s",
                     forca, InpFusaoCorpoMin, (direcao ? "ok" : "contraria"));
      return false;
   }

   if(InpFusaoExigirRompimento)
   {
      int n = MathMax(1, InpFusaoLookback);
      double maiorHigh = iHigh(_Symbol, InpTFSinal, 2);
      double menorLow  = iLow (_Symbol, InpTFSinal, 2);
      for(int i = 3; i <= n + 2; i++)
      {
         double h = iHigh(_Symbol, InpTFSinal, i);
         double l = iLow (_Symbol, InpTFSinal, i);
         if(h > maiorHigh) maiorHigh = h;
         if(l < menorLow)  menorLow  = l;
      }
      if(compra && close1 <= maiorHigh)
      {
         if(InpLogDiagnostico) Print("[FUSAO] Aguardando rompimento do micro-range para compra.");
         return false;
      }
      if(!compra && close1 >= menorLow)
      {
         if(InpLogDiagnostico) Print("[FUSAO] Aguardando rompimento do micro-range para venda.");
         return false;
      }
   }

   if(InpFusaoFiltroEMA && hEMA_FUS != INVALID_HANDLE)
   {
      double buf[];
      ArraySetAsSeries(buf, true);
      if(CopyBuffer(hEMA_FUS, 0, 0, 2, buf) < 2) return false;
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(compra  && bid < buf[0]) return false;
      if(!compra && bid > buf[0]) return false;
   }

   return true;
}

void TentarEntradaORB()
{
   if(!InpUsarORB || !InpEntradasAutomaticas) return;
   if(gBloqueadoDia) return;
   if(gEntradasHoje >= InpMaxEntradasDia) return;
   if(PosicoesEA() >= InpMaxPosicoesAbertas) return;
   if(InpPrioridadeHarmonico && gPad.valido && gPad.tD != gSinalOperadoTD) return;

   // uma tentativa por vela do timeframe do rompimento
   datetime barra = iTime(_Symbol, InpTFSinalORB, 0);
   if(barra == gUltimaBarraORB) return;

   int sinal = VerificarSinalORB();
   if(sinal == 0) return;
   if(!FiltroEMAOrb(sinal)) return;
   if(!SpreadOk()) return;

   gUltimaBarraORB = barra;

   bool compra = (sinal == 1);
   double atr = ATRVal();
   double dist = (atr > 0 ? atr * InpORBStopATRMult : 200 * _Point);
   double preco = compra ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl = compra ? preco - dist : preco + dist;

   double riscoPct = RiscoPorEntradaPct();
   double rr = AlvoPorEntradaPct() / MathMax(0.01, riscoPct);
   double tp = compra ? preco + dist * rr : preco - dist * rr;

   AjustarStops(compra, preco, sl, tp);
   dist = MathAbs(preco - sl);
   double lote = CalcularLote(dist, riscoPct);
   if(lote <= 0) return;

   int dig = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   string com = "ROMPIMENTO " + (compra ? "BUY" : "SELL");
   bool enviado = compra ? trade.Buy (lote, _Symbol, 0.0, sl, tp, com)
                         : trade.Sell(lote, _Symbol, 0.0, sl, tp, com);
   uint ret = trade.ResultRetcode();
   if(enviado && (ret == TRADE_RETCODE_DONE || ret == TRADE_RETCODE_DONE_PARTIAL || ret == TRADE_RETCODE_PLACED))
   {
      gEntradasHoje++;
      gUltimoSinalTexto = "ROMPIMENTO " + (compra ? "COMPRA" : "VENDA");
      PrintFormat("[ENTRADA ROMPIMENTO %d/%d] %s | lote=%.*f SL=%.*f TP=%.*f risco=%.2f%%",
                  gEntradasHoje, InpMaxEntradasDia, compra ? "COMPRA" : "VENDA",
                  DigitosLote(), lote, dig, sl, dig, tp, riscoPct);
      Alert("ENTRADA POR ROMPIMENTO: ", compra ? "COMPRA" : "VENDA", " | ", _Symbol);
   }
   else
   {
      PrintFormat("[ERRO ORDEM ROMPIMENTO] retcode=%u | %s", ret, trade.ResultRetcodeDescription());
   }
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

   if(InpGatilhoCirurgico && InpUsarRSIDiv)
   {
      hRSI = iRSI(_Symbol, InpTFGatilho, InpRSIPeriodo, PRICE_CLOSE);
      if(hRSI == INVALID_HANDLE)
         Print("[AVISO] RSI do gatilho nao criado - confirmacao de divergencia sera ignorada");
   }

   if(InpUsarFusao && InpFusaoFiltroEMA)
   {
      hEMA_FUS = iMA(_Symbol, InpTFSinal, InpFusaoEmaPeriodo, 0, MODE_EMA, PRICE_CLOSE);
   }
   if(InpUsarORB && InpORBFiltroEMA)
   {
      hEMA_ORB = iMA(_Symbol, InpTFSinalORB, InpORBEmaPeriodo, 0, MODE_EMA, PRICE_CLOSE);
      if(hEMA_ORB == INVALID_HANDLE)
         Print("[AVISO] EMA do rompimento nao criada - filtro sera ignorado");
   }

   gDiaAtual = -1;
   AtualizarDia();
   DetectarPadroes();
   DesenharPadrao();
   AtualizarPainel();
   Print("Robo Fenix v4.00 - Precisao Cirurgica no Ponto D | AUTO ", (InpEntradasAutomaticas ? "LIGADO" : "DESLIGADO"),
          " | Entrada no D ", (InpEntrarAoFecharFigura ? "LIGADA" : "DESLIGADA"), " | Stop diario ", InpStopDiarioPct,
         "% | Meta diaria ", InpAlvoDiarioPct, "% | Entradas/dia ", InpMaxEntradasDia,
         " | Breakeven ", (InpMoverBreakeven ? "ON" : "OFF"));
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, PFX);
   if(hATR != INVALID_HANDLE) IndicatorRelease(hATR);
   if(hEMA_ORB != INVALID_HANDLE) IndicatorRelease(hEMA_ORB);
   if(hEMA_FUS != INVALID_HANDLE) IndicatorRelease(hEMA_FUS);
   if(hRSI != INVALID_HANDLE) IndicatorRelease(hRSI);
   ChartRedraw();
}

void OnTick()
{
   AtualizarDia();
   ChecarLimitesDiarios();

   // Reavalia as figuras continuamente (nao espera a vela fechar), assim o
   // ponto D e reconhecido no instante do sinal e a ordem sai na hora.
   // v3.20: as figuras sao recalculadas SOMENTE quando uma vela do timeframe
   // do sinal fecha. Assim o ponto D fica travado e nao muda de lugar a cada
   // tick / a cada movimento da vela em formacao.
   datetime barra = iTime(_Symbol, InpTFSinal, 0);
   bool novaBarra = (barra != gUltimaBarraSinal);
   if(novaBarra)
   {
      gUltimaBarraSinal = barra;
      gUltimoScan       = TimeCurrent();
      DetectarPadroes();            // procura e desenha as figuras (vela fechada)
      DesenharPadrao();
      TentarEntrada();              // entrada no ponto D confirmado
   }
   TentarEntradaORB();              // so roda se InpUsarORB for ligado manualmente
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
