local config = dofile("/computer-link/src/common/config.lua")
local draw = dofile("/computer-link/src/ui/draw.lua")
local display = dofile("/computer-link/src/ui/display.lua")
local prefs = dofile("/computer-link/src/ui/prefs.lua")
local shellui = dofile("/computer-link/src/ui/shell.lua")
local hackedState = dofile("/computer-link/src/client/system_state.lua")
local security = dofile("/computer-link/src/client/security.lua")
local Service = dofile("/computer-link/src/client/service.lua")
local HackerConsole = dofile("/computer-link/src/os/operator_console.lua")
local RemoteDesktop = dofile("/computer-link/src/os/remote_desktop.lua")

local LinkOS = {}
LinkOS.__index = LinkOS

local ACCENTS = {
  cyan = colors.cyan,
  blue = colors.blue,
  lime = colors.lime,
  orange = colors.orange,
  purple = colors.purple,
  red = colors.red
}


local function nowText()
  return textutils.formatTime(os.time(), true)
end

local function epochSeconds()
  if os.epoch then
    local ok, value = pcall(os.epoch, "utc")
    if ok then return math.floor(value / 1000) end
  end
  return math.floor(os.time() * 3600)
end

local function clamp(value, minValue, maxValue)
  return math.max(minValue, math.min(maxValue, value))
end

local function humanBytes(value)
  value = tonumber(value) or 0
  if value >= 1024 * 1024 then
    return string.format("%.1f MB", value / (1024 * 1024))
  elseif value >= 1024 then
    return string.format("%.1f KB", value / 1024)
  end
  return tostring(value) .. " B"
end

function LinkOS.new()
  local self = setmetatable({}, LinkOS)
  self.service = Service.new()
  self.native = term.current()
  self.displays = {}
  self.active = nil
  self.buttons = {}
  self.app = prefs.get("last_app", "home")
  self.selectedPeer = nil
  self.scanResults = {}
  self.filePath = "/user"
  if not fs.exists("/user") then fs.makeDir("/user") end
  self.filePreview = nil
  self.notice = nil
  self.noticeColour = colors.lightGray
  self.running = true
  self.connectionError = nil
  self.hackerConsole = HackerConsole.new(self.service)
  self.sessionLocked = security.enabled()
  self.lastActivity = os.clock()
  self.lockTimer = nil
  self.failedUnlocks = 0
  self.companionButtons = {}
  self.linksecView = "home"
  self.linksecConversations = {}
  self.linksecConversationPeer = nil
  self.linksecConversationMessages = {}
  self.linksecTargets = {}
  self.linksecDevices = {}
  self.linksecDevice = nil
  self.linksecDeviceResult = nil
  self.linksecRedstone = {}
  self.linksecDrives = {}
  self.ghostState = nil
  self.ghostDevices = {}
  self.ghostDevice = nil
  self.ghostDeviceResult = nil
  self.ghostRedstone = {}
  self.ghostDrives = {}
  self.ghostDiskStates = {}
  self.ghostInventories = {}
  self.ghostNearbyComputers = {}
  self.malcraftHosts = {}
  self.malcraftLiveHosts = {}
  self.malcraftLocalDisks = {}
  self.malcraftTarget = nil
  self.startMenuOpen = false
  self.quickPanelOpen = false
  self.appSwitcherOpen = false
  self.previousApp = "home"
  self.calculatorExpression = ""
  self.calculatorResult = "Pret"
  return self
end

function LinkOS:theme()
  local accentName = prefs.get("accent", "cyan")
  local accent = ACCENTS[accentName] or colors.cyan

  return {
    bg = colors.black,
    panel = colors.black,
    panel2 = colors.gray,
    text = colors.white,
    muted = colors.lightGray,
    accent = accent,
    good = colors.lime,
    warn = colors.orange,
    danger = colors.red,
    sidebar = colors.black,
    button = colors.gray
  }
end

function LinkOS:isOperatorUI()
  -- Visibility follows the same read-only ROM policy as the actual LinkSec
  -- authorization. Only explicitly authorised Computer IDs receive the app.
  return self.service:isHackOperator()
end

function LinkOS:refreshDisplays()
  local selected = prefs.get("display_id")
  self.displays, self.active = display.refresh(selected)

  if self.active and self.active.id ~= selected then
    prefs.set("display_id", self.active.id)
  end
end

function LinkOS:addButton(id, x, y, w, h, callback)
  self.buttons[#self.buttons + 1] = {
    id = id, x = x, y = y, w = w, h = h, callback = callback
  }
end

function LinkOS:button(target, id, x, y, w, label, callback, selected)
  local t = self:theme()
  draw.button(target, x, y, w, label, t.text, selected and t.accent or t.button, false)
  self:addButton(id, x, y, w, 1, callback)
end

function LinkOS:setNotice(text, colour)
  self.notice = tostring(text or "")
  self.noticeColour = colour or colors.lightGray
  self.noticeExpires = os.clock() + 3.5

  self.notificationHistory = self.notificationHistory or {}
  if self.notice ~= "" then
    table.insert(self.notificationHistory, 1, {
      text = self.notice,
      colour = self.noticeColour,
      time = textutils.formatTime(os.time(), true)
    })
    while #self.notificationHistory > 6 do
      table.remove(self.notificationHistory)
    end
  end
end

function LinkOS:openApp(id)
  id = tostring(id or "home")

  if not shellui.allowed(id, self:isOperatorUI()) then
    id = "home"
    self:setNotice("Application indisponible sur ce PC.", self:theme().warn)
  else
    self.notice = nil
    self.noticeExpires = nil
  end

  if self.app ~= id then
    self.previousApp = self.app
  end

  self.app = id
  self.startMenuOpen = false
  self.quickPanelOpen = false
  self.appSwitcherOpen = false
  prefs.set("last_app", id)

  if id == "messages" then
    self.service:markRead()
  end

  self:render()
end

function LinkOS:toggleStartMenu()
  self.startMenuOpen = not self.startMenuOpen
  self.quickPanelOpen = false
  self.appSwitcherOpen = false
end

function LinkOS:toggleQuickPanel()
  self.quickPanelOpen = not self.quickPanelOpen
  self.startMenuOpen = false
  self.appSwitcherOpen = false
end

function LinkOS:cycleApp(delta)
  local nextId = shellui.nextApp(self.app, self:isOperatorUI(), delta or 1)
  self:openApp(nextId)
end

function LinkOS:prompt(title, hint)
  local active = self.active
  local t = self:theme()

  if active and active.kind == "monitor" then
    local target = active.target
    local w, h = target.getSize()
    draw.fill(target, 2, math.max(2, h - 4), math.max(1, w - 2), 3, t.panel)
    draw.text(target, 3, math.max(2, h - 3), "Saisie sur l'ecran du PC...", t.warn, t.panel, math.max(1, w - 4))
  end

  local previous = term.current()
  term.redirect(self.native)
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.white)
  term.clear()
  term.setCursorPos(1, 1)
  print("Computer Link / LinkOS")
  print("----------------------")
  print(tostring(title or "Saisie"))
  if hint and hint ~= "" then
    term.setTextColor(colors.lightGray)
    print(tostring(hint))
    term.setTextColor(colors.white)
  end
  write("> ")
  local value = read()
  term.redirect(previous)

  self:render()
  return value
end

function LinkOS:confirm(title)
  local answer = string.lower(self:prompt(title, "Tape OUI pour confirmer.") or "")
  return answer == "oui" or answer == "o" or answer == "yes" or answer == "y"
end

function LinkOS:promptSecret(title, hint)
  local active = self.active
  local t = self:theme()

  if active and active.kind == "monitor" then
    local target = active.target
    local w, h = target.getSize()
    draw.fill(target, 2, math.max(2, h - 4), math.max(1, w - 2), 3, t.panel)
    draw.text(target, 3, math.max(2, h - 3), "Saisie securisee sur le Computer...", t.warn, t.panel, math.max(1, w - 4))
  end

  local previous = term.current()
  term.redirect(self.native)
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.white)
  term.clear()
  term.setCursorPos(1, 1)
  print("LinkOS Security")
  print("---------------")
  print(tostring(title or "Mot de passe"))
  if hint and hint ~= "" then
    term.setTextColor(colors.lightGray)
    print(tostring(hint))
    term.setTextColor(colors.white)
  end
  write("> ")
  local value = read("*")
  term.redirect(previous)
  return value
end

function LinkOS:configurePassword()
  local t = self:theme()

  if security.enabled() then
    local current = self:promptSecret("Mot de passe actuel")
    if not security.verify(current) then
      self:setNotice("Mot de passe incorrect.", t.danger)
      self:render()
      return
    end
  end

  local first = self:promptSecret("Nouveau mot de passe", "4 a 32 caracteres.")
  local second = self:promptSecret("Confirme le mot de passe")

  if first ~= second then
    self:setNotice("Les mots de passe ne correspondent pas.", t.danger)
    self:render()
    return
  end

  local ok, err = security.setPassword(first)
  if not ok then
    self:setNotice(tostring(err), t.danger)
  else
    self.sessionLocked = false
    self.lastActivity = os.clock()
    self:setNotice("Protection par mot de passe activee.", t.good)
  end

  self:render()
end

function LinkOS:disablePassword()
  local t = self:theme()
  if not security.enabled() then return end

  local current = self:promptSecret("Mot de passe actuel")
  local ok, err = security.disable(current)

  if ok then
    self.sessionLocked = false
    self:setNotice("Mot de passe desactive.", t.good)
  else
    self:setNotice(tostring(err), t.danger)
  end

  self:render()
end

function LinkOS:securityEnabled()
  return security.enabled()
end

function LinkOS:lockSession()
  if not security.enabled() then return end
  self.sessionLocked = true
  self:render()
end

function LinkOS:unlockSession()
  if not security.enabled() then
    self.sessionLocked = false
    return true
  end

  local password = self:promptSecret("PC verrouille", "Entre ton mot de passe LinkOS.")
  if security.verify(password) then
    self.sessionLocked = false
    self.failedUnlocks = 0
    self.lastActivity = os.clock()
    self:setNotice("Session deverrouillee.", self:theme().good)
    self:render()
    return true
  end

  self.failedUnlocks = self.failedUnlocks + 1
  self:setNotice("Mot de passe incorrect.", self:theme().danger)

  if self.failedUnlocks >= 3 then
    sleep(2)
  end

  self:render()
  return false
end

function LinkOS:openHackerTerminal()
  if not self:isOperatorUI() then return end
  self.lastActivity = os.clock()
  self.hackerConsole:runInteractive(self.active and self.active.target or self.native)
  self.lastActivity = os.clock()
  self:render()
end

function LinkOS:runUninstallAction()
  local t = self:theme()

  if not http or not http.get then
    self:setNotice("HTTP indisponible: desinstallation impossible.", t.danger)
    self:render()
    return
  end

  local response, err = http.get(config.GITHUB_RAW .. "uninstall.lua?t="
    .. tostring(os.epoch and os.epoch("utc") or os.time()))

  if not response then
    self:setNotice("Desinstallateur inaccessible: " .. tostring(err), t.danger)
    self:render()
    return
  end

  local source = response.readAll()
  response.close()

  local loader, loadErr = load(source, "@linkos_uninstall.lua", "t", _ENV)
  if not loader then
    self:setNotice("Desinstallateur invalide: " .. tostring(loadErr), t.danger)
    self:render()
    return
  end

  term.redirect(self.native)
  local ok, runErr = pcall(loader)

  if not ok then
    self:setNotice("Desinstallation impossible: " .. tostring(runErr), t.danger)
    self:render()
  end
end

function LinkOS:runUpdateAction()
  local t = self:theme()

  if self.service.updateAvailable then
    shell.run("/computer-link/update.lua")
    self.service.updateAvailable = false
    self:setNotice("Mise a jour installee. Redemarre le PC.", t.good)
  else
    local ok, err = self.service:checkUpdate()
    if not ok then
      self:setNotice("Verification impossible: " .. tostring(err), t.danger)
    elseif self.service.updateAvailable then
      self:setNotice("Nouvelle version: " .. tostring(self.service.remoteVersion), t.warn)
    else
      self:setNotice("LinkOS est a jour.", t.good)
    end
  end

  self:render()
end

function LinkOS:layout()
  if not self.active then return nil end
  local w, h = self.active.target.getSize()
  local mode = display.layoutFor(w, h)

  if mode == "compact" then
    return {
      w = w,
      h = h,
      mode = mode,
      sidebar = 0,
      top = 2,
      bottom = 1,
      contentX = 2,
      contentY = 3,
      contentW = math.max(1, w - 2),
      contentH = math.max(1, h - 4)
    }
  end

  return {
    w = w,
    h = h,
    mode = mode,
    sidebar = 0,
    top = 2,
    bottom = 2,
    contentX = 4,
    contentY = 4,
    contentW = math.max(1, w - 7),
    contentH = math.max(1, h - 8)
  }
end

