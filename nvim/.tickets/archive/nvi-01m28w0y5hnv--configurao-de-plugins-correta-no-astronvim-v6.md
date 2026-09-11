---
id: nvi-01m28w0y5hnv
title: Configuração de plugins correta no AstroNvim v6
status: closed
type: chore
priority: 2
mode: afk
created: '2026-09-11T18:35:05.249357336Z'
updated: '2026-09-11T19:01:04.797657245Z'
closed: '2026-09-11T19:01:04.797657245Z'
assignee: grisotto
tags:
- migracao
- v6
acceptance:
- title: <Leader>p cola, medido por maparg nos modos normal e visual
  done: true
- title: Todo lado esquerdo do spec do AstroCore na grafia do :h keycodes
  done: true
- title: Grupo gm nomeado por desc, com o caminho desc -> group exercitado
  done: true
- title: blink.cmp e blink.compat sob o dono novo, completamento do Conjure intacto
  done: true
- title: vim-jack-in e as duas dependencias fora do spec, do lock e do disco
  done: true
- title: Arquivo do plugin removido no v6 apagado e plugin orfao limpo do disco
  done: true
- title: README descreve a instalacao por symlink que existe de fato
  done: true
- title: make lint em 0/0/0 e make test sem falha nem erro
  done: true
- title: Aviso de colisao do checkhealth explicado em comentario, com a causa
  done: true
links:
- nvi-01m28t7sxfk9
external_refs:
- git:4350afc
- git:eec393a
- git:4b06e5e
- git:6828170
- git:9cd89fe
- git:fa337c9
---

## Problem Statement

A configuração pulou do NvChad v2.5 para o template do AstroNvim v6 num commit só. O andaime ficou certo, mas o que o salto deixou para trás só aparece no uso, uma tecla de cada vez:

- `<Leader>p` não faz nada. Colar da área de transferência simplesmente não acontece, e nada no editor diz por quê.
- O menu do which-key em `gm` abre sem nome.
- O `:checkhealth astrocore` acusa colisão de mapeamento toda vez que é aberto — vira ruído, e o próximo aviso de verdade passa despercebido.
- O `vim-jack-in` carrega junto com `vim-dispatch` e `vim-dispatch-neovim`, contra o que o próprio `CLAUDE.md` do projeto declara sobre quem é dono dos processos do Agilis.
- O `blink.cmp` é declarado sob o dono antigo, renomeado no v6.
- Sobrou um arquivo de configuração de um plugin que o v6 removeu, e um plugin órfão em disco.
- O README manda instalar de um jeito que recria o problema: `git clone` por cima de `~/.config/nvim`, que é exatamente onde deve estar o link simbólico para o repositório de dotfiles.

Nada disso quebra o editor — ele abre limpo, sem erro e sem função descontinuada. É configuração que mente sobre si mesma.

## Solution

Auditar todo spec de plugin contra o AstroNvim v6, consertar o que está velho, apagar o que está morto, e escrever a decisão onde o próximo leitor vai esbarrar nela.

Do lado do usuário do editor: colar volta a funcionar, o menu de cursores múltiplos tem nome, o `:checkhealth` só fala quando tem o que dizer, e o README descreve a instalação que existe de fato.

O escopo é correção contra o v6. O que a configuração do NvChad tinha e o v6 não repôs — harpoon, `jj`, atalhos de hunk, ajuste fino de servidor de LSP — é escolha de ergonomia, não defeito, e está inventariado noutro ticket.

## User Stories

