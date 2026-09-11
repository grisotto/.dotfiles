---The two-way diff the panel builds in its own tabpage.
---
---What is compared comes from the section of the line: on a staged line, the
---HEAD against the index; on an unstaged or untracked line, the index against
---the working tree; on a line of a commit, that commit against its first
---parent. The working tree side is the file itself, not a copy of it, so the
---reviewer can fix what they are reading right there — a commit has no such
---side, because both of its versions are history.
---
---A conflicted file has no content at stage zero of the index, so no two-way
---diff of it means anything. What it has is the three sides git is holding in
---the other stages, and those go side by side here, in the third of the
---presentations a conflict has (ADR-0006). Picking a side and walking from one
---conflict to the next are still the diffview's (ADR-0005): what is built here
---only shows the three versions.
---
---The file read in a rev the reviewer chose is built here too, on the same
---buffers and in the same window: one side alone, which is a consultation and
---not a comparison, and comparing it with the file on disk, which is two sides
---like any other diff. It is the one place where what goes beside the panel is
---not the change on the line — and the reason both live here is that they take
---the same space, so leaving one has to take the other down.
local config = require "review.config"
local git = require "review.git"
local window = require "review.window"

local M = {}

---@class ReviewDiffSide
---@field label string what the side is called in the buffer name
---@field rev string|nil rev to read the content from; nil is the file on disk
---@field path string path relative to the repository root
---@field lines string[]|nil the content, when it was already read

---@class ReviewDiffKey an action of the diff, written in the winbar beside what
---it does and mapped in every one of its buffers
---@field key string
---@field label string what it does, in the reviewer's words, as the winbar has room for it
---@field desc string|nil the whole of it, for the mapping; the label when absent
---@field run fun()|nil nil on a key of the editor that the diff only names: it is
---listed in the help and mapped by whoever it belongs to
---@field written boolean|nil whether the winbar writes it; every key is listed in
---the help either way

---@class ReviewDiffMount what one diff put on the screen, and everything that
---has to be given back when it leaves
---@field wins integer[] winids, left to right
---@field bufs integer[] the buffer of each side, left to right
---@field entry ReviewEntry|nil the line of the list this diff is of, when it is
---one of the presentations of a line under review; nil for a consultation of a
---rev, which is not a line of the list being shown
---@field winbar table<integer, string> the winbar each window had before, by winid
---@field bars table<integer, string> the winbar the diff wrote in each window, by
---winid — what it writes back when something else writes over it
---@field keys ReviewDiffKey[] the keys mapped in every buffer of the diff
---@field mappings table[] the buffer local mappings the keys of the diff wrote
---over, as `mapset` takes them back

---The diff this module mounted in each tabpage, so opening another one there
---can take it down. Per tabpage, like the panel: the diff of one tabpage is not
---the diff the reviewer is reading in another.
---@type table<integer, ReviewDiffMount>
local mounted_by_tab = {}

---What the read-only view of each tabpage gives back when it is left: the file
---the reviewer had beside the panel when the consultation started.
---
---Kept here rather than in the closure of one view because a consultation is
---often more than one: the second rev opens over the first, and by then the
---file is not on screen for the window to be asked about it. It goes when
---anything else takes that space, which is what `M.close` is.
---@type table<integer, integer>
local back_to_by_tab = {}

---Which end of the file the diff of each tabpage was left standing at: 1 for
---the last change of it, -1 for the first, and nothing at all while the
---reviewer is somewhere in the middle.
---
---It is what makes leaving the file two presses instead of one. Walking the
---changes and walking the files are two sizes of the same movement, and the
---smaller one running into the larger without saying so would take the file
---being read off the screen on a key that had been staying inside it. The end
---says it is the end; the press after that goes on.
---
---Only a press that did not move arms it, and any press that moved takes it
---back down, so the two presses are always in a row and at the same end. It
---goes with the diff, like everything else here: the file that was at its last
---change is not the one mounted in its place.
---@type table<integer, integer>
local at_edge_by_tab = {}

---How a rev is written on the side it is showing: short enough to leave room
---for the path beside it, which is the other half of the name.
---@param rev string
---@return string
local function short(rev)
  -- Only a whole object name is abbreviated, and how long that is depends on
  -- the repository's hash: forty on SHA-1, sixty-four on SHA-256. A rev the
  -- reviewer would recognise — a branch, something already short — is left as
  -- it is.
  return (rev:gsub("^(%x+)", function(sha) return #sha >= 40 and sha:sub(1, 7) or sha end))
end

---@param entry ReviewEntry
---@return ReviewDiffSide left
---@return ReviewDiffSide right
local function two_way_sides(entry)
  -- A commit is read against what it changed, which is the pair of revs the
  -- entry came with. Neither side is the file on disk: the working tree has
  -- moved on since, and what is being reviewed is the commit.
  if entry.rev then
    return { label = short(entry.base), rev = entry.base, path = entry.orig_path or entry.path }, {
      label = short(entry.rev),
      rev = entry.rev,
      path = entry.path,
    }
  end

  local index = { label = "índice", rev = ":0", path = entry.path }
  if entry.section == "staged" then
    -- A renamed file has its old content under the old path in HEAD.
    return { label = "HEAD", rev = "HEAD", path = entry.orig_path or entry.path }, index
  end
  -- Unstaged and untracked read the same way: what the index has of the file —
  -- nothing at all, for an untracked one — against what is on disk.
  return index, { label = "working tree", rev = nil, path = entry.path }
end

---The name of a side that came from git: the file where it lives, with the rev
---written after it.
---
---A name of the editor is a path to whoever reads it, and something does:
---the file tree reveals the current buffer on every toggle, taking the name
---for a path without asking what kind of buffer it is. A name of its own
---making — `review://<rev>/<caminho>`, which is what this was — is a path that
---leads nowhere, and the tree goes looking for the directory `review:` and
---fails out loud on the way. Under the root, it is a path that leads to the
---repository being reviewed, which is where the tree was going anyway; the
---node it then does not find is a node it quietly does without.
---@param root string
---@param side ReviewDiffSide
---@return string
local function side_name(root, side) return ("%s/%s@%s"):format(root, side.path, side.label) end

---A read-only buffer with the content of one side. Wiped with the window that
---shows it: these buffers are the diff, and they have no life after it.
---@param root string
---@param side ReviewDiffSide
---@return integer bufnr
local function rev_buf(root, side)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].swapfile = false

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, side.lines or git.show(root, side.rev, side.path) or { "" })
  vim.bo[bufnr].modifiable = false

  -- The name is what the reviewer reads to tell the sides apart. The
  -- highlighting is set from the path alone: the rev at the end of the name
  -- would be an extension of its own to whoever guessed from the name.
  pcall(vim.api.nvim_buf_set_name, bufnr, side_name(root, side))
  vim.bo[bufnr].filetype = vim.filetype.match { filename = side.path } or ""

  return bufnr
