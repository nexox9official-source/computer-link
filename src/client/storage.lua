local config = dofile("/computer-link/src/common/config.lua")
local util = dofile("/computer-link/src/common/util.lua")

local storage = {}

local state = {
  schema = 1,
  messages = {},
  seen = {}
}

local function normalise()
  state.schema = state.schema or 1
  state.messages = state.messages or {}
  state.seen = state.seen or {}
end

function storage.load()
  util.ensureDir(config.DATA_DIR)
  state = util.loadTable(config.HISTORY_FILE, state)
  normalise()
  return state
end

function storage.save()
  normalise()
  return util.saveTable(config.HISTORY_FILE, state)
end

function storage.add(message)
  if type(message) ~= "table" then return false end

  local id = tostring(message.id or "")
  if id ~= "" and state.seen[id] then
    return false
  end

  message.id = id ~= "" and id or util.requestId()
  state.seen[message.id] = true
  state.messages[#state.messages + 1] = message

  while #state.messages > config.LOCAL_HISTORY_MAX do
    local removed = table.remove(state.messages, 1)
    if removed and removed.id then
      state.seen[removed.id] = nil
    end
  end

  storage.save()
  return true
end

function storage.conversation(peerId, limit)
  peerId = tonumber(peerId)
  limit = tonumber(limit) or 50

  local out = {}
  local myId = os.getComputerID()

  for i = #state.messages, 1, -1 do
    local m = state.messages[i]
    local fromId = tonumber(m.from_id)
    local toId = tonumber(m.to_id)

    if (fromId == myId and toId == peerId)
      or (fromId == peerId and toId == myId) then
      table.insert(out, 1, m)
      if #out >= limit then break end
    end
  end

  return out
end

function storage.recent(limit)
  limit = tonumber(limit) or 25
  local out = {}
  local first = math.max(1, #state.messages - limit + 1)

  for i = first, #state.messages do
    out[#out + 1] = state.messages[i]
  end

  return out
end

function storage.conversationIndex()
  local myId = os.getComputerID()
  local peers = {}

  for _, message in ipairs(state.messages) do
    local fromId = tonumber(message.from_id)
    local toId = tonumber(message.to_id)
    local peerId = fromId == myId and toId or fromId

    if peerId and peerId ~= myId then
      local key = tostring(peerId)
      local item = peers[key]

      if not item then
        item = {
          peer_id = peerId,
          count = 0,
          last = nil
        }
        peers[key] = item
      end

      item.count = item.count + 1
      item.last = message
    end
  end

  local out = {}
  for _, item in pairs(peers) do
    out[#out + 1] = item
  end

  table.sort(out, function(a, b)
    local at = a.last and tonumber(a.last.sent_at) or 0
    local bt = b.last and tonumber(b.last.sent_at) or 0
    return at > bt
  end)

  return out
end

function storage.count()
  return #state.messages
end

return storage
