---Options of the review panel.
---
---Only presentation and coexistence choices live here. What is data model
---rather than preference — the panel being single with a mode, the boundary
---with neogit — is deliberately not exposed.
---
---The form of the annotation entry is not an option either, though the spec of
---the epic lists it as one. It went the way the two diff presentations went
---(ADR-0006): where both forms are worth having, they are both switched on, on
---keys of their own, instead of one of them being hidden behind a setting the
---reviewer has to change to reach it. Which key opens which entry is
---configurable here like every other key; that is the whole of the preference
---there is to express.
local M = {}

---@class ReviewMappings
---@field close string key that closes the panel from inside it
---@field refresh string key that re-reads git and re-renders
---@field diff string key that opens what the line represents
---@field diff_alternate string key that opens the same thing the other way
---@field diff_conflict string key that opens the three versions of a conflict beside the panel
---@field preview string key that turns the preview on and off while the panel is open
---@field open string key that opens the file in the window beside the panel
---@field open_split string key that opens the file in a split
---@field open_rev string key that opens the file as it is in another rev, read only
---@field diff_rev string key that compares the file with its version in another rev
---@field toggle_seen string key that marks the file on the line as seen, or unmarks it
---@field seen_and_next string key that marks it as seen and moves to the next one still to read
---@field next_unseen string key of the diff that opens the next file still to read
---@field previous_unseen string key of the diff that opens the previous one still to read
---@field next_file string key of the diff that opens the next file, the seen ones included
---@field previous_file string key of the diff that opens the previous one, the seen ones included
---@field next_change string key of the diff that goes to the next change inside the file
---@field previous_change string key of the diff that goes to the previous change inside it
---@field open_here string key of the diff that opens the file on disk at the point being read
---@field back_to_diff string key that brings the diff back from the file it was left for
---@field annotate string key that writes the annotation of the file on the line
---@field annotate_long string key that writes it in the entry of several lines
---@field annotate_line string global key that writes the annotation of the line being read, or of the lines selected
---@field annotate_line_long string global key that writes it in the entry of several lines
---@field seen_and_open_next string global key that marks what is being read as seen and opens the next one still to read
---@field help string key of the panel and of the diff that lists every key of where the reviewer is
---@field report string key that generates the report of the review under way, in XML
---@field report_markdown string key that generates the same report in markdown
---@field graph string key that opens the graph of commits, to review one of them
---@field graph_alternate string key that opens the graph the other way
---@field branch string key of the graph that restricts it to a branch chosen in a search
---@field worktree string key that leaves the commit mode and lists the working tree again
---@field stage string key that moves the file on the line into the index
---@field unstage string key that takes the file on the line out of the index
---@field discard string key that throws the change on the line away, after confirming
---@field copy_relative_path string key that copies the path from the root of the file's project
---@field copy_absolute_path string key that copies the whole path of the file

---@class ReviewMergeLayouts diffview layouts a conflict opens in
---@field conflict string ours, the merge and theirs
---@field conflict_with_base string the same, plus the base version

