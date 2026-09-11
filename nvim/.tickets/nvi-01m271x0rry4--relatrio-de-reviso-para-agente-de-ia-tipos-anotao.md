---
id: nvi-01m271x0rry4
title: 'Relatório de revisão para agente de IA: tipos, anotação no commit e entrega'
status: open
type: feature
priority: 2
mode: afk
created: '2026-09-11T01:39:19.448011637Z'
updated: '2026-09-11T01:39:19.597431337Z'
assignee: grisotto
parent: nvi-01m1d6164sz2
tags:
- git
- review
acceptance:
- title: R gera o relatório em XML e M em markdown, com os mesmos itens, ids e preâmbulo
  done: false
- title: Preâmbulo vem de arquivo de modelo com {types}, {reference} e {not_found}, com padrão embutido
  done: false
- title: Toda anotação tem tipo (8 padrão, issue sem escolha, extras configuráveis), escolhido no seletor ou por prefixo
  done: false
- title: Anotação aceita no lado de depois de unstaged, staged, commit e intervalo; recusada no lado de antes e no arquivo de hoje em modo commit
  done: false
- title: Anotação de commit cita a linha e o código do commit; working tree e staged são reancorados no disco
  done: false
- title: 'Quickfix com #id type, reancorada no disco, item sem linha quando não achado'
  done: false
- title: Gerar entrega as abertas; gerar sem abertas refaz a última entrega congelada; U reabre a última
  done: false
- title: Contagem do painel conta só abertas; anotações antigas continuam válidas sem perder vistos
  done: false
---

## Problem Statement

O revisor usa o painel de revisão para ler o que um agente de IA mudou no código — no working tree (staged ou unstaged) ou já commitado —, escreve anotações sobre linhas, trechos e arquivos, gera o relatório de revisão e cola na conversa com o agente, que ajusta o código.

Hoje isso falha em três pontos:

- O relatório foi escrito para gente ler num PR: agrupado por arquivo, com prosa em volta, sem dizer ao agente o que fazer com cada anotação nem como responder. Uma anotação que é pergunta e uma que é "desfaça isto" chegam iguais.
- No modo commit não dá para anotar o diff do commit: os dois lados são versões, e a anotação é recusada. O único caminho é ir ao arquivo de hoje (`go`) e anotar lá, e aí a linha é do disco, não do commit — num relatório de commit. No diff de staged acontece o mesmo.
- Gerar o relatório de novo traz todas as anotações do modo, inclusive as que já foram entregues ao agente e que ele já resolveu. O revisor anota, entrega, o agente ajusta, o revisor volta a anotar — e o relatório seguinte manda o agente refazer o que já fez.

## Solution

O relatório de revisão passa a ser escrito para o agente de IA que fez a mudança, num formato sucinto e de mercado, em duas apresentações comparáveis: `R` gera em tags XML e `M` em markdown, com o mesmo conteúdo. O documento começa com um preâmbulo que diz ao agente como tratar cada anotação e como responder, e cada anotação é um item numerado com o tipo, o arquivo, as linhas e o código citado. O preâmbulo vem de um arquivo de modelo que o revisor edita.

Toda anotação tem um tipo da anotação, com os nomes do Conventional Comments — `issue` (o padrão), `refactor`, `test`, `revert`, `question`, `suggestion`, `nitpick`, `praise` — e o revisor pode acrescentar outros. O tipo é escolhido num seletor antes do texto, ou, por opção, escrito na frente dele (`question: …`).

A anotação é escrita no lado de depois de qualquer diff: o arquivo no unstaged, o índice no staged, o commit no modo commit e no intervalo. A anotação de um commit fica presa ao commit (ADR-0011): o relatório cita a linha do commit, e o agente a encontra pelo sha. O que é do working tree é reancorado no disco, como hoje.

Gerar o relatório é entregar (ADR-0012): as anotações abertas do modo saem nele e passam a entregues, e o próximo relatório só leva o que for anotado depois. Gerar sem anotação aberta refaz a última entrega exatamente como foi, e uma tecla reabre a última entrega para quando o relatório foi gerado e não foi mandado.

## User Stories

### O documento para o agente

