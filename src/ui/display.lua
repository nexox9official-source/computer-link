local display = {}

local SCALE_STEPS = {0.5, 1, 1.5, 2, 2.5, 3, 3.5, 4, 4.5, 5}
local scaleCache = {}

local function isMonitor(name)
  return peripheral.getType(name) == "monitor"
end

local function maxResolution(monitor)
  local previous = monitor.getTextScale and monitor.getTextScale() or 1
  if monitor.setTextScale then pcall(monitor.setTextScale, 0.5) end
  local w, h = monitor.getSize()
  if monitor.setTextScale then pcall(monitor.setTextScale, previous) end
  return w, h
end

local function chooseThreshold(maxW, maxH)
  if maxW >= 110 and maxH >= 34 then
    return 82, 26
  elseif maxW >= 75 and maxH >= 26 then
    return 60, 21
  elseif maxW >= 48 and maxH >= 19 then
    return 42, 16
  else
    return 26, 12
  end
end

function display.autoScaleMonitor(monitor)
  if not monitor or not monitor.setTextScale then return 1 end

  local maxW, maxH = maxResolution(monitor)
  local minW, minH = chooseThreshold(maxW, maxH)
  local best = 0.5

  for _, scale in ipairs(SCALE_STEPS) do
    pcall(monitor.setTextScale, scale)
    local w, h = monitor.getSize()
    if w >= minW and h >= minH then
      best = scale
    else
      break
    end
  end

  pcall(monitor.setTextScale, best)
  return best
end

function display.layoutFor(w, h)
  if w >= 86 and h >= 24 then
    return "wall"
  elseif w >= 58 and h >= 18 then
    return "wide"
  elseif w >= 38 and h >= 15 then
    return "standard"
  end
  return "compact"
end

function display.list()
  local out = {}

  local native = term.native and term.native() or term.current()
  local nw, nh = native.getSize()
  out[#out + 1] = {
    id = "computer",
    name = "computer",
    label = "Ecran du PC",
    kind = "computer",
    target = native,
    width = nw,
    height = nh,
    color = native.isColor and native.isColor() or false,
    touch = native.isColor and native.isColor() or false,
    scale = nil,
    layout = display.layoutFor(nw, nh),
    score = nw * nh
  }

  for _, name in ipairs(peripheral.getNames()) do
    if isMonitor(name) then
      local monitor = peripheral.wrap(name)
      if monitor then
        local beforeW, beforeH = monitor.getSize()
        local cached = scaleCache[name]
        local scale
        if cached and cached.w == beforeW and cached.h == beforeH then
          scale = cached.scale
        else
          scale = display.autoScaleMonitor(monitor)
        end
        local w, h = monitor.getSize()
        scaleCache[name] = {w=w, h=h, scale=scale}
        out[#out + 1] = {
          id = "monitor:" .. name,
          name = name,
          label = "Moniteur " .. name,
          kind = "monitor",
          target = monitor,
          width = w,
          height = h,
          color = monitor.isColor and monitor.isColor() or false,
          touch = monitor.isColor and monitor.isColor() or false,
          scale = scale,
          layout = display.layoutFor(w, h),
          score = (w * h) + (monitor.isColor and monitor.isColor() and 10000 or 0)
        }
      end
    end
  end

  table.sort(out, function(a, b)
    if a.kind ~= b.kind then
      if a.kind == "monitor" and b.kind == "computer" then return true end
      if a.kind == "computer" and b.kind == "monitor" then return false end
    end
    return a.score > b.score
  end)

  return out
end

function display.findById(displays, id)
  for _, d in ipairs(displays or {}) do
    if d.id == id then return d end
  end
  return nil
end

function display.best(displays)
  displays = displays or display.list()
  local best = displays[1]
  if not best then return nil end

  for _, d in ipairs(displays) do
    if d.kind == "monitor" and d.color then
      if not best or best.kind ~= "monitor" or not best.color or d.score > best.score then
        best = d
      end
    elseif not best then
      best = d
    end
  end

  return best
end

function display.refresh(selectedId)
  local displays = display.list()
  local active = selectedId and display.findById(displays, selectedId) or nil
  if not active then active = display.best(displays) end
  if not active then active = displays[1] end
  return displays, active
end

return display
