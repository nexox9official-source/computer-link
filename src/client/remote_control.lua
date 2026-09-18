local config = dofile("/computer-link/src/common/config.lua")
local util = dofile("/computer-link/src/common/util.lua")
local network = dofile("/computer-link/src/common/network.lua")
local hackedState = dofile("/computer-link/src/client/system_state.lua")
local security = dofile("/computer-link/src/client/security.lua")

local hack = {}

local pending = {}
local sessions = {}

local serverPolicy = nil
do
  local ok, policy = pcall(require, "computer_link_policy")
  if ok and type(policy) == "table" then
    serverPolicy = policy
  end
end

local function isOperator(computerId)
  computerId = tonumber(computerId)
  if not computerId then return false end

  -- PC #0 is the built-in Astralium LinkSec workstation.
  -- os.getComputerID()/rednet sender IDs are provided by ComputerCraft, so a
  -- different client cannot gain this identity by editing local Lua files.
  if computerId == 0 then
    return true
  end

  -- The read-only server ROM policy may authorize additional operator IDs later.
  if serverPolicy and type(serverPolicy.hack_operator_ids) == "table" then
    return serverPolicy.hack_operator_ids[computerId] == true
  end

  return false
end

function hack.isOperator(computerId)
  return isOperator(computerId or os.getComputerID())
end

local function requireOperator()
  if not isOperator(os.getComputerID()) then
    return false, "ACCES REFUSE: ce PC n'est pas autorise a utiliser le module d'intrusion."
  end
  return true
end

local function hash(value)
  local h = 7
  for i = 1, #value do
    h = (h * 131 + string.byte(value, i)) % 2147483647
  end
  return h
end

local function directTransmit(modemName, payload)
  peripheral.call(
    modemName,
    "transmit",
    config.HACK_CHANNEL,
    config.HACK_CHANNEL,
    payload
  )
end

local function hackPacket(kind, payload)
  return {
    magic = config.HACK_MAGIC,
    version = config.HACK_PROTOCOL_VERSION,
    type = kind,
    source_id = os.getComputerID(),
    payload = payload or {},
    sent_at = util.now()
  }
end

local function isHackPacket(value)
  return type(value) == "table"
    and value.magic == config.HACK_MAGIC
    and value.version == config.HACK_PROTOCOL_VERSION
    and type(value.type) == "string"
end

local function cleanPath(path)
  path = tostring(path or "/")
  local combined = fs.combine("", path)

  if combined == "" or combined == "." then
    return "/"
  end

  return "/" .. combined
end

local function isRomPath(path)
  path = cleanPath(path)
  return path == "/rom" or string.sub(path, 1, 5) == "/rom/"
end

