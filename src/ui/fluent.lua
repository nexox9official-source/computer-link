local draw = dofile("/computer-link/src/ui/draw.lua")

local fluent = {}

local PALETTE = {
  [colors.black] = 0x0b0f14,
  [colors.gray] = 0x202832,
  [colors.lightGray] = 0x7d8996,
  [colors.white] = 0xf3f7fb,
  [colors.blue] = 0x0f6cbd,
  [colors.lightBlue] = 0x4cc2ff,
  [colors.cyan] = 0x47c5fb,
  [colors.lime] = 0x6ccb5f,
  [colors.green] = 0x2ea043,
  [colors.yellow] = 0xf1c40f,
  [colors.orange] = 0xf0883e,
  [colors.red] = 0xf85149,
  [colors.purple] = 0xa371f7,
  [colors.magenta] = 0xd65db1,
  [colors.brown] = 0x8b6f47,
  [colors.pink] = 0xff7eb6
}

local ACCENTS = {
  cyan = colors.cyan,
  blue = colors.lightBlue,
  lime = colors.lime,
  orange = colors.orange,
  purple = colors.purple,
  red = colors.red
}

local ICONS = {
  home       = {glyph="W", colour=colors.lightBlue, pixels={"#.#","...","#.#"}},
  messages   = {glyph="@", colour=colors.cyan,      pixels={"###","#.#","###"}},
  contacts   = {glyph="o", colour=colors.lightBlue,pixels={".#.",".#.","###"}},
  network    = {glyph="^", colour=colors.lime,      pixels={"..#",".##","###"}},
  security   = {glyph="#", colour=colors.purple,    pixels={"###","###",".#."}},
  files      = {glyph="D", colour=colors.orange,    pixels={"##.","###","###"}},
  notes      = {glyph="N", colour=colors.yellow,    pixels={"###","###","##."}},
  calculator = {glyph="=", colour=colors.green,     pixels={"###","#.#","###"}},
  terminal   = {glyph=">", colour=colors.lightGray, pixels={"#..",".#.","..#"}},
  settings   = {glyph="*", colour=colors.blue,      pixels={"#.#",".#.","#.#"}},
  about      = {glyph="i", colour=colors.cyan,      pixels={".#.","...","##."}},
  hacker     = {glyph="!", colour=colors.red,       pixels={"#.#",".#.","#.#"}},
  store      = {glyph="+", colour=colors.blue,      pixels={".#.","###","#.#"}},
  tasks      = {glyph="v", colour=colors.cyan,      pixels={"#..","##.","###"}},
  stopwatch  = {glyph="C", colour=colors.orange,    pixels={".#.","###",".#."}},
  units      = {glyph="=", colour=colors.lightBlue,pixels={"#.#",".#.","#.#"}},
  devices    = {glyph="P", colour=colors.purple,    pixels={"###","#.#","###"}},
  calendar   = {glyph="J", colour=colors.red,       pixels={"###","#.#","###"}},
  system     = {glyph="I", colour=colors.lightBlue,pixels={"###",".#.","###"}},
  redstone   = {glyph="R", colour=colors.red,       pixels={".#.","###",".#."}},
  gps        = {glyph="G", colour=colors.lime,      pixels={".#.","#.#",".#."}}
}

function fluent.applyPalette(target)
  if not target or not target.setPaletteColor then return false end
  local ok = true
  for colour, rgb in pairs(PALETTE) do
    local success = pcall(target.setPaletteColor, colour, rgb)
    ok = ok and success
  end
  return ok
end

function fluent.theme(accentName)
  local accent = ACCENTS[tostring(accentName or "blue")] or colors.lightBlue
  return {
    bg = colors.black,
    desktop = colors.black,
    surface = colors.gray,
    surface2 = colors.black,
    elevated = colors.gray,
    border = colors.lightGray,
    text = colors.white,
    muted = colors.lightGray,
    accent = accent,
    accentText = colors.white,
    good = colors.lime,
    warn = colors.orange,
    danger = colors.red,
    taskbar = colors.black,
    titleActive = colors.gray,
    titleInactive = colors.black,
    selection = colors.gray,
    button = colors.gray,
    buttonQuiet = colors.black
  }
