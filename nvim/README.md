# AstroNvim Template

**NOTE:** This is for AstroNvim v6+

A template for getting started with [AstroNvim](https://github.com/AstroNvim/AstroNvim)

Esta configuração tem um painel de revisão de código próprio (`lua/review/`);
todas as teclas dele estão em [Painel de revisão](#painel-de-revisão).

## 🛠️ Installation

#### Make a backup of your current nvim and shared folder

```shell
mv ~/.config/nvim ~/.config/nvim.bak
mv ~/.local/share/nvim ~/.local/share/nvim.bak
mv ~/.local/state/nvim ~/.local/state/nvim.bak
mv ~/.cache/nvim ~/.cache/nvim.bak
```

#### Create a new user repository from this template

Press the "Use this template" button above to create a new repository to store your user configuration.

You can also just clone this repository directly if you do not want to track your user configuration in GitHub.

#### Clone the repository

```shell
git clone https://github.com/<your_user>/<your_repository> ~/.config/nvim
```

#### Start Neovim

```shell
nvim
```

## Painel de revisão

A janela lateral que lista os arquivos em revisão, agrupados por estado, e que é
o ponto de partida de toda ação de revisão. Ele tem dois modos: o working tree,
que é como abre, e um commit — ou um intervalo de commits — escolhido no grafo.
As teclas são exatamente as mesmas nos dois.

`<Leader>` é o espaço, como no AstroNvim.

### Teclas globais

Valem em qualquer buffer.

| Tecla | O que faz |
| --- | --- |
| `<Leader>r` | Abre o painel, ou fecha se já estiver aberto |
| `<Leader>ga` | Anota a linha sob o cursor (entrada de uma linha) |
| `<Leader>gA` | Anota a linha sob o cursor (entrada de várias linhas) |

As duas de anotação só valem dentro de um arquivo do repositório — não no
painel, não num lado do diff, não num buffer sem arquivo atrás. Nos outros casos
elas avisam em vez de anotar.

### Teclas do painel

Locais ao buffer do painel, e sempre sobre a linha onde o cursor está.

| Tecla | O que faz |
| --- | --- |
| `<CR>` | Abre o diff da linha; no cabeçalho `Vistos`, expande ou recolhe a seção |
| `d` | Abre a apresentação alternativa (aba do diffview) |
| `D` | Abre as três versões de um conflito ao lado do painel |
| `o` | Abre o arquivo na janela ao lado do painel |
| `O` | Abre o arquivo num split |
| `e` | Vê o arquivo como ele está em outro rev, escolhido numa busca |
| `E` | Compara o arquivo atual com a versão dele em outro rev |
| `v` | Marca o arquivo como visto, ou desmarca |
| `a` | Anota o arquivo inteiro, sem linha (entrada de uma linha) |
| `A` | Anota o arquivo inteiro na entrada de várias linhas |
| `R` | Gera o relatório da revisão e põe os pontos anotados na quickfix |
| `c` | Abre o grafo com os commits de todas as branches, ao lado do painel |
| `C` | Abre o grafo na apresentação alternativa (gitgraph) |
| `w` | Volta do modo commit para o working tree |
| `s` | Move a mudança para staged |
| `u` | Tira a mudança de staged |
| `X` | Descarta a mudança, perguntando antes (`Sim` / `Não`) |
| `y` | Copia o caminho a partir da raiz do projeto do arquivo |
| `Y` | Copia o caminho absoluto |
| `r` | Relê o git e redesenha |
| `q` | Fecha o painel |

Num arquivo conflitado: `<CR>` abre o merge tool de três vias e `d` o layout que
mostra também a versão base; `s` marca a resolução que estiver no disco; `u` e
`X` recusam com uma mensagem — desfazer merge é do merge tool, não da lista.

### Teclas do grafo de commits

Locais ao buffer do grafo, e escritas na linha abaixo do cabeçalho dele.

| Tecla | O que faz |
| --- | --- |
| `<CR>` | Revisa o commit da linha (o clique esquerdo faz o mesmo) |
| `V<CR>` | Revisa o intervalo das linhas selecionadas |
| `b` | Reabre o grafo restrito a uma branch escolhida numa busca |
| `q` | Fecha o grafo sem escolher nada |

### Modo commit

`c` abre o grafo dos commits de todas as branches na janela ao lado do painel,
com a lista ainda visível. `<CR>` (ou o clique esquerdo) numa linha do grafo põe
os arquivos daquele commit no painel: mesma seção com contagem, mesma seção
`Vistos`, mesmas teclas. O cabeçalho passa a trazer o commit em vez da branch, e
`w` volta ao working tree. `q` fecha o grafo sem escolher nada.

`b` filtra o grafo por branch: a busca lista as branches do repositório —
locais e remotas, mais recentes primeiro — e escolher uma reabre o grafo só com
os commits dela, com o nome dela no cabeçalho. A primeira opção da busca,
`todas as branches`, tira o filtro. O filtro é o grafo reaberto pedindo ao git só
aquela branch; não há filtro dentro do desenho.

No modo commit, `<CR>` numa linha abre o diff do commit contra o pai dele — os
dois lados são revs, nenhum é o arquivo no disco. Um merge mostra o que ele
trouxe em relação ao primeiro pai; o primeiro commit do repositório mostra o que
ele criou, com o lado esquerdo vazio. `s`, `u` e `X` recusam com uma mensagem: o
que está commitado é história, e essas três teclas mexem no working tree.

### Modo intervalo

Selecionar mais de uma linha do grafo (`V` e `j`/`k`) e apertar `<CR>` revisa o
intervalo inteiro, que é o gesto de ler uma feature completa de uma vez. As duas
pontas entram: o intervalo começa antes do commit mais antigo selecionado.

O que o painel lista é a diferença entre as duas pontas, e não a soma dos
commits um a um — um arquivo criado e apagado dentro do intervalo não aparece,
porque não sobrou nada nele para ler. Pelo mesmo motivo os merges no meio do
caminho não pedem nada de especial: comparar duas árvores não tem commit nenhum
para ter pais. O cabeçalho traz `<mais antigo>^..<mais novo> · N commits` — com
o `^` porque o commit mais antigo entra na revisão, e `a..b` diria a quem lê git
que ele está de fora. `<CR>` numa linha abre o diff do arquivo entre as duas
pontas, e `d` abre o mesmo intervalo no diffview.

Um intervalo que começa no primeiro commit do repositório compara com o que não
havia: os arquivos aparecem como adicionados e o lado esquerdo do diff é vazio.
Selecionar uma linha só é o mesmo que escolher aquele commit.

Os dois commits têm que estar na mesma linha da história. O grafo desenha todas
as branches, então duas linhas vizinhas na tela podem ser de branches que
divergiram: comparar as duas pontas listaria tudo o que difere entre elas, que
não é intervalo nenhum. Nesse caso a tecla avisa e o painel fica como está.

O visto atravessa os modos por construção, porque é do conteúdo e não do caminho
(ADR-0002): um texto marcado como visto revisando um commit já aparece visto no
working tree. As anotações, ao contrário, são de um modo só — as de um commit
não contam nas linhas do working tree, e o relatório de cada modo é um documento
seu.

`C` desenha o mesmo histórico com o gitgraph, que é a apresentação alternativa
(as duas ficam ligadas ao mesmo tempo, ADR-0006). Escolher um commit lá faz
exatamente o mesmo que escolher no grafo do painel.

`D` é a terceira apresentação de conflito, e a única que não troca de aba: as
três versões que o git guarda no índice — a atual, a base e a que está entrando,
nessa ordem da esquerda para a direita — aparecem juntas ao lado do painel, com
a lista ainda visível. Ela só mostra: escolher lado continua sendo no merge
tool. Fora de um conflito, `D` avisa em vez de abrir. As três teclas de conflito
são de propósito redundantes, para serem comparadas em uso.

### O arquivo em outro rev

`e` e `E` são o mesmo par: o arquivo da linha, em outra versão. A busca é a
mesma dos dois — as branches do repositório primeiro, depois os commits daquele
arquivo, cada um com o sha curto, a data e o assunto —, e é por ela que nunca é
preciso digitar sha. Com um picker instalado, é ele quem desenha a lista.

`e` abre a versão daquele rev num buffer somente leitura ao lado do painel,
nomeado `review://<rev>/<caminho>`, que é como se sabe qual versão está na tela.
É consulta, não arquivo para editar. `q` ali volta: a janela recebe de volta o
arquivo que estava sendo lido — o mesmo que o diff tinha do lado direito — e o
cursor volta ao painel. Se o rev não tiver o arquivo, `e` avisa em vez de abrir
um buffer vazio.

`E` compara: a versão daquele rev à esquerda, o que o painel está revisando à
direita — o arquivo no disco no working tree, e a versão do próprio commit no
modo commit, onde os dois lados são história como no diff da linha. É o mesmo
diff de duas vias que `<CR>` monta. Aqui um rev que não tem o arquivo é um lado
vazio, que é o que ele é.

Num arquivo renomeado os dois procuram pelos dois nomes: a busca lista a
história do nome antigo junto com a do novo — sem isso uma renomeação ainda não
commitada não teria história nenhuma —, e o rev é lido pelo nome que ele tem,
que é o antigo em qualquer rev anterior à renomeação.

### Entrada de várias linhas

A janela que `A` e `<Leader>gA` abrem (as teclas estão escritas na borda dela).

| Tecla | O que faz |
| --- | --- |
| `<C-s>` (normal e insert) | Grava a anotação |
| `q` (normal) | Cancela |

Fechar a janela de qualquer outro jeito também é desistir da anotação.

### Mouse

| Gesto | O que faz |
| --- | --- |
| Clique esquerdo numa linha | O mesmo que `<CR>` |
| Clique direito | Menu de contexto; dentro do painel ele traz as ações acima, cada uma mostrando a sua tecla |

### Depois de `R`

A quickfix fica com um ponto por anotação, na mesma ordem em que o relatório é
lido, e é percorrida com as teclas do editor: `:cnext`, `:cprev`, `:copen`. A
lista anterior continua a um `:colder` de distância.

### Onde as coisas são gravadas

Nunca dentro do repositório revisado, para a revisão não sujar a lista que o
próprio painel está mostrando:

- vistos e anotações: `~/.local/share/nvim/review/<raiz do repo>.json`
- relatório: `~/.local/share/nvim/review/reports/<raiz do repo>-<modo>.md`, com o
  modo sendo `worktree`, `commit-<sha>` ou `range-<sha>..<sha>`

A raiz vai no nome com as barras escapadas (`%2F`). O destino do relatório é
configurável em `lua/polish.lua` (`report_directory`, caminho absoluto).

### Roteiro de teste manual

1. **Abrir** — `cd` num repositório com mudanças e `<Leader>r`. O cabeçalho traz
   a branch e `0/N vistos`; as seções são Conflitos, Staged, Unstaged e
   Untracked. Num diretório que não é repositório, e num repositório sem
   commits, o painel abre com uma mensagem em vez de um erro.
2. **Diff** — `<CR>` numa linha abre o diff de duas vias ao lado; `d` abre a aba
   do diffview; `o` e `O` abrem o arquivo em si.
3. **Conflito** — num repositório com merge conflitado, as três teclas na linha
   do conflito: `<CR>` (merge tool), `d` (com a versão base) e `D` (as três
   versões ao lado do painel, sem trocar de aba). Depois de `D`, `<CR>` em outra
   linha desmonta as três e põe o diff de duas vias no lugar.
4. **Visto** — `v` tira o arquivo da seção e o põe em `Vistos`, recolhida no fim;
   `<CR>` no cabeçalho dela expande. Edite e salve o arquivo: ele volta a
   aparecer como não visto, porque o visto é do conteúdo, não do nome.
5. **Staged/unstaged/descartar** — `s`, `u` e `X`. O `X` pergunta antes, e a
   pergunta diz exatamente o que se perde.
6. **Caminhos** — `y` e `Y`; a notificação mostra o que foi para a área de
   transferência. Num monorepo, `y` sai relativo ao módulo do arquivo (o
   servidor de linguagem tem que estar de pé nele).
7. **Anotar** — `a` no painel anota o arquivo; `o` e depois `<Leader>ga` numa
   linha anota a linha. A contagem aparece na linha do painel (`M  a.txt  ✎ 2`).
   Anotar o mesmo ponto de novo abre a entrada já preenchida e edita a anotação
   que está lá; apagar o texto todo remove a anotação. `A` e `<Leader>gA` abrem
   a entrada de várias linhas.
8. **Relatório** — `R`. A notificação diz onde ele foi gravado; a quickfix abre
   com os pontos, e o cursor fica no painel. Abra o `.md`: as anotações estão
   agrupadas por arquivo, cada uma com a linha e o trecho de código citado.
   `git status` no repositório revisado continua igual ao de antes.
9. **Reancoragem** — anote a linha 2 de um arquivo, insira duas linhas acima
   dela, salve e gere o relatório de novo: a anotação sai na linha 4. Agora
   apague a linha anotada, salve e gere: ela sai na seção `Anotações
   deslocadas`, com o trecho que havia quando foi escrita, e na quickfix marcada
   como `deslocada · …` (o `:cnext` chega nela).
10. **Menu** — clique direito dentro do painel: as entradas mostram a ação e a
    tecla; escolher uma faz o mesmo que a tecla.
11. **Persistência** — `q` e `<Leader>r` de novo: vistos e contagens de anotação
    continuam lá, porque vêm do documento gravado, e não da memória do painel.
    Reabrir também volta para o commit que estava sendo revisado.
12. **Modo commit** — `c` abre o grafo ao lado; os commits das outras branches
    estão lá, com o nome delas na linha. `<CR>` num commit troca o painel para
    ele: o cabeçalho identifica o commit, e todas as teclas continuam valendo.
    `w` volta ao working tree. `C` abre o mesmo histórico no gitgraph, e escolher
    um commit lá faz a mesma coisa.
13. **Visto entre modos** — marque um arquivo como visto revisando um commit e
    volte com `w`: um arquivo do working tree com aquele mesmo texto já está em
    `Vistos`, sem ninguém tê-lo marcado.
14. **Filtro por branch** — `b` no grafo: a busca lista as branches; escolha uma
    e o grafo volta só com os commits dela, com o nome no cabeçalho. `b` de novo
    e `todas as branches` desfaz o filtro. Escolher um commit no grafo filtrado
    funciona como no de sempre.
15. **Intervalo** — no grafo, `V` e `j` sobre dois ou mais commits em fila, e
    `<CR>`: o painel lista o que mudou da ponta mais antiga até a mais nova, o
    cabeçalho traz `a1b2c3d^..e4f5g6h · N commits`, e `<CR>` num arquivo abre o
    diff das duas pontas. Um arquivo que nasceu e morreu dentro do intervalo não
    está na lista. `d` no mesmo arquivo abre o diffview com o intervalo inteiro,
    e não só com o último commit dele. Selecionar duas branches que divergiram
    avisa em vez de listar. `w` volta ao working tree.
16. **Outro rev** — `o` num arquivo mudado e depois `e` nele: a busca lista as
    branches e os commits daquele arquivo; escolha um commit antigo. A versão
    dele abre ao lado, somente leitura, com o rev no nome do buffer, e o editor
    recusa a escrita. `q` devolve o arquivo que estava na janela e o cursor ao
    painel. `E` no mesmo arquivo compara aquela versão com o que está no disco;
    `e` num arquivo untracked, escolhendo uma branch, avisa que ele não existe
    lá.