local function listFiles(path)
  path = cleanPath(path)

  if isRomPath(path) then
    return nil, "ROM protegee."
  end

  if not fs.exists(path) then
    return nil, "Chemin introuvable."
  end

  if not fs.isDir(path) then
    return nil, "Ce chemin n'est pas un dossier."
  end

  local entries = fs.list(path)
  table.sort(entries)

  local result = {}
  for i = 1, math.min(#entries, config.HACK_MAX_LIST_ENTRIES) do
    local child = fs.combine(path, entries[i])
    result[#result + 1] = {
      name = entries[i],
      dir = fs.isDir(child),
      size = fs.isDir(child) and 0 or fs.getSize(child)
    }
  end

  return result
end

local function readTextFile(path)
  path = cleanPath(path)

  if isRomPath(path) then
    return nil, "ROM protegee."
  end

  if not fs.exists(path) then
    return nil, "Fichier introuvable."
  end

  if fs.isDir(path) then
    return nil, "C'est un dossier."
  end

  local file = fs.open(path, "r")
  if not file then
    return nil, "Lecture impossible."
  end

  local content = file.read(config.HACK_MAX_READ_BYTES)
  file.close()
  return content or ""
end

local function writeTextFile(path, content)
  path = cleanPath(path)
  content = tostring(content or "")

  if isRomPath(path) then
    return nil, "ROM protegee."
  end

  if #content > config.HACK_MAX_WRITE_BYTES then
    return nil, "Contenu trop long."
  end

  local dir = fs.getDir(path)
  if dir and dir ~= "" and not fs.exists(dir) then
    fs.makeDir(dir)
  end

  if fs.exists(path) and fs.isDir(path) then
    return nil, "La cible est un dossier."
  end

  local file = fs.open(path, "w")
  if not file then
    return nil, "Ecriture impossible."
  end

  file.write(content)
  file.close()
  return {
    path = path,
    bytes = #content
  }
end

local function deletePath(path)
  path = cleanPath(path)

  if path == "/" then
    return nil, "Suppression de la racine interdite."
  end

  if isRomPath(path) then
    return nil, "ROM protegee."
  end

  if not fs.exists(path) then
    return nil, "Chemin introuvable."
  end

  fs.delete(path)
  return { path = path }
end

local function serialiseValue(value, depth)
  depth = depth or 0
  local kind = type(value)

  if kind == "nil" or kind == "boolean" or kind == "number" or kind == "string" then
    return value
  end

  if kind ~= "table" or depth >= 3 then
    return tostring(value)
  end

  local out = {}
  local count = 0

  for key, child in pairs(value) do
    count = count + 1
    if count > 64 then break end
    out[tostring(key)] = serialiseValue(child, depth + 1)
  end

  return out
end

local function connectedDevices()
  local out = {}

  for _, name in ipairs(peripheral.getNames()) do
    local deviceTypes = {peripheral.getType(name)}
    local methods = peripheral.getMethods(name) or {}

    table.sort(methods)

    out[#out + 1] = {
      name = name,
      types = deviceTypes,
      methods = methods
    }
  end

  table.sort(out, function(a, b)
    return tostring(a.name) < tostring(b.name)
  end)

  return out
end

local function deviceDetails(name)
  name = tostring(name or "")

  if name == "" or not peripheral.isPresent(name) then
    return nil, "Peripherique introuvable."
  end

  local methods = peripheral.getMethods(name) or {}
  table.sort(methods)

  return {
    name = name,
    types = {peripheral.getType(name)},
    methods = methods
  }
end

local function methodAllowed(method)
  method = tostring(method or "")
  if method == "" then return false end

  local lower = string.lower(method)
  local prefixes = {
    "get", "is", "has", "list", "read",
    "set", "enable", "disable", "activate", "deactivate",
    "open", "close", "start", "stop", "fire", "shoot",
    "assemble", "disassemble", "move", "rotate", "turn",
    "eject", "play"
  }

  for _, prefix in ipairs(prefixes) do
    if string.sub(lower, 1, #prefix) == prefix then
      return true
    end
  end

  return false
end

local function callDevice(argument)
  local arg = type(argument) == "table" and argument or {}
  local name = tostring(arg.name or "")
  local method = tostring(arg.method or "")

  if name == "" or not peripheral.isPresent(name) then
    return nil, "Peripherique introuvable."
  end

  if not methodAllowed(method) then
    return nil, "Methode non autorisee par LinkSec."
  end

  local found = false
  for _, candidate in ipairs(peripheral.getMethods(name) or {}) do
    if candidate == method then
      found = true
      break
    end
  end

  if not found then
    return nil, "Methode indisponible."
  end

  local args = type(arg.args) == "table" and arg.args or {}
  local result = table.pack(pcall(peripheral.call, name, method, table.unpack(args)))

  if result[1] ~= true then
    return nil, tostring(result[2])
  end

  local values = {}
  for i = 2, result.n do
    values[#values + 1] = serialiseValue(result[i])
  end

  return {
    name = name,
    method = method,
    results = values
  }
end

local function redstoneState()
  local out = {}

  for _, side in ipairs(redstone.getSides()) do
    local row = {
      side = side,
      input = redstone.getInput(side),
      output = redstone.getOutput(side)
    }

    if redstone.getAnalogInput then
      row.analog_input = redstone.getAnalogInput(side)
    end

    if redstone.getAnalogOutput then
      row.analog_output = redstone.getAnalogOutput(side)
    end

    out[#out + 1] = row
  end

  return out
end

local function setRedstoneState(argument)
  local arg = type(argument) == "table" and argument or {}
  local side = tostring(arg.side or "")
  local value = arg.value
  local valid = false

  for _, candidate in ipairs(redstone.getSides()) do
    if candidate == side then
      valid = true
      break
    end
  end

  if not valid then
    return nil, "Face redstone invalide."
  end

  local numeric = tonumber(value)

  if numeric and redstone.setAnalogOutput then
    numeric = math.max(0, math.min(15, math.floor(numeric)))
    redstone.setAnalogOutput(side, numeric)
  else
    local enabled = value == true
      or tostring(value) == "1"
      or string.lower(tostring(value)) == "on"
      or string.lower(tostring(value)) == "true"

    redstone.setOutput(side, enabled)
  end

  return {
    side = side,
    output = redstone.getOutput(side),
    analog_output = redstone.getAnalogOutput and redstone.getAnalogOutput(side) or nil
  }
end

local function connectedDrives()
  local out = {}

  for _, name in ipairs(peripheral.getNames()) do
    local isDrive = false
    local types = {peripheral.getType(name)}

    for _, deviceType in ipairs(types) do
      if deviceType == "drive" then
        isDrive = true
        break
      end
    end

    if isDrive then
      out[#out + 1] = {
        name = name,
        present = disk.isPresent(name),
        has_data = disk.hasData(name),
        id = disk.isPresent(name) and disk.getID(name) or nil,
        label = disk.isPresent(name) and disk.getLabel(name) or nil,
        mount = disk.hasData(name) and disk.getMountPath(name) or nil
      }
    end
  end

  return out
end

local function sessionFor(sourceId, token)
  local session = sessions[tonumber(sourceId)]
  if not session then return nil end

  if session.expires_at < util.now() then
    sessions[tonumber(sourceId)] = nil
    return nil
  end

  if session.token ~= token then return nil end
  return session
end

local function sendHackResult(targetId, requestId, success, data, message)
  rednet.send(targetId, {
    magic = config.HACK_MAGIC,
    version = config.HACK_PROTOCOL_VERSION,
    type = "HACK_RESULT",
    source_id = os.getComputerID(),
    reply_to = requestId,
    success = success,
    data = data,
    message = message
  }, config.HACK_PROTOCOL)
end

function hack.openChannel(modemName)
  local modem = peripheral.wrap(modemName)
  if modem and not modem.isOpen(config.HACK_CHANNEL) then
    modem.open(config.HACK_CHANNEL)
  end
end

function hack.handleModem(modemName, channel, replyChannel, message, distance)
  if channel ~= config.HACK_CHANNEL or not isHackPacket(message) then
    return
  end

  local sourceId = tonumber(message.source_id)
  if not sourceId or sourceId == os.getComputerID() then
    return
  end

  -- Verifie cote cible le vrai Computer ID de l'attaquant. PC #0 est autorise
  -- nativement; les autres IDs doivent etre presents dans la politique serveur.
  if not isOperator(sourceId) then
    return
  end

  local payload = message.payload or {}
  local targetId = tonumber(payload.target_id)

  if message.type == "SCAN" then
    if type(distance) ~= "number" or distance > config.HACK_MAX_DISTANCE then
      return
    end

    directTransmit(modemName, hackPacket("SCAN_REPLY", {
      target_id = sourceId,
      scan_id = payload.scan_id,
      label = os.getComputerLabel(),
      security = config.HACK_DEFAULT_SECURITY
    }))
    return
  end

  if targetId ~= os.getComputerID() then
    return
  end

  if type(distance) ~= "number" or distance > config.HACK_MAX_DISTANCE then
    return
  end

  if message.type == "CHALLENGE_REQUEST" then
    local requestId = tostring(payload.request_id or "")
    local nonce = tostring(util.now())
      .. ":" .. tostring(math.random(100000, 999999))
      .. ":" .. tostring(sourceId)
    local difficulty = config.HACK_BASE_DIFFICULTY * config.HACK_DEFAULT_SECURITY

    pending[sourceId] = {
      request_id = requestId,
      nonce = nonce,
      difficulty = difficulty,
      expires_at = util.now() + config.HACK_CHALLENGE_SECONDS
    }

    directTransmit(modemName, hackPacket("CHALLENGE", {
      target_id = sourceId,
      request_id = requestId,
      nonce = nonce,
      difficulty = difficulty,
      security = config.HACK_DEFAULT_SECURITY
    }))
    return
  end

  if message.type == "HACK_PROOF" then
    local challenge = pending[sourceId]
    if not challenge then return end

    if challenge.expires_at < util.now() then
      pending[sourceId] = nil
      return
    end

    if tostring(payload.request_id or "") ~= challenge.request_id then
      return
    end

    local proof = tonumber(payload.proof)
    if not proof then return end

    local valid = hash(challenge.nonce .. ":" .. tostring(proof))
      % challenge.difficulty == 0
    pending[sourceId] = nil

    if not valid then
      rednet.send(sourceId, {
        magic = config.HACK_MAGIC,
        version = config.HACK_PROTOCOL_VERSION,
        type = "HACK_DENIED",
        source_id = os.getComputerID(),
        reply_to = challenge.request_id,
        message = "Exploit refuse."
      }, config.HACK_PROTOCOL)
      return
    end

    local token = tostring(hash(
      challenge.nonce
      .. ":" .. tostring(proof)
      .. ":" .. tostring(math.random(100000, 999999))
      .. ":" .. tostring(util.now())
    ))

    sessions[sourceId] = {
      token = token,
      expires_at = util.now() + config.HACK_SESSION_SECONDS,
      distance = distance
    }

    rednet.send(sourceId, {
      magic = config.HACK_MAGIC,
      version = config.HACK_PROTOCOL_VERSION,
      type = "HACK_GRANTED",
      source_id = os.getComputerID(),
      reply_to = challenge.request_id,
      token = token,
      expires_at = sessions[sourceId].expires_at
    }, config.HACK_PROTOCOL)
  end
end

function hack.handleRednet(senderId, message, protocol, storage)
  if protocol ~= config.HACK_PROTOCOL or not isHackPacket(message) then
    return false
  end

  if not isOperator(senderId) then
    return true
  end

  -- Refuse packets which claim another source ID. rednet senderId is supplied
  -- by ComputerCraft and is the identity used for authorization.
  if tonumber(message.source_id) ~= tonumber(senderId) then
    return true
  end

  if message.type ~= "HACK_COMMAND" then
    return false
  end

  local payload = message.payload or {}
  local session = sessionFor(senderId, payload.token)

  if not session then
    sendHackResult(
      senderId,
      message.request_id,
      false,
      nil,
      "Session pirate invalide ou expiree."
    )
    return true
  end

  local action = string.lower(tostring(payload.action or ""))
  local argument = payload.argument

  if action == "info" then
    local locked, lockData = hackedState.isLocked()
    sendHackResult(senderId, message.request_id, true, {
      computer_id = os.getComputerID(),
      label = os.getComputerLabel(),
      messages = storage.count(),
      free_space = fs.getFreeSpace("/"),
      locked = locked,
      locked_by = lockData and lockData.source_id or nil
    })

  elseif action == "conversations" then
    sendHackResult(senderId, message.request_id, true, {
      messages = storage.recent(config.HACK_DUMP_MESSAGES)
    })

  elseif action == "conversation_index" then
    sendHackResult(senderId, message.request_id, true, {
      conversations = storage.conversationIndex()
    })

  elseif action == "conversation" then
    local peerId = tonumber(argument)
    if not peerId then
      sendHackResult(senderId, message.request_id, false, nil, "ID conversation invalide.")
    else
      sendHackResult(senderId, message.request_id, true, {
        peer_id = peerId,
        messages = storage.conversation(peerId, config.HACK_DUMP_MESSAGES)
      })
    end

  elseif action == "devices" then
    sendHackResult(senderId, message.request_id, true, {
      devices = connectedDevices()
    })

  elseif action == "device_info" then
    local data, err = deviceDetails(argument)
    sendHackResult(senderId, message.request_id, data ~= nil, data, err)

  elseif action == "device_call" then
    local data, err = callDevice(argument)
    sendHackResult(senderId, message.request_id, data ~= nil, data, err)

  elseif action == "redstone" then
    sendHackResult(senderId, message.request_id, true, {
      sides = redstoneState()
    })

  elseif action == "redstone_set" then
    local data, err = setRedstoneState(argument)
    sendHackResult(senderId, message.request_id, data ~= nil, data, err)

  elseif action == "drives" then
    sendHackResult(senderId, message.request_id, true, {
      drives = connectedDrives()
    })

  elseif action == "authinfo" then
    local info = security.info()
    sendHackResult(senderId, message.request_id, true, {
      enabled = info.enabled,
      salt = info.salt,
      password_hash = info.password_hash,
      auto_lock_seconds = info.auto_lock_seconds
    })

  elseif action == "ls" then
    local entries, err = listFiles(argument or "/")
    sendHackResult(senderId, message.request_id, entries ~= nil, {
      path = cleanPath(argument or "/"),
      entries = entries
    }, err)

  elseif action == "cat" then
    local content, err = readTextFile(argument)
    sendHackResult(senderId, message.request_id, content ~= nil, {
      path = cleanPath(argument),
      content = content
    }, err)

  elseif action == "write" then
    local arg = type(argument) == "table" and argument or {}
    local result, err = writeTextFile(arg.path, arg.content)
    sendHackResult(senderId, message.request_id, result ~= nil, result, err)

  elseif action == "delete" then
    local result, err = deletePath(argument)
    sendHackResult(senderId, message.request_id, result ~= nil, result, err)

  elseif action == "label" then
    local label = tostring(argument or "")
    if label == "" then
      sendHackResult(senderId, message.request_id, false, nil, "Label vide.")
    else
      os.setComputerLabel(string.sub(label, 1, 32))
      sendHackResult(senderId, message.request_id, true, {
        label = os.getComputerLabel()
      })
      os.queueEvent("linkos_refresh")
    end

  elseif action == "message" then
    local flash = hackedState.flash(senderId, tostring(argument or ""))
    sendHackResult(senderId, message.request_id, true, {
      displayed = true,
      message = flash.message
    })

  elseif action == "lock" then
    local text = tostring(argument or "")
    if text == "" then
      text = "Your system is under remote control."
    end

    local data = hackedState.lock(senderId, text)
    sendHackResult(senderId, message.request_id, true, {
      locked = true,
      message = data.message
    })

  elseif action == "unlock" then
    hackedState.unlock()
    sendHackResult(senderId, message.request_id, true, {
      locked = false
    })

  elseif action == "reboot" then
    sendHackResult(senderId, message.request_id, true, {
      rebooting = true
    })
    sleep(0.35)
    os.reboot()

  elseif action == "crash" then
    util.writeAll(config.CRASH_FLAG, textutils.serialize({
      source_id = senderId,
      at = util.now()
    }))

    sendHackResult(senderId, message.request_id, true, {
      rebooting = true,
      recovery_seconds = config.CRASH_RECOVERY_SECONDS
    })

    sleep(0.4)
    os.reboot()

  else
    sendHackResult(
      senderId,
      message.request_id,
      false,
      nil,
      "Action distante inconnue."
    )
  end

  return true
end

function hack.scan(modemName, duration)
  local allowed, err = requireOperator()
  if not allowed then return nil, err end

  duration = tonumber(duration) or 2
  local scanId = util.requestId()
  local found = {}

  directTransmit(modemName, hackPacket("SCAN", {
    scan_id = scanId
  }))

  local timer = os.startTimer(duration)

  while true do
    local event, side, channel, replyChannel, message, distance = os.pullEvent()

    if event == "timer" and side == timer then
      break
    end

    if event == "modem_message"
      and channel == config.HACK_CHANNEL
      and isHackPacket(message)
      and message.type == "SCAN_REPLY"
      and tostring((message.payload or {}).scan_id or "") == scanId
      and tonumber((message.payload or {}).target_id) == os.getComputerID() then

      local id = tonumber(message.source_id)
      if id and id ~= os.getComputerID() then
        found[id] = {
          id = id,
          label = (message.payload or {}).label,
          security = (message.payload or {}).security,
          distance = distance
        }
      end
    end
  end

  local list = {}
  for _, entry in pairs(found) do
    list[#list + 1] = entry
  end

  table.sort(list, function(a, b)
    return (a.distance or 999999) < (b.distance or 999999)
  end)

  return list
end

function hack.attack(modemName, targetId)
  local allowed, err = requireOperator()
  if not allowed then return nil, err end

  targetId = tonumber(targetId)
  if not targetId then return nil, "ID PC invalide." end

  local requestId = util.requestId()

  directTransmit(modemName, hackPacket("CHALLENGE_REQUEST", {
    target_id = targetId,
    request_id = requestId
  }))

  local challenge
  local timer = os.startTimer(3)

  while true do
    local event, a, channel, replyChannel, message = os.pullEvent()

    if event == "timer" and a == timer then
      return nil, "PC cible hors de portee ou ne repond pas."
    end

    if event == "modem_message"
      and channel == config.HACK_CHANNEL
      and isHackPacket(message)
      and message.type == "CHALLENGE"
      and tonumber(message.source_id) == targetId
      and tostring((message.payload or {}).request_id or "") == requestId then

      challenge = message.payload
      break
    end
  end

  local difficulty = tonumber(challenge.difficulty) or config.HACK_BASE_DIFFICULTY
  local proof

  for candidate = 0, config.HACK_MAX_PROOF do
    if hash(tostring(challenge.nonce) .. ":" .. tostring(candidate))
      % difficulty == 0 then
      proof = candidate
      break
    end

    if candidate % 5000 == 0 then
      os.queueEvent("computer_link_yield")
      os.pullEvent("computer_link_yield")
    end
  end

  if not proof then
    return nil, "Aucun exploit trouve."
  end

  directTransmit(modemName, hackPacket("HACK_PROOF", {
    target_id = targetId,
    request_id = requestId,
    proof = proof
  }))

  local replyTimer = os.startTimer(3)

  while true do
    local event, a, message, protocol = os.pullEvent()

    if event == "timer" and a == replyTimer then
      return nil, "La cible n'a pas valide l'exploit."
    end

    if event == "rednet_message"
      and tonumber(a) == targetId
      and protocol == config.HACK_PROTOCOL
      and type(message) == "table"
      and message.magic == config.HACK_MAGIC
      and message.reply_to == requestId then

      if message.type == "HACK_GRANTED" then
        return {
          target_id = targetId,
          token = message.token,
          expires_at = message.expires_at
        }
      end

      return nil, message.message or "Intrusion refusee."
    end
  end
end

function hack.remote(targetId, token, action, argument)
  local allowed, err = requireOperator()
  if not allowed then return nil, err end

  targetId = tonumber(targetId)
  if not targetId then return nil, "ID PC invalide." end

  local requestId = util.requestId()

  rednet.send(targetId, {
    magic = config.HACK_MAGIC,
    version = config.HACK_PROTOCOL_VERSION,
    type = "HACK_COMMAND",
    source_id = os.getComputerID(),
    request_id = requestId,
    payload = {
      token = token,
      action = action,
      argument = argument
    }
  }, config.HACK_PROTOCOL)

  local timer = os.startTimer(5)

  while true do
    local event, a, message, protocol = os.pullEvent()

    if event == "timer" and a == timer then
      return nil, "Connexion distante expiree."
    end

    if event == "rednet_message"
      and tonumber(a) == targetId
      and protocol == config.HACK_PROTOCOL
      and type(message) == "table"
      and message.magic == config.HACK_MAGIC
      and message.type == "HACK_RESULT"
      and message.reply_to == requestId then

      if message.success then
        return message.data or {}
      end

      return nil, message.message or "Action distante refusee."
    end
  end
end

return hack