1. Como revisor, quero que o relatório de revisão seja escrito para um agente de IA, para que eu cole na conversa e ele entenda sem eu explicar nada.
2. Como revisor, quero gerar o relatório em tags XML com uma tecla (`R`), para entregar ao agente no formato que a documentação da Anthropic recomenda para misturar instruções e dados.
3. Como revisor, quero gerar o relatório em markdown com outra tecla (`M`), para comparar com o XML qual formato o agente entende melhor.
4. Como revisor, quero que os dois formatos tenham os mesmos itens, na mesma ordem, com os mesmos ids e o mesmo preâmbulo, para que comparar os dois meça só o formato.
5. Como agente de IA, quero um cabeçalho com o caminho absoluto da raiz do repositório, a branch e a referência do que foi revisado, para saber onde e sobre o quê estou agindo mesmo rodando num subdiretório de um monorepo.
6. Como agente de IA, quero que a referência de um commit traga o sha completo e o assunto, para achar o commit sem ambiguidade.
7. Como agente de IA, quero que a referência de um intervalo traga `antigo^..novo`, para saber exatamente quais commits a revisão cobriu.
8. Como agente de IA, quero que a referência do working tree traga o HEAD, para saber sobre qual base as mudanças não commitadas estão.
9. Como revisor, quero que o relatório não traga a data de geração, porque ela é ruído para o agente.
10. Como agente de IA, quero cada anotação como um item com `id`, `type`, `file` e `lines`, para localizar e tratar uma de cada vez.
11. Como agente de IA, quero as linhas anotadas citadas exatamente como estão, sem contexto em volta, para achar o trecho com a minha ferramenta de edição.
12. Como agente de IA, quero que a anotação de arquivo inteiro venha sem linhas e sem código, para não procurar um trecho que não existe.
13. Como agente de IA, quero os itens em lista plana ordenada por arquivo e depois por linha, com a anotação de arquivo antes das de linha, para percorrer o código numa ordem natural.
14. Como agente de IA, quero que no markdown o trecho venha na linguagem do arquivo, para ler como código.
15. Como agente de IA, quero um preâmbulo que diga o que cada tipo usado no relatório pede, para agir certo em cada item.
16. Como revisor, quero que o preâmbulo liste só os tipos usados no relatório, para o documento continuar sucinto.
17. Como revisor, quero que o preâmbulo peça ao agente para não alterar nada além do que as anotações pedem, para que ele não aproveite a rodada para mexer em outras coisas.
18. Como revisor, quero que o preâmbulo peça ao agente para não commitar, porque eu valido antes e peço o commit depois.
19. Como revisor, quero que o preâmbulo peça uma resposta de uma linha por id — `feito`, `respondido` ou `recusado: motivo` —, para conferir a volta item por item.
20. Como agente de IA, quero que o preâmbulo diga de qual versão são as linhas citadas e, num commit, como ver o conteúdo exato (`git show <sha>:<arquivo>`), para não confundir a linha do commit com a do disco.
21. Como revisor, quero editar o texto do preâmbulo num arquivo de modelo, para ajustar o tom e as regras sem mexer no código do plugin.
22. Como revisor, quero que o modelo tenha marcadores para os tipos usados, para a referência e para a regra das anotações não encontradas, para mudar o texto em volta sem perder o que o plugin preenche.
23. Como revisor, quero que um marcador desconhecido fique no texto como está e que um marcador omitido simplesmente não apareça, para que um modelo meu nunca quebre a geração.
24. Como revisor, quero que, sem arquivo de modelo, o relatório use o preâmbulo padrão, para não precisar criar arquivo nenhum para começar.
25. Como agente de IA, quero que uma anotação cujo trecho não foi encontrado venha na mesma lista, marcada como não encontrada, com o código de quando ela foi escrita, para eu mesmo procurar o trecho.
26. Como agente de IA, quero que o preâmbulo só explique o "não encontrado" quando houver item assim, para não ler regra que não se aplica.

### Tipo da anotação

