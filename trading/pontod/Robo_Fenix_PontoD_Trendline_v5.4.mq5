// v5.40: confirmacoes do ponto D lidas na vela do D (pin bar, volume, RSI e
// divergencia M5) em vez da vela de rompimento; alerta de FIGURA separado do
// alerta de ENTRADA/RECUSA; orcamento diario reduz o risco em vez de travar.
// v5.30: entradas confirmadas com repeticao limitada, diagnostico visivel,
// risco previsto USD500/alvo bruto USD1000 por operacao; limites diarios
// compartilhados por conta+magic. Nao e opcao binaria e nao garante lucro.
// Compilacao MetaEditor e execucao na corretora precisam de validacao externa.
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
//| v4.50 - FUSAO UNICA: HARMONICO (PONTO D) + ROMPIMENTO/FORCA      |
//|  - Um robo unico: a figura harmonica define ONDE (ponto D) e a   |
//|    leitura de rompimento/forca define QUANDO (confirmacao)       |
//|  - Entrada exatamente no ponto D, no fechamento da vela do sinal |
//|  - Gestao: 0.10% de perda e 0.20% de alvo por operacao           |
//|  - Dia: stop 0.20% | meta 0.40% | 2 entradas | 1 posicao         |
//|  - Sem parcial e sem zero a zero: trade normal ate alvo ou stop  |
//+------------------------------------------------------------------+
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
#property version   "5.30"

#include <Trade\Trade.mqh>

//======================= ENTRADAS ==================================
input group "=== v5.0 ESTRATEGIA 2: LINHAS DE TENDENCIA (AutoTrendline) ==="
input bool   InpUsarTrendline           = true;        // Entrar tambem no rompimento de LTA/LTB
input int    InpTLSwing                 = 6;           // Sensibilidade do pivo (velas de cada lado)
input int    InpTLHistorico             = 500;         // Velas analisadas para as linhas
input int    InpTLDistMinPontos         = 10;          // Fechamento minimo alem da linha (pontos)
input int    InpTLStopBarras            = 10;          // Stop no topo/fundo das ultimas N velas
input double InpTLFolgaATR              = 0.30;        // Folga do stop alem do topo/fundo (x ATR)
input double InpTLRR                    = 2.0;         // Alvo = N x o stop
input double InpTLCorpoMin              = 0.40;        // Corpo minimo da vela de rompimento (0-1)

input group "=== PADROES HARMONICOS ==="
input ENUM_TIMEFRAMES InpTFSinal        = PERIOD_H1;  // Timeframe do sinal (padrao)
input int    InpFractalDepth            = 2;           // Profundidade do pivo (velas de cada lado)
input int    InpBarrasBusca             = 1000;         // Barras analisadas para achar XABCD
input double InpTolerancia              = 0.15;        // Tolerancia dos niveis Fibonacci (estrito 0.05)
input int    InpMaxPivos                = 60;          // Quantidade de pivos analisados
input bool   InpUsarFiltroCD            = false;        // Exigir projecao CD dentro da faixa Fibonacci
input bool   InpAceitarGenerico         = true;       // Aceitar padrao harmonico generico (ABCD)
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
input bool   InpGestaoEmDolares         = true;         // Gestao em DOLARES (true) ou percentual (false)
input double InpStopDiarioUSD           = 500.0;         // Stop maximo diario (US$)
input double InpAlvoDiarioUSD           = 1000.0;         // Alvo maximo diario (US$)
input double InpStopDiarioPct           = 0.20;         // Stop maximo diario (%) - usado se dolares=false
input double InpAlvoDiarioPct           = 0.40;         // Alvo maximo diario (%) - usado se dolares=false
input int    InpMaxEntradasDia          = 10;          // Maximo de entradas por dia
input int    InpDivisorRisco            = 2;           // Legado: divisor usado somente no modo percentual sem risco fixo
input int    InpMaxPosicoesAbertas      = 1;           // Maximo de posicoes abertas ao mesmo tempo
input double InpRRMinimo                = 1.2;         // Razao risco/retorno minima aceita
input bool   InpUsarRiscoFixo           = true;        // Usar risco/alvo fixos por operacao (abaixo)
input double InpRiscoPorEntradaPct      = 0.10;        // Stop por operacao (% do saldo)
input double InpAlvoPorEntradaPct       = 0.20;        // Take profit por operacao (% do saldo)

input group "=== VALORES POR OPERACAO v5.4 ==="
input double InpRiscoPorEntradaUSD = 500.0;    // Perda bruta prevista no SL (custos/gaps podem ultrapassar)
input double InpAlvoPorEntradaUSD  = 1000.0;   // Lucro bruto planejado no TP
input int    InpRepetirSegundos    = 3;        // Intervalo das tentativas enquanto o sinal e recente
input int    InpValidadeSinalSeg   = 300;      // Nao perseguir o sinal depois desta janela (segundos)
input int    InpMaxIdadeD          = 12;       // Maximo de velas fechadas desde o D para operar a figura
input double InpRiscoMinFracao     = 0.50;     // Se o limite do dia ja foi usado em parte: entra com risco reduzido ate esta fracao (0 = nunca)
input bool   InpAlertaEntrada      = true;     // Alerta quando ENVIAR ordem ou quando um sinal for RECUSADO

input group "=== EXECUCAO ==="
input double InpFolgaStopATR            = 0.7;         // Folga do stop (x ATR) alem do ponto X
input int    InpATRPeriodo              = 14;          // Periodo do ATR
input int    InpSlippage                = 30;          // Desvio maximo (pontos)
input ulong  InpMagic                   = 20260902;    // Numero magico
input bool   InpFecharTudoNaMeta        = true;        // Fechar posicoes ao bater meta/stop diario
input bool   InpUsarSpreadMaximo        = true;        // Bloquear entrada com spread alto
input int    InpSpreadMaximoPontos      = 80;          // Spread maximo permitido (pontos)
input bool   InpPularEntradaLoteMinimo  = true;        // Nao entrar se o lote de risco < lote minimo
input bool   InpMoverBreakeven          = false;        // Mover stop para o breakeven
input double InpGatilhoBE               = 1.0;         // Gatilho do BE (x risco inicial a favor)
input double InpOffsetBE                = 0.1;         // Folga do BE alem da entrada (x risco)
input bool   InpSaidaParcial            = false;        // Realizar parcial e travar no zero a zero
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
input ENUM_TIMEFRAMES InpTFSinalORB     = PERIOD_H1;  // Timeframe do sinal de rompimento
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
input int    InpFusaoLookback            = 1;           // Barras do micro-range (1 = romper a maxima/minima da vela anterior)
input bool   InpFusaoExigirRompimento    = true;        // Exigir rompimento do micro-range na direcao do padrao
input bool   InpFusaoFiltroEMA           = false;       // Exigir preco a favor da EMA rapida
input int    InpFusaoEmaPeriodo          = 50;          // Periodo da EMA rapida da fusao

input group "=== GATILHO CIRURGICO NO PONTO D ==="
// ---- AJUSTE DE SENSIBILIDADE POR ATIVO: comece por estes parametros ----
input bool   InpGatilhoCirurgico          = true;        // Exigir gatilho cirurgico no ponto D
input double InpMaxDistPRZ_ATR            = 2.00;        // Distancia MAXIMA do preco ao ponto D (x ATR) - menor = mais cirurgico
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

