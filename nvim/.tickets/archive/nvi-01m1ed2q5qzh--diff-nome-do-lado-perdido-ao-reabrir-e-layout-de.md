---
id: nvi-01m1ed2q5qzh
title: Layout de merge preso quando o diffview não abre
status: closed
type: bug
priority: 3
mode: afk
created: '2026-09-01T11:53:39.767494853Z'
updated: '2026-09-02T01:42:27.468224641Z'
closed: '2026-09-02T01:42:27.468224641Z'
assignee: grisotto
parent: nvi-01m1d61ppxj1
tags:
- review
---

## Description

Achado de baixa severidade da revisão de código de nvi-01m1d7wc6car, fora do escopo dela: é de código já entregue por nvi-01m1d6hw839c.

`actions.use_merge_layout` troca `view.merge_tool.layout` antes de `diffview.open`, e só arma a restauração quando `pending_restore` está vazio. Se o open estourar, ou se o nome de layout for recusado e nenhuma view chegar a fechar, o autocmd `DiffviewViewClosed` nunca dispara: `pending_restore` fica não-nulo para sempre, todo conflito seguinte pula o rearme, e o layout configurado pelo revisor se perde pelo resto da sessão — exatamente o que o comentário do módulo diz que não pode acontecer. Trocar o layout só depois de o open dar certo, e apagar o autocmd (`nvim_del_autocmd`) quando ele falhar.

O outro achado deste ticket — nome do lado perdido ao reabrir o mesmo diff — foi corrigido em 7f1e6bf; veja a nota.

## Notes

**2026-09-01T19:09:57.162000689Z**

O primeiro achado — nome do lado perdido ao reabrir o mesmo diff — foi corrigido
em 7f1e6bf, junto com o terceiro modo de conflito (nvi-01m1d6hx62xh): com três
lados o defeito apagava a identidade da tela inteira, e a revisão de spec daquele
ticket o reencontrou. A correção é a que este ticket já apontava, fechar antes de
montar: `build` desmonta o diff anterior e só então lê os lados novos. Dois testes
em tests/review/open_spec.lua cobrem o reabrir, com dois lados e com três; os dois
falham sem a correção.

Sobra o segundo achado, o layout de merge preso quando o diffview não abre, que é
o que a descrição descreve agora.

**2026-09-02T01:42:27.334949051Z**

Corrigido em 0a0ee1e.

A troca do layout agora devolve o que armar: com view aberta, arma a restauração;
sem view, desfaz a troca na hora. Quem responde se abriu é o `DiffviewViewOpened`
do próprio diffview — `diffview.open` não devolve nada, e um repositório recusado
é um aviso na tela e um retorno calado para nós. O open estourado é pego, o
layout volta, e o erro é relançado como veio.

Duas premissas da descrição não se confirmaram na verificação com o diffview de
verdade:

- Um nome de layout que não existe não prende nada. `name_to_layout` dá assert,
  mas quem o chama é `get_updated_files`, dentro de um `vim.schedule`: a view
  chega a abrir, dispara o evento e fecha normalmente. O caso que prendia é o
  open que não abre view nenhuma — repositório recusado, ou estouro.
- `nvim_del_autocmd` acabou desnecessário: armando depois do open, o autocmd nem
  chega a existir no caminho que falha. De quebra fecha uma corrida que já
  existia, a de um `DiffviewViewClosed` disparando entre o armar e o abrir.

Sem teste na suíte, pelo motivo de sempre: o `minimal_init` deixa o diffview fora
do runtimepath de propósito. A verificação é à mão, e o caso novo ficou descrito
em docs/agents/testing.md. Com a correção revertida, a primeira afirmação dela
falha.

A revisão de código do próprio ticket achou que a restauração não é da view que
a armou — semântica herdada, não regressão. Virou nvi-01m1fweftw6s.
