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

`tests/minimal_init.lua` põe no runtimepath só este repositório, o plenary, o
astrocore e o mini.icons — sem AstroNvim, sem gerenciador de plugins — para que
nenhum teste dependa da configuração real. O astrocore está lá porque o painel
não detecta raiz de projeto nenhuma: ele pergunta ao detector do editor, que é o
rooter do astrocore (veja o quinto item da costura).

O mini.icons está lá porque toda linha do painel começa com o ícone que ele dá:
uma suíte sem ele afirmaria sobre uma tela que o revisor nunca vê. Ele é o único
dos três que precisa de `setup()` no `minimal_init` — é lá que o cache de onde
os ícones saem é montado, e é lá que o `MiniIcons` global aparece, que é como o
painel pergunta se há ícones. O ícone em si não entra nas asserções de linha: o
helper tira a coluna dele (`panel.section`, `panel.current`, `panel.dimmed`), e
ele tem asserção própria, contra o que o `MiniIcons.get` responde para aquele
caminho — um glifo escrito à mão muda quando o mini.icons muda.

`make test-file` roda o busted dentro do editor que o `-u` iniciou. O
`PlenaryBustedFile` abriria outro editor, e esse outro não recebe `-u` nenhum:
o teste rodaria contra a configuração real, com o que o gerenciador de plugins
tivesse carregado nela.

## A costura

Uma só, definida na spec do épico (`nvi-01m1d6164sz2`): Neovim headless, um
repositório temporário de verdade montado pelo fixture, a API pública do plugin
acionada, e as afirmações feitas sobre cinco coisas apenas:

1. as linhas renderizadas no buffer do painel, e o que ele desenha sobre elas
   (o esmaecido de um arquivo visto, lido por `panel.dimmed`; a cor do ícone e
   a do código de status, lidas por `panel.highlights`) e ao lado delas (o
   `+N −M`, que é virtual text alinhado à direita, lido por `panel.numbers`);
2. o estado real do repositório depois das ações;
3. o que o painel põe na tela ao lado dele: as janelas em modo diff que ele
   monta, o conteúdo de cada lado, a winbar de cada uma — o lado que ela mostra
   e as teclas que o diff atende —, o arquivo que ele abre, e a winbar da
   própria janela do painel, com a tecla que lista todas as outras;
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
    (`graph.choose_range`);
13. a tabela de mapeamentos do próprio editor
    (`nvim_buf_get_keymap`): a descrição que cada tecla do painel carrega, que é
    o que o which-key mostra, e a espera do `nowait` na tecla que também é o
    Leader do revisor — e, por `maparg`, as teclas globais de anotar que o
    `setup` mapeia: que elas estão lá, com a tecla das opções, e que o diff não
    põe uma dele por cima;
14. o que ele diz em voz alta, lido da UI de notificação do editor de teste
    (`notify.messages`, `notify.last`), que é onde a mensagem aparece para o
    revisor.

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

j décimo quarto entrou com o par que anda pelas mudanças de dentro do arquivo
(`]c` e `[c`): na ponta do arquivo a tecla não move nada, e a mensagem é a
resposta inteira — sem ela o teste não distinguiria a tecla que avisou da tecla
que não fez nada, que é justamente a diferença que o revisor sente. É a mesma
ideia do quinto e do sexto: a tela aqui é uma UI do editor, e é dela que o teste
lê. As outras mensagens do painel continuam sem asserção, porque nelas a
mensagem acompanha um efeito que já é lido — o `git status` depois da recusa, a
lista depois da volta ao working tree.

A ida ao arquivo e a volta (`go` e `<C-o>`) são lidas pelo terceiro item e pelo
primeiro: qual buffer está na janela ao lado do painel e em que linha o cursor
parou, mais as janelas em modo diff — nenhuma, depois do `go`; as duas de volta,
depois da volta. A jumplist não é afirmada: o que se afirma é onde o revisor
está, que é o que ele vê. A tecla é lida da tabela de mapeamentos (décimo
terceiro item) no teste de que ela sai do arquivo do revisor quando outro diff é
montado — uma tecla nossa esquecida no arquivo dele é o que esse teste existe
para impedir.

