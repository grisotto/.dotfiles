# "Visto" é chaveado pelo hash do conteúdo, não pelo caminho do arquivo

A marca de visto usa o blob sha do conteúdo (`git hash-object`) como chave, e não
o caminho. Isso dá duas propriedades de graça: um arquivo que muda depois de
marcado volta a aparecer como não-visto (que é o comportamento que importa em
revisão), e o mesmo conteúdo revisado em um commit já aparece visto no working
tree, sem dois espaços de chaves separados.

O preço é que um arquivo pode aparecer pré-marcado num contexto que o revisor
nunca abriu — aceitável, porque o conteúdo é literalmente idêntico ao que ele já
leu.

## Considered Options

Chavear por `(caminho, contexto)` foi rejeitado: exigiria invalidar o visto na
mão a cada edição e manteria espaços de chaves separados para commit e working
tree, fazendo o revisor reler conteúdo idêntico.
