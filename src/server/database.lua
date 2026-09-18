local config = dofile("/computer-link/src/common/config.lua")
local util = dofile("/computer-link/src/common/util.lua")

local database = {}

local state = {
  schema = 3,
  devices = {},
  queues = {},
  ghost_hosts = {},
  ghost_disks = {}
}

local function normalise()
  state.schema = 3
  state.devices = state.devices or {}
  state.queues = state.queues or {}
  state.ghost_hosts = state.ghost_hosts or {}
  state.ghost_disks = state.ghost_disks or {}
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

function database.ghostHost(computerId)
  local key = tostring(tonumber(computerId) or computerId)
  local value = state.ghost_hosts[key]
  if type(value) ~= "table" then
    return {infected=false, spread=false}
  end
  return value
end

function database.setGhostHost(computerId, infected, actorId, spread)
  computerId = tonumber(computerId)
  if not computerId then return nil end

  local key = tostring(computerId)

  if infected then
    local current = state.ghost_hosts[key] or {}
    current.infected = true
    if spread ~= nil then current.spread = spread == true end
    if current.spread == nil then current.spread = true end
    current.actor_id = tonumber(actorId) or actorId
    current.updated_at = util.now()
    current.created_at = current.created_at or current.updated_at
    state.ghost_hosts[key] = current
  else
    state.ghost_hosts[key] = nil
  end

  database.save()
  return database.ghostHost(computerId)
end

function database.listGhostHosts()
  local out = {}
  for key, value in pairs(state.ghost_hosts) do
    if type(value) == "table" and value.infected == true then
      out[#out + 1] = {
        computer_id = tonumber(key) or key,
        infected = true,
        spread = value.spread == true,
        actor_id = value.actor_id,
        created_at = value.created_at,
        updated_at = value.updated_at
      }
    end
  end
  table.sort(out, function(a, b)
    return tonumber(a.computer_id) < tonumber(b.computer_id)
  end)
  return out
end

function database.ghostDisk(diskId)
  local key = tostring(tonumber(diskId) or diskId)
  local value = state.ghost_disks[key]
  if type(value) ~= "table" then
    return {infected=false}
  end
  return value
end

function database.setGhostDisk(diskId, infected, actorId)
  diskId = tonumber(diskId)
  if not diskId then return nil end

  local key = tostring(diskId)

  if infected then
    local current = state.ghost_disks[key] or {}
    current.infected = true
    current.actor_id = tonumber(actorId) or actorId
    current.updated_at = util.now()
    current.created_at = current.created_at or current.updated_at
    state.ghost_disks[key] = current
  else
    state.ghost_disks[key] = nil
  end

  database.save()
  return database.ghostDisk(diskId)
end

function database.listGhostDisks()
  local out = {}
  for key, value in pairs(state.ghost_disks) do
    if type(value) == "table" and value.infected == true then
      out[#out + 1] = {
        disk_id = tonumber(key) or key,
        infected = true,
        actor_id = value.actor_id,
        created_at = value.created_at,
        updated_at = value.updated_at
      }
    end
  end
  table.sort(out, function(a, b)
    return tonumber(a.disk_id) < tonumber(b.disk_id)
  end)
  return out
end

return database
