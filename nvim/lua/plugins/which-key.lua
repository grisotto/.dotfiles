-- O menu do which-key é ancorado no rodapé. Com `no_overlap` ligado, que é o
-- padrão, `view.lua:check_overlap` empurra a janela para baixo do cursor quando
-- ela o cobriria, e força altura mínima 4 mesmo sem espaço: numa tela de 35
-- linhas, com o cursor no fim do arquivo, a janela nasce fora da tela. O menu
-- some, ou sobra só a borda com o título — que no `,` é `Prev ftFT`, o rótulo
-- do preset de movimentos, e não o menu do Conjure.
--
-- Isto não é regressão de versão: o código é idêntico no `main` do plugin.
-- Deixar a janela sobrepor o cursor é a troca certa aqui; a linha do cursor não
-- é o que se lê enquanto se escolhe uma tecla.

---@type LazySpec
return {
  "folke/which-key.nvim",
  opts = { win = { no_overlap = false } },
}