input group "=== v4.7 FILTRO DE ALTA ASSERTIVIDADE ==="
input bool   InpFiltroQualidade           = true;        // Liga os filtros de qualidade abaixo
input bool   InpUsarRSIExtremo            = true;        // Exigir RSI H1 esticado no D (exaustao real)
input double InpRSICompraMax              = 45.0;        // Compra so com RSI do sinal abaixo de
input double InpRSIVendaMin               = 55.0;        // Venda so com RSI do sinal acima de
input bool   InpUsarFiltroADX             = true;        // Bloquear reversao contra tendencia forte
input int    InpADXPeriodo                = 14;          // Periodo do ADX
input double InpADXMax                    = 38.0;        // ADX maximo (acima = tendencia forte, harmonico falha)
input bool   InpUsarFiltroHorario         = true;        // Operar so no horario de liquidez
input int    InpHoraInicio                = 3;           // Hora inicial (horario do servidor)
input int    InpHoraFim                   = 21;          // Hora final (horario do servidor)
input bool   InpBloquearSexta             = true;        // Nao abrir entradas na sexta apos 16h

input group "=== ALVOS DINAMICOS (RR 1:2 + PARCIAIS FIBONACCI) ==="
input double InpRRObrigatorio             = 1.5;         // Risco/Retorno minimo obrigatorio do alvo final
input bool   InpParciaisFibonacci         = false;        // Fracionar parciais nos Fibos do impulso CD
input double InpFibParcial1               = 61.8;        // Nivel 1 do impulso CD (%) - parcial 1
input double InpFibParcial2               = 100.0;        // Nivel 2 do impulso CD (%) - parcial 2
input double InpPercFibParcial1           = 30.0;        // Volume fechado na parcial 1 (%)
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
string   gTLTexto = "procurando...";
string   gDiagnostico = "BUSCANDO FIGURA / ROMPIMENTO";
datetime gUltimaTentativa = 0;
datetime gTLSinalOperado = 0;
string   gChaveGestao = "";
string   gUltimaRecusa = "";
string   gIdRecusa = "";
// BEGIN_TESTABLE_RULES
// Regras usadas pelo EA e pelo teste C++ (nao simula MetaTrader).
double RiscoUSDRegra(bool usd, double valor, double base, double pct)
{ return usd ? valor : base * pct / 100.0; }
bool LimiteEntradasRegra(int usadas, int maximo)
{ return usadas >= maximo; }
double OrcamentoRegra(double realizado, double stopDia, double reservado)
{ return MathMax(0.0, stopDia + realizado - reservado); }
bool JanelaRegra(long agora, long abertura, int validade)
{ return abertura > 0 && agora >= abertura && agora - abertura <= validade; }
double VolumeRegra(double risco, double perdaLote, double minL, double maxL, double passo)
{
   if(risco <= 0 || perdaLote <= 0 || passo <= 0) return 0.0;
   double v = MathFloor(MathMin(maxL, risco / perdaLote) / passo + 1e-9) * passo;
   return v + 1e-9 < minL ? 0.0 : v;
}
double RiscoAjustadoRegra(double risco, double disponivel, double fracMin)
{
   if(risco <= 0) return 0.0;
   if(disponivel + 0.01 >= risco) return risco;
   if(fracMin <= 0 || disponivel < risco * fracMin) return 0.0;
   return disponivel;
}
// END_TESTABLE_RULES

void Motivo(string texto)
{
   if(texto != gDiagnostico && InpLogDiagnostico) Print("[DIAG] ", _Symbol, " | ", texto);
   gDiagnostico = texto;
}

// v5.4: avisa uma vez por sinal quando uma seta/figura confirmada NAO virou ordem.
void RegistrarRecusa(string origem, string id)
{
   if(gDiagnostico == "AGUARDANDO OUTRO ATIVO") return; // transitorio: tenta de novo em segundos
   string texto = origem + ": " + gDiagnostico;
   gUltimaRecusa = texto;
   if(id == gIdRecusa) return;
   gIdRecusa = id;
   PrintFormat("[RECUSA] %s %s | o robo tenta de novo por ate %d s enquanto o sinal for valido",
               _Symbol, texto, InpValidadeSinalSeg);
   if(InpAlertaEntrada) Alert("SINAL NAO EXECUTADO ", _Symbol, " - ", texto);
}

void AvisarEntrada(string origem, bool compra)
{
   gUltimaRecusa = "";
   if(InpAlertaEntrada) Alert("ENTRADA ENVIADA ", _Symbol, " ", origem, " ", compra ? "COMPRA" : "VENDA");
}

datetime InicioDia()
{
   MqlDateTime t; TimeToStruct(TimeCurrent(), t);
   t.hour=0; t.min=0; t.sec=0;
   return StructToTime(t);
}

bool HorarioOk()
{
   MqlDateTime t; TimeToStruct(TimeCurrent(), t);
   if(InpUsarFiltroHorario && InpHoraInicio != InpHoraFim)
   {
      bool ok = InpHoraInicio < InpHoraFim ? (t.hour >= InpHoraInicio && t.hour < InpHoraFim)
                                          : (t.hour >= InpHoraInicio || t.hour < InpHoraFim);
      if(!ok) { Motivo("FORA DO HORARIO (servidor)"); return false; }
   }
   if(InpBloquearSexta && t.day_of_week==5 && t.hour>=16)
   { Motivo("SEXTA APOS 16h (servidor)"); return false; }
   return true;
}

bool JanelaSinal()
{
   if(!JanelaRegra((long)TimeCurrent(), (long)iTime(_Symbol,InpTFSinal,0), InpValidadeSinalSeg))
   { Motivo("SINAL EXPIRADO - aguardando nova vela"); return false; }
   return true;
}

bool HistoricoDiaPronto()
{
   if(!HistorySelect(InicioDia(),TimeCurrent()+60))
   { Motivo("HISTORICO INDISPONIVEL - entrada bloqueada"); return false; }
   return true;
}


//--- v4.00: handles e memoria dos alvos parciais Fibonacci
int      hRSI = INVALID_HANDLE;
int      hRSI_SIN = INVALID_HANDLE;
int      hADX = INVALID_HANDLE;
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
   return gChaveGestao+"d_"+_Symbol+"_"+(string)InpTFSinal;
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
   datetime ini = InicioDia();
   if(!HistorySelect(ini, TimeCurrent() + 60)) return 0.0;
   double soma = 0.0;
   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong t = HistoryDealGetTicket(i);
      if(t == 0) continue;
      if(HistoryDealGetInteger(t, DEAL_MAGIC) != (long)InpMagic) continue;
      soma += HistoryDealGetDouble(t, DEAL_PROFIT)
            + HistoryDealGetDouble(t, DEAL_SWAP)
            + HistoryDealGetDouble(t, DEAL_COMMISSION)
            + HistoryDealGetDouble(t, DEAL_FEE);
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
   if(!HistorySelect(InicioDia(), TimeCurrent()+60)) return gEntradasHoje;
   ulong ordens[]; ArrayResize(ordens,0);
   for(int i=0; i<HistoryDealsTotal(); i++)
   {
      ulong t=HistoryDealGetTicket(i);
      if(t==0 || HistoryDealGetInteger(t,DEAL_MAGIC)!=(long)InpMagic) continue;
      long e=HistoryDealGetInteger(t,DEAL_ENTRY);
      if(e!=DEAL_ENTRY_IN && e!=DEAL_ENTRY_INOUT) continue;
      ulong o=(ulong)HistoryDealGetInteger(t,DEAL_ORDER);
      bool existe=false;
      for(int j=0;j<ArraySize(ordens);j++) if(ordens[j]==o) { existe=true; break; }
      if(!existe) { int n=ArraySize(ordens); ArrayResize(ordens,n+1); ordens[n]=o; }
   }
   return ArraySize(ordens);
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

