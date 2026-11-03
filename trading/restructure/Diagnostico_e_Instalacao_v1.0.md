# Fênix Confluência — diagnóstico e instalação

## Antes de operar

Esta é uma nova estratégia de **continuação por rompimento confirmado**, não uma atualização silenciosa do Ponto D. Ela não desenha figuras harmônicas. Mais filtros não garantem mais acerto, mais entradas ou lucro. Os dez stops relatados não permitem determinar a causa sem o relatório do testador e os registros de execução.

Não use em conta real antes de compilar, realizar backtest e testar em demonstração. Não foi possível executar MetaEditor/MT5 nem validar o Pine no TradingView neste ambiente.

## Autópsia: os três principais problemas

### 1. Falta de confluência e sinais que ainda mudam

- Nos EAs ORB, `OnTick()` aceita fechamento acima/abaixo do range com corpo forte, mas não exige alinhamento de tendência por EMA nem RSI/volume relativo. Uma vela grande não prova continuidade: o código pode comprar um rompimento contra a tendência predominante.
- `Robô_da_Grana.txt` usa reversão nas bandas com `open`/`close` da vela atual, sem filtro de tendência. `Robô_da_Grana_02.txt` também usa vela atual nos engolfos/padrões. As condições podem aparecer e desaparecer antes do fechamento.
- Os dois arquivos `Robo_indicador_MQ5...` são idênticos. São indicadores, não robôs de execução. Seus pré-sinais amarelos usam a vela em formação, deliberadamente; não devem ser confundidos com confirmação fechada.
- Na atualização incremental destes indicadores, `CopyBuffer(..., to_copy, FastBuf)` copia poucos valores recentes para um buffer completo sem alinhar explicitamente a posição desses dados com os índices finais usados pelo cálculo. Esse padrão de cópia pode deixar valores desalinhados/desatualizados após a primeira execução; a direção dos arrays também não é definida explicitamente. O novo EA lê cada indicador isoladamente em `shift=1/2`, eliminando essa ambiguidade.

### 2. Trava diária não acompanha a perda aberta e o lote pode exceder o risco

- Os dois EAs usam `ACCOUNT_BALANCE - g_saldoInicioDia` (MultiTF, linhas 297–300; XAUUSD, 298–301). Isso ignora o prejuízo ainda flutuante e inclui alterações de saldo da conta que não necessariamente pertencem ao robô.
- A referência diária é redefinida ao anexar/reiniciar o EA. O bloqueio não é persistido. A gestão pode ficar diferente entre gráficos.
- `CalcularLote()` eleva o volume calculado ao mínimo da corretora e retorna o mínimo quando o tick é inválido. Se esse mínimo arrisca mais que o orçamento, o risco anunciado deixa de ser respeitado.

### 3. Execução desprotegida e possibilidade de acumular entradas

- Não há filtro explícito de spread, limite de margem livre por ordem nem checagem dos stops mínimos antes das compras/vendas automáticas.
- Os EAs permitem até quatro posições. Uma vela nova ainda acima do mesmo range pode gerar outra compra sem exigir um novo cruzamento. Isso pode concentrar risco num único movimento.
- O retorno de `CTrade` não é conferido integralmente por código do servidor. Os contadores também usam identificador de posição como ticket, pressuposto que não é universal.
- O XAUUSD `SemSwap` bloqueia novas entradas às 22h30 e tenta zerar às 23h45 por padrão: apesar do nome “24h”, não abre ordens em todo horário. Isso explica uma restrição operacional, não os dez stops.

Esses são defeitos ou vulnerabilidades demonstráveis; não são uma prova da causa de cada perda. Corretagem, spread histórico, ativo, lote, horário e prints dos negócios precisam ser examinados para atribuir os stops.

## O novo Expert Advisor

Arquivo: `Robo_Fenix_Confluencia_v1.0.mq5`.