end

function fluent.icon(id)
  id = tostring(id or "")
  if id:sub(1,4) == "pkg:" then id = id:sub(5) end
  return ICONS[id] or {glyph="+", colour=colors.lightBlue, pixels={"###","#.#","###"}}
end

function fluent.glyph(id)
  return fluent.icon(id).glyph
end

function fluent.iconColour(id, fallback)
  return fluent.icon(id).colour or fallback or colors.lightBlue
end

function fluent.drawIcon(target, id, x, y, selected, background)
  local icon = fluent.icon(id)
  local bg = background or colors.black
  local pixel = icon.colour
  local pattern = icon.pixels
  if selected then
    draw.fill(target, x-1, y-1, 5, 5, colors.gray)
  end
  for row=1,3 do
    local line = pattern[row] or "..."
    for col=1,3 do
      local on = line:sub(col,col) == "#"
      draw.fill(target, x+col-1, y+row-1, 1, 1, on and pixel or bg)
    end
  end
end

function fluent.drawMiniIcon(target, id, x, y, active, bg)
  local icon = fluent.icon(id)
  draw.fill(target, x, y, 3, 1, active and icon.colour or (bg or colors.black))
  draw.text(target, x+1, y, icon.glyph, colors.white,
    active and icon.colour or (bg or colors.black), 1)
end

function fluent.surface(target, x, y, w, h, elevated)
  local bg = elevated and colors.gray or colors.black
  draw.fill(target, x, y, w, h, bg)
  if w >= 2 and h >= 2 then
    draw.fill(target, x, y, w, 1, elevated and colors.gray or colors.black)
  end
  return bg
end

function fluent.card(target, x, y, w, h, opts)
  opts = opts or {}
  local bg = opts.bg or colors.gray
  draw.fill(target, x, y, w, h, bg)
  if opts.accent then draw.fill(target, x, y, 1, h, opts.accent) end
  if opts.title then
    draw.text(target, x + (opts.accent and 2 or 1), y,
      opts.title, opts.titleFg or colors.white, bg,
      math.max(1, w - (opts.accent and 3 or 2)))
  end
  if opts.subtitle and h >= 2 then
    draw.text(target, x + (opts.accent and 2 or 1), y+1,
      opts.subtitle, opts.muted or colors.lightGray, bg,
      math.max(1, w - (opts.accent and 3 or 2)))
  end
end

function fluent.button(target, x, y, w, label, state)
  state = state or {}
  local bg = state.danger and colors.red
    or state.primary and (state.accent or colors.lightBlue)
    or state.active and colors.gray
    or colors.black
  local fg = colors.white
  draw.button(target, x, y, w, label, fg, bg)
  if state.active and w >= 3 then
    draw.fill(target, x+1, y, math.max(1,w-2), 1, bg)
    draw.text(target, x+1, y, tostring(label or ""), fg, bg, math.max(1,w-2))
  end
end

function fluent.searchBox(target, x, y, w, text, placeholder, accent)
  draw.fill(target, x, y, w, 1, colors.black)
  draw.text(target, x+1, y, "?", accent or colors.lightBlue, colors.black, 1)
  local value = tostring(text or "")
  draw.text(target, x+3, y, value ~= "" and value or tostring(placeholder or "Rechercher"),
    value ~= "" and colors.white or colors.lightGray, colors.black, math.max(1,w-4))
end

function fluent.sectionTitle(target, x, y, w, title, subtitle, accent)
  draw.text(target, x, y, tostring(title or ""), colors.white, colors.black, w)
  if subtitle and y then
    draw.text(target, x, y+1, tostring(subtitle), colors.lightGray, colors.black, w)
  end
  if accent and w > 0 then draw.fill(target, x, y+2, math.min(6,w), 1, accent) end
end

return fluent