//=================== v5.0 PONTOS CORRIDOS ==========================
// Soma dos pontos a favor/contra e do resultado em US$ das posicoes
// deste robo no ativo do grafico.
int PontosCorridos(double &pts, double &usd)
{
   pts = 0.0; usd = 0.0; int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(!PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      double ab = PositionGetDouble(POSITION_PRICE_OPEN);
      double at = PositionGetDouble(POSITION_PRICE_CURRENT);
      bool compra = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      pts += (compra ? at - ab : ab - at) / _Point;
      usd += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      n++;
   }
   return n;
}

// Etiqueta ao lado do preco, a direita da ultima vela
void EtiquetaPreco(int n, double pts, double usd)
{
   string nm = "FTL_preco";
   if(n <= 0) { ObjectDelete(0, nm); return; }
   datetime t = iTime(_Symbol, _Period, 0) + PeriodSeconds(_Period) * 3;
   double p = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ObjectFind(0, nm) < 0)
   {
      ObjectCreate(0, nm, OBJ_TEXT, 0, t, p);
      ObjectSetInteger(0, nm, OBJPROP_ANCHOR, ANCHOR_LEFT);
      ObjectSetInteger(0, nm, OBJPROP_FONTSIZE, 11);
      ObjectSetString (0, nm, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
   }
   ObjectMove(0, nm, 0, t, p);
   ObjectSetString(0, nm, OBJPROP_TEXT, (pts >= 0 ? "+" : "") + DoubleToString(pts, 0) + " pts  |  " +
                   (usd >= 0 ? "+US$ " : "-US$ ") + DoubleToString(MathAbs(usd), 2));
   ObjectSetInteger(0, nm, OBJPROP_COLOR, usd >= 0 ? clrLime : clrTomato);
}

//=================== v5.0 LINHAS DE TENDENCIA ======================
// Pivos confirmados (somente velas fechadas) no tempo do sinal.
bool TLPivo(int i, bool topo)
{
   double v = topo ? iHigh(_Symbol, InpTFSinal, i) : iLow(_Symbol, InpTFSinal, i);
   for(int k = 1; k <= InpTLSwing; k++)
   {
      if(topo)
      {
         if(iHigh(_Symbol, InpTFSinal, i - k) >= v || iHigh(_Symbol, InpTFSinal, i + k) > v) return false;
      }
      else
      {
         if(iLow(_Symbol, InpTFSinal, i - k) <= v || iLow(_Symbol, InpTFSinal, i + k) < v) return false;
      }
   }
   return true;
}

// Acha a linha mais recente: LTB (topos descendentes) ou LTA (fundos ascendentes)
// que nao foi cortada por fechamentos entre os dois pivos.
bool TLAcharLinha(bool resistencia, int &iA, double &pA, int &iB, double &pB)
{
   int barras = MathMin(InpTLHistorico, iBars(_Symbol, InpTFSinal) - InpTLSwing - 2);
   int idx[]; ArrayResize(idx, 0);
   for(int i = InpTLSwing + 2; i < barras && ArraySize(idx) < 12; i++)
      if(TLPivo(i, resistencia)) { int z = ArraySize(idx); ArrayResize(idx, z + 1); idx[z] = i; }
   int n = ArraySize(idx);
   for(int r = 0; r < n - 1; r++)
   {
      iB = idx[r];
      pB = resistencia ? iHigh(_Symbol, InpTFSinal, iB) : iLow(_Symbol, InpTFSinal, iB);
      for(int a = r + 1; a < n; a++)
      {
         iA = idx[a];
         pA = resistencia ? iHigh(_Symbol, InpTFSinal, iA) : iLow(_Symbol, InpTFSinal, iA);
         if(resistencia ? pB >= pA : pB <= pA) continue;
         double inc = (pB - pA) / (iA - iB);
         bool ok = true;
         for(int k = iB + 1; k < iA && ok; k++)
         {
            double lv = pA + inc * (iA - k);
            double c = iClose(_Symbol, InpTFSinal, k);
            if(resistencia ? c > lv : c < lv) ok = false;
         }
         // a linha tambem nao pode ter sido rompida antes da vela 1
         for(int k = 2; k < iB && ok; k++)
         {
            double lv = pA + inc * (iA - k);
            double c = iClose(_Symbol, InpTFSinal, k);
            if(resistencia ? c > lv : c < lv) ok = false;
         }
         if(ok) return true;
      }
   }
   return false;
}

double TLPrecoNa(int iA, double pA, int iB, double pB, int barra)
{
   return pA + (pB - pA) / (iA - iB) * (iA - barra);
}

void TLDesenhar(string nm, int iA, double pA, int iB, double pB, color cor)
{
   datetime tA = iTime(_Symbol, InpTFSinal, iA), tB = iTime(_Symbol, InpTFSinal, iB);
   if(ObjectFind(0, nm) < 0) ObjectCreate(0, nm, OBJ_TREND, 0, tA, pA, tB, pB);
   ObjectMove(0, nm, 0, tA, pA); ObjectMove(0, nm, 1, tB, pB);
   ObjectSetInteger(0, nm, OBJPROP_COLOR, cor);
   ObjectSetInteger(0, nm, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, nm, OBJPROP_RAY_RIGHT, true);
   ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
}

void TLSeta(bool compra, int barra)
{
   string nm = "FTL_seta_" + (string)(long)iTime(_Symbol, InpTFSinal, barra);
   double p = compra ? iLow(_Symbol, InpTFSinal, barra) : iHigh(_Symbol, InpTFSinal, barra);
   ObjectCreate(0, nm, compra ? OBJ_ARROW_UP : OBJ_ARROW_DOWN, 0, iTime(_Symbol, InpTFSinal, barra), p);
   ObjectSetInteger(0, nm, OBJPROP_COLOR, compra ? clrLime : clrRed);
   ObjectSetInteger(0, nm, OBJPROP_ANCHOR, compra ? ANCHOR_TOP : ANCHOR_BOTTOM);
   ObjectSetInteger(0, nm, OBJPROP_WIDTH, 3);
}

// Retorna 1 = rompeu LTB para cima (compra), -1 = rompeu LTA para baixo (venda)
int TLSinal()
{
   int iA, iB; double pA, pB; int sinal = 0;
   double minDist = InpTLDistMinPontos * _Point;
   double o1 = iOpen(_Symbol, InpTFSinal, 1), c1 = iClose(_Symbol, InpTFSinal, 1);
   double h1 = iHigh(_Symbol, InpTFSinal, 1), l1 = iLow(_Symbol, InpTFSinal, 1);
   double corpo = (h1 - l1) > 0 ? MathAbs(c1 - o1) / (h1 - l1) : 0;
   gTLTexto = "";
   ObjectDelete(0, "FTL_RES"); ObjectDelete(0, "FTL_SUP");
   if(TLAcharLinha(true, iA, pA, iB, pB))
   {
      TLDesenhar("FTL_RES", iA, pA, iB, pB, clrRed);
      gTLTexto += "LTB ok ";
      double l = TLPrecoNa(iA, pA, iB, pB, 1);
      if(c1 > l + minDist && c1 > o1 && corpo >= InpTLCorpoMin &&
         iClose(_Symbol, InpTFSinal, 2) <= TLPrecoNa(iA, pA, iB, pB, 2)) sinal = 1;
   }
   if(TLAcharLinha(false, iA, pA, iB, pB))
   {
      TLDesenhar("FTL_SUP", iA, pA, iB, pB, clrDodgerBlue);
      gTLTexto += "LTA ok";
      double l = TLPrecoNa(iA, pA, iB, pB, 1);
      if(sinal == 0 && c1 < l - minDist && c1 < o1 && corpo >= InpTLCorpoMin &&
         iClose(_Symbol, InpTFSinal, 2) >= TLPrecoNa(iA, pA, iB, pB, 2)) sinal = -1;
   }
   if(gTLTexto == "") gTLTexto = "procurando...";
   return sinal;
}

