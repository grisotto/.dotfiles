# O botão direito abre menu de contexto em todo o editor, e cada entrada carrega o atalho no próprio texto

O menu de contexto do painel de revisão não é um menu do painel: é o menu do
editor, com as ações do painel dentro dele enquanto o revisor está no painel. Por
isso o modelo de mouse é decidido globalmente (`mousemodel=popup_setpos`, em
`lua/plugins/astrocore.lua`) e não só onde o painel está.

A alternativa seria ligar o menu de contexto dentro do painel e deixar o botão
direito com o comportamento antigo — estender a seleção — no resto do editor. Foi
rejeitada: o botão direito teria dois significados no mesmo editor, decididos pela
janela em que o ponteiro está, e o revisor descobriria qual é o de agora clicando.
O menu de contexto é o que o botão direito faz em qualquer outro editor, e é o que
ele passa a fazer aqui, em toda parte.

O menu do editor é um só e global, não é propriedade de um buffer. As entradas do
painel entram quando o revisor entra no painel e saem quando ele sai, para que o
botão direito em qualquer outro buffer continue mostrando exatamente o que
mostrava antes. Clicar com o direito no painel a partir de outra janela funciona
porque o clique leva o foco para lá primeiro, e o menu que aparece já é o de lá.

O atalho de cada ação é escrito dentro do texto da entrada, numa coluna alinhada,
e não no campo de acelerador que o editor tem para isso. O campo de acelerador —
o que vem depois de um `<Tab>` no nome do menu — é desenhado só por menu gráfico;
no terminal, que é onde este menu é lido, ele não aparece. Um atalho que ninguém
vê perde o motivo do menu existir, que é descobrir as teclas sem consultar
documentação.

## Consequences

O menu do painel é a única lista completa das ações dele que o revisor vê sem
teclar nada, e por isso ele e as teclas saem da mesma lista no código
(`panel_actions`, em `lua/review/panel.lua`). Duas listas divergiriam, e uma
entrada mostrando a tecla errada é pior do que não ter menu nenhum.

As entradas próprias do editor — inspecionar, colar, ir para a definição — ficam
no menu do painel, abaixo das nossas e separadas por um divisor. Elas não fazem
sentido numa lista de arquivos, mas escondê-las significaria desmontar e remontar
o menu do editor a cada entrada e saída do painel, e o que ficaria diferente para
o revisor é uma linha a menos que ele não estava lendo.

O padrão do Neovim hoje já é `popup_setpos`; a opção está escrita na configuração
mesmo assim, porque o menu do painel deixa de existir se ela mudar, e um padrão
não é lugar de guardar uma decisão.
