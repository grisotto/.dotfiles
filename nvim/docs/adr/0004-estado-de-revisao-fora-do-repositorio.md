# O estado de revisão vive fora do repositório

Visto, anotações e relatórios são gravados sob o diretório de dados do Neovim,
identificados pelo caminho do repositório, e nunca dentro do repositório
revisado. Revisão é um artefato pessoal e temporário; escrever no working tree
sujaria justamente a lista que o painel está mostrando, fazendo os próprios
arquivos da revisão aparecerem como untracked no meio dela.

A consequência assumida é que nada disso é compartilhável com o time: quem
quiser passar as observações adiante usa o relatório de revisão, que existe
exatamente para sair do editor.
