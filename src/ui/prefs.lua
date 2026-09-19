local config = dofile("/computer-link/src/common/config.lua")
local util = dofile("/computer-link/src/common/util.lua")

local prefs = {}
local PATH = config.DATA_DIR .. "/ui.db"

local defaults = {
  schema = 3,
  display_id = nil,
  accent = "cyan",
  wallpaper = "dots",
  taskbar_labels = false,
  start_compact = false,
  quick_panel = true,
  aliases = {},
  last_app = "home"
}

local state = nil

local function normalise(value)
  value = type(value) == "table" and value or {}
  for key, default in pairs(defaults) do
    if value[key] == nil then
      if type(default) == "table" then
        value[key] = {}
      else
        value[key] = default
      end
    end
  end
  value.aliases = value.aliases or {}
  return value
end

function prefs.load()
  if state then return state end
  util.ensureDir(config.DATA_DIR)
  state = normalise(util.loadTable(PATH, {}))
  return state
end

function prefs.save()
  if not state then prefs.load() end
  return util.saveTable(PATH, state)
end

function prefs.get(key, fallback)
  local s = prefs.load()
  if s[key] == nil then return fallback end
  return s[key]
end

function prefs.set(key, value)
  local s = prefs.load()
  s[key] = value
  prefs.save()
end

function prefs.alias(computerId)
  local s = prefs.load()
  return s.aliases[tostring(computerId)]
end

function prefs.setAlias(computerId, name)
  local s = prefs.load()
  local key = tostring(tonumber(computerId) or computerId)
  name = tostring(name or "")
  if name == "" then
    s.aliases[key] = nil
  else
    s.aliases[key] = string.sub(name, 1, 24)
  end
  prefs.save()
end

function prefs.all()
  return prefs.load()
end

return prefs