---@class ReviewConfig
---@field position "left"|"right" side of the editor the panel opens on
---@field width integer width of the panel in columns
---@field seen_display "section"|"dimmed" where a file marked as seen is shown
---@field preview boolean whether the panel starts with the diff following its cursor
---@field close_on_diff boolean whether going into the diff of a line takes the panel off the screen
---@field neo_tree "close"|"ignore" what to do with a neo-tree window in the way
---@field report_directory string|nil where the review report is written
---@field annotation_types ReviewAnnotationType[] types added to the built-in ones, or replacing the instruction of one
---@field mappings ReviewMappings
---@field merge_layouts ReviewMergeLayouts
local defaults = {
  position = "left",
  width = 40,
  -- The types of an annotation the reviewer adds to the eight built in — the
  -- ones of the Conventional Comments, `issue` first —, each with what it asks
  -- the agent for. A name that is already a type replaces its instruction; a
  -- new one goes after the others, in the order given here. The list is the
  -- reviewer's alone, and the built-in types live with the annotation: the
  -- options are merged by `vim.tbl_deep_extend`, which takes a list whole, and
  -- a list written here would replace all eight instead of adding to them.
  annotation_types = {},
  -- Where the report is written, as an absolute path. Absent, it goes beside
  -- the review state under the editor's data directory — outside the
  -- repository being reviewed, which is the part that is not a preference
  -- (ADR-0004). Pointing it at a directory inside the repository is the
  -- reviewer's own doing, and the panel says so: the report shows up as
  -- untracked in the list it is displaying.
  --
  -- The default is resolved when the report is generated and not here, so it
  -- follows the data directory of the editor that is running instead of the
  -- one that was running when the options were read.
  report_directory = nil,
  -- Both presentations of a seen file are meant to be tried in use: the
  -- section of its own at the end, which leaves only what is left on the list,
  -- and the dimming in place, which keeps the file where it is.
  seen_display = "section",
  -- Off, because the reviewer going down the list is most of the time on their
  -- way to one file: switched on, the sweep pays for reading every file it
  -- passes. Whoever is sweeping turns it on with the key and turns it off when
  -- they start reading for real — which is why it is a key and not only this
  -- option (ADR-0006). This is the state the panel of a tabpage opens in.
  preview = false,
  -- Off, because the panel is where every action of the review starts from, and
  -- a list that leaves the screen on its own is one the reviewer has to call
  -- back. On, going into the diff of a line — the key that opens it, or the
  -- focus arriving at a diff the preview drew — gives the diff the whole width,
  -- and the key that closes the diff brings the list back. The review walks with
  -- the list off screen either way (ADR-0009).
  --
  -- An option and not a key, unlike the presentations of a diff: it does not
  -- choose between two ways to read a file, it chooses who takes the list off
  -- the screen — and a key for that would be one more gesture before every file
  -- read, which is what the option is there to spare (ADR-0006).
  close_on_diff = false,
  neo_tree = "close",
  mappings = {
    close = "q",
    refresh = "r",
    -- Two keys for the same line, on purpose: the default presentation and the
    -- alternative one, to be compared in use before either becomes the
    -- standard (ADR-0006).
    diff = "<CR>",
    diff_alternate = "d",
    -- A conflict has a third presentation, and it gets the shifted key beside
    -- the other one: the pair reads like the copy keys below, two forms of the
    -- same gesture, and this is the form that keeps the list on screen.
    diff_conflict = "D",
    -- "p" de "preview", e é uma tecla do painel e não de uma linha dele: o que
    -- ela liga é o modo de varredura da lista inteira. Numa lista, colar não é
    -- gesto de ninguém.
    preview = "p",
    open = "o",
    open_split = "O",
    -- "e" de "em outro rev", e o par lê como os de cima: a tecla simples é a
    -- consulta — o arquivo como ele está lá, para ler —, a shifted é a
    -- comparação com o que está aqui. Como "v" e "w", a tecla é local a uma
    -- lista, onde andar por palavra não é gesto de ninguém.
    open_rev = "e",
    diff_rev = "E",
    -- "v" for "visto". The key is local to the panel's buffer, which is a
    -- list, not text to select in visual mode.
    toggle_seen = "v",
    -- Mark this one and go to the next one still to read, which is the gesture
    -- that closes a file's review from inside the list. The space bar because
    -- it is what "the next one" is in every reader that has one — a pager
    -- taking the page down, a list ticking an item off — and, like "v" for
    -- visto, because the key is local to a list, where moving one column to the
    -- right is not a gesture anyone has.
    --
    -- It is also the Leader of this configuration, and the one key of the panel
    -- that waits before acting because of it (`acts_at_once`, in the panel).
    seen_and_next = "<Space>",
    -- The same loop from inside the diff, which is where the reviewer is
    -- nearly all the time: the plain pair walks what is left to read and the
    -- shifted one walks everything, which is how a file already seen is gone
    -- back to. The brackets because they are the editor's own idiom for "the
    -- next one of this kind", and because they cost the file nothing: the
    -- working tree side of a diff is the reviewer's own buffer, where `<Tab>`
    -- is indentation and `v` is visual mode.
    next_unseen = "]f",
    previous_unseen = "[f",
    next_file = "]F",
    previous_file = "[F",
    -- The pair inside the file, under the same brackets as the two above and
    -- one scale below them: the reviewer walks the changes of a file and then
    -- walks to the next file. They are the editor's own keys for the changes of
    -- a diff, taken over so that the end of a file is not a dead key — there
    -- they say it is the end, and pressing again goes on into the next file
    -- still to read, which is where `]f` was going to take the reviewer anyway.
    next_change = "]c",
    previous_change = "[c",
    -- "o" de "abrir", que é a tecla do painel, com o `g` na frente porque esta
    -- vale de dentro do diff: um dos lados dele é o arquivo do revisor, onde
    -- `o` sozinho abre uma linha e entra em inserção. O que o `g` shadowa é o
    -- "ir para o byte N" do editor, que não é gesto de ninguém, e só enquanto o
    -- diff está montado.
    open_here = "go",
    -- A volta é a do editor, e não uma tecla nova: quem entrou no arquivo pelo
    -- diff anda dali por definições e outros arquivos, e volta pelo caminho que
    -- veio. O diff fica um passo atrás do arquivo nessa lista — o `<C-o>` segue
    -- sendo o do editor enquanto o pulo é dentro do arquivo, e é nosso no pulo
    -- que sairia dele.
    back_to_diff = "<C-o>",
    -- "a" for "anotar", and the pair reads like the copy keys below: the plain
    -- key is the one-line remark, which is nearly every remark, and the shifted
    -- one opens the entry of several lines for when it is not.
    annotate = "a",
    annotate_long = "A",
    -- The same pair from inside the file being read, where `a` is the editor's
    -- own append and so the pair goes behind the Leader. Unlike every other key
    -- here these are global: `setup` maps them from these values, in normal
    -- mode for the line and in visual mode for the run of lines selected, and
    -- the winbar of the diff writes them from the same values.
    annotate_line = "<Leader>ga",
    annotate_line_long = "<Leader>gA",
    -- The `<Space>` of the panel from inside the file being read, global like
    -- the pair above and mapped by `setup` for the same reason: the help of the
    -- diff lists it, and lists the key that is really mapped. `v` is the letter
    -- of visto, as in the panel; alone, in a file, it is visual mode.
    seen_and_open_next = "<Leader>gv",
    -- "?" is what help is in the readers that have one, and the `g` in front is
    -- what lets it be the same key in the panel and in the diff: one side of a
    -- diff is the reviewer's own file, where `?` alone is the search backwards.
    -- What the `g` shadows there is the editor's rot13, and only while the diff
    -- is up — diffview and mason answer the same key the same way. In the panel
    -- `gg` still reaches the top: `g?` is not a prefix of it.
    help = "g?",
    -- "R" for "relatório", beside the "r" that refreshes: the two are the
    -- panel's own keys, about the review and not about a line of it. The report
    -- goes to an agent, and whether it reads tags XML or markdown better is not
    -- known yet, so both are switched on to be compared in use (ADR-0006): "R"
    -- writes it in XML, and "M" for "markdown" writes the same report in
    -- markdown. What "M" shadows is the jump to the middle of the window, in a
    -- list that is rarely taller than it.
    report = "R",
    report_markdown = "M",
    -- "c" for "commits", and the pair reads like the diff keys: the plain key
    -- is the graph built beside the panel, the shifted one the gitgraph's
    -- drawing of the same history, both switched on to be compared in use
    -- (ADR-0006). Not "g", which is a prefix — the panel is a list, and `gg`
    -- has to keep taking the reviewer to the top of it.
    graph = "c",
    graph_alternate = "C",
    -- "b" for "branch", and it is a key of the graph, not of the panel: the
    -- filter exists for the reviewer already looking at the history and finding
    -- too much of it. The panel's own keys are all about the list in front of
    -- it.
    branch = "b",
    -- "w" for "working tree", which is the mode it goes back to. Like "v" for
    -- visto, the key is local to a list, where moving by word is not a gesture
    -- anyone has.
    worktree = "w",
    -- The letters the git plugins already use for these, so the gesture is the
    -- one the reviewer's fingers know. Discarding is the shifted key: it is the
    -- one that loses work, and it does not sit next to the other two.
    stage = "s",
    unstage = "u",
    discard = "X",
    -- "y" for yank, and the pair reads like the one above it: the plain key is
    -- the short path, the shifted one the whole path. The relative path gets
    -- the plain key because it is the one that goes into a PR or a message.
    copy_relative_path = "y",
    copy_absolute_path = "Y",
  },
  merge_layouts = {
    conflict = "diff3_horizontal",
    conflict_with_base = "diff4_mixed",
  },
}

