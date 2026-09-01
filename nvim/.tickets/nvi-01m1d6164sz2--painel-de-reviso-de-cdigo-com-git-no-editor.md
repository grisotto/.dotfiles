---
id: nvi-01m1d6164sz2
title: Painel de revisão de código com Git no editor
status: open
type: epic
priority: 1
mode: afk
created: '2026-09-01T00:31:15.096596169Z'
updated: '2026-09-01T00:31:17.871730514Z'
assignee: grisotto
tags:
- git
- review
- plugin-local
---

## Description

Painel de revisão de código com Git dentro do Neovim, com o fluxo de trabalho do
IntelliJ: varrer os arquivos que mudaram, marcar o que já foi lido, anotar
observações presas a arquivo e linha, e tirar essas anotações do editor num
documento.

Esta é a spec da funcionalidade inteira. A execução é dividida em três tickets
filhos encadeados por dependência.

## Problem Statement

Revisar um conjunto de mudanças no editor hoje exige montar o fluxo na cabeça a
cada vez:

- Não existe onde registrar que um arquivo já foi lido. Numa revisão de muitos
  arquivos, o revisor perde o fio de onde parou e relê o que já tinha revisado.
- Não existe onde escrever uma observação presa a um arquivo e a uma linha. As
  observações ficam num arquivo de rascunho à parte, sem ligação com o código, e
  reencontrar cada ponto depois é trabalho manual.
- Não existe como transformar essas observações num documento que saia do editor
  para colar num PR, ticket ou mensagem.
- Copiar o caminho de um arquivo alterado — absoluto, ou relativo à raiz do
  projeto — exige sair do fluxo de revisão.
- As ações disponíveis não se descobrem sozinhas. No IntelliJ o revisor clica
  com o botão direito e vê a ação junto do atalho dela; aqui é preciso já saber.
- Revisar os arquivos de um commit qualquer, de qualquer branch, tem exatamente
  os mesmos problemas, e ainda exige sair para outra ferramenta para escolher o
  commit.

Os plugins já instalados resolvem partes vizinhas — o neogit faz o commit
interativo, o diffview faz o diff e o merge tool, o gitsigns marca o gutter —
mas nenhum deles tem estado de revisão por arquivo, e nenhum expõe API para
receber esse estado por cima.

## Solution

Um painel de revisão lateral que lista os arquivos em revisão agrupados por
estado (conflitos, staged, unstaged, untracked), com um contador de progresso no
cabeçalho.

A partir de qualquer linha do painel, com uma tecla ou com o mouse, o revisor:
abre o diff daquele arquivo, abre o arquivo em si, marca ou desmarca o arquivo
como visto, copia o caminho absoluto ou o caminho relativo à raiz do projeto,
move o arquivo entre staged e unstaged, ou escreve uma anotação.

Arquivos vistos saem das suas seções e vão para uma seção "Vistos" recolhida no
fim, de onde podem voltar. Como o visto identifica o conteúdo e não o nome
(ADR-0002), um arquivo que muda depois de marcado volta a aparecer como não
visto.

As anotações são presas a um arquivo e opcionalmente a uma linha, e ficam
guardadas fora do repositório revisado (ADR-0004). Um atalho gera o relatório de
revisão — um documento com as anotações agrupadas por arquivo, cada uma com o
trecho citado — e simultaneamente popula a quickfix, para o revisor voltar a
cada ponto sem reabrir nada.

O mesmo painel troca de modo: em vez do working tree, passa a listar os arquivos
de um commit ou de um intervalo de commits escolhido num grafo de todas as
branches. Todas as teclas continuam valendo, e o visto e as anotações funcionam
igual.

## User Stories

1. Como revisor, quero abrir o painel de revisão com um atalho, para começar a
   revisar sem digitar comando.
2. Como revisor, quero ver os arquivos alterados agrupados por estado, para
   saber o que já está staged e o que ainda não.
3. Como revisor, quero que arquivos com mudanças staged e unstaged ao mesmo
   tempo apareçam nas duas seções, para não confundir duas mudanças diferentes
   no mesmo arquivo.
