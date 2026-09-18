local config = dofile("/computer-link/src/common/config.lua")
local draw = dofile("/computer-link/src/ui/draw.lua")
local display = dofile("/computer-link/src/ui/display.lua")
local prefs = dofile("/computer-link/src/ui/prefs.lua")
local Service = dofile("/computer-link/src/client/service.lua")

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

local APPS = {
  {id="home", title="Accueil", short="HOME"},
  {id="messages", title="Messages", short="MSG"},
  {id="network", title="Reseau", short="NET"},
  {id="security", title="Securite", short="SEC"},
  {id="files", title="Fichiers", short="FILES"},
  {id="settings", title="Parametres", short="SET"},
  {id="about", title="A propos", short="INFO"}
}

local function nowText()
  return textutils.formatTime(os.time(), true)
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
  self.filePath = "/"
  self.filePreview = nil
  self.notice = nil
  self.noticeColour = colors.lightGray
  self.running = true
  self.exitToCli = false
  self.connectionError = nil
  return self
end

function LinkOS:theme()
  local accentName = prefs.get("accent", "cyan")
  local accent = ACCENTS[accentName] or colors.cyan

  return {
    bg = colors.black,
    panel = colors.gray,
    panel2 = colors.lightGray,
    text = colors.white,
    muted = colors.lightGray,
    accent = accent,
    good = colors.lime,
    warn = colors.orange,
    danger = colors.red,
    sidebar = colors.gray,
    button = colors.gray
  }
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
end

function LinkOS:openApp(id)
  self.app = id
  prefs.set("last_app", id)
  self.notice = nil

  if id == "messages" then
    self.service:markRead()
  end

  self:render()
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

function LinkOS:layout()
  if not self.active then return nil end
  local w, h = self.active.target.getSize()
  local mode = display.layoutFor(w, h)

  local sidebar = 0
  if mode == "standard" then sidebar = 13
  elseif mode == "wide" then sidebar = 16
  elseif mode == "wall" then sidebar = 19
  end

  return {
    w = w,
    h = h,
    mode = mode,
    sidebar = sidebar,
    top = 2,
    bottom = mode == "compact" and 2 or 1,
    contentX = sidebar > 0 and sidebar + 2 or 2,
    contentY = 3,
    contentW = sidebar > 0 and w - sidebar - 2 or w - 2,
    contentH = h - 4
  }
end

