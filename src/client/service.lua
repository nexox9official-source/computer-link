local config = dofile("/computer-link/src/common/config.lua")
local util = dofile("/computer-link/src/common/util.lua")
local network = dofile("/computer-link/src/common/network.lua")
local storage = dofile("/computer-link/src/client/storage.lua")
local hack = dofile("/computer-link/src/client/remote_control.lua")

local service = {}
service.__index = service

local function malcraftBusAvailable()
  return type(malcraft_bus) == "table"
    and type(malcraft_bus.version) == "function"
    and type(malcraft_bus.listInfected) == "function"
end

local function jsonDecode(value)
  if type(value) ~= "string" or value == "" then return nil end
  local ok, decoded = pcall(textutils.unserializeJSON, value)
  if ok then return decoded end
  return nil
end

local function jsonEncode(value)
  local ok, encoded = pcall(textutils.serializeJSON, value or {})
  if ok then return encoded end
  return "{}"
end

local function packetError(packet)
  if packet and packet.type == "ERROR" then
    return (packet.payload or {}).message or "Erreur MER."
  end
  return nil
end

function service.new()
  local self = setmetatable({}, service)
  self.online = false
  self.serverId = nil
  self.modemName = nil
  self.unread = 0
  self.hackSessions = {}
  self.lastError = nil
  self.startedAt = util.now()
  self.updateAvailable = false
  self.remoteVersion = config.VERSION
  self.serverVersion = nil
  self.updateTimer = nil
  return self
end

function service:checkUpdate()
  if not http or not http.get then
    return false, "HTTP indisponible."
  end

  local url = config.GITHUB_RAW .. "manifest.lua?t=" .. tostring(util.now())
  local response, err = http.get(url)

  if not response then
    return false, err or "Manifest distant inaccessible."
  end

  local source = response.readAll()
  response.close()

  local loader, loadErr = load(source, "@remote_manifest.lua", "t", {})
  if not loader then
    return false, loadErr
  end

  local ok, manifest = pcall(loader)
  if not ok or type(manifest) ~= "table" then
    return false, "Manifest distant invalide."
  end

  self.remoteVersion = tostring(manifest.version or config.VERSION)
  self.updateAvailable = self.remoteVersion ~= tostring(config.VERSION)
  os.queueEvent("linkos_refresh")
  return true, self.updateAvailable
end

function service:startUpdateMonitor()
  if not self.updateTimer then
    self.updateTimer = os.startTimer(60)
  end
end

function service:start()
  local ok, modemOrError = network.open()
  if not ok then
    self.lastError = modemOrError
    return false, modemOrError
  end

  self.modemName = modemOrError
  hack.openChannel(self.modemName)
  storage.load()

  if not os.getComputerLabel() then
    os.setComputerLabel("ASTRAL-PC-" .. os.getComputerID())
  end

  self.serverId = network.findServer()
  if not self.serverId then
    self.lastError = "MER introuvable."
    self.online = false
    return false, self.lastError
  end

  local hello, err = self:request("HELLO", {
    label = os.getComputerLabel()
  }, 5)

  if not hello then
    self.lastError = err
    self.online = false
    return false, err
  end

  self.serverVersion = hello.payload and hello.payload.version or nil
  self.online = true
  self.lastError = nil
  self:syncInbox(false)
  return true
end

function service:request(kind, payload, timeout)
  if not self.serverId then
    return nil, "MER non connecte."
  end

  local requestId = util.requestId()
  rednet.send(
    self.serverId,
    network.packet(kind, payload or {}, requestId),
    config.PROTOCOL
  )

  local timer = os.startTimer(timeout or 5)

  while true do
    local event, a, b, c, d, e = os.pullEvent()

    if event == "timer" and a == timer then
      return nil, "Aucune reponse du MER."
    end

    if event == "rednet_message" then
      local sender, packet, protocol = a, b, c

      if protocol == config.HACK_PROTOCOL then
        hack.handleRednet(sender, packet, protocol, storage)
      elseif sender == self.serverId
        and protocol == config.PROTOCOL
        and network.isPacket(packet) then

        if packet.type == "MESSAGE_EVENT" then
          if storage.add(packet.payload) then
            self.unread = self.unread + 1
            os.queueEvent("linkos_refresh")
          end
        elseif packet.reply_to == requestId then
          local err = packetError(packet)
          if err then return nil, err, packet end
          return packet
        end
      end

    elseif event == "modem_message" then
      local side, channel, replyChannel, message, distance = a, b, c, d, e
      hack.handleModem(self.modemName, channel, replyChannel, message, distance)

    elseif event == "peripheral" or event == "peripheral_detach"
      or event == "monitor_resize" or event == "term_resize" then
      os.queueEvent("linkos_display_changed")
    end
  end
