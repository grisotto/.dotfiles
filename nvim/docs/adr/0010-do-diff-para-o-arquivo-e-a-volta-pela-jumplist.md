# Do diff para o arquivo, e a volta pela jumplist

De dentro do diff, uma tecla (`go`) troca a comparação pelo arquivo no disco, no
ponto que está sendo lido. A volta é o `<C-o>` do próprio editor, com o diff um
passo atrás do arquivo na jumplist.

Um diff são duas versões lado a lado e mais nada. No modo commit os dois lados
são buffers somente leitura de história, sem arquivo por trás: não há servidor de
linguagem, não há ir para a definição, não há editar. Quem leu até uma linha e
quer *fazer* alguma coisa — corrigir, seguir uma chamada, entender o que
chama aquilo — está pedindo o arquivo, e está pedindo naquela linha. O `o` do
painel já abria o arquivo, mas no topo dele, e o topo não é o que foi pedido: a
posição é o pedido inteiro.

O ponto é reencontrado pelo **texto** da linha, e não pelo número dela, que é a
mesma decisão da âncora das anotações (ADR-0003). O lado que está sendo lido é
uma versão do arquivo — o índice, um commit —, e a numeração de lá não vale no
disco depois de qualquer mudança acima. A busca é do número para fora, porque um
arquivo repete linhas e, de duas iguais, a mais perto de onde o revisor estava é
a que ele estava lendo. Linha em branco ou curta demais não ancora nada — metade
de um arquivo é `end` —, e ali o número é o que há; quando o texto não está no
arquivo, a tecla vai para o número e diz que foi isso que fez, em vez de fingir
que acertou.

Mapear a linha pelo alinhamento do próprio diff (as linhas de preenchimento, a
linha da tela) foi rejeitado: só responde enquanto os dois lados estão na tela, e
no modo commit não responde nada — o arquivo no disco não é nenhum dos dois
lados, então não há alinhamento nenhum para ler.

A tecla é `go` e não `o` porque um dos lados do diff é o buffer do arquivo do
revisor, onde `o` abre uma linha e entra em inserção. Vale aqui a mesma regra das
teclas do laço: as do diff são as que não custam nada ao arquivo. O que `g o`
sobrepõe é o "ir para o byte N" do editor, e só enquanto o diff está montado.

A volta não é tecla nossa. Voltar não é gesto novo: o revisor entra no arquivo
pela linha que estava lendo, anda dali para uma definição e para outros arquivos,
e volta pelo caminho que veio — que é a jumplist. Então o diff fica logo abaixo
do fundo dela. Enquanto o pulo é dentro do arquivo, o `<C-o>` é o do editor,
fazendo o que sempre fez; o que o diff toma para si é o único pulo que sairia do
arquivo, que é o que passaria por cima do que estava sendo lido. Quem responde
para onde esse pulo iria, sem pular, é o `getjumplist`.

Uma tecla própria para voltar foi rejeitada: seria mais uma para aprender, teria
de ser escrita no arquivo do revisor do mesmo jeito, e competiria com o gesto que
ele já tem nos dedos. Reabrir pelo painel também: a linha teria de ser procurada
de novo, que é justamente o que a ida resolveu.

## Consequences

O mapeamento da volta fica no buffer do arquivo do revisor enquanto vale, e sai
de lá quando deixa de valer — na volta ao diff, ou quando outro diff é montado
naquela aba —, devolvendo o que estava embaixo dele. É a mesma disciplina das
teclas do diff, e pelo mesmo motivo: o arquivo é dele, não nosso.

Uma tecla que o editor guarda em bytes de modificador (`<C-o>` é listado como
`<C-O>`) não pode ser comparada como está escrita na configuração. A comparação
passa pelo `keytrans`, que é a resposta do próprio editor para "que tecla é
esta"; sem isso um mapeamento nosso não seria reconhecido na hora de sair, e
ficaria no arquivo do revisor para sempre.

No modo commit o que a ida abre é o arquivo de **hoje**, e não a versão do
commit: é onde se age sobre o que se acabou de ler. Ver o conteúdo daquele rev
continua sendo `e`, e comparar com ele, `E`.

A ida fecha o diff, e a volta o monta de novo — não é a mesma janela guardada
para depois. É o que faz a volta funcionar com o painel aberto ou fechado
(ADR-0009): o diff é remontado onde houver espaço, e o painel é perguntado na
hora, não lembrado.