void TentarEntradaTrendline()
{
   if(!InpUsarTrendline || !InpEntradasAutomaticas) return;
   datetime tempo=iTime(_Symbol,InpTFSinal,1);
   if(tempo<=0 || tempo==gTLSinalOperado || !JanelaSinal()) return;
   int sinal=TLSinal();
   if(sinal==0) return;
   bool compra=sinal>0;
   TLSeta(compra,1);
   gUltimoSinalTexto="TRENDLINE "+(compra ? "COMPRA" : "VENDA");
   double atr=ATRVal();
   if(atr<=0) { Motivo("ATR AINDA NAO CARREGOU"); return; }
   int ib=compra ? iLowest(_Symbol,InpTFSinal,MODE_LOW,InpTLStopBarras,1)
                 : iHighest(_Symbol,InpTFSinal,MODE_HIGH,InpTLStopBarras,1);
   if(ib<0) { Motivo("SEM TOPO/FUNDO PARA O STOP"); return; }
   double sl=compra ? iLow(_Symbol,InpTFSinal,ib)-InpTLFolgaATR*atr
                    : iHigh(_Symbol,InpTFSinal,ib)+InpTLFolgaATR*atr;
   if(!EnviarOrdem(compra,sl,"Fenix Trendline"))
   {
      RegistrarRecusa("TRENDLINE", "TL"+(string)(long)tempo);
      return;
   }
   {
      AvisarEntrada("TRENDLINE", compra);
      gTLSinalOperado=tempo;
      GlobalVariableSet(gChaveGestao+"tl_"+_Symbol+"_"+(string)InpTFSinal,(double)tempo);
   }
}

//======================= CONTROLE DE DIA ===========================
void AtualizarDia()
{
   int dia=(int)InicioDia();
   if(dia != gDiaAtual)
   {
      gDiaAtual=dia;
      gSaldoInicioDia=Saldo()-ResultadoFechadoHoje();
      if(gSaldoInicioDia<=0) gSaldoInicioDia=Saldo();
      gBloqueadoDia=false; gMotivoBloqueio="";
      CarregarSinalOperado();
   }
   gEntradasHoje=EntradasHojeHistorico();
   string chave=gChaveGestao+"dia_"+(string)dia;
   if(GlobalVariableCheck(chave) && GlobalVariableGet(chave)>0)
   { gBloqueadoDia=true; gMotivoBloqueio="LIMITE DIARIO ATINGIDO - todos os ativos"; }
}

