-- Malcraft background gameplay daemon for CC:Tweaked / Astralium.
-- This is strictly an in-game ComputerCraft mechanic. It never accesses the
-- player's real operating system or any network outside Minecraft.

local argv = { ... }
local ONE_SHOT = argv[1] == "--oneshot"

local PROTOCOL = "astralnet.ghostlink.v1" -- kept for 0.9.x compatibility
local HOST = "MER-GHOST"
local CHANNEL = 55124
local CHECK_SECONDS = 10

local LOCAL_INFECTED = "astralium.malcraft.infected"
local LOCAL_SPREAD = "astralium.malcraft.spread"
local LOCAL_SOURCE = "astralium.malcraft.source"

local MARKER_DIR = ".malcraft"
local MARKER_FILE = "carrier.dat"
local MARKER_MAGIC = "ASTRALIUM_MALCRAFT_CARRIER_V1"

local infected = settings.get(LOCAL_INFECTED, false) == true
local spreadEnabled = settings.get(LOCAL_SPREAD, false) == true
local networkModemName = nil
local wirelessModemName = nil
local networkModem = nil
local wirelessModem = nil
local lastSpread = {}
local captureSurface = rawget(_ENV, "__malcraft_capture")
  or (rawget(_G, "__malcraft_capture"))
local screenSubscribers = {}

local function policy()
  local ok, value = pcall(require, "computer_link_policy")
  if ok and type(value) == "table" then return value end
  return nil
end

local function isOperator(id)
  local p = policy()
  return p
    and type(p.hack_operator_ids) == "table"
    and p.hack_operator_ids[tonumber(id)] == true
end

local function isImmune(id)
  local p = policy()
  if not p then return false end

  id = tonumber(id)
  if isOperator(id) then return true end

  return type(p.ghostlink_immune_ids) == "table"
    and p.ghostlink_immune_ids[id] == true
end

local function saveSettings()
  pcall(settings.save)
end

local function setLocalState(value, spread, source)
  if isImmune(os.getComputerID()) then
    value = false
    spread = false
    source = nil
  end

  infected = value == true
  spreadEnabled = infected and spread == true

  settings.set(LOCAL_INFECTED, infected)
  settings.set(LOCAL_SPREAD, spreadEnabled)

  if source and source ~= "" then
    settings.set(LOCAL_SOURCE, tostring(source))
  else
    settings.unset(LOCAL_SOURCE)
  end

  saveSettings()
end

local function hasPeripheralType(name, wanted)
  local types = {peripheral.getType(name)}
  for _, value in ipairs(types) do
    if value == wanted then return true end
  end
  return false
end

local function findModems()
  networkModemName = nil
  wirelessModemName = nil
  networkModem = nil
  wirelessModem = nil

  local fallback = nil

  for _, name in ipairs(peripheral.getNames()) do
    if hasPeripheralType(name, "modem") then
      local modem = peripheral.wrap(name)
      local okWireless, wireless = pcall(modem.isWireless)

      if okWireless and wireless then
        wirelessModemName = wirelessModemName or name
        networkModemName = networkModemName or name
      elseif not fallback then
        fallback = name
      end
    end
  end

  networkModemName = networkModemName or fallback

  if networkModemName then
    networkModem = peripheral.wrap(networkModemName)
    if not rednet.isOpen(networkModemName) then
      pcall(rednet.open, networkModemName)
    end
  end

  if wirelessModemName then
    wirelessModem = peripheral.wrap(wirelessModemName)
    if not rednet.isOpen(wirelessModemName) then
      pcall(rednet.open, wirelessModemName)
    end
    if wirelessModem and not wirelessModem.isOpen(CHANNEL) then
      pcall(wirelessModem.open, CHANNEL)
    end
  end
end

local function merId()
  if not networkModemName then return nil end
  return rednet.lookup(PROTOCOL, HOST)
end

