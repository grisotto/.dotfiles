# Testes

O runner é o busted do plenary, rodando em Neovim headless. Nenhuma dependência
nova foi instalada para os testes: o plenary já estava aqui como dependência de
outro plugin, e o astrocore é dependência do próprio painel.

## Rodar

```sh
make test                                    # a suíte inteira
make test-file FILE=tests/review/panel_spec.lua   # um arquivo só
make lint                                    # selene
make format                                  # stylua
```

`tests/minimal_init.lua` põe no runtimepath só este repositório, o plenary e o
astrocore — sem AstroNvim, sem gerenciador de plugins — para que nenhum teste
dependa da configuração real. O astrocore está lá porque o painel não detecta
raiz de projeto nenhuma: ele pergunta ao detector do editor, que é o rooter do
astrocore (veja o quinto item da costura).

`make test-file` roda o busted dentro do editor que o `-u` iniciou. O
`PlenaryBustedFile` abriria outro editor, e esse outro não recebe `-u` nenhum:
o teste rodaria contra a configuração real, com o que o gerenciador de plugins
tivesse carregado nela.

## A costura

Uma só, definida na spec do épico (`nvi-01m1d6164sz2`): Neovim headless, um
repositório temporário de verdade montado pelo fixture, a API pública do plugin
acionada, e as afirmações feitas sobre cinco coisas apenas:

1. as linhas renderizadas no buffer do painel, e o que ele desenha sobre elas
   (o esmaecido de um arquivo visto, lido por `panel.dimmed`);
2. o estado real do repositório depois das ações;
3. o que o painel põe na tela ao lado dele: as janelas em modo diff que ele
   monta, o conteúdo de cada lado, e o arquivo que ele abre;
4. os processos `git` que ele dispara para montar a lista, contados por um `git`
   de mentira que fica na frente do PATH (`fixture.trace_git`);
5. o que ele põe na área de transferência, lido do provedor de clipboard do
   editor de teste (`clipboard.content`), e nos registradores do editor;
6. o que ele pergunta antes de uma ação destrutiva, lido da UI de seleção do
   editor de teste (`confirm.prompts`), que é também por onde a resposta do
   revisor é dada (`confirm.answer`);
7. o que ele põe no menu de contexto do editor, lido do menu do próprio editor
   (`menu.entries`, `menu.actions`), que é de onde o menu desenhado na tela sai;
8. o que ele pergunta ao pedir o texto de uma anotação: a entrada de uma linha,
   lida da UI de entrada do editor de teste (`input.prompts`, `input.defaults`,
   e `input.answer` para responder), e a entrada longa, lida da janela que ela
   abre (`entry.lines`, `entry.title`), como o painel é lido;
9. o documento de estado da revisão, lido de volta de onde foi gravado
   (`document.annotations`);
10. o relatório de revisão, lido de volta de onde foi gravado (`report.headings`,
    `report.section`), que é o documento com que o revisor sai do editor;
11. o que ele põe na quickfix do editor, lido da lista do próprio editor
    (`quickfix.items`, `quickfix.is_open`), que é a que o `:cnext` do revisor
    percorre;
12. o grafo de commits que ele monta ao lado do painel, lido como o painel é
    lido: as linhas renderizadas nele (`graph.lines`, `graph.line_matching`), a
    escolha de um commit (`graph.choose`) e a de um intervalo
    (`graph.choose_range`).

O terceiro item é a mesma regra dos outros dois — afirmar sobre o que o revisor
vê — aplicada ao que a spec do épico já mandava cobrir: "O diff construído pelo
próprio painel, esse sim é testado, porque é código nosso". Ele entrou aqui
junto com o ticket que abre o diff (`nvi-01m1d6hw839c`); a spec do épico ainda
descreve a costura com dois itens.

A terceira apresentação de conflito (`nvi-01m1d6hx62xh`) é lida por ele também,
e é a única das três que os testes alcançam: ela é montada por nós, na aba do
painel, enquanto as outras duas são do diffview. As três versões são o que
`diff.sides` devolve, na ordem em que estão na tela, e os nomes dos buffers
(`diff.names`) são como o revisor sabe qual é qual — com três lados, dizer que
o conteúdo está lá não basta.

