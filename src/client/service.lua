local config = dofile("/computer-link/src/common/config.lua")
local util = dofile("/computer-link/src/common/util.lua")
local network = dofile("/computer-link/src/common/network.lua")
local storage = dofile("/computer-link/src/client/storage.lua")
local hack = dofile("/computer-link/src/client/hack.lua")

local service = {}
service.__index = service

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
  return self
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
  if event == "modem_message" then
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
