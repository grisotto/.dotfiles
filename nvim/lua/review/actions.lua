---What a key of the review does: the keys on a line of the panel, and the one
---the reviewer presses in the code they are reading.
---
---Opening the line has more than one key on purpose (ADR-0006): one for the
---way it opens by default, and one for each alternative presentation of the
---same thing, to be compared in use before one of them becomes the standard.
---A changed file has two, our two-way diff and the diffview's tab. A conflict
---has three: the three-way merge tool and the layout that also shows the base
---version, both the diffview's because navigating conflicts and picking a side
---are already solved there (ADR-0005), and the three versions of it built
---beside the panel, which is the one that does not change tabpage.
local annotation = require "review.annotation"
local config = require "review.config"
local diff = require "review.diff"
local git = require "review.git"
local report = require "review.report"
local root = require "review.root"
local state = require "review.state"
local window = require "review.window"

local M = {}

---@param target ReviewTarget
---@return string absolute path of the file on the line
local function absolute(target) return target.root .. "/" .. target.entry.path end

---The layout swaps standing right now: one for each view of ours that opened
---in a layout that is not the reviewer's, the newest last. What is in the
---diffview's configuration is always the newest one's layout, and the
---reviewer's own goes back when the last of them is dropped.
---
---A stack and not a single one, because the reviewer's layout has to come back
---exactly when the last of our views closes — one close earlier and a view
---still on the screen is rebuilt in the wrong layout on its next refresh,
---which the diffview does on its own every second.
---
---The diffview reads the merge tool layout from one place, so with two of ours
---alive at once only one of them can be in there. The newest wins: it is the
---one the reviewer just asked for.
---
---Which costs the other one nothing, and it is worth knowing why before trying
---to make the value follow the reviewer around (`nvi-01m1h44fpr1h`, closed for
---describing something that does not happen): a view reads the layout once, to
---build the entry of a file, and ours are opened on a single file. The refresh
---reuses the entry it already has, so nothing in there reaches a view that is
---already on the screen.
---@type { layout: string }[]
local swaps = {}

---What was in the configuration before any layout of ours went in — the
---reviewer's. Read once, when a swap goes on an empty stack: reading it again
---for a second swap would pick up a layout of ours and hand it back as theirs.
---@type string|nil
local reviewer_layout = nil

---@return table the diffview's view configuration, which is where it reads the
---merge tool layout from on every refresh
local function diffview_view() return require("diffview.config").get_config().view end

---@return table the diffview's own event bus, which is what its documented
---`view_opened` and `view_closed` hooks are fed from. The events carry the view
---they are about; the `User` autocommands of the same names do not.
local function diffview_events() return _G.DiffviewGlobal.emitter end