function LinkOS:renderChrome(target, l)
  local t = self:theme()
  local operator = self:isOperatorUI()
  local app = shellui.find(self.app, operator) or shellui.find("home", operator)
  local appTitle = app and app.title or "Bureau"

  draw.clear(target, t.bg, t.text)

  -- Top system bar: deliberately compact so the desktop keeps most of the
  -- ComputerCraft screen. The interaction model is inspired by desktop OSes
  -- such as LevelOS, but the implementation is native LinkOS.
  draw.fill(target, 1, 1, l.w, 2, colors.black)
  draw.text(target, 2, 1, "LINKOS", t.accent, colors.black)

  if operator and l.w >= 34 then
    draw.text(target, 10, 1, "LINKSEC", colors.red, colors.black, 8)
  end

  local netText = self.service.online and "NET:ON" or "NET:OFF"
  local netColour = self.service.online and t.good or t.danger
  draw.text(target, math.max(2, l.w - #netText - 1), 1, netText, netColour, colors.black)

  local label = os.getComputerLabel() or ("PC-" .. tostring(os.getComputerID()))
  draw.text(target, 2, 2,
    appTitle .. " | " .. label .. " (#" .. tostring(os.getComputerID()) .. ")",
    t.muted, colors.black, math.max(1, l.w - 14))

  local clock = nowText()
  draw.text(target, math.max(2, l.w - #clock - 1), 2, clock, t.muted, colors.black)

  -- Update indicator remains available from every app.
  local updateLabel = self.service.updateAvailable and "UPDATE!" or "UPD"
  local updateW = #updateLabel + 2
  local updateX = math.max(8, l.w - #clock - updateW - 4)
  if updateX + updateW < l.w - #clock then
    local updateBg = self.service.updateAvailable and colors.yellow or colors.gray
    local updateFg = self.service.updateAvailable and colors.black or colors.white
    draw.button(target, updateX, 2, updateW, updateLabel, updateFg, updateBg)
    self:addButton("quick:update", updateX, 2, updateW, 1, function()
      self:runUpdateAction()
    end)
  end

  if self.app ~= "home" and l.mode ~= "compact" then
    draw.box(target, 2, 3, l.w - 2, l.h - 6, colors.black, t.panel2, appTitle)
  end

  local taskY = l.mode == "compact" and l.h or (l.h - 1)
  local taskH = l.mode == "compact" and 1 or 2
  draw.fill(target, 1, taskY, l.w, taskH, t.panel)

  local startW = l.mode == "compact" and 5 or 8
  local startLabel = l.mode == "compact" and "MENU" or "START"
  draw.button(target, 1, taskY, startW, startLabel, colors.white,
    self.startMenuOpen and t.accent or colors.black)
  self:addButton("shell:start", 1, taskY, startW, 1, function()
    self:toggleStartMenu()
    self:render()
  end)

  local quickLabel = l.mode == "compact" and "Q" or "SYS"
  local quickW = #quickLabel + 2
  local quickX = math.max(startW + 2, l.w - quickW + 1)
  draw.button(target, quickX, taskY, quickW, quickLabel, colors.white,
    self.quickPanelOpen and t.accent or colors.black)
  self:addButton("shell:quick", quickX, taskY, quickW, 1, function()
    self:toggleQuickPanel()
    self:render()
  end)

  local rightLimit = quickX - 1
  local x = startW + 2
  local showLabels = prefs.get("taskbar_labels", false)

  for _, pinned in ipairs(shellui.pinned(operator)) do
    local labelText
    if l.mode == "compact" then
      labelText = pinned.icon or string.sub(pinned.short or pinned.title, 1, 2)
    elseif showLabels then
      labelText = pinned.short or pinned.title
    else
      labelText = pinned.icon or string.sub(pinned.short or pinned.title, 1, 2)
    end

    local bw = math.max(3, #labelText + 2)
    if x + bw - 1 < rightLimit then
      local selected = self.app == pinned.id
      local bg = selected and (pinned.operator and colors.red or t.accent) or colors.black
      draw.button(target, x, taskY, bw, labelText, colors.white, bg)
      local appId = pinned.id
      self:addButton("task:" .. appId, x, taskY, bw, 1, function()
        self:openApp(appId)
      end)
      x = x + bw + 1
    end
  end

  if taskH >= 2 then
    local unread = tonumber(self.service.unread) or 0
    local second = unread > 0
      and ("Messages: " .. tostring(unread))
      or ("Libre: " .. humanBytes(fs.getFreeSpace("/")))
    draw.text(target, 2, taskY + 1, second,
      unread > 0 and t.warn or t.muted, t.panel, math.max(1, l.w - 14))
    draw.text(target, math.max(2, l.w - #config.VERSION - 1), taskY + 1,
      config.VERSION, t.muted, t.panel)
  end
end

function LinkOS:renderStartMenu(target, l)
  if not self.startMenuOpen then return end

  local t = self:theme()
  local operator = self:isOperatorUI()
  local apps = shellui.apps(operator)
  local x, y, w, h = shellui.startMenuRect(l)

  draw.box(target, x, y, w, h, colors.gray, colors.white, " LINKOS ")
  draw.text(target, x + 2, y + 1,
    os.getComputerLabel() or ("PC #" .. os.getComputerID()),
    t.accent, colors.gray, math.max(1, w - 4))

  local appTop = y + 3
  local footerRows = h >= 12 and 3 or 2
  local usable = math.max(1, h - footerRows - 4)
  local cols = w >= 34 and 2 or 1
  local gap = 1
  local cellW = math.floor((w - 3 - (cols - 1) * gap) / cols)

  for i, app in ipairs(apps) do
    local col = (i - 1) % cols
    local row = math.floor((i - 1) / cols)
    if row < usable then
      local bx = x + 2 + col * (cellW + gap)
      local by = appTop + row
      local label = tostring(app.icon or "") .. " " .. tostring(app.title)
      local selected = self.app == app.id
      local bg = selected and (app.operator and colors.red or t.accent) or colors.black
      draw.text(target, bx, by, string.rep(" ", cellW), colors.white, bg, cellW)
      draw.text(target, bx + 1, by, label, colors.white, bg, math.max(1, cellW - 2))
      local appId = app.id
      self:addButton("start:" .. appId, bx, by, cellW, 1, function()
        self:openApp(appId)
      end)
    end
  end

  local fy = y + h - 2

  local setW = math.min(11, math.max(7, math.floor((w - 4) / 3)))
  draw.button(target, x + 2, fy, setW, "SETTINGS", colors.white, colors.black)
  self:addButton("start:settings", x + 2, fy, setW, 1, function()
    self:openApp("settings")
  end)

  local lockX = x + 3 + setW
  if security.enabled() and lockX + 7 < x + w then
    draw.button(target, lockX, fy, 7, "LOCK", colors.white, colors.black)
    self:addButton("start:lock", lockX, fy, 7, 1, function()
      self.startMenuOpen = false
      self:lockSession()
    end)
  end

  local powerW = 7
  local powerX = x + w - powerW - 1
  draw.button(target, powerX, fy, powerW, "POWER", colors.white, colors.red)
  self:addButton("start:power", powerX, fy, powerW, 1, function()
    if self:confirm("Redemarrer ce PC ?") then
      os.reboot()
    end
  end)
end

function LinkOS:renderQuickPanel(target, l)
  if not self.quickPanelOpen then return end

  local t = self:theme()
  local x, y, w, h = shellui.quickPanelRect(l)
  draw.box(target, x, y, w, h, colors.gray, colors.white, " SYSTEME ")

  local row = y + 2
  local function line(label, value, colour)
    if row >= y + h - 2 then return end
    draw.text(target, x + 2, row, label, t.muted, colors.gray, math.max(1, w - 4))
    local valueText = tostring(value or "-")
    draw.text(target, math.max(x + 2, x + w - #valueText - 2), row,
      valueText, colour or colors.white, colors.gray, math.max(1, w - 4))
    row = row + 1
  end

  line("AstralNet", self.service.online and "ONLINE" or "OFFLINE",
    self.service.online and t.good or t.danger)
  line("Securite", security.enabled() and "VERROUILLEE" or "STANDARD",
    security.enabled() and t.good or t.warn)
  line("Stockage", humanBytes(fs.getFreeSpace("/")), colors.white)
  line("Affichage", self.active and self.active.label or "-", colors.white)

  local by = y + h - 2
  local bw = math.min(8, math.max(5, math.floor((w - 4) / 3)))

  draw.button(target, x + 2, by, bw, "UPDATE", colors.white,
    self.service.updateAvailable and colors.yellow or colors.black)
  self:addButton("quickpanel:update", x + 2, by, bw, 1, function()
    self:runUpdateAction()
  end)

  if security.enabled() and w >= 23 then
    draw.button(target, x + 3 + bw, by, bw, "LOCK", colors.white, colors.black)
    self:addButton("quickpanel:lock", x + 3 + bw, by, bw, 1, function()
      self.quickPanelOpen = false
      self:lockSession()
    end)
  end
end

function LinkOS:renderShellOverlays(target, l)
  if self.startMenuOpen then
    self:renderStartMenu(target, l)
  elseif self.quickPanelOpen then
    self:renderQuickPanel(target, l)
  end
end

function LinkOS:renderNotice(target, l)
  if not self.notice or self.notice == "" then return end
  local t = self:theme()
  local y = l.mode == "compact" and (l.h - 1) or (l.h - 3)
  if y <= 2 then return end
  draw.fill(target, l.contentX, y, l.contentW, 1, colors.black)
  draw.text(target, l.contentX, y, self.notice, self.noticeColour, colors.black, l.contentW)
end

function LinkOS:card(target, x, y, w, h, title, subtitle, callback)
  local t = self:theme()
  draw.box(target, x, y, w, h, t.panel, t.accent, title)

  if subtitle and h >= 3 then
    local lines = draw.wrap(subtitle, math.max(1, w - 2))
    for i = 1, math.min(#lines, h - 2) do
      draw.text(target, x + 1, y + i, lines[i], t.text, t.panel, w - 2)
    end
  end

  if callback then
    self:addButton("card:" .. title, x, y, w, h, callback)
  end
end

function LinkOS:renderHome(target, l)
  local t = self:theme()
  local x, y, w = l.contentX, l.contentY, l.contentW

  shellui.wallpaper(
    target,
    1,
    3,
    l.w,
    math.max(1, (l.mode == "compact" and l.h - 3 or l.h - 5)),
    prefs.get("wallpaper", "grid"),
    t.accent
  )

  draw.text(target, x, y, "Bureau LinkOS", t.text, t.bg, w)

  if l.mode ~= "compact" and w >= 24 then
    local sw = 12
    local sx = x + w - sw
    draw.button(target, sx, y, sw, "PARAMETRES", t.text, t.panel)
    self:addButton("home:settings:quick", sx, y, sw, 1, function()
      self:openApp("settings")
    end)
  end

  y = y + 2

  local info = self.service:identity()
  if l.mode == "compact" then
    draw.text(target, x, y, tostring(info.label or ("PC #" .. info.computer_id)), t.accent, t.bg, w)
    y = y + 1
    draw.text(target, x, y,
      (self.service.online and "AstralNet connecte" or "AstralNet hors-ligne")
        .. (self.service.unread > 0 and ("  |  " .. self.service.unread .. " msg") or ""),
      self.service.online and t.good or t.danger, t.bg, w)
    y = y + 2

    local apps = {
      {"Messages", "messages"},
      {"Contacts", "contacts"},
      {"Reseau", "network"},
      {"Fichiers", "files"},
      {"Notes", "notes"},
      {"Calculatrice", "calculator"},
      {"Terminal", "terminal"},
      {"Securite", "security"}
    }

    if self:isOperatorUI() then
      apps[#apps + 1] = {"LinkSec", "hacker"}
    end
    apps[#apps + 1] = {"Parametres", "settings"}

    local gap = 1
    local cols = w >= 28 and 2 or 1
    local tileW = math.floor((w - ((cols - 1) * gap)) / cols)
    local tileH = 3

    for i, app in ipairs(apps) do
      local col = (i - 1) % cols
      local row = math.floor((i - 1) / cols)
      local tx = x + col * (tileW + gap)
      local ty = y + row * (tileH + 1)

      if ty + tileH - 1 < l.h then
        local subtitle = ""
        if app[2] == "messages" and self.service.unread > 0 then
          subtitle = tostring(self.service.unread) .. " nouveau(x)"
        elseif app[2] == "network" then
          subtitle = self.service.online and "ONLINE" or "OFFLINE"
        elseif app[2] == "security" then
          subtitle = security.enabled() and "MDP actif" or "Standard"
        elseif app[2] == "hacker" then
          subtitle = "Operateur"
        end

        draw.box(target, tx, ty, tileW, tileH, t.panel, t.accent, app[1])
        if subtitle ~= "" and tileH >= 3 then
          draw.text(target, tx + 1, ty + 1, subtitle, t.muted, t.panel, math.max(1, tileW - 2))
        end

        local appId = app[2]
        self:addButton("home:" .. appId, tx, ty, tileW, tileH, function()
          self:openApp(appId)
        end)
      end
    end
    return
  end

  local gap = 1
  local columns = l.mode == "wall" and 3 or 2
  local cardW = math.floor((w - (columns - 1) * gap) / columns)
  local cardH = l.mode == "wall" and 6 or 5

  local statusText = self.service.online
    and ("Connecte au MER #" .. tostring(self.service.serverId))
    or ("Hors-ligne : " .. tostring(self.service.lastError or "MER indisponible"))

  local cards = {
    {"Messages", self.service.unread > 0 and (self.service.unread .. " nouveau(x)") or "Discuter avec un autre PC", "messages"},
    {"Contacts", "Retrouver rapidement les PC connus", "contacts"},
    {"Reseau", self.service.online and "AstralNet connecte" or "AstralNet hors-ligne", "network"},
    {"Fichiers", humanBytes(fs.getFreeSpace("/")) .. " disponibles", "files"},
    {"Notes", "Bloc-notes personnel", "notes"},
    {"Calculatrice", "Calcul rapide et securise", "calculator"},
    {"Terminal", "Console CraftOS integree", "terminal"},
    {"Securite", security.enabled() and "Mot de passe actif" or "Protection standard", "security"}
  }

  if self:isOperatorUI() then
    cards[#cards + 1] = {"LinkSec CMD", "Terminal operateur", "hacker"}
  end

  cards[#cards + 1] = {"Parametres", "Affichage et systeme", "settings"}

  for i, card in ipairs(cards) do
    local col = (i - 1) % columns
    local row = math.floor((i - 1) / columns)
    local cx = x + col * (cardW + gap)
    local cy = y + row * (cardH + 1)

    if cy + cardH <= l.h - 1 then
      self:card(target, cx, cy, cardW, cardH, card[1], card[2], function()
        self:openApp(card[3])
      end)
    end
  end
end

function LinkOS:peerName(id)
  return prefs.alias(id) or ("PC #" .. tostring(id))
end

function LinkOS:renderMessages(target, l)
  local t = self:theme()
  local x, y, w, h = l.contentX, l.contentY, l.contentW, l.contentH

  draw.text(target, x, y, "Messages", t.text, t.bg, math.max(1,w-12))
  self:button(target, "msg:new", math.max(x,x+w-10), y, math.min(10,w), "+ NOUVEAU", function()
    local targetId = tonumber(self:prompt("Nouveau message", "Computer ID du destinataire"))
    if not targetId then
      self:setNotice("Computer ID invalide.", t.danger)
      return
    end
    local body = self:prompt("PC #" .. targetId, "Ecris ton message")
    if body and body ~= "" then
      local message, err = self.service:sendMessage(targetId, body)
      if message then
        self.selectedPeer = targetId
        self:setNotice("Message envoye.", t.good)
      else
        self:setNotice(tostring(err), t.danger)
      end
    end
  end)
  y=y+2

  local peers=self.service:peers()
  if not self.selectedPeer then
    if #peers==0 then
      draw.text(target,x,y+1,"Aucune conversation",t.text,t.bg,w)
      draw.text(target,x,y+3,"Utilise + NOUVEAU pour contacter un Computer.",t.muted,t.bg,w)
      return
    end

    draw.text(target,x,y,"CONVERSATIONS",t.muted,t.bg,w)
    y=y+2
    for _,peer in ipairs(peers) do
      if y+1>=l.h-1 then break end
      local name=self:peerName(peer.id)
      local last=peer.last and tostring(peer.last.body or "") or "Aucun message"
      draw.fill(target,x,y,w,2,colors.black)
      draw.fill(target,x,y,1,2,t.accent)
      draw.text(target,x+2,y,name,t.text,colors.black,math.max(1,w-3))
      draw.text(target,x+2,y+1,last,t.muted,colors.black,math.max(1,w-3))
      local pid=peer.id
      self:addButton("peer:"..pid,x,y,w,2,function()
        self.selectedPeer=pid
        self.service:markRead()
      end)
      y=y+3
    end
    return
  end

  local peerId=self.selectedPeer
  local name=self:peerName(peerId)
  draw.text(target,x,y,"< Conversations",t.accent,t.bg,math.min(16,w))
  self:addButton("msg:back",x,y,math.min(16,w),1,function() self.selectedPeer=nil end)
  if w>=26 then
    draw.text(target,x+18,y,name,t.text,t.bg,math.max(1,w-18))
  end
  y=y+2

  local history=self.service:history(peerId,math.max(8,h-7))
  local maxLines=math.max(1,math.min(#history,l.h-y-5))
  local first=math.max(1,#history-maxLines+1)
  for i=first,#history do
    if y>=l.h-4 then break end
    local m=history[i]
    local mine=tonumber(m.from_id)==os.getComputerID()
    local prefix=mine and "MOI  " or "EUX  "
    local fg=mine and t.accent or t.text
    draw.text(target,x,y,prefix..tostring(m.body),fg,t.bg,w)
    y=y+1
  end

  local actionY=math.min(l.h-2,math.max(y+1,l.h-4))
  self:button(target,"msg:reply",x,actionY,math.min(12,w),"REPONDRE",function()
    local body=self:prompt(name,"Ecris ton message")
    if body and body~="" then
      local _,err=self.service:sendMessage(peerId,body)
      self:setNotice(err or "Message envoye.",err and t.danger or t.good)
    end
  end)
  if w>=27 then
    self:button(target,"msg:alias",x+14,actionY,math.min(10,w-14),"ALIAS",function()
      local alias=self:prompt("Alias de PC #"..peerId,"Vide = supprimer")
      prefs.setAlias(peerId,alias)
      self:setNotice("Alias mis a jour.",t.good)
    end)
  end
end

function LinkOS:renderContacts(target, l)
  local t=self:theme()
  local x,y,w=l.contentX,l.contentY,l.contentW

  draw.text(target,x,y,"Contacts",t.text,t.bg,math.max(1,w-11))
  self:button(target,"contact:add",math.max(x,x+w-10),y,math.min(10,w),"+ AJOUTER",function()
    local id=tonumber(self:prompt("Nouveau contact","Computer ID"))
    if not id then
      self:setNotice("Computer ID invalide.",t.danger)
      return
    end
    local name=self:prompt("PC #"..id,"Nom local du contact")
    if name and name~="" then
      prefs.setAlias(id,name)
      self:setNotice("Contact ajoute.",t.good)
    end
  end)
  y=y+2

  local contacts={}
  for id,name in pairs(prefs.all().aliases or {}) do
    contacts[#contacts+1]={id=tonumber(id) or id,name=name}
  end
  table.sort(contacts,function(a,b)
    return string.lower(tostring(a.name))<string.lower(tostring(b.name))
  end)

  if #contacts==0 then
    draw.text(target,x,y+1,"Aucun contact",t.text,t.bg,w)
    draw.text(target,x,y+3,"Les alias restent uniquement sur ce Computer.",t.muted,t.bg,w)
    return
  end

  for _,contact in ipairs(contacts) do
    if y+1>=l.h-1 then break end
    local cid=tonumber(contact.id)
    draw.fill(target,x,y,w,2,colors.black)
    draw.fill(target,x,y,2,2,t.accent)
    draw.text(target,x,y,"@",colors.white,t.accent,2)
    draw.text(target,x+3,y,tostring(contact.name),t.text,colors.black,math.max(1,w-11))
    local idText="#"..tostring(contact.id)
    draw.text(target,math.max(x+3,x+w-#idText),y,idText,t.muted,colors.black,#idText)
    draw.text(target,x+3,y+1,cid and "Ouvrir la conversation" or "Alias local",
      t.muted,colors.black,math.max(1,w-4))
    self:addButton("contact:"..tostring(contact.id),x,y,w,2,function()
      if cid then
        self.selectedPeer=cid
        self:openApp("messages")
      end
    end)
    y=y+3
  end
end

function LinkOS:renderNetwork(target, l)
  local t = self:theme()
  local x, y, w = l.contentX, l.contentY, l.contentW
  local info = self.service:identity()

  draw.text(target, x, y, "AstralNet", t.text, t.bg, math.max(1,w-12))
  local status = info.online and "ONLINE" or "OFFLINE"
  draw.text(target, math.max(x,x+w-#status), y, status,
    info.online and t.good or t.danger, t.bg, #status)
  y = y + 2

  draw.fill(target, x, y, w, 5, colors.black)
  draw.fill(target, x, y, 1, 5, info.online and t.good or t.danger)

  local label = tostring(info.label or ("PC-" .. tostring(info.computer_id)))
  draw.text(target, x+2, y, label, t.text, colors.black, math.max(1,w-3))
  draw.text(target, x+2, y+1, "Computer #" .. tostring(info.computer_id), t.muted, colors.black, math.max(1,w-3))
  draw.text(target, x+2, y+2,
    "MER  " .. (info.server_id and ("#" .. tostring(info.server_id)) or "non detecte"),
    info.server_id and t.accent or t.warn, colors.black, math.max(1,w-3))
  draw.text(target, x+2, y+3,
    "Modem  " .. tostring(info.modem or "absent"),
    info.modem and t.text or t.warn, colors.black, math.max(1,w-3))
  y = y + 6

  local bw = math.max(7, math.floor((w-2)/3))
  self:button(target, "net:ping", x, y, bw, "PING", function()
    local result, err = self.service:ping()
    if result then
      self:setNotice("MER ~" .. tostring(result.latency) .. " ms", t.good)
    else
      self:setNotice(tostring(err), t.danger)
    end
  end)

  if x+bw+1 <= x+w-1 then
    self:button(target, "net:sync", x+bw+1, y, math.min(bw,w-bw-1), "SYNC", function()
      local count, err = self.service:syncInbox(true)
      if count then
        self:setNotice(tostring(count) .. " message(s) synchronise(s).", t.good)
      else
        self:setNotice(tostring(err), t.danger)
      end
    end)
  end

  if x+(bw+1)*2 <= x+w-1 then
    self:button(target, "net:reconnect", x+(bw+1)*2, y,
      math.min(bw,w-(bw+1)*2), "RECONN.", function()
        local ok, err = self.service:reconnect()
        self:setNotice(ok and "Connexion MER retablie." or tostring(err),
          ok and t.good or t.danger)
      end)
  end
  y = y + 2

  self:button(target, "net:rename", x, y, math.min(12,w), "RENOMMER", function()
    local value = self:prompt("Nouveau nom du PC", "Maximum 32 caracteres.")
    local ok, err = self.service:setLabel(value)
    self:setNotice(ok and "Nom du PC mis a jour." or tostring(err), ok and t.good or t.danger)
  end)

  if w >= 24 then
    self:button(target, "net:details", x+14, y, math.min(10,w-14),
      self.networkDetails and "MASQUER" or "DETAILS", function()
        self.networkDetails = not self.networkDetails
      end)
  end

  if self.networkDetails then
    y = y + 3
    draw.text(target, x, y, "DETAILS TECHNIQUES", t.muted, t.bg, w)
    y = y + 2
    draw.text(target, x, y, "Protocole", t.muted, t.bg, 10)
    draw.text(target, x+11, y, tostring(config.PROTOCOL), t.text, t.bg, math.max(1,w-11))
    y = y + 1
    draw.text(target, x, y, "Version", t.muted, t.bg, 10)
    draw.text(target, x+11, y, tostring(config.VERSION), t.text, t.bg, math.max(1,w-11))
  end
end

function LinkOS:linksecTarget()
  local id = tonumber(self.hackerConsole.target)
  if not id then
    self:setNotice("Aucune cible active. Lance un scan puis connecte-toi a un PC.", self:theme().warn)
    return nil
  end
  return id
end

function LinkOS:linksecScan()
  local list, err = self.service:scan()
  if not list then
    self:setNotice("Scan impossible: " .. tostring(err), self:theme().danger)
    return
  end

  self.linksecTargets = list
  self.linksecView = "targets"
  self:setNotice(tostring(#list) .. " PC detecte(s).", self:theme().good)
end

function LinkOS:linksecConnect(id)
  id = tonumber(id)
  if not id then return end

  local session, err = self.service:hack(id)
  if not session then
    self:setNotice("Connexion refusee: " .. tostring(err), self:theme().danger)
    return
  end

  self.hackerConsole.target = id
  self.linksecView = "home"
  self:setNotice("Session LinkSec ouverte sur PC #" .. tostring(id) .. ".", self:theme().good)
end

function LinkOS:linksecLoadConversationIndex()
  local targetId = self:linksecTarget()
  if not targetId then return end

  local data, err = self.service:remote(targetId, "conversation_index")
  if not data then
    self:setNotice("Messages indisponibles: " .. tostring(err), self:theme().danger)
    return
  end

  self.linksecConversations = data.conversations or {}
  self.linksecConversationPeer = nil
  self.linksecConversationMessages = {}
  self.linksecView = "conversations"
end

function LinkOS:linksecOpenConversation(peerId)
  local targetId = self:linksecTarget()
  if not targetId then return end

  peerId = tonumber(peerId)
  if not peerId then return end

  local data, err = self.service:remote(targetId, "conversation", peerId)
  if not data then
    self:setNotice("Conversation indisponible: " .. tostring(err), self:theme().danger)
    return
  end

  self.linksecConversationPeer = peerId
  self.linksecConversationMessages = data.messages or {}
  self.linksecView = "conversation"
end

function LinkOS:linksecLoadDevices()
  local targetId = self:linksecTarget()
  if not targetId then return end

  local data, err = self.service:remote(targetId, "devices")
  if not data then
    self:setNotice("Peripheriques: " .. tostring(err), self:theme().danger)
    return
  end

  self.linksecDevices = data.devices or {}
  self.linksecDevice = nil
  self.linksecDeviceResult = nil
  self.linksecView = "devices"
end

function LinkOS:linksecOpenDevice(name)
  for _, device in ipairs(self.linksecDevices or {}) do
    if device.name == name then
      self.linksecDevice = device
      self.linksecDeviceResult = nil
      self.linksecView = "device"
      return
    end
  end
end

function LinkOS:linksecCallDevice(method)
  local targetId = self:linksecTarget()
  if not targetId or not self.linksecDevice then return end

  local raw = self:prompt(
    tostring(self.linksecDevice.name) .. "." .. tostring(method),
    "Arguments separes par des espaces. Vide = aucun argument."
  )

  local args = {}
  local methodLower = string.lower(tostring(method or ""))

  -- Les imprimantes CC:Tweaked ont besoin de recevoir le texte complet comme
  -- un seul argument, espaces compris.
  if methodLower == "write" or methodLower == "setpagetitle" then
    args[1] = tostring(raw or "")
  else
    for token in tostring(raw or ""):gmatch("%S+") do
      local lower = string.lower(token)
      if lower == "true" or lower == "on" then
        args[#args + 1] = true
      elseif lower == "false" or lower == "off" then
        args[#args + 1] = false
      else
        args[#args + 1] = tonumber(token) or token
      end
    end
  end

  local data, err = self.service:remote(targetId, "device_call", {
    name = self.linksecDevice.name,
    method = method,
    args = args
  })

  if not data then
    self.linksecDeviceResult = "ERREUR: " .. tostring(err)
    self:setNotice(self.linksecDeviceResult, self:theme().danger)
    return
  end

  local parts = {}
  for _, value in ipairs(data.results or {}) do
    if type(value) == "table" then
      parts[#parts + 1] = textutils.serialize(value, {compact=true})
    else
      parts[#parts + 1] = tostring(value)
    end
  end

  self.linksecDeviceResult = #parts > 0 and table.concat(parts, " | ") or "OK"
  self:setNotice(tostring(method) .. " execute.", self:theme().good)
end

function LinkOS:linksecLoadRedstone()
  local targetId = self:linksecTarget()
  if not targetId then return end

  local data, err = self.service:remote(targetId, "redstone")
  if not data then
    self:setNotice("Redstone: " .. tostring(err), self:theme().danger)
    return
  end

  self.linksecRedstone = data.sides or {}
  self.linksecView = "redstone"
end

function LinkOS:linksecSetRedstone(side)
  local targetId = self:linksecTarget()
  if not targetId then return end

  local value = self:prompt("Redstone " .. tostring(side), "Tape on, off ou 0-15.")
  local data, err = self.service:remote(targetId, "redstone_set", {
    side = side,
    value = tonumber(value) or value
  })

  if not data then
    self:setNotice("Redstone: " .. tostring(err), self:theme().danger)
    return
  end

  self:setNotice("Sortie " .. tostring(side) .. " modifiee.", self:theme().good)
  self:linksecLoadRedstone()
end

function LinkOS:linksecLoadDrives()
  local targetId = self:linksecTarget()
  if not targetId then return end

  local data, err = self.service:remote(targetId, "drives")
  if not data then
    self:setNotice("Disques: " .. tostring(err), self:theme().danger)
    return
  end

  self.linksecDrives = data.drives or {}
  self.linksecView = "drives"
end

function LinkOS:malcraftTargetId()
  return tonumber(self.malcraftTarget or self.hackerConsole.target)
end

function LinkOS:malcraftLocalDiskList()
  local out = {}

  for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "drive" and disk.isPresent(name) then
      local diskId = disk.getID(name)
      if diskId then
        out[#out + 1] = {
          name = name,
          id = diskId,
          label = disk.getLabel(name),
          mount = disk.hasData(name) and disk.getMountPath(name) or nil
        }
      end
    end
  end

  table.sort(out, function(a, b)
    return tonumber(a.id) < tonumber(b.id)
  end)

  return out
end

function LinkOS:malcraftCarrierPath(drive)
  if not drive or not drive.mount then return nil end
  return fs.combine(fs.combine(drive.mount, ".malcraft"), "carrier.dat")
end

function LinkOS:malcraftWriteCarrier(drive, active)
  if not drive or not drive.mount then
    return false, "Ce disque n'a pas de stockage de donnees."
  end

  local path = self:malcraftCarrierPath(drive)
  if not path then return false, "Chemin disque indisponible." end

  if active then
    local dir = fs.getDir(path)
    if dir and dir ~= "" and not fs.exists(dir) then
      local ok = pcall(fs.makeDir, dir)
      if not ok then return false, "Impossible de preparer le disque." end
    end

    local file = fs.open(path, "w")
    if not file then return false, "Ecriture du disque impossible." end
    file.writeLine("ASTRALIUM_MALCRAFT_CARRIER_V1")
    file.writeLine("disk=" .. tostring(drive.id or "unknown"))
    file.writeLine("source=" .. tostring(os.getComputerID()))
    file.close()
  else
    if fs.exists(path) then
      pcall(fs.delete, path)
    end

    local dir = fs.getDir(path)
    if dir and dir ~= "" and fs.exists(dir) and fs.isDir(dir) then
      local entries = fs.list(dir)
      if #entries == 0 then pcall(fs.delete, dir) end
    end
  end

  return true
end

function LinkOS:malcraftOpenHub()
  local registry, err = self.service:ghostList()

  self.malcraftHosts = registry and (registry.hosts or {}) or {}
  self.malcraftLocalDisks = self:malcraftLocalDiskList()
  self.ghostDiskStates = {}

  for _, item in ipairs((registry and registry.disks) or {}) do
    self.ghostDiskStates[tonumber(item.disk_id)] = true
  end

  if not registry then
    self:setNotice(
      "MER indisponible: les disques locaux restent utilisables. " .. tostring(err or ""),
      self:theme().warn
    )
  end

  self.linksecView = "malcraft_hub"
end

function LinkOS:malcraftRefreshHosts()
  local registry = self.service:ghostList()
  if registry and type(registry.hosts) == "table" then
    self.malcraftHosts = registry.hosts
    return true
  end
  return false
end

function LinkOS:malcraftOpenHosts()
  local registry, err = self.service:ghostList()
  if not registry then
    self:setNotice("Malcraft: " .. tostring(err), self:theme().danger)
    return
  end

  self.malcraftHosts = registry.hosts or {}
  self.linksecView = "malcraft_hosts"
end

function LinkOS:malcraftOpenLiveHosts()
  local computers, err = self.service:ghostLiveComputers()
  if not computers then
    self:setNotice("Malcraft Bridge: " .. tostring(err), self:theme().danger)
    return
  end

  self.malcraftLiveHosts = computers
  self.linksecView = "malcraft_live_hosts"
end

function LinkOS:malcraftSelectById()
  local value = self:prompt("Cible Malcraft", "Computer ID a verifier / contaminer.")
  local id = tonumber(value)
  if not id or id < 0 or math.floor(id) ~= id then
    self:setNotice("Computer ID invalide.", self:theme().danger)
    return
  end

  self:malcraftSelectHost(id)
end

function LinkOS:malcraftSelectHost(computerId)
  computerId = tonumber(computerId)
  if not computerId then return end

  self.malcraftTarget = computerId

  local data, err = self.service:ghostStatus(computerId)
  if not data then
    self:setNotice("Malcraft: " .. tostring(err), self:theme().danger)
    return
  end

  local state = data.state or {}
  if state.infected == true and state.online == true then
    local agent = self.service:ghostRemote(computerId, "status")
    if agent then data.agent_status = agent end
  end

  self.ghostState = data
  self.linksecView = "ghost"
end

function LinkOS:malcraftOpenLocalDisks()
  local registry = self.service:ghostList()

  self.malcraftLocalDisks = self:malcraftLocalDiskList()
  self.ghostDiskStates = {}

  for _, item in ipairs((registry and registry.disks) or {}) do
    self.ghostDiskStates[tonumber(item.disk_id)] = true
  end

  -- Detect the physical Malcraft marker too, so the screen remains accurate
  -- even while the MER is offline.
  for _, drive in ipairs(self.malcraftLocalDisks) do
    local path = self:malcraftCarrierPath(drive)
    if path and fs.exists(path) then
      self.ghostDiskStates[tonumber(drive.id)] = true
    end
  end

  self.linksecView = "malcraft_local_disks"
end

function LinkOS:malcraftToggleLocalDisk(diskId)
  diskId = tonumber(diskId)
  if not diskId then return end

  local drive = nil
  for _, candidate in ipairs(self.malcraftLocalDisks or {}) do
    if tonumber(candidate.id) == diskId then
      drive = candidate
      break
    end
  end

  if not drive then
    self:setNotice("Disque local introuvable.", self:theme().danger)
    return
  end

  local active = self.ghostDiskStates[diskId] == true
  local nextState = not active

  -- Le marqueur est physiquement ecrit dans le disque CC:Tweaked. Ainsi un
  -- Computer sans LinkOS peut le detecter uniquement via la ROM du datapack.
  local markerOk, markerErr = self:malcraftWriteCarrier(drive, nextState)
  if not markerOk then
    self:setNotice("Malcraft disque: " .. tostring(markerErr), self:theme().danger)
    return
  end

  local data, err = self.service:ghostDiskSet(diskId, nextState)

  if not data then
    self.ghostDiskStates[diskId] = nextState
    self:setNotice(
      "Marqueur " .. (nextState and "Malcraft ecrit" or "Malcraft retire")
        .. " sur Disk #" .. tostring(diskId)
        .. ", mais MER indisponible: " .. tostring(err),
      self:theme().warn
    )
    return
  end

  self.ghostDiskStates[diskId] = nextState
  self:setNotice(
    "Disk #" .. tostring(diskId)
      .. (active and " nettoye." or " contamine par Malcraft."),
    self:theme().good
  )
end

function LinkOS:ghostRefresh()
  local targetId = self:malcraftTargetId()
  if not targetId then return end

  local data, err = self.service:ghostStatus(targetId)
  if not data then
    self:setNotice("Malcraft: " .. tostring(err), self:theme().danger)
    return
  end

  local state = data.state or {}
  if state.infected == true and state.online == true then
    local agent = self.service:ghostRemote(targetId, "status")
    if agent then data.agent_status = agent end
  end

  self.ghostState = data
  self.linksecView = "ghost"
end

function LinkOS:ghostInstall()
  local targetId = self:malcraftTargetId()
  if not targetId then return end

  local data, err = self.service:ghostInstall(targetId, true)
  if not data then
    self:setNotice("Installation Malcraft impossible: " .. tostring(err), self:theme().danger)
    return
  end

  self:setNotice("Malcraft actif sur PC #" .. tostring(targetId) .. ".", self:theme().good)
  self:ghostRefresh()
end

function LinkOS:ghostClean()
  local targetId = self:malcraftTargetId()
  if not targetId then return end

  local data, err = self.service:ghostClean(targetId)
  if not data then
    self:setNotice("Nettoyage Malcraft impossible: " .. tostring(err), self:theme().danger)
    return
  end

  self:setNotice("Malcraft retire de PC #" .. tostring(targetId) .. ".", self:theme().good)
  self:ghostRefresh()
end

function LinkOS:ghostToggleSpread()
  local targetId = self:malcraftTargetId()
  if not targetId or not self.ghostState then return end

  local state = self.ghostState.state or {}
  local enabled = not (state.spread == true)
  local data, err = self.service:ghostSetSpread(targetId, enabled)

  if not data then
    self:setNotice("Propagation: " .. tostring(err), self:theme().danger)
    return
  end

  self:setNotice("Propagation " .. (enabled and "activee." or "desactivee."), self:theme().good)
  self:ghostRefresh()
end

function LinkOS:ghostSpreadTo()
  local sourceId = self:malcraftTargetId()
  if not sourceId then return end

  local raw = self:prompt(
    "Propagation Malcraft",
    "Computer ID a contaminer depuis la cible active."
  )
  local targetId = tonumber(raw)
  if not targetId then
    self:setNotice("ID cible invalide.", self:theme().danger)
    return
  end

  local data, err = self.service:ghostRemote(sourceId, "spread", {
    target_id = targetId
  })

  if not data then
    self:setNotice("Propagation impossible: " .. tostring(err), self:theme().danger)
    return
  end

  self:setNotice(
    "PC #" .. tostring(targetId) .. " propage Malcraft via PC #" .. tostring(sourceId) .. ".",
    self:theme().good
  )
end

function LinkOS:ghostLoadDevices()
  local targetId = self:malcraftTargetId()
  if not targetId then return end

  local data, err = self.service:ghostRemote(targetId, "devices")
  if not data then
    self:setNotice("Peripheriques Malcraft: " .. tostring(err), self:theme().danger)
    return
  end

  self.ghostDevices = data.devices or {}
  self.linksecView = "ghost_devices"
end

function LinkOS:ghostOpenDevice(name)
  for _, device in ipairs(self.ghostDevices or {}) do
    if device.name == name then
      self.ghostDevice = device
      self.ghostDeviceResult = nil
      self.linksecView = "ghost_device"
      return
    end
  end
end

function LinkOS:ghostCallDevice(method)
  local targetId = self:malcraftTargetId()
  if not targetId or not self.ghostDevice then return end

  local raw = self:prompt(
    tostring(self.ghostDevice.name) .. "." .. tostring(method),
    "Arguments separes par des espaces. Vide = aucun argument."
  )

  local args = {}
  local methodLower = string.lower(tostring(method or ""))

  -- Les imprimantes CC:Tweaked ont besoin de recevoir le texte complet comme
  -- un seul argument, espaces compris.
  if methodLower == "write" or methodLower == "setpagetitle" then
    args[1] = tostring(raw or "")
  else
    for token in tostring(raw or ""):gmatch("%S+") do
      local lower = string.lower(token)
      if lower == "true" or lower == "on" then
        args[#args + 1] = true
      elseif lower == "false" or lower == "off" then
        args[#args + 1] = false
      else
        args[#args + 1] = tonumber(token) or token
      end
    end
  end

  local data, err = self.service:ghostRemote(targetId, "device_call", {
    name = self.ghostDevice.name,
    method = method,
    args = args
  })

  if not data then
    self.ghostDeviceResult = "ERREUR: " .. tostring(err)
    self:setNotice(self.ghostDeviceResult, self:theme().danger)
    return
  end

  local parts = {}
  for _, value in ipairs(data.results or {}) do
    if type(value) == "table" then
      parts[#parts + 1] = textutils.serialize(value, {compact=true})
    else
      parts[#parts + 1] = tostring(value)
    end
  end

  self.ghostDeviceResult = #parts > 0 and table.concat(parts, " | ") or "OK"
  self:setNotice(tostring(method) .. " execute.", self:theme().good)
end

function LinkOS:ghostLoadRedstone()
  local targetId = self:malcraftTargetId()
  if not targetId then return end

  local data, err = self.service:ghostRemote(targetId, "redstone")
  if not data then
    self:setNotice("Redstone Malcraft: " .. tostring(err), self:theme().danger)
    return
  end

  self.ghostRedstone = data.sides or {}
  self.linksecView = "ghost_redstone"
end

function LinkOS:ghostSetRedstone(side)
  local targetId = self:malcraftTargetId()
  if not targetId then return end

  local value = self:prompt("Redstone " .. tostring(side), "Tape on, off ou 0-15.")
  local data, err = self.service:ghostRemote(targetId, "redstone_set", {
    side = side,
    value = tonumber(value) or value
  })

  if not data then
    self:setNotice("Redstone: " .. tostring(err), self:theme().danger)
    return
  end

  self:setNotice("Sortie " .. tostring(side) .. " modifiee.", self:theme().good)
  self:ghostLoadRedstone()
end

function LinkOS:ghostLoadDrives()
  local targetId = self:malcraftTargetId()
  if not targetId then return end

  local data, err = self.service:ghostRemote(targetId, "drives")
  if not data then
    self:setNotice("Disques Malcraft: " .. tostring(err), self:theme().danger)
    return
  end

  self.ghostDrives = data.disk_ids or {}
  self.ghostDiskStates = {}

  local registry = self.service:ghostList()
  if registry and type(registry.disks) == "table" then
    for _, item in ipairs(registry.disks) do
      self.ghostDiskStates[tonumber(item.disk_id)] = true
    end
  end

  self.linksecView = "ghost_drives"
end

function LinkOS:ghostCarrier(diskId)
  diskId = tonumber(diskId)
  if not diskId then return end

  local infected = self.ghostDiskStates[diskId] == true
  local data, err = self.service:ghostDiskSet(diskId, not infected)

  if not data then
    self:setNotice("Support Malcraft: " .. tostring(err), self:theme().danger)
    return
  end

  self.ghostDiskStates[diskId] = not infected
  self:setNotice(
    "Disque #" .. tostring(diskId)
      .. (infected and " nettoye." or " marque comme vecteur Malcraft."),
    self:theme().good
  )
end

function LinkOS:openMalcraftDesktop()
  local targetId = self:malcraftTargetId()
  if not targetId then
    self:setNotice("Aucune cible Malcraft.", self:theme().warn)
    return
  end

  local previous = term.redirect(self.native)
  pcall(self.native.setCursorBlink, false)

  local ok, runOk, runErr = pcall(RemoteDesktop.run, self.service, targetId)

  term.redirect(previous)

  if not ok then
    self:setNotice("Bureau distant: " .. tostring(runOk), self:theme().danger)
  elseif not runOk then
    self:setNotice("Bureau distant: " .. tostring(runErr), self:theme().danger)
  else
    self:setNotice("Bureau distant ferme.", self:theme().muted)
  end

  self:refreshDisplays()
  self:render()
end

function LinkOS:ghostInventoryScan()
  local targetId = self:malcraftTargetId()
  if not targetId then return end

  local data, err = self.service:ghostRemote(targetId, "inventory_scan")
  if not data then
    self:setNotice("Inventaires: " .. tostring(err), self:theme().danger)
    return
  end

  self.ghostInventories = data.inventories or {}
  self.linksecView = "ghost_inventories"
end

function LinkOS:ghostLoadNearbyComputers()
  local targetId = self:malcraftTargetId()
  if not targetId then return end

  local data, err = self.service:ghostRemote(targetId, "nearby_computers")
  if not data then
    self:setNotice("PC proches: " .. tostring(err), self:theme().danger)
    return
  end

  self.ghostNearbyComputers = data.computers or {}
  self.linksecView = "ghost_nearby"
end

function LinkOS:ghostNearbyPower(name, action)
  local targetId = self:malcraftTargetId()
  if not targetId then return end

  local data, err = self.service:ghostRemote(targetId, "nearby_power", {
    name = name,
    action = action
  })

  if not data then
    self:setNotice("Alimentation distante: " .. tostring(err), self:theme().danger)
    return
  end

  self:setNotice(tostring(name) .. " -> " .. tostring(action), self:theme().good)
  self:ghostLoadNearbyComputers()
end

function LinkOS:ghostPower(action)
  local targetId = self:malcraftTargetId()
  if not targetId then return end

  local data, err = self.service:ghostRemote(targetId, action)
  if not data then
    self:setNotice("Malcraft " .. tostring(action) .. ": " .. tostring(err), self:theme().danger)
    return
  end

  self:setNotice("Commande " .. tostring(action) .. " envoyee au PC #" .. tostring(targetId) .. ".", self:theme().good)
end

function LinkOS:showRemoteData(action, data)
  local t = self:theme()

  if action == "info" then
    self:setNotice("PC #" .. tostring(data.computer_id)
      .. " | " .. tostring(data.label or "-")
      .. " | " .. tostring(data.messages or 0) .. " msg", t.good)

  elseif action == "conversations" then
    local lines = {}
    for _, m in ipairs(data.messages or {}) do
      lines[#lines + 1] = "#" .. tostring(m.from_id) .. ">#" .. tostring(m.to_id)
        .. " " .. tostring(m.body)
    end
    self.remoteView = {
      title = "Conversations interceptees",
      lines = lines
    }

  elseif action == "ls" then
    local lines = {}
    for _, entry in ipairs(data.entries or {}) do
      lines[#lines + 1] = (entry.dir and "[DIR] " or "      ") .. tostring(entry.name)
    end
    self.remoteView = {
      title = "Fichiers distants " .. tostring(data.path or "/"),
      lines = lines
    }

  elseif action == "cat" then
    self.remoteView = {
      title = tostring(data.path or "Fichier distant"),
      lines = draw.wrap(tostring(data.content or ""), 70)
    }

  elseif action == "crash" then
    self:setNotice("Crash distant execute.", t.danger)
  end
end

function LinkOS:renderHacker(target, l)
  local t = self:theme()
  local x, y, w, h = l.contentX, l.contentY, l.contentW, l.contentH

  if not self:isOperatorUI() then
    self:openApp("security")
    return
  end

  draw.text(target, x, y, "LinkSec", colors.red, t.bg, w)

  local malcraftView = string.sub(tostring(self.linksecView or ""), 1, 5) == "ghost"
    or string.sub(tostring(self.linksecView or ""), 1, 8) == "malcraft"
  local shownTarget = malcraftView and self:malcraftTargetId() or tonumber(self.hackerConsole.target)

  local targetText = shownTarget
    and ("Cible PC #" .. tostring(shownTarget))
    or "Aucune cible"

  if w >= 26 then
    draw.text(target, math.max(x, x + w - #targetText), y, targetText,
      shownTarget and t.good or t.warn, t.bg, #targetText)
  end

  y = y + 2

  if self.linksecView == "targets" then
    draw.text(target, x, y, "< ACCUEIL", t.accent, t.bg, w)
    self:addButton("linksec:targets:back", x, y, math.min(12, w), 1, function()
      self.linksecView = "home"
      self:render()
    end)
    y = y + 2

    draw.text(target, x, y, "PC detectes - clique pour ouvrir une session", t.text, t.bg, w)
    y = y + 2

    if #self.linksecTargets == 0 then
      draw.text(target, x, y, "Aucun PC detecte.", t.muted, t.bg, w)
    else
      for i = 1, math.min(#self.linksecTargets, math.max(1, l.h - y - 2)) do
        local pc = self.linksecTargets[i]
        local label = "PC #" .. tostring(pc.id)
          .. "  " .. tostring(pc.label or "-")
          .. "  " .. tostring(math.floor((pc.distance or 0) * 10) / 10) .. "b"

        draw.text(target, x, y, label, t.text, t.panel, w)
        local id = pc.id
        self:addButton("linksec:target:" .. tostring(id), x, y, w, 1, function()
          self:linksecConnect(id)
          self:render()
        end)
        y = y + 1
      end
    end
    return
  end

  if self.linksecView == "conversations" then
    draw.text(target, x, y, "< LINKSEC", t.accent, t.bg, w)
    self:addButton("linksec:conv:back", x, y, math.min(12, w), 1, function()
      self.linksecView = "home"
      self:render()
    end)
    y = y + 2

    draw.text(target, x, y, "Conversations disponibles", t.text, t.bg, w)
    y = y + 2

    if #self.linksecConversations == 0 then
      draw.text(target, x, y, "Aucune conversation stockee sur cette cible.", t.muted, t.bg, w)
    else
      for i = 1, math.min(#self.linksecConversations, math.max(1, l.h - y - 2)) do
        local item = self.linksecConversations[i]
        local last = item.last or {}
        local preview = tostring(last.body or "")
        if #preview > math.max(8, w - 18) then
          preview = string.sub(preview, 1, math.max(5, w - 21)) .. "..."
        end

        local line = "PC #" .. tostring(item.peer_id)
          .. " (" .. tostring(item.count or 0) .. ")"
          .. (preview ~= "" and ("  " .. preview) or "")

        draw.text(target, x, y, line, t.text, t.panel, w)
        local peerId = item.peer_id
        self:addButton("linksec:conv:" .. tostring(peerId), x, y, w, 1, function()
          self:linksecOpenConversation(peerId)
          self:render()
        end)
        y = y + 1
      end
    end
    return
  end

  if self.linksecView == "conversation" then
    draw.text(target, x, y, "< CONVERSATIONS", t.accent, t.bg, w)
    self:addButton("linksec:thread:back", x, y, math.min(16, w), 1, function()
      self.linksecView = "conversations"
      self:render()
    end)
    y = y + 2

    draw.text(target, x, y,
      "Cible #" .. tostring(self.hackerConsole.target)
        .. " <-> PC #" .. tostring(self.linksecConversationPeer or "?"),
      colors.red, t.bg, w)
    y = y + 2

    local available = math.max(1, l.h - y - 2)
    local messages = self.linksecConversationMessages or {}
    local first = math.max(1, #messages - available + 1)

    for i = first, #messages do
      local m = messages[i]
      local fromId = tonumber(m.from_id)
      local prefix = fromId == tonumber(self.hackerConsole.target)
        and "CIBLE: "
        or ("#" .. tostring(fromId) .. ": ")

      draw.text(target, x, y, prefix .. tostring(m.body or ""), t.text, t.bg, w)
      y = y + 1
      if y >= l.h - 1 then break end
    end
    return
  end

  if self.linksecView == "malcraft_hub" then
    draw.text(target, x, y, "< LINKSEC", t.accent, t.bg, w)
    self:addButton("malcraft:back", x, y, math.min(12, w), 1, function()
      self.linksecView = "home"
      self:render()
    end)
    y = y + 2

    draw.text(target, x, y, "MALCRAFT CONTROL CENTER", colors.red, t.bg, w)
    y = y + 1
    draw.text(target, x, y,
      tostring(#self.malcraftHosts) .. " PC infecte(s)  |  "
        .. tostring(#self.malcraftLocalDisks) .. " disque(s) local(aux)",
      t.muted, t.bg, w)
    y = y + 2

    local bw = math.min(18, math.max(11, math.floor((w - 2) / 2)))

    if self.hackerConsole.target then
      local currentId = tonumber(self.hackerConsole.target)
      draw.button(target, x, y, bw, "CIBLE #" .. tostring(currentId), colors.white, t.panel)
      self:addButton("malcraft:current", x, y, bw, 1, function()
        self:malcraftSelectHost(currentId)
        self:render()
      end)

      if w >= bw * 2 + 2 then
        draw.text(target, x + bw + 2, y,
          "Verifier / infecter / controler cette cible",
          t.muted, t.bg, math.max(1, w - bw - 2))
      end

      y = y + 2
    end

    draw.button(target, x, y, bw, "RESEAU INFECTE", colors.white, colors.red)
    self:addButton("malcraft:hosts", x, y, bw, 1, function()
      self:malcraftOpenHosts()
      self:render()
    end)

    if w >= bw * 2 + 2 then
      draw.button(target, x + bw + 2, y, bw, "PCS CHARGES", colors.white, t.panel)
      self:addButton("malcraft:live", x + bw + 2, y, bw, 1, function()
        self:malcraftOpenLiveHosts()
        self:render()
      end)
    end

    y = y + 2

    draw.button(target, x, y, bw, "DISQUES LOCAUX", colors.white, t.panel)
    self:addButton("malcraft:localdisks", x, y, bw, 1, function()
      self:malcraftOpenLocalDisks()
      self:render()
    end)

    if w >= bw * 2 + 2 then
      draw.button(target, x + bw + 2, y, bw, "CIBLE PAR ID", colors.white, t.panel)
      self:addButton("malcraft:byid", x + bw + 2, y, bw, 1, function()
        self:malcraftSelectById()
        self:render()
      end)
    end

    y = y + 2

    draw.text(target, x, y, "Propagation automatique :", t.text, t.bg, w)
    y = y + 1
    draw.text(target, x, y, "- proximite courte portee", t.good, t.bg, w)
    y = y + 1
    draw.text(target, x, y, "- disque contamine branche sur un PC", t.good, t.bg, w)
    y = y + 1
    draw.text(target, x, y, "- PC infecte -> nouveaux disques inseres", t.good, t.bg, w)
    y = y + 1
    draw.text(target, x, y, "- PC operateur immunise mais emetteur", t.good, t.bg, w)
    return
  end

  if self.linksecView == "malcraft_hosts" then
    draw.text(target, x, y, "< MALCRAFT", t.accent, t.bg, w)
    self:addButton("malcraft:hosts:back", x, y, math.min(14, w), 1, function()
      self:malcraftOpenHub()
      self:render()
    end)
    y = y + 2

    draw.text(target, x, y, "PC actuellement marques Malcraft", colors.red, t.bg, w)
    y = y + 2

    if #self.malcraftHosts == 0 then
      draw.text(target, x, y, "Aucun PC infecte.", t.muted, t.bg, w)
    else
      for i = 1, math.min(#self.malcraftHosts, math.max(1, l.h - y - 2)) do
        local item = self.malcraftHosts[i]
        local lastSeen = tonumber(item.last_seen) or 0
        local online = item.online == true
          or (item.online == nil and lastSeen > 0 and (epochSeconds() - lastSeen) <= 25)
        local source = tostring(item.source or item.last_source or "")
        if #source > 12 then source = string.sub(source,1,12) end
        local line = "PC #" .. tostring(item.computer_id)
          .. " " .. tostring(item.label or "")
          .. (online and " [ONLINE]" or " [OFFLINE]")
          .. (item.spread and " [PROP]" or "")
          .. (source ~= "" and (" <" .. source .. ">") or "")

        draw.text(target, x, y, line,
          online and (item.spread and colors.red or t.good) or t.muted,
          t.panel, w)
        local id = item.computer_id
        self:addButton("malcraft:host:" .. tostring(id), x, y, w, 1, function()
          self:malcraftSelectHost(id)
          self:render()
        end)
        y = y + 1
      end
    end
    return
  end

  if self.linksecView == "malcraft_live_hosts" then
    draw.text(target, x, y, "< MALCRAFT", t.accent, t.bg, w)
    self:addButton("malcraft:live:back", x, y, math.min(14, w), 1, function()
      self:malcraftOpenHub()
      self:render()
    end)
    y = y + 2

    draw.text(target, x, y, "Computers charges par le serveur", colors.red, t.bg, w)
    y = y + 1
    draw.text(target, x, y, "LinkOS ou modem non requis.", t.muted, t.bg, w)
    y = y + 2

    if #self.malcraftLiveHosts == 0 then
      draw.text(target, x, y, "Aucun Computer cible actuellement charge.", t.muted, t.bg, w)
    else
      for i = 1, math.min(#self.malcraftLiveHosts, math.max(1, l.h - y - 2)) do
        local item = self.malcraftLiveHosts[i]
        local infected = item.infected == true
        local pos = tostring(item.x or "?") .. "," .. tostring(item.y or "?") .. "," .. tostring(item.z or "?")
        local line = "PC #" .. tostring(item.computer_id)
          .. " " .. tostring(item.label or "")
          .. (infected and " [INFECTE]" or " [SAIN]")
          .. " " .. pos

        draw.text(target,x,y,line,infected and colors.red or t.good,t.panel,w)
        local id=item.computer_id
        self:addButton("malcraft:live:"..tostring(id),x,y,w,1,function()
          self:malcraftSelectHost(id)
          self:render()
        end)
        y=y+1
      end
    end
    return
  end

  if self.linksecView == "malcraft_local_disks" then
    draw.text(target, x, y, "< MALCRAFT", t.accent, t.bg, w)
    self:addButton("malcraft:disks:back", x, y, math.min(14, w), 1, function()
      self:malcraftOpenHub()
      self:render()
    end)
    y = y + 2

    draw.text(target, x, y, "Disques branches sur le PC hacker", colors.red, t.bg, w)
    y = y + 1
    draw.text(target, x, y, "Clique un disque pour contaminer ou nettoyer.", t.muted, t.bg, w)
    y = y + 2

    if #self.malcraftLocalDisks == 0 then
      draw.text(target, x, y, "Aucun disk drive avec disque detecte.", t.muted, t.bg, w)
    else
      for i = 1, math.min(#self.malcraftLocalDisks, math.max(1, l.h - y - 2)) do
        local drive = self.malcraftLocalDisks[i]
        local active = self.ghostDiskStates[tonumber(drive.id)] == true
        local line = "Disk #" .. tostring(drive.id)
          .. "  " .. tostring(drive.label or "sans label")
          .. (active and "  [MALCRAFT ACTIF]" or "  [SAIN]")

        draw.text(target, x, y, line, active and colors.red or t.text, t.panel, w)
        local diskId = drive.id
        self:addButton("malcraft:localdisk:" .. tostring(diskId), x, y, w, 1, function()
          self:malcraftToggleLocalDisk(diskId)
          self:render()
        end)
        y = y + 1
      end
    end
    return
  end

  if self.linksecView == "devices" then
    draw.text(target, x, y, "< LINKSEC", t.accent, t.bg, w)
    self:addButton("linksec:devices:back", x, y, math.min(12, w), 1, function()
      self.linksecView = "home"
      self:render()
    end)
    y = y + 2

    draw.text(target, x, y, "Peripheriques connectes - clique pour controler", t.text, t.bg, w)
    y = y + 2

    if #self.linksecDevices == 0 then
      draw.text(target, x, y, "Aucun peripherique detecte.", t.muted, t.bg, w)
    else
      for i = 1, math.min(#self.linksecDevices, math.max(1, l.h - y - 2)) do
        local device = self.linksecDevices[i]
        local line = tostring(device.name)
          .. " [" .. table.concat(device.types or {}, ",") .. "]"
          .. "  " .. tostring(#(device.methods or {})) .. " methodes"

        draw.text(target, x, y, line, t.text, t.panel, w)
        local name = device.name
        self:addButton("linksec:device:" .. tostring(name), x, y, w, 1, function()
          self:linksecOpenDevice(name)
          self:render()
        end)
        y = y + 1
      end
    end
    return
  end

  if self.linksecView == "device" and self.linksecDevice then
    draw.text(target, x, y, "< PERIPHERIQUES", t.accent, t.bg, w)
    self:addButton("linksec:device:back", x, y, math.min(18, w), 1, function()
      self.linksecView = "devices"
      self:render()
    end)
    y = y + 2

    draw.text(target, x, y,
      tostring(self.linksecDevice.name)
        .. " [" .. table.concat(self.linksecDevice.types or {}, ",") .. "]",
      colors.red, t.bg, w)
    y = y + 2

    local methods = self.linksecDevice.methods or {}
    local maxRows = math.max(1, l.h - y - 4)

    for i = 1, math.min(#methods, maxRows) do
      local method = methods[i]
      draw.text(target, x, y, tostring(method), t.text, t.panel, w)
      local methodName = method
      self:addButton("linksec:method:" .. tostring(methodName), x, y, w, 1, function()
        self:linksecCallDevice(methodName)
        self:render()
      end)
      y = y + 1
    end

    if self.linksecDeviceResult and y < l.h - 1 then
      draw.text(target, x, y + 1, tostring(self.linksecDeviceResult), t.good, t.bg, w)
    end
    return
  end

  if self.linksecView == "redstone" then
    draw.text(target, x, y, "< LINKSEC", t.accent, t.bg, w)
    self:addButton("linksec:redstone:back", x, y, math.min(12, w), 1, function()
      self.linksecView = "home"
      self:render()
    end)
    y = y + 2

    draw.text(target, x, y, "Redstone - clique une face pour modifier", t.text, t.bg, w)
    y = y + 2

    for i = 1, math.min(#self.linksecRedstone, math.max(1, l.h - y - 2)) do
      local side = self.linksecRedstone[i]
      local line = tostring(side.side)
        .. "  IN:" .. tostring(side.analog_input or (side.input and 15 or 0))
        .. "  OUT:" .. tostring(side.analog_output or (side.output and 15 or 0))

      draw.text(target, x, y, line, t.text, t.panel, w)
      local sideName = side.side
      self:addButton("linksec:redstone:" .. tostring(sideName), x, y, w, 1, function()
        self:linksecSetRedstone(sideName)
        self:render()
      end)
      y = y + 1
    end
    return
  end

  if self.linksecView == "drives" then
    draw.text(target, x, y, "< LINKSEC", t.accent, t.bg, w)
    self:addButton("linksec:drives:back", x, y, math.min(12, w), 1, function()
      self.linksecView = "home"
      self:render()
    end)
    y = y + 2

    draw.text(target, x, y, "Lecteurs et disques connectes", t.text, t.bg, w)
    y = y + 2

    if #self.linksecDrives == 0 then
      draw.text(target, x, y, "Aucun lecteur detecte.", t.muted, t.bg, w)
    else
      for i = 1, math.min(#self.linksecDrives, math.max(1, l.h - y - 2)) do
        local drive = self.linksecDrives[i]
        local line = tostring(drive.name)
          .. " ID:" .. tostring(drive.id or "-")
          .. " " .. tostring(drive.label or "sans label")
          .. (drive.mount and (" " .. tostring(drive.mount)) or "")
        draw.text(target, x, y, line, t.text, t.panel, w)
        y = y + 1
      end
    end
    return
  end

  if self.linksecView == "ghost" then
    draw.text(target, x, y, "< LINKSEC", t.accent, t.bg, w)
    self:addButton("ghost:back", x, y, math.min(12, w), 1, function()
      self:malcraftOpenHub()
      self:render()
    end)
    y = y + 2

    local state = (self.ghostState and self.ghostState.state) or {}
    local infected = state.infected == true
    local spread = state.spread == true
    local immune = self.ghostState and self.ghostState.immune == true

    draw.text(target, x, y, "Malcraft", colors.red, t.bg, w)
    y = y + 1
    draw.text(target, x, y,
      immune and "IMMUNISE"
        or (infected and "ACTIF" or "ABSENT"),
      immune and t.good or (infected and colors.red or t.muted),
      t.bg, w)
    y = y + 1

    if infected then
      local agent = self.ghostState and self.ghostState.agent_status or nil
      local online = state.online == true
      local profile = not online and "HORS LIGNE"
        or (agent and agent.linkos_installed == true and "LINKOS + ROM" or "ROM SEUL")
      draw.text(target,x,y,
        "Etat: " .. (online and "ONLINE" or "OFFLINE") .. " | " .. profile,
        online and t.good or t.muted,t.bg,w)
      y = y + 1

      local source=tostring((agent and agent.source) or state.source or "-")
      draw.text(target,x,y,"Source: "..source,t.muted,t.bg,w)
      y = y + 1

      if state.dimension and state.dimension ~= "" then
        local pos=tostring(state.dimension).." "
          ..tostring(state.x or "?")..","..tostring(state.y or "?")..","..tostring(state.z or "?")
        draw.text(target,x,y,"Pos: "..pos,t.muted,t.bg,w)
        y = y + 1
      end
    end
    y = y + 1

    if immune then
      draw.text(target, x, y, "Ce poste est protege par la politique operateur.", t.muted, t.bg, w)
      return
    end

    if not infected then
      draw.button(target, x, y, math.min(18, w), "INFECTER MALCRAFT", colors.white, colors.red)
      self:addButton("ghost:install", x, y, math.min(18, w), 1, function()
        self:ghostInstall()
        self:render()
      end)
      return
    end

    local bw = math.min(16, math.max(10, math.floor((w - 2) / 2)))

    draw.button(target, x, y, bw, "ECRAN DISTANT", colors.white, colors.red)
    self:addButton("ghost:desktop", x, y, bw, 1, function()
      self:openMalcraftDesktop()
    end)

    if w >= bw * 2 + 2 then
      draw.button(target, x + bw + 2, y, bw, "OUTILS", colors.white, t.panel)
      self:addButton("ghost:tools", x + bw + 2, y, bw, 1, function()
        self.linksecView = "ghost_tools"
        self:render()
      end)
    end

    y = y + 2

    draw.button(target, x, y, bw,
      spread and "PROPAGATION ON" or "PROPAGATION OFF",
      colors.white, spread and colors.red or t.panel)
    self:addButton("ghost:spread", x, y, bw, 1, function()
      self:ghostToggleSpread()
      self:render()
    end)

    if w >= bw * 2 + 2 then
      draw.button(target, x + bw + 2, y, bw, "SYSTEME", colors.white, colors.red)
      self:addButton("ghost:system", x + bw + 2, y, bw, 1, function()
        self.linksecView = "ghost_system"
        self:render()
      end)
    end

    return
  end

  if self.linksecView == "ghost_tools" then
    draw.text(target, x, y, "< MALCRAFT", t.accent, t.bg, w)
    self:addButton("ghost:tools:back", x, y, math.min(14, w), 1, function()
      self.linksecView = "ghost"
      self:render()
    end)
    y = y + 2

    draw.text(target, x, y, "Outils de la cible", colors.red, t.bg, w)
    y = y + 2

    local bw = math.min(16, math.max(10, math.floor((w - 2) / 2)))

    draw.button(target, x, y, bw, "PERIPHERIQUES", colors.white, t.panel)
    self:addButton("ghost:devices", x, y, bw, 1, function()
      self:ghostLoadDevices()
      self:render()
    end)

    if w >= bw * 2 + 2 then
      draw.button(target, x + bw + 2, y, bw, "INVENTAIRES", colors.white, t.panel)
      self:addButton("ghost:inventories", x + bw + 2, y, bw, 1, function()
        self:ghostInventoryScan()
        self:render()
      end)
    end

    y = y + 2

    draw.button(target, x, y, bw, "REDSTONE", colors.white, t.panel)
    self:addButton("ghost:redstone", x, y, bw, 1, function()
      self:ghostLoadRedstone()
      self:render()
    end)

    if w >= bw * 2 + 2 then
      draw.button(target, x + bw + 2, y, bw, "DISQUES", colors.white, t.panel)
      self:addButton("ghost:drives", x + bw + 2, y, bw, 1, function()
        self:ghostLoadDrives()
        self:render()
      end)
    end

    y = y + 2

    draw.button(target, x, y, math.min(18, w), "PC PROCHES / CABLE", colors.white, t.panel)
    self:addButton("ghost:nearby", x, y, math.min(18, w), 1, function()
      self:ghostLoadNearbyComputers()
      self:render()
    end)
    return
  end

  if self.linksecView == "ghost_system" then
    draw.text(target, x, y, "< MALCRAFT", t.accent, t.bg, w)
    self:addButton("ghost:system:back", x, y, math.min(14, w), 1, function()
      self.linksecView = "ghost"
      self:render()
    end)
    y = y + 2

    draw.text(target, x, y, "Systeme distant PC #" .. tostring(self:malcraftTargetId() or "?"),
      colors.red, t.bg, w)
    y = y + 2

    local bw = math.min(16, math.max(10, math.floor((w - 2) / 2)))

    draw.button(target, x, y, bw, "ALLUMER", colors.white, t.good)
    self:addButton("ghost:sys:on", x, y, bw, 1, function()
      self:ghostPower("turn_on")
      self:render()
    end)

    if w >= bw * 2 + 2 then
      draw.button(target, x + bw + 2, y, bw, "REBOOT", colors.white, t.panel)
      self:addButton("ghost:sys:reboot", x + bw + 2, y, bw, 1, function()
        self:ghostPower("reboot")
        self:render()
      end)
    end

    y = y + 2

    draw.button(target, x, y, bw, "ARRET", colors.white, colors.red)
    self:addButton("ghost:sys:shutdown", x, y, bw, 1, function()
      self:ghostPower("shutdown")
      self:render()
    end)

    if w >= bw * 2 + 2 then
      draw.button(target, x + bw + 2, y, bw, "CRASH", colors.white, colors.red)
      self:addButton("ghost:sys:crash", x + bw + 2, y, bw, 1, function()
        self:ghostPower("crash")
        self:render()
      end)
    end

    y = y + 2

    draw.button(target, x, y, bw, "NETTOYER", colors.white, t.panel)
    self:addButton("ghost:sys:clean", x, y, bw, 1, function()
      self:ghostClean()
      self:render()
    end)

    y = y + 2

    draw.button(target, x, y, math.min(18, w), "CONTAMINER PC", colors.white, colors.red)
    self:addButton("ghost:sys:spreadto", x, y, math.min(18, w), 1, function()
      self:ghostSpreadTo()
      self:render()
    end)

    if y + 2 < l.h then
      draw.text(target, x, y + 2,
        "Malcraft Bridge peut rallumer un Computer infecte charge, sans modem.",
        t.muted, t.bg, w)
    end
    return
  end

  if self.linksecView == "ghost_inventories" then
    draw.text(target, x, y, "< MALCRAFT", t.accent, t.bg, w)
    self:addButton("ghost:inventories:back", x, y, math.min(14, w), 1, function()
      self.linksecView = "ghost"
      self:render()
    end)
    y = y + 2

    draw.text(target, x, y, "Inventaires accessibles depuis la cible", colors.red, t.bg, w)
    y = y + 2

    if #self.ghostInventories == 0 then
      draw.text(target, x, y, "Aucun inventaire expose a CC:Tweaked.", t.muted, t.bg, w)
    else
      local remaining = math.max(1, l.h - y - 2)
      for _, inventory in ipairs(self.ghostInventories) do
        if remaining <= 0 then break end
        draw.text(target, x, y,
          tostring(inventory.name) .. " [" .. table.concat(inventory.types or {}, ",") .. "]",
          t.accent, t.bg, w)
        y = y + 1
        remaining = remaining - 1

        local slots = inventory.items or {}
        for slot, item in pairs(slots) do
          if remaining <= 0 then break end
          local line = "  " .. tostring(slot) .. ": "
            .. tostring(type(item) == "table" and (item.name or item.displayName or "item") or item)
          if type(item) == "table" and item.count then
            line = line .. " x" .. tostring(item.count)
          end
          draw.text(target, x, y, line, t.text, t.bg, w)
          y = y + 1
          remaining = remaining - 1
        end
      end
    end
    return
  end

  if self.linksecView == "ghost_nearby" then
    draw.text(target, x, y, "< MALCRAFT", t.accent, t.bg, w)
    self:addButton("ghost:nearby:back", x, y, math.min(14, w), 1, function()
      self.linksecView = "ghost"
      self:render()
    end)
    y = y + 2

    draw.text(target, x, y, "Computers accessibles autour / via reseau cable", colors.red, t.bg, w)
    y = y + 2

    if #self.ghostNearbyComputers == 0 then
      draw.text(target, x, y, "Aucun Computer expose comme peripherique.", t.muted, t.bg, w)
    else
      for i = 1, math.min(#self.ghostNearbyComputers, math.max(1, math.floor((l.h - y - 2) / 2))) do
        local pc = self.ghostNearbyComputers[i]
        draw.text(target, x, y,
          tostring(pc.name) .. "  PC #" .. tostring(pc.id or "?")
            .. "  " .. tostring(pc.label or "")
            .. (pc.on and " [ON]" or " [OFF]"),
          pc.on and t.good or t.muted, t.panel, w)
        y = y + 1

        local half = math.max(8, math.floor((w - 2) / 3))
        draw.button(target, x, y, half, "ON", colors.white, t.panel)
        local name = pc.name
        self:addButton("ghost:nearby:on:" .. tostring(name), x, y, half, 1, function()
          self:ghostNearbyPower(name, "on")
          self:render()
        end)

        if w >= half * 2 + 1 then
          draw.button(target, x + half + 1, y, half, "REBOOT", colors.white, t.panel)
          self:addButton("ghost:nearby:reboot:" .. tostring(name), x + half + 1, y, half, 1, function()
            self:ghostNearbyPower(name, "reboot")
            self:render()
          end)
        end

        if w >= half * 3 + 2 then
          draw.button(target, x + (half + 1) * 2, y, half, "OFF", colors.white, colors.red)
          self:addButton("ghost:nearby:off:" .. tostring(name), x + (half + 1) * 2, y, half, 1, function()
            self:ghostNearbyPower(name, "off")
            self:render()
          end)
        end

        y = y + 1
      end
    end
    return
  end

  if self.linksecView == "ghost_devices" then
    draw.text(target, x, y, "< MALCRAFT", t.accent, t.bg, w)
    self:addButton("ghost:devices:back", x, y, math.min(14, w), 1, function()
      self.linksecView = "ghost"
      self:render()
    end)
    y = y + 2

    draw.text(target, x, y, "Peripheriques connectes - clique pour controler", t.text, t.bg, w)
    y = y + 2

    if #self.ghostDevices == 0 then
      draw.text(target, x, y, "Aucun peripherique detecte.", t.muted, t.bg, w)
    else
      for i = 1, math.min(#self.ghostDevices, math.max(1, l.h - y - 2)) do
        local device = self.ghostDevices[i]
        local line = tostring(device.name)
          .. " [" .. table.concat(device.types or {}, ",") .. "]"
          .. "  " .. tostring(#(device.methods or {})) .. " methodes"

        draw.text(target, x, y, line, t.text, t.panel, w)

        local deviceName = device.name
        self:addButton("ghost:device:" .. tostring(deviceName), x, y, w, 1, function()
          self:ghostOpenDevice(deviceName)
          self:render()
        end)

        y = y + 1
      end
    end
    return
  end

  if self.linksecView == "ghost_device" and self.ghostDevice then
    draw.text(target, x, y, "< PERIPHERIQUES", t.accent, t.bg, w)
    self:addButton("ghost:device:back", x, y, math.min(18, w), 1, function()
      self.linksecView = "ghost_devices"
      self:render()
    end)
    y = y + 2

    draw.text(target, x, y,
      tostring(self.ghostDevice.name)
        .. " [" .. table.concat(self.ghostDevice.types or {}, ",") .. "]",
      colors.red, t.bg, w)
    y = y + 2

    local methods = self.ghostDevice.methods or {}
    local maxRows = math.max(1, l.h - y - 4)

    for i = 1, math.min(#methods, maxRows) do
      local method = methods[i]
      draw.text(target, x, y, tostring(method), t.text, t.panel, w)

      local methodName = method
      self:addButton("ghost:method:" .. tostring(methodName), x, y, w, 1, function()
        self:ghostCallDevice(methodName)
        self:render()
      end)

      y = y + 1
    end

    if self.ghostDeviceResult and y < l.h - 1 then
      draw.text(target, x, y + 1, tostring(self.ghostDeviceResult), t.good, t.bg, w)
    end
    return
  end

  if self.linksecView == "ghost_redstone" then
    draw.text(target, x, y, "< MALCRAFT", t.accent, t.bg, w)
    self:addButton("ghost:redstone:back", x, y, math.min(14, w), 1, function()
      self.linksecView = "ghost"
      self:render()
    end)
    y = y + 2

    draw.text(target, x, y, "Redstone - clique une face pour modifier", t.text, t.bg, w)
    y = y + 2

    for i = 1, math.min(#self.ghostRedstone, math.max(1, l.h - y - 2)) do
      local side = self.ghostRedstone[i]
      local line = tostring(side.side)
        .. "  IN:" .. tostring(side.analog_input or (side.input and 15 or 0))
        .. "  OUT:" .. tostring(side.analog_output or (side.output and 15 or 0))

      draw.text(target, x, y, line, t.text, t.panel, w)
      local sideName = side.side
      self:addButton("ghost:redstone:" .. tostring(sideName), x, y, w, 1, function()
        self:ghostSetRedstone(sideName)
        self:render()
      end)
      y = y + 1
    end
    return
  end

  if self.linksecView == "ghost_drives" then
    draw.text(target, x, y, "< MALCRAFT", t.accent, t.bg, w)
    self:addButton("ghost:drives:back", x, y, math.min(14, w), 1, function()
      self.linksecView = "ghost"
      self:render()
    end)
    y = y + 2

    draw.text(target, x, y, "Disques connectes - clique pour marquer un vecteur", t.text, t.bg, w)
    y = y + 2

    if #self.ghostDrives == 0 then
      draw.text(target, x, y, "Aucun disque detecte.", t.muted, t.bg, w)
    else
      for i = 1, math.min(#self.ghostDrives, math.max(1, l.h - y - 2)) do
        local diskId = self.ghostDrives[i]
        local active = self.ghostDiskStates[tonumber(diskId)] == true
        local line = "Disk #" .. tostring(diskId)
          .. (active and "  [MALCRAFT ACTIF - NETTOYER]"
            or "  [CONTAMINER MALCRAFT]")
        draw.text(target, x, y, line, active and colors.red or t.text, t.panel, w)
        self:addButton("ghost:disk:" .. tostring(diskId), x, y, w, 1, function()
          self:ghostCarrier(diskId)
          self:render()
        end)
        y = y + 1
      end
    end
    return
  end

  draw.text(target, x, y, "Poste operateur PC #" .. os.getComputerID(), t.muted, t.bg, w)
  y = y + 2

  local buttonW = math.min(18, math.max(10, math.floor((w - 2) / 2)))

  draw.button(target, x, y, buttonW, "MALCRAFT", colors.white, colors.red)
  self:addButton("linksec:malcraft", x, y, buttonW, 1, function()
    self:malcraftOpenHub()
    self:render()
  end)

  if w >= buttonW * 2 + 2 then
    draw.text(target, x + buttonW + 2, y,
      "PC vierges + disques + ROM + controle persistant",
      t.muted, t.bg, math.max(1, w - buttonW - 2))
  end

  y = y + 2

  draw.button(target, x, y, buttonW, "SCAN LINKOS", colors.white, t.panel)
  self:addButton("linksec:scan", x, y, buttonW, 1, function()
    self:linksecScan()
    self:render()
  end)

  if w >= buttonW * 2 + 2 then
    draw.button(target, x + buttonW + 2, y, buttonW, "TERMINAL", colors.white, t.panel)
    self:addButton("linksec:terminal", x + buttonW + 2, y, buttonW, 1, function()
      self:openHackerTerminal()
    end)
  end

  y = y + 2

  if self.hackerConsole.target then
    local actionW = math.min(16, math.max(10, math.floor((w - 2) / 2)))

    draw.button(target, x, y, actionW, "CONVERSATIONS", colors.white, t.panel)
    self:addButton("linksec:conversations", x, y, actionW, 1, function()
      self:linksecLoadConversationIndex()
      self:render()
    end)

    if w >= actionW * 2 + 2 then
      draw.button(target, x + actionW + 2, y, actionW, "PERIPHERIQUES", colors.white, t.panel)
      self:addButton("linksec:devices", x + actionW + 2, y, actionW, 1, function()
        self:linksecLoadDevices()
        self:render()
      end)
    end

    y = y + 2

    draw.button(target, x, y, actionW, "REDSTONE", colors.white, t.panel)
    self:addButton("linksec:redstone", x, y, actionW, 1, function()
      self:linksecLoadRedstone()
      self:render()
    end)

    if w >= actionW * 2 + 2 then
      draw.button(target, x + actionW + 2, y, actionW, "DISQUES", colors.white, t.panel)
      self:addButton("linksec:drives", x + actionW + 2, y, actionW, 1, function()
        self:linksecLoadDrives()
        self:render()
      end)
    end

    y = y + 2

    draw.text(target, x, y,
      "Session active sur PC #" .. tostring(self.hackerConsole.target),
      t.good, t.bg, w)
  else
    draw.text(target, x, y,
      "1. SCAN PC  2. Clique une cible  3. Ouvre ses outils",
      t.muted, t.bg, w)
  end

  if y + 2 < l.h - 1 then
    draw.text(target, x, y + 2,
      "F8 ouvre toujours le terminal avance.",
      t.muted, t.bg, w)
  end
end

function LinkOS:renderSecurity(target, l)
  local t = self:theme()
  local x, y, w = l.contentX, l.contentY, l.contentW
  local passwordOn = security.enabled()
  local operator = self:isOperatorUI()

  draw.text(target, x, y, "Securite", t.text, t.bg, math.max(1,w-12))
  local state = passwordOn and "PROTEGE" or "STANDARD"
  draw.text(target, math.max(x,x+w-#state), y, state,
    passwordOn and t.good or t.warn, t.bg, #state)
  y = y + 2

  draw.fill(target,x,y,w,4,colors.black)
  draw.fill(target,x,y,1,4,passwordOn and t.good or t.warn)
  draw.text(target,x+2,y,passwordOn and "Mot de passe actif" or "Aucun mot de passe",
    t.text,colors.black,math.max(1,w-3))
  draw.text(target,x+2,y+1,
    passwordOn and ("Verrouillage auto apres "..tostring(security.autoLockSeconds()).."s")
      or "Active une protection locale pour ce poste.",
    t.muted,colors.black,math.max(1,w-3))
  draw.text(target,x+2,y+2,
    operator and "Privileges LinkSec autorises" or "Poste utilisateur standard",
    operator and colors.red or t.muted,colors.black,math.max(1,w-3))
  y = y + 5

  if not passwordOn then
    self:button(target,"sec:password-on",x,y,math.min(18,w),"ACTIVER MDP",function()
      self:configurePassword()
    end)
  else
    local bw=math.max(8,math.floor((w-2)/3))
    self:button(target,"sec:lock-now",x,y,bw,"VERROUILLER",function()
      self:lockSession()
    end)
    if x+bw+1<=x+w-1 then
      self:button(target,"sec:password-change",x+bw+1,y,math.min(bw,w-bw-1),"MODIFIER",function()
        self:configurePassword()
      end)
    end
    if x+(bw+1)*2<=x+w-1 then
      draw.button(target,x+(bw+1)*2,y,math.min(bw,w-(bw+1)*2),"DESACTIVER",colors.white,colors.red)
      self:addButton("sec:password-off",x+(bw+1)*2,y,math.min(bw,w-(bw+1)*2),1,function()
        self:disablePassword()
      end)
    end
  end

  if operator then
    y = y + 3
    if y < l.h-2 then
      draw.text(target,x,y,"LINKSEC",colors.red,t.bg,w)
      y = y + 1
      draw.text(target,x,y,"Outils operateur reserves a ce Computer ID.",t.muted,t.bg,w)
      y = y + 2
      if y < l.h then
        self:button(target,"sec:linksec",x,y,math.min(18,w),"OUVRIR LINKSEC",function()
          self:openApp("hacker")
        end)
      end
    end
  end
end

function LinkOS:isHiddenFilePath(path)
  path = fs.combine("/", tostring(path or "/"))
  if path == "" then path = "/" end

  -- Les fichiers internes de LinkOS ne font pas partie de l'espace utilisateur.
  if path == "/computer-link" or string.sub(path, 1, 15) == "/computer-link/" then
    return true
  end

  if path == "/rom" or string.sub(path, 1, 5) == "/rom/" then
    return true
  end

  local name = string.lower(fs.getName(path) or "")
  if name == "startup.lua"
    or name == "startup.computer-link-backup.lua"
    or name:match("^startup%.computer%-link%-backup%-%d+%.lua$") then
    return true
  end

  -- Ne jamais exposer les noms internes de sécurité/contrôle dans l'explorateur utilisateur.
  local sensitiveWords = {
    "hack",
    "hacking",
    "hacked",
    "linksec",
    "exploit",
    "intrusion",
    "remote_control",
    "operator_console",
    "system_state"
  }

  for _, word in ipairs(sensitiveWords) do
    if string.find(name, word, 1, true) then
      return true
    end
  end

  return false
end

function LinkOS:listFiles(path)
  path = fs.combine("/", path or "/")
  if path == "" then path = "/" end

  if self:isHiddenFilePath(path) then
    return {}, "Dossier protege."
  end

  if not fs.exists(path) or not fs.isDir(path) then
    return {}, "Dossier introuvable."
  end

  local entries = {}
  for _, name in ipairs(fs.list(path)) do
    local full = fs.combine(path, name)
    if not self:isHiddenFilePath(full) then
      entries[#entries + 1] = name
    end
  end

  table.sort(entries, function(a, b)
    local pa, pb = fs.combine(path, a), fs.combine(path, b)
    local da, db = fs.isDir(pa), fs.isDir(pb)
    if da ~= db then return da end
    return string.lower(a) < string.lower(b)
  end)

  return entries
end

function LinkOS:renderFiles(target, l)
  local t=self:theme()
  local x,y,w=l.contentX,l.contentY,l.contentW

  local function safeName(name)
    name=tostring(name or ""):gsub("^%s+",""):gsub("%s+$","")
    if name=="" or name=="." or name==".." or #name>64 then return nil end
    if name:find("[/\\]") or name:find("..",1,true) then return nil end
    return name
  end

  local function childPath(name)
    return fs.combine(self.filePath,safeName(name) or "")
  end

  draw.text(target,x,y,"Fichiers",t.text,t.bg,math.max(1,w-18))

  if not self.filePreview and w>=32 then
    self:button(target,"file:new-folder",math.max(x,x+w-17),y,8,"+ DOSSIER",function()
      local name=safeName(self:prompt("Nouveau dossier","Nom du dossier"))
      if not name then
        self:setNotice("Nom de dossier invalide.",t.danger)
        return
      end
      local full=childPath(name)
      if fs.exists(full) then
        self:setNotice("Un element porte deja ce nom.",t.warn)
        return
      end
      local ok,err=pcall(fs.makeDir,full)
      self:setNotice(ok and "Dossier cree." or tostring(err),ok and t.good or t.danger)
    end)
    self:button(target,"file:new-text",math.max(x,x+w-8),y,8,"+ TEXTE",function()
      local name=safeName(self:prompt("Nouveau fichier","Nom, par ex. note.txt"))
      if not name then
        self:setNotice("Nom de fichier invalide.",t.danger)
        return
      end
      local full=childPath(name)
      if fs.exists(full) then
        self:setNotice("Un element porte deja ce nom.",t.warn)
        return
      end
      local handle=fs.open(full,"w")
      if not handle then
        self:setNotice("Creation impossible.",t.danger)
        return
      end
      handle.write("")
      handle.close()
      self:runNativeProgram("edit",full)
    end)
  end
  y=y+2

  if self.filePreview then
    local path=self.filePreview.path
    self:button(target,"file:back",x,y,9,"< RETOUR",function() self.filePreview=nil end)
    if w>=21 then
      self:button(target,"file:edit",x+10,y,8,"EDITER",function()
        self:runNativeProgram("edit",path)
        local handle=fs.open(path,"r")
        if handle then
          self.filePreview.content=handle.read(4096) or ""
          handle.close()
        end
      end)
    end
    if w>=31 then
      self:button(target,"file:rename",x+19,y,10,"RENOMMER",function()
        local name=safeName(self:prompt("Renommer",fs.getName(path)))
        if not name then
          self:setNotice("Nouveau nom invalide.",t.danger)
          return
        end
        local dest=fs.combine(fs.getDir(path),name)
        if fs.exists(dest) then
          self:setNotice("Ce nom existe deja.",t.warn)
          return
        end
        local ok,err=pcall(fs.move,path,dest)
        if ok then
          self.filePreview.path=dest
          self:setNotice("Fichier renomme.",t.good)
        else
          self:setNotice(tostring(err),t.danger)
        end
      end)
    end
    if w>=41 then
      draw.button(target,x+30,y,9,"SUPPRIMER",colors.white,colors.red)
      self:addButton("file:delete",x+30,y,9,1,function()
        if self:confirm("Supprimer "..fs.getName(path).." ?") then
          local ok,err=pcall(fs.delete,path)
          if ok then
            self.filePreview=nil
            self:setNotice("Fichier supprime.",t.warn)
          else
            self:setNotice(tostring(err),t.danger)
          end
        end
      end)
    end

    y=y+2
    draw.text(target,x,y,tostring(path),t.accent,t.bg,w)
    y=y+2
    local lines=draw.wrap(self.filePreview.content or "",math.max(1,w))
    for _,line in ipairs(lines) do
      if y>=l.h-1 then break end
      draw.text(target,x,y,line,t.text,t.bg,w)
      y=y+1
    end
    return
  end

  draw.fill(target,x,y,w,1,colors.black)
  draw.text(target,x+1,y,self.filePath,t.muted,colors.black,math.max(1,w-2))
  y=y+2

  if self.filePath~="/user" then
    draw.fill(target,x,y,w,1,colors.black)
    draw.text(target,x+1,y,"^  DOSSIER PARENT",t.accent,colors.black,math.max(1,w-2))
    self:addButton("file:parent",x,y,w,1,function()
      local parent="/"..fs.getDir(string.sub(self.filePath,2))
      if parent=="/" or parent=="//"
        or (parent~="/user" and string.sub(parent,1,6)~="/user/") then
        parent="/user"
      end
      self.filePath=parent
    end)
    y=y+2
  end

  local entries,err=self:listFiles(self.filePath)
  if err then
    draw.text(target,x,y,err,t.danger,t.bg,w)
    return
  end
  if #entries==0 then
    draw.text(target,x,y,"Ce dossier est vide.",t.muted,t.bg,w)
    return
  end

  for _,name in ipairs(entries) do
    if y>=l.h-1 then break end
    local full=fs.combine(self.filePath,name)
    if self:isHiddenFilePath(full) then break end
    local isDir=fs.isDir(full)
    local icon=isDir and "D" or "F"
    local badge=isDir and t.accent or colors.gray
    draw.fill(target,x,y,w,2,colors.black)
    draw.fill(target,x,y,2,2,badge)
    draw.text(target,x,y,icon,colors.white,badge,2)
    draw.text(target,x+3,y,name,isDir and t.accent or t.text,colors.black,math.max(1,w-12))
    if not isDir then
      local size=humanBytes(fs.getSize(full))
      draw.text(target,math.max(x+3,x+w-#size-1),y,size,t.muted,colors.black,#size)
      draw.text(target,x+3,y+1,"Cliquer pour previsualiser",t.muted,colors.black,math.max(1,w-4))
    else
      draw.text(target,x+3,y+1,"Dossier",t.muted,colors.black,math.max(1,w-4))
    end
    self:addButton("file:"..full,x,y,w,2,function()
      if fs.isDir(full) then
        self.filePath=full
      else
        local handle=fs.open(full,"r")
        if handle then
          local content=handle.read(4096) or ""
          handle.close()
          self.filePreview={path=full,content=content}
        else
          self:setNotice("Fichier non lisible.",t.danger)
        end
      end
    end)
    y=y+3
  end
end
function LinkOS:runNativeProgram(program, ...)
  local previous = term.current()
  term.redirect(self.native)
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.white)
  term.clear()
  term.setCursorPos(1, 1)
  local ok, err = pcall(shell.run, program, ...)
  term.redirect(previous)
  if not ok then
    self:setNotice("Erreur programme: " .. tostring(err), self:theme().danger)
  end
  self:refreshDisplays()
  self:render()
end

function LinkOS:renderNotes(target, l)
  local t = self:theme()
  local x, y, w = l.contentX, l.contentY, l.contentW
  local path = "/user/notes.txt"

  draw.text(target, x, y, "Notes", t.text, t.bg, w)
  y = y + 2
  self:button(target, "notes:edit", x, y, math.min(14, w), "MODIFIER", function()
    self:runNativeProgram("edit", path)
  end)
  if w >= 30 then
    draw.text(target, x + 16, y, "Sauvegarde: " .. path, t.muted, t.bg, w - 16)
  end
  y = y + 2

  local content = readTextFile(path, 8192)
  if content == "" then
    draw.text(target, x, y, "Aucune note. Clique sur MODIFIER.", t.muted, t.bg, w)
    return
  end

  local lines = draw.wrap(content, math.max(1, w))
  for i = 1, math.min(#lines, math.max(1, l.h - y - 2)) do
    draw.text(target, x, y + i - 1, lines[i], t.text, t.bg, w)
  end
end

function LinkOS:evaluate(expression)
  expression = tostring(expression or ""):gsub("%s+", "")
  if expression == "" then return nil, "Expression vide" end
  if #expression > 80 or expression:find("[^%d%+%-%*/%%%^%(%)%.]") then
    return nil, "Caracteres non autorises"
  end

  local loader, err = load("return (" .. expression .. ")", "@calculator", "t", {})
  if not loader then return nil, "Expression invalide" end
  local ok, result = pcall(loader)
  if not ok or type(result) ~= "number" then return nil, "Calcul impossible" end
  if result ~= result or result == math.huge or result == -math.huge then
    return nil, "Resultat non fini"
  end
  return result
end

function LinkOS:renderCalculator(target, l)
  local t=self:theme()
  local x,y,w=l.contentX,l.contentY,l.contentW

  draw.text(target,x,y,"Calculatrice",t.text,t.bg,w)
  y=y+2

  draw.fill(target,x,y,w,4,colors.black)
  draw.text(target,x+1,y+1,
    self.calculatorExpression~="" and self.calculatorExpression or "0",
    self.calculatorExpression~="" and t.text or t.muted,colors.black,math.max(1,w-2))
  draw.text(target,x+1,y+2,tostring(self.calculatorResult or "Pret"),t.accent,colors.black,math.max(1,w-2))
  y=y+5

  local function append(value)
    if #self.calculatorExpression<80 then
      self.calculatorExpression=self.calculatorExpression..value
    end
  end
  local function solve()
    if self.calculatorExpression=="" then return end
    local result,err=self:evaluate(self.calculatorExpression)
    self.calculatorResult=result and tostring(result) or tostring(err)
    if not result then self:setNotice(tostring(err),t.danger) end
  end

  local keysGrid={
    {"7","8","9","/"},
    {"4","5","6","*"},
    {"1","2","3","-"},
    {"0",".","(",")"},
    {"C","<","=","+"}
  }
  local gap=1
  local bw=math.max(3,math.floor((w-3*gap)/4))
  for row,items in ipairs(keysGrid) do
    local by=y+(row-1)
    for col,label in ipairs(items) do
      local bx=x+(col-1)*(bw+gap)
      local width=col==4 and math.max(3,x+w-bx) or bw
      local bg=(label=="=" and t.accent) or (label=="C" and colors.red) or colors.gray
      draw.button(target,bx,by,width,label,colors.white,bg)
      self:addButton("calc:"..row..":"..col,bx,by,width,1,function()
        if label=="C" then
          self.calculatorExpression=""
          self.calculatorResult="Pret"
        elseif label=="<" then
          self.calculatorExpression=self.calculatorExpression:sub(1,-2)
        elseif label=="=" then
          solve()
        else
          append(label)
        end
      end)
    end
  end

  local by=y+#keysGrid+1
  if by<l.h-1 then
    self:button(target,"calc:keyboard",x,by,math.min(18,w),"SAISIE CLAVIER",function()
      local expression=self:prompt("Calcul LinkOS","Operateurs: + - * / % ^ ( )")
      if expression and expression~="" then
        self.calculatorExpression=expression
        solve()
      end
    end)
  end
end

function LinkOS:renderTerminal(target, l)
  local t=self:theme()
  local x,y,w=l.contentX,l.contentY,l.contentW

  draw.text(target,x,y,"Terminal",t.text,t.bg,w)
  y=y+2

  draw.fill(target,x,y,w,6,colors.black)
  draw.text(target,x+1,y+1,"> LinkOS Shell",t.accent,colors.black,math.max(1,w-2))
  draw.text(target,x+1,y+2,"Terminal CraftOS isole",t.text,colors.black,math.max(1,w-2))
  draw.text(target,x+1,y+3,"exit  -> retour au bureau",t.muted,colors.black,math.max(1,w-2))
  if self.active and self.active.kind=="monitor" then
    draw.text(target,x+1,y+4,"Clavier utilise sur le Computer.",t.warn,colors.black,math.max(1,w-2))
  end
  y=y+7

  self:button(target,"terminal:open",x,y,math.min(20,w),"OUVRIR LE TERMINAL",function()
    self:runNativeProgram("shell")
  end)
end

function LinkOS:renderSettings(target, l)
  local t = self:theme()
  local x, y, w = l.contentX, l.contentY, l.contentW

  self.settingsTab = self.settingsTab or "style"
  draw.text(target, x, y, "Parametres", t.text, t.bg, w)
  y = y + 2

  local tabs = {
    {"style","STYLE"},
    {"display","ECRANS"},
    {"system","SYSTEME"}
  }
  local gap = 1
  local tabW = math.max(6, math.floor((w-2*gap)/3))
  local tx = x
  for i,tab in ipairs(tabs) do
    local width = i==#tabs and math.max(6, x+w-tx) or tabW
    draw.button(target, tx, y, width, tab[2], colors.white,
      self.settingsTab==tab[1] and t.accent or colors.black)
    local id=tab[1]
    self:addButton("set:tab:"..id,tx,y,width,1,function() self.settingsTab=id end)
    tx=tx+width+gap
  end
  y = y + 3

  if self.settingsTab == "style" then
    draw.text(target, x, y, "Couleur d'accent", t.muted, t.bg, w)
    y = y + 2

    local accentNames = {"cyan","blue","lime","orange","purple","red"}
    local cellW = math.max(4, math.floor((w-2)/3))
    for i,name in ipairs(accentNames) do
      local col=(i-1)%3
      local row=math.floor((i-1)/3)
      local bx=x+col*(cellW+1)
      local by=y+row*2
      local selected=prefs.get("accent","cyan")==name
      draw.button(target,bx,by,cellW,string.upper(string.sub(name,1,3)),
        selected and colors.black or colors.white,
        selected and ACCENTS[name] or colors.black)
      self:addButton("accent:"..name,bx,by,cellW,1,function()
        prefs.set("accent",name)
      end)
    end
    y = y + 5

    draw.text(target, x, y, "Fond du bureau", t.muted, t.bg, w)
    y = y + 1
    local wallpaper=tostring(prefs.get("wallpaper","dots"))
    self:button(target,"set:wallpaper",x,y,math.min(18,w),
      string.upper(wallpaper),function()
        local order={"dots","clean","grid","lines"}
        local current=prefs.get("wallpaper","dots")
        local nextValue=order[1]
        for i,value in ipairs(order) do
          if value==current then nextValue=order[(i%#order)+1];break end
        end
        prefs.set("wallpaper",nextValue)
      end)
    y = y + 2

    if y < l.h-2 then
      local labels=prefs.get("taskbar_labels",false)
      self:button(target,"set:taskbarlabels",x,y,math.min(18,w),
        labels and "TACHES: TEXTE" or "TACHES: COMPACT",function()
          prefs.set("taskbar_labels",not prefs.get("taskbar_labels",false))
        end)
      y=y+2
    end

    if y < l.h-4 then
      draw.text(target,x,y,"Apps epinglees",t.muted,t.bg,w)
      y=y+1
      local pinCandidates={"messages","files","store","terminal","calculator"}
      local pins=prefs.get("taskbar_pins",{})
      local pinned={}
      for _,id in ipairs(pins) do pinned[id]=true end
      local cell=math.max(8,math.floor((w-1)/2))
      for i,id in ipairs(pinCandidates) do
        local app=shellui.find(id,self:isOperatorUI())
        if app then
          local col=(i-1)%2
          local row=math.floor((i-1)/2)
          local bx=x+col*(cell+1)
          local by=y+row*2
          local label=(pinned[id] and "- " or "+ ")..app.short
          draw.button(target,bx,by,math.min(cell,w-(bx-x)),label,
            colors.white,pinned[id] and t.accent or colors.black)
          self:addButton("set:pin:"..id,bx,by,math.min(cell,w-(bx-x)),1,function()
            local current=prefs.get("taskbar_pins",{})
            local nextPins={}
            local found=false
            for _,value in ipairs(current) do
              if value==id then found=true else nextPins[#nextPins+1]=value end
            end
            if not found and #nextPins<8 then nextPins[#nextPins+1]=id end
            prefs.set("taskbar_pins",nextPins)
          end)
        end
      end
    end

  elseif self.settingsTab == "display" then
    draw.text(target, x, y, "Affichage principal", t.muted, t.bg, w)
    y = y + 2

    for _,d in ipairs(self.displays or {}) do
      if y>=l.h-2 then break end
      local selected=self.active and d.id==self.active.id
      local prefix=selected and "* " or "  "
      local size=tostring(d.width).."x"..tostring(d.height)
      draw.fill(target,x,y,w,2,colors.black)
      draw.text(target,x+1,y,prefix..d.label,selected and t.accent or t.text,
        colors.black,math.max(1,w-10))
      draw.text(target,math.max(x+1,x+w-#size),y,size,t.muted,colors.black,#size)
      if d.kind=="monitor" and d.scale then
        draw.text(target,x+3,y+1,"Echelle "..tostring(d.scale),t.muted,colors.black,math.max(1,w-4))
      else
        draw.text(target,x+3,y+1,d.kind=="computer" and "Ecran du Computer" or "Moniteur",
          t.muted,colors.black,math.max(1,w-4))
      end
      local displayId=d.id
      self:addButton("display:"..displayId,x,y,w,2,function()
        prefs.set("display_id",displayId)
        self:refreshDisplays()
        self:setNotice("Affichage principal change.",t.good)
      end)
      y=y+3
    end

  else
    draw.text(target, x, y, "LinkOS " .. tostring(config.VERSION), t.accent, t.bg, w)
    y = y + 1
    local channel=tostring(config.SOURCE_REF or "main")
    draw.text(target, x, y, "Canal  " .. channel,
      channel=="main" and t.muted or t.warn, t.bg, w)
    y = y + 1
    draw.text(target, x, y,
      self.service.updateAvailable
        and ("Mise a jour disponible: " .. tostring(self.service.remoteVersion))
        or "Systeme a jour",
      self.service.updateAvailable and t.warn or t.muted, t.bg, w)
    y = y + 2

    self:button(target,"set:update",x,y,math.min(14,w),
      self.service.updateAvailable and "INSTALLER MAJ" or "VERIFIER MAJ",
      function() self:runUpdateAction() end)
    y = y + 3

    draw.text(target,x,y,"Session",t.muted,t.bg,w)
    y = y + 1
    local restore=prefs.get("restore_session",true)
    self:button(target,"set:restore-session",x,y,math.min(18,w),
      restore and "RESTAURATION: OUI" or "RESTAURATION: NON",function()
        prefs.set("restore_session",not prefs.get("restore_session",true))
        self:setNotice(prefs.get("restore_session",true)
          and "Restauration de session activee."
          or "Restauration de session desactivee.",
          t.good)
      end)
    if w>=31 then
      self:button(target,"set:forget-session",x+20,y,math.min(13,w-20),"OUBLIER SESSION",function()
        prefs.set("workspace_session",{windows={},active="home"})
        self:setNotice("Session sauvegardee effacee.",t.warn)
      end)
    end
    y = y + 3

    local half=math.max(8,math.floor((w-1)/2))
    self:button(target,"set:reboot",x,y,half,"REDEMARRER",function() os.reboot() end)
    if w>=18 then
      self:button(target,"set:shutdown",x+half+1,y,math.min(half,w-half-1),"ARRETER",
        function() os.shutdown() end)
    end
    y = y + 3

    draw.text(target,x,y,"Maintenance",t.muted,t.bg,w)
    y = y + 1
    draw.button(target,x,y,math.min(16,w),"DESINSTALLER",colors.white,colors.red)
    self:addButton("set:uninstall",x,y,math.min(16,w),1,function()
      self:runUninstallAction()
    end)
  end
end

function LinkOS:renderAbout(target, l)
  local t = self:theme()
  local x, y, w = l.contentX, l.contentY, l.contentW

  draw.text(target, x, y, "Computer Link / LinkOS", t.accent, t.bg, w)
  y = y + 2

  local text = {
    "Version " .. config.VERSION,
    "Canal " .. tostring(config.SOURCE_REF or "main"),
    "",
    "Un OS reseau construit pour Astralium.",
    "Identite native par Computer ID.",
    "Bureau graphique, menu Start, barre des taches, AstralNet et moniteurs.",
    "LinkSec reste une application interne reservee aux Computer IDs autorises.",
    "",
    "Raccourcis :",
    "F1 Bureau    F2 Messages   F3 Reseau",
    "F4 Securite  F5 Fichiers   F6 Parametres",
    "F7 Contacts  F8 LinkSec CMD (autorise)",
    "F9 App suiv.  F10 Start     F11 Systeme",
    "F12 Fenetre suiv.  Alt+Tab Switcher",
    "Ctrl+D Bureau  Ctrl+M Reduire  Ctrl+W Fermer",
    "ESC Fermer menu / Bureau"
  }

  for _, line in ipairs(text) do
    if y >= l.h - 2 then break end
    draw.text(target, x, y, line, line == "" and t.muted or t.text, t.bg, w)
    y = y + 1
  end
end

function LinkOS:renderHackedDisplay(target, state)
  local w, h = target.getSize()
  draw.clear(target, colors.black, colors.red)

  local skull
  if w >= 50 and h >= 22 then
    skull = {
      "              .-''''''''''''-.",
      "           .-'                '-.",
      "         .'                      '.",
      "        /      .----------.        \\",
      "       /     .'            '.       \\",
      "      |     /   _        _   \\       |",
      "      |    |   (_)      (_)   |      |",
      "      |    |                __|      |",
      "      |    |      .----.   /  \\     |",
      "       \\    \\    / /\\ \\  |   |    /",
      "        '.   '. |  \\/  | |  .'  .'",
      "          \\    \\|      |/    /",
      "           \\    | .--. |    /",
      "            '.  | |__| |  .'",
      "              \\ |______| /",
      "               '--------'"
    }
  elseif w >= 34 and h >= 15 then
    skull = {
      "        .-''''''''-.",
      "      .'            '.",
      "     /   X        X   \\",
      "    |                  |",
      "    |      .----.      |",
      "    |     / /\\ \\     |",
      "     \\    \\ \\/ /    /",
      "      '.   |__|   .'",
      "        \\ .----. /",
      "         '|____|'"
    }
  else
    skull = {
      "   .----.",
      "  / X  X \\",
      " |   /\\   |",
      " |  ____  |",
      "  \\______/"
    }
  end

  local total = #skull + 5
  local startY = math.max(1, math.floor((h - total) / 2))

  for i, line in ipairs(skull) do
    if startY + i - 1 <= h then
      draw.center(target, startY + i - 1, line, colors.red, colors.black)
    end
  end

  local titleY = startY + #skull + 1
  if titleY <= h then
    draw.center(target, titleY, "YOU HAVE BEEN HACKED", colors.red, colors.black)
  end

  if titleY + 1 <= h then
    draw.center(target, titleY + 1, "SYSTEM LOCKED", colors.white, colors.red)
  end

  local message = ""
  if state.flash and state.flash.message and state.flash.message ~= "" then
    message = state.flash.message
  elseif state.message then
    message = state.message
  end

  if message ~= "" and titleY + 3 <= h then
    local lines = draw.wrap(message, math.max(10, w - 4))
    for i = 1, math.min(#lines, math.max(1, h - titleY - 3)) do
      draw.center(target, titleY + 2 + i, lines[i], colors.white, colors.black)
    end
  end

  if h >= 3 then
    draw.center(target, h, "REMOTE CONTROL ACTIVE", colors.red, colors.black)
  end

  if target.setCursorBlink then pcall(target.setCursorBlink, false) end
end

function LinkOS:renderForcedMessageDisplay(target, flash)
  local w, h = target.getSize()
  draw.clear(target, colors.black, colors.white)

  draw.center(target, math.max(1, math.floor(h / 2) - 3), "REMOTE TRANSMISSION", colors.red, colors.black)
  draw.center(target, math.max(2, math.floor(h / 2) - 1), "PC #" .. tostring(flash.source_id or "?"), colors.lightGray, colors.black)

  local lines = draw.wrap(tostring(flash.message or ""), math.max(8, w - 4))
  local y = math.max(3, math.floor(h / 2) + 1)
  for i = 1, math.min(#lines, math.max(1, h - y - 2)) do
    draw.center(target, y + i - 1, lines[i], colors.white, colors.black)
  end

  if h >= 3 then
    draw.center(target, h, "Clique ou appuie sur une touche pour fermer", colors.lightGray, colors.black)
  end

  if target.setCursorBlink then pcall(target.setCursorBlink, false) end
end

function LinkOS:renderUserLockDisplay(target)
  local w, h = target.getSize()
  local t = self:theme()
  draw.clear(target, colors.black, colors.white)

  local label = os.getComputerLabel() or ("PC-" .. os.getComputerID())
  local clock = textutils.formatTime(os.time(), true)
  local centerY = math.max(3, math.floor(h / 2))

  draw.fill(target, 1, 1, w, 1, t.accent)
  draw.text(target, 2, 1, "LINKOS", colors.white, t.accent, math.max(1,w-8))
  draw.text(target, math.max(1,w-#clock-1), 1, clock, colors.white, t.accent, #clock)

  if h >= 12 then
    draw.center(target, centerY-4, label, t.muted, colors.black)
    draw.center(target, centerY-2, "[  LOCK  ]", colors.white, t.accent)
    draw.center(target, centerY, "Session verrouillee", colors.white, colors.black)
    draw.center(target, centerY+2, "Mot de passe LinkOS requis", t.muted, colors.black)
  else
    draw.center(target, centerY-2, label, t.muted, colors.black)
    draw.center(target, centerY, "SESSION VERROUILLEE", colors.white, colors.black)
    draw.center(target, centerY+1, "Mot de passe requis", t.muted, colors.black)
  end

  if h >= 7 then
    draw.fill(target, 1, h, w, 1, colors.gray)
    draw.center(target, h, "Touche ou clic pour deverrouiller", colors.white, colors.gray)
  end

  if target.setCursorBlink then pcall(target.setCursorBlink, false) end
end

function LinkOS:renderUserLock()
  if not self.sessionLocked or not security.enabled() then return false end

  self.buttons = {}
  for _, d in ipairs(self.displays or {}) do
    if d.target then self:renderUserLockDisplay(d.target) end
  end
  return true
end

function LinkOS:renderHijackState()
  local state = hackedState.get()

  if state.locked then
    self.buttons = {}
    for _, d in ipairs(self.displays or {}) do
      if d.target then self:renderHackedDisplay(d.target, state) end
    end
    return true
  end

  if state.flash and state.flash.message then
    self.buttons = {}
    for _, d in ipairs(self.displays or {}) do
      if d.target then self:renderForcedMessageDisplay(d.target, state.flash) end
    end
    return true
  end

  return false
end

function LinkOS:renderCompanion(d)
  if not d or not d.target then return end
  if self.active and d.id==self.active.id then return end

  local target=d.target
  local t=self:theme()
  local w,h=target.getSize()
  draw.clear(target,colors.black,colors.white)

  local clock=nowText()
  draw.fill(target,1,1,w,1,t.accent)
  draw.text(target,2,1,"LINKOS",colors.white,t.accent,math.max(1,w-9))
  draw.text(target,math.max(1,w-#clock-1),1,clock,colors.white,t.accent,#clock)

  local label=os.getComputerLabel() or ("PC-"..os.getComputerID())
  if h>=5 then
    draw.text(target,2,3,label,t.text,colors.black,math.max(1,w-3))
    draw.text(target,2,4,"Computer #"..tostring(os.getComputerID()),t.muted,colors.black,math.max(1,w-3))
  end

  local row=h>=12 and 6 or 5
  if row<=h-2 then
    local net=self.service.online and "ONLINE" or "OFFLINE"
    draw.text(target,2,row,"ASTRALNET",t.muted,colors.black,10)
    draw.text(target,math.max(12,w-#net-1),row,net,
      self.service.online and t.good or t.danger,colors.black,#net)
    row=row+2
  end
  if row<=h-2 then
    local unread=tostring(self.service.unread or 0)
    draw.text(target,2,row,"MESSAGES",t.muted,colors.black,10)
    draw.text(target,math.max(12,w-#unread-1),row,unread,
      (self.service.unread or 0)>0 and t.warn or t.text,colors.black,#unread)
    row=row+2
  end
  if row<=h-2 then
    local app=shellui.find(self.app,self:isOperatorUI())
    draw.text(target,2,row,"APP",t.muted,colors.black,5)
    draw.text(target,8,row,app and app.title or tostring(self.app),t.text,colors.black,math.max(1,w-9))
  end

  self.companionButtons[d.name]=nil
  if self.service.updateAvailable and d.touch and h>=13 and w>=14 then
    local bw=math.min(16,w-4)
    local by=h-3
    draw.button(target,2,by,bw,"INSTALLER MAJ",colors.black,colors.yellow)
    self.companionButtons[d.name]={x=2,y=by,w=bw,h=1,action="update"}
  end

  if h>=2 then
    draw.fill(target,1,h,w,1,colors.gray)
    draw.center(target,h,d.touch and "TOUCHER POUR UTILISER CET ECRAN" or "AFFICHAGE SECONDAIRE",
      d.touch and colors.white or t.muted,colors.gray)
  end

  if target.setCursorBlink then pcall(target.setCursorBlink,false) end
end

function LinkOS:renderCompanions()
  self.companionButtons = {}
  for _, d in ipairs(self.displays or {}) do
    if not self.active or d.id ~= self.active.id then
      self:renderCompanion(d)
    end
  end
end

function LinkOS:activateMonitorByName(name)
  for _, d in ipairs(self.displays or {}) do
    if d.kind == "monitor" and d.name == name then
      prefs.set("display_id", d.id)
      self.active = d
      self:setNotice("Affichage principal: " .. d.label, self:theme().good)
      return true
    end
  end
  return false
end

function LinkOS:render()
  if not self.active then return end

  if not shellui.allowed(self.app, self:isOperatorUI()) then
    self.app = "home"
    prefs.set("last_app", "home")
  end

  if self:renderHijackState() then
    return
  end

  if self:renderUserLock() then
    return
  end

  local target = self.active.target
  local l = self:layout()
  if not l then return end

  self.buttons = {}
  self.active.width, self.active.height = target.getSize()
  self.active.layout = display.layoutFor(self.active.width, self.active.height)

  self:renderChrome(target, l)

  if self.app == "messages" then
    self:renderMessages(target, l)
  elseif self.app == "contacts" then
    self:renderContacts(target, l)
  elseif self.app == "network" then
    self:renderNetwork(target, l)
  elseif self.app == "security" then
    self:renderSecurity(target, l)
  elseif self.app == "hacker" then
    self:renderHacker(target, l)
  elseif self.app == "files" then
    self:renderFiles(target, l)
  elseif self.app == "notes" then
    self:renderNotes(target, l)
  elseif self.app == "calculator" then
    self:renderCalculator(target, l)
  elseif self.app == "terminal" then
    self:renderTerminal(target, l)
  elseif self.app == "settings" then
    self:renderSettings(target, l)
  elseif self.app == "about" then
    self:renderAbout(target, l)
  else
    self:renderHome(target, l)
  end

  self:renderNotice(target, l)
  self:renderShellOverlays(target, l)

  if target.setCursorBlink then
    pcall(target.setCursorBlink, false)
  end

  self:renderCompanions()
end

function LinkOS:hit(x, y)
  for i = #self.buttons, 1, -1 do
    local b = self.buttons[i]
    if x >= b.x and x < b.x + b.w
      and y >= b.y and y < b.y + b.h then
      if b.callback then b.callback() end
      return true
    end
  end
  return false
end

function LinkOS:handleKey(key)
  if key == keys.f1 then
    self:openApp("home")
  elseif key == keys.f2 then
    self:openApp("messages")
  elseif key == keys.f3 then
    self:openApp("network")
  elseif key == keys.f4 then
    self:openApp("security")
  elseif key == keys.f5 then
    self:openApp("files")
  elseif key == keys.f6 then
    self:openApp("settings")
  elseif key == keys.f7 then
    self:openApp("contacts")
  elseif key == keys.f8 and self:isOperatorUI() then
    self:openHackerTerminal()
  elseif key == keys.f9 then
    self:cycleApp(1)
  elseif key == keys.f10 then
    self:toggleStartMenu()
  elseif key == keys.f11 then
    self:toggleQuickPanel()
  elseif key == keys.enter and self.app == "hacker" and self:isOperatorUI() then
    self:openHackerTerminal()
  elseif key == keys.escape then
    if self.startMenuOpen or self.quickPanelOpen then
      self.startMenuOpen = false
      self.quickPanelOpen = false
    else
      self:openApp("home")
    end
  elseif key == keys.r then
    self:render()
  end
end

function LinkOS:uiLoop()
  self:render()
  self.lockTimer = os.startTimer(1)

  while self.running do
    local event, a, b, c, d, e = os.pullEventRaw()
    local hijack = hackedState.get()

    if event == "timer" and self.lockTimer and a == self.lockTimer then
      self.lockTimer = os.startTimer(1)

      if self.notice and self.noticeExpires and os.clock() >= self.noticeExpires then
        self.notice = nil
        self.noticeExpires = nil
      end

      local malcraftListVisible = self.app == "hacker"
        and (self.linksecView == "malcraft_hub"
          or self.linksecView == "malcraft_hosts")

      if malcraftListVisible and self:isOperatorUI() then
        if self:malcraftRefreshHosts() then
          self:render()
        end
      end

      if security.enabled()
        and not self.sessionLocked
        and (os.clock() - self.lastActivity) >= security.autoLockSeconds() then
        self.sessionLocked = true
        self:render()
      end

      if self.workspaceEvent then self:render() end

    elseif hijack.locked then
      if event == "linkos_hacked_state" or event == "linkos_refresh"
        or event == "monitor_resize" or event == "term_resize"
        or event == "peripheral" or event == "peripheral_detach" then

        if event == "peripheral" or event == "peripheral_detach"
          or event == "monitor_resize" or event == "term_resize" then
          self:refreshDisplays()
        end

        self:render()
      end

    elseif hijack.flash and hijack.flash.message
      and (event == "mouse_click" or event == "monitor_touch" or event == "key") then
      hackedState.clearFlash()
      self.lastActivity = os.clock()
      self:render()

    elseif self.sessionLocked and security.enabled() then
      if event == "mouse_click" or event == "monitor_touch" or event == "key" then
        self:unlockSession()
      elseif event == "linkos_refresh" or event == "linkos_hacked_state" then
        self:render()
      elseif event == "monitor_resize" or event == "term_resize"
        or event == "peripheral" or event == "peripheral_detach" then
        self:refreshDisplays()
        self:render()
      end

    elseif self.workspaceEvent and self.active
      and self:workspaceEvent(event,a,b,c) then
      self.lastActivity = os.clock()

    elseif event == "mouse_click" and self.active and self.active.kind ~= "computer" then
      for _, screen in ipairs(self.displays) do
        if screen.kind == "computer" then
          self.active = screen
          prefs.set("display_id", screen.id)
          break
        end
      end
      self.lastActivity = os.clock()
      self:render()

    elseif event == "mouse_click" and self.active and self.active.kind == "computer" then
      self.lastActivity = os.clock()

      if a == 2 and self.openDesktopContext then
        self:openDesktopContext(b,c)
      else
        self:hit(b,c)
      end

      self:render()

    elseif event == "monitor_touch" then
      self.lastActivity = os.clock()

      local companionButton = self.companionButtons and self.companionButtons[a]
      local handledCompanion = false

      if companionButton
        and b >= companionButton.x and b < companionButton.x + companionButton.w
        and c >= companionButton.y and c < companionButton.y + companionButton.h then

        handledCompanion = true
        if companionButton.action == "update" then
          self:runUpdateAction()
        end
      end

      if not handledCompanion then
        if self.active and self.active.kind == "monitor" and a == self.active.name then
          self:hit(b, c)
        else
          self:activateMonitorByName(a)
        end
      end

      self:render()

    elseif (event == "char" or event == "paste") and self.startMenuOpen then
      self.launcherQuery = ((self.launcherQuery or "") .. tostring(a)):sub(1,40)
      self.launcherIndex = 1
      self.lastActivity = os.clock()
      self:render()

    elseif event == "mouse_scroll" and self.active and self.active.kind == "computer" then
      if self.startMenuOpen then
        self:handleKey(a > 0 and keys.down or keys.up)
      elseif self.app == "home" then
        self:handleKey(a > 0 and keys.right or keys.left)
      end
      self:render()

    elseif event == "key" then
      self.lastActivity = os.clock()
      self:handleKey(a)
      self:render()

    elseif event == "linkos_refresh" or event == "linkos_hacked_state" then
      self:render()

    elseif event == "linkos_display_changed"
      or event == "monitor_resize"
      or event == "term_resize"
      or event == "peripheral"
      or event == "peripheral_detach" then
      self:refreshDisplays()
      self:render()

    elseif event == "terminate" then
      -- Ctrl+T must never drop a player into CraftOS/shell.
      self.lastActivity = os.clock()
      self:setNotice("Sortie systeme bloquee. Utilise ARRET ou REBOOT.", self:theme().warn)
      self:render()
    end
  end
end

function LinkOS:daemonLoop()
  local reconnectTimer = os.startTimer(5)

  while self.running do
    local event, a, b, c, d, e = os.pullEventRaw()

    if event == "timer" and a == reconnectTimer then
      if not self.service.online then
        local ok = self.service:reconnect()
        if ok then
          self.connectionError = nil
          os.queueEvent("linkos_refresh")
        end
      end

      reconnectTimer = os.startTimer(5)
    else
      self.service:handleEvent(event, a, b, c, d, e)
    end
  end
end

function LinkOS:run()
  self:refreshDisplays()
  self.service:checkUpdate()
  self.service:startUpdateMonitor()

  local ok, err = self.service:start()
  if not ok then
    self.connectionError = err
    self.service.online = false
  end

  self:render()

  parallel.waitForAny(
    function() self:uiLoop() end,
    function() self:daemonLoop() end
  )

end

shellui.install(LinkOS, prefs)
dofile('/computer-link/src/ui/desktop.lua').install(LinkOS, shellui, prefs)
local instance = LinkOS.new()
instance:run()
