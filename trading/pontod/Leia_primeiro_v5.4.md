# Fênix Ponto D + Trendline — v5.4

## Por que apareciam alertas e nenhuma entrada
1. **O alerta “Padrao … COMPRA/VENDA” não era sinal de entrada.** Ele avisava apenas que uma *figura* (X-A-B-C-D) foi desenhada. Ele aparecia até para figuras antigas e em todos os gráficos ao ligar o robô. A ordem só sai depois da vela de confirmação e dos filtros.
2. **Os filtros da figura se contradiziam.** Para entrar, a figura precisava passar pelos filtros de pin bar, volume e RSI, mas eles eram lidos na **vela de rompimento** (horas depois do ponto D):
   - o pin bar pedia corpo **pequeno**, enquanto a confirmação de força pedia corpo **grande** na mesma vela;
   - o RSI “esticado” era lido depois que o preço já tinha voltado do D;
   - a divergência M5 olhava as velas M5 atuais, não as do ponto D.
   Na prática, quase nenhuma figura conseguia passar ao mesmo tempo.
3. **A força pedia romper as 3 velas anteriores**, o que é raro logo depois de uma reversão.
4. **Uma perda pequena travava o dia.** Com stop diário de US$500 e risco de US$500 por operação, qualquer prejuízo (até -US$1 de custos) impedia novas entradas pelo resto do dia.

## O que mudou na v5.4
| Item | v5.3 | v5.4 |
|---|---|---|
| Pin bar, volume e RSI | lidos na vela de rompimento | lidos na **vela do ponto D** |
| Divergência M5 | velas M5 atuais | velas M5 **dentro da vela do D** |
| Rompimento de força | romper 3 velas | romper a máxima/mínima da **vela anterior** |
| Tempo para executar após a abertura da vela | 120 s | 300 s |
| Depois de perda pequena no dia | travava | entra com risco reduzido (ex.: livre US$480 → risco US$480, alvo US$960), até 50% do valor |
| Alerta de figura | “Padrao…” (parecia entrada) | “FIGURA … ainda NÃO é entrada”, só figuras recentes |
| Alerta de ordem | não havia | “ENTRADA ENVIADA” ou “SINAL NAO EXECUTADO – motivo” |
| Painel | só o estado atual | também mostra **Última recusa** |

Valores mantidos: risco US$500 e alvo US$1.000 por operação, stop diário US$500, meta diária US$1.000, máximo de 10 entradas/dia, 1 posição por ativo, H1, horário 03h–21h do servidor e sexta bloqueada após 16h.
Para nunca reduzir o risco abaixo de US$500, coloque **InpRiscoMinFracao = 0**.

## Como instalar
1. Abra `Robo_Fenix_PontoD_Trendline_v5.4.mq5` no MetaEditor e aperte **F7**. Se aparecer algum erro, envie o print.
2. Remova a v5.3 de todos os gráficos e coloque a v5.4 (H1). Use o mesmo magic e os mesmos valores em todos.
3. Ao colocar, clique em **Redefinir** nas configurações para não carregar valores antigos salvos.
4. Quando um sinal não virar ordem, aparecerá um alerta **SINAL NAO EXECUTADO** com o motivo. Envie esse alerta ou a aba **Experts/Especialistas** se continuar sem entradas.

## Limites
Os novos testes de risco, janela e orçamento passaram fora do MetaTrader. **O arquivo não foi compilado no MT5 nem passou por backtest neste ambiente.** Há mais entradas porque os filtros contraditórios foram corrigidos, mas isso não garante acerto nem lucro. Spread, comissão, gaps e derrapagem mudam o resultado real. Teste primeiro na demo e no testador (6–12 meses, ticks reais).
