# Anotação de commit é presa ao commit

No modo commit, e no intervalo, a anotação é escrita no lado de depois do diff —
o conteúdo do commit — e guarda a linha que ela tem ali. Na geração do relatório
ela não é reancorada: o commit não muda, e o agente que recebe o relatório
encontra a linha pelo sha (`git show <sha>:<arquivo>`). A reancoragem do ADR-0003
fica restrita ao que ainda muda depois de anotado — o arquivo no disco e o
índice —, e é no disco que as duas são reancoradas.

Reancorar a anotação de commit no disco foi rejeitado. O revisor leu o commit, e
é sobre o texto do commit que ele escreveu; o disco diverge dele assim que o
agente trabalha em cima, e uma anotação sobre uma linha que o agente já mudou
sairia deslocada justamente quando ela é mais útil. Um commit antigo tem uma
referência exata, e o agente sabe ir até ela.

## Consequences

Um relatório de commit tem uma referência só, o commit. Por isso, no modo commit,
anotar o arquivo de hoje (depois do `go`) é recusado, e o aviso aponta de volta
para o diff: aceitar poria no mesmo documento linhas do commit e linhas do disco,
e o número de cada item dependeria de onde ele foi escrito.

A quickfix é a exceção, e de propósito: ela é a navegação do revisor, e o revisor
anda pelo arquivo de hoje. Os itens dela são reancorados no disco, e o que não é
achado vai sem linha. O relatório e a quickfix podem citar linhas diferentes para
o mesmo `#id` — o relatório diz onde a linha está no commit, a quickfix diz onde
ela está agora.

As anotações de modo commit gravadas antes desta decisão foram escritas no
arquivo de hoje e não guardam versão. Elas são reancoradas contra o conteúdo do
commit: achadas ali, viram anotações do commit como as outras; não achadas, saem
como não encontradas.

Uma anotação de commit nunca sai deslocada.