4. Como revisor, quero ver os conflitos numa seção própria no topo, para tratá-los
   antes de qualquer outra coisa.
5. Como revisor, quero ver quantos arquivos há em cada seção, para dimensionar o
   trabalho.
6. Como revisor, quero ver no cabeçalho quantos arquivos já foram vistos do
   total, para saber quanto falta.
7. Como revisor, quero ver a branch atual no cabeçalho do painel, para não
   revisar na branch errada.
8. Como revisor, quero abrir o diff de um arquivo com Enter, para ler a mudança.
9. Como revisor, quero que o diff abra ao lado do painel sem trocar de aba, para
   continuar vendo a lista enquanto leio.
10. Como revisor, quero abrir o mesmo diff no diffview com outra tecla, para
    comparar as duas apresentações durante o uso e decidir qual prefiro
    (ADR-0006).
11. Como revisor, quero que o diff de uma linha da seção staged compare o HEAD
    com o índice, e o de uma linha unstaged compare o índice com o working tree,
    para ler exatamente a mudança daquela seção.
12. Como revisor, quero que um arquivo conflitado abra no merge tool de três
    vias, com a versão atual à esquerda, o merge no meio e a versão que está
    entrando à direita, para resolver o conflito.
13. Como revisor, quero uma segunda tecla que abra o mesmo conflito num layout
    que também mostra a versão base, para escolher qual layout me serve.
14. Como revisor, quero um terceiro modo de conflito construído no próprio
    painel, para comparar com os dois do diffview antes de fixar um padrão.
15. Como revisor, quero abrir o arquivo de verdade a partir do painel, para
    editá-lo.
16. Como revisor, quero abrir o arquivo num split, para vê-lo junto de outra
    coisa.
17. Como revisor, quero marcar um arquivo como visto com uma tecla, para
    registrar que já li aquilo.
18. Como revisor, quero desmarcar um arquivo visto, para corrigir quando marco
    errado ou quero reler.
19. Como revisor, quero que os arquivos vistos saiam das suas seções e vão para
    uma seção "Vistos" recolhida no fim, para a lista mostrar só o que falta.
20. Como revisor, quero expandir a seção "Vistos", para revisitar o que já li.
21. Como revisor, quero que um arquivo que eu marquei como visto e que mudou
    depois volte a aparecer como não visto, para não deixar passar uma alteração
    nova.
22. Como revisor, quero que o visto sobreviva a fechar e reabrir o editor, para
    retomar a revisão no dia seguinte.
23. Como revisor, quero que um conteúdo que eu já vi revisando um commit apareça
    já como visto no working tree, para não ler duas vezes o mesmo texto.
24. Como revisor, quero copiar o caminho absoluto de um arquivo do painel, para
    colar onde precisar de caminho completo.
25. Como revisor, quero copiar o caminho relativo à raiz do projeto, para colar
    num PR ou mensagem.
26. Como revisor em monorepo, quero que esse caminho relativo seja resolvido
    pela raiz do projeto daquele arquivo, e não pela raiz do repositório, para o
    caminho fazer sentido dentro do módulo.
27. Como revisor, quero mover um arquivo para staged a partir do painel, para
    montar o commit enquanto reviso.
28. Como revisor, quero tirar um arquivo de staged a partir do painel, pelo
    mesmo motivo.
29. Como revisor, quero descartar as mudanças de um arquivo a partir do painel,
    com confirmação antes, para não perder trabalho por engano.
30. Como revisor, quero que o commit em si continue no neogit, para ter mensagem,
    amend e hooks de verdade (ADR-0005).
31. Como revisor, quero clicar num arquivo com o botão esquerdo e abrir o diff,
    para usar o mouse quando estou lendo.
32. Como revisor, quero clicar com o botão direito e ver um menu com as ações
    disponíveis e o atalho de cada uma, para descobrir o que dá para fazer sem
    consultar documentação.
33. Como revisor, quero que as teclas do painel apareçam no which-key, para
    descobri-las pelo teclado.
34. Como revisor, quero que o painel se atualize sozinho quando eu salvo um
    arquivo ou volto para o editor, para não olhar uma lista velha.
