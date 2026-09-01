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
working tree, ou as de um commit (ou intervalo de commits) selecionado.
_Avoid_: aba, tela, view

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

**Âncora**:
O texto da linha guardado junto com a anotação, usado para reencontrar a linha
depois que o arquivo muda.
_Avoid_: contexto, snippet

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
