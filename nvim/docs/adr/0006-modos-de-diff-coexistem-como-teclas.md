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
