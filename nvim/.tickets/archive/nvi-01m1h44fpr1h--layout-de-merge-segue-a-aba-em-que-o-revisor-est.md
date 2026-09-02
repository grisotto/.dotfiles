---
id: nvi-01m1h44fpr1h
title: Layout de merge segue a aba em que o revisor está
status: closed
type: bug
priority: 3
mode: afk
created: '2026-09-02T13:15:03.765294463Z'
updated: '2026-09-02T14:31:17.981533421Z'
closed: '2026-09-02T14:31:17.981533421Z'
assignee: grisotto
parent: nvi-01m1d61ppxj1
tags:
- review
acceptance:
- title: Com duas views nossas vivas, voltar para a aba da mais velha põe o layout dela na configuração antes do refresh
  done: false
- title: O layout do revisor continua voltando só quando a última das nossas views fecha
  done: false
links:
- nvi-01m1fweftw6s
---

## Description

Achado da revisão de código de nvi-01m1fweftw6s, fora do escopo dela: o que
aquele ticket consertou é de quem é a restauração, não qual layout está valendo
enquanto duas views nossas estão vivas.

A configuração do diffview tem um lugar só para `view.merge_tool.layout`, e é de
lá que ele relê o layout a cada refresh — o `watch_index` faz um a cada 1000ms,
e ele é filtrado por `is_cur_tabpage`. Hoje quem está nesse lugar é a troca mais
nova da pilha (`swaps`, em lua/review/actions.lua). Então, com um conflito aberto
com `<CR>` e outro aberto com `d`, voltar para a aba do primeiro e esperar o
refresh remonta aquele conflito no layout do segundo.

O lugar é um só, então não dá para as duas estarem certas ao mesmo tempo. O que
dá é fazer o valor seguir quem está na tela: a view da aba atual é a única que
pode refrescar, então o layout que tem que estar na configuração é o da troca
daquela view. Isso é escutar `view_enter` no barramento do diffview — o mesmo de
onde `view_opened` e `view_closed` são lidos hoje — e chamar o `settle_layout`
com a troca daquela view no topo, em vez de com a mais nova. A pilha passa a
precisar saber de que view é cada troca, que é o campo que nvi-01m1fweftw6s tirou
justamente porque ninguém precisava dele.

Mexe no comentário de `swaps`, que hoje diz que a mais nova ganha de propósito, e
no parágrafo de docs/agents/testing.md que descreve isto como o que não tem
conserto.

Sem teste na suíte, como toda a delegação ao diffview (ADR-0005): a verificação é
à mão, com o diffview no runtimepath e um layout de revisor que não seja nenhum
dos nossos dois, do jeito que os três fechamentos de docs/agents/testing.md já
são verificados.

## Notes

**2026-09-02T14:31:09.074950959Z**

Fechado por não existir: a premissa não se sustenta, e a verificação foi feita com o diffview de verdade.

O layout de merge só é lido na hora de construir a entrada de um arquivo — get_updated_files, em scene/views/diff/diff_view.lua, que passa o merge_layout para diff_file_list. No refresh o diffview casa a lista velha com a nova pelo caminho e reaproveita a entrada que já existe, de propósito, para não recriar buffer; e ensure_layout remonta a partir do cur_layout que a view já tem. Nenhum dos dois relê a configuração.

E as views que abrimos são de um arquivo só: os argumentos são { '--', <caminho> }. Confirmado num repositório com dois arquivos conflitados — path_args da view é o arquivo único e a lista de conflitados dela tem uma entrada, não duas. Então nenhuma entrada nova entra numa view nossa depois que ela abriu.

Somando: uma view nossa lê a configuração uma vez, quando abre, com o layout que a troca acabou de pôr lá. O que entrar ali depois não a alcança. Forçando diff4_mixed na configuração por trás de uma view diff3_horizontal viva, e depois refrescando, andando nas entradas e refrescando de novo, ela fica nas quatro janelas do diff3 o tempo todo.

A correção chegou a ser escrita (settle_layout seguindo view_enter, com a view de volta em cada troca) e passava, mas não muda nada que o revisor veja: foi descartada. O parágrafo de docs/agents/testing.md que afirmava o resíduo foi corrigido, e o comentário de swaps em lua/review/actions.lua passa a dizer por que a mais nova ganhar não custa nada à outra.

**2026-09-02T14:31:17.981533421Z**

Inválido: o defeito descrito não acontece. Uma view nossa lê o layout de merge uma vez, ao abrir, e as views que abrimos são de um arquivo só — o refresh reaproveita a entrada que já existe e o ensure_layout remonta do cur_layout, então o que entra na configuração depois não a alcança. Os dois critérios de aceite ficam sem sentido: o primeiro descreve um sintoma que não existe e o segundo já era garantido por nvi-01m1fweftw6s. Ver a nota com a verificação; docs/agents/testing.md e o comentário de swaps foram corrigidos.