local function request(kind, payload, timeout)
  local server = merId()
  if not server then return nil end

  local requestId = tostring(os.epoch and os.epoch("utc") or os.time())
    .. ":" .. tostring(math.random(100000, 999999))

  rednet.send(server, {
    magic = "GHOSTLINK_GAMEPLAY",
    type = kind,
    request_id = requestId,
    computer_id = os.getComputerID(),
    payload = payload or {}
  }, PROTOCOL)

  local timer = os.startTimer(timeout or 1.5)

  while true do
    local event, a, message, protocol = os.pullEvent()

    if event == "timer" and a == timer then
      return nil
    end

    if event == "rednet_message"
      and tonumber(a) == tonumber(server)
      and protocol == PROTOCOL
      and type(message) == "table"
      and message.magic == "GHOSTLINK_GAMEPLAY"
      and message.reply_to == requestId then
      return message
    end
  end
end

local function drives()
  local out = {}

  for _, name in ipairs(peripheral.getNames()) do
    if hasPeripheralType(name, "drive") and disk.isPresent(name) then
      out[#out + 1] = {
        name = name,
        id = disk.getID(name),
        has_data = disk.hasData(name),
        mount = disk.hasData(name) and disk.getMountPath(name) or nil,
        label = disk.getLabel(name)
      }
    end
  end

  return out
end