---Put in the configuration what the standing swaps ask for: the newest one's
---layout, or the reviewer's when none is left. The only writer of that value,
---so that what the diffview reads is always what the stack says.
local function settle_layout()
  local newest = swaps[#swaps]
  diffview_view().merge_tool.layout = newest and newest.layout or reviewer_layout
end

---Drop a swap that is over — its view closed, or never opened — and leave the
---configuration on what is still standing.
---@param swap { layout: string }
local function drop_swap(swap)
  for i, standing in ipairs(swaps) do
    if standing == swap then
      table.remove(swaps, i)
      break
    end
  end
  settle_layout()
end

---Put a layout in the diffview's configuration for as long as the view it is
---opening lives. The diffview reads the merge tool layout from there, and
---re-reads it on every refresh, so a layout of ours cannot be handed over per
---call: it has to sit in the configuration and come back out.
---
---What takes it out again is the view closing, so the swap only holds if a
---view did open. An open that threw, and one the diffview refused outright —
---a repository it will not read — leave nothing behind to close: a restore
---armed on either would never run, and our layout would be the reviewer's for
---the rest of the session, the one thing the swap must not do. So the arming
---waits for the answer, which is why it is the returned function that does it
---and not this one.
---@param layout string
---@return fun(opened: table|nil) hangs the swap on the view that opened, and
---drops it when none did
local function use_merge_layout(layout)
  if #swaps == 0 then reviewer_layout = diffview_view().merge_tool.layout end
  local swap = { layout = layout }
  swaps[#swaps + 1] = swap
  settle_layout()

  return function(opened)
    if not opened then return drop_swap(swap) end
    -- Every view's close comes through here, and the swap comes out on this
    -- one's: the `DiffviewViewClosed` autocommand names no view at all
    -- (`:h diffview-user-autocmds`), so a restore hung on it is the first
    -- close of the session and not this view's (`nvi-01m1fweftw6s`) — another
    -- tab of the diffview opened beside this one, or one closed with
    -- `:tabclose` before this conflict was even asked for.
    --
    -- Not the view's own emitter, which would seem to be the filter already
    -- written: on top of its own events, every event of the session is put on
    -- the emitter of whichever view holds the current tabpage when it goes
    -- out. So a view of ours announces the close of the one the reviewer just
    -- closed in another tab as if it were its own.
    diffview_events():on("view_closed", function(_, closed)
      if closed ~= opened then return end
      drop_swap(swap)
      -- Done: the emitter drops a listener that answers true.
      return true
    end)
  end
end

---Open the diffview and say which view came out of it.
---
---What says so is the diffview's own event, the counterpart of the one the
---swap is hung on. Nothing else answers it — `diffview.open` returns nothing,
---and a repository it refuses is a message on the reviewer's screen and a
---silent return to us.
---
---Read from the bus and not from the `DiffviewViewOpened` autocommand for the
---reason the close is: the autocommand is the same event with the view left
---out, and which view opened is the whole question — it is what the swap is
---hung on, so that the layout comes back when *this* view closes
---(`nvi-01m1fweftw6s`).
---
---An open that throws is caught, so that the layout can be put back before the
---error goes on its way. It is re-raised as it came: what the reviewer sees of
---a diffview that broke is the diffview's own message.
---@param open fun(args: string[])
---@param args string[]
---@return table|nil opened the view that opened, nil when none did
---@return string|nil failure the error the open threw, to be re-raised once the
---layout is back
local function open_view(open, args)
  local opened = nil
  local function watch(_, view) opened = view end

  diffview_events():on("view_opened", watch)
  local ok, err = pcall(open, args)
  diffview_events():off(watch, "view_opened")

  if ok then return opened, nil end
  return opened, err or "review: o diffview não abriu."
end

---Ask the diffview for a view of one file.
---@param target ReviewTarget
---@param merge_layout string|nil layout to open a conflict in
local function diffview(target, merge_layout)
  local ok, diffview_module = pcall(require, "diffview")
  if not ok then
    vim.notify("review: o diffview não está disponível.", vim.log.levels.WARN)
    return
  end

  local args = { "--", absolute(target) }
  -- Staged compares the HEAD with the index; everything else the index with
  -- the working tree, which is what the diffview does without a rev.
  if target.entry.section == "staged" then table.insert(args, 1, "--cached") end
  -- A commit is its own two sides: `<rev>^!` is what git calls the commit
  -- against its parent, and it is the range the diffview takes. It is also the
  -- one notation that works on the first commit of the repository, which has no
  -- parent for a `^` to resolve.
  --
  -- A range of commits is not one commit against its parent, and asking for the
  -- newest end alone would put a single commit in this tab while the list
  -- beside it — and the key next to this one — show the whole range. The two
  -- revs the entry was read between are what that range is, and the entry of a
  -- single commit is the one whose base is its own parent.
  if target.entry.rev then
    local revs = target.entry.base == target.entry.rev .. "^" and ("%s^!"):format(target.entry.rev)
      or ("%s..%s"):format(target.entry.base, target.entry.rev)
    args = { revs, "--", absolute(target) }
  end

  local finish = merge_layout and use_merge_layout(merge_layout)
  local opened, failure = open_view(diffview_module.open, args)
  if finish then finish(opened) end
  if failure then error(failure, 0) end
end

---Open what the line represents, the default way: the two-way diff beside the
---panel, or the merge tool when the file is conflicted.
---@param target ReviewTarget
function M.open(target)
  if target.entry.section == "conflicts" then return diffview(target, config.options.merge_layouts.conflict) end
  diff.open(target)
end

---Show what the line represents beside the panel without taking the reviewer
---out of the list: the diff the preview draws while the cursor walks it.
---
---A conflict shows the three versions built beside the panel, and not the merge
---tool the same line opens with `<CR>`: the merge tool is a tabpage of the
---diffview's, and a preview that changed tabpage every time the sweep passed a
---conflict would not be a sweep at all. It is the presentation a conflict has
---for exactly this — the one that keeps the list on screen (ADR-0006).
---@param target ReviewTarget
function M.preview(target)
  if target.entry.section == "conflicts" then return diff.open_conflict(target, { focus = false }) end
  diff.open(target, { focus = false })
end

---Open the same thing in its alternative presentation: the diffview's own tab,
---or, for a conflict, the layout that includes the base version.
---@param target ReviewTarget
function M.open_alternate(target)
  if target.entry.section == "conflicts" then
    return diffview(target, config.options.merge_layouts.conflict_with_base)
  end
  diffview(target, nil)
end

---Open the conflict on the line as the three versions git is holding of it in
---the index — ours, the base and the one coming in — beside the panel.
---
---The third presentation a conflict has (ADR-0006), and the only one that does
---not take the reviewer to a tabpage of the diffview: the list stays visible
---next to the three. It shows them and nothing else — picking a side is still
---the merge tool's (ADR-0005).
---
---Only a conflict has three versions, so on any other line the key says so
---instead of building something: the two-way diff of that line is a key away,
---and silence would read as a key that did not work.
---@param target ReviewTarget
function M.open_conflict(target)
  if target.entry.section ~= "conflicts" then
    vim.notify("review: só um arquivo conflitado tem três versões para comparar.", vim.log.levels.WARN)
    return
  end
  diff.open_conflict(target)
end

---Mark what the line puts under review as seen, or unmark it when it already
---is. The mark is on the content, not on the file (ADR-0002), so the same file
---listed as two changes is two different marks.
---@param target ReviewTarget
function M.toggle_seen(target)
  local content = target.entry.content
  if not content then
    vim.notify("review: não foi possível identificar o conteúdo deste arquivo.", vim.log.levels.WARN)
    return
  end
  state.toggle(target.root, content, target.entry.path)
end

---Write the annotation of the file on the line: of the file itself, without a
---line, because a line of the panel is a file and the remark written from
---there is about all of it. A file that already has one is edited.
---@param target ReviewTarget
---@param opts { long: boolean|nil }|nil `long` opens the entry of several lines
---@param done fun() redraws the panel — the count on the line is what tells the
---reviewer the annotation took; called after the reviewer answers, which with a
---picker in front of `vim.ui.input` arrives long after this returns
function M.annotate_file(target, opts, done)
  annotation.write(annotation.point_of_file(target.root, target.entry.path, target.mode), opts, done)
end

---Write the annotation of the line the cursor is on, in whatever file the
---reviewer is reading. This is the one key of the review that does not come
---from a line of the panel: a remark about a line is written where the line is.
---
---In the file itself, and not in a side of a diff that is a rev — the two
---sides of a staged diff are both revs, and the line numbers there are the
---index's, not the file's. Annotating a line of a rev is out of the scope of
---the epic; what the reviewer does instead is open the file, which is a key of
---the panel away.
---@param mode ReviewMode the review being made, which is the panel's
---@param opts { long: boolean|nil }|nil `long` opens the entry of several lines
---@param done fun() redraws the panels, whose counts the annotation changes
function M.annotate_line(mode, opts, done)
  local point = annotation.point_under_cursor(mode)
  if not point then
    vim.notify("review: só dá para anotar uma linha do arquivo em si; abra-o pelo painel.", vim.log.levels.WARN)
    return
  end
  annotation.write(point, opts, done)
end

---Put something where the reviewer can paste it: in the system clipboard,
---which is where copying points — a PR, a ticket, a message — and in the
---unnamed register, so it is also there for a `p` in the editor, clipboard
---provider or not.
---@param value string|string[] a list goes in line by line
local function to_clipboard(value)
  local regtype = type(value) == "table" and "l" or "v"
  vim.fn.setreg("+", value, regtype)
  vim.fn.setreg('"', value, regtype)
end

---Generate the review report, put it in the clipboard, and fill the quickfix
---with the same points.
---
---This one is not about a line of the panel: it is about the review as a
---whole, which is why it takes the repository and not a target. Without a
---panel to say which one that is — the key is the panel's, but the public
---function is not — it is the repository of the current directory, the same
---one the panel would open on.
---
---The document is made to leave the editor, and the clipboard is the shortest
---way out of it: the reviewer presses the key and pastes. The file stays,
---because it is what is left when the clipboard has moved on. Where it was
---written is said out loud: it is outside the repository (ADR-0004), so the
---path is the only way the reviewer knows where to find it.
---@param repository string|nil absolute path of the repository root
---@param mode ReviewMode the review to report, which is the panel's
---@param format ReviewReportFormat
function M.report(repository, mode, format)
  repository = repository or git.root(vim.fn.getcwd())
  if not repository then
    vim.notify("review: fora de um repositório git.", vim.log.levels.WARN)
    return
  end

  local path, count, document = report.generate(repository, mode, format)
  -- Nothing is copied from an empty review: what the reviewer had in the
  -- clipboard is worth more than a report that says nothing.
  if not document then
    vim.notify "review: nenhuma anotação nesta revisão para relatar."
    return
  end

  -- Copied even when the file could not be written, which the generation has
  -- already warned about: the document was built all the same, and pasting it
  -- is what it is for.
  to_clipboard(document)
  local copied = ("review: relatório com %d %s copiado"):format(count, count == 1 and "anotação" or "anotações")
  vim.notify(path and ("%s; gravado em %s"):format(copied, path) or copied)
end

---Say it when git refused. Everything here changes the repository, and a
---command that did nothing has to be visible: the panel redraws either way,
---and a list that came back unchanged looks exactly like a key that was never
---pressed.
---@param ok boolean
---@param detail string|nil git's own error message
local function report_refusal(ok, detail)
  if ok then return end
  vim.notify("review: " .. (detail and detail ~= "" and detail or "o git recusou a operação."), vim.log.levels.WARN)
end

---Say no to what a commit cannot do.
---
---What is committed is history: staging it, taking it out of the index or
---throwing it away are all about the working tree, and what is on disk today
---is not what the line is showing. Acting anyway would change a file the
---reviewer is not looking at, so the key says so — and says where the keys
---that do work are.
---@param target ReviewTarget
---@param what string what the key would have done, named in the message
---@return boolean refused
local function refuse_on_a_commit(target, what)
  if target.entry.section ~= "commit" then return false end
  vim.notify(
    ("review: não dá para %s no modo commit; volte ao working tree com %s."):format(
      what,
      config.options.mappings.worktree
    ),
    vim.log.levels.WARN
  )
  return true
end

---Move the change on the line into the index. On an untracked file that is the
---file itself; on a deleted one, its deletion; on a conflicted one, the
---resolution the reviewer left on disk — which is the one thing the panel
---knows how to do with a conflict (ADR-0007).
---@param target ReviewTarget
function M.stage(target)
  if refuse_on_a_commit(target, "mover para staged") then return end
  report_refusal(git.stage(target.root, target.entry))
end

---Take the change on the line out of the index.
---@param target ReviewTarget
function M.unstage(target)
  if refuse_on_a_commit(target, "tirar de staged") then return end
  -- Resetting a conflicted path would drop the sides git is holding in the
  -- index and leave the file looking merged, with the markers still in it.
  -- Undoing a merge is the merge tool's, not a key of the list (ADR-0007).
  if target.entry.section == "conflicts" then
    vim.notify("review: um conflito não sai do índice daqui; resolva-o no merge tool.", vim.log.levels.WARN)
    return
  end
  report_refusal(git.unstage(target.root, target.entry))
end

---What the panel asks before throwing a change away. Each section gets its own
---question, naming the file and saying exactly what goes: this is the one key
---that loses work, and the answer is given once.
---@param entry ReviewEntry
---@return string|nil nil when the line is not something to discard
local function question(entry)
  if entry.section == "untracked" then
    return ("Apagar %s? O arquivo não está no git, não dá para recuperar."):format(entry.path)
  elseif entry.section == "unstaged" then
    return ("Descartar as mudanças não staged de %s?"):format(entry.path)
  elseif entry.section == "staged" then
    return ("Descartar as mudanças de %s, staged e no disco?"):format(entry.path)
  end
end

---Throw the change on the line away, after asking. The question goes through
---the editor's own selection UI, so it is asked wherever the reviewer already
---reads questions, and so that it can be answered without the editor sitting
---blocked on it.
---@param target ReviewTarget
---@param done fun() redraws the panel; called after the answer, which with a
---picker in front of `vim.ui.select` arrives long after this function returns
function M.discard(target, done)
  if refuse_on_a_commit(target, "descartar") then return end
  -- The only line without a question is a conflict: discarding one would be
  -- picking a side without saying which (ADR-0007).
  local asking = question(target.entry)
  if not asking then
    vim.notify("review: um conflito não se descarta daqui; resolva-o no merge tool.", vim.log.levels.WARN)
    return
  end

  vim.ui.select({ "Sim", "Não" }, { prompt = asking }, function(choice)
    if choice ~= "Sim" then return end
    report_refusal(git.discard(target.root, target.entry))
    done()
  end)
end

---@param win integer winid to open the file in
---@param path string
local function edit(win, path)
  vim.api.nvim_set_current_win(win)
  -- The window may be coming back from a diff of another file.
  vim.cmd "diffoff"
  vim.cmd.edit(vim.fn.fnameescape(path))
end

---Open the file itself, in the window beside the panel. The diff goes: the
---reviewer asked for the file, not for half of a comparison next to it.
---@param target ReviewTarget
function M.open_file(target)
  diff.close()
  local path = absolute(target)
  edit(window.content(target.panel, vim.fn.bufadd(path)), path)
end

---The line of `bufnr` that reads like `text`, looked for from `lnum` outwards:
---the same line when the file has not moved under the reviewer, and the nearest
---line that says the same thing when it has.
---
---By the text and not by the number, which is the reancoragem the annotations
---already do (ADR-0003): the line being read comes from a version of the file —
---the index, a commit — and the number it has there means nothing on disk once
---anything above it has changed. Outwards from the number because a file
---repeats lines, and of two lines that read the same the one nearer where the
---reviewer was is the one they were reading.
---
---Blank lines and lines of punctuation alone anchor nothing: half a file reads
---like `end`, and the nearest one is not the one being read. There the number
---is all there is.
---@param bufnr integer
---@param text string the line as it is in the diff
---@param lnum integer where it was in the diff
---@return integer|nil lnum nil when the text is not in the file
function M.line_that_reads_like(bufnr, text, lnum)
  local wanted = vim.trim(text)
  if wanted == "" or #wanted < 3 then return nil end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local last = #lines
  for distance = 0, last do
    for _, candidate in ipairs { lnum - distance, lnum + distance } do
      if candidate >= 1 and candidate <= last and vim.trim(lines[candidate]) == wanted then return candidate end
    end
  end
end

---Open the file on disk at the point being read, from inside the diff: the
---reviewer read down to a line and wants the file itself there — to edit it, to
---jump from it, to use everything the editor has on a real file, which two
---read-only sides do not have.
---
---What is opened is always the file on disk. In the working tree one of the
---sides already is it, and this is that side without the comparison over it; in
---a commit neither side is — both are history — and the file is where the
---reviewer would go to act on what they just read.
---
---The point comes from the text of the line, not from its number: the two only
---agree when nothing above has changed, which is exactly what a diff says is
---not the case. When the text is nowhere in the file — a line deleted in the
---commit being read, a file that moved on since — the number is what is left,
---and the key says so instead of pretending it landed.
---@param target ReviewTarget
---@param at { lnum: integer, text: string } where the reviewer is in the diff
function M.open_file_at(target, at)
  local path = absolute(target)
  if vim.fn.filereadable(path) == 0 then
    vim.notify(("review: %s não está no disco."):format(target.entry.path), vim.log.levels.WARN)
    return
  end

  diff.close()
  local bufnr = vim.fn.bufadd(path)
  local win = window.content(target.panel, bufnr)
  edit(win, path)

  local found = M.line_that_reads_like(bufnr, at.text, at.lnum)
  local lnum = math.min(found or at.lnum, vim.api.nvim_buf_line_count(bufnr))
  vim.api.nvim_win_set_cursor(win, { math.max(lnum, 1), 0 })
  -- Centred, because the reviewer arrives reading: the line they came for with
  -- what surrounds it, and not stuck to the top or the bottom of the window.
  vim.api.nvim_win_call(win, function() vim.cmd "normal! zz" end)

  -- The diff is one step behind the file from here on, on the key the reviewer
  -- already walks back with.
  diff.returns_to { bufnr = bufnr, lnum = lnum, text = at.text, target = target }

  if not found then
    vim.notify(("review: esta linha não está no arquivo; %s:%d é onde ela estava."):format(target.entry.path, lnum))
  end
end

---Put a path where the reviewer can paste it. The notification shows what went
---there: the two keys differ only in the path they copy, and reading it back is
---the only way to tell the key that was pressed from the one that was meant.
---@param path string
local function copy(path)
  to_clipboard(path)
  vim.notify("review: copiado " .. path)
end

---Copy the absolute path of the file on the line.
---@param target ReviewTarget
function M.copy_absolute_path(target) copy(absolute(target)) end

---Copy the path of the file on the line written from the root of its project —
---the root of the module it belongs to, which in a monorepo is not the root of
---the repository. The repository root is what is left when there is no
---detector to ask at all, which is also the right answer wherever the
---repository holds a single module.
---@param target ReviewTarget
function M.copy_relative_path(target)
  local path = absolute(target)
  local from = root.project(path) or target.root
  -- A path the root turns out not to contain is copied whole: half a path is
  -- worse than a long one.
  copy(root.relative_to(from, path) or path)
end

---How far back the search reads the history of the file. A rev that is not in
---the five hundred most recent commits of one file is not one anybody finds by
---scrolling, and the bound is what keeps a file with a very long history from
---freezing the editor while git walks it — the same reason the graph is bounded.
local REVS = 500

---Choose the rev in the editor's own selection UI — a search, wherever the
---reviewer has a picker in front of it — and do `run` with what came back.
---
---What it offers is the branches of the repository and the commits of this
---file, so that no sha is ever typed. The label is what the reviewer picks, and
---the rev behind it is what git is given: a commit is offered by its short sha,
---its date and its subject, none of which git would resolve.
---@param target ReviewTarget
---@param prompt string
---@param run fun(rev: string, label: string)
local function choose_rev(target, prompt, run)
  local choices = git.revs_of(target.root, target.entry, REVS)
  if not choices then
    vim.notify("review: não foi possível ler os revs do git.", vim.log.levels.WARN)
    return
  end
  if #choices == 0 then
    vim.notify("review: não há branch nem commit para escolher.", vim.log.levels.WARN)
    return
  end

  local labels, rev_by_label = {}, {}
  for _, choice in ipairs(choices) do
    -- Two commits can read exactly alike on one line — the same subject on the
    -- same day, amended — and the newest of them is the one on offer.
    if not rev_by_label[choice.label] then
      labels[#labels + 1] = choice.label
      rev_by_label[choice.label] = choice.rev
    end
  end

  vim.ui.select(labels, { prompt = prompt }, function(label)
    if not label then return end
    run(rev_by_label[label], label)
  end)
end

---Show the file on the line as it is in another rev, chosen in the search:
---read only, named after the rev, in the window beside the panel.
---
---The way back is said out loud, because it is the whole point of the gesture:
---a consultation that costs the reviewer their navigation is one they stop
---making. It is written in the winbar of the view as well, and stays here for
---what does not fit there: the rev as the search offered it, with the date and
---the subject of the commit, where the winbar has room for the short rev alone.
---@param target ReviewTarget
function M.open_rev(target)
  choose_rev(target, ("Ver %s em outro rev"):format(target.entry.path), function(rev, label)
    if not diff.open_rev(target, rev) then
      vim.notify(("review: %s não existe em %s."):format(target.entry.path, label), vim.log.levels.WARN)
      return
    end
    vim.notify(("review: %s em %s · %s volta"):format(target.entry.path, label, config.options.mappings.close))
  end)
end

---Compare the file on the line with the version of it in another rev, chosen in
---the same search. What is compared is the file as it is on disk: the reviewer
---asked what changed between the two, and one of the two is what they have.
---@param target ReviewTarget
function M.diff_rev(target)
  choose_rev(
    target,
    ("Comparar %s com outro rev"):format(target.entry.path),
    function(rev) diff.open_against(target, rev) end
  )
end

---Open the file itself in a split, keeping what was already in the window
---beside the panel.
---@param target ReviewTarget
function M.open_file_in_split(target)
  diff.close()
  local path = absolute(target)
  local bufnr = vim.fn.bufadd(path)
  edit(window.below(window.content(target.panel, bufnr), bufnr), path)
end

return M
