---
id: nvi-01m1d6hxeg2b
title: Filtro por branch e intervalo de commits
status: closed
type: task
priority: 3
mode: afk
created: '2026-09-01T00:40:23.245789612Z'
updated: '2026-09-01T23:34:14.576222967Z'
closed: '2026-09-01T23:34:14.576222967Z'
assignee: grisotto
parent: nvi-01m1d62bd8hq
tags:
- git
- review
acceptance:
- title: Escolher uma branch numa busca reabre o grafo restrito a ela
  done: true
- title: Selecionar um intervalo lista os arquivos do intervalo inteiro
  done: true
- title: O cabeçalho identifica o intervalo em revisão
  done: true
- title: As teclas do painel funcionam igual no modo intervalo
  done: true
deps:
- nvi-01m1d6hxabg5
---

## Description

### O que construir

Escolher uma branch numa busca reabre o grafo restrito a ela, para não procurar o commit no meio de tudo. O filtro é obtido reabrindo o grafo já restrito, e não por uma funcionalidade do plugin de grafo, que não expõe filtro por branch.

Selecionar um intervalo de commits, e não só um, faz o painel listar os arquivos do intervalo inteiro — o gesto de revisar uma feature completa de uma vez. O cabeçalho identifica o intervalo.

## Notes

**2026-09-01T23:33:53.072954314Z**

Filtro por branch: uma tecla do grafo (b), a busca é a UI de seleção do editor — com um picker por cima ela é a busca que a spec pede. Reabre o grafo com a branch como argumento do git log; a primeira opção da lista tira o filtro. As branches vêm de git branch --all, remotas incluídas (a branch que se procura é muitas vezes de outra pessoa), menos refs/remotes/origin/HEAD: o git encurta esse ponteiro para "origin", sem HEAD nenhum no nome para reconhecê-lo, então o nome curto e o completo são lidos juntos.

Intervalo: seleção visual no grafo, mesma tecla que abre uma linha. As duas pontas entram, e o que o painel lista é a diferença entre as duas árvores (git diff-tree <mais antigo>^ <mais novo>) — o líquido do intervalo, não a soma dos commits: um arquivo criado e apagado dentro dele não aparece. Isso também resolve os merges no meio do caminho de graça: comparar duas árvores não tem commit nenhum para ter pais, então nada de --diff-merges aqui. Um intervalo que chega ao primeiro commit do repositório compara com a árvore vazia (git hash-object -t tree /dev/null, que é o hash deste repositório e não uma constante), mas as entradas continuam levando <mais antigo>^ como base: é o que o revisor lê no lado esquerdo do diff.

O modo virou três em vez de dois (lua/review/mode.lua): range-<sha>..<sha> com os dois nomes inteiros, porque o mesmo commit revisado sozinho e como ponta de uma feature são duas leituras, e as anotações de uma não são da outra.

Três coisas saíram do code review:
- O d (diffview) mostrava só o último commit do intervalo enquanto o <CR> mostrava o intervalo inteiro — silenciosamente duas revisões diferentes na mesma linha. Agora ele recebe base..rev; o ^! continua para o commit sozinho, que é a notação que também funciona no primeiro commit do repositório.
- Intervalo entre duas branches que divergiram agora é recusado com aviso: o grafo desenha todas as branches, duas linhas vizinhas na tela podem não estar na mesma história, e comparar as pontas listaria tudo o que difere entre elas. A pergunta (merge-base --is-ancestor) é feita no gesto, não a cada redesenho.
- O cabeçalho traz <mais antigo>^..<mais novo>, com o ^: a..b diria a quem lê git que a ponta mais antiga está de fora, e ela não está. É também como o lado esquerdo do diff é nomeado.

O gitgraph também ganhou o intervalo (on_select_range_commit), que a fatia anterior tinha deixado explicitamente para esta: ele entrega as pontas na ordem que review.range espera. Sem filtro por branch lá, porque o filtro é reabrir o grafo e quem reabre o dele é ele.

Fora do que o ticket pedia, e por isso registrado aqui: o grafo ganhou uma linha de dicas sob o cabeçalho, montada da mesma lista de onde saem as teclas dele. Os dois gestos novos são invisíveis — ninguém adivinha que uma seleção visual revisa um intervalo — e a linha existe para que o revisor os encontre olhando para a lista. É a mesma razão pela qual o menu de contexto do painel mostra as teclas.

**2026-09-01T23:34:14.576222967Z**

Filtro por branch e modo intervalo no grafo do painel, com o gitgraph ligado ao mesmo gesto. Os quatro critérios de aceite estão cobertos por tests/review/commit_spec.lua (43 testes no arquivo, 190 na suíte). Três achados do code review entraram antes do commit: o d do diffview mostrava só o último commit do intervalo, o intervalo entre branches divergentes agora é recusado, e o cabeçalho escreve o intervalo com o ^ que diz que a ponta mais antiga entra.
