-- The root detector, as the tests get it.
--
-- The panel asks the astrocore rooter where a file's project begins, and the
-- rooter reads the list of detectors from the astrocore configuration — which
-- is filled in by AstroNvim at setup, not by astrocore itself, so a headless
-- editor that only put astrocore on the runtimepath has an empty one and
-- detects nothing.
--
-- This is that list: the one AstroNvim ships and this configuration keeps,
-- written out here so a test runs against the detector the reviewer has. It is
-- a copy, and copies drift: the day `lua/plugins/astrocore.lua` starts
-- overriding `rooter`, this has to follow it.

local M = {}

---Give the rooter the detectors this configuration runs with: the language
---servers of the file first, project markers after.
function M.install()
  require("astrocore").config.rooter = {
    detector = { "lsp", { ".git", "_darcs", ".hg", ".bzr", ".svn" }, { "lua", "Makefile", "package.json" } },
  }
end

return M