35. Como revisor, quero atualizar o painel manualmente, para quando eu mexi no
    git fora do editor.
36. Como revisor, quero escrever uma anotação numa linha do código, para
    registrar o que precisa mudar ali.
37. Como revisor, quero escrever uma anotação de arquivo, sem linha, para
    observações sobre o arquivo inteiro.
38. Como revisor, quero escrever a anotação numa linha só na maior parte das
    vezes, porque quase toda observação é uma frase.
39. Como revisor, quero uma forma de escrever uma anotação longa em várias
    linhas, para quando a observação não cabe numa frase.
40. Como revisor, quero que anotar uma linha que já tem anotação edite a
    existente, para não empilhar observações repetidas no mesmo ponto.
41. Como revisor, quero ver no painel quantas anotações cada arquivo tem, para
    saber onde deixei observações.
42. Como revisor, quero que minhas anotações sobrevivam a editar o arquivo
    depois, para não perder o que escrevi enquanto o código muda (ADR-0003).
43. Como revisor, quero que uma anotação cuja âncora não é mais encontrada me
    seja entregue marcada como deslocada em vez de sumir, para eu decidir o que
    fazer com ela.
44. Como revisor, quero gerar o relatório de revisão com um atalho, para colar as
    observações num PR ou ticket.
45. Como revisor, quero o relatório agrupado por arquivo, com o caminho e a
    linha de cada anotação e o trecho de código citado, para quem lê entender
    sem abrir o repositório.
46. Como revisor, quero que gerar o relatório também popule a quickfix, para
    percorrer meus próprios pontos dentro do editor.
47. Como revisor, quero que o relatório contenha só as anotações do modo atual,
    para o documento ser sobre a revisão que estou fazendo agora.
48. Como revisor, quero que o relatório e as anotações fiquem fora do
    repositório, para a revisão não sujar a lista de arquivos untracked que o
    próprio painel está mostrando (ADR-0004).
49. Como revisor, quero abrir um grafo com os commits de todas as branches, para
    achar o commit que quero revisar.
50. Como revisor, quero filtrar esse grafo por branch, escolhendo a branch numa
    busca, para não procurar no meio de tudo.
51. Como revisor, quero selecionar um commit e ver os arquivos dele no painel,
    para revisá-lo com as mesmas teclas.
52. Como revisor, quero selecionar um intervalo de commits e ver os arquivos do
    intervalo, para revisar uma feature inteira de uma vez.
53. Como revisor, quero ver no cabeçalho qual commit estou revisando, para não
    me perder entre modos.
54. Como revisor, quero voltar do modo commit para o working tree com uma tecla,
    para retomar de onde parei.
55. Como revisor, quero ver um arquivo como ele está em outro commit ou branch,
    para entender como ele era antes.
56. Como revisor, quero comparar o arquivo atual com a versão dele em outro
    commit ou branch, para ver o que mudou entre os dois.
57. Como revisor, quero voltar facilmente do arquivo em outro rev para o que eu
    estava fazendo, para essa consulta não me custar a navegação.
58. Como revisor, quero escolher o rev numa busca que lista branches e os
    commits daquele arquivo, para não digitar sha.
59. Como revisor, quero que o painel abra com uma mensagem, e não com um erro,
    quando estou fora de um repositório ou num repositório sem commits.
60. Como revisor, quero que um arquivo renomeado apareça listado com o caminho
    novo, sem a linha quebrar.
61. Como revisor, quero poder ajustar posição e largura do painel, e onde o
    relatório é gravado, para adaptar ao meu uso.
62. Como revisor, quero poder trocar a apresentação dos vistos entre a seção
    própria e o esmaecido no lugar, para testar as duas.
63. Como revisor, quero que o painel e o neo-tree não briguem pelo mesmo espaço,
    para não perder a lista quando abro a árvore de arquivos.

## Implementation Decisions

### Forma geral

- Plugin local, escrito neste repositório de configuração e carregado como
  módulo — não é um plugin de terceiros nem um fork. Painel próprio, e não
  enxerto nos buffers do neogit ou do diffview (ADR-0001).
