local M = {}

local group = vim.api.nvim_create_augroup("agilis_workflow", { clear = true })

local function notify(message, level) vim.notify(message, level or vim.log.levels.INFO, { title = "Agilis" }) end

function M.root(bufnr)
  bufnr = bufnr or 0
  local path = vim.api.nvim_buf_get_name(bufnr)
  if path == "" then path = vim.fn.getcwd() end

  local root = vim.fs.root(path, "workspace.edn")
  if not root then return nil end

  local required = { "bb.edn", "shadow-cljs.edn", "bases/webapp" }
  for _, relative in ipairs(required) do
    if not (vim.uv or vim.loop).fs_stat(root .. "/" .. relative) then return nil end
  end
  return root
end

local function current_root()
  local root = M.root()
  if not root then notify("O buffer atual não pertence ao projeto Agilis.", vim.log.levels.WARN) end
  return root
end

local function run_in_terminal(argv, title)
  local root = current_root()
  if not root then return end

  vim.cmd "botright 15new"
  local bufnr = vim.api.nvim_get_current_buf()
  vim.bo[bufnr].bufhidden = "wipe"
  local job = vim.fn.jobstart(argv, {
    cwd = root,
    term = true,
    on_exit = function(_, code)
      vim.schedule(
        function()
          notify(("%s terminou com código %d."):format(title, code), code == 0 and nil or vim.log.levels.ERROR)
        end
      )
    end,
  })
  if job <= 0 then
    notify("Não foi possível iniciar " .. title .. ".", vim.log.levels.ERROR)
    return
  end
  vim.cmd "startinsert"
end

function M.connect_backend()
  if not current_root() then return end
  vim.cmd "ConjureConnect localhost 7888"
end

function M.connect_shadow()
  local root = current_root()
  if not root then return end

  local port_file = root .. "/.shadow-cljs/nrepl.port"
  local ok, lines = pcall(vim.fn.readfile, port_file)
  local port = ok and vim.trim(lines[1] or "") or ""
  if not port:match "^%d+$" then
    notify("Shadow CLJS não está pronto: porta não encontrada.", vim.log.levels.WARN)
    return
  end

  vim.cmd("ConjureConnect localhost " .. port)
  vim.defer_fn(function()
    local selected, err = pcall(vim.cmd, "ConjureShadowSelect main")
    if not selected then notify("Falha ao selecionar o build main: " .. err, vim.log.levels.ERROR) end
  end, 800)
end

function M.format_current_file()
  local root = current_root()
  if not root then return end

  local bufnr = vim.api.nvim_get_current_buf()
  local path = vim.api.nvim_buf_get_name(bufnr)
  if path == "" then
    notify("Salve o arquivo antes de formatar.", vim.log.levels.WARN)
    return
  end
  if vim.bo[bufnr].modified then vim.api.nvim_buf_call(bufnr, function() vim.cmd.write() end) end

  vim.system({ "bb", "fmt", path }, { cwd = root, text = true }, function(result)
    vim.schedule(function()
      if result.code == 0 then
        if vim.api.nvim_buf_is_valid(bufnr) then vim.api.nvim_buf_call(bufnr, function() vim.cmd.checktime() end) end
        notify "Arquivo formatado com bb fmt."
      else
        local output = vim.trim((result.stdout or "") .. "\n" .. (result.stderr or ""))
        notify(output ~= "" and output or "bb fmt falhou.", vim.log.levels.ERROR)
      end
    end)
  end)
end

function M.test_current_brick()
  local root = current_root()
  if not root then return end

  local path = vim.api.nvim_buf_get_name(0)
  local relative = path:sub(#root + 2)
  local brick = relative:match "^components/([^/]+)/" or relative:match "^bases/([^/]+)/"
  if not brick then
    notify("Não foi possível obter o brick a partir deste arquivo.", vim.log.levels.WARN)
    return
  end
  run_in_terminal(
    { "clojure", "-M:poly", "test", "project:development", "brick:" .. brick },
    "Teste do brick " .. brick
  )
end

function M.test_cljs() run_in_terminal({ "bb", "test:cljs" }, "Testes ClojureScript") end

function M.lint() run_in_terminal({ "clj-kondo", "--lint", "components/", "bases/", "projects/" }, "clj-kondo") end

function M.halt_nrepl() run_in_terminal({ "bb", "nrepl:halt" }, "Parada do backend") end

function M.open_webapp()
  if not current_root() then return end
  vim.ui.open "http://localhost:3000/"
end

local mappings = {
  { "<Leader>ab", M.connect_backend, "Agilis: conectar backend" },
  { "<Leader>as", M.connect_shadow, "Agilis: conectar Shadow CLJS" },
  { "<Leader>af", M.format_current_file, "Agilis: formatar arquivo" },
  { "<Leader>at", M.test_current_brick, "Agilis: testar brick atual" },
  { "<Leader>aT", M.test_cljs, "Agilis: testar ClojureScript" },
  { "<Leader>al", M.lint, "Agilis: executar lint" },
  { "<Leader>ah", M.halt_nrepl, "Agilis: parar backend" },
  { "<Leader>ao", M.open_webapp, "Agilis: abrir webapp" },
}

function M.attach(bufnr)
  if not M.root(bufnr) then return end
  for _, mapping in ipairs(mappings) do
    vim.keymap.set("n", mapping[1], mapping[2], { buffer = bufnr, desc = mapping[3], silent = true })
  end

  local ok, which_key = pcall(require, "which-key")
  if ok then which_key.add { { "<Leader>a", group = "Agilis", buffer = bufnr } } end
end

function M.setup()
  local commands = {
    AgilisConnectBackend = M.connect_backend,
    AgilisConnectShadow = M.connect_shadow,
    AgilisFormat = M.format_current_file,
    AgilisTestBrick = M.test_current_brick,
    AgilisTestCljs = M.test_cljs,
    AgilisLint = M.lint,
    AgilisHalt = M.halt_nrepl,
    AgilisOpen = M.open_webapp,
  }
  for name, callback in pairs(commands) do
    vim.api.nvim_create_user_command(name, callback, { desc = name:gsub("^Agilis", "Agilis: ") })
  end

  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    callback = function(args) M.attach(args.buf) end,
  })
end

return M
