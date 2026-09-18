local BASE = "https://raw.githubusercontent.com/nexox9official-source/computer-link/main/"
local ROOT = "/computer-link"

local function readAll(path)
  if not fs.exists(path) then return nil end
  local f = fs.open(path, "r")
  if not f then return nil end
  local value = f.readAll()
  f.close()
  return value
end

local function currentRole()
  local value = readAll(ROOT .. "/role.txt")
  if not value then return "client" end
  value = value:gsub("%s+", "")
  if value == "server" then return "server" end
  return "client"
end

local function download(path)
  local response, err = http.get(BASE .. path)

  if not response then
    return false, err or "HTTP error"
  end

  local content = response.readAll()
  response.close()

  local destination = ROOT .. "/" .. path
  local dir = fs.getDir(destination)

  if dir ~= "" and not fs.exists(dir) then
    fs.makeDir(dir)
  end

  local file = fs.open(destination, "w")
  if not file then
    return false, "Impossible d'ecrire " .. destination
  end

  file.write(content)
  file.close()
  return true
end

local function roleFiles(manifest, role)
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

  if role == "server" then
    add(manifest.server_files)
  else
    add(manifest.client_files)
  end

  if #out == 0 then
    add(manifest.files)
  end

  return out
end

local function cleanup(role)
  local paths = {
    ROOT .. "/src/client/hack.lua",
    ROOT .. "/src/client/hacked_state.lua",
    ROOT .. "/src/os/hacker_console.lua"
  }

  if role == "client" then
    paths[#paths + 1] = ROOT .. "/src/server"
    paths[#paths + 1] = ROOT .. "/src/client/cli.lua"
    paths[#paths + 1] = ROOT .. "/uninstall.lua"
  else
    paths[#paths + 1] = ROOT .. "/src/ui"
    paths[#paths + 1] = ROOT .. "/src/os"
  end

  for _, path in ipairs(paths) do
    if fs.exists(path) then pcall(fs.delete, path) end
  end
end

print("Computer Link - mise a jour")

if not http or not http.get then
  error("HTTP indisponible.")
end

local manifestResponse, manifestError = http.get(BASE .. "manifest.lua?t="
  .. tostring(os.epoch and os.epoch("utc") or os.time()))
if not manifestResponse then
  error("Manifest inaccessible: " .. tostring(manifestError))
end

local manifestSource = manifestResponse.readAll()
manifestResponse.close()

local loader, loadError = load(manifestSource, "@manifest.lua", "t", {})
if not loader then
  error(loadError)
end

local okManifest, manifest = pcall(loader)
if not okManifest or type(manifest) ~= "table" then
  error("Manifest invalide.")
end

local role = currentRole()
local files = roleFiles(manifest, role)

print("Role: " .. string.upper(role))
print("Version distante: " .. tostring(manifest.version))

for index, path in ipairs(files) do
  write("[" .. index .. "/" .. #files .. "] " .. path .. " ... ")
  local ok, err = download(path)

  if ok then
    term.setTextColor(colors.lime)
    print("OK")
  else
    term.setTextColor(colors.red)
    print("ERREUR")
    term.setTextColor(colors.white)
    error(tostring(err))
  end

  term.setTextColor(colors.white)
end

cleanup(role)

print("Mise a jour terminee.")
