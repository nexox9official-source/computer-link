local config = dofile("/computer-link/src/common/config.lua")
local util = dofile("/computer-link/src/common/util.lua")
local network = dofile("/computer-link/src/common/network.lua")
local database = dofile("/computer-link/src/server/database.lua")

local GHOST_PROTOCOL = "astralnet.ghostlink.v1"
local GHOST_HOST = "MER-GHOST"

local serverPolicy = nil
do
  local ok, policy = pcall(require, "computer_link_policy")
  if ok and type(policy) == "table" then serverPolicy = policy end
end

local function merAuthorized()
  if not serverPolicy then return false, "Politique serveur absente." end

  local id = os.getComputerID()
  if type(serverPolicy.deny_mer_ids) == "table"
    and serverPolicy.deny_mer_ids[id] == true then
    return false, "Ce Computer ID est interdit pour le role MER."
  end

  local trusted = serverPolicy.trusted_mer_ids
  if type(trusted) == "table" and next(trusted) ~= nil
    and trusted[id] ~= true then
    return false, "Ce Computer n'est pas le MER autorise."
  end

  return true
end

local function isOperator(id)
  id = tonumber(id)
  if not id then return false end
  return serverPolicy
    and type(serverPolicy.hack_operator_ids) == "table"
    and serverPolicy.hack_operator_ids[id] == true
end

local function isGhostImmune(id)
  id = tonumber(id)
  if not id then return true end
  if isOperator(id) then return true end
  return serverPolicy
    and type(serverPolicy.ghostlink_immune_ids) == "table"
    and serverPolicy.ghostlink_immune_ids[id] == true
end

local function setColour(colour)
  if term.isColor and term.isColor() then
    term.setTextColor(colour)
  end
end

local function log(message, colour)
  if colour then setColour(colour) end
  print("[" .. textutils.formatTime(os.time(), true) .. "] " .. message)
  setColour(colors.white)
end

local allowedMer, merError = merAuthorized()
if not allowedMer then
  if term.isColor and term.isColor() then term.setTextColor(colors.red) end
  print("MER BLOQUE: " .. tostring(merError))
  if term.isColor and term.isColor() then term.setTextColor(colors.white) end
  return
end

local ok, modemOrError = network.open()
if not ok then
  setColour(colors.red)
  print(modemOrError)
  setColour(colors.white)
  print("Place un Wireless Modem sur le MER puis redemarre.")
  return
end

database.load()

pcall(function()
  rednet.unhost(config.PROTOCOL, config.SERVER_HOSTNAME)
end)
rednet.host(config.PROTOCOL, config.SERVER_HOSTNAME)
pcall(function() rednet.unhost(GHOST_PROTOCOL, GHOST_HOST) end)
rednet.host(GHOST_PROTOCOL, GHOST_HOST)
os.setComputerLabel("MER-SERVER")

term.clear()
term.setCursorPos(1, 1)
setColour(colors.cyan)
print("================================")
print("        A S T R A L N E T")
print("     MER - SERVEUR CENTRAL")
print("================================")
setColour(colors.white)
print("Version    : " .. config.VERSION)
print("Computer ID: " .. os.getComputerID())
print("Modem      : " .. tostring(modemOrError))
print("Protocole  : " .. config.PROTOCOL)
print("PC connus  : " .. database.countDevices())
print("--------------------------------")
log("MER ONLINE", colors.lime)

local function pushGhostState(targetId)
  targetId = tonumber(targetId)
  if not targetId then return end

  local state = database.ghostHost(targetId)
  rednet.send(targetId, {
    magic = "GHOSTLINK_GAMEPLAY",
    type = "STATE_PUSH",
    payload = {
      infected = state.infected == true and not isGhostImmune(targetId),
      spread = state.spread == true and not isGhostImmune(targetId)
    }
  }, GHOST_PROTOCOL)
end

local function reply(target, request, kind, payload)
  local packet = network.packet(kind, payload, nil)
  packet.reply_to = request and request.request_id or nil
  rednet.send(target, packet, config.PROTOCOL)
end

local function ensureKnown(senderId, request)
  local device = database.getDevice(senderId)

  if not device then
    reply(senderId, request, "ERROR", {
      code = "UNKNOWN_PC",
      message = "PC non initialise. Redemarre Computer Link."
    })
    return nil
  end

  database.touch(senderId)
  return device
end

