local config = dofile("/computer-link/src/common/config.lua")
local util = dofile("/computer-link/src/common/util.lua")
local network = dofile("/computer-link/src/common/network.lua")

local function setColour(colour)
  if term.isColor and term.isColor() then
    term.setTextColor(colour)
  end
end

local function title()
  term.clear()
  term.setCursorPos(1, 1)
  setColour(colors.cyan)
  print("================================")
  print("        A S T R A L N E T")
  print("       COMPUTER LINK CLIENT")
  print("================================")
  setColour(colors.white)
  print("Version: " .. config.VERSION)
  print()
end

local ok, modemOrError = network.open()
if not ok then
  title()
  setColour(colors.red)
  print(modemOrError)
  setColour(colors.white)
  print("Ajoute un Wireless Modem puis redemarre.")
  return
end

os.setComputerLabel(os.getComputerLabel() or ("ASTRAL-CLIENT-" .. os.getComputerID()))

title()
print("Recherche du serveur MER...")
local serverId = network.findServer()

if not serverId then
  setColour(colors.red)
  print("MER introuvable.")
  setColour(colors.white)
  print("Verifie que le serveur MER est allume et a portee.")
  return
end

setColour(colors.lime)
print("MER trouve: PC #" .. serverId)
setColour(colors.white)
print("Tape 'help' pour les commandes.")
print()

local inboxEvents = {}

local function send(kind, payload)
  local requestId = util.requestId()
  rednet.send(serverId, network.packet(kind, payload, requestId), config.PROTOCOL)

  local deadline = os.startTimer(5)

  while true do
    local event, a, b, c = os.pullEvent()

    if event == "timer" and a == deadline then
      return nil, "Delai depasse: aucune reponse du MER."
    end

    if event == "rednet_message" then
      local sender, packet, protocol = a, b, c

      if sender == serverId and protocol == config.PROTOCOL and network.isPacket(packet) then
        if packet.type == "MESSAGE_EVENT" then
          inboxEvents[#inboxEvents + 1] = packet.payload
        elseif packet.reply_to == requestId then
          return packet
        end
      end
    end
  end
end

local function printMessage(message)
  setColour(colors.yellow)
  print("[" .. tostring(message.from) .. "]")
  setColour(colors.white)
  print(tostring(message.message))
end

local function flushEvents()
  if #inboxEvents == 0 then return end

  setColour(colors.lime)
  print("--- Nouveaux messages ---")
  setColour(colors.white)

  for _, message in ipairs(inboxEvents) do
    printMessage(message)
  end

  inboxEvents = {}
end

local function showResponse(packet)
  if not packet then return end
  local payload = packet.payload or {}

  if packet.type == "ERROR" then
    setColour(colors.red)
    print("ERREUR: " .. tostring(payload.message))
    setColour(colors.white)

  elseif packet.type == "PONG" then
    setColour(colors.lime)
    print("MER ONLINE - v" .. tostring(payload.version) .. " - PC #" .. tostring(payload.server_id))
    setColour(colors.white)

  elseif packet.type == "REGISTER_RESULT" then
    setColour(payload.success and colors.lime or colors.red)
    print(tostring(payload.message))
    setColour(colors.white)

  elseif packet.type == "IDENTITY" then
    print("Compte : " .. tostring(payload.username))
    print("PC ID  : " .. tostring(payload.computer_id))

  elseif packet.type == "USER_LIST" then
    local users = payload.users or {}
    print("Utilisateurs AstralNet (" .. #users .. "):")
    for _, user in ipairs(users) do
      print(" - " .. tostring(user.username) .. " [PC " .. tostring(user.computer_id) .. "]")
    end

  elseif packet.type == "MESSAGE_SENT" then
    setColour(colors.lime)
    print("Message envoye a " .. tostring(payload.target) .. ".")
    setColour(colors.white)

  elseif packet.type == "INBOX_RESULT" then
    local messages = payload.messages or {}
    if #messages == 0 then
      print("Aucun message.")
    else
      print("Boite de reception (" .. #messages .. "):")
      for _, message in ipairs(messages) do
        printMessage(message)
      end
    end

  elseif packet.type == "STATS_RESULT" then
    print("MER PC #" .. tostring(payload.server_id))
    print("Version : " .. tostring(payload.version))
    print("Comptes : " .. tostring(payload.users))

  else
    print("Reponse: " .. tostring(packet.type))
  end
end

local function help()
  setColour(colors.cyan)
  print("Commandes:")
  setColour(colors.white)
  print(" help")
  print(" register <pseudo>")
  print(" whoami")
  print(" users")
  print(" msg <pseudo> <message>")
  print(" inbox")
  print(" ping")
  print(" stats")
  print(" clear")
  print(" update")
  print(" quit")
end

while true do
  flushEvents()

  setColour(colors.lightBlue)
  write("astralnet> ")
  setColour(colors.white)

  local line = read()
  local command, rest = line:match("^(%S+)%s*(.-)$")
  command = string.lower(command or "")

  if command == "" then
    -- Rien.

  elseif command == "help" then
    help()

  elseif command == "register" then
    if rest == "" then
      print("Usage: register <pseudo>")
    else
      local packet, err = send("REGISTER", { username = rest })
      if err then print(err) else showResponse(packet) end
    end

  elseif command == "whoami" then
    local packet, err = send("WHOAMI")
    if err then print(err) else showResponse(packet) end

  elseif command == "users" then
    local packet, err = send("USERS")
    if err then print(err) else showResponse(packet) end

  elseif command == "msg" then
    local target, message = rest:match("^(%S+)%s+(.+)$")

    if not target or not message then
      print("Usage: msg <pseudo> <message>")
    else
      local packet, err = send("SEND_MESSAGE", {
        target = target,
        message = message
      })
      if err then print(err) else showResponse(packet) end
    end

  elseif command == "inbox" then
    local packet, err = send("INBOX")
    if err then print(err) else showResponse(packet) end

  elseif command == "ping" then
    local packet, err = send("PING")
    if err then print(err) else showResponse(packet) end

  elseif command == "stats" then
    local packet, err = send("STATS")
    if err then print(err) else showResponse(packet) end

  elseif command == "clear" or command == "cls" then
    title()

  elseif command == "update" then
    shell.run("/computer-link/update.lua")
    print("Redemarre le PC pour charger la nouvelle version.")

  elseif command == "quit" or command == "exit" then
    print("Deconnexion AstralNet.")
    return

  else
    print("Commande inconnue. Tape 'help'.")
  end
end