O quarto entrou com o visto (`nvi-01m1d6hwc7f9`), que tem como critério de
aceite hashear o working tree num processo só. É a única afirmação que não é
sobre o que aparece na tela, e existe porque a alternativa — um processo por
arquivo — não muda nenhuma linha do painel, só o tempo que ele leva para abrir:
não há como observá-la de fora de outro jeito. Ainda assim é comportamento
externo, e não estrutura interna: o que se conta são processos do sistema, não
chamadas de função nossas.

O quinto entrou com a cópia de caminhos (`nvi-01m1d6hwge5g`), onde a área de
transferência é a tela: copiar um caminho não muda nenhuma linha do painel. É
por causa dele que o astrocore está no runtimepath da suíte. O critério de
aceite é sobre monorepo — o caminho sai relativo ao módulo do arquivo, não à
raiz do repositório — e quem responde isso é o detector de raiz do editor,
consultando o servidor de linguagem daquele arquivo. Um detector de mentira
provaria só que multiplicamos strings; o de verdade prova a resposta. Então o
teste de monorepo sobe um servidor de linguagem que não responde nada além do
handshake, enraizado no módulo (`tests/helpers/lsp.lua`), que é tudo o que o
detector lê de um servidor.

O sexto entrou com o descartar (`nvi-01m1d6hwmyc2`), cujo critério de aceite é
que a ação só acontece depois da confirmação. É a mesma ideia do quinto: a
pergunta é feita pela UI do próprio editor (`vim.ui.select`), e o teste lê e
responde a UI do editor de teste — não uma costura de mentira dentro do plugin.
`vim.fn.confirm` não serviria: num editor headless ele devolve sempre a resposta
padrão, e o caminho do "sim" ficaria sem teste.

O filtro por branch (`nvi-01m1d6hxeg2b`) é lido por ele também: a busca em que a
branch é escolhida é a mesma UI de seleção, e o que ela oferece
(`confirm.offered`) é a lista que o revisor vê nela. Com um picker instalado por
cima, é ele quem desenha essa lista; o que o plugin decide é o que vai nela — as
branches do repositório e a volta para todas.

O sétimo entrou com o mouse e o menu de contexto (`nvi-01m1d6hws3y2`), cujo
critério de aceite é o que cada entrada do menu mostra — a ação e o atalho dela —
e onde ela aparece. O menu é do editor, não do plugin: `vim.fn.menu_get` devolve
as entradas na ordem em que o editor as desenha, e `emenu` escolhe uma como o
clique escolhe. É a mesma ideia do quinto e do sexto: a tela aqui é uma UI do
editor, e é dela que o teste lê.

O oitavo entrou com a anotação (`nvi-01m1d6hwxd9p`), cujo critério de aceite é
que a entrada é de uma linha por padrão e que uma segunda tecla abre a longa —
e que anotar de novo o mesmo ponto edita a anotação que está lá. As duas
entradas são do editor: a curta é `vim.ui.input`, lida e respondida como a
pergunta do descartar; a longa é uma janela com um buffer dentro, achada pelo
filetype e lida como o painel. Que a entrada chega preenchida com o texto já
escrito (`input.defaults`) é como a edição se mostra na tela: é por isso que o
revisor sabe que está corrigindo, e não escrevendo do zero.

O nono entrou com a mesma anotação, e é o único que olha o disco fora do
repositório. Uma anotação guarda campos que ninguém consegue ver ainda: a
âncora e o instante só chegam ao revisor pelo relatório, que é a fatia
seguinte, e o critério de aceite manda gravá-los agora. O documento é onde eles
são observáveis, e é o lugar certo para olhá-los — é um artefato persistido com
esquema próprio, o contrato que o relatório vai ler, e não uma estrutura de
dentro do plugin. O helper o acha varrendo o diretório de dados do editor em vez
de remontar o nome que o módulo de estado dá a ele: que o teste o encontre lá é
metade do que ele está afirmando (ADR-0004).

