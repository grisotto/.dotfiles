# Modos alternativos de diff coexistem como teclas distintas, não como opção de configuração

Onde havia dúvida genuína sobre qual apresentação de diff funciona melhor (diff
inline na aba do painel vs. aba do diffview; e, em conflito, três layouts
diferentes), todas as alternativas ficam ligadas ao mesmo tempo, em teclas
diferentes, em vez de atrás de uma opção de configuração.

O motivo é que uma opção de configuração se testa uma vez e nunca mais: o
revisor esquece qual está ativa e nunca compara de verdade. Teclas paralelas
permitem comparar as alternativas no mesmo arquivo, no mesmo minuto, e o que
sobrar no uso vira o padrão.

## Consequences

Um leitor futuro vai encontrar teclas quase redundantes e pode querer "limpar"
isso. A redundância é temporária e proposital; apagar as perdedoras é uma linha
cada, e só deve acontecer depois que o uso decidir.

## Atualização: o painel sair da tela ao ler é uma opção

`close_on_diff` é uma opção, e não uma tecla, e isso não contradiz o que está
acima: ela não escolhe entre duas apresentações de diff que valha comparar lado
a lado. O diff é o mesmo com ela ou sem ela; o que muda é quem tira a lista da
tela. Tirar a lista já é uma tecla (`q` no painel, `<Leader>r`) e continua
sendo com a opção ligada; o que a opção acrescenta é a entrada no diff fazer o
mesmo. Como tecla, isso seria um gesto a mais antes de cada arquivo lido —
justamente o que ela existe para poupar —, e uma tecla que só valeria "da
próxima vez que entrar no diff" é uma opção com outro nome.

É da mesma natureza do `seen_display` e do `neo_tree`: como a tela se arranja, e
não qual apresentação ler. Desligada no plugin, porque o painel é o ponto de
partida de toda ação e uma lista que sai sozinha é uma lista que o revisor tem
que chamar de volta; ligada em `lua/polish.lua`, que é a escolha deste revisor.

## Atualização: o relatório em dois formatos

O relatório de revisão é entregue a um agente de IA, e não se sabe se ele entende
melhor um documento em tags XML ou em markdown. Os dois ficam ligados, em teclas
diferentes: `R` gera em XML e `M` em markdown. O conteúdo é o mesmo nos dois — os
mesmos itens, na mesma ordem, com os mesmos `id` e o mesmo preâmbulo —, e só a
sintaxe muda, para que comparar os dois meça o formato e nada mais.

Como o tipo da anotação é escolhido é uma opção, e não uma tecla: no seletor
antes do texto (o padrão) ou escrito na frente dele (`question: …`). Não são duas
apresentações do mesmo resultado para comparar lado a lado, e sim dois jeitos de
escrever, que não convivem na mesma entrada — com os dois, o tipo seria pedido
duas vezes.
