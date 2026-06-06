-- cide base IDE — yazi bootstrap (user init; setup() calls go HERE, never in main.lua)
require("git"):setup { order = 1500 }   -- per-file git status linemode
-- osc7 removed: its main.lua fails to load on yazi 26.5.6 (cwd-sync is optional; revisit/replace later)
-- require("githead"):setup()            -- uncomment if the githead flavor/plugin is installed