local function diskIds()
  local out = {}
  for _, drive in ipairs(drives()) do
    if drive.id then out[#out + 1] = drive.id end
  end
  return out
end

local function markerPath(mount)
  return fs.combine(fs.combine(mount, MARKER_DIR), MARKER_FILE)
end

local function diskHasMarker(drive)
  if not drive or not drive.has_data or not drive.mount then return false end
  local path = markerPath(drive.mount)
  if not fs.exists(path) or fs.isDir(path) then return false end

  local file = fs.open(path, "r")
  if not file then return false end
  local value = file.readAll()
  file.close()

  return tostring(value or ""):find(MARKER_MAGIC, 1, true) ~= nil
end

local function writeMarker(drive)
  if not drive or not drive.has_data or not drive.mount then
    return false
  end

  local dir = fs.combine(drive.mount, MARKER_DIR)
  if not fs.exists(dir) then
    local ok = pcall(fs.makeDir, dir)
    if not ok then return false end
  end

  local file = fs.open(markerPath(drive.mount), "w")
  if not file then return false end

  file.writeLine(MARKER_MAGIC)
  file.writeLine("disk=" .. tostring(drive.id or "unknown"))
  file.writeLine("source=" .. tostring(os.getComputerID()))
  file.close()
  return true
end

local function carrierPresent()
  for _, drive in ipairs(drives()) do
    if diskHasMarker(drive) then
      return true, drive
    end
  end
  return false, nil
end

local function localCarrierInfection()
  if isImmune(os.getComputerID()) then
    if infected or spreadEnabled then setLocalState(false, false, nil) end
    return false
  end

  local present, drive = carrierPresent()
  if present then
    setLocalState(true, true, "disk:" .. tostring(drive.id or "?"))
    return true
  end

  return false
end

local function propagationSettings()
  local p = policy() or {}
  return {
    proximity = p.ghostlink_proximity_spread == true,
    operator_emitter = p.malcraft_operator_proximity_emitter ~= false,
    auto_disks = p.malcraft_auto_infect_disks ~= false,
    distance = tonumber(p.ghostlink_proximity_distance) or 2.5,
    interval = math.max(2, tonumber(p.ghostlink_beacon_seconds) or 5),
    cooldown = math.max(5, tonumber(p.ghostlink_spread_cooldown_seconds) or 15)
  }
end

local function canSpreadFromHere()
  local cfg = propagationSettings()
  if isOperator(os.getComputerID()) then
    return cfg.operator_emitter == true
  end
  return infected and spreadEnabled
end

local function infectConnectedDisks()
  local cfg = propagationSettings()
  if not cfg.auto_disks or not (infected and spreadEnabled) then return end

  for _, drive in ipairs(drives()) do
    if drive.has_data and writeMarker(drive) and drive.id then
      pcall(request, "INFECT_DISK", {disk_id=drive.id}, 0.8)
    end
  end
end

local function syncState()
  if isImmune(os.getComputerID()) then
    setLocalState(false, false, nil)
  else
    localCarrierInfection()
  end

  if not networkModemName then return end

  local reply = request("STATE", {
    disk_ids = diskIds(),
    local_infected = infected,
    local_spread = spreadEnabled,
    local_source = settings.get(LOCAL_SOURCE),
    carrier_present = carrierPresent(),
    label = os.getComputerLabel()
  }, 1.2)

  if reply and type(reply.payload) == "table" then
    local payload = reply.payload
    setLocalState(
      payload.infected == true,
      payload.spread == true,
      payload.infected and (settings.get(LOCAL_SOURCE) or "mer") or nil
    )
  end

  if infected and spreadEnabled then
    infectConnectedDisks()
  end
end

local function currentMs()
  if os.epoch then
    local ok, value = pcall(os.epoch, "utc")
    if ok then return value end
  end
  return math.floor(os.clock() * 1000)
end

local function screenFrame()
  local surface = captureSurface

  if not surface
    or type(surface.getSize) ~= "function"
    or type(surface.getLine) ~= "function" then
    return nil, "Capture d'ecran indisponible sur ce Computer."
  end

  local width, height = surface.getSize()
  local lines = {}

  for y = 1, height do
    local text, foreground, background = surface.getLine(y)
    lines[#lines + 1] = {
      text = text,
      foreground = foreground,
      background = background
    }
  end

  local cursorX, cursorY = surface.getCursorPos()
  local cursorBlink = surface.getCursorBlink and surface.getCursorBlink() or false

  return {
    width = width,
    height = height,
    lines = lines,
    cursor_x = cursorX,
    cursor_y = cursorY,
    cursor_blink = cursorBlink == true
  }
end

local function countSubscribers()
  local count = 0
  for _ in pairs(screenSubscribers) do count = count + 1 end
  return count
end

local function sendScreenFrames()
  if countSubscribers() == 0 or not networkModemName then return end

  local frame = screenFrame()
  if not frame then return end

  local now = currentMs()

  for targetId, expiry in pairs(screenSubscribers) do
    if expiry < now then
      screenSubscribers[targetId] = nil
    elseif isOperator(targetId) then
      rednet.send(targetId, {
        magic = "GHOSTLINK_GAMEPLAY",
        type = "SCREEN_FRAME",
        source_id = os.getComputerID(),
        payload = frame
      }, PROTOCOL)
    else
      screenSubscribers[targetId] = nil
    end
  end
end

local function inventoryScan()
  local inventories = {}

  for _, name in ipairs(peripheral.getNames()) do
    local methods = peripheral.getMethods(name) or {}
    local hasList = false

    for _, method in ipairs(methods) do
      if method == "list" then
        hasList = true
        break
      end
    end

    if hasList then
      local ok, items = pcall(peripheral.call, name, "list")
      if ok and type(items) == "table" then
        inventories[#inventories + 1] = {
          name = name,
          types = {peripheral.getType(name)},
          items = items
        }
      end
    end
  end

  return inventories
end

local function nearbyComputers()
  local out = {}

  for _, name in ipairs(peripheral.getNames()) do
    local types = {peripheral.getType(name)}
    local computerLike = false

    for _, kind in ipairs(types) do
      if kind == "computer" or kind == "turtle" then
        computerLike = true
        break
      end
    end

    if computerLike then
      local function call(method)
        local ok, value = pcall(peripheral.call, name, method)
        return ok and value or nil
      end

      out[#out + 1] = {
        name = name,
        id = call("getID"),
        label = call("getLabel"),
        on = call("isOn") == true,
        types = types
      }
    end
  end

  return out
end

local function powerNearby(argument)
  local name = tostring(argument.name or "")
  local action = string.lower(tostring(argument.action or ""))

  if name == "" or not peripheral.isPresent(name) then
    return nil, "Computer peripherique introuvable."
  end

  local allowed = {
    on = "turnOn",
    turnon = "turnOn",
    reboot = "reboot",
    shutdown = "shutdown",
    off = "shutdown"
  }

  local method = allowed[action]
  if not method then return nil, "Action d'alimentation invalide." end

  local ok, err = pcall(peripheral.call, name, method)
  if not ok then return nil, tostring(err) end

  return {
    name = name,
    action = action
  }
end

local function queueRemoteInput(argument)
  local eventName = tostring(argument.event or "")
  local allowed = {
    char = true,
    paste = true,
    key = true,
    key_up = true,
    mouse_click = true,
    mouse_up = true,
    mouse_drag = true,
    mouse_scroll = true
  }

  if not allowed[eventName] then
    return nil, "Evenement distant refuse."
  end

  local args = type(argument.args) == "table" and argument.args or {}
  os.queueEvent(eventName, table.unpack(args))
  return {queued=true}
end

local function safeValue(value, depth)
  depth = depth or 0
  local kind = type(value)

  if kind == "nil" or kind == "boolean" or kind == "number" or kind == "string" then
    return value
  end

  if kind ~= "table" or depth >= 2 then return tostring(value) end

  local out, count = {}, 0
  for key, child in pairs(value) do
    count = count + 1
    if count > 48 then break end
    out[tostring(key)] = safeValue(child, depth + 1)
  end
  return out
end

local function devices()
  local out = {}

  for _, name in ipairs(peripheral.getNames()) do
    local methods = peripheral.getMethods(name) or {}
    table.sort(methods)

    out[#out + 1] = {
      name = name,
      types = {peripheral.getType(name)},
      methods = methods
    }
  end

  return out
end

local function redstoneInfo()
  local out = {}

  for _, side in ipairs(redstone.getSides()) do
    out[#out + 1] = {
      side = side,
      input = redstone.getInput(side),
      output = redstone.getOutput(side),
      analog_input = redstone.getAnalogInput and redstone.getAnalogInput(side) or nil,
      analog_output = redstone.getAnalogOutput and redstone.getAnalogOutput(side) or nil
    }
  end

  return out
end

local function setRedstone(payload)
  local side = tostring(payload.side or "")
  local value = payload.value
  local valid = false

  for _, candidate in ipairs(redstone.getSides()) do
    if candidate == side then valid = true break end
  end

  if not valid then return nil, "Face redstone invalide." end

  local numeric = tonumber(value)

  if numeric and redstone.setAnalogOutput then
    redstone.setAnalogOutput(side, math.max(0, math.min(15, math.floor(numeric))))
  else
    local on = value == true
      or tostring(value) == "1"
      or string.lower(tostring(value)) == "on"
      or string.lower(tostring(value)) == "true"

    redstone.setOutput(side, on)
  end

  return {
    side = side,
    output = redstone.getOutput(side),
    analog_output = redstone.getAnalogOutput and redstone.getAnalogOutput(side) or nil
  }
end

local function allowedMethod(method)
  method = string.lower(tostring(method or ""))
  if method == "" then return false end

  local exact = {
    ["write"] = true,
    ["newpage"] = true,
    ["endpage"] = true
  }
  if exact[method] then return true end

  local prefixes = {
    "get", "is", "has", "list", "read",
    "set", "enable", "disable", "activate", "deactivate",
    "open", "close", "start", "stop", "fire", "shoot",
    "assemble", "disassemble", "move", "rotate", "turn",
    "eject", "play"
  }

  for _, prefix in ipairs(prefixes) do
    if string.sub(method, 1, #prefix) == prefix then return true end
  end

  return false
end

local function callDevice(payload)
  local name = tostring(payload.name or "")
  local method = tostring(payload.method or "")

  if name == "" or not peripheral.isPresent(name) then
    return nil, "Peripherique introuvable."
  end
  if not allowedMethod(method) then
    return nil, "Methode non autorisee."
  end

  local exists = false
  for _, candidate in ipairs(peripheral.getMethods(name) or {}) do
    if candidate == method then exists = true break end
  end
  if not exists then return nil, "Methode indisponible." end

  local args = type(payload.args) == "table" and payload.args or {}
  local result = table.pack(pcall(peripheral.call, name, method, table.unpack(args)))

  if not result[1] then return nil, tostring(result[2]) end

  local values = {}
  for i = 2, result.n do
    values[#values + 1] = safeValue(result[i])
  end

  return {name=name, method=method, results=values}
end

local function reply(target, requestMessage, ok, payload, err)
  if not networkModemName then return end

  rednet.send(target, {
    magic = "GHOSTLINK_GAMEPLAY",
    type = "COMMAND_RESULT",
    reply_to = requestMessage.request_id,
    ok = ok == true,
    payload = payload or {},
    error = err
  }, PROTOCOL)
end

local function handleCommand(sender, message)
  if not infected or not isOperator(sender) then return end
  if tonumber(message.source_id) ~= tonumber(sender) then return end

  local payload = message.payload or {}
  local action = string.lower(tostring(payload.action or ""))
  local argument = type(payload.argument) == "table" and payload.argument or {}

  if action == "status" then
    reply(sender, message, true, {
      infected = infected,
      spread = spreadEnabled,
      computer_id = os.getComputerID(),
      label = os.getComputerLabel()
    })

  elseif action == "devices" then
    reply(sender, message, true, {devices=devices()})

  elseif action == "device_call" then
    local data, err = callDevice(argument)
    reply(sender, message, data ~= nil, data, err)

  elseif action == "redstone" then
    reply(sender, message, true, {sides=redstoneInfo()})

  elseif action == "redstone_set" then
    local data, err = setRedstone(argument)
    reply(sender, message, data ~= nil, data, err)

  elseif action == "drives" then
    reply(sender, message, true, {disk_ids=diskIds()})

  elseif action == "spread" then
    if not spreadEnabled then
      reply(sender, message, false, nil, "Propagation desactivee.")
      return
    end

    local targetId = tonumber(argument.target_id)
    if not targetId then
      reply(sender, message, false, nil, "ID cible invalide.")
      return
    end

    local response = request("SPREAD_TO", {target_id=targetId}, 1.0)
    reply(sender, message, response ~= nil, response and response.payload or nil,
      response and response.error or "MER indisponible.")

  elseif action == "infect_disk" then
    local diskId = tonumber(argument.disk_id)
    if not diskId then
      reply(sender, message, false, nil, "Disk ID invalide.")
      return
    end

    local response = request("INFECT_DISK", {disk_id=diskId}, 1.0)
    reply(sender, message, response ~= nil, response and response.payload or nil,
      response and response.error or "MER indisponible.")

  elseif action == "screen_snapshot" then
    local frame, err = screenFrame()
    reply(sender, message, frame ~= nil, frame, err)

  elseif action == "screen_subscribe" then
    screenSubscribers[sender] = (currentMs()) + 15000
    reply(sender, message, true, {subscribed=true})

  elseif action == "screen_keepalive" then
    screenSubscribers[sender] = (currentMs()) + 15000
    reply(sender, message, true, {subscribed=true})

  elseif action == "screen_unsubscribe" then
    screenSubscribers[sender] = nil
    reply(sender, message, true, {subscribed=false})

  elseif action == "input" then
    local data, err = queueRemoteInput(argument)
    reply(sender, message, data ~= nil, data, err)

  elseif action == "inventory_scan" then
    reply(sender, message, true, {inventories=inventoryScan()})

  elseif action == "nearby_computers" then
    reply(sender, message, true, {computers=nearbyComputers()})

  elseif action == "nearby_power" then
    local data, err = powerNearby(argument)
    reply(sender, message, data ~= nil, data, err)

  elseif action == "reboot" then
    reply(sender, message, true, {action="reboot"})
    sleep(0.1)
    os.reboot()

  elseif action == "shutdown" then
    reply(sender, message, true, {action="shutdown"})
    sleep(0.1)
    os.shutdown()

  elseif action == "crash" then
    reply(sender, message, true, {action="crash"})
    local native = term.native()
    native.setBackgroundColor(colors.black)
    native.setTextColor(colors.red)
    native.clear()
    native.setCursorPos(1, 1)
    native.write("MALCRAFT SYSTEM CRASH")
    sleep(1.5)
    os.reboot()

  else
    reply(sender, message, false, nil, "Commande Malcraft inconnue.")
  end
end

local function nowMs()
  if os.epoch then return os.epoch("utc") end
  return math.floor(os.clock() * 1000)
end

local function sendBeacon()
  if not wirelessModem then return end

  wirelessModem.transmit(CHANNEL, CHANNEL, {
    magic = "GHOSTLINK_GAMEPLAY",
    type = "BEACON",
    computer_id = os.getComputerID()
  })
end

local function handleBeacon(message, distance)
  local cfg = propagationSettings()

  if not cfg.proximity or not canSpreadFromHere() then return end
  if type(distance) ~= "number" or distance > cfg.distance then return end

  if type(message) ~= "table"
    or message.magic ~= "GHOSTLINK_GAMEPLAY"
    or message.type ~= "BEACON" then
    return
  end

  local targetId = tonumber(message.computer_id)
  if not targetId or targetId == os.getComputerID() or isImmune(targetId) then
    return
  end

  local now = nowMs()
  local last = lastSpread[targetId] or 0

  if now - last < cfg.cooldown * 1000 then return end
  lastSpread[targetId] = now

  pcall(request, "SPREAD_TO", {target_id=targetId}, 1.0)
end

findModems()

if isImmune(os.getComputerID()) then
  setLocalState(false, false, nil)
else
  localCarrierInfection()
end

syncState()
sendBeacon()

-- Standard Computers do not have multishell. The autorun launcher executes
-- this one-shot pass at boot so a contaminated disk can infect a Computer
-- which has never installed LinkOS. Advanced Computers then keep the daemon
-- alive in the background for hot-plug and proximity propagation.
if ONE_SHOT then
  return
end

local stateTimer = os.startTimer(CHECK_SECONDS)
local beaconTimer = os.startTimer(propagationSettings().interval)
local screenTimer = os.startTimer(0.25)

while true do
  local event, a, b, c, d, e = os.pullEvent()

  if event == "timer" and a == stateTimer then
    findModems()
    syncState()
    stateTimer = os.startTimer(CHECK_SECONDS)

  elseif event == "timer" and a == screenTimer then
    sendScreenFrames()
    screenTimer = os.startTimer(0.25)

  elseif event == "timer" and a == beaconTimer then
    sendBeacon()
    beaconTimer = os.startTimer(propagationSettings().interval)

  elseif event == "disk" or event == "peripheral" then
    findModems()
    localCarrierInfection()
    syncState()
    infectConnectedDisks()

  elseif event == "disk_eject" or event == "peripheral_detach" then
    findModems()
    syncState()

  elseif event == "modem_message" then
    local channel = b
    local message = d
    local distance = e

    if channel == CHANNEL then
      pcall(handleBeacon, message, distance)
    end

  elseif event == "rednet_message" then
    local sender = a
    local message = b
    local protocol = c

    if protocol == PROTOCOL
      and type(message) == "table"
      and message.magic == "GHOSTLINK_GAMEPLAY" then

      if message.type == "STATE_PUSH" then
        local server = merId()
        if server and tonumber(sender) == tonumber(server) then
          local payload = message.payload or {}

          setLocalState(
            payload.infected == true,
            payload.spread == true,
            payload.infected and (settings.get(LOCAL_SOURCE) or "mer") or nil
          )

          if infected and spreadEnabled then
            infectConnectedDisks()
          end
        end

      elseif message.type == "COMMAND" then
        pcall(handleCommand, sender, message)
      end
    end
  end
end