- Padrão inicial: sinais M30 com EMA 200 do H1. Isso é um ponto de partida para teste, não uma conclusão de superioridade.
- Compra: fechamento rompe o topo das 20 velas anteriores, vela de alta com corpo ≥55%, preço acima da EMA H1 com inclinação positiva, RSI entre 52 e 70, volume de ticks ≥1,10 vezes a média anterior.
- Venda: lógica simétrica, RSI entre 30 e 48 e EMA descendente.
- Não usa pivôs futuros nem confirmação pela vela corrente. Sinal só é avaliado uma vez por vela, após fechamento. Ao ligar no meio de uma vela, espera a próxima, evitando entrada retroativa.
- Uma posição/ordem por símbolo, considerando qualquer robô ou operação manual nesse símbolo; intervalo mínimo de três velas entre entradas. Não há teto arbitrário de entradas por dia: os sinais e o orçamento global determinam quando operar.
- Stop inicial estrutural atrás do extremo das últimas cinco velas +0,30 ATR, respeitando stops mínimos. Stop excessivamente largo é descartado. O stop não se alarga depois da entrada.
- TP inicial de pelo menos 2 vezes a distância do SL. Trailing começa após movimento favorável de 2 ATR, seguindo a 1,5 ATR. Não há parcial. **O trailing pode fechar antes do TP; portanto, 1:2 é a relação inicial, não o retorno realizado garantido.**
- Filtro de spread: máximo de 40 pontos e de 10% do ATR simultaneamente. Ajustar pontos à cotação do instrumento, especialmente ouro e índices; um limite universal não serve para todos os ativos.
- Sessão padrão: 6h–22h; sexta até 18h; pausa de rollover 23h50–00h10. Horários do servidor, não horário de Brasília. Não há calendário de notícias: suspenda manualmente em eventos importantes; filtro de spread sozinho não evita todo choque de volatilidade.

### Travas de US$500/US$1.000

- Exige moeda da conta **USD**. Não converte silenciosamente outra moeda.
- Escopo: todas as posições e negócios do **mesmo magic 20261103**, em todos os símbolos no mesmo terminal. Não fecha posições manuais nem de outro magic; o resultado dessas operações fica fora das travas.
- Soma lucro/prejuízo, swap, comissão e taxas dos negócios do dia + lucro/swap flutuante de todas as posições do magic. Não conta depósitos como ganho.
- Ao atingir **−US$500** ou **+US$1.000**, grava o bloqueio antes de tentar zerar posições e cancelar pendentes do magic. Repete tentativas enquanto bloqueado caso o servidor rejeite. Checa em cada tick e a cada segundo.
- Bloqueio compartilhado por gráficos e preservado após reiniciar/remover o EA, através de variáveis globais do terminal. Use o mesmo magic e os mesmos limites em todos os gráficos. Não use duas instalações/terminais simultâneos para gerenciar a mesma conta: as variáveis não são compartilhadas entre terminais. Variáveis globais do MT5 expiram após quatro semanas sem acesso; não apagá-las para contornar a trava.
- Liberação na próxima segunda–sexta à meia-noite do servidor: sexta bloqueada → segunda. Feriados não são modelados; mercado sem sessão não executará ordens. Não representa calendário oficial de feriados de cada bolsa.
- Posições carregadas são incluídas com flutuante integral: abordagem conservadora, não um extrato mark-to-market que desconta a equity da meia-noite.
- Sem cotações, conexão ou mercado aberto, não é possível garantir zeragem imediata. Gaps, taxas inesperadas e slippage podem ultrapassar US$500. A trava é uma regra de execução, não um seguro financeiro.

### Lote e banca de US$100.000

Risco inicial configurado em **0,10% da equity**, isto é, cerca de US$100 com US$100.000 de equity. O EA limita esse valor ao orçamento diário restante, descontando a perda ainda possível nas posições abertas até seus stops. Reserva estimada de custos de 10% reduz o lote. Se o lote mínimo da corretora excede esse orçamento, **não entra**. Também limita a margem por ordem a 30% da margem livre e o lote a 5.

O alvo de US$1.000 é **diário**, não por operação. Não se força entrada para atingir a meta. Uma posição com US$100 de risco e TP 1:2 projeta aproximadamente US$200 brutos antes do trailing/custos.

## Instalação no MetaTrader 5

