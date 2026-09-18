local config = dofile("/computer-link/src/common/config.lua")
local util = dofile("/computer-link/src/common/util.lua")

local security = {}
local PATH = config.DATA_DIR .. "/security.db"

local DEFAULTS = {
  schema = 1,
  enabled = false,
  salt = nil,
  password_hash = nil,
  auto_lock_seconds = 15
}

local state = nil

local function hashRaw(value)
  local h = 5381
  value = tostring(value or "")
  for i = 1, #value do
    h = (h * 33 + string.byte(value, i)) % 2147483647
  end
  return tostring(h)
end

local function normalize(value)
  value = type(value) == "table" and value or {}
  for key, default in pairs(DEFAULTS) do
    if value[key] == nil then value[key] = default end
  end
  return value
end

local function save()
  util.ensureDir(config.DATA_DIR)
  return util.saveTable(PATH, state)
end

function security.load()
  if state then return state end
  state = normalize(util.loadTable(PATH, {}))
  return state
end

function security.hashPassword(password, salt)
  return hashRaw(tostring(salt or "") .. ":" .. tostring(password or ""))
end

function security.enabled()
  return security.load().enabled == true
end

function security.info()
  local s = security.load()
  return {
    enabled = s.enabled == true,
    salt = s.salt,
    password_hash = s.password_hash,
    auto_lock_seconds = tonumber(s.auto_lock_seconds) or 15
  }
end

function security.verify(password)
  local s = security.load()
  if not s.enabled then return true end
  if not s.salt or not s.password_hash then return false end
  return security.hashPassword(password, s.salt) == tostring(s.password_hash)
end

function security.setPassword(password)
  password = tostring(password or "")
  if #password < 4 then
    return false, "Le mot de passe doit faire au moins 4 caracteres."
  end
  if #password > 32 then
    return false, "Le mot de passe est trop long (32 caracteres max)."
  end

  local s = security.load()
  s.salt = tostring(util.now())
    .. ":" .. tostring(os.getComputerID())
    .. ":" .. tostring(math.random(100000, 999999))
  s.password_hash = security.hashPassword(password, s.salt)
  s.enabled = true
  save()
  return true
end

function security.disable(password)
  local s = security.load()
  if s.enabled and not security.verify(password) then
    return false, "Mot de passe incorrect."
  end

  s.enabled = false
  s.salt = nil
  s.password_hash = nil
  save()
  return true
end

function security.setAutoLock(seconds)
  seconds = tonumber(seconds)
  if not seconds then return false end
  seconds = math.max(5, math.min(300, math.floor(seconds)))
  local s = security.load()
  s.auto_lock_seconds = seconds
  save()
  return true
end

function security.autoLockSeconds()
  return tonumber(security.load().auto_lock_seconds) or 15
end

return security