end

function service:reconnect()
  self.serverId = network.findServer()
  if not self.serverId then
    self.online = false
    self.lastError = "MER introuvable."
    return false, self.lastError
  end

  local packet, err = self:request("HELLO", {
    label = os.getComputerLabel()
  })

  if not packet then
    self.online = false
    self.lastError = err
    return false, err
  end

  self.serverVersion = packet.payload and packet.payload.version or nil
  self.online = true
  self.lastError = nil
  return true
end

function service:syncInbox(markUnread)
  local packet, err = self:request("INBOX")
  if not packet then return nil, err end

  local messages = (packet.payload or {}).messages or {}
  local added = 0

  for _, message in ipairs(messages) do
    if storage.add(message) then
      added = added + 1
      if markUnread ~= false then
        self.unread = self.unread + 1
      end
    end
  end

  return added
end

function service:sendMessage(targetId, body)
  targetId = tonumber(targetId)
  body = util.trim(body)

  if not targetId then return nil, "ID PC invalide." end
  if body == "" then return nil, "Message vide." end

  local packet, err = self:request("SEND_MESSAGE", {
    target_id = targetId,
    body = body
  })

  if not packet then return nil, err end

  local message = (packet.payload or {}).message
  if message then storage.add(message) end
  return message
end

function service:identity()
  return {
    computer_id = os.getComputerID(),
    label = os.getComputerLabel(),
    server_id = self.serverId,
    modem = self.modemName,
    online = self.online,
    version = config.VERSION
  }
end

function service:setLabel(label)
  label = util.trim(label)
  if label == "" then return false, "Label vide." end
  os.setComputerLabel(string.sub(label, 1, 32))

  if self.online then
    local packet, err = self:request("HELLO", {
      label = os.getComputerLabel()
    })
    if not packet then return false, err end
  end

  return true
end

function service:deviceInfo(targetId)
  local packet, err = self:request("DEVICE_INFO", {
    computer_id = tonumber(targetId)
  })
  if not packet then return nil, err end
  return packet.payload
end

function service:ping()
  local started = os.clock()
  local packet, err = self:request("PING")
  if not packet then return nil, err end
  return {
    payload = packet.payload,
    latency = math.floor((os.clock() - started) * 1000)
  }
end

function service:stats()
  local packet, err = self:request("STATS")
  if not packet then return nil, err end
  return packet.payload
end

local function versionParts(value)
  local a, b, c = tostring(value or ""):match("^(%d+)%.(%d+)%.(%d+)")
  return tonumber(a) or 0, tonumber(b) or 0, tonumber(c) or 0
end

local function versionAtLeast(value, required)
  local a1, b1, c1 = versionParts(value)
  local a2, b2, c2 = versionParts(required)

  if a1 ~= a2 then return a1 > a2 end
  if b1 ~= b2 then return b1 > b2 end
  return c1 >= c2
end

function service:ensureGhostSupport()
  if not self.serverVersion then
    local packet, err = self:request("PING")
    if not packet then return false, err end
    self.serverVersion = packet.payload and packet.payload.version or nil
  end

  if not versionAtLeast(self.serverVersion, "0.10.0") then
    return false,
      "MER trop ancien pour Malcraft (" .. tostring(self.serverVersion or "?")
      .. "). Mets a jour puis redemarre le MER en 0.10.0."
  end

  return true
end

function service:ghostStatus(targetId)
  targetId = tonumber(targetId)
  if not targetId then return nil, "ID cible invalide." end

  if malcraftBusAvailable() then
    local registry = jsonDecode(malcraft_bus.listInfected()) or {hosts={}}
    local found = nil

    for _, item in ipairs(registry.hosts or {}) do
      if tonumber(item.computer_id) == targetId then
        found = item
        break
      end
    end

    return {
      computer_id = targetId,
      state = {
        infected = found ~= nil,
        spread = found and found.spread == true or false,
        online = found and found.online == true or false,
        source = found and found.source or nil,
        label = found and found.label or nil,
        last_seen = found and found.last_seen or nil,
        dimension = found and found.dimension or nil,
        x = found and found.x or nil,
        y = found and found.y or nil,
        z = found and found.z or nil
      },
      immune = targetId == 0,
      transport = "malcraft_bridge"
    }
  end

  local supported, supportErr = self:ensureGhostSupport()
  if not supported then return nil, supportErr end

  local packet, err = self:request("GHOST_STATUS", {
    target_id = targetId
  })
  if not packet then return nil, err end
  return packet.payload
