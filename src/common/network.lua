local config = dofile("/computer-link/src/common/config.lua")

local network = {}

local function isWirelessModem(name)
  if peripheral.getType(name) ~= "modem" then
    return false
  end

  local modem = peripheral.wrap(name)
  if not modem then return false end

  if type(modem.isWireless) == "function" then
    local ok, value = pcall(modem.isWireless)
    return ok and value == true
  end

  return false
end

function network.findWirelessModem()
  for _, name in ipairs(peripheral.getNames()) do
    if isWirelessModem(name) then
      return name
    end
  end
  return nil
end

function network.open()
  local modemName = network.findWirelessModem()

  if not modemName then
    return false, "Aucun Wireless Modem detecte."
  end

  if not rednet.isOpen(modemName) then
    rednet.open(modemName)
  end

  return true, modemName
end

function network.packet(kind, payload, requestId)
  return {
    magic = config.MAGIC,
    protocol_version = config.PROTOCOL_VERSION,
    type = kind,
    source_id = os.getComputerID(),
    payload = payload or {},
    request_id = requestId,
    sent_at = os.epoch and os.epoch("utc") or os.time()
  }
end

function network.isPacket(value)
  return type(value) == "table"
    and value.magic == config.MAGIC
    and value.protocol_version == config.PROTOCOL_VERSION
    and type(value.type) == "string"
end

function network.findServer()
  local serverId = rednet.lookup(config.PROTOCOL, config.SERVER_HOSTNAME)
  if not serverId then return nil end

  local ok, policy = pcall(require, "computer_link_policy")
  if ok and type(policy) == "table"
    and type(policy.trusted_mer_ids) == "table"
    and next(policy.trusted_mer_ids) ~= nil then

    if policy.trusted_mer_ids[tonumber(serverId)] ~= true then
      return nil
    end
  end

  return serverId
end

return network
