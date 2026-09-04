---
id: nvi-01m1j8zy1rqj
title: 'Fase 4: o laço da revisão — varrer, marcar e avançar'
status: closed
type: feature
priority: 1
mode: afk
created: '2026-09-02T23:59:11.924972956Z'
updated: '2026-09-03T19:30:53.196011182Z'
closed: '2026-09-03T19:30:53.196011182Z'
assignee: grisotto
parent: nvi-01m1d6164sz2
tags:
- git
- review
- plugin-local
external_refs:
- git:414cabf
---

## Description

As fases 1 a 3 entregaram os **verbos** da revisão — abrir o diff, marcar visto, anotar, relatar, trocar de modo. Nenhuma delas entregou o **laço**: o caminho que o revisor percorre do primeiro arquivo ao último sem montar o percurso na cabeça a cada arquivo.

Hoje ler um arquivo e ir ao próximo custa três gestos: voltar o foco à lista, `j`, `<CR>`. Toda ferramenta de revisão madura resolve isso com uma tecla só.

### O que as outras ferramentas fazem

| Ferramenta | Onde o revisor mora | O que fecha o laço |
|---|---|---|
| IntelliJ | no diff | `F7`/`Shift+F7` andam pela próxima diferença e **atravessam o arquivo sozinhos**: acabaram as diferenças, cai no próximo arquivo da lista |
| Gerrit | no diff | `[`/`]` = arquivo anterior/próximo sem voltar à lista; `r` marca reviewed |
| GitHub PR | numa página só | o checkbox "Viewed" **colapsa** o arquivo e o tira do caminho; árvore lateral com contador |
| Magit | na lista | `TAB` expande o diff dentro da própria lista; nunca há segunda janela |
| lazygit / Sublime Merge | na lista | o diff ao lado **acompanha o cursor**; stage por hunk dentro dele |
| diffview.nvim (já instalado) | no diff | `<Tab>`/`<S-Tab>` = próximo/anterior arquivo sem sair do diff |

### Decisões desta fase

1. **As três residências coexistem**, cada uma numa tecla, como as apresentações de diff (ADR-0006): a lista com preview (lazygit), o diff com navegação própria (IntelliJ/Gerrit) e a lista com avanço (GitHub). O que não coexiste é preview ligado e desligado ao mesmo tempo — daí ser uma tecla, e não uma opção decidida uma vez.
2. **O modo vira perfil**: as teclas continuam as mesmas em qualquer modo (ADR-0001); o que muda é o que o painel *informa* — o cabeçalho, o que o menu oferece, e qual é o próximo passo quando acaba.
3. **Nada de poda**: os quatro pares do ADR-0006 seguem ligados. O que falta não é tecla a menos, é laço.
4. **A revisão continua sem ciclo de vida**: nada de "iniciar" e "finalizar". O visto por conteúdo (ADR-0002) vale justamente por não pertencer a uma sessão. O fim vira uma linha que diz o próximo passo, não um estado novo.

### Fora desta fase

Qualquer poda das teclas concorrentes do ADR-0006; anotação por hunk; navegação por *diferença* dentro do arquivo (o `]c`/`[c` do próprio Neovim já faz isso em modo diff).

## Notes

**2026-09-03T19:30:53.196011182Z**

As onze fatias da fase estão fechadas: o laço de dentro da lista (<Space>), o de dentro do diff (]f, [f, ]F, [F e o <Leader>gv), o preview numa tecla, o ícone e a cor na linha, o +N −M do numstat, a linha de informação do cabeçalho por modo, e o painel informando por modo — menu e which-key filtrados no commit, mais a linha do próximo passo com tudo visto. As três residências coexistem, cada uma numa tecla (ADR-0006), nenhuma tecla concorrente foi podada, e a revisão segue sem ciclo de vida: o fim é uma linha, e não um estado.