1. Faça backup e remova os robôs antigos dos símbolos onde testará esta estratégia. Não deixe os seis arquivos operando junto.
2. Abra MT5 → Arquivo → Abrir pasta de dados → `MQL5/Experts`.
3. Copie `Robo_Fenix_Confluencia_v1.0.mq5` para essa pasta.
4. Pressione F4, abra o arquivo no MetaEditor e F7 para compilar. O `.ex5` só será produzido pelo MetaEditor. Se houver erro, envie a lista completa de erros e a versão do terminal.
5. Primeiro abra o Testador (Ctrl+R), selecione este EA e uma conta USD. Use ticks reais, custos reais da corretora e 6–12 meses. Comece com apenas um símbolo.
6. Use os ajustes iniciais M30/H1 e depósito US$100.000; mantenha as travas US$500/US$1.000. Não conclua pela taxa de acerto isolada: compare fator de lucro, retorno líquido, drawdown, número de trades e perda máxima real.
7. Separe uma parte do histórico para validação fora da amostra. Compare com o robô antigo no mesmo ativo/período/custos, sem otimizar tudo no histórico de validação.
8. Em demonstração, ative Algo Trading e anexe o EA aos símbolos escolhidos com o mesmo magic e limites. Use símbolos exclusivos: em conta netting, outro robô/manual que negociar o mesmo símbolo pode misturar a posição e destruir o isolamento por magic.
9. Acompanhe “Experts”/“Diário” e o painel: ele mostra por que uma entrada foi recusada. Se não entra, examine primeiro spread, lote mínimo, indicadores, horário e confluência; não desligue todos os filtros às cegas.

## Script de suporte manual à IQ Option

Arquivo: `IQOption_Confluencia_M2_M5_v1.0.pine` — Pine Script v6 para **TradingView**, alternativa expressamente permitida no pedido. Não usa API não oficial, não pede credenciais da IQ Option e não envia ordens.

Lógica: continuação após pullback na EMA 20, alinhamento com EMA 100 inclinada, recuperação/rompimento do extremo da vela anterior, RSI equilibrado e corpo confirmado. M2/M5 apenas; volatilidade mínima por ATR. Volume relativo é opcional porque alguns feeds não fornecem volume útil. Setas só aparecem depois do fechamento. Sinais são avisos manuais, não promessa de validade para opções binárias.

### Como executar

1. Abra TradingView e o gráfico do par correspondente à IQ Option. Não espelhe OTC com cotação comum: são feeds diferentes.
2. Abra Pine Editor, crie indicador vazio e substitua pelo conteúdo completo do `.pine`.
3. Salve e clique em “Adicionar ao gráfico”. Selecione 2 ou 5 minutos; a disponibilidade depende do seu plano/feed no TradingView.
4. Crie alerta → Condição: este indicador → “Any alert() function call”/“Qualquer chamada de alert()”. Configure notificação no aplicativo/e-mail conforme seu plano. Depois de alterar parâmetros, recrie o alerta, pois ele mantém cópia da configuração anterior.
5. Ao fechamento de uma vela com sinal, o alerta informa par, CALL/PUT, preço de referência, duração e vencimento indicativo em UTC. Vencimento = fechamento do sinal + uma vela por padrão (2 ou 5 minutos).
6. Confirme cotação e vencimento efetivo diretamente na IQ Option. O preço de fechamento mostrado **não é preenchimento garantido**. Atraso manual e vencimentos disponíveis podem invalidar o sinal; se já passou o momento, não entre atrasado.
7. O indicador mostra/alerta “NÃO OPERAR” em baixa volatilidade e sinaliza timeframe inválido. Não foi conectado à IQ Option nem executado numa conta real.

## Validações e limites

Cinco testes automatizados extraem do MQL5 as funções puras e as compilam em C++: bloqueio exatamente em −500, meta exatamente em +1.000, reserva global de risco, rejeição de lote abaixo do mínimo e sexta→segunda. Rodar com `python3 trading/restructure/test_rules.py` no código-fonte entregue ao projeto. Isso **não compila o EA**, não prova compatibilidade integral MQL5/Pine e não simula ordens/trailing/mutex no terminal. Compile no MetaEditor e TradingView; teste as travas em demonstração antes de usar dinheiro real.

## Referências técnicas

- https://www.mql5.com/en/docs/trading/ordercalcprofit
- https://www.mql5.com/en/docs/trading/ordercalcmargin
- https://www.mql5.com/en/docs/constants/environment_state/marketinfoconstants
- https://www.mql5.com/en/docs/constants/tradingconstants/dealproperties
- https://www.mql5.com/en/docs/standardlibrary/tradeclasses/ctrade/positionmodify
- https://www.mql5.com/en/docs/globals
- https://www.tradingview.com/pine-script-docs/concepts/alerts/