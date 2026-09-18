local config = dofile("/computer-link/src/common/config.lua")
local util = dofile("/computer-link/src/common/util.lua")
local network = dofile("/computer-link/src/common/network.lua")
local database = dofile("/computer-link/src/server/database.lua")

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

while true do
  local senderId, message, protocol = rednet.receive(config.PROTOCOL)

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
  end
end