1. Como usuário do editor, quero que `<Leader>p` cole o que está no registro da área de transferência, para não descobrir no meio de uma edição que a tecla não faz nada.
2. Como usuário do editor, quero que `<Leader>y`, `<Leader>Y`, `<Leader>yy` e `<Leader>P` sigam copiando e colando pelo mesmo registro, para o gesto ser o mesmo nos dois sentidos.
3. Como usuário do editor, quero que copiar e colar funcionem também em modo visual, para a seleção ser o argumento natural do gesto.
4. Como usuário do editor, quero saber por que colar demora meio segundo, para não tratar a espera como travamento.
5. Como usuário do editor, quero que o menu do which-key em `gm` apareça com nome, para reconhecer o grupo antes de escolher a tecla.
6. Como usuário do editor, quero que `<C-Up>` e `<C-Down>` criem cursor, para o gesto de multi-cursor continuar sendo o que os dedos já sabem.
7. Como usuário do editor, quero que `<C-Left>` e `<C-Right>` continuem redimensionando split, para não perder a única forma de redimensionar por teclado.
8. Como usuário do editor, quero que a assimetria das quatro setas esteja explicada onde ela é configurada, para não parecer descuido.
9. Como usuário do editor, quero abrir `:checkhealth astrocore` e que o aviso que sobrar seja explicável, para o comando voltar a ser sinal.
10. Como usuário do editor, quero que o completamento do Conjure continue funcionando em Clojure, para a migração do dono do plugin não me custar o REPL.
11. Como mantenedor da configuração, quero que todo plugin seja declarado sob o dono que o v6 usa, para o lock não fixar um repositório por um nome que mudou.
12. Como mantenedor da configuração, quero que o `vim-jack-in` saia junto com as duas dependências dele, para o editor parar de contradizer o que o `CLAUDE.md` declara sobre o fluxo do Agilis.
13. Como mantenedor da configuração, quero que arquivos de configuração de plugins que o v6 removeu sejam apagados, para ninguém ler um ajuste que não tem efeito.
14. Como mantenedor da configuração, quero que plugins órfãos saiam do disco, para o que está instalado ser o que está declarado.
15. Como mantenedor da configuração, quero que o lado esquerdo de todo mapeamento siga a grafia do `:h keycodes`, para duas grafias da mesma tecla nunca coexistirem na tabela.
16. Como mantenedor da configuração, quero que o motivo da normalização esteja escrito no arquivo, para ela não ser desfeita por parecer preciosismo.
17. Como mantenedor da configuração, quero que a colisão que o `:checkhealth` acusa e que não tem conserto local esteja documentada com a causa, para ninguém gastar uma tarde tentando calá-la.
18. Como mantenedor da configuração, quero que o que ficou para trás do NvChad esteja inventariado num ticket, para decidir item a item com calma em vez de no meio da auditoria.
19. Como quem instala numa máquina nova, quero que o README descreva o arranjo de symlink que existe, para não clonar por cima do lugar do link.
20. Como quem instala numa máquina nova, quero que o README diga a versão mínima do Neovim, para não descobrir o requisito pelo erro.
21. Como quem instala numa máquina nova, quero que o README diga o que esperar da primeira abertura, para não achar que travou enquanto o gerenciador baixa tudo.
22. Como quem instala numa máquina nova, quero que o README diga como confirmar que deu certo, para ter um critério em vez de uma impressão.
23. Como agente trabalhando neste repositório, quero que a configuração e a documentação concordem, para não precisar escolher em qual das duas acreditar.
24. Como agente trabalhando neste repositório, quero que o comportamento de mapeamento seja verificável por sonda headless, para afirmar sobre tecla medindo, não lendo o arquivo.
25. Como revisor desta mudança, quero que a suíte do painel de revisão continue verde, para saber que uma mudança de configuração não alcançou o plugin.

## Implementation Decisions

- **A causa-raiz dos defeitos de tecla é a caixa do keycode, não cada tecla.** O AstroCore guarda mapeamentos numa tabela indexada pela string do lado esquerdo; duas grafias da mesma tecla entram como duas chaves. O `normalize_mappings` do AstroCore junta as duas no `setup()`, percorrendo a tabela enquanto a altera — quando as duas existem, qual sobrevive muda de uma partida para outra. Medido: seis partidas do editor, resultados diferentes entre elas. Portanto a regra é uma só: **nunca escrever a mesma tecla em duas grafias**, e sempre na grafia do `:h keycodes`.
- O spec do AstroCore passa a ter todo lado esquerdo na grafia canônica (`<Leader>`, `<LocalLeader>`, `<Tab>`). A entrada que desligava `<Leader>p` sai; sobra um mapeamento só, que cola.
- `<Leader>p` fica com colar, e não com o menu "Plugins" do AstroNvim, que segue existindo nas subtaclas. A consequência — colar só acontece depois do `timeoutlen` — é aceita e registrada em comentário, porque sem isso ela se lê como defeito.
- `<C-Up>`/`<C-Down>` ficam com o cursor múltiplo e **não são declarados** na nossa configuração. O Visual-Multi reescreve as duas para os `<Plug>` dele quando carrega, então o estado de regime já é o desejado; declarar seria escrever algo que ele sobrescreve. Redimensionar split continua em `<C-Left>`/`<C-Right>`.
- O aviso de colisão do `:checkhealth astrocore` **fica**, com comentário explicando a causa: um terceiro escreve `<C-up>` e outro escreve `<C-Up>` na mesma tabela. Calá-lo exigiria `= false` numa das grafias, o que reintroduz as duas grafias nossas e o cara-ou-coroa. O conserto é no astrocommunity, e é trabalho à parte.
- Grupo de menu do which-key se nomeia com `desc`, não com `name`: o AstroCore deriva `group` de `desc`, e uma entrada com `name` é enfileirada sem nome.
- O spec do blink.cmp e o da camada de compatibilidade passam a usar o dono novo. O completamento do Conjure continua saindo da ponte de compatibilidade, porque o pack de Clojure do astrocommunity não fornece fonte própria.
- O spec do `vim-jack-in` é removido inteiro. As duas dependências saem com ele, e o `CLAUDE.md` passa a descrever o estado real.
- O arquivo de configuração do plugin de projeto removido no v6 é apagado. O ajuste equivalente de formatação do servidor de Lua já existe no arquivo que o próprio servidor lê.
- O lock é atualizado pelo próprio gerenciador, e o órfão sai do disco pela operação de limpeza dele — nada é editado à mão.
- A seção de instalação do README é reescrita em torno do arranjo que existe: clone dos dotfiles no repositório, link simbólico apontando para a pasta da configuração, e a afirmação explícita de que clonar sobre o lugar do link é o que desfaz o arranjo.
- Decisões de tecla ficam em comentário no arquivo onde a tecla é configurada, não em ADR: nenhuma é cara de reverter, e o leitor que precisa delas está olhando o arquivo.

