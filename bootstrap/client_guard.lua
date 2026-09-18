local ROOT = "/computer-link"
local BASE = "https://raw.githubusercontent.com/nexox9official-source/computer-link/main/"

local function readAll(path)
  if not fs.exists(path) then return nil end
  local f = fs.open(path, "r")
  if not f then return nil end
  local value = f.readAll()
  f.close()
  return value
end

local function writeAll(path, content)
  local dir = fs.getDir(path)
  if dir ~= "" and not fs.exists(dir) then fs.makeDir(dir) end
  local f = fs.open(path, "w")
  if not f then return false end
  f.write(content)
  f.close()
  return true
end

local function get(url)
  if not http or not http.get then return nil end
  local response = http.get(url)
  if not response then return nil end
  local value = response.readAll()
  response.close()
  return value
end

local function policy()
  local ok, value = pcall(require, "computer_link_policy")
  if ok and type(value) == "table" then return value end
  return nil
end

local function role()
  local value = readAll(ROOT .. "/role.txt")
  if not value then return nil end
  return value:gsub("%s+", "")
end

local function listContainsId(map, id)
  return type(map) == "table" and map[tonumber(id)] == true
end

local function removeTree(path)
  if fs.exists(path) then pcall(fs.delete, path) end
end

local function roleFiles(manifest, currentRole)
  local out, seen = {}, {}
  local function add(list)
    for _, path in ipairs(list or {}) do
      if not seen[path] then
        seen[path] = true
        out[#out + 1] = path
      end
    end
  end

  add(manifest.common_files)
  if currentRole == "server" then
    add(manifest.server_files)
  else
    add(manifest.client_files)
  end
  return out
end

local function restoreOfficialFiles(currentRole)
  local source = get(BASE .. "manifest.lua?t=" .. tostring(os.epoch and os.epoch("utc") or os.time()))
  if not source then return false end

  local loader = load(source, "@computer_link_guard_manifest.lua", "t", {})
  if not loader then return false end

  local ok, manifest = pcall(loader)
  if not ok or type(manifest) ~= "table" then return false end

  local protected = roleFiles(manifest, currentRole)
  if #protected == 0 then
    protected = manifest.files or {}
  end

  for _, path in ipairs(protected) do
    local official = get(BASE .. path)
    if official then
      local destination = ROOT .. "/" .. path
      local localCopy = readAll(destination)
      if localCopy ~= official then
        writeAll(destination, official)
      end
    end
  end

  return true
end

local function enforceStartup()
  local expected = [[-- Computer Link / LinkOS
shell.run("/computer-link/boot.lua")
]]
  if readAll("/startup.lua") ~= expected then
    writeAll("/startup.lua", expected)
  end
end

local function cleanupClient()
  removeTree(ROOT .. "/src/server")
  removeTree(ROOT .. "/src/client/cli.lua")
  removeTree(ROOT .. "/uninstall.lua")

  for _, path in ipairs({
    ROOT .. "/src/client/hack.lua",
    ROOT .. "/src/client/hacked_state.lua",
    ROOT .. "/src/os/hacker_console.lua"
  }) do
    removeTree(path)
  end
end

local currentRole = role()
if not currentRole then return end

local p = policy()
if not p or p.lockdown_clients ~= true then
  enforceStartup()
  return
end

local id = os.getComputerID()

if currentRole == "server" then
  local trusted = p.trusted_mer_ids
  local hasTrusted = type(trusted) == "table" and next(trusted) ~= nil

  if listContainsId(p.deny_mer_ids, id) then
    writeAll(ROOT .. "/role.txt", "client\n")
    currentRole = "client"
  elseif hasTrusted and not listContainsId(trusted, id) then
    writeAll(ROOT .. "/role.txt", "client\n")
    currentRole = "client"
  end
end

enforceStartup()

if currentRole == "client" then
  cleanupClient()
end

-- Repare silencieusement les fichiers systeme LinkOS avant le startup utilisateur.
restoreOfficialFiles(currentRole)