A anotação de um trecho não trouxe item novo além de uma leitura: o modo em que
o editor ficou (`vim.fn.mode()`), que é o que o revisor vê no canto da tela.
Sair do modo visual antes de a entrada abrir é o que se afirma com ela — uma
entrada aberta por cima de uma seleção ainda viva devolveria ao revisor linhas
selecionadas que ele não pediu. O resto é lido pelo oitavo, pelo nono, pelo
décimo e pelo décimo primeiro: o que a entrada diz (`a.txt:2-3`), o que o
documento guarda (`end_line` e a âncora de várias linhas), o que o relatório
cita e onde a quickfix aponta. A tecla apertada é a de verdade: as teclas
globais de anotar são mapeadas pelo `setup`, que todo spec chama, e a seleção e
a tecla vão ao editor como uma sequência só (`visual.press_on_lines`).

O relatório ir para a área de transferência é lido pelo quinto item, como os
caminhos copiados: o que se afirma é que o texto copiado é o documento gravado.

A ajuda das teclas (`g?`) não trouxe item novo: é uma janela com um buffer,
achada pelo filetype e lida como a entrada longa é lida pelo oitavo item. No
painel o que se afirma é que ela lista, tecla por tecla, o que a tabela de
mapeamentos do buffer descreve (décimo terceiro item) — as duas saem da mesma
lista, e o teste é o que prova que não divergiram. No diff, que ela lista as
teclas que a winbar deixou de escrever e as globais que valem nele. As teclas
que a winbar escreve são lidas pelo terceiro item, como sempre foram.

O painel sair da tela ao ler (`close_on_diff`) também não trouxe item novo: é
lido pelo primeiro e pelo terceiro juntos — se a janela do painel está na tela,
quantas janelas de diff há, onde está o foco, em que linha o cursor do painel
volta e com que largura. A janela do diff é entrada pelo gesto do revisor — a
tecla, ou `nvim_set_current_win` no lugar do `<C-w>l` —, e o `WinEnter` chega
sozinho num editor headless. O que o painel faz com ele é agendado, e o teste
espera pelo painel sair ou voltar (`vim.wait` com a condição), e não por um
tempo. Onde o que se afirma é que ele *não* sai, não há condição a esperar, e a
espera é a de um giro do laço.

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
(`panel.section_count`), as entradas esmaecidas (`panel.dimmed`), o que ele
desenha por cima de uma linha (`panel.highlights`, que devolve o grupo de
destaque de cada trecho pelo texto que ele cobre) e ao lado dela
(`panel.numbers`, o `+N −M` que o numstat contou; nil na linha que não tem
números), põe o cursor
numa entrada de uma seção (`panel.focus("Staged", "a%.txt")` — a seção importa,
porque o mesmo arquivo pode estar listado em mais de uma) ou no cabeçalho de uma
seção (`panel.focus_section "Vistos"`, para expandir e recolher) e manda teclas
para o painel (`panel.feed`). Onde o cursor ficou depois de uma tecla é lido por
`panel.cursor` (a linha) e `panel.current` (o que está escrito nela), que é como
se afirma sobre a tecla que marca e desce para a próxima não vista.

`panel.move` é a tecla que anda pela lista mais o `CursorMoved` que um editor
headless não dispara, que é o gesto que o preview segue; `panel.cursor_moved`
dispara só o evento, no buffer do painel, para o teste que precisa dele com o
revisor em outra janela.

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
(`diff.sides`), o nome de cada buffer (`diff.names`) e a winbar de cada janela
(`diff.winbars`), que é onde o revisor lê qual lado está vendo e como o diff se
fecha. Vale para os dois lados de um diff e para as três versões de um conflito:
o que ele lê é o que está na tela, quantos lados forem.

O mesmo helper manda teclas para o diff (`diff.feed`), diz qual arquivo ele está
mostrando (`diff.reading`) e se o revisor está dentro dele (`diff.focused`), que
é onde as teclas do laço têm que deixá-lo. Em que linha do arquivo o cursor
parou é lido por `diff.cursor`, que é como se afirma sobre as teclas que andam
pelas mudanças de dentro dele, e `diff.to_top` o põe no alto do arquivo, que é
de onde o revisor começa a lê-lo.

`tests/helpers/notify.lua` é a UI de notificação do editor de teste:
`notify.messages()` devolve o que o painel disse, na ordem, e `notify.last()` a
última coisa dita. `notify.install()` num `before_each` e `notify.restore()` num
`after_each`, como a UI de seleção e a de entrada. Ela existe para as teclas em
que a mensagem é a resposta inteira — a ponta do arquivo, em `]c` e `[c`, e o que
impede a revisão de andar quando não é o fim da lista —, e não para conferir o
texto de toda mensagem do painel.

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

