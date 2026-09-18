local config = dofile("/computer-link/src/common/config.lua")
local util = dofile("/computer-link/src/common/util.lua")
local network = dofile("/computer-link/src/common/network.lua")
local storage = dofile("/computer-link/src/client/storage.lua")
local hack = dofile("/computer-link/src/client/hack.lua")

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
  print("        COMPUTER LINK")
  print("================================")
  setColour(colors.white)
  print("Version : " .. config.VERSION)
  print("PC ID   : #" .. os.getComputerID())
  print("Label   : " .. tostring(os.getComputerLabel() or "-"))
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

local modemName = modemOrError
hack.openChannel(modemName)
storage.load()

if not os.getComputerLabel() then
  os.setComputerLabel("ASTRAL-PC-" .. os.getComputerID())
end

title()
print("Recherche du MER...")
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

local unread = 0
local hackSessions = {}

local function sendMer(kind, payload)
  local requestId = util.requestId()
  rednet.send(serverId, network.packet(kind, payload, requestId), config.PROTOCOL)
  local timer = os.startTimer(5)

  while true do
    local event, a, b, c = os.pullEvent()

    if event == "timer" and a == timer then
      return nil, "Aucune reponse du MER."
    end

    if event == "rednet_message" then
      local sender, packet, protocol = a, b, c

      if sender == serverId
        and protocol == config.PROTOCOL
        and network.isPacket(packet) then

        if packet.type == "MESSAGE_EVENT" then
          if storage.add(packet.payload) then
            unread = unread + 1
          end
        elseif packet.reply_to == requestId then
          return packet
        end
      end
    end
  end
end

local hello, helloErr = sendMer("HELLO", {
  label = os.getComputerLabel()
})

if not hello then
  setColour(colors.red)
  print("Initialisation impossible: " .. tostring(helloErr))
  setColour(colors.white)
  return
end

local initialInbox = sendMer("INBOX")
if initialInbox and initialInbox.type == "INBOX_RESULT" then
  for _, message in ipairs((initialInbox.payload or {}).messages or {}) do
    if storage.add(message) then unread = unread + 1 end
  end
end

print("Connexion privee etablie.")
print("Tape 'help'.")
print()

local function printMessage(message)
  local mine = tonumber(message.from_id) == os.getComputerID()
  setColour(mine and colors.lightBlue or colors.yellow)
  write(mine and ("Moi -> #" .. tostring(message.to_id))
    or ("#" .. tostring(message.from_id) .. " -> Moi"))
  setColour(colors.white)
  print(" : " .. tostring(message.body))
end

local function showMer(packet)
  if not packet then return end
  local payload = packet.payload or {}

  if packet.type == "ERROR" then
    setColour(colors.red)
    print("ERREUR: " .. tostring(payload.message))
    setColour(colors.white)

  elseif packet.type == "PONG" then
    setColour(colors.lime)
    print("MER ONLINE v" .. tostring(payload.version) .. " [#" .. tostring(payload.server_id) .. "]")
    setColour(colors.white)

  elseif packet.type == "IDENTITY_RESULT" then
    print("PC ID : #" .. tostring(payload.computer_id))
    print("Label : " .. tostring(payload.label or "-"))

  elseif packet.type == "DEVICE_INFO_RESULT" then
    print("PC #" .. tostring(payload.computer_id))
    print("Label     : " .. tostring(payload.label or "-"))
    print("Last seen : " .. tostring(payload.last_seen or "?"))

  elseif packet.type == "MESSAGE_SENT" then
    local message = payload.message
    if message then
      storage.add(message)
      setColour(colors.lime)
      print("Message prive envoye au PC #" .. tostring(message.to_id) .. ".")
      setColour(colors.white)
    end

  elseif packet.type == "STATS_RESULT" then
    print("MER      : #" .. tostring(payload.server_id))
    print("Version  : " .. tostring(payload.version))
    print("PC connus: " .. tostring(payload.devices))

  else
    print("Reponse MER: " .. tostring(packet.type))
  end
end

