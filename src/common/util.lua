local util = {}

function util.trim(value)
  if type(value) ~= "string" then return "" end
  return value:match("^%s*(.-)%s*$") or ""
end

function util.now()
  if os.epoch then
    local ok, value = pcall(os.epoch, "utc")
    if ok then return math.floor(value / 1000) end
  end
  return math.floor(os.time() * 3600)
end

function util.count(tbl)
  local n = 0
  for _ in pairs(tbl or {}) do n = n + 1 end
  return n
end

function util.ensureDir(path)
  if not fs.exists(path) then
    fs.makeDir(path)
  end
end

function util.readAll(path)
  if not fs.exists(path) then return nil end
  local file = fs.open(path, "r")
  if not file then return nil end
  local content = file.readAll()
  file.close()
  return content
end

function util.writeAll(path, content)
  local dir = fs.getDir(path)
  if dir and dir ~= "" then
    util.ensureDir(dir)
  end

  local file = fs.open(path, "w")
  if not file then
    return false, "Impossible d'ouvrir " .. path
  end

  file.write(content)
  file.close()
  return true
end

function util.loadTable(path, fallback)
  local content = util.readAll(path)
  if not content or content == "" then
    return fallback
  end

  local ok, value = pcall(textutils.unserialize, content)
  if ok and type(value) == "table" then
    return value
  end

  return fallback
end

function util.saveTable(path, value)
  return util.writeAll(path, textutils.serialize(value))
end

function util.requestId()
  return tostring(os.getComputerID())
    .. "-" .. tostring(util.now())
    .. "-" .. tostring(math.random(100000, 999999))
end

return util