27. Como revisor, quero que toda anotação tenha um tipo, para dizer ao agente se é para corrigir, refatorar, criar teste, desfazer, responder, avaliar, ajustar um detalhe ou manter.
28. Como revisor, quero que sem escolha o tipo seja `issue`, porque quase tudo o que anoto numa mudança de agente é "isto está errado".
29. Como revisor, quero o tipo `revert`, para dizer ao agente que ele mexeu onde não devia.
30. Como revisor, quero o tipo `praise`, para dizer ao agente que aquilo está certo e deve sobreviver ao retrabalho.
31. Como revisor, quero acrescentar tipos meus na configuração, cada um com a instrução ao agente, para cobrir pedidos como `security` ou `docs`.
32. Como revisor, quero trocar a instrução de um tipo padrão na configuração, para ajustar o que o agente entende por ele.
33. Como revisor, quero escolher o tipo num seletor antes de escrever o texto, com a instrução de cada tipo ao lado, para decidir o que estou pedindo antes de escrever.
34. Como revisor, quero que o seletor venha com `issue` primeiro numa anotação nova e com o tipo atual primeiro numa anotação que estou editando, para que `<CR>` escolha o óbvio.
35. Como revisor, quero que desistir do seletor desista da anotação, como desistir da entrada de texto.
36. Como revisor, quero que a entrada de texto diga o tipo e o ponto (`issue em a.clj:42-44`), para confirmar o que estou escrevendo.
37. Como revisor, quero poder ativar por opção o modo prefixo, em que escrevo `question: …` na frente do texto e não aparece seletor, para anotar sem um passo a mais.
38. Como revisor, no modo prefixo, quero que um prefixo que não é tipo conhecido (`nota: …`) seja texto comum com tipo `issue`, para não ter uma frase minha recusada.
39. Como revisor, no modo prefixo, quero que a anotação editada venha preenchida com o prefixo do tipo dela, para trocar o tipo editando o texto.
40. Como revisor, quero que as anotações que já tenho, sem tipo, contem como `issue`, para não perder nada ao atualizar.

### Onde se anota

41. Como revisor, quero anotar uma linha ou um trecho no lado de depois do diff de um commit, para comentar a mudança do agente sem sair do diff.
42. Como revisor, quero anotar no lado de depois do diff de um intervalo, que é o commit mais novo, para revisar a feature inteira do agente de uma vez.
43. Como revisor, quero anotar no lado de depois do diff de staged, que é o índice, para revisar o que o agente deixou staged.
44. Como revisor, quero continuar anotando no arquivo, no unstaged e fora do diff, como hoje.
45. Como revisor, quero que o lado de antes de qualquer diff recuse a anotação com um aviso, porque o que se anota é o que a mudança passou a ter.
46. Como revisor, quero que as três versões de um conflito continuem recusando a anotação.
47. Como revisor, no modo commit, quero que anotar o arquivo de hoje (depois do `go`) seja recusado com um aviso que aponta a volta ao diff (`<C-o>`), para que o relatório de um commit tenha uma referência só.
48. Como revisor, quero que a ajuda do diff (`g?`) liste as teclas de anotar em todo diff cujo lado de depois aceita anotação — unstaged, staged, commit e intervalo.
49. Como revisor, quero que a linha 5 do índice e a linha 5 do disco sejam pontos diferentes, porque são linhas diferentes.
50. Como agente de IA, quero que a anotação de um commit cite a linha e o código do commit, e não do disco, para ir ao commit e ver exatamente o que o revisor leu.
51. Como revisor, quero que a anotação feita no staged seja reancorada no disco na geração, igual à do unstaged, porque é o disco que o agente edita.
52. Como revisor, quero que uma anotação de commit nunca saia como não encontrada, porque o commit não muda.
53. Como revisor, quero que as anotações de modo commit que já fiz no arquivo de hoje sejam reancoradas contra o conteúdo do commit, para virarem anotações do commit quando o texto está lá.

### Quickfix

54. Como revisor, quero que cada item da quickfix comece com `#id type`, para ligar o item à linha de resposta do agente.
55. Como revisor, quero que a quickfix seja reancorada no disco na hora, inclusive num relatório de commit, para andar pelo arquivo de hoje.
56. Como revisor, quero que o item cujo trecho não está no disco vá sem linha e diga que não está no disco, para não pular para uma linha errada.

### Entrega

57. Como revisor, quero que gerar o relatório entregue as anotações abertas do modo, para que o próximo relatório não traga o que o agente já recebeu.
58. Como revisor, quero que gerar de novo sem nenhuma anotação aberta refaça a última entrega, para trocar de formato ou copiar outra vez.
59. Como revisor, quero que refazer uma entrega reproduza exatamente o que o agente recebeu — as linhas e os trechos do momento da geração —, para validar o que ele fez contra o que eu pedi.
60. Como revisor, quero que a notificação diga quando o relatório é uma entrega refeita, para não confundir com uma entrega nova.
61. Como revisor, quero reabrir a última entrega com uma tecla do painel (`U`), para corrigir ou completar um relatório que gerei e não mandei.
62. Como revisor, quero que anotar um ponto que tem anotação entregue comece uma anotação nova, com a entrada vazia, porque depois da entrega é outro pedido.
63. Como revisor, quero que a contagem na linha do painel conte só as anotações abertas, porque é o que falta mandar.
64. Como revisor, quero que as entregas fiquem guardadas no documento de estado.
65. Como revisor, quero que as anotações e entregas de um modo continuem separadas das de outro, para que o relatório de um commit nunca traga anotações do working tree.
66. Como revisor, quero que gerar num modo sem anotação aberta e sem entrega nenhuma continue dizendo que não há o que relatar, sem mexer na área de transferência.
67. Como revisor, quero que `R`, `M` e `U` apareçam no menu de contexto, no which-key e na ajuda do painel, com a descrição de cada uma.