function LinkOS:renderChrome(target, l)
  local t = self:theme()
  draw.clear(target, t.bg, t.text)

  draw.fill(target, 1, 1, l.w, 2, colors.black)
  draw.text(target, 2, 1, "LINK OS", t.accent, colors.black)
  draw.text(target, 2, 2, "PC #" .. os.getComputerID(), t.muted, colors.black)

  local status = self.service.online and "MER ONLINE" or "MER OFFLINE"
  local statusColour = self.service.online and t.good or t.danger
  local statusX = math.max(2, l.w - #status - 1)
  draw.text(target, statusX, 1, status, statusColour, colors.black)

  local clock = nowText()
  draw.text(target, math.max(2, l.w - #clock - 1), 2, clock, t.muted, colors.black)

  if l.sidebar > 0 then
    draw.fill(target, 1, 3, l.sidebar, l.h - 3, t.sidebar)

    local y = 4
    for _, app in ipairs(APPS) do
      if y <= l.h - 2 then
        local selected = self.app == app.id
        local bg = selected and t.accent or t.sidebar
        local fg = selected and colors.black or t.text
        draw.text(target, 2, y, " " .. app.title, fg, bg, l.sidebar - 2)
        self:addButton("nav:" .. app.id, 1, y, l.sidebar, 1, function()
          self:openApp(app.id)
        end)
        y = y + 2
      end
    end

    draw.text(target, 2, l.h - 1, config.VERSION, t.muted, t.sidebar, l.sidebar - 2)
  else
    local navY = l.h
    draw.fill(target, 1, navY, l.w, 1, t.panel)

    local compactApps = {
      {"home", "H"},
      {"messages", "M"},
      {"network", "N"},
      {"security", "S"},
      {"settings", "*"}
    }

    local slotW = math.max(3, math.floor(l.w / #compactApps))
    for i, entry in ipairs(compactApps) do
      local x = (i - 1) * slotW + 1
      local w = i == #compactApps and l.w - x + 1 or slotW
      local selected = self.app == entry[1]
      draw.button(target, x, navY, w, entry[2], t.text, selected and t.accent or t.panel)
      self:addButton("nav:" .. entry[1], x, navY, w, 1, function()
        self:openApp(entry[1])
      end)
    end
  end
end

function LinkOS:renderNotice(target, l)
  if not self.notice or self.notice == "" then return end
  local t = self:theme()
  local y = l.h - (l.mode == "compact" and 1 or 1)
  if l.mode == "compact" then y = l.h - 1 end
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

  draw.text(target, x, y, "Bienvenue sur LinkOS", t.text, t.bg, w)
  y = y + 2

  local info = self.service:identity()
  if l.mode == "compact" then
    draw.text(target, x, y, "PC #" .. info.computer_id .. " | " .. tostring(info.label or "-"), t.accent, t.bg, w)
    y = y + 1
    draw.text(target, x, y, self.service.online and "Reseau connecte" or "Reseau hors-ligne",
      self.service.online and t.good or t.danger, t.bg, w)
    y = y + 2

    local apps = {
      {"Messages", "messages", "Conversations privees"},
      {"Reseau", "network", "MER et modem"},
      {"Securite", "security", "Protection et intrusion"},
      {"Fichiers", "files", "Disque local"},
      {"Parametres", "settings", "Affichage et systeme"}
    }

    for _, app in ipairs(apps) do
      if y <= l.h - 3 then
        draw.text(target, x, y, "> " .. app[1], t.accent, t.bg, w)
        self:addButton("home:" .. app[2], x, y, w, 1, function() self:openApp(app[2]) end)
        y = y + 1
        if y <= l.h - 3 then
          draw.text(target, x + 2, y, app[3], t.muted, t.bg, math.max(1, w - 2))
          y = y + 2
        end
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
    {"Messages", self.service.unread > 0 and (self.service.unread .. " nouveau(x)") or "Conversations privees par ID", "messages"},
    {"Reseau", statusText, "network"},
    {"Securite", self.service:isHackOperator() and "Console speciale autorisee" or "Protection active", "security"},
    {"Fichiers", humanBytes(fs.getFreeSpace("/")) .. " libres", "files"},
    {"Parametres", self.active.label .. " / " .. l.mode, "settings"},
    {"A propos", "Computer Link " .. config.VERSION, "about"}
  }

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

  draw.text(target, x, y, "Messages", t.text, t.bg, w)
  self:button(target, "msg:new", math.max(x, x + w - 11), y, math.min(11, w), "+ Nouveau", function()
    local idText = self:prompt("ID du PC destinataire", "Exemple: 27")
    local targetId = tonumber(idText)
    if not targetId then
      self:setNotice("ID invalide.", t.danger)
      return
    end

    local body = self:prompt("Message pour PC #" .. targetId, "Tape ton message puis Entree.")
    if body and body ~= "" then
      local message, err = self.service:sendMessage(targetId, body)
      if not message then
        self:setNotice(tostring(err), t.danger)
      else
        self.selectedPeer = targetId
        self:setNotice("Message envoye au PC #" .. targetId .. ".", t.good)
      end
    end
  end)
  y = y + 2

  local peers = self.service:peers()

  if l.mode == "compact" then
    if self.selectedPeer then
      draw.text(target, x, y, "< " .. self:peerName(self.selectedPeer), t.accent, t.bg, w)
      self:addButton("msg:back", x, y, w, 1, function()
        self.selectedPeer = nil
        self:render()
      end)
      y = y + 1

      local history = self.service:history(self.selectedPeer, math.max(3, h - 5))
      local available = math.max(1, l.h - y - 2)
      local start = math.max(1, #history - available + 1)

      for i = start, #history do
        local m = history[i]
        local mine = tonumber(m.from_id) == os.getComputerID()
        local prefix = mine and "Moi: " or (self:peerName(m.from_id) .. ": ")
        draw.text(target, x, y, prefix .. tostring(m.body), mine and t.accent or t.text, t.bg, w)
        y = y + 1
        if y >= l.h - 1 then break end
      end

      if y < l.h - 1 then
        self:button(target, "msg:reply", x, y, math.min(w, 14), "Repondre", function()
          local body = self:prompt("Message pour " .. self:peerName(self.selectedPeer))
          if body and body ~= "" then
            local _, err = self.service:sendMessage(self.selectedPeer, body)
            self:setNotice(err or "Message envoye.", err and t.danger or t.good)
          end
        end)
      end
      return
    end

    if #peers == 0 then
      draw.text(target, x, y, "Aucune conversation.", t.muted, t.bg, w)
      y = y + 2
      draw.text(target, x, y, "Utilise + Nouveau.", t.muted, t.bg, w)
      return
    end

    for i = 1, math.min(#peers, h - 3) do
      local peer = peers[i]
      local last = peer.last and peer.last.body or ""
      draw.text(target, x, y, self:peerName(peer.id), t.accent, t.bg, w)
      self:addButton("peer:" .. peer.id, x, y, w, 2, function()
        self.selectedPeer = peer.id
        self:render()
      end)
      y = y + 1
      draw.text(target, x + 1, y, last, t.muted, t.bg, math.max(1, w - 1))
      y = y + 1
    end
    return
  end

  local listW = clamp(math.floor(w * 0.34), 16, 28)
  local chatX = x + listW + 1
  local chatW = w - listW - 1

  draw.box(target, x, y, listW, math.max(4, h - 2), t.panel, t.accent, "Conversations")

  if #peers == 0 then
    draw.text(target, x + 1, y + 2, "Aucune conversation", t.muted, t.panel, listW - 2)
  else
    local py = y + 2
    for i = 1, math.min(#peers, h - 5) do
      local peer = peers[i]
      local selected = self.selectedPeer == peer.id
      local bg = selected and t.accent or t.panel
      local fg = selected and colors.black or t.text
      draw.text(target, x + 1, py, self:peerName(peer.id), fg, bg, listW - 2)
      self:addButton("peer:" .. peer.id, x + 1, py, listW - 2, 1, function()
        self.selectedPeer = peer.id
        self:render()
      end)
      py = py + 1
    end
  end

  draw.box(target, chatX, y, chatW, math.max(4, h - 2), colors.black, t.accent,
    self.selectedPeer and self:peerName(self.selectedPeer) or "Selectionne une conversation")

  if self.selectedPeer then
    local history = self.service:history(self.selectedPeer, math.max(10, h - 5))
    local cy = y + 2
    local maxLines = math.max(1, h - 6)
    local start = math.max(1, #history - maxLines + 1)

    for i = start, #history do
      local m = history[i]
      local mine = tonumber(m.from_id) == os.getComputerID()
      local prefix = mine and "Moi > " or ("#" .. tostring(m.from_id) .. " > ")
      draw.text(target, chatX + 1, cy, prefix .. tostring(m.body),
        mine and t.accent or t.text, colors.black, chatW - 2)
      cy = cy + 1
      if cy >= y + h - 3 then break end
    end

    self:button(target, "msg:reply", chatX + 1, y + h - 4, math.min(14, chatW - 2), "Repondre", function()
      local body = self:prompt("Message pour " .. self:peerName(self.selectedPeer))
      if body and body ~= "" then
        local _, err = self.service:sendMessage(self.selectedPeer, body)
        self:setNotice(err or "Message envoye.", err and t.danger or t.good)
      end
    end)

    if chatW >= 28 then
      self:button(target, "msg:alias", chatX + 16, y + h - 4, math.min(12, chatW - 17), "Alias", function()
        local alias = self:prompt("Alias local pour PC #" .. self.selectedPeer,
          "Laisse vide pour supprimer l'alias.")
        prefs.setAlias(self.selectedPeer, alias)
        self:setNotice("Alias enregistre.", t.good)
      end)
    end
  end
end

function LinkOS:renderNetwork(target, l)
  local t = self:theme()
  local x, y, w = l.contentX, l.contentY, l.contentW
  local info = self.service:identity()

  draw.text(target, x, y, "Reseau AstralNet", t.text, t.bg, w)
  y = y + 2

  local lines = {
    "Computer ID : #" .. tostring(info.computer_id),
    "Nom du PC   : " .. tostring(info.label or "-"),
    "MER         : " .. (info.server_id and ("#" .. info.server_id) or "non detecte"),
    "Etat        : " .. (info.online and "connecte" or "hors-ligne"),
    "Modem       : " .. tostring(info.modem or "absent"),
    "Protocole   : " .. config.PROTOCOL,
    "Version     : " .. config.VERSION
  }

  for _, line in ipairs(lines) do
    draw.text(target, x, y, line, t.text, t.bg, w)
    y = y + 1
    if y >= l.h - 3 then break end
  end

  y = y + 1
  if y < l.h - 2 then
    self:button(target, "net:ping", x, y, math.min(12, w), "PING MER", function()
      local result, err = self.service:ping()
      if result then
        self:setNotice("MER repond en ~" .. tostring(result.latency) .. " ms.", t.good)
      else
        self:setNotice(tostring(err), t.danger)
      end
    end)

    if w >= 28 then
      self:button(target, "net:sync", x + 14, y, math.min(12, w - 14), "SYNC", function()
        local count, err = self.service:syncInbox(true)
        if count then
          self:setNotice(tostring(count) .. " message(s) synchronise(s).", t.good)
        else
          self:setNotice(tostring(err), t.danger)
        end
      end)
    end

    if w >= 42 then
      self:button(target, "net:rename", x + 28, y, math.min(13, w - 28), "RENOMMER", function()
        local label = self:prompt("Nouveau nom du PC", "Maximum 32 caracteres.")
        local ok, err = self.service:setLabel(label)
        self:setNotice(ok and "Nom du PC mis a jour." or tostring(err), ok and t.good or t.danger)
      end)
    end
  end
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

function LinkOS:renderSecurity(target, l)
  local t = self:theme()
  local x, y, w, h = l.contentX, l.contentY, l.contentW, l.contentH

  draw.text(target, x, y, "Centre de securite", t.text, t.bg, w)
  y = y + 2

  if not self.service:isHackOperator() then
    self:card(target, x, y, w, math.min(7, h - 2), "Protection active",
      "Ce PC peut utiliser AstralNet normalement. Les outils d'intrusion sont verrouilles par la politique serveur. Operateur autorise : PC #1.")
    return
  end

  draw.text(target, x, y, "MODE OPERATEUR SPECIAL - PC #1", t.danger, t.bg, w)
  y = y + 2

  self:button(target, "sec:scan", x, y, math.min(14, w), "SCAN PROXIMITE", function()
    self:setNotice("Scan radio en cours...", t.warn)
    self:render()
    local found, err = self.service:scan()
    if not found then
      self:setNotice(tostring(err), t.danger)
    else
      self.scanResults = found
      self:setNotice(tostring(#found) .. " PC detecte(s).", t.good)
    end
  end)

  if w >= 31 then
    self:button(target, "sec:sessions", x + 16, y, math.min(14, w - 16), "SESSIONS", function()
      local sessions = self.service:sessions()
      local lines = {}
      for _, s in ipairs(sessions) do
        lines[#lines + 1] = "PC #" .. s.id .. " session active"
      end
      self.remoteView = {
        title = "Sessions pirates",
        lines = #lines > 0 and lines or {"Aucune session active."}
      }
    end)
  end

  y = y + 2

  if self.remoteView then
    draw.box(target, x, y, w, math.max(5, math.min(h - 4, 10)), t.panel, t.accent, self.remoteView.title)
    local lines = self.remoteView.lines or {}
    for i = 1, math.min(#lines, math.max(1, h - 7)) do
      draw.text(target, x + 1, y + i, lines[i], t.text, t.panel, w - 2)
    end
    self:addButton("sec:closeview", x, y, w, math.max(5, math.min(h - 4, 10)), function()
      self.remoteView = nil
      self:render()
    end)
    return
  end

  if #self.scanResults == 0 then
    draw.text(target, x, y, "Aucun resultat. Lance un scan.", t.muted, t.bg, w)
  else
    for i, pc in ipairs(self.scanResults) do
      if y >= l.h - 3 then break end
      local label = "#" .. tostring(pc.id)
        .. "  " .. tostring(math.floor((pc.distance or 0) * 10) / 10) .. " blocs"
        .. "  SEC " .. tostring(pc.security or "?")
        .. "  " .. tostring(pc.label or "-")
      draw.text(target, x, y, label, t.text, t.bg, w)
      local targetId = pc.id
      self:addButton("sec:target:" .. targetId, x, y, w, 1, function()
        local session, err = self.service:hack(targetId)
        if not session then
          self:setNotice("Echec #" .. targetId .. ": " .. tostring(err), t.danger)
        else
          self:setNotice("Acces obtenu au PC #" .. targetId .. ".", t.good)
          self.remoteTarget = targetId
        end
      end)
      y = y + 1
    end
  end

  if self.remoteTarget and y < l.h - 4 then
    y = y + 1
    draw.text(target, x, y, "Session PC #" .. self.remoteTarget, t.accent, t.bg, w)
    y = y + 1

    local actions = {
      {"INFO", "info"},
      {"MESSAGES", "conversations"},
      {"FICHIERS", "ls"},
      {"CRASH", "crash"}
    }

    local bx = x
    for _, action in ipairs(actions) do
      local bw = math.min(11, math.max(7, math.floor(w / #actions) - 1))
      if bx + bw - 1 <= x + w - 1 then
        local actionName = action[2]
        self:button(target, "sec:remote:" .. actionName, bx, y, bw, action[1], function()
          local data, err = self.service:remote(self.remoteTarget, actionName, actionName == "ls" and "/" or nil)
          if not data then
            self:setNotice(tostring(err), t.danger)
          else
            self:showRemoteData(actionName, data)
          end
        end)
        bx = bx + bw + 1
      end
    end
  end
end

function LinkOS:listFiles(path)
  path = fs.combine("/", path or "/")
  if path == "" then path = "/" end

  if not fs.exists(path) or not fs.isDir(path) then
    return {}, "Dossier introuvable."
  end

  local entries = fs.list(path)
  table.sort(entries, function(a, b)
    local pa, pb = fs.combine(path, a), fs.combine(path, b)
    local da, db = fs.isDir(pa), fs.isDir(pb)
    if da ~= db then return da end
    return string.lower(a) < string.lower(b)
  end)

  return entries
end

function LinkOS:renderFiles(target, l)
  local t = self:theme()
  local x, y, w, h = l.contentX, l.contentY, l.contentW, l.contentH

  draw.text(target, x, y, "Fichiers  " .. self.filePath, t.text, t.bg, w)
  y = y + 2

  if self.filePreview then
    draw.text(target, x, y, "< Retour", t.accent, t.bg, w)
    self:addButton("file:back", x, y, w, 1, function()
      self.filePreview = nil
      self:render()
    end)
    y = y + 2

    local lines = draw.wrap(self.filePreview.content or "", math.max(1, w))
    for i = 1, math.min(#lines, h - 4) do
      draw.text(target, x, y + i - 1, lines[i], t.text, t.bg, w)
    end
    return
  end

  if self.filePath ~= "/" then
    draw.text(target, x, y, "[..] Dossier parent", t.accent, t.bg, w)
    self:addButton("file:parent", x, y, w, 1, function()
      self.filePath = "/" .. fs.getDir(string.sub(self.filePath, 2))
      if self.filePath == "/" or self.filePath == "//" then self.filePath = "/" end
      self:render()
    end)
    y = y + 1
  end

  local entries, err = self:listFiles(self.filePath)
  if err then
    draw.text(target, x, y, err, t.danger, t.bg, w)
    return
  end

  for i = 1, math.min(#entries, math.max(1, l.h - y - 2)) do
    local name = entries[i]
    local full = fs.combine(self.filePath, name)
    local isDir = fs.isDir(full)
    local prefix = isDir and "[DIR] " or "      "
    local suffix = isDir and "" or ("  " .. humanBytes(fs.getSize(full)))

    draw.text(target, x, y, prefix .. name .. suffix, isDir and t.accent or t.text, t.bg, w)

    self:addButton("file:" .. full, x, y, w, 1, function()
      if fs.isDir(full) then
        self.filePath = full
      else
        local f = fs.open(full, "r")
        if f then
          local content = f.read(4096) or ""
          f.close()
          self.filePreview = {path=full, content=content}
        else
          self:setNotice("Fichier non lisible.", t.danger)
        end
      end
      self:render()
    end)

    y = y + 1
  end
end

function LinkOS:renderSettings(target, l)
  local t = self:theme()
  local x, y, w = l.contentX, l.contentY, l.contentW

  draw.text(target, x, y, "Parametres LinkOS", t.text, t.bg, w)
  y = y + 2

  draw.text(target, x, y, "Affichage actif : " .. tostring(self.active.label), t.accent, t.bg, w)
  y = y + 1
  draw.text(target, x, y, tostring(self.active.width) .. "x" .. tostring(self.active.height)
    .. " | mode " .. tostring(self.active.layout)
    .. (self.active.scale and (" | scale " .. self.active.scale) or ""), t.muted, t.bg, w)
  y = y + 2

  for _, d in ipairs(self.displays) do
    if y >= l.h - 6 then break end
    local selected = d.id == self.active.id
    local label = (selected and "* " or "  ") .. d.label
      .. "  " .. d.width .. "x" .. d.height
      .. "  " .. d.layout
    draw.text(target, x, y, label, selected and t.good or t.text, t.bg, w)
    local displayId = d.id
    self:addButton("display:" .. displayId, x, y, w, 1, function()
      prefs.set("display_id", displayId)
      self:refreshDisplays()
      self:setNotice("Affichage principal change.", t.good)
      self:render()
    end)
    y = y + 1
  end

  y = y + 1
  if y < l.h - 4 then
    draw.text(target, x, y, "Couleur d'accent", t.text, t.bg, w)
    y = y + 1

    local accentNames = {"cyan", "blue", "lime", "orange", "purple", "red"}
    local bx = x
    for _, name in ipairs(accentNames) do
      local bw = math.min(8, math.max(5, math.floor(w / #accentNames)))
      if bx + bw - 1 <= x + w - 1 then
        draw.button(target, bx, y, bw, string.sub(name, 1, 3), colors.white, ACCENTS[name])
        local accentName = name
        self:addButton("accent:" .. name, bx, y, bw, 1, function()
          prefs.set("accent", accentName)
          self:render()
        end)
        bx = bx + bw
      end
    end
    y = y + 2
  end

  if y < l.h - 2 then
    local buttons = {
      {"UPDATE", function()
        shell.run("/computer-link/update.lua")
        self:setNotice("Mise a jour terminee. Reboot conseille.", t.good)
      end},
      {"CLI", function()
        self.exitToCli = true
        self.running = false
      end},
      {"DESINSTALLER", function()
        if self:confirm("Desinstaller Computer Link ?") then
          shell.run("/computer-link/uninstall.lua", "yes")
          sleep(1)
          os.reboot()
        end
      end}
    }

    local bx = x
    for _, item in ipairs(buttons) do
      local bw = math.min(14, math.max(7, math.floor(w / #buttons) - 1))
      if bx + bw - 1 <= x + w - 1 then
        self:button(target, "set:" .. item[1], bx, y, bw, item[1], item[2])
        bx = bx + bw + 1
      end
    end
  end
end

function LinkOS:renderAbout(target, l)
  local t = self:theme()
  local x, y, w = l.contentX, l.contentY, l.contentW

  draw.text(target, x, y, "Computer Link / LinkOS", t.accent, t.bg, w)
  y = y + 2

  local text = {
    "Version " .. config.VERSION,
    "",
    "Un OS reseau construit pour Astralium.",
    "Identite native par Computer ID.",
    "Messagerie privee, MER, fichiers, securite, moniteurs et interface adaptative.",
    "",
    "Raccourcis :",
    "F1 Accueil   F2 Messages   F3 Reseau",
    "F4 Securite  F5 Fichiers   F6 Parametres",
    "ESC Accueil"
  }

  for _, line in ipairs(text) do
    if y >= l.h - 2 then break end
    draw.text(target, x, y, line, line == "" and t.muted or t.text, t.bg, w)
    y = y + 1
  end
end

function LinkOS:render()
  if not self.active then return end

  local target = self.active.target
  local l = self:layout()
  if not l then return end

  self.buttons = {}
  self.active.width, self.active.height = target.getSize()
  self.active.layout = display.layoutFor(self.active.width, self.active.height)

  self:renderChrome(target, l)

  if self.app == "messages" then
    self:renderMessages(target, l)
  elseif self.app == "network" then
    self:renderNetwork(target, l)
  elseif self.app == "security" then
    self:renderSecurity(target, l)
  elseif self.app == "files" then
    self:renderFiles(target, l)
  elseif self.app == "settings" then
    self:renderSettings(target, l)
  elseif self.app == "about" then
    self:renderAbout(target, l)
  else
    self:renderHome(target, l)
  end

  self:renderNotice(target, l)

  if target.setCursorBlink then
    pcall(target.setCursorBlink, false)
  end
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
  if key == keys.f1 then self:openApp("home")
  elseif key == keys.f2 then self:openApp("messages")
  elseif key == keys.f3 then self:openApp("network")
  elseif key == keys.f4 then self:openApp("security")
  elseif key == keys.f5 then self:openApp("files")
  elseif key == keys.f6 then self:openApp("settings")
  elseif key == keys.escape then self:openApp("home")
  elseif key == keys.r then
    self:render()
  end
end

function LinkOS:uiLoop()
  self:render()

  while self.running do
    local event, a, b, c, d, e = os.pullEvent()

    if event == "mouse_click" and self.active and self.active.kind == "computer" then
      self:hit(b, c)
      self:render()

    elseif event == "monitor_touch" and self.active
      and self.active.kind == "monitor"
      and a == self.active.name then
      self:hit(b, c)
      self:render()

    elseif event == "key" then
      self:handleKey(a)
      self:render()

    elseif event == "linkos_refresh" then
      self:render()

    elseif event == "linkos_display_changed"
      or event == "monitor_resize"
      or event == "term_resize"
      or event == "peripheral"
      or event == "peripheral_detach" then
      self:refreshDisplays()
      self:render()

    elseif event == "terminate" then
      self.running = false
    end
  end
end

function LinkOS:daemonLoop()
  while self.running do
    local event, a, b, c, d, e = os.pullEvent()
    self.service:handleEvent(event, a, b, c, d, e)
  end
end

function LinkOS:run()
  self:refreshDisplays()

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

  if self.exitToCli and fs.exists("/computer-link/src/client/cli.lua") then
    term.redirect(self.native)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()
    term.setCursorPos(1, 1)
    shell.run("/computer-link/src/client/cli.lua")
  end
end

local instance = LinkOS.new()
instance:run()