local function handle(senderId, request)
  if not network.isPacket(request) then return end

  local kind = request.type
  local payload = request.payload or {}

  if kind == "HELLO" then
    local device = database.registerDevice(senderId, payload.label)
    reply(senderId, request, "HELLO_RESULT", {
      computer_id = senderId,
      label = device and device.label or nil,
      server_id = os.getComputerID(),
      version = config.VERSION
    })

    log("PC #" .. senderId .. " connecte" .. (device and device.label and (" [" .. device.label .. "]") or ""), colors.lime)
    return
  end

  if kind == "PING" then
    reply(senderId, request, "PONG", {
      server = config.SERVER_HOSTNAME,
      version = config.VERSION,
      server_id = os.getComputerID()
    })
    return
  end

  local device = ensureKnown(senderId, request)
  if not device then return end

  if kind == "IDENTITY" then
    reply(senderId, request, "IDENTITY_RESULT", {
      computer_id = senderId,
      label = device.label
    })

  elseif kind == "DEVICE_INFO" then
    local targetId = tonumber(payload.computer_id)
    local target = targetId and database.getDevice(targetId) or nil

    if not target then
      reply(senderId, request, "ERROR", {
        code = "UNKNOWN_TARGET",
        message = "PC #" .. tostring(payload.computer_id) .. " inconnu du MER."
      })
      return
    end

    reply(senderId, request, "DEVICE_INFO_RESULT", {
      computer_id = target.computer_id,
      label = target.label,
      last_seen = target.last_seen
    })

  elseif kind == "INBOX" then
    reply(senderId, request, "INBOX_RESULT", {
      messages = database.takeQueue(senderId)
    })

  elseif kind == "SEND_MESSAGE" then
    local targetId = tonumber(payload.target_id)
    local body = util.trim(payload.body)

    if not targetId or targetId < 0 or math.floor(targetId) ~= targetId then
      reply(senderId, request, "ERROR", {
        code = "INVALID_TARGET",
        message = "ID PC cible invalide."
      })
      return
    end

    if not database.getDevice(targetId) then
      reply(senderId, request, "ERROR", {
        code = "UNKNOWN_TARGET",
        message = "Le PC #" .. tostring(targetId) .. " n'est pas connu du MER."
      })
      return
    end

    if body == "" or #body > config.MESSAGE_MAX then
      reply(senderId, request, "ERROR", {
        code = "INVALID_MESSAGE",
        message = "Message vide ou trop long (max " .. config.MESSAGE_MAX .. ")."
      })
      return
    end

    local entry = database.queueMessage(senderId, targetId, body)

    rednet.send(
      targetId,
      network.packet("MESSAGE_EVENT", entry),
      config.PROTOCOL
    )

    reply(senderId, request, "MESSAGE_SENT", {
      message = entry
    })

    log("Message prive PC #" .. senderId .. " -> PC #" .. targetId, colors.lightBlue)

  elseif kind == "GHOST_STATUS" then
    if not isOperator(senderId) then
      reply(senderId, request, "ERROR", {
        code = "FORBIDDEN",
        message = "Acces GhostLink refuse."
      })
      return
    end

    local targetId = tonumber(payload.target_id)
    if not targetId then
      reply(senderId, request, "ERROR", {
        code = "INVALID_TARGET",
        message = "ID cible invalide."
      })
      return
    end

    reply(senderId, request, "GHOST_STATUS_RESULT", {
      computer_id = targetId,
      state = database.ghostHost(targetId),
      immune = isGhostImmune(targetId)
    })

  elseif kind == "GHOST_INFECT" then
    if not isOperator(senderId) then
      reply(senderId, request, "ERROR", {
        code = "FORBIDDEN",
        message = "Acces GhostLink refuse."
      })
      return
    end

    local targetId = tonumber(payload.target_id)
    if not targetId or isGhostImmune(targetId) then
      reply(senderId, request, "ERROR", {
        code = "IMMUNE_OR_INVALID",
        message = "Cette cible est invalide ou immunisee."
      })
      return
    end

    local state = database.setGhostHost(targetId, true, senderId, payload.spread ~= false)
    pushGhostState(targetId)
    reply(senderId, request, "GHOST_INFECT_RESULT", {
      computer_id = targetId,
      state = state
    })

  elseif kind == "GHOST_CLEAN" then
    if not isOperator(senderId) then
      reply(senderId, request, "ERROR", {
        code = "FORBIDDEN",
        message = "Acces GhostLink refuse."
      })
      return
    end

    local targetId = tonumber(payload.target_id)
    if not targetId then
      reply(senderId, request, "ERROR", {
        code = "INVALID_TARGET",
        message = "ID cible invalide."
      })
      return
    end

    database.setGhostHost(targetId, false, senderId, false)
    pushGhostState(targetId)
    reply(senderId, request, "GHOST_CLEAN_RESULT", {
      computer_id = targetId,
      cleaned = true
    })

  elseif kind == "GHOST_SPREAD" then
    if not isOperator(senderId) then
      reply(senderId, request, "ERROR", {
        code = "FORBIDDEN",
        message = "Acces GhostLink refuse."
      })
      return
    end

    local targetId = tonumber(payload.target_id)
    local state = database.ghostHost(targetId)
    if not targetId or state.infected ~= true then
      reply(senderId, request, "ERROR", {
        code = "NOT_INFECTED",
        message = "La cible n'est pas sous GhostLink."
      })
      return
    end

    state = database.setGhostHost(targetId, true, senderId, payload.enabled == true)
    pushGhostState(targetId)
    reply(senderId, request, "GHOST_SPREAD_RESULT", {
      computer_id = targetId,
      state = state
    })

  elseif kind == "GHOST_LIST" then
    if not isOperator(senderId) then
      reply(senderId, request, "ERROR", {
        code = "FORBIDDEN",
        message = "Acces GhostLink refuse."
      })
      return
    end

    reply(senderId, request, "GHOST_LIST_RESULT", {
      hosts = database.listGhostHosts(),
      disks = database.listGhostDisks()
    })

  elseif kind == "GHOST_DISK_SET" then
    if not isOperator(senderId) then
      reply(senderId, request, "ERROR", {
        code = "FORBIDDEN",
        message = "Acces GhostLink refuse."
      })
      return
    end

    local diskId = tonumber(payload.disk_id)
    if not diskId then
      reply(senderId, request, "ERROR", {
        code = "INVALID_DISK",
        message = "Disk ID invalide."
      })
      return
    end

    local state = database.setGhostDisk(diskId, payload.infected ~= false, senderId)
    reply(senderId, request, "GHOST_DISK_SET_RESULT", {
      disk_id = diskId,
      state = state
    })

  elseif kind == "STATS" then
    reply(senderId, request, "STATS_RESULT", {
      devices = database.countDevices(),
      server_id = os.getComputerID(),
      version = config.VERSION
    })

  else
    reply(senderId, request, "ERROR", {
      code = "UNKNOWN_COMMAND",
      message = "Commande reseau inconnue: " .. tostring(kind)
    })
  end