- Um único painel com modo (working tree ou commit), e não um painel por
  contexto: o mesmo conjunto de teclas vale em qualquer modo (ADR-0001).
- Delegação explícita (ADR-0005): commit interativo, amend, rebase e push ficam
  com o neogit; diff em aba, comparação com outro rev e merge tool de três vias
  ficam com o diffview; sinais no gutter ficam com o gitsigns. O painel
  implementa apenas mover arquivo entre staged e unstaged e descartar.

### Módulos

- **Leitura do git**: envolve as chamadas ao git e traduz `git status
  --porcelain=v2 -z` em entradas do painel. Um registro pode virar duas
  entradas (staged e unstaged) quando o arquivo tem os dois tipos de mudança.
  Registros de renomeação trazem o caminho antigo num campo separado e precisam
  ser consumidos como tal, sob pena de a linha aparecer corrompida; só o caminho
  novo é exibido.
- **Estado**: carrega e grava o visto e as anotações, indexados pelo caminho da
  raiz do repositório, sob o diretório de dados do editor (ADR-0004). O visto é
  chaveado pelo hash do conteúdo (ADR-0002); os hashes dos arquivos do working
  tree são calculados num único processo, e para conteúdo já identificado pelo
  índice ou pelo HEAD nenhum hash extra é calculado.
- **Painel**: cria e mantém a janela, renderiza as seções e o cabeçalho, guarda
  o mapa de linha para entrada, e trata recolher/expandir seção.
- **Ações**: as operações disparadas de uma linha do painel.
- **Diff**: monta o diff de duas vias na aba do painel e despacha para o
  diffview quando for o caso.
- **Anotações**: criação, edição, âncora e relatório.
- **Modo commit**: integra o grafo de commits e a escolha de branch.

### Contratos e formatos

- O estado persistido é um documento JSON por repositório, com uma versão de
  esquema, o mapa de vistos indexado por hash de conteúdo (cada um guardando o
  caminho e o instante em que foi marcado) e a lista de anotações.
- Cada anotação guarda: caminho, o modo em que foi escrita, a linha (ausente na
  anotação de arquivo), a âncora, o texto e o instante.
- A âncora é o texto da linha no momento em que a anotação foi escrita. Na
  geração do relatório, se o texto da linha guardada não bate mais, a âncora é
  procurada no arquivo e a anotação é reancorada; não sendo encontrada, ela sai
  no relatório marcada como deslocada (ADR-0003).
- O relatório de revisão é um documento markdown agrupado por arquivo, com
  caminho e linha, o trecho citado e o texto da anotação, mais uma seção final
  com as anotações deslocadas. É gravado fora do repositório revisado.

### Teclas

- Um atalho de abertura curto para o painel, mais um grupo de atalhos de revisão
  dentro do grupo de git existente. O atalho curto escolhido está livre nesta
  configuração hoje, mas é reivindicado por um plugin de refactoring do
  astrocommunity que não está importado — se ele for importado um dia, colidem.
- Dentro do painel, as teclas são de uma letra e locais ao buffer.
- Onde havia dúvida real sobre a melhor apresentação de diff, as alternativas
  ficam ligadas ao mesmo tempo em teclas diferentes, e não atrás de uma opção de
  configuração (ADR-0006).

### Configuração

Expostas como opção: posição e largura do painel; apresentação dos vistos
(seção própria ou esmaecido no lugar); forma de entrada da anotação; destino do
relatório; layouts do merge tool; convivência com o neo-tree.

Deliberadamente não expostas, por serem modelo de dados e não preferência: a
chave do visto, a ancoragem da anotação, o painel único com modo e a fronteira
com o neogit.

### Mouse e descoberta

- Clique esquerdo numa linha abre o diff; clique direito abre um menu de contexto
  cujas entradas mostram a ação e o atalho correspondente.
- O modelo de mouse passa a ser o de menu de contexto globalmente, e não só
  dentro do painel — decisão consciente, para o botão direito ter o mesmo
  comportamento em todo o editor.
- As descrições das teclas do painel alimentam o which-key.

### Raiz do projeto