end

function service:ghostInstall(targetId, spread)
  targetId = tonumber(targetId)
  if not targetId then return nil, "ID cible invalide." end

  if malcraftBusAvailable() then
    local ok = malcraft_bus.infectTarget(
      targetId,
      "operator:" .. tostring(os.getComputerID())
    )
    if not ok then return nil, "Malcraft Bridge a refuse la contamination." end

    if type(malcraft_bus.setSpreadTarget) == "function" then
      pcall(malcraft_bus.setSpreadTarget, targetId, spread ~= false)
    end

    return self:ghostStatus(targetId)
  end

  local supported, supportErr = self:ensureGhostSupport()
  if not supported then return nil, supportErr end

  local packet, err = self:request("GHOST_INFECT", {
    target_id = targetId,
    spread = spread ~= false
  })
  if not packet then return nil, err end
  return packet.payload
end

function service:ghostClean(targetId)
  targetId = tonumber(targetId)
  if not targetId then return nil, "ID cible invalide." end

  if malcraftBusAvailable() then
    local ok = malcraft_bus.cleanTarget(targetId)
    if not ok then return nil, "Nettoyage Malcraft refuse." end
    return {
      computer_id = targetId,
      cleaned = true,
      transport = "malcraft_bridge"
    }
  end

  local supported, supportErr = self:ensureGhostSupport()
  if not supported then return nil, supportErr end

  local packet, err = self:request("GHOST_CLEAN", {
    target_id = targetId
  })
  if not packet then return nil, err end
  return packet.payload
end

function service:ghostSetSpread(targetId, enabled)
  targetId = tonumber(targetId)
  if not targetId then return nil, "ID cible invalide." end

  if malcraftBusAvailable() and type(malcraft_bus.setSpreadTarget) == "function" then
    local ok = malcraft_bus.setSpreadTarget(targetId, enabled == true)
    if not ok then return nil, "Modification de propagation refusee." end
    return self:ghostStatus(targetId)
  end

  local supported, supportErr = self:ensureGhostSupport()
  if not supported then return nil, supportErr end

  local packet, err = self:request("GHOST_SPREAD", {
    target_id = targetId,
    enabled = enabled == true
  })
  if not packet then return nil, err end
  return packet.payload
end

function service:ghostLiveComputers()
  if malcraftBusAvailable() and type(malcraft_bus.listComputers) == "function" then
    local data = jsonDecode(malcraft_bus.listComputers())
    if data and type(data.computers) == "table" then
      return data.computers
    end
    return {}, nil
  end

  return nil, "Malcraft Bridge 0.11.0 requis pour lister les Computers charges sans LinkOS."
end

function service:ghostList()
  if malcraftBusAvailable() then
    local data = jsonDecode(malcraft_bus.listInfected())
    if data then
      -- The Bridge is the authoritative low-latency host registry. Physical
      -- disk state is read directly from the inserted CC:Tweaked disks.
      data.disks = data.disks or {}
      return data
    end
  end

  local supported, supportErr = self:ensureGhostSupport()
  if not supported then return nil, supportErr end

  local packet, err = self:request("GHOST_LIST")
  if not packet then return nil, err end
  return packet.payload
end

function service:ghostDiskSet(diskId, infected)
  local supported, supportErr = self:ensureGhostSupport()
  if not supported then
    -- A physical Malcraft carrier marker still works without the MER. The
    -- caller writes/removes that marker locally before reaching this function.
    if malcraftBusAvailable() then
      return {
        disk_id = tonumber(diskId),
        state = {infected = infected ~= false},
        transport = "physical_carrier"
      }
    end
    return nil, supportErr
  end

  local packet, err = self:request("GHOST_DISK_SET", {
    disk_id = tonumber(diskId),
    infected = infected ~= false
  })
  if not packet then return nil, err end
  return packet.payload
end