## Testing Decisions

- **Um bom teste aqui afirma sobre o que o editor responde, não sobre o que o arquivo diz.** Ler o Lua de volta prova que o texto foi escrito; o que precisa de prova é qual tecla ficou mapeada ao quê depois de todo o empilhamento de specs, que é onde os defeitos nasceram.
- **A costura é o editor real, em headless, respondendo sobre os próprios mapeamentos**: `maparg` para cada tecla decidida, e `:checkhealth astrocore` para a colisão. Uma costura só, no ponto mais alto disponível — nada de novo é construído, porque o health check já existe no AstroCore exatamente para colisão de mapeamento.
- **Isto fica fora do `make test`, deliberadamente.** O `minimal_init` da suíte põe no runtimepath só este repositório, plenary, astrocore e mini.icons, sem AstroNvim e sem gerenciador de plugins, para que nenhum teste dependa da configuração real. Um spec que afirmasse sobre `<Leader>p` teria que carregar a configuração real e inverteria essa premissa; seria uma segunda costura, paga para testar uma tabela de constantes.
- Prior art da sonda: o molde de `docs/agents/debugging.md` — rodar a configuração real em headless e gravar o resultado num arquivo para leitura, em vez de imprimir na sessão.
- Prior art do que não muda: a suíte do painel de revisão roda inalterada e serve de controle. Se ela mexer, a mudança de configuração vazou para onde não devia.
- Medições que valem como evidência desta entrega: `maparg` de `<Leader>p`, `<Leader>y/Y/yy/P` nos modos normal e visual, `<Leader><Tab>`, `<LocalLeader>ts`, `<C-Up>` antes e depois de o Visual-Multi carregar, e `<C-Left>`; a saída de `:checkhealth astrocore`, `vim.deprecated` e `astronvim`; e o comportamento do AstroCore diante de `name` e de `desc` numa entrada de grupo.

## Out of Scope

- O inventário do que o NvChad tinha e o v6 não repôs — harpoon, `jj`, `;` por `:`, teclas de hunk, splits, snyk, Chrome de debug, link do GitHub, teclas de LSP, e o ajuste fino de `angularls`, `terraformls` e `pyright`. Está no ticket `nvi-01m28t7sxfk9`, para triagem item a item.
- O PR ao astrocommunity trocando `<C-up>` por `<C-Up>`, que é o que apaga o aviso de colisão para todos.
- Tudo do painel de revisão (`lua/review/`) e do fluxo do Agilis. Esta mudança não toca nem um nem outro; a suíte deles é controle, não alvo.
- A reformatação do lock em linha única, que já estava na árvore antes desta mudança.

## Further Notes

- Versões em que isto foi medido: AstroNvim v6.1.0, Neovim v0.12.2. O `:checkhealth vim.deprecated` já vinha limpo antes e continua — não havia dívida de API, só de configuração.
- O salto do NvChad para o v6 foi um commit só, e por isso o "antes" desta configuração não está em backup nenhum: está no git. O conteúdo original de qualquer peça se recupera pelo commit anterior a ele.
- A não-determinismo do `normalize_mappings` vale como aviso para qualquer mapeamento futuro: se o `:checkhealth astrocore` começar a acusar uma tecla nova, a pergunta certa é "quem escreveu a outra grafia", não "qual mapeamento está errado".

## Notes

**2026-09-11T19:01:04.797657245Z**

Entregue na branch astrovim6, em seis commits (4350afc..fa337c9). <Leader>p cola, grupo gm nomeado por desc, grafias na forma do :h keycodes, blink.cmp sob saghen/, vim-jack-in e .neoconf.json fora, README descrevendo o symlink. make lint 0/0/0 e make test 371 Success / 0 Failed / 0 Errors. O aviso de colisao em <C-Up>/<C-up> fica, documentado com a causa e medido como intermitente (2 de 8 partidas); o conserto e um PR ao astrocommunity, listado em Out of Scope junto com o inventario do NvChad (nvi-01m28t7sxfk9).