A raiz do projeto usada no caminho relativo é resolvida pelo detector de raiz já
existente na configuração, que consulta o LSP e cai para marcadores de projeto.
Nenhuma detecção própria é escrita.

### Fases

A execução é dividida em três, para o desenho ser ajustado com o uso antes de
crescer:

1. Painel, leitura do estado do git, navegação, diff, visto, cópia de caminhos,
   staged/unstaged/descartar, mouse e menu, which-key, persistência do visto.
   Autossuficiente: já dá para revisar com ela.
2. Anotações, relatório de revisão e quickfix, e o terceiro modo de conflito
   construído no painel.
3. Modo commit, grafo de commits, filtro por branch, ver e comparar arquivo em
   outro rev.

## Testing Decisions

### O que é um bom teste aqui

O painel de revisão é a interface: o texto renderizado nele é o comportamento
externo. Um bom teste afirma sobre o que o revisor veria e sobre o que aconteceu
com o repositório de verdade — nunca sobre estruturas internas do plugin.

### A costura

Uma só: um Neovim headless, um repositório temporário de verdade montado por um
helper de fixture, a API pública do plugin acionada, e as afirmações feitas
sobre duas coisas apenas:

1. as linhas renderizadas no buffer do painel — seções, contadores do cabeçalho,
   o que está sob "Vistos", a marca de contagem de anotações;
2. o estado real do repositório depois das ações — a saída do git após mover
   arquivos entre staged e unstaged e após descartar.

Testar a tradução do `porcelain=v2` como função isolada foi rejeitado: ela só
importa através do que aparece no painel, e uma costura separada dividiria as
afirmações em dois lugares deixando o caminho real sem cobertura. Pela mesma
razão a persistência não tem teste próprio — ela é verificada reabrindo o painel
e conferindo que o arquivo continua sob "Vistos".

### Ferramenta e prior art

Não há testes neste repositório hoje, então não há prior art interna. O runner é
o busted do plenary, que já está instalado como dependência de outro plugin e
roda em Neovim headless — nenhuma dependência nova entra.

### Situações que o fixture precisa cobrir

Arquivo só staged; só unstaged; staged e unstaged ao mesmo tempo; untracked;
renomeado; deletado; conflitado; repositório sem nenhum commit; diretório que não
é repositório.

### O que fica sem teste, deliberadamente

A delegação ao diffview e ao neogit. São chamadas de uma linha, e cobri-las
exigiria injetar um backend falso — uma segunda costura que existiria só para
provar que uma linha foi executada. O diff construído pelo próprio painel, esse
sim é testado, porque é código nosso.

## Out of Scope

- Qualquer operação de git remoto: fetch, pull, push, criação de PR.
- Commit, amend, rebase e cherry-pick a partir do painel — ficam no neogit.
- Resolução de conflito com lógica própria além do terceiro modo de
  visualização; escolher lado e navegar entre conflitos continua sendo do
  diffview.
- Compartilhar anotações com outras pessoas por qualquer canal automático. O
  relatório de revisão é a única saída, e é manual.
- Anotação no lado esquerdo do diff, isto é, presa a uma linha do rev base.
- Integração com plataformas de code review (GitHub, GitLab) e com os comentários
  de PR delas.
- Blame, histórico de linha e gráfico de contribuição.
- Suporte a submódulos como itens navegáveis no painel.
- Tratamento especial de arquivos binários além de aparecerem na lista.

## Further Notes

- O grafo de commits previsto para a fase 3 vem de um plugin ainda em
  desenvolvimento, que não tem filtro por branch documentado. O filtro será
  obtido reabrindo o grafo já restrito à branch escolhida numa busca, e não por
  uma funcionalidade do plugin.
- Um arquivo conflitado não tem conteúdo no estágio zero do índice, então o diff
  de duas vias do painel não se aplica a ele. É por isso que o Enter num
  conflito vai para o merge tool, e não para o diff comum.
- As teclas quase redundantes de diff e de conflito são propositais e
  temporárias (ADR-0006). Depois que o uso decidir, apagar as perdedoras é uma
  linha cada — mas isso é uma decisão do revisor, não uma limpeza automática.