O décimo entrou com o relatório (`nvi-01m1d6hx1mma`), e é a outra metade da
promessa que o nono deixou pendurada: a âncora e a linha só chegam ao revisor
por ele. É onde a reancoragem é observável — a âncora só é procurada na geração
(ADR-0003), e a linha que o relatório escreve é o que a busca achou — e é onde a
anotação deslocada aparece marcada, na seção própria. É lido como o documento de
estado, varrendo o diretório de dados: que ele esteja fora do repositório
revisado é um critério de aceite, não um detalhe de onde procurar.

Uma anotação de outro modo não tem como ser escrita pelo editor hoje — o painel
lista o working tree e mais nada —, e o relatório tem que deixá-la de fora. Ela
é plantada no documento de estado (`document.plant`), que é o contrato entre
quem escreve a anotação e quem a relata, e não uma estrutura de dentro do
plugin.

O décimo primeiro entrou com o mesmo relatório: gerar o documento e popular a
quickfix são a mesma tecla. A lista é do editor, como a UI de entrada e a de
seleção são: o teste lê a lista do próprio editor, que é a que o revisor
percorre com `:cnext`, e não uma cópia que o plugin tivesse guardado.

O décimo segundo entrou com o modo commit (`nvi-01m1d6hxabg5`), cujo primeiro
critério de aceite é sobre o grafo: ele mostra os commits de todas as branches.
O grafo desenhado pelo painel é código nosso, como o diff de duas vias é, e é
lido do mesmo jeito — as linhas que estão na tela. Escolher um commit ali é o
gesto que o critério seguinte descreve, e é por ele que todo teste de modo
commit entra: o modo não é ligado por uma chamada de dentro do plugin, é ligado
por uma tecla numa linha do grafo.

O filtro por branch e o intervalo (`nvi-01m1d6hxeg2b`) entram por ele também, e
pela mesma razão: nenhum dos dois é ligado por uma chamada de dentro do plugin.
O filtro é uma tecla do grafo mais a resposta da busca (`graph.filter_by`), e o
que se afirma é o grafo que volta — quais commits estão nele e o que o cabeçalho
diz. O intervalo é a seleção de linhas do grafo e a mesma tecla que abre uma
(`graph.choose_range`), e o que se afirma é a lista do painel: um arquivo criado
e apagado dentro do intervalo não está nela, que é a diferença entre revisar o
intervalo e revisar o último commit dele.

Ver e comparar um arquivo em outro rev (`nvi-01m1d6hxjmxm`) não trouxe costura
nova: a busca em que o rev é escolhido é a mesma UI de seleção do filtro por
branch, e o que ela oferece (`confirm.offered`) é a lista que o revisor vê — as
branches e os commits daquele arquivo. O que a tecla abre é lido pelo terceiro
item, como o diff de duas vias e as três versões de um conflito são: a vista é
um buffer só, então o que se lê dele é o nome — que é o que diz de que rev ele é
— e o que está nele, direto da janela em que ele abriu. A volta é lida do mesmo
jeito: depois da tecla, o que a janela ao lado do painel está mostrando.

O segundo grafo, o do gitgraph, fica sem teste como a delegação ao diffview e ao
neogit ficam, e pelo mesmo motivo (ADR-0005): é uma chamada de uma linha, e
cobri-la exigiria um backend falso. O que o hook dele faz — `review.commit` — é
exatamente o que o grafo daqui faz, e esse caminho é testado.

Nunca sobre estruturas internas do plugin. Testar a tradução do
`git status --porcelain=v2` como função isolada foi rejeitado: ela só importa
através do que aparece no painel; vale o mesmo para a do `git diff-tree --raw`,
que é como os arquivos de um commit são lidos. A persistência do visto também
não tem teste próprio: ela é verificada marcando, fechando o painel e reabrindo
— o painel não guarda nada em memória, então o que ele mostra ao reabrir veio do
documento gravado. E que o visto atravessa os modos não tem costura nova
nenhuma: é marcar num commit, voltar com uma tecla e olhar a lista do working
tree.

## Helpers

