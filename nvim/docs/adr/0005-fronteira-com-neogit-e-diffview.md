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
