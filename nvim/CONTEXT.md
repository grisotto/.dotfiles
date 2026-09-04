# Configuração Neovim

Configuração pessoal do Neovim sobre AstroNvim 6. O domínio modelado aqui é o
fluxo de **revisão de código com Git** dentro do editor: ler o que mudou,
registrar o que já foi lido e anotar o que precisa mudar.

## Language

### Revisão com Git

**Painel de revisão**:
A janela lateral que lista os arquivos em revisão, agrupados por estado, e que
é o ponto de partida de toda ação de revisão.
_Avoid_: sidebar, árvore de arquivos, explorer

**Janela de conteúdo**:
A janela ao lado do painel, onde vai tudo o que o painel abre: o arquivo, o
diff, o grafo. O painel não sai da janela dele e nada entra nela — buffer nenhum
é aberto na janela do painel, e o buffer do painel que apareça em qualquer outra
é despejado de volta.
_Avoid_: janela principal, janela grande, editor

**Modo**:
O conjunto de arquivos que o painel está listando no momento: as mudanças do
working tree, ou as de um commit (ou intervalo de commits) selecionado. É também
a que revisão uma anotação pertence e de que revisão um relatório é.
_Avoid_: aba, tela, view

**Tamanho da mudança**:
Quantas linhas a mudança de uma entrada pôs e tirou, escrito ao lado dela e
somado no cabeçalho. É o que decide em que ordem revisar. Não existe onde não há
o que contar: um arquivo untracked, um conflito, um binário.
_Avoid_: diff stat, numstat, contagem

**Linha de informação**:
A segunda linha do cabeçalho do painel, esmaecida, onde fica o que muda de um
modo para outro: os totais de linhas no working tree, o autor e a data num
commit, quantos commits num intervalo. As teclas são as mesmas em qualquer modo
— o que muda é o que o painel informa.
_Avoid_: subtítulo, resumo, barra de status

**Linha do próximo passo**:
A linha que o painel escreve quando não há mais nada para ler: commitar no
neogit, no working tree; gerar o relatório, num commit ou intervalo. É o fim da
revisão sem estado novo nenhum — nada é iniciado, nada é finalizado.
_Avoid_: conclusão, finalizar, fim da revisão

**Grafo de commits**:
A lista dos commits de todas as branches, desenhada ao lado do painel, de onde
sai o commit — ou o intervalo — que troca o modo. Escolher ali é o único jeito
de entrar no modo commit. Pode ser restrito a uma branch, e o filtro é o próprio
grafo reaberto pedindo ao git só aquela branch.
_Avoid_: histórico, log, árvore

**Rev**:
Um ponto da história que o git resolve: um commit, uma branch. É o que identifica
o modo do painel e o que nomeia cada lado de um diff. O revisor nunca o digita —
ele sai sempre de uma lista, o grafo ou a busca.
_Avoid_: versão, referência, sha

**Vista em outro rev**:
O arquivo da linha como ele está num rev escolhido, aberto ao lado do painel só
para ler. É consulta, e por isso tem volta: uma tecla devolve à janela o que
estava sendo lido antes dela.
_Avoid_: preview, espiada, snapshot

**Ida ao arquivo**:
Trocar o diff pelo arquivo no disco, no ponto que está sendo lido — a linha
reencontrada pela âncora, e não pelo número. É o que se faz quando ler vira
agir: editar, seguir uma definição, usar o que só existe sobre um arquivo de
verdade. A volta é o `<C-o>` do editor, com o diff um passo atrás do arquivo na
jumplist: dentro do arquivo o pulo é o de sempre, e o pulo que sairia dele traz o
diff de volta.
_Avoid_: abrir, pular, editar

**Preview**:
O diff da entrada sob o cursor desenhado na janela de conteúdo enquanto o
revisor anda pela lista, sem que o foco saia dela. É um estado do painel, ligado
e desligado numa tecla: varrer e ler são dois momentos da mesma revisão, e
alternar entre eles é gesto, não mudança de configuração. O que ele desenha é o
mesmo diff que a tecla de abrir desenha — não é uma janela nova nem uma versão
reduzida dele; a diferença é só o foco ficar onde está.
_Avoid_: prévia, espiada, diff automático

**Intervalo**:
Os dois commits que delimitam uma revisão de mais de um commit, os dois
incluídos. O que ele põe no painel é a diferença entre as duas pontas — o que a
feature inteira mudou —, e não a soma dos commits um a um: um arquivo criado e
apagado dentro dele não está lá.
_Avoid_: range, série, sequência

**Posição da revisão**:
Qual entrada da lista está sendo revisada agora, que é onde está o cursor do
painel. É uma só: a lista e o diff movem o mesmo cursor, e é dela que saem "o
próximo arquivo" e "marque este como visto", venha a tecla de onde vier. O
arquivo aberto na janela de conteúdo não responde isso — o mesmo arquivo pode
estar em duas entradas. Com a lista fora da tela quem responde é o diff montado,
que foi construído de uma entrada e por isso não tem essa ambiguidade; o cursor
alcança a revisão quando a lista volta.
_Avoid_: seleção, arquivo atual, foco

**Visto**:
Marca de que um conteúdo de arquivo já foi lido nesta revisão. Vale para o
conteúdo, não para o nome do arquivo: o mesmo conteúdo visto em um commit
continua visto no working tree, e um arquivo que mudou deixa de estar visto.
_Avoid_: lido, revisado, checado, resolvido

**Anotação**:
Um texto que o revisor escreve sobre um ponto do código, preso a um arquivo e
opcionalmente a uma linha. É observação de revisão, não comentário de código.
_Avoid_: comentário, review comment, TODO

**Anotação de arquivo**:
Anotação presa ao arquivo inteiro, sem linha.

**Ponto**:
Onde uma anotação se prende: o arquivo, o modo, e a linha quando houver. Dois
textos escritos no mesmo ponto são um só, corrigido.
_Avoid_: local, posição, alvo

**Entrada da anotação**:
Onde o revisor escreve o texto. A de uma linha é a padrão, porque quase toda
observação de revisão é uma frase; a longa é a janela de várias linhas, para
quando não couber.
_Avoid_: prompt, input, caixa

**Âncora**:
O texto de uma linha usado para reencontrá-la depois que o arquivo muda, no
lugar do número dela. É o que a anotação guarda, e é também como a ida ao
arquivo encontra o ponto que estava sendo lido: a linha vista num rev não tem o
mesmo número no disco.
_Avoid_: contexto, snippet

**Reancoragem**:
Procurar a âncora no arquivo e prender a anotação à linha em que ela está agora.
Acontece na geração do relatório, que é o único momento em que a linha guardada
é confrontada com o arquivo.
_Avoid_: realocação, remapeamento

**Anotação deslocada**:
Anotação cuja âncora não foi encontrada no arquivo. Ela não é descartada: é
entregue marcada, para o revisor decidir.
_Avoid_: anotação órfã, quebrada, inválida

**Relatório de revisão**:
O documento gerado a partir das anotações de um modo, feito para sair do editor
(colar em PR, ticket, mensagem).
_Avoid_: export, dump, relatório

**Raiz do projeto**:
A raiz do módulo ao qual um arquivo pertence, resolvida pelo LSP. Em monorepo é
mais estreita que a raiz do repositório.
_Avoid_: root, workspace

**Raiz do repositório**:
O topo do repositório Git. Só coincide com a raiz do projeto quando o repositório
tem um módulo só.
_Avoid_: root, toplevel
