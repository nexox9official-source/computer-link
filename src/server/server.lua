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
print("Comptes    : " .. util.count(database.get().users))
print("--------------------------------")
log("MER ONLINE", colors.lime)

local function reply(target, request, kind, payload)
  local packet = network.packet(kind, payload, nil)
  packet.reply_to = request and request.request_id or nil
  rednet.send(target, packet, config.PROTOCOL)
end

local function requireIdentity(senderId, request)
  local username = database.usernameForComputer(senderId)

  if not username then
    reply(senderId, request, "ERROR", {
      code = "NOT_REGISTERED",
      message = "Ce PC n'est pas enregistre. Utilise: register <pseudo>"
    })
    return nil
  end

  database.touch(senderId)
  return username
end

local function handle(senderId, request)
  if not network.isPacket(request) then
    return
  end

  local kind = request.type
  local payload = request.payload or {}

  if kind == "PING" then
    reply(senderId, request, "PONG", {
      server = config.SERVER_HOSTNAME,
      version = config.VERSION,
      server_id = os.getComputerID()
    })
    return
  end

  if kind == "REGISTER" then
    local success, message = database.register(senderId, payload.username)
    reply(senderId, request, "REGISTER_RESULT", {
      success = success,
      message = message,
      username = success and database.usernameForComputer(senderId) or nil
    })

    if success then
      log("Compte: " .. tostring(database.usernameForComputer(senderId)) .. " [PC " .. senderId .. "]", colors.lime)
    else
      log("Inscription refusee pour PC " .. senderId .. ": " .. tostring(message), colors.orange)
    end
    return
  end

  local username = requireIdentity(senderId, request)
  if not username then return end

  if kind == "WHOAMI" then
    reply(senderId, request, "IDENTITY", {
      username = username,
      computer_id = senderId
    })

  elseif kind == "USERS" then
    reply(senderId, request, "USER_LIST", {
      users = database.listUsers()
    })

  elseif kind == "INBOX" then
    reply(senderId, request, "INBOX_RESULT", {
      messages = database.takeInbox(username)
    })

  elseif kind == "SEND_MESSAGE" then
    local target = util.trim(payload.target)
    local message = util.trim(payload.message)

    if target == "" or not database.getUser(target) then
      reply(senderId, request, "ERROR", {
        code = "UNKNOWN_USER",
        message = "Utilisateur introuvable."
      })
      return
    end

    if message == "" or #message > config.MESSAGE_MAX then
      reply(senderId, request, "ERROR", {
        code = "INVALID_MESSAGE",
        message = "Message vide ou trop long (max " .. config.MESSAGE_MAX .. ")."
      })
      return
    end

    local entry = database.pushMessage(username, target, message)
    local targetUser = database.getUser(target)

    if targetUser and targetUser.computer_id then
      rednet.send(targetUser.computer_id, network.packet("MESSAGE_EVENT", entry), config.PROTOCOL)
    end

    reply(senderId, request, "MESSAGE_SENT", {
      target = target,
      sent_at = entry.sent_at
    })

    log(username .. " -> " .. target .. ": " .. message, colors.lightBlue)

  elseif kind == "STATS" then
    reply(senderId, request, "STATS_RESULT", {
      users = util.count(database.get().users),
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
      log("ERREUR requete PC " .. tostring(senderId) .. ": " .. tostring(err), colors.red)

      if type(message) == "table" then
        pcall(reply, senderId, message, "ERROR", {
          code = "SERVER_ERROR",
          message = "Erreur interne MER."
        })
      end
    end
  end
end
