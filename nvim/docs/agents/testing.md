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
   revisor é dada (`confirm.answer`).

O terceiro item é a mesma regra dos outros dois — afirmar sobre o que o revisor
vê — aplicada ao que a spec do épico já mandava cobrir: "O diff construído pelo
próprio painel, esse sim é testado, porque é código nosso". Ele entrou aqui
junto com o ticket que abre o diff (`nvi-01m1d6hw839c`); a spec do épico ainda
descreve a costura com dois itens.

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

Nunca sobre estruturas internas do plugin. Testar a tradução do
`git status --porcelain=v2` como função isolada foi rejeitado: ela só importa
através do que aparece no painel. A persistência do visto também não tem teste
próprio: ela é verificada marcando, fechando o painel e reabrindo — o painel não
guarda nada em memória, então o que ele mostra ao reabrir veio do documento
gravado.

## Helpers

`tests/helpers/fixture.lua` monta repositórios temporários com `git` de verdade,
num ambiente que ignora a configuração git da máquina. Sabe montar arquivo só
staged, só unstaged, os dois ao mesmo tempo, untracked, renomeado, deletado,
conflitado (`repo:conflict`), repositório sem commits
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

Um teste de visto abre o painel numa aba própria: o painel vive por aba e
guarda, entre outras coisas, se a seção Vistos está expandida. Reaproveitar a
aba de outro teste carrega esse estado junto.

`tests/helpers/diff.lua` lê o diff que o painel monta: as janelas em modo diff
da aba, da esquerda para a direita (`diff.windows`), o conteúdo de cada lado
(`diff.sides`) e o nome de cada buffer (`diff.names`).

`tests/helpers/clipboard.lua` é a área de transferência do editor de teste:
`clipboard.content()` devolve o que foi copiado e `clipboard.clear()` a esvazia.
Ela é instalada pelo `minimal_init`, e tem que ser antes de qualquer escrita em
registrador — o Neovim resolve o provedor de clipboard uma vez só, na primeira
delas. Sem ela a suíte escreveria na área de transferência de quem está rodando
os testes.

`tests/helpers/confirm.lua` é a UI de seleção do editor de teste, por onde o
painel pergunta antes de descartar: `confirm.answer "Sim"` diz o que o revisor
responde daqui em diante, `confirm.prompts()` devolve as perguntas feitas e
`confirm.restore()` num `after_each` devolve a UI do editor. Sem responder nada,
a pergunta é cancelada — é o padrão de propósito, para um teste que esqueceu de
responder não descartar nada em silêncio.

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
que os testes afirmam sobre ela é o contrário: que o painel *não* monta o diff
de duas vias num conflito, e que a tecla não estoura quando o diffview não está
no runtimepath.

Um pedaço dessa delegação não é chamada de uma linha e merece atenção quando
mudar: para abrir um conflito num layout de merge tool que não é o configurado,
o valor é trocado na configuração do próprio diffview e volta quando a view
fecha (o diffview relê esse valor a cada refresh, então não dá para passá-lo por
chamada). Isso é verificado à mão, com o diffview no runtimepath — inclusive o
caso de abrir um segundo conflito antes de o primeiro fechar, que não pode
guardar como "layout do revisor" um layout nosso.
