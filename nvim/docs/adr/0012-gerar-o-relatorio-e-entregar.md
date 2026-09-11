# Gerar o relatório é entregar

O relatório de revisão é entregue a um agente de IA, que ajusta o código, e a
revisão continua depois disso no mesmo modo. Um relatório que trouxesse de novo o
que já foi pedido faria o agente refazer o que já fez. Por isso gerar o relatório
(`R` ou `M`) é entregar: as anotações abertas daquele modo saem nele e passam a
ser entregues, e o próximo relatório só leva o que for anotado depois.

Três regras completam isso. Gerar sem nenhuma anotação aberta refaz a última
entrega, para trocar de formato ou copiar de novo. A última entrega pode ser
reaberta (`U` no painel), para quando o relatório foi gerado e não foi mandado: as
anotações dela voltam a ser abertas. E anotar um ponto que tem anotação entregue
começa uma anotação nova, com a entrada vazia, porque depois da entrega o código
mudou e o que se escreve ali é outro pedido.

Uma entrega guarda o que foi entregue, e não só quais anotações foram: cada item
com a linha e o trecho citado no momento da geração. Refazer reproduz exatamente
o que o agente recebeu — validar é comparar o pedido com o que ele fez, e o pedido
não pode mudar porque o arquivo mudou. Só a quickfix é reancorada na hora, porque
é a navegação do revisor no arquivo de hoje. Todas as entregas ficam guardadas no
documento de estado.

## Considered Options

Uma tecla explícita de "entregue", apertada depois de colar no agente, foi
rejeitada: o erro que ela evita — anotações velhas voltando no relatório — passaria
a depender de o revisor lembrar a tecla, e o fluxo comum ganharia um passo.

Fechar a entrega sozinha na primeira anotação escrita depois de gerar também foi
rejeitado: a anotação esquecida logo depois de gerar iria calada para uma entrega
separada, sem que o revisor soubesse que o relatório que ele ia mandar já estava
fechado.

## Consequences

A contagem do painel conta só as anotações abertas: é o que falta mandar. Uma
entrega refeita é dita na notificação, para não se confundir com uma entrega nova.

Nenhuma tecla mostra as entregas antigas; elas ficam no documento de estado. O
`U` reabre só a última, porque reabrir uma antiga misturaria pedidos feitos sobre
um código que já mudou várias vezes.
