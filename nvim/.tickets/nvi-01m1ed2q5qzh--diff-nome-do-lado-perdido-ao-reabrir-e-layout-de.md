---
id: nvi-01m1ed2q5qzh
title: 'Diff: nome do lado perdido ao reabrir, e layout de merge preso quando o diffview não abre'
status: open
type: bug
priority: 3
mode: afk
created: '2026-09-01T11:53:39.767494853Z'
updated: '2026-09-01T11:53:39.767494853Z'
assignee: grisotto
parent: nvi-01m1d61ppxj1
tags:
- review
---

## Description

Dois achados de baixa severidade da revisão de código de nvi-01m1d7wc6car, fora do escopo dela: são de código já entregue por nvi-01m1d6hw839c.

**Nome do lado perdido ao reabrir o mesmo diff.** `diff.M.open` monta os buffers dos lados *antes* de chamar `M.close()`, e é o close que apaga os buffers anteriores (`bufhidden = "wipe"`). O buffer novo tenta tomar um nome que o antigo ainda tem, `nvim_buf_set_name` estoura E95 e o `pcall` engole: abrir duas vezes o diff do mesmo arquivo deixa o lado sem nome (`review://índice/a.txt` numa vez, `""` na outra), e sem nome não há realce de sintaxe nem como o revisor saber que lado está lendo. O teste que existe usa dois arquivos diferentes, então não pega. Basta fechar antes de montar.

**Layout de merge preso quando o diffview não abre.** `actions.use_merge_layout` troca `view.merge_tool.layout` antes de `diffview.open`, e só arma a restauração quando `pending_restore` está vazio. Se o open estourar, ou se o nome de layout for recusado e nenhuma view chegar a fechar, o autocmd `DiffviewViewClosed` nunca dispara: `pending_restore` fica não-nulo para sempre, todo conflito seguinte pula o rearme, e o layout configurado pelo revisor se perde pelo resto da sessão — exatamente o que o comentário do módulo diz que não pode acontecer. Trocar o layout só depois de o open dar certo, e apagar o autocmd (`nvim_del_autocmd`) quando ele falhar.