## Implementation Decisions

- **Módulo de relatório** passa a ter três partes separadas: montar os itens de uma entrega (placement com reancoragem por versão), congelar a entrega, e renderizar uma entrega em um formato. A renderização recebe uma entrega congelada e o formato (`xml` ou `markdown`) e não lê repositório nem estado — é o que garante que refazer reproduz exatamente o que foi entregue e que os dois formatos saem da mesma fonte.
- **Item de entrega** (congelado na geração): `id` (a partir de 1, na ordem de leitura), `type`, `file` (a partir da raiz do repositório), `lines` (primeira e última, ausente na anotação de arquivo), `code` (as linhas citadas, ausente na anotação de arquivo), `text`, e `found` (falso quando a âncora não foi encontrada; nesse caso `code` é a âncora e `lines` fica ausente). A entrega guarda também o cabeçalho: raiz absoluta, branch, e a referência do modo (sha completo e assunto; `antigo^..novo`; HEAD).
- **Formato XML**: um elemento raiz `code_review` com o cabeçalho em atributos, um `instructions` com o preâmbulo renderizado, e um `comment` por item com `id`, `type`, `file`, `lines` e `status="not-found"` quando não encontrado; o código vai num `code` filho e o texto do revisor logo depois. Texto e código vão crus, sem escapar entidades: o leitor é um modelo de linguagem, não um parser.
- **Formato markdown**: título `# Code review · <raiz> · branch <b> · <referência>`, o preâmbulo, e um `## <id>. <type> · <file>:<lines>` por item (com ` · trecho não encontrado` quando for o caso), o código numa cerca longa o bastante para o conteúdo e na linguagem do arquivo, e o texto. Tags, atributos e nomes de tipo em inglês; preâmbulo e texto do revisor em português.
- **Preâmbulo**: modelo com os marcadores `{types}` (a instrução de cada tipo usado, na ordem da configuração), `{reference}` (de qual versão são as linhas, e no commit como ver o conteúdo exato) e `{not_found}` (a regra das não encontradas, vazia sem nenhuma). O padrão vem embutido no plugin, com o texto acordado: revisão humana da mudança do agente; o que cada tipo usado pede; não altere nada além do pedido; localize pelo código citado, não só pelo número; não faça commit; responda uma linha por id com `feito`, `respondido` ou `recusado: motivo`. Uma opção de configuração dá o caminho do arquivo de modelo, com padrão sob o diretório de configuração do editor (`review/preamble.md`); arquivo ausente usa o embutido. Marcador desconhecido fica literal; marcador ausente não aparece.
- **Arquivos gravados**: um por modo e formato, `<raiz>-<modo>.xml` e `<raiz>-<modo>.md`, reescritos a cada geração daquele formato, no mesmo diretório de hoje (ADR-0004).
- **Tipos**: nova opção `annotation_types`, uma lista de `{ name, instruction }`. Os oito padrão vêm embutidos, nesta ordem: `issue`, `refactor`, `test`, `revert`, `question`, `suggestion`, `nitpick`, `praise`. Uma entrada com nome existente troca a instrução; com nome novo, é acrescentada ao fim. O tipo padrão é sempre `issue`.
- **Entrada do tipo**: nova opção `annotation_type_entry = "select" | "prefix"`, padrão `select`. No `select`, o tipo é pedido por `vim.ui.select` antes da entrada de texto (curta ou longa), cada item formatado como `nome — instrução`, com `issue` primeiro numa anotação nova e o tipo atual primeiro numa edição; cancelar desiste. No `prefix`, não há seletor: um prefixo `nome:` que casa exatamente um tipo configurado define o tipo e sai do texto; sem prefixo ou com prefixo desconhecido, o tipo é `issue` e o texto fica intacto; a edição vem preenchida com `nome: ` na frente para qualquer tipo que não seja `issue`. Sem abreviações.
- **Ponto e versão**: o ponto de uma anotação de linha passa a guardar a versão em que a linha foi lida — o disco, o índice, ou o sha do commit (o mais novo, num intervalo). A identidade do ponto é arquivo, modo, versão, linha e fim do trecho. A anotação de arquivo inteiro não guarda versão.
- **Onde a anotação de linha é aceita**: no buffer do arquivo no disco quando o modo é o working tree; no lado de depois do diff montado a partir de uma entrada — o arquivo no unstaged, o índice no staged, o commit no modo commit e no intervalo. Recusada, com aviso, no lado de antes, nas três versões de um conflito, na vista em outro rev, e no arquivo no disco quando o modo é commit ou intervalo (o aviso aponta o `<C-o>` de volta ao diff). A âncora é lida do buffer do lado anotado.
- **Reancoragem na geração**: versão disco e versão índice são reancoradas contra o arquivo no disco; versão commit não é reancorada — linha e código saem do conteúdo daquele commit. Anotação de modo commit ou intervalo sem versão (gravada antes desta mudança) é reancorada contra o conteúdo do commit do modo; não achada, sai não encontrada. Anotação de modo working tree sem versão é versão disco.
- **Quickfix**: mesma lista e título de hoje, preenchida a cada geração ou entrega refeita, com os itens na ordem dos ids. Texto `#<id> <type> · <primeira linha do texto>` (com ` …` quando houver mais linhas). A linha é sempre reancorada no disco na hora, a partir do código do item; não achada, ou arquivo ausente, o item vai sem linha e o texto ganha `não está no disco · `.
- **Documento de estado**: a anotação ganha `type` (ausente = `issue`), `version` (ausente = legado, tratado como acima) e `delivery` (o id da entrega em que saiu; ausente = aberta). O documento ganha `deliveries`: a lista de entregas, cada uma com id, modo, instante, cabeçalho e itens congelados. As mudanças são aditivas e a versão do documento **não** é incrementada: o carregamento hoje descarta o documento inteiro numa versão diferente, e isso apagaria vistos e anotações do revisor.
- **Entrega**: gerar (`R` ou `M`) com anotações abertas no modo monta os itens, congela a entrega, marca as anotações com o id dela, renderiza no formato pedido, grava o arquivo, copia para a área de transferência e para o registrador sem nome, e preenche a quickfix. Sem abertas e com entrega anterior no modo, renderiza a última entrega no formato pedido e a notificação diz `relatório da última entrega (N anotações) copiado`. Sem abertas e sem entrega, a mensagem de hoje, sem tocar na área de transferência. A escrita do arquivo que falha continua avisando e ainda copia.
- **Reabrir (`U`)**: tira a última entrega do modo do histórico e devolve as anotações dela a abertas. Sem entrega no modo, avisa. Se uma anotação da entrega tem o mesmo ponto de uma anotação aberta (escrita depois da entrega), a reabertura é recusada com um aviso que nomeia o ponto, para não haver dois textos no mesmo ponto.
- **Existência de anotação no ponto**: só as abertas contam. Anotar um ponto com anotação entregue abre a entrada vazia e grava uma anotação nova; apagar o texto todo continua removendo a aberta.
- **Contagem do painel**: conta só as abertas do modo.
- **Teclas e opções novas**: `mappings.report` continua `R` e passa a gerar XML; `mappings.report_markdown` (`M`); `mappings.reopen_delivery` (`U`). As três na lista única de ações do painel, que alimenta menu, which-key e ajuda (ADR-0008). A ajuda do diff lista as teclas de anotar quando o lado de depois aceita anotação.
- **README**: tabela de teclas do painel (`R`, `M`, `U`), a seção de anotações e reancoragem, "Depois de `R`" (formatos, entrega, refazer, reabrir), a seção do diff (onde se anota), "Onde as coisas são gravadas" (`.xml`, modelo do preâmbulo), as opções novas, e o roteiro de teste manual (anotar no commit e no staged, tipo pelo seletor e pelo prefixo, entrega, refazer e reabrir).

