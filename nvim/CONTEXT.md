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

**Modo**:
O conjunto de arquivos que o painel está listando no momento: as mudanças do
working tree, ou as de um commit (ou intervalo de commits) selecionado. É também
a que revisão uma anotação pertence e de que revisão um relatório é.
_Avoid_: aba, tela, view

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

**Intervalo**:
Os dois commits que delimitam uma revisão de mais de um commit, os dois
incluídos. O que ele põe no painel é a diferença entre as duas pontas — o que a
feature inteira mudou —, e não a soma dos commits um a um: um arquivo criado e
apagado dentro dele não está lá.
_Avoid_: range, série, sequência

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
O texto da linha guardado junto com a anotação, usado para reencontrar a linha
depois que o arquivo muda.
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
