local draw = {}

local function safeColour(target, method, value)
  if target and target[method] then
    pcall(target[method], value)
  end
end

function draw.size(target)
  return target.getSize()
end

function draw.clear(target, bg, fg)
  safeColour(target, "setBackgroundColor", bg or colors.black)
  safeColour(target, "setTextColor", fg or colors.white)
  target.clear()
  target.setCursorPos(1, 1)
end

function draw.fill(target, x, y, w, h, bg, char)
  if w <= 0 or h <= 0 then return end
  char = char or " "
  safeColour(target, "setBackgroundColor", bg or colors.black)
  local line = string.rep(char, w)
  for row = y, y + h - 1 do
    target.setCursorPos(x, row)
    target.write(line)
  end
end

function draw.text(target, x, y, text, fg, bg, maxWidth)
  text = tostring(text or "")
  if maxWidth and #text > maxWidth then
    if maxWidth <= 1 then
      text = string.sub(text, 1, maxWidth)
    else
      text = string.sub(text, 1, maxWidth - 1) .. "~"
    end
  end
  if bg then safeColour(target, "setBackgroundColor", bg) end
  if fg then safeColour(target, "setTextColor", fg) end
  target.setCursorPos(x, y)
  target.write(text)
end

function draw.center(target, y, text, fg, bg)
  local w = target.getSize()
  text = tostring(text or "")
  local x = math.max(1, math.floor((w - #text) / 2) + 1)
  draw.text(target, x, y, text, fg, bg)
end

function draw.hline(target, x, y, w, char, fg, bg)
  char = char or "-"
  draw.text(target, x, y, string.rep(char, math.max(0, w)), fg, bg)
end

function draw.box(target, x, y, w, h, bg, fg, title)
  if w < 2 or h < 2 then return end
  draw.fill(target, x, y, w, h, bg)
  if title and h >= 2 then
    draw.text(target, x + 1, y, " " .. tostring(title) .. " ", fg, bg, math.max(0, w - 2))
  end
end

function draw.button(target, x, y, w, label, fg, bg, selected)
  if w <= 0 then return end
  local text = tostring(label or "")
  if #text > w - 2 then
    text = string.sub(text, 1, math.max(1, w - 3)) .. "~"
  end
  local pad = math.max(0, w - #text)
  local left = math.floor(pad / 2)
  local right = pad - left
  local fillBg = selected and (fg or colors.white) or (bg or colors.gray)
  local fillFg = selected and (bg or colors.black) or (fg or colors.white)
  draw.text(target, x, y, string.rep(" ", left) .. text .. string.rep(" ", right), fillFg, fillBg)
end

function draw.wrap(text, width)
  text = tostring(text or "")
  width = math.max(1, tonumber(width) or 1)
  local lines = {}

  for paragraph in (text .. "\n"):gmatch("(.-)\n") do
    if paragraph == "" then
      lines[#lines + 1] = ""
    else
      local line = ""
      for word in paragraph:gmatch("%S+") do
        if #word > width then
          if line ~= "" then
            lines[#lines + 1] = line
            line = ""
          end
          while #word > width do
            lines[#lines + 1] = string.sub(word, 1, width)
            word = string.sub(word, width + 1)
          end
          line = word
        elseif line == "" then
          line = word
        elseif #line + 1 + #word <= width then
          line = line .. " " .. word
        else
          lines[#lines + 1] = line
          line = word
        end
      end
      if line ~= "" then lines[#lines + 1] = line end
    end
  end

  return lines
end

function draw.list(target, x, y, w, h, items, fg, muted, bg)
  local count = math.min(h, #items)
  for i = 1, count do
    local item = items[i]
    local text = type(item) == "table" and item.text or tostring(item)
    local colour = type(item) == "table" and (item.fg or fg) or fg
    draw.text(target, x, y + i - 1, text, colour or colors.white, bg, w)
  end
  for i = count + 1, h do
    draw.text(target, x, y + i - 1, string.rep(" ", w), muted or colors.gray, bg)
  end
end

return draw
