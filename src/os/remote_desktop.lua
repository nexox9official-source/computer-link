local util = dofile("/computer-link/src/common/util.lua")

local RemoteDesktop = {}

local PROTOCOL = "astralnet.ghostlink.v1"

local function sendCommand(targetId, action, argument)
  rednet.send(targetId, {
    magic = "GHOSTLINK_GAMEPLAY",
    type = "COMMAND",
    source_id = os.getComputerID(),
    request_id = util.requestId(),
    payload = {
      action = action,
      argument = argument or {}
    }
  }, PROTOCOL)
end

local function crop(value, width)
  value = tostring(value or "")
  if #value > width then return string.sub(value, 1, width) end
  if #value < width then return value .. string.rep(" ", width - #value) end
  return value
end

local function cropColour(value, width, fill)
  value = tostring(value or "")
  fill = tostring(fill or "0")
  if #value > width then return string.sub(value, 1, width) end
  if #value < width then return value .. string.rep(fill, width - #value) end
  return value
end

local function renderFrame(targetId, frame, control, status)
  local target = term.current()
  local width, height = target.getSize()

  target.setBackgroundColor(colors.black)
  target.setTextColor(colors.white)
  target.clear()

  local mode = control and "CONTROLE" or "OBSERVATION"
  local title = "MALCRAFT #" .. tostring(targetId) .. " | " .. mode
  target.setCursorPos(1, 1)
  target.setBackgroundColor(control and colors.red or colors.gray)
  target.setTextColor(colors.white)
  target.write(crop(title, width))

  if frame and type(frame.lines) == "table" then
    local rows = math.min(tonumber(frame.height) or #frame.lines, math.max(0, height - 2))

    for y = 1, rows do
      local row = frame.lines[y] or {}
      local text = crop(row.text, width)

      target.setCursorPos(1, y + 1)

      if target.isColor and target.isColor()
        and type(row.foreground) == "string"
        and type(row.background) == "string" then

        local fg = cropColour(row.foreground, width, "0")
        local bg = cropColour(row.background, width, "f")
        local ok = pcall(target.blit, text, fg, bg)
        if not ok then
          target.setBackgroundColor(colors.black)
          target.setTextColor(colors.white)
          target.write(text)
        end
      else
        target.setBackgroundColor(colors.black)
        target.setTextColor(colors.white)
        target.write(text)
      end
    end
  else
    target.setCursorPos(1, 3)
    target.setBackgroundColor(colors.black)
    target.setTextColor(colors.orange)
    target.write(crop(status or "En attente de l'ecran distant...", width))
  end

  target.setCursorPos(1, height)
  target.setBackgroundColor(colors.gray)
  target.setTextColor(colors.white)
  target.write(crop("ESC retour | F1 mode | F2 reboot | F3 arret | F4 crash", width))

  if frame
    and control
    and frame.cursor_blink
    and tonumber(frame.cursor_x)
    and tonumber(frame.cursor_y)
    and frame.cursor_y + 1 < height then

    target.setCursorPos(
      math.max(1, math.min(width, frame.cursor_x)),
      math.max(2, math.min(height - 1, frame.cursor_y + 1))
    )
    pcall(target.setCursorBlink, true)
  else
    pcall(target.setCursorBlink, false)
  end
end

local function remoteInput(targetId, eventName, ...)
  sendCommand(targetId, "input", {
    event = eventName,
    args = {...}
  })
end

function RemoteDesktop.run(service, targetId)
  targetId = tonumber(targetId)
  if not targetId then return false, "ID cible invalide." end

  local snapshot, err = service:ghostRemote(targetId, "screen_snapshot")
  if not snapshot then
    return false, err or "Ecran Malcraft indisponible."
  end

  local subscribed, subErr = service:ghostRemote(targetId, "screen_subscribe")
  if not subscribed then
    return false, subErr or "Impossible d'ouvrir le flux Malcraft."
  end

  local control = false
  local frame = snapshot
  local lastFrameAt = os.clock()
  local keepalive = os.startTimer(5)
  local watchdog = os.startTimer(1)

  renderFrame(targetId, frame, control)

  local running = true
  while running do
    local event, a, b, c, d, e = os.pullEventRaw()

    if event == "rednet_message"
      and tonumber(a) == targetId
      and c == PROTOCOL
      and type(b) == "table"
      and b.magic == "GHOSTLINK_GAMEPLAY"
      and b.type == "SCREEN_FRAME" then

      frame = b.payload
      lastFrameAt = os.clock()
      renderFrame(targetId, frame, control)

    elseif event == "timer" and a == keepalive then
      sendCommand(targetId, "screen_keepalive")
      keepalive = os.startTimer(5)

    elseif event == "timer" and a == watchdog then
      if os.clock() - lastFrameAt > 3 then
        renderFrame(targetId, frame, control, "Cible hors ligne / flux interrompu")
      end
      watchdog = os.startTimer(1)

    elseif event == "key" then
      if a == keys.escape then
        running = false

      elseif a == keys.f1 then
        control = not control
        renderFrame(targetId, frame, control)

      elseif a == keys.f2 then
        sendCommand(targetId, "reboot")

      elseif a == keys.f3 then
        sendCommand(targetId, "shutdown")

      elseif a == keys.f4 then
        sendCommand(targetId, "crash")

      elseif control then
        remoteInput(targetId, "key", a, b == true)
      end

    elseif event == "key_up" and control then
      remoteInput(targetId, "key_up", a)

    elseif event == "char" and control then
      remoteInput(targetId, "char", a)

    elseif event == "paste" and control then
      remoteInput(targetId, "paste", a)

    elseif event == "mouse_click" and control then
      if c and c >= 2 then
        remoteInput(targetId, "mouse_click", a, b, c - 1)
      end

    elseif event == "mouse_up" and control then
      if c and c >= 2 then
        remoteInput(targetId, "mouse_up", a, b, c - 1)
      end

    elseif event == "mouse_drag" and control then
      if c and c >= 2 then
        remoteInput(targetId, "mouse_drag", a, b, c - 1)
      end

    elseif event == "mouse_scroll" and control then
      if c and c >= 2 then
        remoteInput(targetId, "mouse_scroll", a, b, c - 1)
      end

    elseif event == "term_resize" then
      renderFrame(targetId, frame, control)

    elseif event == "terminate" then
      running = false
    end
  end

  sendCommand(targetId, "screen_unsubscribe")
  pcall(term.setCursorBlink, false)
  return true
end

return RemoteDesktop