`tests/helpers/fixture.lua` monta repositórios temporários com `git` de verdade,
num ambiente que ignora a configuração git da máquina. Sabe montar arquivo só
staged, só unstaged, os dois ao mesmo tempo, untracked, renomeado, deletado,
conflitado (`repo:conflict`), conflitado sem base — os dois lados criaram o
arquivo, e o índice não tem estágio 1 dele (`repo:conflict_without_base`) —,
repositório sem commits
(`fixture.repo_without_commits`) e diretório que não é repositório
(`fixture.plain_dir`). Também monta um diretório de dados do editor só para o
teste (`fixture.data_dir`), que é onde o estado da revisão é gravado, e o `git`
de mentira que registra as chamadas (`fixture.trace_git`). Chame
`fixture.cleanup()` num `after_each`: é ele que devolve `XDG_DATA_HOME` e `PATH`
ao que eram. O repositório do fixture também é lido de volta, que é como se
afirma sobre o disco depois de uma ação: `repo:read` e `repo:exists`.

`tests/helpers/panel.lua` lê o painel como o revisor o vê: acha a janela pelo
filetype, devolve as linhas renderizadas (`panel.lines`), as entradas de uma
seção (`panel.section "Staged"`), a contagem do cabeçalho de seção
(`panel.section_count`), as entradas esmaecidas (`panel.dimmed`), põe o cursor
numa entrada de uma seção (`panel.focus("Staged", "a%.txt")` — a seção importa,
porque o mesmo arquivo pode estar listado em mais de uma) ou no cabeçalho de uma
seção (`panel.focus_section "Vistos"`, para expandir e recolher) e manda teclas
para o painel (`panel.feed`).

O clique de mouse é mandado em duas metades (`panel.click`, `panel.click_section`
e `panel.click_here`): um editor headless não tem tela para apontar, então pôr o
cursor na linha faz o papel de apertar o botão — que é o que move o cursor para
lá — e o painel reage à soltura. Que o clique de verdade chega assim foi
verificado à mão, com um editor rodando dentro de um terminal.

Um teste de visto abre o painel numa aba própria: o painel vive por aba e
guarda, entre outras coisas, se a seção Vistos está expandida. Reaproveitar a
aba de outro teste carrega esse estado junto.

`tests/helpers/graph.lua` lê o grafo de commits como o revisor o vê: acha a
janela pelo filetype, devolve as linhas (`graph.lines`, `graph.line_matching`) e
a linha em que o cursor está (`graph.current`), e escolhe um commit pelo texto da
linha dele (`graph.choose`), que é pôr o cursor lá e apertar a tecla que abre.
Um intervalo é escolhido pelas duas linhas que o delimitam
(`graph.choose_range`), que é selecioná-las e apertar a mesma tecla, e o filtro
por branch é a tecla que abre a busca mais o que se responde nela
(`graph.filter_by`).

`tests/helpers/diff.lua` lê o diff que o painel monta: as janelas em modo diff
da aba, da esquerda para a direita (`diff.windows`), o conteúdo de cada lado
(`diff.sides`) e o nome de cada buffer (`diff.names`). Vale para os dois lados
de um diff e para as três versões de um conflito: o que ele lê é o que está na
tela, quantos lados forem.

`tests/helpers/clipboard.lua` é a área de transferência do editor de teste:
`clipboard.content()` devolve o que foi copiado e `clipboard.clear()` a esvazia.
Ela é instalada pelo `minimal_init`, e tem que ser antes de qualquer escrita em
registrador — o Neovim resolve o provedor de clipboard uma vez só, na primeira
delas. Sem ela a suíte escreveria na área de transferência de quem está rodando
os testes.

`tests/helpers/confirm.lua` é a UI de seleção do editor de teste, por onde o
painel pergunta antes de descartar e por onde a branch do filtro é escolhida:
`confirm.answer "Sim"` diz o que o revisor responde daqui em diante,
`confirm.prompts()` devolve as perguntas feitas, `confirm.offered()` o que a
última delas deu para escolher, e `confirm.restore()` num `after_each` devolve a
UI do editor. Sem responder nada, a pergunta é cancelada — é o padrão de
propósito, para um teste que esqueceu de responder não descartar nada em
silêncio.

`confirm.answer_matching "primeiro"` escolhe pela linha, e não pelo texto
inteiro dela: é como o revisor escolhe numa busca cujas linhas o teste não tem
como escrever, porque o commit é oferecido com o sha curto dentro e o sha é do
repositório.

