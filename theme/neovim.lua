-- Ryoku Neovim palettes. Structural tokens are shared; only the hue families
-- differ.
--   :RyokuPalette <name>          switch live, this session only
--   :RyokuPalette default <name>  set the persisted default (survives restart)
--   :RyokuPalette / default       report current / persisted default
-- Persisted default lives in ~/.local/state/ryoku/nvim-palette.

local base = {
  bg = "#000000", dark_bg = "#000000", darker_bg = "#000000", lighter_bg = "#17171a",
  fg = "#cdc4ba", dark_fg = "#7a756e", light_fg = "#b0a9a0", bright_fg = "#f4f2ed",
  muted = "#7a756e",
  red = "#e2342a", bright_red = "#f05a4e", brown = "#4a453f",
  accent = "#cdc4ba", cursor = "#f4f2ed",
  foreground = "#cdc4ba", background = "#000000",
  selection = "#2a2724", selection_foreground = "#f4f2ed", selection_background = "#2a2724",
}

local palettes = {
  -- Traditional woodblock pigments: warm, earthy, colourful without neon.
  ukiyoe = {
    yellow = "#e0b563", bright_yellow = "#e8c88f",
    orange = "#d97a4e",
    green = "#8fae6d", bright_green = "#a3c281",
    cyan = "#6fa8a3", bright_cyan = "#86bdb8",
    blue = "#7d9fc4", bright_blue = "#96b3d4",
    magenta = "#b06a84", bright_magenta = "#c47a94",
  },
  -- Roughly double the original Ryoku saturation; still reads monochrome.
  inkwash = {
    yellow = "#d8c9a4", bright_yellow = "#e8d8c9",
    orange = "#c8805f",
    green = "#96a37e", bright_green = "#a9b492",
    cyan = "#85a0a6", bright_cyan = "#9cb4b9",
    blue = "#93a0ba", bright_blue = "#a8b3c9",
    magenta = "#b09aa4", bright_magenta = "#c2a6b2",
  },
}

local fallback_default = "ukiyoe"
local state_dir = vim.fn.expand("~/.local/state/ryoku")
local state_file = state_dir .. "/nvim-palette"

local function persisted_default()
  local f = io.open(state_file, "r")
  if not f then return fallback_default end
  local name = vim.trim(f:read("*l") or "")
  f:close()
  return palettes[name] and name or fallback_default
end

local function set_persisted_default(name)
  vim.fn.mkdir(state_dir, "p")
  local f = io.open(state_file, "w")
  if f then
    f:write(name .. "\n")
    f:close()
  end
end

local function colors_for(name)
  return vim.tbl_extend("force", base, palettes[name])
end

-- Tracks what's actually applied this session; starts from the persisted
-- default and moves independently of it until `default <name>` is used.
local current = persisted_default()

return {
  {
    "bjarneo/aether.nvim",
    branch = "v3",
    name = "aether",
    priority = 1000,
    opts = { colors = colors_for(current) },
    init = function()
      vim.api.nvim_create_user_command("RyokuPalette", function(cmd)
        local args = vim.split(vim.trim(cmd.args), "%s+")
        if args[1] == "" then
          vim.notify("Ryoku palette: " .. current .. " (default: " .. persisted_default() .. ")")
          return
        end

        if args[1] == "default" then
          local name = args[2]
          if not name then
            vim.notify("Ryoku default palette: " .. persisted_default())
            return
          end
          if not palettes[name] then
            vim.notify("No such palette: " .. name, vim.log.levels.ERROR)
            return
          end
          set_persisted_default(name)
          vim.notify("Ryoku default palette set: " .. name)
          return
        end

        local name = args[1]
        if not palettes[name] then
          vim.notify("No such palette: " .. name, vim.log.levels.ERROR)
          return
        end
        current = name
        require("aether").setup({ colors = colors_for(name) })
        vim.cmd.colorscheme("aether")
        vim.notify("Ryoku palette: " .. name)
      end, {
        nargs = "?",
        desc = "Switch or set default Ryoku Neovim syntax palette",
        complete = function(_, cmdline)
          local names = vim.tbl_keys(palettes)
          table.sort(names)
          if cmdline:match("^%s*RyokuPalette%s+default%s+%S*$") then
            return names
          end
          local opts = { "default" }
          vim.list_extend(opts, names)
          return opts
        end,
      })
    end,
  },
  {
    "LazyVim/LazyVim",
    opts = { colorscheme = "aether" },
  },
}