end

---@param root string
---@param path string
---@return integer bufnr the buffer of the file itself
local function file_buf(root, path)
  local bufnr = vim.fn.bufadd(root .. "/" .. path)
  vim.fn.bufload(bufnr)
  return bufnr
end

---A label as the winbar shows it and not as it reads it: a `%` in a rev or a
---path is the start of an item there.
---@param text string
---@return string
local function literal(text) return (text:gsub("%%", "%%%%")) end

---The winbar of one window of the diff: the side it is showing on the left,
---and, on the window that carries them, the keys it writes aligned to the
---right. The key goes beside what it does, which is how the context menu writes
---the same pair (ADR-0008) — the answer to "how do I close this" in the place
---where the question is asked.
---
---Only the keys marked as written: the way out, and the key that lists every
---other one in the help. A winbar too long for its window loses what is between
---the name of the side and the end, and with every key written what was lost
---was the keys — sometimes all of them, the name of the side left alone on the
---bar.
---@param label string
---@param keys ReviewDiffKey[]|nil
---@return string
local function winbar(label, keys)
  local bar = " " .. literal(label)

  local written = {}
  for _, key in ipairs(keys or {}) do
    if key.written then written[#written + 1] = ("%s  %s"):format(key.label, key.key) end
  end
  if #written == 0 then return bar end
  return bar .. "%=" .. literal(table.concat(written, "    ")) .. " "
end

---The diff a window is one of the sides of, whatever tabpage it was mounted in:
---a window carried elsewhere (`<C-w>T`) is still part of the diff it came from.
---@param win integer winid
---@return integer|nil tab the tabpage the diff was mounted in
---@return ReviewDiffMount|nil
local function mount_of(win)
  for tab, mount in pairs(mounted_by_tab) do
    if vim.tbl_contains(mount.wins, win) then return tab, mount end
  end
end

---The buffer local mapping of `lhs` in `bufnr`, in the form `mapset` takes it
---back: what the reviewer already had on that key, before the diff wrote over
---it.
---@param bufnr integer
---@param lhs string
---@return table|nil
local function mapping_of(bufnr, lhs)
  -- Compared as the editor writes the key and not as the configuration spells
  -- it: `<C-o>` is listed back as `<C-O>`, and held as modifier bytes that are
  -- not what `nvim_replace_termcodes` gives for it. `keytrans` is the editor's
  -- own answer for "what key is this", and it is the same answer for both. A
  -- key not recognised here is a key of ours left on the reviewer's own file
  -- for good, or one of theirs deleted as if it were ours.
  local wanted = vim.fn.keytrans(vim.api.nvim_replace_termcodes(lhs, true, false, true))
  for _, map in ipairs(vim.api.nvim_buf_get_keymap(bufnr, "n")) do
    if map.lhs == lhs or vim.fn.keytrans(map.lhsraw or map.lhs) == wanted then return map end
  end
end

---Give back everything the diff put on windows and buffers that outlive it: the
---winbar each window had before, and the keys of the diff — including whatever
---the reviewer's own configuration had on those keys, which the diff wrote over.
---
---The rev buffers are wiped with their windows and have nothing to give back,
---but the working tree side is the reviewer's own file — it must not be left
---carrying a key of ours once the diff is gone, nor missing one of theirs.
---@param mount ReviewDiffMount
local function unhook(mount)
  for win, previous in pairs(mount.winbar) do
    if vim.api.nvim_win_is_valid(win) then
      pcall(vim.api.nvim_set_option_value, "winbar", previous, { scope = "local", win = win })
    end
  end
  for _, bufnr in ipairs(mount.bufs) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      for _, key in ipairs(mount.keys) do
        -- Only while the key is still ours. Something else can have taken it
        -- back while the diff was up — the editor writes these same keys on
        -- `FileType`, which a `:edit` of the working tree side re-fires — and
        -- deleting that would leave the reviewer's own file without a key that
        -- was never the diff's to take.
        local standing = mapping_of(bufnr, key.key)
        if standing and standing.callback == key.run then pcall(vim.keymap.del, "n", key.key, { buffer = bufnr }) end
      end
    end
  end
  for _, previous in ipairs(mount.mappings) do
    if vim.api.nvim_buf_is_valid(previous.bufnr) then
      pcall(vim.api.nvim_buf_call, previous.bufnr, function() vim.fn.mapset(previous.map) end)
    end
  end
end

---Take the diff mounted in `tab` off the screen. The rev buffers go with their
---windows; the working tree side is the reviewer's own file buffer and stays,
---unsaved edits included.
---@param tab integer tabpage handle
---@param spared integer|nil winid this is not to close: the one the editor is
---already closing, or the one that has gone back to being the reviewer's
local function take_down(tab, spared)
  local mount = mounted_by_tab[tab]
  mounted_by_tab[tab] = nil
  -- What a view of this tabpage was going to give back goes with it: whatever
  -- takes this space now is what a later consultation has to come back to.
  back_to_by_tab[tab] = nil
  at_edge_by_tab[tab] = nil
  if not mount then return end

  unhook(mount)
  for _, win in ipairs(mount.wins) do
    if win ~= spared and vim.api.nvim_win_is_valid(win) then
      -- Closing the last window of a tabpage closes the tabpage with it. The
      -- diff can go without taking the reviewer's tab along.
      if #vim.api.nvim_tabpage_list_wins(vim.api.nvim_win_get_tabpage(win)) > 1 then
        pcall(vim.api.nvim_win_close, win, true)
      else
        vim.api.nvim_win_call(win, function() vim.cmd "diffoff" end)
      end
    end
  end
end

---Take down the diff of this tabpage.
function M.close() take_down(vim.api.nvim_get_current_tabpage()) end

---Take the diff down once the editor is done with the layout, and not in the
---middle of it.
---
---A window leaving is something the editor is doing — `:q`, `:only`,
---`:tabclose`, a buffer being closed — and closing another window from inside
---that aborts the command that started it (`E855`), which can leave the very
---window the reviewer asked to keep gone and one of ours in its place. By the
---next turn of the loop the layout is the editor's own again, and what is left
---of the diff can be taken down without arguing with it.
---
---Only if it is still the same diff: the reviewer can have opened another one
---in that tabpage in between, and that one is not this one to take down.
---@param tab integer tabpage handle
---@param mount ReviewDiffMount the diff as it was when the window left
---@param spared integer|nil winid that has gone back to being the reviewer's
local function defer_take_down(tab, mount, spared)
  vim.schedule(function()
    if mounted_by_tab[tab] ~= mount then return end
    take_down(tab, spared)
    -- The window that kept the buffer keeps the layout too, and only the diff
    -- mode over it has to go.
    if spared and vim.api.nvim_win_is_valid(spared) then
      vim.api.nvim_win_call(spared, function() vim.cmd "diffoff" end)
    end
  end)
end

local GROUP = vim.api.nvim_create_augroup("review-diff", { clear = true })

---There is no half a diff on the screen. A window of it closed by hand —
---`<Leader>x`, `:q` — takes the whole thing with it: the side left behind would
---stay in diff mode with nothing to compare against, colouring a file that is
---being compared with nothing, and the reviewer's own file would keep the key
---that closes a diff that is no longer there. It is what makes closing one of
---these windows harmless instead of forbidden.
vim.api.nvim_create_autocmd("WinClosed", {
  group = GROUP,
  desc = "Derrubar o diff inteiro quando uma das janelas dele fecha",
  callback = function(event)
    local closing = tonumber(event.match)
    if not closing then return end

    local tab, mount = mount_of(closing)
    if tab and mount then defer_take_down(tab, mount) end
  end,
})

---The other way a side leaves: the window stays and shows something else. That
---is what `<Leader>x` does to the working tree side when the reviewer has
---another buffer for the editor to put there — the file goes, the window does
---not. What is in that window is theirs now, so it is the one window the diff
---does not take with it: it is left with the buffer it was given, out of diff
---mode and without our winbar over it.
vim.api.nvim_create_autocmd("BufWinEnter", {
  group = GROUP,
  desc = "Derrubar o diff quando uma das janelas dele passa a mostrar outro buffer",
  callback = function()
    -- Asked of the windows themselves, and not of the buffer the event carries:
    -- a buffer can be put in a window that is not the one the editor is sitting
    -- in. A side still showing its own buffer — a `:edit` of the file being
    -- reviewed — is the side still being the side.
    for tab, mount in pairs(mounted_by_tab) do
      for _, win in ipairs(mount.wins) do
        if vim.api.nvim_win_is_valid(win) and not vim.tbl_contains(mount.bufs, vim.api.nvim_win_get_buf(win)) then
          defer_take_down(tab, mount, win)
          break
        end
      end
    end
  end,
})

---The winbar of a side is the diff's while the diff is up, and the statusline
---plugin of the configuration writes over it: heirline, under AstroNvim, writes
---its own winbar on every `BufWinEnter` and `FileType` of a file buffer, and the
---working tree side is one — the reviewer's own file. A `:edit`, a jump back
---into it, a plugin setting its filetype again, and the bar lost the keys of the
---diff with nothing on screen saying why.
---
---Written back on the same two events, on the turn of the loop after them. Not
---on `OptionSet`: the other plugin writes from an autocommand of its own, and
---autocommands do not nest, so that event never comes. And not right away,
---because in whichever order the two autocommands run, the one that runs later
---has to be ours. Only while the diff is still up — taking it down forgets the
---mount before giving the windows their winbar back — and only in a window
---still showing a side of it: one given another buffer is being let go.
vim.api.nvim_create_autocmd({ "BufWinEnter", "FileType" }, {
  group = GROUP,
  desc = "Devolver a winbar do diff às janelas dele quando outro plugin a troca",
  callback = function()
    vim.schedule(function()
      for _, mount in pairs(mounted_by_tab) do
        for win, ours in pairs(mount.bars) do
          if
            vim.api.nvim_win_is_valid(win)
            and vim.tbl_contains(mount.bufs, vim.api.nvim_win_get_buf(win))
            and vim.wo[win].winbar ~= ours
          then
            vim.wo[win].winbar = ours
          end
        end
      end
    end)
  end,
})

---How the key that brings the diff back is known to be ours when it is time to
---give it back: it is written on the reviewer's own file, where the editor and
---their configuration write too.
local RETURN_DESC = "Voltar ao diff que este arquivo foi aberto de"

---@class ReviewReturn the diff a file was opened from, and the way back to it
---@field bufnr integer the file the reviewer was left in
---@field lnum integer the line they were left on
---@field text string what that line read, so the diff comes back to the same
---place: the number of a line in a rev means nothing in the file, and the other
---way round
---@field target ReviewTarget the line of the list the diff was of
---@field previous table|nil what that buffer had on the key, as `mapset` takes it back

---What each tabpage comes back to, while a file opened from a diff has the
---screen. One per tabpage, like the diff itself.
---@type table<integer, ReviewReturn>
local return_by_tab = {}

---Give the buffer its key back and forget the way back.
---
---The mapping is on the reviewer's own file, so it comes off exactly as the
---keys of the diff do: only while it is still ours, and putting back whatever
---was under it.
---@param tab integer tabpage handle
local function forget_return(tab)
  local pending = return_by_tab[tab]
  return_by_tab[tab] = nil
  if not pending or not vim.api.nvim_buf_is_valid(pending.bufnr) then return end

  local key = config.options.mappings.back_to_diff
  local standing = mapping_of(pending.bufnr, key)
  if standing and standing.desc == RETURN_DESC then pcall(vim.keymap.del, "n", key, { buffer = pending.bufnr }) end
  if pending.previous then
    pcall(vim.api.nvim_buf_call, pending.bufnr, function() vim.fn.mapset(pending.previous) end)
  end
end

---Put the diff back on the screen, at the line the reviewer left it at.
---@param tab integer tabpage handle
---@param pending ReviewReturn
local function come_back(tab, pending)
  forget_return(tab)

  -- The panel is asked for now instead of remembered: it can have been closed,
  -- or opened, while the file had the screen.
  M.open {
    entry = pending.target.entry,
    root = pending.target.root,
    mode = pending.target.mode,
    panel = require("review.panel").win(),
  }

  local at = require("review.actions").line_that_reads_like(vim.api.nvim_get_current_buf(), pending.text, pending.lnum)
  if not at then return end
  vim.api.nvim_win_set_cursor(0, { at, 0 })
  vim.cmd "normal! zz"
end

---The file opened from the diff comes back to it on the key the reviewer
---already walks back with, with the diff one step behind the file.
---
---Not a key of its own, because coming back is not a new gesture: the reviewer
---goes into the file from the line they were reading, walks from there to a
---definition and to other files, and comes back the way they came. The jump
---list is that way, and the diff sits just under the bottom of it.
---
---While the walking is inside the file the key stays the editor's, doing what
---it always did: what the diff takes is the one jump that would leave the file,
---which is the jump that would go past what the reviewer was reading.
---`getjumplist` says where that jump would land without taking it.
---@param pending ReviewReturn
function M.returns_to(pending)
  local tab = vim.api.nvim_get_current_tabpage()
  forget_return(tab)

  local key = config.options.mappings.back_to_diff
  pending.previous = mapping_of(pending.bufnr, key)
  return_by_tab[tab] = pending

  vim.keymap.set("n", key, function()
    local standing = return_by_tab[tab]
    local list, index = unpack(vim.fn.getjumplist())
    -- `index` is where the jump list stands, and the entry under it is where
    -- this key would land.
    local older = index > 0 and list[index] or nil
    if standing and (not older or older.bufnr ~= vim.api.nvim_get_current_buf()) then
      return come_back(tab, standing)
    end
    vim.cmd("normal! " .. vim.api.nvim_replace_termcodes(key, true, false, true))
  end, { buffer = pending.bufnr, nowait = true, desc = RETURN_DESC })
end

---Put these sides side by side beside the panel, replacing whatever diff was
---there.
---
---Each window says in its winbar which side it is showing, and the one furthest
---to the right — where the eye ends up — also says which keys the diff answers
---to. Those keys are mapped in every side, so they work wherever the reviewer
---is, and they are buffer local: one of the sides can be the reviewer's own
---file, and what is put on it there has to come off again when the diff goes.
---@param target ReviewTarget
---@param sides ReviewDiffSide[] left to right
---@param focused_side integer|nil index into `sides` of the one the reviewer is
---left in; nil leaves the cursor where it is, which is what the preview needs
---@param keys ReviewDiffKey[] what the diff answers to while it is on screen
---@param entry ReviewEntry|nil the line this diff is of, for whoever asks later
---what is beside the panel; nil for a consultation, which is not the change on
---a line
---@return integer[] opened winids, left to right
local function build(target, sides, focused_side, keys, entry)
  -- The diff that was there goes first, and only then are the new sides built:
  -- a side is told from the others by the name of its buffer, a name is unique
  -- in the editor, and the side of the previous diff still holding it would
  -- leave this one unnamed — silently, since naming a buffer is allowed to
  -- fail. Opening the same conflict twice is exactly that case.
  M.close()

  local bufs = {}
  for index, side in ipairs(sides) do
    bufs[index] = side.rev and rev_buf(target.root, side) or file_buf(target.root, side.path)
  end

  local opened = { window.content(target.panel, bufs[1]) }
  vim.api.nvim_win_set_buf(opened[1], bufs[1])
  for index = 2, #bufs do
    opened[index] = window.beside(opened[index - 1], bufs[index])
  end

  -- A tabpage that is gone took its diff with it; what is left here is only
  -- the diffs of tabpages still on screen.
  for tab in pairs(mounted_by_tab) do
    if not vim.api.nvim_tabpage_is_valid(tab) then mounted_by_tab[tab] = nil end
  end

  -- Only the keys the diff runs are mapped here, and only those are taken off
  -- when it goes. A key it only names belongs to whoever mapped it, and one
  -- with no function of ours would look, when the diff is taken down, exactly
  -- like any mapping of the reviewer's that has no function either.
  local mapped = vim.tbl_filter(function(key) return key.run ~= nil end, keys)

  ---@type ReviewDiffMount
  local mount = { wins = opened, bufs = bufs, winbar = {}, bars = {}, keys = mapped, mappings = {}, entry = entry }
  local tab = vim.api.nvim_get_current_tabpage()
  -- A diff on the screen is the diff to come back to, so whatever way back a
  -- file of this tabpage was holding is over — including the one this very
  -- build is answering.
  forget_return(tab)
  mounted_by_tab[tab] = mount

  for index, win in ipairs(opened) do
    mount.winbar[win] = vim.api.nvim_get_option_value("winbar", { scope = "local", win = win })
    mount.bars[win] = winbar(sides[index].label, index == #opened and keys or nil)
    vim.wo[win].winbar = mount.bars[win]
  end
  for _, bufnr in ipairs(bufs) do
    -- Everything the keys are about to write over is read before any of them is
    -- written: two keys of the diff configured to the same lhs would otherwise
    -- have the second one read the first one's mapping and hand a mapping of
    -- ours back to the reviewer's file as if it were theirs.
    for _, key in ipairs(mapped) do
      local previous = mapping_of(bufnr, key.key)
      if previous then mount.mappings[#mount.mappings + 1] = { bufnr = bufnr, map = previous } end
    end
    for _, key in ipairs(mapped) do
      vim.keymap.set("n", key.key, key.run, { buffer = bufnr, nowait = true, desc = key.desc or key.label })
    end
  end

  -- One side alone is not a comparison, and putting it in diff mode would fold
  -- the whole file away: nothing differs from nothing.
  if #opened > 1 then
    for _, win in ipairs(opened) do
      vim.api.nvim_win_call(win, function() vim.cmd "diffthis" end)
    end
  end
  -- Every window here was opened without entering it, so a diff that does not
  -- take the focus is this one line left undone: the reviewer stays wherever
  -- they were, which for the preview is the line of the list they are on.
  if focused_side then vim.api.nvim_set_current_win(opened[focused_side]) end

  return opened
end

---The key that takes the diff off the screen, from any of its sides, and leaves
---the reviewer in the panel — which is where the next file comes from. It is the
---key that closes the panel and the graph, doing here what it does there.
---
---The diff is looked up by the window the key was pressed in, and not by the
---tabpage: a side carried elsewhere (`<C-w>T`) still closes the diff it is part
---of.
---@param panel integer|nil winid to go back to; nil when the list is not on
---screen, and then closing the diff is all the key does
---@return ReviewDiffKey
local function closing_key(panel)
  return {
    key = config.options.mappings.close,
    label = "fechar",
    written = true,
    desc = "Fechar o diff e voltar ao painel",
    run = function()
      -- The mapping is buffer local and the working tree side is the reviewer's
      -- own file: the same key is on that buffer wherever else it is open, in
      -- this tabpage or another. Only the window that is a side of this diff
      -- closes it — anywhere else the key has no diff to close, and moving the
      -- reviewer to a panel they are not looking at is worse than doing nothing.
      local tab = mount_of(vim.api.nvim_get_current_win())
      if not tab then return end

      take_down(tab)
      if panel and vim.api.nvim_win_is_valid(panel) then vim.api.nvim_set_current_win(panel) end
    end,
  }
end

---The keys that walk the list from inside the diff: the file before this one
---and the file after it, opened without going back to the panel.
---
---The plain pair walks what is left to read and the shifted one walks
---everything, which is how a file already seen is gone back to. What they move
---is the cursor of the panel, which is the position of the review (ADR-0009):
---the list follows the reviewer instead of being returned to.
---
---The panel is asked for when the key is pressed and not required up here: the
---panel is built on top of this module, and this is the one direction in which
---the two know about each other.
---
---They are guarded like the key that closes, and for the same reason: the
---mapping is buffer local and the working tree side is the reviewer's own file,
---so the same key is on that buffer in every other window it is open in. Only a
---window that is a side of a mounted diff walks the review — anywhere else there
---is no diff to walk it from, and the panel that would move is one the reviewer
---is not reading.
---@return ReviewDiffKey[]
local function stepping_keys()
  local mappings = config.options.mappings
  ---@param direction integer
  ---@param unseen boolean
  ---@return fun()
  local function step(direction, unseen)
    return function()
      if not mount_of(vim.api.nvim_get_current_win()) then return end
      require("review.panel").step { direction = direction, unseen = unseen }
    end
  end

  -- One label for each pair: the two keys are one thing, forward and back.
  local left_to_read, every_file = "não vista", "todas"
  return {
    {
      key = mappings.next_unseen,
      label = left_to_read,
      desc = "Abrir o diff da próxima não vista, sem passar pela lista",
      run = step(1, true),
    },
    {
      key = mappings.previous_unseen,
      label = left_to_read,
      desc = "Abrir o diff da não vista anterior, sem passar pela lista",
      run = step(-1, true),
    },
    {
      key = mappings.next_file,
      label = every_file,
      desc = "Abrir o diff do próximo arquivo, vistos inclusive",
      run = step(1, false),
    },
    {
      key = mappings.previous_file,
      label = every_file,
      desc = "Abrir o diff do arquivo anterior, vistos inclusive",
      run = step(-1, false),
    },
  }
end

---Walk to the change one step away inside the side being read, and say whether
---there was one to walk to. It is the editor's own movement, on the key it has
---always been on: what the diff adds is only what happens when there is nothing
---left in this direction.
---@param direction integer 1 forward through the file, -1 back through it
---@return boolean moved
local function to_change(direction)
  local before = vim.api.nvim_win_get_cursor(0)[1]
  -- A beep and nothing else when there is no change that way, which is exactly
  -- what is being read here. The `pcall` is for the window that is not in diff
  -- mode — one side alone, which these keys are not given to, and a side left
  -- by something else.
  pcall(vim.cmd, "normal! " .. (direction == 1 and "]c" or "[c"))
  return vim.api.nvim_win_get_cursor(0)[1] ~= before
end

---Put the cursor on the change the reviewer is coming in through: the first one
---of the file when they are walking forward, the last one when they are walking
---back.
---
---A file opens at its top, and a key that means "the next change" leaving the
---reviewer above the first one would have to be pressed again for what it had
---already been asked for. Crossing into a file is still the key doing what it
---says.
---@param direction integer
local function to_edge_change(direction)
  local edge = direction == 1 and 1 or vim.api.nvim_buf_line_count(0)
  vim.api.nvim_win_set_cursor(0, { edge, 0 })
  -- The edge line can be inside a change itself, and then it is the answer: the
  -- movement from there would go past it, to the second change of the file.
  if vim.fn.diff_hlID(edge, 1) == 0 then return to_change(direction) end
  if direction == -1 then
    -- Inside the last change, where the start of it is what the key means.
    while edge > 1 and vim.fn.diff_hlID(edge - 1, 1) ~= 0 do
      edge = edge - 1
    end
    vim.api.nvim_win_set_cursor(0, { edge, 0 })
  end
end

---What the end of a file says: that it is the end, and what the same key does
---from here. The key is named because it is the answer — the reviewer pressed
---something and the screen did not move.
---@param direction integer
---@return string
local function edge_message(direction)
  local mappings = config.options.mappings
  if direction == 1 then
    return ("review: última mudança deste arquivo; %s de novo abre o próximo por ler."):format(mappings.next_change)
  end
  return ("review: primeira mudança deste arquivo; %s de novo abre o anterior por ler."):format(
    mappings.previous_change
  )
end

---The keys that walk the changes inside the file being read, and then go on
---into the next file.
---
---They are the editor's own `]c` and `[c`, which is where the reviewer's
---fingers already are, and they answer the same up to the end of the file. What
---the diff adds is the end: the first press there says it is the last change,
---and the one after it opens the next file still to read, at the first change
---of it — the review going on at the scale above, which is `]f` (ADR-0009: the
---cursor of the panel is the position of the review, and this moves it too).
---
---Guarded like the keys beside them: the mapping is buffer local and the
---working tree side is the reviewer's own file, so the same key is on that
---buffer in every other window it is open in. Only a window that is a side of a
---mounted diff walks anything.
---@return ReviewDiffKey[]
local function changing_keys()
  local mappings = config.options.mappings
  ---@param direction integer
  ---@return fun()
  local function step(direction)
    return function()
      local tab = mount_of(vim.api.nvim_get_current_win())
      if not tab then return end

      if to_change(direction) then
        at_edge_by_tab[tab] = nil
        return
      end
      if at_edge_by_tab[tab] ~= direction then
        at_edge_by_tab[tab] = direction
        vim.notify(edge_message(direction))
        return
      end

      at_edge_by_tab[tab] = nil
      local moved, spoke = require("review.panel").step { direction = direction, unseen = true }
      if not moved then
        -- The end of the review, and it is said out loud: the reviewer was just
        -- told this key would open the next file, and a key that answers
        -- nothing twice reads as a key that stopped working. Unless the step
        -- itself has already said what stopped it — two messages about one key
        -- press, and the second one wrong.
        if not spoke then
          vim.notify(
            direction == 1 and "review: não há próximo arquivo por ler."
              or "review: não há arquivo anterior por ler."
          )
        end
        return
      end
      -- Only into a diff of ours. The next line of the list can be a conflict,
      -- which opens in a tabpage of the diffview (ADR-0005), and moving the
      -- cursor inside that one is not this key's business.
      if mount_of(vim.api.nvim_get_current_win()) then to_edge_change(direction) end
    end
  end

  -- One label for the pair: the two keys are one thing, forward and back.
  local inside_the_file = "mudança"
  return {
    {
      key = mappings.next_change,
      label = inside_the_file,
      desc = "Ir para a próxima mudança do arquivo; na última, abrir o próximo arquivo por ler",
      run = step(1),
    },
    {
      key = mappings.previous_change,
      label = inside_the_file,
      desc = "Ir para a mudança anterior do arquivo; na primeira, abrir o arquivo anterior por ler",
      run = step(-1),
    },
  }
end

---The key that leaves the diff for the file itself, at the point being read.
---
---A diff is two versions side by side and nothing else: no LSP, no going to a
---definition, no editing in a commit. The reviewer who read down to a line and
---wants to *do* something there is asking for the file, and asking for it here
---— not at the top of it, which is where the key of the list opens it.
---
---Where "here" is comes from the text of the line and not from its number: the
---side being read is a version of the file, and its numbering means nothing on
---disk after anything above has changed (`open_file_at`, in the actions).
---
---Guarded like the keys beside it, and for the same reason: the mapping is
---buffer local and one of the sides is the reviewer's own file.
---@param target ReviewTarget
---@return ReviewDiffKey
local function opening_key(target)
  return {
    key = config.options.mappings.open_here,
    label = "o arquivo",
    desc = "Abrir o arquivo no disco no ponto que está sendo lido",
    run = function()
      if not mount_of(vim.api.nvim_get_current_win()) then return end
      require("review.actions").open_file_at(target, {
        lnum = vim.api.nvim_win_get_cursor(0)[1],
        text = vim.api.nvim_get_current_line(),
      })
    end,
  }
end

---The global keys of the review that work from inside the diff: the pair that
---annotates the line being read, or the run of lines selected in it, and the
---one that marks it as seen and opens the next one still to read.
---
---They are not the diff's: `setup` maps them, and they work in any file of the
---repository. The diff only names them, in its help, because the diff is where
---the reviewer is reading when the remark occurs to them — and what it names
---comes from the same options `setup` mapped them from.
---@param annotating boolean whether the pair that annotates is offered
---@return ReviewDiffKey[]
local function global_keys(annotating)
  local mappings = config.options.mappings
  local keys = {}
  if annotating then
    keys[#keys + 1] = {
      key = mappings.annotate_line,
      label = "anotar",
      desc = "Anotar a linha, ou o trecho selecionado",
    }
    keys[#keys + 1] = {
      key = mappings.annotate_line_long,
      label = "anotar",
      desc = "Anotar a linha, ou o trecho selecionado, na entrada de várias linhas",
    }
  end
  keys[#keys + 1] = {
    key = mappings.seen_and_open_next,
    label = "visto",
    desc = "Marcar como visto e abrir a próxima não vista",
  }
  return keys
end

---The key that lists every key of the diff in the help window, with what each
---one does: the winbar writes two of them, and the rest are there.
---
---Guarded like the keys beside it, and for the same reason: the mapping is
---buffer local and one of the sides is the reviewer's own file, which can be
---open in other windows too.
---@param keys fun(): ReviewDiffKey[] the keys of the diff — the list this key is
---part of, asked for when it is pressed
---@return ReviewDiffKey
local function helping_key(keys)
  local toggle = config.options.mappings.help
  return {
    key = toggle,
    label = "ajuda",
    desc = "Ver todas as teclas do diff, com o que cada uma faz",
    written = true,
    run = function()
      if not mount_of(vim.api.nvim_get_current_win()) then return end
      local listed = vim.tbl_map(function(key) return { key = key.key, desc = key.desc or key.label } end, keys())
      require("review.help").open("Teclas do diff", listed, toggle)
    end,
  }
end

---What the diff of a file under review answers to: the way out, and the keys
---that move the review to another file. Both of the presentations built here
---that show the change on a line get them — a reviewer walking the list is
---walking it whether the file is conflicted or not.
---
---The keys that annotate are named only when the side on the right — where the
---eye ends up — is the reviewer's own file. An
---annotation is written on the file itself, and on a side that is a rev — both
---sides of a staged diff, every version of a conflict — the key is refused: a
---key offered to be refused is worse than no key at all.
---
---What a rev is read or compared in does not get any of them: those are
---consultations of one file, where the key that matters is the one that gives
---the window back, and a key that moved the review would leave the reviewer
---somewhere they did not ask to be with nothing to come back to.
---@param target ReviewTarget the line the diff is being built of
---@param sides ReviewDiffSide[] left to right
---@return ReviewDiffKey[]
local function reviewing_keys(target, sides)
  local keys = vim.list_extend(
    vim.list_extend(vim.list_extend({ closing_key(target.panel) }, { opening_key(target) }), changing_keys()),
    stepping_keys()
  )
  vim.list_extend(keys, global_keys(sides[#sides].rev == nil))
  -- Beside the way out, where the winbar writes them together.
  table.insert(keys, 2, helping_key(function() return keys end))
  return keys
end

---Which side the reviewer is left in, and none at all when the diff is not to
---take them anywhere: the preview draws beside a list the reviewer is still
---walking, and a diff that took the cursor would end the sweep at its first
---file.
---
---What is built is the same either way — the same sides, the same keys — so
---that the diff the preview drew is the diff the reviewer is already reading
---when they decide to step into it.
---@param opts { focus: boolean|nil }|nil
---@param side integer index of the side to leave the reviewer in
---@return integer|nil
local function focus_on(opts, side)
  if opts and opts.focus == false then return nil end
  return side
end

---Build the diff of `target` beside its panel, replacing whatever diff was
---there. Focus goes to the right side: it is the one to edit in the working
---tree, and the version being reviewed in a commit.
---@param target ReviewTarget
---@param opts { focus: boolean|nil }|nil `focus = false` leaves the cursor
---where it is, which is what the preview of the list needs
function M.open(target, opts)
  local left, right = two_way_sides(target.entry)
  build(target, { left, right }, focus_on(opts, 2), reviewing_keys(target, { left, right }), target.entry)
end

---The line of the list the diff of this tabpage is showing, which is how the
---preview knows whether what is beside the list is already the file the cursor
---is on.
---
---Asked of the diff that is mounted, so the answer goes away exactly when the
---diff does: the key that closes it, a window of it closed by hand, the file
---opened over it. Whoever remembered this for themselves would go on saying a
---file was on the screen after it had gone.
---
---A consultation of a rev answers nothing: what it put there is a version the
---reviewer went looking for, not the change on the line.
---@return ReviewEntry|nil
function M.showing()
  local mount = mounted_by_tab[vim.api.nvim_get_current_tabpage()]
  return mount and mount.entry or nil
end

---The three versions git is holding for a conflicted path: a side each, short
---of the path, which is the file the reviewer asked about.
---
---Ours on the left and theirs on the right, which is where both of the
---diffview's merge layouts put them — the three presentations are there to be
---compared (ADR-0006), and they can only be compared if the reviewer has to
---re-learn which side is which on the way. The base goes in the middle, where
---the merge tool shows the merge: it is the one version neither side wrote,
---and what both of them changed away from.
local STAGES = {
  { label = "atual", rev = ":2" },
  { label = "base", rev = ":1" },
  { label = "entrando", rev = ":3" },
}

---Build the three versions of the conflict on `target` beside its panel,
---replacing whatever diff was there. The panel stays where it is: this is the
---presentation of a conflict that does not take the reviewer to another
---tabpage, so the list is still on the side while the three are read.
---
---A stage the index does not have — a file the two sides each added has no
---base — comes up as an empty side, which is what it is.
---@param target ReviewTarget
---@param opts { focus: boolean|nil }|nil `focus = false` leaves the cursor
---where it is, which is what the preview of the list needs
function M.open_conflict(target, opts)
  local sides = {}
  for index, stage in ipairs(STAGES) do
    sides[index] = vim.tbl_extend("error", stage, { path = target.entry.path })
  end
  -- Left in our own version: it is the side the reviewer knows, and the one
  -- the incoming change is being judged against.
  build(target, sides, focus_on(opts, 1), reviewing_keys(target, sides), target.entry)
end

---The name this file goes by in `rev`, and what is under it there.
---
---A renamed file is under its old name in a rev from before the rename and
---under the new one after it, and which of the two a rev the reviewer picked
---falls on is not something to guess: the name that answers is the one that is
---there. The old name is only tried when there is one, so nothing else pays
---for a second call to git.
---@param root string
---@param entry ReviewEntry
---@param rev string
---@return string|nil path nil when that rev has the file under neither name
---@return string[]|nil lines
local function in_rev(root, entry, rev)
  local lines = git.show(root, rev, entry.path)
  if lines then return entry.path, lines end
  if not entry.orig_path then return nil end
  lines = git.show(root, rev, entry.orig_path)
  if lines then return entry.orig_path, lines end
end

---Compare the file on the line with the version of it in `rev`: that version on
---the left, what the panel is reviewing on the right. The rev chosen is on the
---left because it is the past being read against the present, which is the
---direction of every other diff the panel builds.
---@param target ReviewTarget
---@param rev string anything git resolves
function M.open_against(target, rev)
  local entry = target.entry
  local path, lines = in_rev(target.root, entry, rev)

  -- What the rev is compared against is what the panel is listing: the file on
  -- disk in the working tree, and the commit's own version in commit mode. A
  -- commit has no working tree side for the same reason its own diff has none —
  -- both of its versions are history, and what is on disk today is not what the
  -- line is showing. It is also a file that may not be there at all any more.
  local current = entry.rev and { label = short(entry.rev), rev = entry.rev, path = entry.path }
    or { label = "working tree", rev = nil, path = entry.path }

  build(target, {
    -- A rev that has the file under neither name is an empty side, which is
    -- what it is: the file was not there yet, or was already gone.
    { label = short(rev), rev = rev, path = path or entry.path, lines = lines or { "" } },
    current,
  }, 2, { closing_key(target.panel) })
end

---Take the read-only view of a rev off the screen: the window goes back to the
---file that was beside the panel before it, or goes away when there was none,
---and the reviewer is left in the list they pressed the key in.
---
---This is the whole of "the consultation costs nothing": what was being read
---comes back with one key. A diff that was on screen does not come back — its
---sides went when the view took their place — but the file of it does, which is
---the side the reviewer was reading and the one their edits are in.
---@param win integer winid the view is in
---@param panel integer winid of the panel it was opened from
---@param previous integer|nil bufnr to put back
local function leave(win, panel, previous)
  if vim.api.nvim_win_is_valid(win) then
    local tab = vim.api.nvim_win_get_tabpage(win)
    -- What is about to be in this window is the reviewer's, not for us to take
    -- down later — and it comes back without the winbar of the view over it and
    -- without the key that leaves the view on it. Only when the view is all that
    -- is mounted there: a window carried to another tabpage (`<C-w>T`) lands
    -- among that tabpage's own windows, and forgetting those would leave them
    -- behind on the next diff.
    local mount = mounted_by_tab[tab]
    if mount and #mount.wins == 1 and mount.wins[1] == win then
      mounted_by_tab[tab] = nil
      back_to_by_tab[tab] = nil
      unhook(mount)
    end

    if previous and vim.api.nvim_buf_is_valid(previous) then
      vim.api.nvim_win_set_buf(win, previous)
    elseif #vim.api.nvim_tabpage_list_wins(tab) > 1 then
      pcall(vim.api.nvim_win_close, win, true)
    else
      vim.api.nvim_win_call(win, function() vim.cmd "enew" end)
    end
  end
  -- The panel takes the cursor back when it is there to take it. With the list
  -- closed the reviewer stays in the window that has just come back to them,
  -- which is what they were looking at.
  if panel and vim.api.nvim_win_is_valid(panel) then vim.api.nvim_set_current_win(panel) end
end

---Show the file on the line as it is in `rev`, read only, in the window beside
---the panel, with the way back on the key that closes the panel and the graph.
---
---Read only because it is a consultation: what is in a rev is history, and an
---edit made here would have nowhere to be saved. The buffer is named after the
---rev, which is how the reviewer knows which version they are reading — the
---file itself is a key away, and the two look alike otherwise.
---@param target ReviewTarget
---@param rev string anything git resolves
---@return boolean opened false when that rev has no such path, which is nothing
---to show — unlike a diff, where it is an empty side
function M.open_rev(target, rev)
  local path, lines = in_rev(target.root, target.entry, rev)
  if not path then return false end

  -- Read before anything moves: the diff about to be replaced holds the file
  -- the reviewer was reading, and once its windows are gone there is no telling
  -- what was in them. A view already on screen has nothing to be asked — it is
  -- a buffer of ours — so what it was going to give back is carried forward.
  local tab = vim.api.nvim_get_current_tabpage()
  local previous = window.file_beside(target.panel) or back_to_by_tab[tab]

  -- The key is written where the view is read, like the one that closes a diff,
  -- and it says the other thing this one does: the consultation gives the window
  -- back to what was in it. It is mounted with the view, so it goes with the
  -- view — the window that comes back is the reviewer's again.
  local win
  local back = {
    key = config.options.mappings.close,
    label = "voltar",
    written = true,
    desc = "Voltar ao que estava ao lado do painel",
    run = function() leave(win, target.panel, previous) end,
  }
  win = build(target, { { label = short(rev), rev = rev, path = path, lines = lines } }, 1, { back })[1]
  back_to_by_tab[tab] = previous

  return true
end

return M