## Testing Decisions

- **Uma costura só**, a que a suíte já tem (`docs/agents/testing.md`): Neovim headless, repositório de verdade montado pelo fixture, a API pública e as teclas do plugin acionadas, e afirmações só sobre o que o revisor vê. Nenhuma costura nova e nenhum gancho de teste dentro do plugin.
- **Um bom teste** aqui aciona o que o revisor aciona — abrir o painel, escolher um commit no grafo, abrir o diff, pôr o cursor no lado, apertar a tecla de anotar, responder o seletor e a entrada, apertar `R`/`M`/`U` — e afirma sobre o documento gerado, a quickfix, a área de transferência, o painel, as notificações e o documento de estado. Não afirma sobre funções internas, nem sobre a forma das estruturas em memória.
- **Observáveis usados** (numeração do `testing.md`): #10 o relatório lido de volta do diretório de dados; #11 a quickfix; #5 a área de transferência; #9 o documento de estado (tipo, versão, entregas e itens congelados) e `document.plant` para anotações legadas sem tipo e sem versão; #6 a UI de seleção do editor de teste (`confirm.offered`, `confirm.answer`) para o seletor de tipo; #8 a entrada (`input.answer`, `input.prompts`, `input.defaults`) para o texto e o prefixo; #12 o grafo (`graph.choose`, `graph.choose_range`) para entrar no commit e no intervalo; #3 o diff montado para pôr o cursor no lado certo; #1 a contagem na linha do painel; #13 os mapeamentos com descrição; #14 as notificações de recusa e de entrega refeita.
- **Helper do relatório**: deixa de ler cabeçalhos de markdown e passa a devolver os itens (id, type, file, lines, code, text, not-found) e o cabeçalho de qualquer um dos dois formatos. Um teste afirma que `R` e `M` sobre a mesma revisão devolvem os mesmos itens — o contrato do ADR-0006 —, e os demais afirmam sobre os itens.
- **Preâmbulo**: o teste grava um modelo num diretório temporário e aponta a opção de caminho para ele via `setup`, como já faz com `report_directory`; afirma a substituição dos marcadores, o marcador desconhecido literal e o padrão embutido sem arquivo.
- **Arte anterior**: `report_spec` (documento, reancoragem, deslocada, quickfix, clipboard), `annotation_spec` (entrada curta e longa, trecho, edição no mesmo ponto), `commit_spec` e `rev_spec` (grafo, modo commit e intervalo, lados do diff), `staging_spec` (diff de staged), a confirmação do descartar (seletor do editor), `help_spec` (ajuda do diff) e `mouse_spec` (menu de contexto).
- **Módulos cobertos**: relatório (formatos, preâmbulo, entrega, refazer, reabrir, quickfix), anotação (tipo, seletor, prefixo, versão, onde é aceita), estado (esquema aditivo, anotações legadas), painel (teclas, contagem, menu) e diff (ajuda com as teclas de anotar).
- **Conclusão**: `make format`, `make lint` com zero erros e zero avisos, e `make test` redirecionado para arquivo, com código de saída zero e sem spec falha ou com erro.