`tests/helpers/menu.lua` lê o menu de contexto do editor: `menu.entries()` devolve
as entradas na ordem em que aparecem, `menu.actions()` só as que têm ação e
atalho, na forma tecla → ação, e `menu.choose` escolhe uma pelo texto, que é o
que o clique nela faz.

`tests/helpers/editor.lua` devolve o editor ao estado em que foi encontrado
(`editor.reset()` num `after_each`): uma janela vazia numa aba só, sem buffers
de arquivo sobrando. O buffer do painel sobrevive de propósito — ele é
reaproveitado entre abrir e fechar.

`tests/helpers/input.lua` é a UI de entrada do editor de teste, por onde a
anotação de uma linha é pedida: `input.answer "texto"` diz o que o revisor
escreve daqui em diante, `input.prompts()` devolve o que cada entrada
perguntou e `input.defaults()` com que texto cada uma chegou preenchida.
`input.restore()` num `after_each` devolve a UI do editor. Sem responder nada,
a entrada é cancelada — de propósito, para um teste que esqueceu de escrever
não gravar uma anotação em silêncio.

`tests/helpers/entry.lua` lê a entrada longa como o revisor a vê: acha a janela
pelo filetype, devolve o texto que está nela (`entry.lines`) e o que ela diz
estar anotando (`entry.title`), escreve nela como o revisor escreve
(`entry.type`) e termina pelas duas teclas da borda (`entry.save`,
`entry.cancel`).

`tests/helpers/document.lua` lê de volta o documento de estado gravado no
diretório de dados do editor: `document.annotations()` devolve as anotações e
`document.exists()` diz se a revisão gravou alguma coisa. Ele acha o documento
varrendo o diretório, sem reconstruir o nome que o módulo de estado dá a ele.
`document.plant()` põe nele uma anotação à mão, que é como um teste tem uma
anotação de outro modo — o editor ainda não escreve nenhuma.

`tests/helpers/report.lua` lê de volta o relatório gravado: `report.headings()`
devolve os arquivos por que ele está agrupado, na ordem, mais a seção das
deslocadas quando há uma; `report.section "a.txt"` devolve o que está escrito
sob um deles; `report.lines()` e `report.text()` devolvem o documento inteiro, e
`report.path()` onde ele foi parar — que é como se afirma que não foi parar
dentro do repositório revisado. Ele o acha varrendo o diretório de dados, como o
helper do documento de estado faz.

`tests/helpers/quickfix.lua` lê a quickfix do editor: `quickfix.items()` devolve
os pontos da lista — arquivo, linha e o texto que ela mostra —, `quickfix.title()`
o título que ela recebeu e `quickfix.is_open()` se a janela dela apareceu.
`quickfix.clear()` num `after_each` joga fora as listas que o editor está
guardando, para o teste seguinte não achar as do anterior.

`tests/helpers/lsp.lua` abre um arquivo e prende nele um servidor de linguagem
enraizado num diretório (`lsp.attach(arquivo, raiz)`), que é o que faz o
detector de raiz enxergar um módulo dentro do repositório. `lsp.cleanup()` num
`after_each` derruba os servidores.

`tests/helpers/rooter.lua` dá ao rooter do astrocore a lista de detectores desta
configuração (`rooter.install()`). Ela não vem do astrocore: quem a preenche é o
AstroNvim, que não está na suíte, então um editor headless detectaria nada.

## O que fica sem teste, deliberadamente

A delegação ao diffview e ao neogit: cobri-la exigiria injetar um backend falso
— uma segunda costura que existiria só para provar que a chamada foi feita. O
que os testes afirmam sobre ela é o contrário: que o painel *não* monta diff
nosso nenhum quando a tecla é de uma apresentação do diffview — nem no conflito,
nem fora dele — e que ela não estoura quando o diffview não está no runtimepath.

