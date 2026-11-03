//+------------------------------------------------------------------+
//| Fenix Confluencia v1.2 - estrategia unica de rompimento confirmado |
//| Conta USD; gerenciamento GLOBAL do mesmo magic em todos simbolos. |
//| Nao opera figuras harmonicas nem usa dados de vela em formacao.    |
//| Lucro nao e garantido. Gaps/slippage podem exceder a trava diaria. |
//+------------------------------------------------------------------+
#property version "1.20"
#property strict
#include <Trade/Trade.mqh>
CTrade Trade;

input group "RISCO GLOBAL - CONTA USD"
input long   InpMagic=20261103;
input double InpPerdaDiariaUSD=500.0;
input double InpMetaDiariaUSD=1000.0;
input double InpRiscoUSD=250.0; // v1.2: perda maxima por operacao em US$ (0 = usar InpRiscoPct)
input double InpRiscoPct=0.10; // usado apenas se InpRiscoUSD=0
input double InpRR=2.0;
input double InpReservaCustosPct=10.0; // reserva estimada, NAO garante custos maximos
input double InpLoteMax=50.0;
input double InpMargemLivreMaxPct=30.0;
input int    InpDesvioPontos=10;
input group "CONFLUENCIA - SOMENTE VELAS FECHADAS"
input ENUM_TIMEFRAMES InpTFSinal=PERIOD_M30;
input ENUM_TIMEFRAMES InpTFTendencia=PERIOD_H1;
input int InpEMAPeriodo=200;
input int InpRangeBarras=20;
input int InpRSIPeriodo=14;
input double InpRSICompraMin=52.0;
input double InpRSICompraMax=70.0;
input double InpRSIVendaMin=30.0;
input double InpRSIVendaMax=48.0;
input int InpVolumeBarras=20;
input double InpVolumeMult=1.10; // volume de TICKS relativo, nao volume centralizado
input double InpCorpoMin=0.55;
input double InpBufferRompimentoATR=0.10;
input int InpCooldownBarras=3;
input group "STOPS TECNICOS E TRAILING"
input int InpATRPeriodo=14;
input int InpStopPivosBarras=5;
input double InpFolgaStopATR=0.30;
input double InpStopMinATR=0.80;
input double InpStopMaxATR=4.00; // descarta stop excessivamente largo
input bool   InpUsarTrailing=false; // v1.2: false = operacao vai inteira ate TP (2x) ou SL
input double InpTrailingInicioATR=2.00;
input double InpTrailingDistATR=1.50;
input double InpTrailingPassoATR=0.10;
input group "EXECUCAO E HORARIO DO SERVIDOR"
input int InpSpreadMaxPontos=40; // adaptar aos digitos/tick do ativo
input double InpSpreadMaxATR=0.10;
input int InpHoraInicio=6;
input int InpHoraFim=22;
input int InpSextaFim=18;
input int InpPausaInicioHHMM=2350;
input int InpPausaFimHHMM=10;
input bool InpDebug=true;

int hEMA=INVALID_HANDLE,hRSI=INVALID_HANDLE,hATR=INVALID_HANDLE;
datetime ultimaBarra=0;
string prefixo="",ultimoEstado="";

// REGRAS PURAS: este bloco e tambem testado por um pequeno teste C++.
// BEGIN_TESTABLE_RULES
int DailyDecision(double pnl,double loss,double target)
{
   if(pnl<=-loss) return -1;
   if(pnl>=target) return 1;
   return 0;
}
double AvailableRisk(double pnl,double loss,double reserved)
{
   return MathMax(0.0,loss+pnl-reserved);
}
double NormalizeRiskVolume(double requested,double minimum,double maximum,double step)
{
   if(step<=0.0 || requested<minimum || maximum<minimum) return 0.0;
   double volume=MathFloor(MathMin(requested,maximum)/step)*step;
   if(volume<minimum) return 0.0; // NUNCA elevar ao minimo e exceder o risco
   return volume;
}
int DaysUntilBusinessDay(int dayOfWeek)
{
   if(dayOfWeek==5) return 3;
   if(dayOfWeek==6) return 2;
   return 1;
}
// END_TESTABLE_RULES

