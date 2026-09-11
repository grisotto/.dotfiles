# Configuração do Neovim

Configuração pessoal sobre o [AstroNvim](https://github.com/AstroNvim/AstroNvim)
v6, versionada junto com o resto dos dotfiles em `~/projetos/outros/.dotfiles`.

Tem um painel de revisão de código próprio (`lua/review/`); todas as teclas dele
estão em [Painel de revisão](#painel-de-revisão).

## 🛠️ Instalação

Esta pasta **não é copiada** para `~/.config/nvim`: ela é apontada de lá por um
link simbólico, para o repositório continuar sendo o único lugar onde a
configuração existe. Abrir `~/.config/nvim/init.lua` é abrir o arquivo
versionado, e `git status` aqui enxerga o que foi editado dentro do editor.

Requisitos: Neovim **v0.11 ou mais novo** — v0.12 é a recomendada, e é o que o
AstroNvim v6 pede —, `git`, e uma Nerd Font no terminal.

#### Guardar o que já existe

Se a máquina já tem Neovim, os quatro diretórios saem da frente antes do link.
Guardar, e não apagar: estado e cache se refazem sozinhos, mas a configuração
antiga só existe ali.

```shell
mv ~/.config/nvim      ~/.config/nvim.bak
mv ~/.local/share/nvim ~/.local/share/nvim.bak
mv ~/.local/state/nvim ~/.local/state/nvim.bak
mv ~/.cache/nvim       ~/.cache/nvim.bak
```

#### Clonar os dotfiles e criar o link

```shell
git clone https://github.com/grisotto/.dotfiles.git ~/projetos/outros/.dotfiles
ln -s ~/projetos/outros/.dotfiles/nvim ~/.config/nvim
```

O clone vai para o repositório, nunca para `~/.config/nvim`. Clonar em cima do
lugar do link é o que desfaz o arranjo: passam a existir duas cópias da
configuração, e a que o editor lê não é a que o `git` acompanha.

#### Abrir o editor

```shell
nvim
```

Na primeira abertura o lazy.nvim se instala, baixa os plugins, e o Mason instala
servidores e formatadores. Terminado isso, `:checkhealth astronvim` deve vir sem
erro.

#### Dicionário de português

Esta configuração escreve em português (`spelllang = pt_br,en_us`, em
`init.lua`), e o Neovim só traz o dicionário de inglês. O de português se instala
copiando o `.spl` para o diretório `spell/` dos dados do editor:

```shell
mkdir -p ~/.local/share/nvim/site/spell
curl -fLo ~/.local/share/nvim/site/spell/pt.utf-8.spl \
  https://ftp.nluug.nl/pub/vim/runtime/spell/pt.utf-8.spl
```

O arquivo é um só e serve para `pt_br` e `pt_pt`; não há `pt.utf-8.sug` no
espelho, e sem ele o `z=` sugere do mesmo jeito, só sem a lista pré-calculada.

Sem esse arquivo o editor não fica só sem correção ortográfica. O editor de
mensagem do neogit abre com o `spell` ligado (`commit_editor.spell_check`, ligado
por padrão lá), e é ali que o `spellfile.vim` do Neovim pergunta se quer baixar o
dicionário que falta — `No spell file found for pt (utf-8). Download?`. Com o
noice e o snacks desenhando por cima, esse prompt não tem como ser respondido e
volta a cada redesenho, no exato momento em que a mensagem de commit está sendo
escrita.

Por isso o `init.lua` desliga esse plugin (`vim.g.loaded_spellfile_plugin`): o
dicionário que faltar fica faltando, em silêncio, e nada trava. Instalar outro
idioma é a mesma linha acima com outro `.spl`.

## Desenvolvimento do Agilis

Inicie o ambiente em qualquer terminal:

```sh
tmux-agilis3.sh
```

O launcher sobe os containers, o backend com nREPL na porta 7888, o watcher do
Shadow CLJS e a webapp. Dentro de um arquivo do projeto, `<Leader>a` abre no
which-key os comandos específicos:

| Tecla | Comando | O que faz |
| --- | --- | --- |
| `<Leader>ab` | `:AgilisConnectBackend` | Conecta o Conjure ao backend na porta 7888 |
| `<Leader>as` | `:AgilisConnectShadow` | Conecta à porta dinâmica do Shadow e seleciona o build `main` |
| `<Leader>af` | `:AgilisFormat` | Salva e formata o arquivo atual com `bb fmt` |
| `<Leader>at` | `:AgilisTestBrick` | Obtém o brick pelo caminho e executa o teste Polylith dele |
| `<Leader>aT` | `:AgilisTestCljs` | Executa `bb test:cljs` |
| `<Leader>al` | `:AgilisLint` | Executa clj-kondo nos componentes, bases e projetos |
| `<Leader>ah` | `:AgilisHalt` | Para o backend pelo nREPL |
| `<Leader>ao` | `:AgilisOpen` | Abre `http://localhost:3000/` |

Os comandos que produzem saída abrem um terminal horizontal. O format-on-save
fica desligado para Clojure e EDN: este projeto usa `bb fmt`, que combina o
formatador configurado no repositório com reparo de parênteses.

O `<LocalLeader>` é vírgula. Os gestos principais do Conjure são `,ee` para a
forma sob o cursor, `,er` para a forma de topo, `,eb` para o buffer e `,lg` para
o log. `,K` consulta a documentação no REPL; `K` continua sendo o hover do LSP.
`,ts` alterna entre fonte e teste.

Parinfer roda em modo smart e pode ser alternado com `:ParinferToggle`. Paredit
usa `>(`/`>)` para trazer conteúdo para a forma e `<(`/`<)` para expulsá-lo.

## Painel de revisão

A janela lateral que lista os arquivos em revisão, agrupados por estado, e que é
o ponto de partida de toda ação de revisão. Ele tem dois modos: o working tree,
que é como abre, e um commit — ou um intervalo de commits — escolhido no grafo.
As teclas são exatamente as mesmas nos dois.

O painel é um buffer próprio, alimentado por `git status`, e não um enxerto nos
buffers do neogit ou do diffview: ele precisa de estado por arquivo e de teclas
por linha, que nenhum dos dois expõe (ADR-0001). Ele também é um por aba do
Neovim — cada aba tem o seu painel, com o seu repositório e a sua posição de
revisão. Quem revisa dois repositórios ao mesmo tempo põe cada um numa aba
(`:tcd`), e o painel de uma aba nunca mostra o que está na outra.

`<Leader>` é o espaço, como no AstroNvim.

### Teclas globais

Valem em qualquer buffer.

| Tecla | O que faz |
| --- | --- |
| `<Leader>r` | Abre o painel, ou fecha se já estiver aberto |
| `<Leader>ga` | Anota a linha sob o cursor (entrada de uma linha); no modo visual, o trecho |
| `<Leader>gA` | O mesmo, na entrada de várias linhas |
| `<Leader>gv` | Marca como vista a entrada em que a revisão está e abre o diff da próxima não vista |

As duas de anotação valem num arquivo do repositório e no lado de depois — o da
direita — de um diff: no de unstaged ele é o próprio arquivo, e no de staged é o
índice. Não valem no painel, no lado de antes de um diff, nas três versões de um
conflito, na vista em outro rev (`e`) nem num buffer sem arquivo atrás: ali elas
avisam em vez de anotar. A ajuda do diff (`g?`) as lista onde elas valem.

Selecione linhas (`V`) e aperte `<Leader>ga`: a anotação fica presa ao trecho
inteiro, a entrada diz `a.txt:2-4`, e o relatório cita todas as linhas dele. Um
trecho de uma linha só é a anotação daquela linha.

As teclas de anotar e o `<Leader>gv` saem das opções do painel
(`mappings.annotate_line`, `mappings.annotate_line_long` e
`mappings.seen_and_open_next`, em `lua/polish.lua`), e é o `setup` que as
mapeia: por isso a ajuda do diff lista sempre a tecla que está valendo.

### Teclas do painel

Locais ao buffer do painel, e sempre sobre a linha onde o cursor está.

| Tecla | O que faz |
| --- | --- |
| `<CR>` | Abre o diff da linha; no cabeçalho `Vistos`, expande ou recolhe a seção |
| `d` | Abre a apresentação alternativa (aba do diffview) |
| `D` | Abre as três versões de um conflito ao lado do painel |
| `p` | Liga ou desliga o preview: o diff segue o cursor da lista |
| `o` | Abre o arquivo na janela ao lado do painel |
| `O` | Abre o arquivo num split |
| `e` | Vê o arquivo como ele está em outro rev, escolhido numa busca |
| `E` | Compara o arquivo atual com a versão dele em outro rev |
| `v` | Marca o arquivo como visto, ou desmarca |
| `<Space>` | Marca o arquivo como visto e leva à próxima não vista, sem dar a volta |
| `a` | Anota o arquivo inteiro, sem linha (entrada de uma linha) |
| `A` | Anota o arquivo inteiro na entrada de várias linhas |
| `R` | Gera o relatório da revisão para o agente em tags XML, copia para a área de transferência e põe os pontos anotados na quickfix |
| `M` | O mesmo relatório, em markdown |
| `c` | Abre o grafo com os commits de todas as branches, ao lado do painel |
| `C` | Abre o grafo na apresentação alternativa (gitgraph) |
| `w` | Volta do modo commit para o working tree |
| `s` | Move a mudança para staged |
| `u` | Tira a mudança de staged |
| `X` | Descarta a mudança, perguntando antes (`Sim` / `Não`) |
| `y` | Copia o caminho a partir da raiz do projeto do arquivo |
| `Y` | Copia o caminho absoluto |
| `g?` | Mostra todas as teclas do painel, com o que cada uma faz (`q` fecha) |
| `r` | Relê o git e redesenha |
| `q` | Fecha o painel |

A winbar do painel escreve `ver todas as teclas  g?`: as teclas são demais para
uma barra da largura da lista, e a que lista todas elas cabe.

O `<Space>` é o Leader desta configuração, e por isso é a única tecla do painel
que espera o `timeoutlen` antes de agir: os comandos de `<Leader>` continuam
valendo com o cursor na lista, que é onde o revisor mais fica.

Num arquivo conflitado: `<CR>` abre o merge tool de três vias e `d` o layout que
mostra também a versão base; `s` marca a resolução que estiver no disco; `u` e
`X` recusam com uma mensagem — desfazer merge é do merge tool, não da lista.

### Preview

`p` liga e desliga o preview: com ele ligado, o diff da entrada sob o cursor é
desenhado na janela ao lado enquanto o revisor anda pela lista, sem o foco sair
dela. É o mesmo diff que `<CR>` monta — o que muda é só onde fica o foco.

Ele é uma tecla, e não uma opção que se vai mudar na configuração, porque varrer
a lista e ler um arquivo são dois momentos da mesma revisão (ADR-0006): liga-se
o preview para procurar o arquivo e desliga-se ao começar a ler de verdade.

Nesta configuração o painel abre com ele **ligado** (`preview`, em
`lua/polish.lua`): a lista já mostra o diff da linha sob o cursor, e `p` desliga
quando a leitura começa de verdade. O padrão do plugin é o contrário — quem
desce a lista está quase sempre a caminho de um arquivo só, e com o preview
ligado a varredura paga a leitura de todos por onde passa. As duas posições são
uma linha de configuração, e é por isso que o estado inicial é opção e a troca
no meio da revisão é tecla.

Ligar desenha logo o que está sob o cursor, que é a resposta à tecla. Desligar
deixa a tela como está — quem desliga achou o que procurava — e por isso diz em
voz alta que desligou: com o diff ainda ali, nada mais na tela contaria.

### O painel sai da tela ao ler

Com `close_on_diff = true` (ligado em `lua/polish.lua`), entrar no diff de uma
linha tira o painel da tela e dá ao diff a largura inteira do editor: o `<CR>`
num arquivo, e também pular para o diff que o preview desenhou (`<C-w>l`, um
clique). Varrer a lista com o preview ligado não esconde nada — o diff é
desenhado sem o foco sair dela. As três versões de um conflito (`D`) e o arquivo
em outro rev (`e`, `E`) mantêm a lista, que é o motivo de existirem.

A revisão continua andando com a lista fora da tela (`]f`, `]c`, `<Leader>gv`).
O `q` do diff fecha o diff e traz de volta a lista que a entrada no diff tirou:
com a largura dela, ao lado do que o diff deixou na aba (o seu arquivo, no diff
de unstaged), e com o cursor no arquivo que estava sendo lido. A lista que você
fechou por conta própria (`q` no painel, `<Leader>r`) continua fechada, e
`<Leader>r` a traz a qualquer momento. Por que é opção e não tecla, e por que a
lista volta depois de o diff sair, estão nas atualizações dos ADRs 0006 e 0009.

### Descartar

O que `X` apaga é decidido pela seção da linha, e não pelo arquivo (ADR-0007):

| Seção da linha | O que `X` faz |
| --- | --- |
| Unstaged | O arquivo volta ao que está no índice, preservando o que já foi staged |
| Staged | O arquivo volta ao HEAD, no índice e no disco de uma vez |
| Untracked | O arquivo sai do disco, e não dá para recuperar |
| Conflito | Recusa com uma mensagem |

A pergunta feita antes nomeia exatamente o que se perde (`staged e no disco`, no
caso da linha staged) em vez de só dizer o nome do arquivo. Descartar o arquivo
inteiro a partir de qualquer linha, como faz o rollback do IntelliJ, foi
rejeitado: o painel lista a mudança staged e a unstaged do mesmo arquivo como
duas linhas separadas, e uma tecla que apagasse as duas a partir de qualquer uma
contradiria a lista que o revisor está lendo. A linha staged é a exceção assumida
— dela não existe descarte parcial, porque pôr o índice de volta sem tocar no
disco é o que `u` já faz.

Um conflito fica sem `X` e sem `u`: a mudança dele não é uma só — são dois lados
—, e escolher um é resolução de conflito, que é do merge tool. As duas teclas
avisam em vez de escolher um lado caladas, porque um `git reset` num caminho
conflitado jogaria fora os lados que o git guarda no índice e deixaria o arquivo
parecendo mesclado, com os marcadores ainda dentro. O que o painel sabe fazer com
um conflito é o contrário: `s` é o `git add` que registra a resolução já feita no
merge tool.

### Teclas do diff

Locais aos buffers do diff montado ao lado do painel — os dois lados de uma
mudança e as três versões de um conflito —, e escritas na winbar da janela mais
à direita. Elas devolvem ao buffer o que ele tinha nessas teclas quando o diff
sai da tela.

A winbar escreve só duas: `fechar q` e `ajuda g?`. As outras estão na ajuda, a
uma tecla — `g?` abre uma janela com todas as teclas do diff, inclusive as
globais que valem nele, e `q` a fecha. Uma winbar maior que a janela perde o que
fica entre o nome do lado e o fim, e com todas as teclas escritas o que se perdia
eram as teclas — às vezes todas, sobrando só o nome do lado.

A barra do AstroNvim (heirline) escreve a winbar dela a cada vez que um buffer
de arquivo entra numa janela ou tem o filetype definido, e o lado do working
tree é o seu arquivo. Enquanto o diff está aberto, ele escreve a dele de volta
logo depois; fechado o diff, a do heirline volta a valer.

| Tecla | O que faz |
| --- | --- |
| `]c` / `[c` | Vai para a próxima mudança de dentro do arquivo e para a anterior |
| `]f` / `[f` | Abre a próxima não vista e a anterior, sem passar pela lista |
| `]F` / `[F` | O mesmo por todos os arquivos, vistos inclusive |
| `go` | Abre o arquivo no disco no ponto que está sendo lido |
| `<C-o>` | (já no arquivo) traz o diff de volta, quando o pulo sairia dele |
| `q` | Fecha o diff e volta ao painel |
| `<Leader>ga` / `<Leader>gA` | Anota a linha, ou o trecho (as teclas globais, listadas na ajuda) |
| `<Leader>gv` | Marca como visto e abre a próxima não vista (a tecla global, listada na ajuda) |
| `g?` | Mostra todas as teclas do diff, com o que cada uma faz (`q` fecha) |

A ajuda lista `<Leader>ga` e `<Leader>gA` quando o lado da direita aceita
anotação: no diff de unstaged, que é o seu arquivo, e no de staged, que é o
índice. A anotação feita no índice é lida dele — a âncora é o texto do lado
anotado — e é um ponto diferente da mesma linha no disco; na geração do
relatório ela é reancorada no disco, como a do arquivo (veja [Anotações e
reancoragem](#anotações-e-reancoragem)). O lado de antes de qualquer diff — o
`HEAD` no staged, o índice no unstaged — recusa com um aviso, porque o que se
anota é o que a mudança passou a ter; as três versões de um conflito também
recusam, e ali a ajuda não lista as teclas. As teclas globais não são do diff, e
ele não as mapeia nem as tira ao sair.

As quatro andam pela lista sem voltar a ela: movem o cursor do painel, abrem o
diff da entrada e deixam o foco no diff, que é onde o revisor está. A ordem é a
da lista — as seções na ordem em que ela as desenha, caminhos crescentes —, e
não a das linhas na tela: um arquivo já visto continua no lugar dele para o
`]F`, mesmo estando desenhado no fim, dentro da seção `Vistos`. Chegar num deles
abre a seção, que é onde o cursor vai parar. Nenhuma delas dá a volta.

Elas não precisam da lista na tela. Fechar o painel (`q` nele, ou `<Leader>r` de
novo) deixa o diff de pé com a largura inteira do editor, que é como se lê um
arquivo com espaço, e a revisão continua a mesma: as quatro andam por ela, e o
que diz onde ela está é o diff que está montado. Reabrir o painel põe o cursor
na entrada que está sendo lida, e não na que ficou para trás.

`]c` e `[c` são as teclas do próprio editor para as mudanças de um diff, e
respondem o mesmo até a ponta do arquivo. O que o painel acrescenta é a ponta:
na última mudança a tecla diz que é a última e fica onde está; apertada de novo
ali, ela abre o próximo arquivo por ler, na primeira mudança dele. `[c` faz o
simétrico — na primeira mudança avisa, e de novo volta ao arquivo anterior, na
última mudança dele. São duas teclas porque são dois tamanhos do mesmo
movimento: ler uma mudança depois da outra é de dentro do arquivo, e sair dele
termina a leitura daquele arquivo. Uma travessia caladinha na primeira tecla
tiraria da tela o que estava sendo lido.

Só um par de teclas seguidas na mesma ponta atravessa: qualquer tecla que mova
o cursor desarma, então quem volta ao meio do arquivo e chega de novo ao fim é
avisado outra vez. A travessia é a do `]f` — o que falta ler —, e se não houver
próximo arquivo por ler a tecla diz isso, em vez de não responder nada depois de
ter dito que ia abrir o próximo.

O cursor do painel é a posição da revisão (ADR-0009): é ele que `<CR>`, `]f` e
`<Leader>gv` movem, e é dele que sai qual entrada está sendo lida — o arquivo na
tela não diria, porque o mesmo arquivo com mudança staged e unstaged está em
duas linhas da lista. Com a lista fechada quem responde é o diff montado, que
foi construído de uma entrada e por isso não tem essa ambiguidade; numa aba sem
painel nenhum não há revisão para andar, e a tecla diz isso.

`e` e `E` não recebem essas teclas: são consultas de um arquivo, e ali a tecla
que importa é a que devolve a janela ao que estava sendo lido.

Elas só andam a revisão de dentro de uma janela que é lado do diff montado, como
`q` só fecha de lá: o buffer do lado do working tree é o arquivo do revisor, e a
mesma tecla está nele em qualquer outra janela que o mostre — inclusive numa aba
que está revisando outro repositório, onde andar seria mexer numa revisão que
ninguém está olhando.

`go` troca o diff pelo arquivo de verdade, na linha em que o revisor está. Um
diff são duas versões lado a lado e mais nada — sem servidor de linguagem, sem ir
para a definição, sem edição nenhuma quando os dois lados são história —, e quem
leu até uma linha e quer *fazer* alguma coisa ali está pedindo o arquivo. O `o`
do painel também o abre, mas no topo dele; esta abre onde a leitura parou.

Onde é o "ali" sai do **texto** da linha, e não do número dela: o lado que está
sendo lido é uma versão do arquivo — o índice, um commit —, e a numeração de lá
não vale no disco depois de qualquer mudança acima. É a mesma reancoragem das
anotações (ADR-0003), procurando do número para fora, porque de duas linhas
iguais a mais perto de onde o revisor estava é a que ele estava lendo. Linha em
branco e linha curta demais não ancoram nada — metade de um arquivo é `end` —, e
ali o número é o que há. Quando o texto não está no arquivo (uma linha apagada
pelo commit que se está lendo), a tecla vai para o número e diz que foi isso que
fez. No modo commit o que abre é o arquivo de **hoje**: para ver o conteúdo
daquele rev, `e` e `E` continuam sendo as teclas.

A volta é o `<C-o>` do próprio editor, com o diff um passo atrás do arquivo na
jumplist: você entra no arquivo pela linha que estava lendo, anda dali para uma
definição e para outros arquivos, e volta pelo caminho que veio. Enquanto o pulo
é **dentro** do arquivo, o `<C-o>` é o de sempre; o pulo que sairia dele é o que
o diff toma para si — e aí o diff volta, na linha em que estava. Na prática:
`<C-o>` até chegar de novo no arquivo aberto pelo `go`, e mais um.

Essa tecla é escrita no arquivo do revisor e sai de lá quando deixa de valer: ao
voltar ao diff, ou quando outro diff é montado naquela aba. O que estava nela
antes volta.

`]c` e `[c` não precisam ser devolvidas a ninguém quando o diff sai: elas não
são mapeamento de ninguém fora daqui — são comando do editor —, e o que o painel
tira ao sair é o mapeamento dele.

Dentro do arquivo, `]f` e `[f` são "próxima função" do treesitter nesta
configuração. Enquanto o diff está montado eles são a revisão; quando ele fecha,
voltam a ser o que eram. Um `:edit` do lado do working tree devolve as quatro ao
treesitter com o diff ainda montado — o editor as reescreve a cada `FileType` —,
e elas só voltam a ser da revisão quando o diff é remontado (`<CR>` na lista).
O diff não apaga o que não foi ele que escreveu: o que ele tira ao sair é o que
ele pôs.

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
nomeado `<caminho>@<rev>` sob a raiz do repositório, que é como se sabe qual
versão está na tela. O nome fica sob a raiz de propósito: quem lê nome de buffer
como caminho — o neo-tree revela o buffer atual a cada toggle — cai no
repositório que está sendo revisado em vez de sair procurando um diretório que
não existe.
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

### Anotações e reancoragem

Uma anotação se prende a um ponto: o arquivo, o modo, e a linha ou o trecho
quando houver, com a versão em que foram lidos — o arquivo no disco, ou o índice
no diff de staged. A linha 5 do índice e a linha 5 do disco são pontos
diferentes, porque são linhas diferentes. Dois textos escritos no mesmo ponto
são um só, corrigido — anotar de novo abre a entrada já preenchida, e apagar o
texto todo remove a anotação.

Toda anotação tem um tipo, que diz ao agente o que você está pedindo com ela. Ao
anotar — uma linha, um trecho ou o arquivo, na entrada curta ou na longa — o
tipo é escolhido num seletor do editor antes do texto, com a instrução de cada
um ao lado. `<CR>` escolhe o primeiro: `issue` numa anotação nova, e o tipo que
ela já tem numa anotação que está sendo editada. Desistir do seletor é desistir
da anotação, como desistir da entrada. A entrada diz o tipo e o ponto
(`issue em a.clj:42-44`).

| Tipo | O que pede ao agente |
| --- | --- |
| `issue` | Corrigir o problema apontado |
| `refactor` | Refatorar sem mudar o comportamento |
| `test` | Criar ou ajustar o teste |
| `revert` | Desfazer a mudança naquele trecho |
| `question` | Responder, sem tocar no código |
| `suggestion` | Avaliar e aplicar, ou recusar dizendo o motivo |
| `nitpick` | Fazer um ajuste trivial |
| `praise` | Manter como está, também ao refazer o resto |

Os nomes são os do Conventional Comments. `annotation_types`, em
`lua/polish.lua`, acrescenta tipos ao fim da lista e troca a instrução de um que
já existe; o nome é uma palavra, e a instrução é o que o preâmbulo do relatório
diz ao agente:

```lua
annotation_types = {
  { name = "security", instruction = "trate como falha de segurança." }, -- novo
  { name = "question", instruction = "responda aqui, sem tocar no código." }, -- troca
},
```

Uma anotação gravada antes de haver tipo conta como `issue`.

Com `annotation_type_entry = "prefix"`, em `lua/polish.lua`, o seletor não
aparece: o tipo é escrito na frente do texto, e a entrada diz só o ponto
(`a.clj:42-44`). `question: por que isto?` grava uma `question` com o texto
`por que isto?`. Só o nome exato de um tipo configurado conta, sem abreviações:
sem prefixo, ou com um que não é tipo (`nota: …`), a anotação é `issue` e o
texto fica como foi escrito. Ao editar, a entrada vem com `nome: ` na frente do
texto em todo tipo que não é `issue`, e trocar o prefixo troca o tipo. O
`issue` vem sem prefixo, a não ser que o texto dele comece com o nome de um tipo,
o próprio `issue` incluído: aí vem `issue: ` na frente, para gravar sem mexer
não trocar o tipo nem tirar aquele nome do texto. O
padrão é `"select"`, o seletor.

Cada anotação de linha guarda o número da linha e também o texto dela, a âncora
(ADR-0003). Na geração do relatório, se o texto não bate mais, a âncora é
procurada no arquivo e a anotação é reancorada na linha em que está agora; se não
for encontrada, a anotação fica deslocada: entra na mesma lista marcada como
trecho não encontrado, sem linha e com o código que havia quando foi escrita, em
vez de ser descartada ou de apontar para a linha errada. Guardar só o
número faria a anotação apontar para o lugar errado depois de qualquer edição
acima dela, e extmarks resolveriam isso só enquanto o buffer estivesse aberto —
anotações precisam sobreviver a fechar o editor.

A anotação feita no índice é reancorada no disco do mesmo jeito: é o disco que
o agente edita, e a linha que o relatório cita é a do arquivo, achada pelo texto
lido no índice. Quando esse texto não está no disco, ela sai não encontrada. Uma
anotação do working tree gravada antes de haver versão conta como do disco.

A anotação de um trecho guarda a primeira e a última linha, e a âncora dela é o
texto de todas. Ela é reancorada inteira: as linhas têm que estar juntas e na
mesma ordem, e uma delas solta no arquivo não é o trecho. Se qualquer linha do
trecho mudou, ele sai deslocado. O trecho é um ponto diferente da primeira linha
dele — as duas anotações convivem.

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

O botão direito abre menu de contexto em **todo** o editor, e não só no painel
(`mousemodel=popup_setpos`, em `lua/plugins/astrocore.lua`). É de propósito: o
botão direito com dois significados no mesmo editor, decididos pela janela em que
o ponteiro está, faria o revisor descobrir qual é o de agora clicando.

O menu do editor é um só e global, e não propriedade de um buffer: as entradas do
painel entram quando o revisor entra nele e saem quando ele sai, para que o botão
direito em qualquer outro buffer continue mostrando o que sempre mostrou. Clicar
com o direito no painel a partir de outra janela funciona porque o clique leva o
foco para lá primeiro. As entradas próprias do editor — inspecionar, colar, ir
para a definição — ficam abaixo das nossas, separadas por um divisor.

O atalho de cada ação é escrito dentro do texto da entrada, numa coluna alinhada,
e não no campo de acelerador do editor: aquele campo só é desenhado por menu
gráfico, e no terminal não apareceria. Um atalho que ninguém vê perde o motivo de
o menu existir, que é descobrir as teclas sem consultar documentação — por isso o
menu e as teclas saem da mesma lista no código (`panel_actions`, em
`lua/review/panel.lua`), já que duas listas divergiriam.

No modo commit, `s`, `u` e `X` saem do menu e do which-key, mas seguem mapeadas:
quem apertar por hábito recebe a recusa que aponta a tecla de volta ao working
tree. Um menu que oferece o que vai ser recusado é pior do que não ter menu.

### Depois de `R`

O relatório é escrito para o agente de IA que fez a mudança: você cola na
conversa com ele, e ele entende sem você explicar nada. `R` gera em tags XML e
`M` gera o mesmo relatório em markdown — os mesmos itens, na mesma ordem, com os
mesmos ids e o mesmo preâmbulo —, para comparar em uso qual formato o agente
entende melhor (ADR-0006).

O documento inteiro vai para a área de transferência (`+`) e para o registro
sem nome (`"`), no formato da tecla apertada. Cada formato também grava o seu
arquivo, `.xml` ou `.md` (veja [Onde as coisas são gravadas](#onde-as-coisas-são-gravadas)),
e a notificação diz as duas coisas. Numa revisão sem anotação nada é copiado — o
que estava na área de transferência continua lá.

O documento tem três partes, e nenhuma data:

- o cabeçalho: a raiz absoluta do repositório, a branch e o que foi revisado —
  `HEAD <sha>` no working tree, `<sha> <assunto>` num commit e
  `<mais antigo>^..<mais novo>` num intervalo, sempre com o sha inteiro;
- o preâmbulo: que é a revisão humana da mudança dele, o que cada tipo usado
  pede, que não altere nada além do pedido, que localize cada trecho pelo código
  citado, que não faça commit e que responda uma linha por id com `feito`,
  `respondido` ou `recusado: motivo`. Só os tipos que aparecem nos itens são
  explicados, com a instrução da configuração e na ordem dela. A regra do trecho
  não encontrado só aparece quando algum item é assim. O texto vem de um modelo
  que você pode editar (veja [O preâmbulo](#o-preâmbulo));
- os itens, numa lista só, ordenada por arquivo e por linha, com a anotação de
  arquivo antes das de linha. Cada um tem `id`, o tipo escolhido no seletor
  (veja [Anotações e reancoragem](#anotações-e-reancoragem)), arquivo, linhas, o
  código citado exatamente como está e o texto. A anotação de arquivo inteiro vai
  sem linhas e sem código.

```xml
<code_review root="/home/eu/projeto" branch="main" reference="HEAD 4f1c…">
<instructions>
…
</instructions>
<comment id="1" type="issue" file="src/a.clj" lines="42-44">
<code>
(defn soma [a b]
  (- a b))
</code>
O nome diz soma e o corpo subtrai.
</comment>
<comment id="2" type="issue" file="src/b.clj" status="not-found">
…
</comment>
</code_review>
```

No markdown o cabeçalho é o título (`# Code review · <raiz> · branch <b> · <referência>`),
cada item é um `## <id>. <tipo> · <arquivo>:<linhas>` (com
` · trecho não encontrado` quando for o caso) e o código vai numa cerca na
linguagem do arquivo. No XML o texto e o código vão crus, sem entidades: quem lê é
um modelo de linguagem, e não um parser.

A quickfix fica com um ponto por anotação, na ordem dos ids, cada um começando
com `#<id> <tipo>` — que é o que liga o ponto à linha de resposta do agente —, e é
percorrida com as teclas do editor: `:cnext`, `:cprev`, `:copen`. O item cujo
trecho não foi encontrado vai sem linha e diz `não está no disco`. A lista
anterior continua a um `:colder` de distância.

### O preâmbulo

O texto do preâmbulo vem de um arquivo de modelo, que você edita para ajustar o
tom e as regras sem mexer no plugin: `review/preamble.md` no diretório de
configuração do editor (`~/.config/nvim/review/preamble.md`, que nesta
configuração é este repositório: o modelo fica dentro dele, e entra no git se
você o commitar), ou o
caminho absoluto em `preamble_template`, em `lua/polish.lua`. Sem o arquivo,
vale o preâmbulo embutido, o `PREAMBLE` de `lua/review/report.lua`, que é o
ponto de partida para copiar. O arquivo é lido a cada geração — a edição vale no
próximo `R` ou `M`, sem reiniciar o editor —, e os dois formatos levam o mesmo
preâmbulo.

| Marcador | O que o relatório põe no lugar |
| --- | --- |
| `{types}` | A instrução de cada tipo usado nos itens, uma por linha, na ordem da configuração |
| `{reference}` | De qual versão são as linhas citadas |
| `{not_found}` | A regra do trecho não encontrado; vazio quando nenhum item é assim |

Um marcador que o relatório não conhece (`{agente}`) fica no texto como está, e
um que o modelo não traz simplesmente não aparece: um modelo seu nunca quebra a
geração. Linhas em branco seguidas viram uma só, para que um marcador vazio não
deixe um buraco no texto.

### O que é do neogit e do diffview

O painel move arquivo entre staged e unstaged e descarta (`s`, `u`, `X`) porque
esse é o gesto central da revisão e são chamadas diretas ao git. O resto é
delegado (ADR-0005):

| O que | Onde |
| --- | --- |
| Commit interativo, amend, rebase, push | neogit |
| Diff em aba | diffview (`d`) |
| Merge tool 3-way e navegação entre conflitos | diffview (`<CR>` e `d` num conflito) |
| Grafo alternativo | gitgraph (`C`) |

A fronteira parece arbitrária de fora — "por que faz metade das operações de
git?" —, mas reimplementar resolução de conflito significaria reescrever
navegação entre conflitos e escolha de lado, que o diffview já tem prontos e
testados. Quando não há mais nada para ler, a última linha do painel diz qual é o
próximo passo: commitar no neogit, no working tree; gerar o relatório, num commit
ou intervalo.

A comparação com outro rev (`E`) é a exceção, e ficou no painel: ele já monta um
diff de duas vias de um rev contra o arquivo no disco — é o diff do unstaged, com
outro rev à esquerda —, então construí-la é reusar o que existe, enquanto delegar
seria uma apresentação a menos coberta pelos testes.

### Onde as coisas são gravadas

Nunca dentro do repositório revisado, para a revisão não sujar a lista que o
próprio painel está mostrando:

- vistos e anotações: `~/.local/share/nvim/review/<raiz do repo>.json`
- relatório: `~/.local/share/nvim/review/reports/<raiz do repo>-<modo>.xml` (`R`)
  e `<raiz do repo>-<modo>.md` (`M`), cada um regravado a cada geração no seu
  formato, com o modo sendo `worktree`, `commit-<sha>` ou `range-<sha>..<sha>`

A raiz vai no nome com as barras escapadas (`%2F`). O destino do relatório é
configurável em `lua/polish.lua` (`report_directory`, caminho absoluto).

O modelo do preâmbulo não é gravado, é lido: `review/preamble.md` no diretório de
configuração do editor, ou o caminho absoluto em `preamble_template` (veja
[O preâmbulo](#o-preâmbulo)).

Revisão é artefato pessoal e temporário, e escrever no working tree sujaria
justamente a lista que o painel está mostrando: os arquivos da revisão apareceriam
como untracked no meio dela (ADR-0004). A consequência assumida é que nada disso é
compartilhável com o time — quem quiser passar as observações adiante usa o
relatório, que existe exatamente para sair do editor.

### Por que as teclas são redundantes

Onde havia dúvida genuína sobre qual apresentação funciona melhor — diff inline
(`<CR>`) vs. aba do diffview (`d`); os três layouts de conflito (`<CR>`, `d`,
`D`); grafo do painel (`c`) vs. gitgraph (`C`); relatório em XML (`R`) vs.
markdown (`M`) —, todas as alternativas ficam
ligadas ao mesmo tempo, em teclas diferentes, em vez de atrás de uma opção de
configuração (ADR-0006). Uma opção se testa uma vez e nunca mais: o revisor
esquece qual está ativa e nunca compara de verdade. Teclas paralelas permitem
comparar as alternativas no mesmo arquivo, no mesmo minuto, e o que sobrar no uso
vira o padrão. A redundância é temporária e proposital; apagar as perdedoras é uma
linha cada, e só depois que o uso decidir.

A exceção é como um arquivo visto é desenhado (`seen_display`, em
`lua/polish.lua`): `section` o põe na seção recolhida do fim, `dimmed` o deixa
esmaecido onde ele está. Ali as duas apresentações não podem coexistir na tela ao
mesmo tempo, então elas são uma opção — e não duas teclas.

A outra é o painel sair da tela ao ler (`close_on_diff`): ela não escolhe entre
duas apresentações a comparar, e sim quem tira a lista da tela — você, com `q`
ou `<Leader>r`, que continuam valendo, ou também a entrada no diff. Como tecla,
seria um gesto a mais antes de cada arquivo lido, que é o que ela poupa
(atualização do ADR-0006).

E a terceira é como o tipo da anotação é dado (`annotation_type_entry`): no
seletor ou no prefixo do texto. Não são duas apresentações do mesmo resultado, e
sim dois jeitos de escrever que não cabem na mesma entrada — com os dois, o tipo
seria pedido duas vezes.

O porquê de cada decisão acima está em [`docs/adr/`](docs/adr/) — a ida ao
arquivo e a volta por ela são o ADR-0010, e as duas escalas do laço estão na
atualização do ADR-0009.

### Roteiro de teste manual

1. **Abrir** — `cd` num repositório com mudanças e `<Leader>r`. O cabeçalho traz
   a branch e `0/N vistos`; as seções são Conflitos, Staged, Unstaged e
   Untracked. Num diretório que não é repositório, e num repositório sem
   commits, o painel abre com uma mensagem em vez de um erro.
2. **Diff** — `<CR>` numa linha abre o diff de duas vias ao lado; `d` abre a aba
   do diffview; `o` e `O` abrem o arquivo em si. O painel abre com o preview
   ligado: desça a lista e o diff da linha sob o cursor vai sendo desenhado ao
   lado, com o foco na lista; `p` desliga e deixa na tela o diff que estava lá,
   e `p` de novo liga desenhando logo o da linha do cursor. `g?` na lista e
   dentro do diff abre a janela com todas as teclas de onde se está; `q` fecha e
   devolve o cursor. A winbar do diff escreve só `fechar q` e `ajuda g?`, e
   continua inteira num diff estreito. Com `close_on_diff` ligado, o `<CR>`
   esconde a lista e o `q` no diff a traz de volta; com o preview ligado, descer
   a lista não esconde nada, e `<C-w>l` para dentro do diff esconde.
3. **Conflito** — num repositório com merge conflitado, as três teclas na linha
   do conflito: `<CR>` (merge tool), `d` (com a versão base) e `D` (as três
   versões ao lado do painel, sem trocar de aba). Depois de `D`, `<CR>` em outra
   linha desmonta as três e põe o diff de duas vias no lugar.
4. **Visto** — `v` tira o arquivo da seção e o põe em `Vistos`, recolhida no fim;
   `<CR>` no cabeçalho dela expande. Edite e salve o arquivo: ele volta a
   aparecer como não visto, porque o visto é do conteúdo, não do nome.
   `<Space>` marca e desce para a próxima não vista, na ordem em que a lista
   está desenhada e pulando `Vistos`; no último arquivo por ler ele vai para o
   cabeçalho, que é onde está escrito `N/N vistos`. Em cima de um arquivo já
   visto ele desmarca e fica onde está.
5. **O laço de dentro do diff** — `<CR>` numa linha e, sem voltar à lista, `]c`
   e `[c`: o cursor anda de mudança em mudança dentro do arquivo. Na última,
   a tecla avisa e fica onde está; apertada de novo, abre o próximo arquivo por
   ler já na primeira mudança dele. Depois `]f`
   e `[f`: o diff seguinte abre, o cursor do painel anda junto e o foco fica no
   diff. Marque um arquivo do meio como visto e confira que `]f` passa por cima
   dele e que `]F` para nele, abrindo a seção `Vistos` para receber o cursor.
   `<Leader>gv` dentro do arquivo marca o que está sendo lido e abre a próxima
   não vista; no último, o cursor do painel vai para o cabeçalho e o diff fica
   onde está. Feche a lista com `<Leader>r` e repita `]f` e `]c`: com o diff
   sozinho na tela a revisão anda igual, e `<Leader>r` de volta traz o cursor
   para o arquivo que está sendo lido. Com o diff fechado (`q`), `]f` volta a
   ser "próxima função".
6. **Do diff para o arquivo e de volta** — com o diff aberto, desça até uma
   linha mudada e aperte `go`: o arquivo do disco abre no lugar do diff, com o
   cursor naquela mesma linha. Dali pule para uma definição em outro arquivo e
   volte com `<C-o>`: os pulos dentro dos arquivos são os do editor, e o
   primeiro `<C-o>` apertado já de volta no arquivo do `go` traz o diff, na
   linha em que ele ficou. Faça o `go` também do lado esquerdo (a versão do
   índice) depois de inserir linhas acima no disco: ele acha a linha pelo texto,
   e não pelo número. Numa linha que o commit apagou, ele avisa que caiu no
   número.
7. **Staged/unstaged/descartar** — `s`, `u` e `X`. O `X` pergunta antes, e a
   pergunta diz exatamente o que se perde.
8. **Caminhos** — `y` e `Y`; a notificação mostra o que foi para a área de
   transferência. Num monorepo, `y` sai relativo ao módulo do arquivo (o
   servidor de linguagem tem que estar de pé nele).
9. **Anotar** — `a` no painel anota o arquivo; `o` e depois `<Leader>ga` numa
   linha anota a linha. Antes do texto vem o seletor de tipo, com `issue`
   primeiro e a instrução de cada tipo ao lado; escolha `question` e a entrada
   diz `question em a.txt:N`. `<Esc>` no seletor desiste sem pedir texto. A
   contagem aparece na linha do painel (`M  a.txt  ✎ 2`).
   Anotar o mesmo ponto de novo traz o tipo dela primeiro no seletor e abre a
   entrada já preenchida; escolher outro tipo troca o tipo, e apagar o texto
   todo remove a anotação. `A` e `<Leader>gA` passam pelo mesmo seletor e abrem
   a entrada de várias linhas, com o tipo na borda. No arquivo, `V` e `2j` e
   `<Leader>ga`: a entrada diz `:N-M`, e o modo visual já saiu. Com `<CR>` num
   arquivo unstaged ou staged, `g?` no diff lista `<Leader>ga`; nas três versões
   de um conflito (`D`), não. No diff de staged, `<Leader>ga` na linha 2 do lado
   da direita anota o índice; `o` e `<Leader>ga` na linha 2 do arquivo é outra
   anotação, e as duas convivem. Insira uma linha acima no disco, salve e gere o
   relatório: a do índice sai na linha 3, com o texto dela. `<Leader>ga` no lado
   da esquerda de qualquer diff avisa que o lado de antes não se anota. Com um
   `annotation_types` em `lua/polish.lua`, o tipo novo aparece no fim do
   seletor, e o que troca a instrução de um existente aparece com a nova.
   Com `annotation_type_entry = "prefix"`, `<Leader>ga` abre a entrada direto,
   sem seletor, dizendo só `a.txt:N`; escreva `question: por que isto?` e gere
   o relatório: o item é `question` e o texto não tem o prefixo. `nota: algo`
   sai `issue` com o texto inteiro. Anotar o mesmo ponto de novo traz
   `question: por que isto?` na entrada; trocar para `test:` troca o tipo.
10. **Relatório** — `R`. A notificação diz que ele foi copiado e onde foi
   gravado (`….xml`); a quickfix abre com os pontos, cada um começando com
   `#<id> <tipo>`, e o cursor fica no painel. O preâmbulo explica só os tipos
   que aparecem nos itens. Cole (`<C-S-v>` no terminal, ou `p`
   no editor): é o `.xml` inteiro — `<code_review>` com a raiz absoluta, a branch
   e `HEAD <sha>`, sem data; o preâmbulo em `<instructions>`; e um `<comment>` por
   anotação com `id`, `type`, `file`, `lines`, o código citado em `<code>` e o
   texto. A anotação de arquivo inteiro vai sem `lines` e sem `<code>`; o trecho
   anotado sai como `lines="N-M"` com todas as linhas. Agora `M`: o `.md` gravado
   ao lado tem o mesmo cabeçalho no título, o mesmo preâmbulo e os mesmos itens,
   como `## <id>. issue · <arquivo>:<linhas>`, com o código na linguagem do
   arquivo. Menu de contexto, which-key e `g?` no painel mostram `R` e `M`. Num
   commit, o cabeçalho traz o sha inteiro e o assunto; num intervalo,
   `<mais antigo>^..<mais novo>`. `git status` no repositório revisado continua
   igual ao de antes. Crie `~/.config/nvim/review/preamble.md` com
   `Olá, {agente}.`, uma linha em branco e `{types}`, e aperte `R` e `M` de novo:
   o preâmbulo dos dois é esse texto, com `{agente}` como está e a instrução do
   tipo no lugar de `{types}`, e sem referência nem regra do trecho não
   encontrado. Apague o arquivo e gere: o preâmbulo embutido volta.
11. **Reancoragem** — anote a linha 2 de um arquivo, insira duas linhas acima
   dela, salve e gere o relatório de novo: a anotação sai na linha 4. Agora
   apague a linha anotada, salve e gere: ela continua na lista, no lugar dela,
   marcada como não encontrada (`status="not-found"`, ou ` · trecho não
   encontrado` no markdown), sem linhas e com o código que havia quando foi
   escrita; só então o preâmbulo traz a regra do trecho não encontrado. Na
   quickfix ela sai como `#<id> issue · não está no disco · …` (o `:cnext` chega
   nela).
12. **Menu** — clique direito dentro do painel: as entradas mostram a ação e a
    tecla; escolher uma faz o mesmo que a tecla.
13. **Persistência** — `q` e `<Leader>r` de novo: vistos e contagens de anotação
    continuam lá, porque vêm do documento gravado, e não da memória do painel.
    Reabrir também volta para o commit que estava sendo revisado.
14. **Modo commit** — `c` abre o grafo ao lado; os commits das outras branches
    estão lá, com o nome delas na linha. `<CR>` num commit troca o painel para
    ele: o cabeçalho identifica o commit, e todas as teclas continuam valendo.
    `w` volta ao working tree. `C` abre o mesmo histórico no gitgraph, e escolher
    um commit lá faz a mesma coisa.
15. **Visto entre modos** — marque um arquivo como visto revisando um commit e
    volte com `w`: um arquivo do working tree com aquele mesmo texto já está em
    `Vistos`, sem ninguém tê-lo marcado.
16. **Filtro por branch** — `b` no grafo: a busca lista as branches; escolha uma
    e o grafo volta só com os commits dela, com o nome no cabeçalho. `b` de novo
    e `todas as branches` desfaz o filtro. Escolher um commit no grafo filtrado
    funciona como no de sempre.
17. **Intervalo** — no grafo, `V` e `j` sobre dois ou mais commits em fila, e
    `<CR>`: o painel lista o que mudou da ponta mais antiga até a mais nova, o
    cabeçalho traz `a1b2c3d^..e4f5g6h · N commits`, e `<CR>` num arquivo abre o
    diff das duas pontas. Um arquivo que nasceu e morreu dentro do intervalo não
    está na lista. `d` no mesmo arquivo abre o diffview com o intervalo inteiro,
    e não só com o último commit dele. Selecionar duas branches que divergiram
    avisa em vez de listar. `w` volta ao working tree.
18. **Outro rev** — `o` num arquivo mudado e depois `e` nele: a busca lista as
    branches e os commits daquele arquivo; escolha um commit antigo. A versão
    dele abre ao lado, somente leitura, com o rev no nome do buffer, e o editor
    recusa a escrita. `q` devolve o arquivo que estava na janela e o cursor ao
    painel. `E` no mesmo arquivo compara aquela versão com o que está no disco;
    `e` num arquivo untracked, escolhendo uma branch, avisa que ele não existe
    lá.