end

local function ghostReply(target, request, ok, payload, err)
  rednet.send(target, {
    magic = "GHOSTLINK_GAMEPLAY",
    type = "RESULT",
    reply_to = request and request.request_id or nil,
    ok = ok == true,
    payload = payload or {},
    error = err
  }, GHOST_PROTOCOL)
end

local function handleGhost(senderId, message)
  if type(message) ~= "table" or message.magic ~= "GHOSTLINK_GAMEPLAY" then return end

  local kind = tostring(message.type or "")
  local payload = type(message.payload) == "table" and message.payload or {}
  local sender = tonumber(senderId)

  if kind == "STATE" then
    if isGhostImmune(sender) then
      database.setGhostHost(sender, false, "policy", false)
      ghostReply(sender, message, true, {
        infected = false,
        spread = false,
        immune = true
      })
      return
    end

    for _, diskId in ipairs(payload.disk_ids or {}) do
      local diskState = database.ghostDisk(diskId)
      if diskState.infected == true then
        database.setGhostHost(sender, true, "disk:" .. tostring(diskId), true)
        break
      end
    end

    local state = database.ghostHost(sender)
    ghostReply(sender, message, true, {
      infected = state.infected == true,
      spread = state.spread == true,
      immune = false
    })
    return
  end

  local state = database.ghostHost(sender)
  local senderCanSpread = isOperator(sender)
    or (state.infected == true and state.spread == true)

  if not senderCanSpread then
    ghostReply(sender, message, false, nil, "Propagation Malcraft non autorisee.")
    return
  end

  if kind == "SPREAD_TO" then
    local targetId = tonumber(payload.target_id)
    if not targetId or isGhostImmune(targetId) then
      ghostReply(sender, message, false, nil, "Cible invalide ou immunisee.")
      return
    end

    local targetState = database.setGhostHost(targetId, true, sender, true)
    pushGhostState(targetId)
    ghostReply(sender, message, true, {
      target_id = targetId,
      infected = targetState.infected == true
    })

  elseif kind == "INFECT_DISK" then
    local diskId = tonumber(payload.disk_id)
    if not diskId then
      ghostReply(sender, message, false, nil, "Disk ID invalide.")
      return
    end

    database.setGhostDisk(diskId, true, sender)
    ghostReply(sender, message, true, {
      disk_id = diskId,
      infected = true
    })

  else
    ghostReply(sender, message, false, nil, "Commande GhostLink inconnue.")
  end
end

while true do
  local senderId, message, protocol = rednet.receive()

  if protocol == config.PROTOCOL then
    local success, err = pcall(handle, senderId, message)

    if not success then
      log("ERREUR requete PC #" .. tostring(senderId) .. ": " .. tostring(err), colors.red)

      if type(message) == "table" then
        pcall(reply, senderId, message, "ERROR", {
          code = "SERVER_ERROR",
          message = "Erreur interne MER."
        })
      end
    end

  elseif protocol == GHOST_PROTOCOL then
    local success, err = pcall(handleGhost, senderId, message)
    if not success then
      log("ERREUR GhostLink PC #" .. tostring(senderId) .. ": " .. tostring(err), colors.red)
    end
  end
end