datetime Now() { return TimeCurrent(); }
datetime DayStart(datetime t)
{
   MqlDateTime d; TimeToStruct(t,d); d.hour=0; d.min=0; d.sec=0;
   return StructToTime(d);
}
datetime NextBusinessDay(datetime t)
{
   MqlDateTime d; TimeToStruct(t,d);
   return DayStart(t)+DaysUntilBusinessDay(d.day_of_week)*86400;
}
void Status(string s)
{
   if(s!=ultimoEstado && InpDebug) Print("[Fenix] ",s);
   ultimoEstado=s;
}
// Mutex compartilhado por magic/conta/servidor: nao usa variaveis locais por grafico.
// Expira em 120s para recuperar uma instancia encerrada; trade e sincronico.
bool Acquire()
{
   string k=prefixo+"mutex";
   double old=GlobalVariableGet(k);
   datetime now=Now();
   if(old>(double)now) return false;
   return GlobalVariableSetOnCondition(k,(double)(now+120),old);
}
void Release() { GlobalVariableSet(prefixo+"mutex",0.0); }
bool IsOurPosition(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return false;
   return PositionGetInteger(POSITION_MAGIC)==InpMagic;
}
// Historico inclui comissoes/taxas de ENTRADA e SAIDA; conta cada deal uma vez.
// Resultado = negocios de hoje + lucro/swap de todas as posicoes ainda abertas
// do magic. Posicoes carregadas entram com seu flutuante integral (conservador).
bool DailyPL(double &pnl)
{
   pnl=0.0;
   if(!HistorySelect(DayStart(Now()),Now())) return false;
   for(int i=0;i<HistoryDealsTotal();i++)
   {
      ulong tk=HistoryDealGetTicket(i); if(tk==0) return false;
      if(HistoryDealGetInteger(tk,DEAL_MAGIC)!=InpMagic) continue;
      pnl+=HistoryDealGetDouble(tk,DEAL_PROFIT)+HistoryDealGetDouble(tk,DEAL_SWAP)
          +HistoryDealGetDouble(tk,DEAL_COMMISSION)+HistoryDealGetDouble(tk,DEAL_FEE);
   }
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(!IsOurPosition(tk)) continue;
      pnl+=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
   }
   return true;
}
bool TradeOK(bool sent)
{
   uint code=Trade.ResultRetcode();
   return sent && (code==TRADE_RETCODE_DONE || code==TRADE_RETCODE_DONE_PARTIAL);
}
void CloseScope()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(!IsOurPosition(tk)) continue;
      string sym=PositionGetString(POSITION_SYMBOL);
      Trade.SetTypeFillingBySymbol(sym);
      if(!TradeOK(Trade.PositionClose(tk)))
         PrintFormat("[TRAVA] Falha fechar %I64u: %u %s; tentara novamente.",tk,
                     Trade.ResultRetcode(),Trade.ResultRetcodeDescription());
   }
   // Este EA nao cria pendentes; remove tambem eventuais pendentes do seu magic.
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong tk=OrderGetTicket(i); if(tk==0) continue;
      if(OrderGetInteger(ORDER_MAGIC)!=InpMagic) continue;
      if(!TradeOK(Trade.OrderDelete(tk)))
         PrintFormat("[TRAVA] Falha cancelar ordem %I64u: %s",tk,Trade.ResultRetcodeDescription());
   }
}
// Fail-closed: erro de historico impede novas ordens. A trava e gravada ANTES
// de fechar; reinicio e outros graficos mantem o bloqueio mesmo apos o PL mudar.
bool GuardLocked(double &pnl)
{
   if(!DailyPL(pnl)) { Status("SEM HISTORICO: novas entradas bloqueadas"); return false; }
   double until=GlobalVariableGet(prefixo+"until");
   int decision=DailyDecision(pnl,InpPerdaDiariaUSD,InpMetaDiariaUSD);
   if(until<=(double)Now() && decision!=0)
   {
      until=(double)NextBusinessDay(Now());
      GlobalVariableSet(prefixo+"until",until); GlobalVariablesFlush();
      PrintFormat("[TRAVA] PL=%.2f USD; bloqueado ate %s",pnl,TimeToString((datetime)until));
   }
   if(until>(double)Now())
   {
      CloseScope(); Status("TRAVA DIARIA ATIVA"); return false;
   }
   MqlDateTime d; TimeToStruct(Now(),d);
   if(d.day_of_week==0 || d.day_of_week==6) { Status("FIM DE SEMANA"); return false; }
   return true;
}
bool TradingTime()
{
   MqlDateTime d; TimeToStruct(Now(),d);
   if(d.day_of_week==0 || d.day_of_week==6) return false;
   if(d.day_of_week==5 && d.hour>=InpSextaFim) return false;
   bool hours=(InpHoraInicio<InpHoraFim)?(d.hour>=InpHoraInicio && d.hour<InpHoraFim)
      :(InpHoraInicio==InpHoraFim || d.hour>=InpHoraInicio || d.hour<InpHoraFim);
   int hhmm=d.hour*100+d.min;
   bool pause=(InpPausaInicioHHMM<InpPausaFimHHMM)?
      (hhmm>=InpPausaInicioHHMM && hhmm<InpPausaFimHHMM):
      (InpPausaInicioHHMM!=InpPausaFimHHMM && (hhmm>=InpPausaInicioHHMM || hhmm<InpPausaFimHHMM));
   return hours && !pause;
}
bool Value(int handle,int shift,double &value)
{
   double b[1]; if(CopyBuffer(handle,0,shift,1,b)!=1) return false;
   value=b[0]; return MathIsValidNumber(value) && value!=EMPTY_VALUE;
}
bool SameSymbolOccupied()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0) continue;
      if(PositionGetString(POSITION_SYMBOL)==_Symbol) return true;
   }
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(OrderGetTicket(i)==0) continue;
      if(OrderGetString(ORDER_SYMBOL)==_Symbol) return true;
   }
   return false; // qualquer magic: evita misturar posicoes netting
}
bool CooldownPassed()
{
   double last=GlobalVariableGet(prefixo+"last_"+_Symbol);
   return (double)Now()-last>=InpCooldownBarras*PeriodSeconds(InpTFSinal);
}
// Pior perda incremental ate os stops a partir do preco atual. Considera
// TODOS os simbolos do magic, evitando comprometer $500 em cada grafico.
bool ReservedRisk(double &reserved)
{
   reserved=0.0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(!IsOurPosition(tk)) continue;
      string sym=PositionGetString(POSITION_SYMBOL);
      MqlTick q; if(!SymbolInfoTick(sym,q)) return false;
      double sl=PositionGetDouble(POSITION_SL); if(sl<=0.0) return false;
      bool buy=PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY;
      double estimate=0.0;
      if(!OrderCalcProfit(buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL,sym,
         PositionGetDouble(POSITION_VOLUME),buy?q.bid:q.ask,sl,estimate)) return false;
      reserved+=MathMax(0.0,-estimate);
   }
   // Nao suportar exposicao de ordens pendentes criadas externamente no magic.
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(OrderGetTicket(i)==0) continue;
      if(OrderGetInteger(ORDER_MAGIC)==InpMagic) return false;
   }
   return true;
}
double RoundPrice(double p,bool upward)
{
   double tick=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(tick<=0.0) return 0.0;
   double v=upward?MathCeil(p/tick)*tick:MathFloor(p/tick)*tick;
   return NormalizeDouble(v,_Digits);
}
bool SpreadOK(MqlTick &q,double atr)
{
   double spread=q.ask-q.bid;
   return q.ask>q.bid && q.bid>0.0 && spread<=InpSpreadMaxPontos*_Point && spread<=InpSpreadMaxATR*atr;
}
void DrawRange(double high,double low)
{
   string names[2]={"FNC_Range_H","FNC_Range_L"};
   for(int i=0;i<2;i++)
   {
      if(ObjectFind(0,names[i])<0) ObjectCreate(0,names[i],OBJ_HLINE,0,0,i==0?high:low);
      ObjectSetDouble(0,names[i],OBJPROP_PRICE,i==0?high:low);
      ObjectSetInteger(0,names[i],OBJPROP_COLOR,i==0?clrTomato:clrSeaGreen);
      ObjectSetInteger(0,names[i],OBJPROP_STYLE,STYLE_DASH);
   }
}
// Retorna 1=compra, -1=venda, 0=nao operar. Todos indicadores na barra 1/2.
int Signal(double &sl,double &atr)
{
   int n=MathMax(MathMax(InpRangeBarras,InpVolumeBarras),InpStopPivosBarras)+3;
   MqlRates bars[]; ArraySetAsSeries(bars,true);
   if(CopyRates(_Symbol,InpTFSinal,0,n,bars)!=n) { Status("AGUARDANDO HISTORICO"); return 0; }
   double ema=0,previousEMA=0,rsi=0;
   if(!Value(hEMA,1,ema) || !Value(hEMA,2,previousEMA) || !Value(hRSI,1,rsi) || !Value(hATR,1,atr) || atr<=0.0)
      { Status("AGUARDANDO INDICADORES"); return 0; }
   double top=bars[2].high,bottom=bars[2].low;
   for(int i=3;i<=InpRangeBarras+1;i++) { top=MathMax(top,bars[i].high); bottom=MathMin(bottom,bars[i].low); }
   DrawRange(top,bottom);
   double range=bars[1].high-bars[1].low;
   double body=MathAbs(bars[1].close-bars[1].open);
   if(range<=0.0 || body/range<InpCorpoMin) { Status("SEM CORPO DE CONFIRMACAO"); return 0; }
   double avg=0.0;
   for(int i=2;i<=InpVolumeBarras+1;i++) avg+=(double)bars[i].tick_volume;
   avg/=InpVolumeBarras;
   if(avg<=0.0 || (double)bars[1].tick_volume<avg*InpVolumeMult) { Status("VOLUME RELATIVO INSUFICIENTE"); return 0; }
   double buffer=InpBufferRompimentoATR*atr;
   bool buy=bars[1].close>top+buffer && bars[2].close<=top && bars[1].close>bars[1].open
      && bars[1].close>ema && ema>previousEMA && rsi>=InpRSICompraMin && rsi<=InpRSICompraMax;
   bool sell=bars[1].close<bottom-buffer && bars[2].close>=bottom && bars[1].close<bars[1].open
      && bars[1].close<ema && ema<previousEMA && rsi>=InpRSIVendaMin && rsi<=InpRSIVendaMax;
   if(!buy && !sell) { Status("SEM CONFLUENCIA DE ROMPIMENTO/EMA/RSI"); return 0; }
   sl=buy?bars[1].low:bars[1].high;
   for(int i=2;i<=InpStopPivosBarras;i++) sl=buy?MathMin(sl,bars[i].low):MathMax(sl,bars[i].high);
   sl+=buy?-InpFolgaStopATR*atr:InpFolgaStopATR*atr;
   return buy?1:-1;
}
void TryEntry(int direction,double technicalSL,double atr,double pnl)
{
   if(!TradingTime() || SameSymbolOccupied() || !CooldownPassed()) { Status("HORARIO/POSICAO/INTERVALO"); return; }
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED)
      || !AccountInfoInteger(ACCOUNT_TRADE_EXPERT)) { Status("ALGO TRADING DESABILITADO"); return; }
   MqlTick q; if(!SymbolInfoTick(_Symbol,q) || !SpreadOK(q,atr)) { Status("SPREAD ALTO OU SEM COTACAO"); return; }
   bool buy=direction>0;
   ENUM_ORDER_TYPE type=buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL;
   double entry=buy?q.ask:q.bid;
   double tick=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(tick<=0.0) return;
   double stops=(double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*_Point+tick;
   double sl=buy?MathMin(technicalSL,MathMin(entry-InpStopMinATR*atr,q.bid-stops)):
                 MathMax(technicalSL,MathMax(entry+InpStopMinATR*atr,q.ask+stops));
   sl=RoundPrice(sl,!buy);
   double distance=MathAbs(entry-sl);
   if(sl<=0.0 || distance>InpStopMaxATR*atr) { Status("STOP TECNICO EXCESSIVO"); return; }
   double tp=RoundPrice(buy?entry+distance*InpRR:entry-distance*InpRR,buy);
   if(tp<=0.0 || (buy?tp-q.bid:q.ask-tp)<stops) return;
   double reserved=0.0;
   if(!ReservedRisk(reserved)) { Status("RISCO EXISTENTE DESCONHECIDO: BLOQUEADO"); return; }
   double riscoOrdem=InpRiscoUSD>0.0?InpRiscoUSD:AccountInfoDouble(ACCOUNT_EQUITY)*InpRiscoPct/100.0;
   double budget=MathMin(riscoOrdem,
                        AvailableRisk(pnl,InpPerdaDiariaUSD,reserved));
   double minVol=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),unit=0.0;
   if(minVol<=0.0 || !OrderCalcProfit(type,_Symbol,minVol,entry,sl,unit) || unit>=0.0) return;
   double perLot=(-unit/minVol)*(1.0+InpReservaCustosPct/100.0);
   double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double volume=NormalizeRiskVolume(budget/perLot,minVol,
      MathMin(InpLoteMax,SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX)),step);
   if(volume<=0.0) { Status("LOTE MINIMO EXCEDERIA ORCAMENTO DE RISCO"); return; }
   double margin=0.0;
   if(!OrderCalcMargin(type,_Symbol,volume,entry,margin)) return;
   double maxMargin=AccountInfoDouble(ACCOUNT_MARGIN_FREE)*InpMargemLivreMaxPct/100.0;
   if(margin>maxMargin && margin>0.0)
      volume=NormalizeRiskVolume(volume*maxMargin/margin,minVol,volume,step);
   if(volume<=0.0) { Status("MARGEM INSUFICIENTE"); return; }
   // Revalidar a trava e a cotacao imediatamente antes do envio.
   double fresh=0.0; if(!GuardLocked(fresh)) return;
   if(!SymbolInfoTick(_Symbol,q) || !SpreadOK(q,atr)) return;
   double currentEntry=buy?q.ask:q.bid;
   if(MathAbs(currentEntry-entry)>InpDesvioPontos*_Point) { Status("PRECO SE AFASTOU: SEM ENTRADA TARDIA"); return; }
   double currentRisk=0.0;
   if(!OrderCalcProfit(type,_Symbol,volume,currentEntry,sl,currentRisk) || currentRisk>=0.0) return;
   if(-currentRisk*(1.0+InpReservaCustosPct/100.0)>MathMin(budget,AvailableRisk(fresh,InpPerdaDiariaUSD,reserved))) return;
   if((buy?q.bid-sl:sl-q.ask)<stops || (buy?tp-q.bid:q.ask-tp)<stops) return;
   Trade.SetTypeFillingBySymbol(_Symbol);
   bool sent=buy?Trade.Buy(volume,_Symbol,0.0,sl,tp,"Fenix confluencia"):
                 Trade.Sell(volume,_Symbol,0.0,sl,tp,"Fenix confluencia");
   uint rc=Trade.ResultRetcode();
   if(TradeOK(sent) || (sent && rc==TRADE_RETCODE_PLACED))
   {
      GlobalVariableSet(prefixo+"last_"+_Symbol,(double)Now()); GlobalVariablesFlush();
      PrintFormat("[ORDEM] %s lote %.4f SL %.5f TP %.5f retorno %u",buy?"BUY":"SELL",volume,sl,tp,rc);
   }
   else PrintFormat("[ORDEM RECUSADA] %u %s",rc,Trade.ResultRetcodeDescription());
}
// Trailing nunca alarga o stop inicial e conserva o TP. Usa tick atual e
// ATR da vela fechada, respeitando stops/freeze. Nao faz parcial.
void Trailing()
{
   double atr=0.0; if(!Value(hATR,1,atr) || atr<=0.0) return;
   MqlTick q; if(!SymbolInfoTick(_Symbol,q)) return;
   double tick=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE); if(tick<=0.0) return;
   double minDist=(double)MathMax(SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL),
                                  SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL))*_Point+tick;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(!IsOurPosition(tk)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      bool buy=PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY;
      double open=PositionGetDouble(POSITION_PRICE_OPEN),old=PositionGetDouble(POSITION_SL);
      double tp=PositionGetDouble(POSITION_TP),current=buy?q.bid:q.ask;
      if((buy?current-open:open-current)<InpTrailingInicioATR*atr) continue;
      double dist=MathMax(InpTrailingDistATR*atr,minDist);
      double next=RoundPrice(buy?current-dist:current+dist,!buy);
      double change=MathMax(InpTrailingPassoATR*atr,tick);
      if(next<=0.0 || (old>0.0 && (buy?next-old:old-next)<change)) continue;
      if(old>0.0 && MathAbs(current-old)<=minDist) continue;
      if(tp>0.0 && MathAbs(current-tp)<=minDist) continue;
      Trade.SetTypeFillingBySymbol(_Symbol);
      if(!TradeOK(Trade.PositionModify(tk,next,tp)))
         PrintFormat("[TRAILING] %I64u: %s",tk,Trade.ResultRetcodeDescription());
   }
}
void Dashboard(double pnl)
{
   Comment("FENIX CONFLUENCIA v1.2 | ",EnumToString(InpTFSinal)," / ",EnumToString(InpTFTendencia),
      "\nEscopo: magic ",InpMagic," - todos os simbolos | Conta USD",
      "\nPL realizado hoje + flutuante: $",DoubleToString(pnl,2),
      " | Stop -$",DoubleToString(InpPerdaDiariaUSD,2)," | Meta +$",DoubleToString(InpMetaDiariaUSD,2),
      "\n",ultimoEstado);
}
void Run(bool allowEntry)
{
   if(!Acquire()) return;
   double pnl=0.0;
   bool ready=GuardLocked(pnl);
   if(ready)
   {
      if(InpUsarTrailing) Trailing();
      // Apenas OnTick gera sinais; timer mantem protecao/fechamentos.
      if(allowEntry)
      {
         datetime t=iTime(_Symbol,InpTFSinal,0);
         if(t>0 && t!=ultimaBarra)
         {
            ultimaBarra=t;
            double sl=0.0,atr=0.0; int direction=Signal(sl,atr);
            if(direction!=0) TryEntry(direction,sl,atr,pnl);
         }
      }
   }
   Dashboard(pnl); Release();
}
bool ValidHHMM(int t) { return t>=0 && t<=2359 && t%100<60; }
int OnInit()
{
   if(AccountInfoString(ACCOUNT_CURRENCY)!="USD") { Print("Este EA exige conta em USD."); return INIT_PARAMETERS_INCORRECT; }
   if(InpMagic<=0 || InpPerdaDiariaUSD<=0 || InpMetaDiariaUSD<=0 || InpRiscoUSD<0 || (InpRiscoUSD==0 && (InpRiscoPct<=0 || InpRiscoPct>2.0)) || InpRiscoUSD>InpPerdaDiariaUSD || InpRR<2.0
      || InpRangeBarras<2 || InpVolumeBarras<2 || InpStopPivosBarras<2 || InpEMAPeriodo<2 || InpRSIPeriodo<2 || InpATRPeriodo<2
      || InpCorpoMin<=0 || InpCorpoMin>1 || InpVolumeMult<=0 || InpBufferRompimentoATR<0
      || InpLoteMax<=0 || InpReservaCustosPct<0 || InpCooldownBarras<1 || InpDesvioPontos<0
      || InpMargemLivreMaxPct<=0 || InpMargemLivreMaxPct>100 || InpSpreadMaxPontos<1 || InpSpreadMaxATR<=0
      || InpFolgaStopATR<0 || InpStopMinATR<=0 || InpStopMaxATR<InpStopMinATR
      || InpTrailingInicioATR<=0 || InpTrailingDistATR<=0 || InpTrailingPassoATR<=0
      || InpHoraInicio<0 || InpHoraInicio>23 || InpHoraFim<0 || InpHoraFim>23 || InpSextaFim<0 || InpSextaFim>23
      || !ValidHHMM(InpPausaInicioHHMM) || !ValidHHMM(InpPausaFimHHMM)
      || InpRSICompraMin<0 || InpRSICompraMax>100 || InpRSICompraMin>InpRSICompraMax
      || InpRSIVendaMin<0 || InpRSIVendaMax>100 || InpRSIVendaMin>InpRSIVendaMax
      || PeriodSeconds(InpTFSinal)<=0 || PeriodSeconds(InpTFTendencia)<PeriodSeconds(InpTFSinal))
      return INIT_PARAMETERS_INCORRECT;
   // Em netting, usar simbolos exclusivos para este EA durante sua execucao.
   // Nao ha como separar fisicamente uma posicao que outro EA misturou depois.
   uint hash=0; string server=AccountInfoString(ACCOUNT_SERVER);
   for(int i=0;i<StringLen(server);i++) hash=hash*31+(uint)StringGetCharacter(server,i);
   prefixo=StringFormat("FNC_%I64d_%I64d_%u_",AccountInfoInteger(ACCOUNT_LOGIN),InpMagic,hash);
   if(StringLen(prefixo+"last_"+_Symbol)>63) return INIT_PARAMETERS_INCORRECT;
   // GlobalVariableTemp cria sem sobrescrever uma variavel existente.
   if(!GlobalVariableCheck(prefixo+"mutex") && !GlobalVariableTemp(prefixo+"mutex") && !GlobalVariableCheck(prefixo+"mutex"))
      { Print("Falha ao criar variavel global do robo."); return INIT_FAILED; }
   if(!GlobalVariableCheck(prefixo+"until")) GlobalVariableSet(prefixo+"until",0.0);
   if(!GlobalVariableCheck(prefixo+"last_"+_Symbol)) GlobalVariableSet(prefixo+"last_"+_Symbol,0.0);
   // Impede limites diferentes sob o mesmo magic; configura-los igual em cada grafico.
   // v1.1: varios graficos iniciam juntos; espera a vez em vez de falhar.
   bool ok=false;
   for(int t=0;t<100 && !ok;t++) { ok=Acquire(); if(!ok) Sleep(100+(int)(MathRand()%100)); }
   if(!ok) { Print("Outra instancia ocupada por muito tempo. Reanexe este EA."); return INIT_FAILED; }
   string lossKey=prefixo+"loss",targetKey=prefixo+"target";
   if(!GlobalVariableCheck(lossKey)) GlobalVariableSet(lossKey,InpPerdaDiariaUSD);
   if(!GlobalVariableCheck(targetKey)) GlobalVariableSet(targetKey,InpMetaDiariaUSD);
   bool consistent=MathAbs(GlobalVariableGet(lossKey)-InpPerdaDiariaUSD)<0.001
                && MathAbs(GlobalVariableGet(targetKey)-InpMetaDiariaUSD)<0.001;
   Release();
   if(!consistent) { Print("Limites diferentes para o mesmo magic. Use os valores originais ou novo magic sem exposicao."); return INIT_PARAMETERS_INCORRECT; }
   Trade.SetExpertMagicNumber((ulong)InpMagic);
   Trade.SetDeviationInPoints(InpDesvioPontos);
   Trade.SetAsyncMode(false); Trade.SetTypeFillingBySymbol(_Symbol);
   hEMA=iMA(_Symbol,InpTFTendencia,InpEMAPeriodo,0,MODE_EMA,PRICE_CLOSE);
   hRSI=iRSI(_Symbol,InpTFSinal,InpRSIPeriodo,PRICE_CLOSE);
   hATR=iATR(_Symbol,InpTFSinal,InpATRPeriodo);
   if(hEMA==INVALID_HANDLE || hRSI==INVALID_HANDLE || hATR==INVALID_HANDLE) return INIT_FAILED;
   // Nao entrar retroativamente numa vela que fechou antes de ligar o EA.
   ultimaBarra=iTime(_Symbol,InpTFSinal,0);
   if(!EventSetTimer(1)) return INIT_FAILED;
   Print("Fenix iniciado: validacao em demo/backtest obrigatoria. Conta USD, magic exclusivo.");
   Run(false); return INIT_SUCCEEDED;
}
void OnDeinit(const int reason)
{
   EventKillTimer();
   if(hEMA!=INVALID_HANDLE) IndicatorRelease(hEMA);
   if(hRSI!=INVALID_HANDLE) IndicatorRelease(hRSI);
   if(hATR!=INVALID_HANDLE) IndicatorRelease(hATR);
   ObjectDelete(0,"FNC_Range_H"); ObjectDelete(0,"FNC_Range_L"); Comment("");
   // Nao apagar a trava persistente, mesmo ao remover/reiniciar o EA.
}
void OnTick() { Run(true); }
void OnTimer() { Run(false); }
//+------------------------------------------------------------------+
