-- GhostLink background gameplay daemon for CC:Tweaked / Astralium.
-- Minecraft-only simulation. Runs in a hidden multishell tab on Advanced Computers.

local PROTOCOL = "astralnet.ghostlink.v1"
local HOST = "MER-GHOST"
local CHANNEL = 55124
local CHECK_SECONDS = 60

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

local function openWireless()
  for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "modem" then
      local modem = peripheral.wrap(name)
      local okWireless, wireless = pcall(modem.isWireless)
      if okWireless and wireless then
        if not rednet.isOpen(name) then pcall(rednet.open, name) end
        if not modem.isOpen(CHANNEL) then pcall(modem.open, CHANNEL) end
        return name
      end
    end
  end
  return nil
end

local function merId()
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

local function diskIds()
  local out = {}
  for _, side in ipairs(peripheral.getNames()) do
    if peripheral.getType(side) == "drive" and disk.isPresent(side) then
      local id = disk.getID(side)
      if id then out[#out + 1] = id end
    end
  end
  return out
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
  for i = 2, result.n do values[#values + 1] = safeValue(result[i]) end
  return {name=name, method=method, results=values}
end

local infected = false
local spreadEnabled = false

local function refreshState()
  if isImmune(os.getComputerID()) then
    infected = false
    spreadEnabled = false
    return
  end

  local reply = request("STATE", {disk_ids=diskIds()})
  if reply and type(reply.payload) == "table" then
    infected = reply.payload.infected == true
    spreadEnabled = reply.payload.spread == true
  end
end

local function reply(target, request, ok, payload, err)
  rednet.send(target, {
    magic = "GHOSTLINK_GAMEPLAY",
    type = "COMMAND_RESULT",
    reply_to = request.request_id,
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

    local response = request("SPREAD_TO", {target_id=targetId})
    reply(sender, message, response ~= nil, response and response.payload or nil,
      response and response.error or "MER indisponible.")

  elseif action == "infect_disk" then
    local diskId = tonumber(argument.disk_id)
    if not diskId then
      reply(sender, message, false, nil, "Disk ID invalide.")
      return
    end

    local response = request("INFECT_DISK", {disk_id=diskId})
    reply(sender, message, response ~= nil, response and response.payload or nil,
      response and response.error or "MER indisponible.")

  else
    reply(sender, message, false, nil, "Commande GhostLink inconnue.")
  end
end

local modemName = openWireless()
if not modemName then
  return
end

local modem = peripheral.wrap(modemName)
local lastSpread = {}

local function nowMs()
  if os.epoch then return os.epoch("utc") end
  return math.floor(os.clock() * 1000)
end

local function proximitySettings()
  local p = policy() or {}
  return {
    enabled = p.ghostlink_proximity_spread == true,
    distance = tonumber(p.ghostlink_proximity_distance) or 2.5,
    interval = math.max(2, tonumber(p.ghostlink_beacon_seconds) or 5),
    cooldown = math.max(5, tonumber(p.ghostlink_spread_cooldown_seconds) or 15)
  }
end

local function sendBeacon()
  if not modem then return end
  modem.transmit(CHANNEL, CHANNEL, {
    magic = "GHOSTLINK_GAMEPLAY",
    type = "BEACON",
    computer_id = os.getComputerID()
  })
end

local function handleBeacon(message, distance)
  local cfg = proximitySettings()
  if not cfg.enabled or not infected or not spreadEnabled then return end
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

refreshState()
sendBeacon()

local stateTimer = os.startTimer(CHECK_SECONDS)
local beaconTimer = os.startTimer(proximitySettings().interval)

while true do
  local event, a, b, c, d, e = os.pullEvent()

  if event == "timer" and a == stateTimer then
    refreshState()
    stateTimer = os.startTimer(CHECK_SECONDS)

  elseif event == "timer" and a == beaconTimer then
    sendBeacon()
    beaconTimer = os.startTimer(proximitySettings().interval)

  elseif event == "disk" or event == "disk_eject" or event == "peripheral"
    or event == "peripheral_detach" then
    refreshState()

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
          infected = payload.infected == true and not isImmune(os.getComputerID())
          spreadEnabled = infected and payload.spread == true
        end

      elseif message.type == "COMMAND" then
        pcall(handleCommand, sender, message)
      end
    end
  end
end