## Out of Scope

- Anotar o lado de antes de um diff (a linha removida) e as três versões de um conflito.
- Uma tecla ou tela para ver entregas antigas; elas ficam só no documento de estado. Reabrir entrega que não seja a última.
- Um relatório que junte anotações de mais de um modo.
- Um formato pensado para gente ler num PR, e decorações `blocking`/`non-blocking`.
- Abreviações de tipo no modo prefixo.
- Mandar o relatório ao agente por outro caminho que não a área de transferência, e ler a resposta do agente de volta para o editor.
- Anotar na vista em outro rev (`e`).

## Further Notes

- Domínio e decisões já registrados: `CONTEXT.md` (Relatório de revisão, Anotação, Tipo da anotação, Ponto, Reancoragem, Anotação deslocada, Anotação aberta, Anotação entregue, Entrega), ADR-0011 (anotação de commit presa ao commit), ADR-0012 (gerar o relatório é entregar), atualizações do ADR-0003 (só o que ainda muda é reancorado) e do ADR-0006 (dois formatos como teclas; tipo como opção).
- Decisões tomadas na escrita da spec, sem discussão com o revisor, e que podem ser revistas: a anotação de arquivo inteiro não guarda versão; reabrir é recusado quando colide com uma anotação aberta no mesmo ponto; texto e código vão crus no XML; a versão do documento de estado não é incrementada.
- Referências da pesquisa de formato: Conventional Comments (conventionalcomments.org) para os tipos; a API de comentários de review do GitHub (`path`, `line`, `start_line`, `side`, `commit_id`) para a localização; a documentação de prompting da Anthropic sobre tags XML; o "Prompt for AI Agents" do CodeRabbit e o extrator `obra/coderabbit-review-helper` como prior art de relatório de review para agente.
- Os tickets de relatório e de anotação da fase 2 (`nvi-01m1d6hx1mma`, `nvi-01m1d6hwxd9p`) e o de modo commit (`nvi-01m1d6hxabg5`) descrevem o comportamento que esta spec substitui em parte.