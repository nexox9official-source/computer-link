local draw = dofile("/computer-link/src/ui/draw.lua")

local shellui = {}

local APPS = {
  {id="home", title="Bureau", short="HOME", icon="[]", pinned=true},
  {id="messages", title="Messages", short="MSG", icon="<>", pinned=true},
  {id="contacts", title="Contacts", short="CONT", icon="@@", pinned=false},
  {id="network", title="Reseau", short="NET", icon="::", pinned=true},
  {id="security", title="Securite", short="SEC", icon="##", pinned=true},
  {id="files", title="Fichiers", short="FILES", icon="//", pinned=true},
  {id="notes", title="Notes", short="NOTE", icon="N", pinned=false},
  {id="calculator", title="Calculatrice", short="CALC", icon="+", pinned=false},
  {id="terminal", title="Terminal", short="TERM", icon=">_", pinned=false},
  {id="settings", title="Parametres", short="SET", icon="**", pinned=false},
  {id="about", title="A propos", short="INFO", icon="i", pinned=false},
  {id="hacker", title="LinkSec", short="LSEC", icon="X", pinned=true, operator=true}
}

local function clone(value)
  local out = {}
  for k, v in pairs(value) do out[k] = v end
  return out
end

function shellui.apps(operator)
  local out = {}
  for _, app in ipairs(APPS) do
    if not app.operator or operator then
      out[#out + 1] = clone(app)
    end
  end
  return out
end

function shellui.find(id, operator)
  for _, app in ipairs(shellui.apps(operator)) do
    if app.id == id then return app end
  end
  return nil
end

function shellui.allowed(id, operator)
  return shellui.find(id, operator) ~= nil
end

function shellui.pinned(operator)
  local out = {}
  for _, app in ipairs(shellui.apps(operator)) do
    if app.pinned then out[#out + 1] = app end
  end
  return out
end

function shellui.nextApp(current, operator, delta)
  local apps = shellui.apps(operator)
  if #apps == 0 then return "home" end

  local index = 1
  for i, app in ipairs(apps) do
    if app.id == current then
      index = i
      break
    end
  end

  delta = tonumber(delta) or 1
  index = ((index - 1 + delta) % #apps) + 1
  return apps[index].id
end

function shellui.wallpaper(target, x, y, w, h, mode, accent)
  mode = tostring(mode or "grid")
  local bg = colors.black
  draw.fill(target, x, y, w, h, bg)

  if w <= 0 or h <= 0 then return end

  if mode == "grid" then
    local stepX = w >= 55 and 8 or 6
    local stepY = h >= 20 and 4 or 3
    for py = y, y + h - 1, stepY do
      for px = x, x + w - 1, stepX do
        draw.text(target, px, py, ".", accent or colors.cyan, bg, 1)
      end
    end
  elseif mode == "lines" then
    for py = y, y + h - 1, 3 do
      draw.hline(target, x, py, w, "-", colors.gray, bg)
    end
  elseif mode == "clean" then
    -- Deliberately empty.
  else
    for py = y, y + h - 1, 2 do
      local offset = ((py - y) % 4 == 0) and 0 or 2
      for px = x + offset, x + w - 1, 6 do
        draw.text(target, px, py, ".", colors.gray, bg, 1)
      end
    end
  end
end

function shellui.startMenuRect(layout)
  local w = math.min(math.max(24, math.floor(layout.w * 0.56)), 44)
  local h = math.min(math.max(10, math.floor(layout.h * 0.65)), math.max(8, layout.h - 3))
  local x = 1
  local y = math.max(3, layout.h - h)
  return x, y, w, h
end

function shellui.quickPanelRect(layout)
  local w = math.min(math.max(22, math.floor(layout.w * 0.42)), 36)
  local h = math.min(11, math.max(7, layout.h - 4))
  local x = math.max(1, layout.w - w + 1)
  local y = math.max(3, layout.h - h)
  return x, y, w, h
end

return shellui