void ChecarLimitesDiarios()
{
   double pct = ResultadoDiaPct();
   if(!gBloqueadoDia)
   {
      if(pct <= -StopDiarioEfetivoPct())
      {
         gBloqueadoDia = true;
         gMotivoBloqueio = "STOP DIARIO ATINGIDO (" + DoubleToString(pct, 2) + "%)";
         if(InpFecharTudoNaMeta) FecharTodasEA(false);
         Print("[GESTAO] ", gMotivoBloqueio);
      }
      else if(pct >= AlvoDiarioEfetivoPct())
      {
         gBloqueadoDia = true;
         gMotivoBloqueio = "META DIARIA BATIDA (+" + DoubleToString(pct, 2) + "%)";
         if(InpFecharTudoNaMeta) FecharTodasEA(false);
         Print("[GESTAO] ", gMotivoBloqueio);
      }
   }
   if(gBloqueadoDia)
   {
      GlobalVariableSet(gChaveGestao+"dia_"+(string)gDiaAtual,1.0);
      GlobalVariablesFlush();
      if(InpFecharTudoNaMeta) FecharTodasEA(false); // repete se uma corretora recusou o fechamento
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
   double tol = MathMax(0.01, InpTolerancia); // respeita o ajuste escolhido (antes limitava silenciosamente a 0.08)
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
double SaldoBaseDia()
{
   return (gSaldoInicioDia > 0.0 ? gSaldoInicioDia : AccountInfoDouble(ACCOUNT_BALANCE));
}

// v4.6 - limites efetivos: converte US$ em % do saldo do dia quando InpGestaoEmDolares
double StopDiarioEfetivoPct()
{
   if(InpGestaoEmDolares)
      return InpStopDiarioUSD / MathMax(1.0, SaldoBaseDia()) * 100.0;
   return InpStopDiarioPct;
}

double AlvoDiarioEfetivoPct()
{
   if(InpGestaoEmDolares)
      return InpAlvoDiarioUSD / MathMax(1.0, SaldoBaseDia()) * 100.0;
   return InpAlvoDiarioPct;
}

double RiscoPorEntradaPct()
{
   if(InpGestaoEmDolares) return InpRiscoPorEntradaUSD / MathMax(1.0,SaldoBaseDia()) * 100.0;
   if(InpUsarRiscoFixo && InpRiscoPorEntradaPct>0) return InpRiscoPorEntradaPct;
   return InpStopDiarioPct / MathMax(1,InpDivisorRisco);
}

double AlvoPorEntradaPct()
{
   if(InpGestaoEmDolares) return InpAlvoPorEntradaUSD / MathMax(1.0,SaldoBaseDia()) * 100.0;
   if(InpUsarRiscoFixo && InpAlvoPorEntradaPct>0) return InpAlvoPorEntradaPct;
   return InpAlvoDiarioPct / MathMax(1,InpDivisorRisco);
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
      Motivo("SPREAD ALTO: "+(string)sp+" > "+(string)InpSpreadMaximoPontos+" pontos");
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
bool ConfPinBar(const bool compra, const int shift)
{
   double o = iOpen (_Symbol, InpTFSinal, shift);
   double c = iClose(_Symbol, InpTFSinal, shift);
   double h = iHigh (_Symbol, InpTFSinal, shift);
   double l = iLow  (_Symbol, InpTFSinal, shift);
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
bool ConfDivergenciaRSI(const bool compra, const datetime tD)
{
   // v5.4: compara o extremo M5 DENTRO da vela do ponto D com o extremo M5
   // anterior. Antes comparava as velas M5 atuais, horas depois do D.
   if(hRSI == INVALID_HANDLE || tD <= 0) return false;
   int n = MathMax(4, InpDivLookback);
   int fim = iBarShift(_Symbol, InpTFGatilho, tD, false);   // primeira M5 da vela do D
   if(fim < 0) return false;
   int porVela = MathMax(1, PeriodSeconds(InpTFSinal) / MathMax(1, PeriodSeconds(InpTFGatilho)));
   int ini = MathMax(0, fim - porVela + 1);                  // ultima M5 da vela do D
   int total = fim + n + 2;
   double rsi[];
   ArraySetAsSeries(rsi, true);
   if(CopyBuffer(hRSI, 0, 0, total, rsi) < total) return false;

   int idx = -1; double ext = 0.0;
   for(int i = ini; i <= fim; i++)
   {
      double v = compra ? iLow(_Symbol, InpTFGatilho, i) : iHigh(_Symbol, InpTFGatilho, i);
      if(v <= 0) continue;
      if(idx < 0 || (compra ? v < ext : v > ext)) { ext = v; idx = i; }
   }
   int idxAnt = -1; double ant = 0.0;
   for(int i = fim + 1; i <= fim + n; i++)
   {
      double v = compra ? iLow(_Symbol, InpTFGatilho, i) : iHigh(_Symbol, InpTFGatilho, i);
      if(v <= 0) continue;
      if(idxAnt < 0 || (compra ? v < ant : v > ant)) { ant = v; idxAnt = i; }
   }
   if(idx < 0 || idxAnt < 0) return false;
   bool precoRompeu = compra ? (ext <= ant) : (ext >= ant);
   bool rsiDiverge  = compra ? (rsi[idx] > rsi[idxAnt]) : (rsi[idx] < rsi[idxAnt]);
   bool zonaOk      = compra ? (rsi[idx] < 50.0) : (rsi[idx] > 50.0);
   return (precoRompeu && rsiDiverge && zonaOk);
}

// CONFIRMACAO 3 - Exaustao de volume/fluxo: volume da vela do ponto D acima
// da media (climax de venda no fundo / de compra no topo).
bool ConfExaustaoVolume(const int shift)
{
   int n = MathMax(3, InpVolMedia);
   long soma = 0;
   for(int i = shift + 1; i <= shift + n; i++) soma += iTickVolume(_Symbol, InpTFSinal, i);
   if(soma <= 0) return false;
   double media = (double)soma / (double)n;
   long   volD  = iTickVolume(_Symbol, InpTFSinal, shift);
   return ((double)volD >= media * InpVolFator);
}

// Valida o ponto D: preco AINDA na zona de reversao + confirmacoes de gatilho.
// Nenhuma entrada antecipada (padrao nao fechado) nem atrasada (preco longe).
bool GatilhoCirurgicoOk(const Harmonico &p)
{
   if(!InpGatilhoCirurgico) return true;
   int idadeD = iBarShift(_Symbol, InpTFSinal, p.tD, true);
   if(idadeD < 1) idadeD = 1;

   double atr = ATRVal();
   if(atr <= 0) atr = 20 * _Point;

   // 1) o preco precisa estar dentro da zona do ponto D
   double refPreco = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double limite   = atr * MathMax(0.05, InpMaxDistPRZ_ATR);
   double dist     = MathAbs(refPreco - p.D);
   if(dist > limite)
   {
      Motivo("PRECO AFASTADO DO PONTO D");
      if(InpLogDiagnostico)
         PrintFormat("[GATILHO] %s descartado: preco a %.*f do ponto D (limite %.*f) - entrada tardia evitada",
                     p.nome, _Digits, dist, _Digits, limite);
      return false;
   }

   // 1b) v4.7 - FILTRO DE ALTA ASSERTIVIDADE
   if(InpFiltroQualidade && !FiltroQualidade(p)) return false;

   // 2) confirmacoes independentes
   int    conf   = 0;
   string quais  = "";
   // v5.4: confirmacoes lidas na vela do ponto D (onde a rejeicao acontece).
   if(InpUsarPinBar          && ConfPinBar(p.compra, idadeD))      { conf++; quais += "PinBar "; }
   if(InpUsarRSIDiv          && ConfDivergenciaRSI(p.compra, p.tD)) { conf++; quais += "RSI-Div "; }
   if(InpUsarExaustaoVolume  && ConfExaustaoVolume(idadeD))        { conf++; quais += "Volume "; }

   int minimo = MathMax(1, MathMin(3, InpMinConfirmacoes));
   if(conf < minimo)
   {
      Motivo("GATILHO D: "+(string)conf+"/"+(string)minimo+" confirmacoes");
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

// ===================================================================
// v4.7 FILTRO DE ALTA ASSERTIVIDADE
// Harmonicos perdem principalmente em 3 situacoes:
//  a) o D chega sem exaustao (RSI neutro) -> preco atravessa o D;
//  b) mercado em tendencia forte (ADX alto) -> a reversao nao acontece;
//  c) horario sem liquidez (madrugada/rollover/sexta tarde) -> violino.
// Este filtro descarta essas entradas antes do gatilho.
// ===================================================================
bool FiltroQualidade(const Harmonico &p)
{
   MqlDateTime t; TimeToStruct(TimeCurrent(), t);
   if(InpUsarFiltroHorario)
   {
      bool ok = (InpHoraInicio <= InpHoraFim) ? (t.hour >= InpHoraInicio && t.hour < InpHoraFim)
                                              : (t.hour >= InpHoraInicio || t.hour < InpHoraFim);
      if(!ok) { if(InpLogDiagnostico) PrintFormat("[FILTRO] %s fora do horario de liquidez", p.nome); return false; }
   }
   if(InpBloquearSexta && t.day_of_week == 5 && t.hour >= 16)
   { if(InpLogDiagnostico) Print("[FILTRO] sexta apos 16h - entrada bloqueada"); return false; }

   if(InpUsarRSIExtremo && hRSI_SIN != INVALID_HANDLE)
   {
      double r[]; ArraySetAsSeries(r, true);
      // v5.4: RSI em volta da vela do D (antes: 3 velas mais recentes, ja depois da reversao)
      int idadeD = iBarShift(_Symbol, InpTFSinal, p.tD, true);
      int ini = MathMax(1, idadeD - 1);
      if(CopyBuffer(hRSI_SIN, 0, ini, 3, r) == 3)
      {
         double ext = p.compra ? MathMin(r[0], MathMin(r[1], r[2])) : MathMax(r[0], MathMax(r[1], r[2]));
         if(p.compra && ext > InpRSICompraMax)
         { Motivo("RSI SEM EXAUSTAO PARA COMPRA"); if(InpLogDiagnostico) PrintFormat("[FILTRO] %s compra sem exaustao (RSI %.1f)", p.nome, ext); return false; }
         if(!p.compra && ext < InpRSIVendaMin)
         { Motivo("RSI SEM EXAUSTAO PARA VENDA"); if(InpLogDiagnostico) PrintFormat("[FILTRO] %s venda sem exaustao (RSI %.1f)", p.nome, ext); return false; }
      }
   }
   if(InpUsarFiltroADX && hADX != INVALID_HANDLE)
   {
      double a[], dp[], dm[]; ArraySetAsSeries(a, true); ArraySetAsSeries(dp, true); ArraySetAsSeries(dm, true);
      if(CopyBuffer(hADX, 0, 1, 1, a) == 1 && CopyBuffer(hADX, 1, 1, 1, dp) == 1 && CopyBuffer(hADX, 2, 1, 1, dm) == 1)
      {
         bool contra = p.compra ? (dm[0] > dp[0]) : (dp[0] > dm[0]);
         if(a[0] > InpADXMax && contra)
         { Motivo("ADX: REVERSAO CONTRA TENDENCIA FORTE"); if(InpLogDiagnostico) PrintFormat("[FILTRO] %s contra tendencia forte (ADX %.1f)", p.nome, a[0]); return false; }
      }
   }
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
   if(!InpEntradasAutomaticas || !gPad.valido) return;
   Harmonico p=gPad;
   if(p.tD<=0 || p.tD==gSinalOperadoTD || !JanelaSinal()) return;
   int idade=iBarShift(_Symbol,InpTFSinal,p.tD,true);
   if(idade<1 || idade>InpMaxIdadeD) { Motivo("FIGURA ANTIGA - aguardando novo D"); return; }
   if(!VelaConfirma(p.compra)) { Motivo("AGUARDANDO CONFIRMACAO DA VELA"); return; }
   if(!ConfirmacaoFusao(p.compra)) return;
   if(!GatilhoCirurgicoOk(p)) return;
   double atr=ATRVal();
   if(atr<=0) { Motivo("ATR AINDA NAO CARREGOU"); return; }
   double sl=StopTecnico(p,atr*InpFolgaStopATR);
   if(!EnviarOrdem(p.compra,sl,p.nome+(p.compra ? " BUY" : " SELL")))
   {
      RegistrarRecusa("FIGURA "+p.nome, "D"+(string)(long)p.tD+"_"+(string)(long)iTime(_Symbol,InpTFSinal,0));
      return;
   }
   {
      AvisarEntrada("FIGURA "+p.nome, p.compra);
      MarcarSinalOperado(p.tD);
      double cd=MathAbs(p.C-p.D);
      gAlvoFib1=p.compra ? p.D+cd*InpFibParcial1/100.0 : p.D-cd*InpFibParcial1/100.0;
      gAlvoFib2=p.compra ? p.D+cd*InpFibParcial2/100.0 : p.D-cd*InpFibParcial2/100.0;
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
   double tick=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(tick<=0) tick=pt;
   sl=NormalizeDouble((compra ? MathFloor(sl/tick) : MathCeil(sl/tick))*tick,dig);
   tp=NormalizeDouble((compra ? MathCeil(tp/tick) : MathFloor(tp/tick))*tick,dig);
}

// Executor comum: automatica, trendline, ORB e botoes usam a mesma protecao.
double RiscoReservado()
{
   double soma=0;
   // Ordem ainda em processamento: nao libera seu orcamento para outro grafico.
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong ordem=OrderGetTicket(i);
      if(ordem>0 && OrderGetInteger(ORDER_MAGIC)==(long)InpMagic) return 1e100;
   }
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i);
      if(!PositionSelectByTicket(tk) || PositionGetInteger(POSITION_MAGIC)!=(long)InpMagic) continue;
      string simbolo=PositionGetString(POSITION_SYMBOL);
      double sl=PositionGetDouble(POSITION_SL), resultado=0;
      if(sl<=0) return 1e100; // sem SL: bloqueia novas entradas
      ENUM_ORDER_TYPE tipo=PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      if(!OrderCalcProfit(tipo,simbolo,PositionGetDouble(POSITION_VOLUME),PositionGetDouble(POSITION_PRICE_OPEN),sl,resultado)) return 1e100;
      soma+=MathMax(0.0,-resultado);
   }
   return soma;
}

bool AlvoEmDinheiro(bool compra,double preco,double lote,double alvo,double &tp)
{
   ENUM_ORDER_TYPE tipo=compra ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   double tick=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(tick<=0 || alvo<=0 || lote<=0) return false;
   double baixo=0,alto=MathMax(ATRVal(),tick*10),resultado=0;
   bool encontrou=false;
   for(int i=0;i<40;i++)
   {
      double p=compra ? preco+alto : preco-alto;
      if(p<=0 || !OrderCalcProfit(tipo,_Symbol,lote,preco,p,resultado)) return false;
      if(resultado>=alvo) { encontrou=true; break; }
      alto*=2;
   }
   if(!encontrou) return false;
   for(int i=0;i<50;i++)
   {
      double meio=(baixo+alto)/2;
      double p=compra ? preco+meio : preco-meio;
      if(!OrderCalcProfit(tipo,_Symbol,lote,preco,p,resultado)) return false;
      if(resultado<alvo) baixo=meio; else alto=meio;
   }
   double p=compra ? preco+alto : preco-alto;
   tp=NormalizeDouble((compra ? MathCeil(p/tick) : MathFloor(p/tick))*tick,_Digits);
   return tp>0;
}

bool EnviarOrdem(bool compra,double sl,string comentario)
{
   // Lock atomico compartilhado evita duas instancias reservarem o mesmo risco.
   string chave=gChaveGestao+"exec";
   double anterior=GlobalVariableGet(chave), agora=(double)TimeLocal();
   if(anterior>agora) { Motivo("AGUARDANDO OUTRO ATIVO"); return false; }
   double dono=agora+60;
   if(!GlobalVariableSetOnCondition(chave,dono,anterior)) { Motivo("AGUARDANDO OUTRO ATIVO"); return false; }
   bool ok=ExecutarOrdemProtegida(compra,sl,comentario);
   // Se o servidor aceitou sem confirmar negocio, segura o lock para reconciliar.
   // Falha fechada: prefere aguardar a duplicar exposicao.
   if(ok && trade.ResultDeal()==0)
      GlobalVariableSetOnCondition(chave,agora+120.0,dono);
   else GlobalVariableSetOnCondition(chave,0.0,dono);
   return ok;
}

bool ExecutarOrdemProtegida(bool compra,double sl,string comentario)
{
   AtualizarDia();
   if(!HistoricoDiaPronto()) return false;
   ChecarLimitesDiarios();
   if(gBloqueadoDia) { Motivo(gMotivoBloqueio); return false; }
   if(LimiteEntradasRegra(gEntradasHoje,InpMaxEntradasDia)) { Motivo("LIMITE DE ENTRADAS DO DIA"); return false; }
   if(PosicoesEA()>=InpMaxPosicoesAbertas) { Motivo("OPERACAO JA ABERTA NESTE ATIVO"); return false; }
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
   { Motivo("NEGOCIACAO AUTOMATICA NAO PERMITIDA"); return false; }
   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) || !AccountInfoInteger(ACCOUNT_TRADE_EXPERT))
   { Motivo("CONTA NAO PERMITE ORDENS DO ROBO"); return false; }
   if(!HorarioOk() || !SpreadOk()) return false;
   double risco=RiscoUSDRegra(InpGestaoEmDolares,InpRiscoPorEntradaUSD,SaldoBaseDia(),RiscoPorEntradaPct());
   double alvo=RiscoUSDRegra(InpGestaoEmDolares,InpAlvoPorEntradaUSD,SaldoBaseDia(),AlvoPorEntradaPct());
   double limite=SaldoBaseDia()*StopDiarioEfetivoPct()/100.0;
   double disponivel=OrcamentoRegra(ResultadoFechadoHoje(),limite,RiscoReservado());
   double riscoPlano=risco;
   risco=RiscoAjustadoRegra(riscoPlano,disponivel,InpRiscoMinFracao);
   if(risco<=0)
   { Motivo("RISCO DIARIO INSUFICIENTE: livre US$"+DoubleToString(disponivel,2)); return false; }
   if(risco<riscoPlano) alvo=alvo*risco/riscoPlano; // mantem a proporcao 1:2
   MqlTick cotacao;
   if(!SymbolInfoTick(_Symbol,cotacao) || cotacao.ask<=0 || cotacao.bid<=0)
   { Motivo("SEM COTACAO VALIDA"); return false; }
   double preco=compra ? cotacao.ask : cotacao.bid;
   double tp=compra ? preco+MathAbs(preco-sl)*2 : preco-MathAbs(preco-sl)*2;
   AjustarStops(compra,preco,sl,tp);
   double perda=0;
   ENUM_ORDER_TYPE tipo=compra ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(!OrderCalcProfit(tipo,_Symbol,1.0,preco,sl,perda) || perda>=0)
   { Motivo("NAO FOI POSSIVEL CALCULAR RISCO DO STOP"); return false; }
   double lote=VolumeRegra(risco,-perda,SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),
                          SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX),SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP));
   lote=NormalizeDouble(lote,DigitosLote());
   if(lote<=0) { Motivo("LOTE MINIMO EXCEDE O RISCO PERMITIDO"); return false; }
   if(!AlvoEmDinheiro(compra,preco,lote,alvo,tp)) { Motivo("ALVO EM USD INDISPONIVEL"); return false; }
   AjustarStops(compra,preco,sl,tp);
   double finalRisco=0,finalAlvo=0,margem=0;
   if(!OrderCalcProfit(tipo,_Symbol,lote,preco,sl,finalRisco) || -finalRisco>risco+0.01 || finalRisco>=0)
   { Motivo("STOP AJUSTADO EXCEDE RISCO"); return false; }
   if(!OrderCalcProfit(tipo,_Symbol,lote,preco,tp,finalAlvo) || finalAlvo<=0) { Motivo("ALVO CALCULADO INVALIDO"); return false; }
   if(!OrderCalcMargin(tipo,_Symbol,lote,preco,margem) || margem>AccountInfoDouble(ACCOUNT_MARGIN_FREE))
   { Motivo("MARGEM LIVRE INSUFICIENTE"); return false; }
   bool enviado=compra ? trade.Buy(lote,_Symbol,0.0,sl,tp,comentario) : trade.Sell(lote,_Symbol,0.0,sl,tp,comentario);
   uint rc=trade.ResultRetcode();
   bool aceito=enviado && (rc==TRADE_RETCODE_DONE || rc==TRADE_RETCODE_DONE_PARTIAL || rc==TRADE_RETCODE_PLACED);
   if(!aceito)
   { Motivo("ORDEM RECUSADA "+(string)rc+": "+trade.ResultRetcodeDescription()); return false; }
   gEntradasHoje=EntradasHojeHistorico();
   Motivo("ORDEM ACEITA: "+(compra ? "COMPRA" : "VENDA"));
   PrintFormat("[ORDEM] %s %s lote=%.*f risco bruto=%.2f alvo bruto=%.2f SL=%.*f TP=%.*f retcode=%u",
               _Symbol,comentario,DigitosLote(),lote,-finalRisco,finalAlvo,_Digits,sl,_Digits,tp,rc);
   return true;
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

   int idadeAlerta = gPad.valido ? iBarShift(_Symbol, InpTFSinal, gPad.tD, true) : -1;
   if(InpAlertaPadrao && gPad.valido && idadeAlerta >= 1 && idadeAlerta <= InpMaxIdadeD)
   {
      string chave = gPad.nome + (string)gPad.tD;
      if(chave != gUltimoAlerta)
      {
         gUltimoAlerta = chave;
         // v5.4: FIGURA nao e ordem. A entrada exige a vela de confirmacao.
         Alert("FIGURA ", gPad.nome, " ", gPad.compra ? "COMPRA" : "VENDA", " em ", _Symbol,
               " - aguardando confirmacao (ainda NAO e entrada)");
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
      ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_UPPER);
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
      ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_UPPER);
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

   int x = 12, y = 24;
   long altura=ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS,0);
   bool compacto=altura<440;

   Lbl("t0", x, y,      "FENIX v5.4 - PONTO D + TRENDLINE", clrGold, 11);
   Lbl("t1", x, y + 20, "Sinal: " + EnumToString(InpTFSinal) + "  |  Grafico: " + EnumToString((ENUM_TIMEFRAMES)Period()) +
       "  |  Spread: " + (string)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) + " pts", clrSkyBlue);
   Lbl("t2", x, y + 38, "Figura: " + (gPad.valido ? gPad.nome + (gPad.compra ? " COMPRA" : " VENDA") : "buscando..."),
       gPad.valido ? (gPad.compra ? clrLime : clrTomato) : clrSilver);
   Lbl("t3", x, y + 56, "Saldo inicio do dia: " + DoubleToString(gSaldoInicioDia, 2), clrWhite);
   Lbl("t4", x, y + 74, "Resultado do dia: " + DoubleToString(res, 2) + "  (" + DoubleToString(pct, 2) + "%)", cRes);
   string txtStopDia = InpGestaoEmDolares ? "-US$ " + DoubleToString(InpStopDiarioUSD, 2) : "-" + DoubleToString(InpStopDiarioPct, 2) + "%";
   string txtMetaDia = InpGestaoEmDolares ? "+US$ " + DoubleToString(InpAlvoDiarioUSD, 2) : "+" + DoubleToString(InpAlvoDiarioPct, 2) + "%";
   Lbl("t5", x, y + 92, "Stop diario: " + txtStopDia + "   |   Meta diaria: " + txtMetaDia, clrKhaki);
   string txtRisco = InpGestaoEmDolares ? "US$ " + DoubleToString(InpRiscoPorEntradaUSD, 2) : DoubleToString(RiscoPorEntradaPct(), 2) + "%";
   string txtAlvo  = InpGestaoEmDolares ? "US$ " + DoubleToString(InpAlvoPorEntradaUSD, 2) : DoubleToString(AlvoPorEntradaPct(), 2) + "%";
   Lbl("t6", x, y + 110, "Risco/entrada: " + txtRisco + "   |   Alvo/entrada: " + txtAlvo, clrKhaki);
   Lbl("t9", x, y + 128, "Pivos: " + (string)gQtdPivos + "  |  Figuras: " + (string)gQtdPadroes + "/" + (string)MathMax(1, InpMaxFiguras) +
       "   |   Auto: " + (InpEntradasAutomaticas ? "LIGADO" : "DESLIGADO") +
       "   |   BE: " + (InpMoverBreakeven ? "LIGADO" : "DESLIGADO"),
       InpEntradasAutomaticas ? clrLime : clrOrange);
   Lbl("t7", x, y + 146, "Entradas hoje: " + (string)gEntradasHoje + "/" + (string)InpMaxEntradasDia +
       "   |   Abertas: " + (string)PosicoesEA(), clrWhite);

   string aviso = gBloqueadoDia ? gMotivoBloqueio
                : (gEntradasHoje >= InpMaxEntradasDia ? "LIMITE DE ENTRADAS DO DIA" : gDiagnostico);
   color cAviso = gBloqueadoDia ? (pct >= 0 ? clrLime : clrRed)
                : (gEntradasHoje >= InpMaxEntradasDia ? clrOrange : clrLime);
   Lbl("t8", x, y + 168, ">> " + aviso, cAviso, 10);
   double pts = 0.0, usd = 0.0; int nP = PontosCorridos(pts, usd);
   color cP = (usd > 0 ? clrLime : (usd < 0 ? clrTomato : clrSilver));
   Lbl("t10", x, y + 188, nP > 0 ? "Pontos corridos: " + (pts >= 0 ? "+" : "") + DoubleToString(pts, 0) + " pts" : "Pontos corridos: sem operacao aberta", cP, 10);
   Lbl("t11", x, y + 206, nP > 0 ? (usd >= 0 ? "Ganhando agora: +US$ " : "Perdendo agora: -US$ ") + DoubleToString(MathAbs(usd), 2) : (gUltimaRecusa != "" ? "Ultima recusa: " + gUltimaRecusa : "Linhas: " + gTLTexto), nP > 0 ? cP : (gUltimaRecusa != "" ? clrOrange : clrSilver), 10);
   EtiquetaPreco(nP, pts, usd);

   if(InpMostrarBotoes)
   {
      Btn("bBuy",   x, y + 240, 180, 30, "COMPRA MANUAL",  clrGreen,        clrWhite);
      Btn("bSell",  x, y + 274, 180, 30, "VENDA MANUAL",   clrFireBrick,    clrWhite);
      Btn("bCloseS",x, y + 308, 180, 30, "FECHAR SIMBOLO", C'40,40,40',     clrWhite);
      Btn("bCloseA",x, y + 342, 180, 30, "FECHAR TUDO",    C'90,90,90',     clrWhite);
   }
   if(compacto)
   {
      // Quatro graficos lado a lado: linhas curtas e botoes em duas colunas.
      string nomes[12]={"t0","t1","t2","t3","t4","t5","t6","t9","t7","t8","t10","t11"};
      for(int i=0;i<12;i++)
      {
         ObjectSetInteger(0,PFX+nomes[i],OBJPROP_YDISTANCE,16+i*14);
         ObjectSetInteger(0,PFX+nomes[i],OBJPROP_FONTSIZE,8);
      }
      if(InpMostrarBotoes)
      {
         Btn("bBuy",x,188,140,23,"COMPRA MANUAL",clrGreen,clrWhite);
         Btn("bSell",x+146,188,140,23,"VENDA MANUAL",clrFireBrick,clrWhite);
         Btn("bCloseS",x,215,140,23,"FECHAR SIMBOLO",C'40,40,40',clrWhite);
         Btn("bCloseA",x+146,215,140,23,"FECHAR TUDO",C'90,90,90',clrWhite);
      }
   }
   ChartRedraw();
}