local function pullInbox(showMessages)
  local packet, err = sendMer("INBOX")

  if not packet then
    print(tostring(err))
    return
  end

  if packet.type == "ERROR" then
    showMer(packet)
    return
  end

  local messages = (packet.payload or {}).messages or {}
  local added = 0

  for _, message in ipairs(messages) do
    if storage.add(message) then
      added = added + 1
      if showMessages then printMessage(message) end
    end
  end

  unread = 0

  if #messages == 0 then
    print("Aucun message en attente.")
  elseif not showMessages then
    print(tostring(added) .. " nouveau(x) message(s).")
  elseif added == 0 then
    print("Aucun nouveau message (doublons deja recus en direct).")
  end
end

local function printRemoteResult(action, data)
  if action == "info" then
    print("PC #" .. tostring(data.computer_id))
    print("Label        : " .. tostring(data.label or "-"))
    print("Messages     : " .. tostring(data.messages or 0))
    print("Espace libre : " .. tostring(data.free_space or "?"))

  elseif action == "conversations" then
    local messages = data.messages or {}
    print("Extrait local (" .. #messages .. " messages):")
    for _, message in ipairs(messages) do
      print("#" .. tostring(message.from_id)
        .. " -> #" .. tostring(message.to_id)
        .. " : " .. tostring(message.body))
    end

  elseif action == "ls" then
    print("Dossier " .. tostring(data.path or "/") .. ":")
    for _, entry in ipairs(data.entries or {}) do
      print((entry.dir and "[DIR] " or "      ") .. entry.name
        .. (entry.dir and "" or (" (" .. tostring(entry.size) .. "o)")))
    end

  elseif action == "cat" then
    print("--- " .. tostring(data.path or "fichier") .. " ---")
    print(tostring(data.content or ""))

  elseif action == "crash" then
    setColour(colors.red)
    print("CRASH distant envoye. Cible indisponible ~"
      .. tostring(data.recovery_seconds or "?") .. "s.")
    setColour(colors.white)
  end
end

local function help()
  setColour(colors.cyan)
  print("RESEAU PRIVE PAR ID")
  setColour(colors.white)
  print(" id")
  print(" label <nom>")
  print(" msg <PC_ID> <message>")
  print(" inbox")
  print(" history <PC_ID>")
  print(" device <PC_ID>")
  print(" ping")
  print(" stats")
  print()
  setColour(colors.red)
  print("MODULE INTRUSION (jeu)")
  setColour(colors.white)
  if hack.isOperator() then
    print(" Autorisation : OUI (PC #0)")
  else
    print(" Autorisation : NON - reserve au PC #0")
  end
  print(" scan")
  print(" hack <PC_ID>")
  print(" sessions")
  print(" remote <PC_ID> info")
  print(" remote <PC_ID> conversations")
  print(" remote <PC_ID> ls [chemin]")
  print(" remote <PC_ID> cat <fichier>")
  print(" remote <PC_ID> crash")
  print()
  print(" update | clear | quit")
end

local function uiLoop()
  while true do
    if unread > 0 then
      setColour(colors.yellow)
      print("[!] " .. unread .. " message(s) prive(s) recu(s). Tape inbox.")
      setColour(colors.white)
      unread = 0
    end

    setColour(colors.lightBlue)
    write("#" .. os.getComputerID() .. "> ")
    setColour(colors.white)

    local line = read()
    local command, rest = line:match("^(%S+)%s*(.-)$")
    command = string.lower(command or "")

    if command == "" then

    elseif command == "help" then
      help()

    elseif command == "id" or command == "whoami" then
      local packet, err = sendMer("IDENTITY")
      if err then print(err) else showMer(packet) end

    elseif command == "label" then
      if rest == "" then
        print("Usage: label <nom>")
      else
        os.setComputerLabel(string.sub(rest, 1, 32))
        local packet, err = sendMer("HELLO", { label = os.getComputerLabel() })
        if err then print(err) else
          print("Label du PC: " .. tostring(os.getComputerLabel()))
        end
      end

    elseif command == "msg" then
      local target, body = rest:match("^(%d+)%s+(.+)$")

      if not target or not body then
        print("Usage: msg <PC_ID> <message>")
      else
        local packet, err = sendMer("SEND_MESSAGE", {
          target_id = tonumber(target),
          body = body
        })
        if err then print(err) else showMer(packet) end
      end

    elseif command == "inbox" then
      pullInbox(true)

    elseif command == "history" then
      local target = tonumber(rest)

      if not target then
        print("Usage: history <PC_ID>")
      else
        local messages = storage.conversation(target, 50)
        print("Conversation avec PC #" .. target .. " (" .. #messages .. "):")
        for _, message in ipairs(messages) do printMessage(message) end
      end

    elseif command == "device" then
      local target = tonumber(rest)
      if not target then
        print("Usage: device <PC_ID>")
      else
        local packet, err = sendMer("DEVICE_INFO", { computer_id = target })
        if err then print(err) else showMer(packet) end
      end

    elseif command == "ping" then
      local packet, err = sendMer("PING")
      if err then print(err) else showMer(packet) end

    elseif command == "stats" then
      local packet, err = sendMer("STATS")
      if err then print(err) else showMer(packet) end

    elseif command == "scan" then
      setColour(colors.red)
      print("Scan radio de proximite...")
      setColour(colors.white)
      local found, scanErr = hack.scan(modemName, 2)

      if not found then
        setColour(colors.red)
        print(tostring(scanErr))
        setColour(colors.white)
      elseif #found == 0 then
        print("Aucun PC Computer Link detecte a proximite.")
      else
        for _, pc in ipairs(found) do
          print("#" .. pc.id
            .. " | " .. tostring(math.floor((pc.distance or 0) * 10) / 10) .. " blocs"
            .. " | SEC " .. tostring(pc.security or "?")
            .. " | " .. tostring(pc.label or "-"))
        end
      end

    elseif command == "hack" then
      local target = tonumber(rest)

      if not target then
        print("Usage: hack <PC_ID>")
      else
        setColour(colors.red)
        print("Intrusion sur PC #" .. target .. "...")
        setColour(colors.white)

        local session, err = hack.attack(modemName, target)

        if not session then
          setColour(colors.red)
          print("ECHEC: " .. tostring(err))
          setColour(colors.white)
        else
          hackSessions[target] = session
          setColour(colors.lime)
          print("ACCES OBTENU au PC #" .. target .. ".")
          print("Session temporaire ouverte.")
          setColour(colors.white)
        end
      end

    elseif command == "sessions" then
      local any = false
      for target, session in pairs(hackSessions) do
        any = true
        print("PC #" .. target .. " | expiration " .. tostring(session.expires_at))
      end
      if not any then print("Aucune session pirate.") end

    elseif command == "remote" then
      local targetText, action, argument = rest:match("^(%d+)%s+(%S+)%s*(.-)$")
      local target = tonumber(targetText)
      action = string.lower(action or "")

      if not target or action == "" then
        print("Usage: remote <PC_ID> <info|conversations|ls|cat|crash> [argument]")
      else
        if action == "conv" then action = "conversations" end
        if action == "read" then action = "cat" end

        local session = hackSessions[target]
        if not session then
          print("Pas de session sur PC #" .. target .. ". Utilise: hack " .. target)
        else
          local data, err = hack.remote(target, session.token, action, argument)

          if not data then
            setColour(colors.red)
            print("ERREUR DISTANTE: " .. tostring(err))
            setColour(colors.white)
          else
            printRemoteResult(action, data)
          end
        end
      end

    elseif command == "clear" or command == "cls" then
      title()

    elseif command == "update" then
      shell.run("/computer-link/update.lua")
      print("Redemarre avec: reboot")

    elseif command == "quit" or command == "exit" then
      print("Computer Link ferme.")
      return

    else
      print("Commande inconnue. Tape 'help'.")
    end
  end
end

local function daemonLoop()
  while true do
    local event, a, b, c, d, e = os.pullEvent()

    if event == "modem_message" then
      local side, channel, replyChannel, message, distance = a, b, c, d, e
      hack.handleModem(modemName, channel, replyChannel, message, distance)

    elseif event == "rednet_message" then
      local sender, message, protocol = a, b, c

      if hack.handleRednet(sender, message, protocol, storage) then
        -- Commande d'intrusion traitee.
      elseif sender == serverId
        and protocol == config.PROTOCOL
        and network.isPacket(message)
        and message.type == "MESSAGE_EVENT" then

        if storage.add(message.payload) then
          unread = unread + 1
        end
      end
    end
  end
end

parallel.waitForAny(uiLoop, daemonLoop)
