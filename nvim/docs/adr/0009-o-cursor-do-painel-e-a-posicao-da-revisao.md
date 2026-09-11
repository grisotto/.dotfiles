# O cursor do painel é a posição da revisão

A revisão tem uma posição só, e ela é o cursor do painel. É dele que sai a
resposta para "qual arquivo eu estou revisando", e é ele que todas as teclas do
laço movem: o `<CR>` da lista, o `<Space>` que marca e avança, o `]f` de dentro
do diff e o `<Leader>gv` de dentro do arquivo. A lista e o diff não têm duas
posições que precisem ser mantidas iguais; têm uma, e cada tecla a move de onde
o revisor está.

A alternativa seria o diff saber sozinho o que está mostrando — o arquivo na
tela — e a lista acompanhar como puder. Foi rejeitada porque o arquivo na tela
não identifica a revisão: um arquivo com mudança staged e mudança unstaged está
em duas linhas do painel, são dois diffs para ler e dois vistos para marcar, e
"o arquivo aberto" não diz qual dos dois. Com o cursor como posição, `]f` e
`<Leader>gv` funcionam de dentro do arquivo sem adivinhar nada: eles perguntam à
lista onde a revisão está.

A ordem em que a revisão anda é a ordem da lista — as seções como o revisor as
lê, caminhos crescentes dentro de cada uma —, e não a ordem das linhas na tela.
As duas coincidem para tudo o que falta ler; o que as separa é a seção `Vistos`,
que junta no fim o que já foi lido. Juntar é apresentação: terminar de ler um
arquivo não muda o lugar dele na revisão, e `]F` continua achando o arquivo
anterior onde ele sempre esteve. Quando o cursor vai para uma entrada que está
dentro da seção fechada, a seção abre — a posição da revisão é uma linha, e ela
precisa existir.

Ninguém dá a volta. Chegando ao fim da lista, o `<Space>` leva o cursor ao
cabeçalho, que é onde está escrito `12/12 vistos`. Acima de toda entrada não há
posição nenhuma — e isso não é o mesmo que estar antes da primeira: dali as
teclas do diff não movem nada, em vez de recomeçar pelo topo. O fim da revisão continua sendo uma linha, e não um estado
(ADR-0002: o visto é do conteúdo, e não pertence a uma sessão).

## Consequences

O painel é o dono do laço, e o diff pede a ele para andar — `review.panel` é
carregado na hora em que a tecla é apertada, porque o painel é construído em
cima do diff e essa é a única direção em que os dois se conhecem.

As teclas do laço só andam a revisão de dentro de uma janela que é lado do diff
montado, que é a mesma guarda da tecla que fecha: o lado do working tree é o
buffer do arquivo do revisor, e um mapeamento local a ele existe em toda janela
que o mostre — inclusive numa aba revisando outro repositório, onde a posição que
andaria seria a de uma revisão que ninguém está olhando.

Uma tecla apertada no diff mexe na lista: o cursor anda e a seção `Vistos` pode
abrir. É de propósito — a lista está na tela ao lado, e é nela que o revisor lê
onde está —, mas é o motivo de o painel não poder tratar a posição do cursor
como coisa só dele.

Com o painel fechado não há posição, e as teclas do laço não fazem nada. Isso
não é um caso a tratar: as teclas do diff só existem enquanto o diff está
montado, e o diff é montado pelo painel.

## Atualização: a revisão anda com a lista fechada

O último parágrafo acima estava errado, e o uso mostrou por quê: fechar a lista
não desmonta o diff. `q` no painel — ou o `<Leader>r` de novo — tira a lista da
tela e deixa o diff de pé, ocupando a largura inteira, que é exatamente o que o
revisor faz para ler um arquivo com espaço. As teclas do laço continuavam
mapeadas ali e não faziam nada, caladas, porque procuravam uma janela de painel
que não existia mais. Uma tecla que responde em silêncio é indistinguível de uma
tecla quebrada.

A posição da revisão continua sendo o cursor do painel sempre que ele está na
tela: um revisor que moveu o cursor para outra linha e apertou `]f` está pedindo
para andar dali, e o arquivo na tela não saberia disso. Com a lista fechada,
quem responde onde a revisão está é o diff que está montado — a entrada de que
ele foi construído, que é uma linha da lista e não "o arquivo aberto": o arquivo
com mudança staged e unstaged continua sendo duas entradas, e o diff foi montado
de uma delas. É a alternativa rejeitada acima só onde ela não é ambígua, e só
quando não há lista para perguntar.

O que a revisão andou com a lista fechada fica guardado no estado do painel
(`at`), e o cursor o alcança quando a lista volta: reabrir o painel põe o cursor
na entrada que está sendo lida, e não na que o revisor deixou para trás. Sem
isso o próximo `]f` andaria a partir de uma posição que ninguém viu.

Sem painel nenhum na aba — uma aba que nunca teve um, ou o buffer do arquivo
aberto numa aba que não é a da revisão — não há revisão para andar, e aí a tecla
diz isso em vez de não fazer nada.

## Atualização: as duas escalas do laço (`]c` e `]f`)

O laço tem duas escalas, e elas são duas teclas. `]f` e `[f` andam pelos arquivos
da lista; `]c` e `[c` andam pelas mudanças de dentro do arquivo, que é a tecla do
próprio editor para as mudanças de um diff, tomada enquanto ele está montado.

Elas se encontram na ponta do arquivo, e ali a passagem é de duas teclas: a
primeira diz que aquela é a última mudança e não move nada, a segunda abre o
próximo arquivo por ler, na primeira mudança dele. Atravessar na primeira tecla
foi rejeitado porque as duas escalas não são a mesma coisa: ler uma mudança
depois da outra é dentro do arquivo, e sair dele tira da tela o que estava sendo
lido. Uma tecla que faz as duas coisas sem avisar faz a segunda por engano.

Só duas teclas seguidas na mesma ponta atravessam — qualquer tecla que mova o
cursor desarma —, então quem voltou ao meio do arquivo e chegou de novo ao fim é
avisado outra vez, em vez de sair dele na primeira tecla.

## Atualização: a lista sai da tela ao ler, e volta pelo `q`

Com `close_on_diff` (ADR-0006), entrar no diff de uma linha tira a lista da tela.
A posição da revisão não muda de dono: com a lista fora, quem responde é o diff
montado, como a primeira atualização estabelece, e o cursor alcança a revisão
quando a lista volta.

A direção entre os dois continua a mesma. É o painel que escuta o foco chegar a
um lado do diff (`WinEnter`) e pergunta ao diff se aquele é o diff de uma linha
(`diff.is_line_diff`): o painel é construído em cima do diff e pode perguntar a
ele. O diff só chama o painel na hora em que a tecla que o fecha é apertada
(`back_from_diff`), como as teclas do laço já faziam.

O `q` do diff traz de volta a lista que a entrada no diff tirou, e só ela. A
lista que o revisor fechou por conta própria continua fechada: ele a tirou para
ler com a largura do editor, e fechar o diff não é pedir a lista de novo. E ela
volta depois de o diff sair, e não antes: a última janela do diff fica de pé na
aba, e o painel abre ao lado dela com a largura dele. Aberto antes, o painel
ficava sozinho quando o diff fechava as janelas dele, e tomava a tela inteira.
