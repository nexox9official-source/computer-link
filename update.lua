local BASE = "https://raw.githubusercontent.com/nexox9official-source/computer-link/main/"
local ROOT = "/computer-link"

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

print("Computer Link - mise a jour")

local manifestResponse, manifestError = http.get(BASE .. "manifest.lua")
if not manifestResponse then
  error("Manifest inaccessible: " .. tostring(manifestError))
end

local manifestSource = manifestResponse.readAll()
manifestResponse.close()

local loader, loadError = load(manifestSource, "@manifest.lua", "t", {})
if not loader then
  error(loadError)
end

local manifest = loader()
print("Version distante: " .. tostring(manifest.version))

for index, path in ipairs(manifest.files) do
  write("[" .. index .. "/" .. #manifest.files .. "] " .. path .. " ... ")
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

print("Mise a jour terminee.")
