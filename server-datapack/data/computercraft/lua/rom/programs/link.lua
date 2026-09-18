local URL = "https://raw.githubusercontent.com/nexox9official-source/computer-link/main/bootstrap/link.lua"
local args = { ... }

local function colour(c)
  if term.isColor and term.isColor() then term.setTextColor(c) end
end

if not http or not http.get then
  colour(colors.red)
  print("Computer Link: HTTP indisponible.")
  colour(colors.white)
  return
end

local response, err = http.get(URL)
if not response then
  colour(colors.red)
  print("Computer Link bootstrap inaccessible:")
  print(tostring(err))
  colour(colors.white)
  return
end

local source = response.readAll()
response.close()

local loader, loadErr = load(source, "@link_bootstrap.lua", "t", _ENV)
if not loader then
  colour(colors.red)
  print("Bootstrap LinkOS invalide:")
  print(tostring(loadErr))
  colour(colors.white)
  return
end

local unpackArgs = table.unpack or unpack
local ok, runErr = pcall(loader, unpackArgs(args))
if not ok then
  colour(colors.red)
  print("Erreur LinkOS:")
  print(tostring(runErr))
  colour(colors.white)
end