`tests/helpers/help.lua` lê a janela de ajuda como o revisor a vê: acha a janela
pelo filetype, devolve o título da borda (`help.title`) e as teclas listadas com
o que cada uma faz (`help.keys`, por tecla), e manda teclas para ela
(`help.feed`), que é como ela se fecha.

`tests/helpers/visual.lua` seleciona linhas na janela em que o revisor está e
aperta uma tecla sobre a seleção (`visual.press_on_lines(2, 3, "<Leader>ga")`),
como o `graph.choose_range` faz no grafo. Uma última linha acima da primeira é
a seleção feita de baixo para cima.

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
os pontos da lista — arquivo, linha, a última linha num ponto de trecho
(`end_lnum`, ausente num ponto de uma linha) e o texto que ela mostra —,
`quickfix.title()`
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

O `WinResized` do editor, que é o que faz o painel tomar como dele a largura
que o revisor lhe deu com ele focado. O editor só o dispara no laço principal,
esperando uma tecla, e um editor headless nunca chega lá: nem redimensionar por
API, nem mandar as teclas de redimensionar o produzem. O teste da largura
adotada faz o gesto do revisor (`<C-w>15<` no painel) e dispara o evento à mão
com `doautocmd`; o que ele afirma é a largura que fica na tela depois de um
acidente de layout, como os outros testes de largura. O ramo que devolve a
largura ao painel é disparado por um `WinClosed`, que é evento comum e chega
sozinho.

Pela mesma razão fica sem teste o `VimResized` que separa o terminal
redimensionado do revisor alargando o painel: os dois eventos são do laço
principal, e um terminal que muda de tamanho não existe num editor headless. O
que se verifica à mão é encolher o terminal com o cursor dentro do painel e
alargá-lo de volta: a lista tem que voltar à largura que tinha, e não ficar com
a que coube no terminal menor.

E pela mesma razão o `CursorMoved`, que é o que faz o preview seguir o cursor da
lista: ele é do laço principal esperando uma tecla, e um editor headless nunca
chega lá — nem a tecla que desce a lista nem `nvim_win_set_cursor` o produzem.
O teste faz o gesto do revisor e dispara o evento à mão (`panel.move`), como o
teste da largura adotada dispara o `WinResized`. Ele é disparado no buffer do
painel e não na janela atual, que é o que também permite dispará-lo de fora do
painel: é assim que a guarda de só desenhar com o painel focado é lida — de
dentro do diff, movendo o cursor da lista como as teclas do laço o movem. O que
se verifica à mão, num editor dentro de um terminal: com o preview ligado, parar
numa linha desenha o diff dela, e segurar o `j` até lá embaixo desenha um só, o
do arquivo em que o cursor parou.

O décimo terceiro entrou com o `<Space>` (`nvi-01m1kh78jhtb`), e é o item que
descreve o que a suíte já lia sem estar escrito aqui: a descrição de cada tecla
do painel, que é o critério de descoberta pelo teclado. A tabela de mapeamentos
é do editor, como o menu de contexto é: o que o teste lê é o que o which-key vai
desenhar, e não uma cópia que o plugin tivesse guardado.

O painel informar por modo (`nvi-01m1kh9b2nak`) não trouxe item novo: ele é lido
pelo sétimo e pelo décimo terceiro juntos, que é o que ele é — as mesmas duas
listas, com três entradas a menos no modo commit. Que as teclas seguem lá é lido
da mesma tabela de mapeamentos: elas estão nela sem descrição, que é o oposto do
que se afirma no working tree.

O laço de dentro do diff (`nvi-01m1kh7rw3p7`) não trouxe item novo: ele é lido
pelo primeiro e pelo terceiro juntos, que é o que ele é — uma tecla apertada no
diff que move o cursor da lista e abre outro diff. O que se afirma é o que os
dois mostram depois dela: qual arquivo está no diff (`diff.reading`, que é o
nome do buffer do terceiro item), em que linha o cursor do painel parou
(`panel.current`) e onde o revisor ficou (`diff.focused`) — deixar o foco no
diff é critério de aceite, e é a única coisa aqui que não é conteúdo de tela.
A tecla é mandada para o diff como as do painel são mandadas para ele
(`diff.feed`), do lado que o revisor está lendo.

O preview (`nvi-01m1kh83jb71`) também não trouxe item novo: ele é lido pelo
primeiro, pelo terceiro e pelo quarto juntos — em que linha da lista o cursor
está, o que apareceu ao lado dela, e quantos processos do git isso custou. O
quarto é o que responde ao critério de não redesenhar: uma entrada que não mudou
seria redesenhada idêntica, e o que separa "não redesenhou" de "redesenhou igual"
são os `git show` que o desenho dispara. A espera do preview é tempo de verdade —
o teste espera pelo que apareceu na tela, como o revisor espera.