void AbrirManual(bool compra)
{
   double atr=ATRVal();
   if(atr<=0) { Motivo("ATR AINDA NAO CARREGOU"); return; }
   double preco=compra ? SymbolInfoDouble(_Symbol,SYMBOL_ASK) : SymbolInfoDouble(_Symbol,SYMBOL_BID);
   EnviarOrdem(compra,compra ? preco-2*atr : preco+2*atr,compra ? "MANUAL BUY" : "MANUAL SELL");
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
      Motivo("FIGURA AGUARDANDO VELA DE FORCA");
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
         Motivo("AGUARDANDO ROMPIMENTO PARA COMPRA");
         if(InpLogDiagnostico) Print("[FUSAO] Aguardando rompimento do micro-range para compra.");
         return false;
      }
      if(!compra && close1 >= menorLow)
      {
         Motivo("AGUARDANDO ROMPIMENTO PARA VENDA");
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
   datetime barra=iTime(_Symbol,InpTFSinalORB,0);
   if(barra==gUltimaBarraORB || !JanelaRegra((long)TimeCurrent(),(long)barra,InpValidadeSinalSeg)) return;
   if(InpPrioridadeHarmonico && gPad.valido && gPad.tD!=gSinalOperadoTD) return;
   int sinal=VerificarSinalORB();
   if(sinal==0 || !FiltroEMAOrb(sinal)) return;
   double atr=ATRVal(); if(atr<=0) return;
   bool compra=sinal>0;
   double preco=compra ? SymbolInfoDouble(_Symbol,SYMBOL_ASK) : SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double sl=compra ? preco-atr*InpORBStopATRMult : preco+atr*InpORBStopATRMult;
   if(EnviarOrdem(compra,sl,compra ? "ROMPIMENTO BUY" : "ROMPIMENTO SELL")) gUltimaBarraORB=barra;
}

