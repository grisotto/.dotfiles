---
id: nvi-01m1d6hwc7f9
title: Visto e a seção Vistos
status: closed
type: task
priority: 1
mode: afk
created: '2026-09-01T00:40:22.149692406Z'
updated: '2026-09-01T12:12:29.790062277Z'
closed: '2026-09-01T12:12:29.790062277Z'
assignee: grisotto
parent: nvi-01m1d61ppxj1
tags:
- git
- review
acceptance:
- title: Uma tecla marca e desmarca visto
  done: true
- title: Arquivo visto sai da sua seção e aparece na seção Vistos recolhida no fim
  done: true
- title: A seção Vistos expande e recolhe, e de dentro dela dá para desmarcar
  done: true
- title: O cabeçalho mostra quantos foram vistos do total
  done: true
- title: Fechar e reabrir o editor mantém os vistos
  done: true
- title: Arquivo que muda depois de marcado volta a aparecer como não visto
  done: true
- title: A apresentação alterna entre seção própria e esmaecido no lugar por configuração
  done: true
- title: Os hashes do working tree são calculados num único processo
  done: true
deps:
- nvi-01m1d6hw44g6
---

## Description

### O que construir

Uma tecla marca e desmarca um arquivo como visto. Arquivos vistos saem das suas seções e vão para a seção Vistos, recolhida no fim do painel, de onde podem ser expandidos para revisitar e desmarcados para voltar. O cabeçalho ganha o contador de progresso: quantos arquivos já foram vistos do total.

O visto identifica o conteúdo, não o nome (ADR-0002): é chaveado pelo hash do conteúdo do arquivo. A consequência que importa é que um arquivo marcado como visto que muda depois volta a aparecer como não visto, para nenhuma alteração nova passar batida.

O estado é gravado fora do repositório revisado (ADR-0004), indexado pelo caminho da raiz do repositório, num documento JSON com versão de esquema. Fechar e reabrir o editor não perde nada.

A apresentação dos vistos é configurável entre a seção própria e o esmaecido no lugar, para as duas serem testadas no uso.

### Desempenho

Os hashes dos arquivos do working tree são calculados num único processo. Conteúdo já identificado pelo índice ou pelo HEAD não é hasheado de novo.

## Notes

**2026-09-01T12:12:29.790062277Z**

Visto marca e desmarca com uma tecla, chaveado pelo conteúdo (ADR-0002) e gravado fora do repositório (ADR-0004). Vistos saem para a seção recolhida no fim, que expande na própria linha; apresentação alterna para o esmaecido no lugar por configuração. Working tree hasheado num processo só. 15 testes em tests/review/seen_spec.lua.
