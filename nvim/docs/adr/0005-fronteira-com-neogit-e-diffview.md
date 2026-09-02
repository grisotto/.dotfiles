# O painel move arquivos entre staged e unstaged, mas não commita nem resolve conflito

O painel implementa `stage`, `unstage` e `discard` porque mover arquivo entre
staged e unstaged é o gesto central da revisão e são chamadas diretas ao git.
Tudo além disso é delegado: commit interativo, amend, rebase e push ficam com o
neogit; o diff em aba, a comparação com outro rev e o merge tool 3-way ficam com
o diffview.

A fronteira parece arbitrária de fora ("por que faz metade das operações de
git?"), mas é deliberada: reimplementar resolução de conflito significaria
reescrever navegação entre conflitos e escolha de lado, que o diffview já tem
prontos e testados.

## Atualização: a comparação com outro rev ficou aqui (nvi-01m1d6hxjmxm)

A fatia que compara o arquivo com a versão dele em outro rev montou esse diff no
painel, e não no diffview, ao contrário do que esta decisão dizia. O que a moveu
foi o custo de cada lado: o painel já monta um diff de duas vias de um rev
contra o arquivo no disco — é exatamente o diff do unstaged, com outro rev à
esquerda —, então construí-lo é reusar o que existe, enquanto delegar seria uma
apresentação a menos coberta pelos testes (a delegação fica sem teste de
propósito). A fronteira continua onde estava para todo o resto: aba do diffview,
merge tool de três vias e navegação entre conflitos.
