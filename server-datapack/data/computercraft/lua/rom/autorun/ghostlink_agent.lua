-- GhostLink gameplay agent for CC:Tweaked / Astralium.
-- Minecraft-only simulation: this code only uses ComputerCraft APIs and never
-- touches the host OS, external machines, or networks outside the game.
--
-- The ROM agent exists on every CC computer through the server datapack.
-- Whether a computer is "infected" is a gameplay state held by the AstralNet MER.

local PROTOCOL = "astralnet.ghostlink.v1"
local HOST = "MER-GHOST"
local CHANNEL = 55124
local CHECK_SECONDS = 8

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

if not openWireless() then
  return
end

refreshState()
local timer = os.startTimer(CHECK_SECONDS)

while true do
  local event, a, message, protocol = os.pullEvent()

  if event == "timer" and a == timer then
    refreshState()
    timer = os.startTimer(CHECK_SECONDS)

  elseif event == "disk" or event == "disk_eject" or event == "peripheral"
    or event == "peripheral_detach" then
    refreshState()

  elseif event == "rednet_message"
    and protocol == PROTOCOL
    and type(message) == "table"
    and message.magic == "GHOSTLINK_GAMEPLAY"
    and message.type == "COMMAND" then
    pcall(handleCommand, a, message)
  end
end
