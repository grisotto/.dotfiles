---
id: nvi-01m1kh78jhtb
title: Espaço marca visto e leva à próxima não vista
status: closed
type: feature
priority: 1
mode: afk
created: '2026-09-03T11:42:15.121731365Z'
updated: '2026-09-03T12:29:30.103711363Z'
closed: '2026-09-03T12:29:30.103711363Z'
assignee: grisotto
parent: nvi-01m1j8zy1rqj
tags:
- git
- review
- plugin-local
acceptance:
- title: v marca e desmarca sem mover o cursor, como hoje
  done: true
- title: Espaço marca visto e leva à próxima não vista na ordem renderizada, sem dar a volta
  done: true
- title: Espaço pula a seção Vistos ao procurar a próxima
  done: true
- title: Espaço em cima de um arquivo já visto desmarca e não avança
  done: true
- title: Sem próxima não vista, o cursor vai ao cabeçalho e o painel avisa o total visto
  done: true
- title: A tecla entra no menu de contexto e no which-key pela mesma lista das outras
  done: true
---

## Description

O gesto que fecha a revisão dentro da lista: *li este, me leve ao próximo que falta*.

- **`v` não muda**: marca e desmarca, e deixa o cursor onde está. Desmarcar é feito olhando para o arquivo, e uma tecla que saísse de cima dele desfaria a marca e esconderia o que foi desfeito.
- **`<Space>` no painel**: marca visto e desce para a **próxima não vista**, na ordem renderizada (Conflitos → Staged → Unstaged → Untracked, caminho crescente), pulando a seção Vistos e **sem dar a volta**. Só avança quando marcou — desmarcar não avança.
- Sem próxima, o cursor vai para o cabeçalho e o painel avisa `12/12 vistos`. Não é um estado novo: a revisão continua sem ciclo de vida, e o fim é uma linha, não um "finalizar".

Hoje ler um arquivo e ir ao próximo custa três gestos: voltar o foco à lista, `j`, `<CR>`. Toda ferramenta de revisão madura resolve isso com uma tecla só — o "Viewed" do GitHub colapsa o arquivo e o tira do caminho, o `r` do Gerrit marca reviewed sem sair do diff.

### Notas de execução

- A ordem de navegação é a ordem **renderizada**, e é dela que sai "a próxima": o painel já monta essa ordem em `build_lines`, e é ela que a tecla anda, não a ordem das entradas do git.
- A tecla nova entra no menu de contexto e no which-key pela mesma lista das outras (`panel_actions`), que é o que impede menu e teclas de divergirem (ADR-0008).
- Aqui nasce a noção de "onde a revisão está" ser o cursor do painel. A decisão de modelo só é forçada pelo ticket seguinte, que move esse cursor de dentro do diff, e o ADR-0009 é escrito lá.

## Notes

**2026-09-03T12:29:30.103711363Z**

O <Space> no painel marca visto e desce para a próxima não vista, na ordem renderizada, pulando a seção Vistos e os arquivos que a marca por conteúdo levou junto, sem dar a volta; sem próxima, o cursor vai ao cabeçalho, onde está escrito N/N vistos. O v continua marcando e desmarcando sem sair do lugar. A tecla entra no menu e no which-key pela lista única do painel_actions (ADR-0008), e é a única do painel que espera antes de agir, por ser o Leader desta configuração.