function service:ghostRemote(targetId, action, argument)
  targetId = tonumber(targetId)
  if not targetId then return nil, "ID cible invalide." end

  action = tostring(action or "")
  argument = argument or {}

  if malcraftBusAvailable() and type(malcraft_bus.send) == "function" then
    if action == "turn_on" or action == "power_on" then
      local ok = malcraft_bus.power(targetId, "on")
      return ok and {action="on", transport="malcraft_bridge"}
        or nil, ok and nil or "Impossible d'allumer cette cible."
    end

    local requestId = util.requestId()
    local sent = malcraft_bus.send(
      targetId,
      requestId,
      action,
      jsonEncode(argument)
    )

    if sent then
      local timer = os.startTimer(4)

      while true do
        local event, a, b, d, e, f = os.pullEvent()

        if event == "timer" and a == timer then
          return nil, "Malcraft Bridge: cible hors ligne ou sans agent actif."
        end

        if event == "malcraft_bus_response"
          and tonumber(a) == targetId
          and tostring(b) == tostring(requestId) then

          local ok = d == true
          local payload = jsonDecode(e) or {}

          if ok then return payload end
          return nil, tostring(f or "Commande Malcraft refusee.")
        end

        if event == "rednet_message" then
          local sender, message, protocol = a, b, d
          if protocol == config.HACK_PROTOCOL then
            hack.handleRednet(sender, message, protocol, storage)
          end
        elseif event == "modem_message" then
          hack.handleModem(self.modemName, b, d, e, f)
        end
      end
    end
  end

  local requestId = util.requestId()
  rednet.send(targetId, {
    magic = "GHOSTLINK_GAMEPLAY",
    type = "COMMAND",
    source_id = os.getComputerID(),
    request_id = requestId,
    payload = {
      action = action,
      argument = argument
    }
  }, "astralnet.ghostlink.v1")

  local timer = os.startTimer(4)

  while true do
    local event, a, message, protocol = os.pullEvent()

    if event == "timer" and a == timer then
      return nil, "Agent Malcraft hors-ligne ou cible indisponible."
    end

    if event == "rednet_message"
      and tonumber(a) == targetId
      and protocol == "astralnet.ghostlink.v1"
      and type(message) == "table"
      and message.magic == "GHOSTLINK_GAMEPLAY"
      and message.type == "COMMAND_RESULT"
      and message.reply_to == requestId then

      if message.ok == true then
        return message.payload or {}
      end

      return nil, message.error or "Commande Malcraft refusee."
    end
  end
end

function service:history(peerId, limit)
  return storage.conversation(tonumber(peerId), limit or 100)
end

function service:recent(limit)
  return storage.recent(limit or 100)
end

function service:peers()
  local seen = {}
  local peers = {}
  local myId = os.getComputerID()

  for _, message in ipairs(storage.recent(500)) do
    local fromId = tonumber(message.from_id)
    local toId = tonumber(message.to_id)
    local peer = fromId == myId and toId or fromId

    if peer and peer ~= myId then
      if not seen[peer] then
        seen[peer] = {
          id = peer,
          count = 0,
          last = nil
        }
        peers[#peers + 1] = seen[peer]
      end

      local entry = seen[peer]
      entry.count = entry.count + 1
      entry.last = message
    end
  end

  table.sort(peers, function(a, b)
    local at = a.last and a.last.sent_at or 0
    local bt = b.last and b.last.sent_at or 0
    return at > bt
  end)

  return peers
end

function service:markRead()
  self.unread = 0
end

function service:isHackOperator()
  return hack.isOperator()
end

function service:scan()
  if not self.modemName then return nil, "Modem absent." end
  return hack.scan(self.modemName, 2)
end

function service:hack(targetId)
  if not self.modemName then return nil, "Modem absent." end

  local session, err = hack.attack(self.modemName, tonumber(targetId))
  if not session then return nil, err end

  self.hackSessions[tonumber(targetId)] = session
  return session
end

function service:sessions()
  local out = {}
  for id, session in pairs(self.hackSessions) do
    out[#out + 1] = {
      id = id,
      token = session.token,
      expires_at = session.expires_at
    }
  end
  table.sort(out, function(a, b) return a.id < b.id end)
  return out
end

function service:remote(targetId, action, argument)
  targetId = tonumber(targetId)
  local session = self.hackSessions[targetId]

  if not session then
    return nil, "Aucune session sur PC #" .. tostring(targetId) .. "."
  end

  return hack.remote(targetId, session.token, action, argument)
end

function service:handleEvent(event, a, b, c, d, e)
  if event == "timer" and self.updateTimer and a == self.updateTimer then
    self.updateTimer = nil
    self:checkUpdate()
    self:startUpdateMonitor()
    return true

  elseif event == "modem_message" then
    hack.handleModem(self.modemName, b, c, d, e)
    return true

  elseif event == "rednet_message" then
    local sender, message, protocol = a, b, c

    if hack.handleRednet(sender, message, protocol, storage) then
      return true
    end

    if sender == self.serverId
      and protocol == config.PROTOCOL
      and network.isPacket(message)
      and message.type == "MESSAGE_EVENT" then

      if storage.add(message.payload) then
        self.unread = self.unread + 1
        os.queueEvent("linkos_refresh")
      end
      return true
    end
  end

  return false
end

return service
