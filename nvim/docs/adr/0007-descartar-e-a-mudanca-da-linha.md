# Descartar age sobre a mudança da linha, e um conflito não se descarta

O que "descartar" apaga é decidido pela seção da linha, e não pelo arquivo: numa
linha unstaged, o arquivo volta ao que está no índice, preservando o que já foi
staged; numa linha staged, ele volta ao que está no HEAD, no índice e no disco de
uma vez; numa linha untracked, o arquivo sai do disco.

Descartar o arquivo inteiro a partir de qualquer linha, como faz o rollback do
IntelliJ, foi rejeitado: o painel lista a mudança staged e a unstaged do mesmo
arquivo como duas linhas separadas, e uma tecla que apagasse as duas a partir de
qualquer uma delas contradiria a lista que o revisor está lendo.

A linha staged é a exceção, e é assumida: dela não existe descarte parcial. Pôr
o índice de volta sem tocar no disco é exatamente o que a tecla de tirar de
staged já faz, então descartar dali só pode significar as duas coisas — e leva
junto a linha unstaged do mesmo arquivo, se houver uma. É por isso que a pergunta
feita antes nomeia as duas ("staged e no disco") em vez de só dizer o nome do
arquivo.

## Consequences

Um conflito fica sem descartar, e também sem sair do índice. A mudança dele não é
uma só — são dois lados — e escolher um é resolução de conflito, que é do merge
tool (ADR-0005). As duas teclas avisam, em vez de escolher um lado caladas: um
`git reset` num caminho conflitado joga fora os lados que o git guarda no índice
e deixa o arquivo parecendo mesclado, com os marcadores ainda dentro dele.

O que o painel sabe fazer com um conflito é o contrário disso: mover para staged
é o `git add` que registra a resolução já feita no merge tool.
