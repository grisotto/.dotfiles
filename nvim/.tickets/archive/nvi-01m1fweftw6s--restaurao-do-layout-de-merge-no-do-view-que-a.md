---
id: nvi-01m1fweftw6s
title: Restauração do layout de merge não é do view que a armou
status: closed
type: bug
priority: 3
mode: afk
created: '2026-09-02T01:41:28.540768797Z'
updated: '2026-09-02T13:15:03.765294463Z'
closed: '2026-09-02T13:08:38.648982264Z'
assignee: grisotto
parent: nvi-01m1d61ppxj1
tags:
- review
links:
- nvi-01m1h44fpr1h
---

## Description

Achado da revisão de código de nvi-01m1ed2q5qzh, fora do escopo dela: é da
semântica que aquele ticket herdou e apenas redocumentou.

A restauração do layout de merge é armada no próximo `DiffviewViewClosed`, seja
de que view for — o evento não nomeia nenhuma, e o `DiffviewViewOpened` que diz
que abriu também não. Então o par "a view que abriu é a view cujo fechamento
devolve o layout" não existe: quem devolve é a primeira view que fechar.

Dois jeitos de ver o defeito, com a mesma raiz:

1. O revisor abre um conflito com `<CR>` (o layout vira o nosso, a restauração é
   armada), volta ao painel e abre um arquivo mudado com `d`, numa segunda aba
   do diffview. Fechar essa segunda aba dispara a restauração: o layout do
   revisor volta enquanto a view do conflito ainda está aberta, e o próximo
   refresh dela — o `watch_index` do diffview faz um a cada 1000ms — remonta o
   conflito no layout errado.

2. `M.close`/`TabClosed` do diffview agenda `dispose_stray_views`, que por sua
   vez agenda o `view:close()`. Uma aba do diffview fechada com `:tabclose`
   logo antes de o conflito ser aberto dispara a restauração depois de ela ter
   sido armada, e `pending_restore` volta a nulo com um layout nosso na
   configuração.

Também é por isso que, com duas views nossas vivas ao mesmo tempo, há uma
restauração só para duas trocas e ela não é de nenhuma das duas: a que fechar
primeiro leva o layout da que ficou.

A correção é a mesma para os dois: prender a restauração ao view que a armou —
guardar o que `lib.get_current_view()` devolve depois do open e conferir no
callback — ou trocar o `pending_restore` único por uma pilha de trocas. Mexe no
comentário do módulo, que hoje diz que há no máximo uma de propósito.

O caminho de falha (nenhuma view abriu) já está correto desde nvi-01m1ed2q5qzh e
não é isto aqui.

## Notes

**2026-09-02T13:08:38.517770314Z**

Corrigido em 6a866f0. A troca é pendurada na view que abriu, lida do barramento de eventos do diffview (view_opened/view_closed carregam a view; as autocommands User de mesmo nome, não). O pending_restore único virou pilha, porque prender à view não basta com duas vivas fechando fora de ordem.

Fica de fora, e não tem como com um lugar só na configuração do diffview: das duas views nossas vivas, só a mais nova está com o layout dela lá, então voltar para a aba da mais velha remonta o conflito no layout da outra no refresh seguinte. Fazer o layout seguir a aba do revisor seria outra mudança.