//======================= EVENTOS ===================================
int OnInit()
{
   if(InpGestaoEmDolares && AccountInfoString(ACCOUNT_CURRENCY)!="USD")
   { Print("[ERRO] Gestao em USD requer conta USD."); return INIT_PARAMETERS_INCORRECT; }
   if(InpRiscoPorEntradaUSD<=0 || InpAlvoPorEntradaUSD<=0 || InpMaxEntradasDia<1 ||
      InpStopDiarioUSD<=0 || InpAlvoDiarioUSD<=0 || InpValidadeSinalSeg<1 || InpRepetirSegundos<1 || InpMaxIdadeD<1 || InpRiscoMinFracao<0 || InpRiscoMinFracao>1)
      return INIT_PARAMETERS_INCORRECT;
   gChaveGestao="F53_"+(string)AccountInfoInteger(ACCOUNT_LOGIN)+"_"+(string)InpMagic+"_";
   GlobalVariableTemp(gChaveGestao+"exec"); // nao sobrescreve lock existente
   string tl=gChaveGestao+"tl_"+_Symbol+"_"+(string)InpTFSinal;
   if(GlobalVariableCheck(tl)) gTLSinalOperado=(datetime)GlobalVariableGet(tl);
   ChartSetInteger(0,CHART_SHIFT,true);
   ChartSetDouble(0,CHART_SHIFT_SIZE,25.0);
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

   hRSI_SIN = iRSI(_Symbol, InpTFSinal, InpRSIPeriodo, PRICE_CLOSE);
   hADX     = iADX(_Symbol, InpTFSinal, InpADXPeriodo);

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

   gUltimaBarraSinal=iTime(_Symbol,InpTFSinal,0);
   gDiaAtual = -1;
   AtualizarDia();
   DetectarPadroes();
   DesenharPadrao();
   AtualizarPainel();
   Print("Robo Fenix v5.4 (Ponto D + Trendline) - Precisao Cirurgica no Ponto D | AUTO ", (InpEntradasAutomaticas ? "LIGADO" : "DESLIGADO"),
          " | Entrada no D ", (InpEntrarAoFecharFigura ? "LIGADA" : "DESLIGADA"), " | Stop diario ", StopDiarioEfetivoPct(),
         "% | Meta diaria ", AlvoDiarioEfetivoPct(), "% | Entradas/dia ", InpMaxEntradasDia,
         " | Breakeven ", (InpMoverBreakeven ? "ON" : "OFF"));
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, "FTL_");
   ObjectsDeleteAll(0, PFX);
   if(hATR != INVALID_HANDLE) IndicatorRelease(hATR);
   if(hEMA_ORB != INVALID_HANDLE) IndicatorRelease(hEMA_ORB);
   if(hEMA_FUS != INVALID_HANDLE) IndicatorRelease(hEMA_FUS);
   if(hRSI != INVALID_HANDLE) IndicatorRelease(hRSI);
   if(hRSI_SIN != INVALID_HANDLE) IndicatorRelease(hRSI_SIN);
   if(hADX != INVALID_HANDLE) IndicatorRelease(hADX);
   ChartRedraw();
}

void OnTick()
{
   AtualizarDia();
   ChecarLimitesDiarios();
   datetime barra=iTime(_Symbol,InpTFSinal,0);
   if(barra<=0) return;
   if(barra!=gUltimaBarraSinal)
   {
      // Nao consome a nova vela antes de os dados estarem carregados.
      if(ATRVal()<=0 || iBars(_Symbol,InpTFSinal)<60)
      { Motivo("CARREGANDO HISTORICO / ATR"); AtualizarPainel(); return; }
      gUltimaBarraSinal=barra;
      DetectarPadroes(); DesenharPadrao(); TLSinal();
      Motivo("BUSCANDO FIGURA / ROMPIMENTO");
   }
   if(InpEntradasAutomaticas && TimeCurrent()-gUltimaTentativa>=InpRepetirSegundos)
   {
      gUltimaTentativa=TimeCurrent();
      if(HorarioOk() && !gBloqueadoDia)
      {
         TentarEntrada();
         TentarEntradaTrendline();
         TentarEntradaORB();
      }
   }
   if(!InpEntradasAutomaticas) Motivo("AUTOMATICO DESLIGADO");
   GerenciarParcial(); GerenciarBreakeven(); AtualizarPainel();
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
