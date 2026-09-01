# Painel de revisão próprio, em vez de enxertar no neogit ou no diffview

O fluxo de revisão desejado precisa de estado por arquivo (visto, anotações) e de
teclas próprias por linha, e nem o neogit nem o diffview expõem API para
adicionar isso aos buffers deles: enxertar significaria fazer parsing do buffer
alheio, que quebra a cada atualização dos plugins. Por isso o painel é um buffer
próprio alimentado por `git status --porcelain=v2`, e os plugins existentes
continuam donos do que já fazem bem.

Uma consequência é que existe **um único painel com modo** (working tree ou
commit) em vez de um painel por contexto: o mesmo conjunto de teclas vale em
qualquer modo, ao custo de o painel não conseguir mostrar dois contextos ao
mesmo tempo.

Único aqui é **por aba do Neovim**: cada aba tem o seu painel, com o seu
repositório e o seu mapa de linha para entrada. Quem revisa dois repositórios ao
mesmo tempo põe cada um numa aba (`:tcd`), e o painel de uma aba nunca mostra o
que está na outra.
