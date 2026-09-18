local config = dofile("/computer-link/src/common/config.lua")
local util = dofile("/computer-link/src/common/util.lua")

local database = {}

local state = {
  schema = 2,
  devices = {},
  queues = {}
}

local function normalise()
  state.schema = 2
  state.devices = state.devices or {}
  state.queues = state.queues or {}
end

function database.load()
  util.ensureDir(config.DATA_DIR)
  state = util.loadTable(config.DATABASE_FILE, state)
  normalise()
  return state
end

function database.save()
  normalise()
  return util.saveTable(config.DATABASE_FILE, state)
end

function database.get()
  return state
end

function database.getDevice(computerId)
  return state.devices[tostring(tonumber(computerId) or computerId)]
end

function database.registerDevice(computerId, label)
  computerId = tonumber(computerId)
  if not computerId then return nil end

  local key = tostring(computerId)
  local now = util.now()
  local device = state.devices[key]

  if not device then
    device = {
      computer_id = computerId,
      first_seen = now
    }
    state.devices[key] = device
  end

  device.last_seen = now

  if type(label) == "string" and label ~= "" then
    device.label = string.sub(label, 1, 32)
  end

  state.queues[key] = state.queues[key] or {}
  database.save()
  return device
end

function database.touch(computerId)
  local device = database.getDevice(computerId)
  if device then
    device.last_seen = util.now()
  end
  return device
end

function database.countDevices()
  local count = 0
  for _ in pairs(state.devices) do count = count + 1 end
  return count
end

function database.queueMessage(fromId, toId, body)
  fromId = tonumber(fromId)
  toId = tonumber(toId)
  if not fromId or not toId then return nil end

  local key = tostring(toId)
  state.queues[key] = state.queues[key] or {}

  local entry = {
    id = util.requestId(),
    from_id = fromId,
    to_id = toId,
    body = body,
    sent_at = util.now()
  }

  state.queues[key][#state.queues[key] + 1] = entry
  database.save()
  return entry
end

function database.takeQueue(computerId)
  local key = tostring(tonumber(computerId) or computerId)
  local messages = state.queues[key] or {}
  state.queues[key] = {}
  database.save()
  return messages
end

return database
