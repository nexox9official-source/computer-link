local config = dofile("/computer-link/src/common/config.lua")
local util = dofile("/computer-link/src/common/util.lua")

local state = {}

local function load()
  local data = util.loadTable(config.HACKED_STATE_FILE, {})
  if type(data) ~= "table" then data = {} end
  return data
end

function state.get()
  return load()
end

function state.isLocked()
  local data = load()
  return data.locked == true, data
end

function state.lock(sourceId, message)
  local data = {
    locked = true,
    source_id = tonumber(sourceId),
    message = tostring(message or ""),
    locked_at = util.now()
  }
  util.saveTable(config.HACKED_STATE_FILE, data)
  os.queueEvent("linkos_hacked_state")
  return data
end

function state.unlock()
  if fs.exists(config.HACKED_STATE_FILE) then
    fs.delete(config.HACKED_STATE_FILE)
  end
  os.queueEvent("linkos_hacked_state")
end

function state.flash(sourceId, message)
  local data = load()
  data.flash = {
    source_id = tonumber(sourceId),
    message = tostring(message or ""),
    at = util.now()
  }
  util.saveTable(config.HACKED_STATE_FILE, data)
  os.queueEvent("linkos_hacked_state")
  return data.flash
end

function state.clearFlash()
  local data = load()
  if data.flash then
    data.flash = nil
    if data.locked then
      util.saveTable(config.HACKED_STATE_FILE, data)
    elseif fs.exists(config.HACKED_STATE_FILE) then
      fs.delete(config.HACKED_STATE_FILE)
    end
  end
end

return state