---@type ReviewConfig
M.options = vim.deepcopy(defaults)

---@param options ReviewConfig
local function validate(options)
  if options.position ~= "left" and options.position ~= "right" then
    error(('review: position must be "left" or "right", got %q'):format(tostring(options.position)))
  end
  if type(options.width) ~= "number" or options.width < 1 then
    error(("review: width must be a positive number, got %s"):format(tostring(options.width)))
  end
  if options.seen_display ~= "section" and options.seen_display ~= "dimmed" then
    error(('review: seen_display must be "section" or "dimmed", got %q'):format(tostring(options.seen_display)))
  end
  -- A typo would be silent otherwise: anything that is not `false` reads as the
  -- preview being on, and the panel would draw a diff on every move of the
  -- cursor without the reviewer having asked for it.
  if type(options.preview) ~= "boolean" then
    error(("review: preview must be a boolean, got %s"):format(tostring(options.preview)))
  end
  -- The same silence as the preview's: anything that is not `false` would read
  -- as on, and the list would leave the screen without the reviewer asking.
  if type(options.close_on_diff) ~= "boolean" then
    error(("review: close_on_diff must be a boolean, got %s"):format(tostring(options.close_on_diff)))
  end
  -- A typo here would be silent otherwise: any value that is not "close" reads
  -- as "ignore", so the panel would just quietly stop making room for itself.
  if options.neo_tree ~= "close" and options.neo_tree ~= "ignore" then
    error(('review: neo_tree must be "close" or "ignore", got %q'):format(tostring(options.neo_tree)))
  end
  -- Absent is the default — beside the review state. Anything else has to be a
  -- directory, and an absolute one: a relative path is resolved from the
  -- editor's current directory, which during a review is the repository being
  -- reviewed, and the report would land in the very list the panel is showing
  -- (ADR-0004).
  if options.report_directory ~= nil then
    if type(options.report_directory) ~= "string" or options.report_directory == "" then
      error(("review: report_directory must be a non-empty string, got %s"):format(tostring(options.report_directory)))
    end
    if not vim.startswith(options.report_directory, "/") then
      error(("review: report_directory must be an absolute path, got %q"):format(options.report_directory))
    end
  end
  -- A type is a word the report writes as it is — in an attribute of the XML,
  -- in a heading of the markdown, at the start of a line of the quickfix — and
  -- one without an instruction is a type the preamble cannot explain. A table
  -- keyed by name instead of a list would be silently empty.
  if not vim.islist(options.annotation_types) then
    error "review: annotation_types must be a list of { name, instruction }"
  end
  for position, kind in ipairs(options.annotation_types) do
    if type(kind) ~= "table" or type(kind.name) ~= "string" or not kind.name:match "^[%w_-]+$" then
      error(("review: annotation_types[%d].name must be a word, got %s"):format(position, vim.inspect(kind)))
    end
    if type(kind.instruction) ~= "string" or vim.trim(kind.instruction) == "" then
      error(("review: annotation_types[%d].instruction must be a non-empty string"):format(position))
    end
  end
  for name, key in pairs(options.mappings) do
    if type(key) ~= "string" or key == "" then
      error(("review: mappings.%s must be a non-empty string, got %s"):format(name, tostring(key)))
    end
  end
  -- The names themselves are the diffview's to validate; what would be silent
  -- here is a value that is not a layout name at all.
  for name, layout in pairs(options.merge_layouts) do
    if type(layout) ~= "string" or layout == "" then
      error(("review: merge_layouts.%s must be a non-empty string, got %s"):format(name, tostring(layout)))
    end
  end
end

---Replace the options with the defaults overridden by `opts`.
---@param opts table|nil
---@return ReviewConfig
function M.setup(opts)
  local options = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
  -- The "~" of a path written by hand is the reviewer's shorthand for their
  -- home, and what the report writes into is the directory it stands for.
  if type(options.report_directory) == "string" then
    options.report_directory = vim.fs.normalize(options.report_directory)
  end
  validate(options)
  M.options = options
  return options
end

return M
