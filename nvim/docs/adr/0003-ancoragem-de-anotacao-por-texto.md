# Anotações são ancoradas pelo texto da linha, não só pelo número

Cada anotação guarda o número da linha e também o texto daquela linha (a
âncora). Na hora de gerar o relatório, se o texto não bate mais, a âncora é
procurada no arquivo e a anotação é reancorada; se não for encontrada, ela sai
marcada como deslocada em vez de ser descartada ou de apontar para a linha
errada.

Guardar só o número da linha faria a anotação apontar para o lugar errado depois
de qualquer edição acima dela. Extmarks resolveriam isso com precisão, mas só
enquanto o buffer estivesse aberto — e anotações precisam sobreviver a fechar o
editor.

## Atualização: só o que ainda muda é reancorado

A reancoragem vale para a anotação escrita sobre o arquivo no disco ou sobre o
índice, e as duas são reancoradas no disco. A anotação de um commit fica na linha
do commit, que não muda — veja o ADR-0011.