Onde o clique caiu, que é o que separa um clique numa linha de um clique nas
linhas vazias abaixo da lista (`is_click_on_a_line`, em `lua/review/window.lua`,
usado pelo painel e pelo grafo de commits).
Um editor headless não tem tela nem ponteiro: `nvim_input_mouse` não faz nada
sem uma interface presa nele, e `getmousepos` responde tudo zerado. O teste
manda a soltura do botão pela lista de teclas, que é como o painel a lê de um
script — e é justamente o caso em que a guarda não tem posição para conferir. A
guarda é verificada à mão, com um editor rodando dentro de um terminal: clique
na área vazia abaixo da lista não abre nada, clique na linha abre o diff dela.
Vale o mesmo para o menu do botão direito desenhado na tela; o que o teste lê é
o menu do editor, de onde esse desenho sai.

Um pedaço dessa delegação não é chamada de uma linha e merece atenção quando
mudar: para abrir um conflito num layout de merge tool que não é o configurado,
o valor é trocado na configuração do próprio diffview e volta quando a view
fecha (o diffview relê esse valor a cada refresh, então não dá para passá-lo por
chamada). Isso é verificado à mão, com o diffview no runtimepath — inclusive o
caso de abrir um segundo conflito antes de o primeiro fechar, que não pode
guardar como "layout do revisor" um layout nosso.

Quem devolve o layout é a view fechando, então o caso que a mão tem que cobrir
é o open que não abre view nenhuma (`nvi-01m1ed2q5qzh`): sem view não há o que
fechar, e um layout nosso deixado na configuração ficaria lá. Ele se reproduz
com o diffview de verdade tirando o `.git` de baixo do painel já desenhado — o
diffview recusa o repositório, avisa e não abre nada — e o que se olha depois é
`require("diffview.config").get_config().view.merge_tool.layout`: tem que ser o
do revisor de novo, e o conflito seguinte tem que voltar a conseguir trocá-lo.
Um layout que não existe não é esse caso: o diffview só o recusa no refresh,
que é `vim.schedule`ado, então a view chega a abrir e a fechar normalmente.

A view que devolve o layout é a que o trocou, e não a próxima que fechar seja
qual for (`nvi-01m1fweftw6s`), então há três fechamentos a cobrir além do
simples. Todos se olham do mesmo jeito, no
`require("diffview.config").get_config().view.merge_tool.layout`, com um layout
de revisor configurado que não seja nenhum dos nossos dois — com
`diff3_horizontal` dos dois lados não dá para ver a diferença:

1. abrir o conflito com `<CR>`, voltar ao painel, abrir um arquivo mudado com
   `d` — que é uma view do diffview sem troca nenhuma — e fechar essa segunda:
   o layout tem que continuar sendo o nosso, porque o conflito ainda está
   aberto;
2. o mesmo, mas fechando a segunda aba com `:tabclose` em vez de
   `:DiffviewClose`: é o caminho do `TabClosed` do diffview, que agenda o
   `dispose_stray_views`, que agenda o `view:close()` — o fechamento chega
   atrasado, depois de o conflito já ter trocado o layout;
3. duas views nossas vivas ao mesmo tempo — `<CR>` num conflito e `d` no mesmo
   conflito, que é o layout com a base — fechadas fora de ordem: fechar a
   primeira deixa o layout da segunda, e só o fechamento da segunda devolve o
   do revisor.

No terceiro caso a configuração fica com o layout de uma das duas views vivas —
a mais nova —, e isso não faz mal à outra, o que não é óbvio e já custou um
ticket inteiro (`nvi-01m1h44fpr1h`, fechado por não existir). O layout só é lido
na hora de construir a entrada de um arquivo (`get_updated_files`, em
`scene/views/diff/diff_view.lua`); no refresh o diffview reaproveita a entrada
que já existe, casando pelo caminho justamente para não recriar buffer nenhum, e
o `ensure_layout` remonta a partir do `cur_layout` que a view já tem. E as views
que abrimos são de um arquivo só — os argumentos são `{ "--", <caminho> }` —,
então nenhuma entrada nova entra nelas depois. Uma view nossa lê a configuração
uma vez, quando abre, e o que entra ali depois não a alcança.

É por isso que o que se verifica à mão é a restauração, e não o layout do meio do
caminho: das duas views vivas, cada uma já está montada na sua.
