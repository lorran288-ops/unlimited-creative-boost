# Fênix Ponto D + Trendline — v5.3

## O que foi encontrado
- No print, o automático está ligado e o contador está em 0/10. Isso não prova que uma ordem foi enviada ou recusada: a aba **Experts/Especialistas** é necessária para identificar o bloqueio ocorrido na sua conta.
- A v5.2 mostrava US$50/100 por entrada porque o painel dividia os limites do dia por 10; o cálculo de lote realmente usava US$250/500, dividindo por outro parâmetro. Corrigida a divergência.
- A busca de figura e rompimento rodava uma vez no começo de cada vela H1. Uma recusa por spread, dados ainda carregando ou execução não era repetida durante essa vela.
- A tolerância de Fibonacci configurada em 0,15 era limitada internamente a 0,08. Agora respeita o ajuste escolhido.
- As figuras e setas são desenhos de estruturas/sinais; não são comprovantes de ordens. As entradas continuam dependendo de confirmação, risco, horário e execução.

## Valores da nova versão
| Ajuste | Valor padrão |
|---|---:|
| Risco bruto previsto por operação | US$500 |
| Alvo bruto por operação | US$1.000 |
| Perda diária compartilhada | US$500 |
| Meta diária compartilhada | US$1.000 |
| Máximo de ordens de entrada/dia, somando ativos | 10 |
| Máximo de posições no mesmo ativo | 1 |
| Sinal | H1 |
| Intervalo de repetição | 3 segundos, quando houver ticks |
| Validade após abertura da vela seguinte | 120 segundos |
| Horário permitido | 03:00 até antes de 21:00 do servidor |
| Sexta-feira | bloqueado após 16:00 do servidor |

**Importante:** com perda do dia de US$500 e risco por operação de US$500, uma perda completa encerra o dia; uma vitória completa de US$1.000 também. Dez é um teto, não uma promessa nem obrigação de fazer dez ordens. A reserva de risco impede abrir simultaneamente várias posições de US$500 quando só há US$500 disponíveis. Depois de perdas menores, o orçamento restante pode não comportar uma nova entrada de US$500 — o painel informa isso. Não aumente o stop do dia apenas para forçar entradas.

O stop técnico continua baseado na estrutura. O lote é arredondado para baixo para não exceder o risco bruto previsto: a perda estimada pode ficar um pouco abaixo de US$500. O preço do alvo é calculado para esse lote usando o cálculo de lucro da corretora, em vez de simplesmente dividir o dinheiro pelo número de entradas.

**Spread, comissão, swap, arredondamento, execução parcial, derrapagem e gaps alteram o resultado real.** O alvo não garante lucro líquido de US$1.000 e o stop não garante perda máxima absoluta de US$500. Os limites diários incluem resultados realizados e flutuantes do magic configurado; não incluem operações de outros robôs ou manuais com magic diferente. Regras de mesa podem considerar toda a conta ou outra virada diária: confira o seu contrato.

## Como instalar e conferir
1. Abra a nova versão no MetaEditor e compile com **F7**. Não há arquivo EX5: esta entrega é código-fonte MQL5.
2. Na **conta demo em USD**, retire a v5.2 e coloque a v5.3 em cada gráfico H1 desejado. Não deixe as duas versões operando ao mesmo tempo.
3. Use os **mesmos valores de limites e magic em todos os gráficos**. Confira os novos ajustes **Risco por entrada USD = 500** e **Alvo por entrada USD = 1000**; parâmetros antigos salvos podem sobrescrever padrões.
4. Habilite AlgoTrading e a permissão de negociação nas propriedades do robô.
5. Aguarde o próximo fechamento H1. A instalação não autoriza perseguir uma seta histórica; figuras antigas são desenhadas, mas só as recentes podem ser operadas.
6. Observe o motivo no painel e a aba **Experts/Especialistas**: spread alto, horário, confirmação pendente, risco disponível, lote mínimo, margem insuficiente ou código de recusa.
7. Compare v5.2 e v5.3 no testador com mesmos ativos, datas, depósito, custos e ticks reais quando disponíveis. Depois valide na demo.

Médias, desenho harmônico/Fibonacci, rompimentos, filtros de confirmação, botões de compra/venda, fechar símbolo/tudo e pontos corridos permanecem. O horário e os filtros não foram desligados para produzir ordens artificialmente. Não é uma opção binária e não usa sinais de um indicador externo.

## O que foi e não foi validado
Passaram testes locais das regras puras extraídas do arquivo: risco de US$500, alvo de US$1.000, limite de 10, janela de repetição, reserva compartilhada e lote mínimo. Isso **não é compilação MQL5, teste de execução ou backtest**. MetaEditor/MT5 e a corretora não estão disponíveis neste ambiente; não há comprovação de ordens, taxa de acerto ou rentabilidade.

Se continuar sem entrar, envie a aba **Experts/Especialistas** no momento de um sinal, junto com os parâmetros e o painel. Somente o print atual não permite afirmar qual filtro bloqueou as últimas três sessões.