A espera do `<Space>`, que é o que deixa os comandos de `<Leader>` de pé dentro
do painel de quem tem o espaço como Leader. O que o teste lê é a tabela de
mapeamentos do próprio editor — a tecla do painel que é o Leader do revisor está
lá sem o `nowait` que todas as outras têm —, e não a espera acontecendo: um
editor headless não espera por tecla nenhuma, e `nvim_feedkeys` entrega a
sequência inteira de uma vez, onde não há ambiguidade que resolver. Que a espera
de fato acontece é verificado à mão, num editor dentro de um terminal: com o
cursor no painel, `<Space>` sozinho marca depois do `timeoutlen`, e `<Space>` mais
a letra de um comando de Leader roda o comando em vez de marcar. Com o which-key
instalado — e ele está — o que se olha é o mesmo gesto com o menu dele no meio:
`<Space>` no painel tem que marcar, e não deixar o revisor dentro do menu do
Leader. Se deixar, quem decide é a regra de uma função só (`acts_at_once`, em
`lua/review/panel.lua`): a tecla volta a agir na hora, e os comandos de Leader
ficam fora do painel.

As teclas do laço serem as mesmas quatro que o editor de verdade escreve no
buffer a cada `FileType` (`]f`, `[f`, `]F`, `[F`, do treesitter do AstroNvim). A
suíte não tem AstroNvim no runtimepath, então o que ela cobre é a regra —
o diff só apaga da tecla o que foi ele que escreveu, e devolve o que estava lá —
e não o encontro com quem as escreve. O que se verifica à mão, num editor com a
configuração real: com o diff montado, `]f` anda a revisão; um `:edit` do lado do
working tree devolve as quatro ao treesitter com o diff ainda de pé, e um `<CR>`
na lista as traz de volta; fechando o diff, `]f` volta a ser "próxima função".

`]c` e `[c` são o caso oposto e ficam sem teste pela mesma razão: elas não são
mapeamento de ninguém — são comando do editor —, então não há o que a suíte
possa ler antes nem depois; o que ela cobre é o que a tecla faz enquanto o diff
está de pé. À mão, num editor com a configuração real: com o diff fechado, `]c`
volta a ser o pulo do próprio editor entre as mudanças de um `:diffthis`, e o
`]g` do gitsigns segue sendo o dele em qualquer arquivo.

O heirline, que escreve a winbar dele por cima da do diff no arquivo do revisor
(veja `debugging.md`). A suíte não tem AstroNvim, então o teste põe no lugar
dele um plugin de mentira que escreve do mesmo jeito — `vim.opt_local.winbar`
de dentro de um autocmd de `BufWinEnter` e `FileType` — e afirma a winbar que
fica na tela depois do giro do laço (terceiro item). O que se verifica à mão,
num editor com a configuração real: com o diff aberto, `:edit` no lado do
working tree e a volta com `<C-o>` depois de um `go` deixam `fechar q` e
`ajuda g?` na barra.

A tecla que a linha do próximo passo nomeia no working tree (`<Leader>gnc`, a
página de commit do neogit). Ela não é nossa e não está nesta configuração: quem
a escreve é o astrocommunity, que não está no runtimepath da suíte, então não há
tabela de mapeamentos em que conferi-la. O que se verifica à mão, num editor com
a configuração real: com tudo visto, a tecla que o painel escreve é a que abre o
neogit. Se ela mudar de lado um dia, é o `NEOGIT_COMMIT` de `lua/review/panel.lua`
que a acompanha.

Onde o clique caiu, que é o que separa um clique numa linha de um clique nas
linhas vazias abaixo da lista (`is_click_on_a_line`, em `lua/review/window.lua`,
usado pelo painel e pelo grafo de commits).
Um editor headless não tem tela nem ponteiro: `nvim_input_mouse` não faz nada
sem uma interface presa nele, e `getmousepos` responde tudo zerado. O teste
manda a soltura do botão pela lista de teclas, que é como o painel a lê de um
script — e é justamente o caso em que a guarda não tem posição para conferir. A
guarda é verificada à mão, com um editor rodando dentro de um terminal: clique
na área vazia abaixo da lista não abre nada, clique na linha abre o diff dela.
Com a winbar do painel ocupando a primeira linha da janela, o que se olha também
é a última linha da lista: o clique nela abre o diff dela, e não é tomado pela
linha vazia abaixo.
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
