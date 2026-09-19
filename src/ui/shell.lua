local draw = dofile("/computer-link/src/ui/draw.lua")
local fluent = dofile("/computer-link/src/ui/fluent.lua")
local ccui = dofile("/computer-link/src/ui/ccui.lua")

local shellui = {}

local APPS = {
  {id="home", title="Bureau", short="HOME", icon="L", pinned=true},
  {id="messages", title="Messages", short="MSG", icon="M", pinned=true},
  {id="contacts", title="Contacts", short="CONT", icon="C", pinned=false},
  {id="network", title="Reseau", short="NET", icon="N", pinned=true},
  {id="security", title="Securite", short="SEC", icon="S", pinned=true},
  {id="files", title="Fichiers", short="FILES", icon="F", pinned=true},
  {id="notes", title="Notes", short="NOTE", icon="T", pinned=false},
  {id="calculator", title="Calculatrice", short="CALC", icon="=", pinned=false},
  {id="terminal", title="Terminal", short="TERM", icon=">", pinned=false},
  {id="settings", title="Parametres", short="SET", icon="*", pinned=false},
  {id="about", title="A propos", short="INFO", icon="i", pinned=false},
  {id="hacker", title="LinkSec", short="LSEC", icon="!", pinned=true, operator=true}
}

local function clone(value)
  local out = {}
  for k, v in pairs(value) do out[k] = v end
  return out
end

function shellui.apps(operator)
  local out = {}
  for _, app in ipairs(APPS) do
    if not app.operator or operator then
      local item = clone(app)
      item.icon = fluent.glyph(item.id)
      item.iconColour = fluent.iconColour(item.id)
      out[#out + 1] = item
    end
  end
  return out
end

function shellui.find(id, operator)
  for _, app in ipairs(shellui.apps(operator)) do
    if app.id == id then return app end
  end
  return nil
end

function shellui.allowed(id, operator)
  return shellui.find(id, operator) ~= nil
end

function shellui.pinned(operator)
  local out = {}
  for _, app in ipairs(shellui.apps(operator)) do
    if app.pinned then out[#out + 1] = app end
  end
  return out
end

function shellui.nextApp(current, operator, delta)
  local apps = shellui.apps(operator)
  if #apps == 0 then return "home" end

  local index = 1
  for i, app in ipairs(apps) do
    if app.id == current then
      index = i
      break
    end
  end

  delta = tonumber(delta) or 1
  index = ((index - 1 + delta) % #apps) + 1
  return apps[index].id
end

function shellui.wallpaper(target, x, y, w, h, mode, accent)
  mode = tostring(mode or "fluent")
  draw.fill(target, x, y, w, h, colors.black)
  if w <= 0 or h <= 0 or mode == "clean" then return end

  if mode == "fluent" then
    -- LinkOS four-pane mark: intentionally simple and readable at ComputerCraft
    -- resolutions while evoking a modern desktop wallpaper.
    if w>=30 and h>=10 then
      local paneW=math.max(3,math.floor(w*0.11))
      local paneH=math.max(2,math.floor(h*0.18))
      local gapX=1
      local gapY=1
      local logoW=paneW*2+gapX
      local logoH=paneH*2+gapY
      local lx=math.min(x+w-logoW-3,x+math.floor(w*0.66))
      local ly=math.max(y+1,y+math.floor((h-logoH)*0.38))

      -- Quiet shadow/backplate for depth.
      draw.fill(target,lx-2,ly-1,logoW+4,logoH+2,colors.gray)
      draw.fill(target,lx,ly,paneW,paneH,colors.lightBlue)
      draw.fill(target,lx+paneW+gapX,ly,paneW,paneH,colors.blue)
      draw.fill(target,lx,ly+paneH+gapY,paneW,paneH,colors.blue)
      draw.fill(target,lx+paneW+gapX,ly+paneH+gapY,paneW,paneH,accent or colors.lightBlue)

      -- A few low-contrast horizontal rays keep the desktop from feeling flat.
      local rayX=math.max(x,lx-math.floor(w*0.12))
      local rayY=math.min(y+h-1,ly+logoH+2)
      for i=0,2 do
        local rw=math.max(3,logoW-i*3)
        if rayY+i<=y+h-1 then
          draw.fill(target,rayX+i*2,rayY+i,rw,1,i==1 and colors.blue or colors.gray)
        end
      end
    end
    return
  end

  if mode == "lines" then
    for py = y + 1, y + h - 1, 4 do
      draw.hline(target, x, py, w, "-", colors.gray, colors.black)
    end
    return
  end

  local stepX = mode == "grid" and 10 or 14
  local stepY = mode == "grid" and 4 or 5
  for py = y + 1, y + h - 1, stepY do
    local offset = ((py - y) % (stepY * 2) == 0) and 2 or math.floor(stepX / 2)
    for px = x + offset, x + w - 1, stepX do
      draw.text(target, px, py, mode == "grid" and "." or "'", accent or colors.cyan, colors.black, 1)
    end
  end
end

function shellui.startMenuRect(layout)
  local w = math.min(math.max(30, math.floor(layout.w * 0.72)), math.max(22, layout.w - 6))
  local h = math.min(math.max(12, math.floor(layout.h * 0.78)), math.max(9, layout.h - 3))
  local x = math.max(1, math.floor((layout.w - w) / 2) + 1)
  return x, math.max(1, layout.h - h), w, h
end

function shellui.quickPanelRect(layout)
  local w = math.min(math.max(25, math.floor(layout.w * 0.48)), math.max(20, layout.w - 3))
  local h = math.min(15, math.max(9, layout.h - 3))
  return math.max(1, layout.w - w), math.max(1, layout.h - h), w, h
end

-- Responsive shell v0.13. Kept separate from the network/application backend.
function shellui.page(items, width, height, requested, tileHeight)
  local cols = math.max(1, math.min(4, math.floor((width + 1) / 16)))
  local rows = math.max(1, math.floor(height / (tileHeight + 1)))
  local capacity = cols * rows
  local pages = math.max(1, math.ceil(#items / capacity))
  local page = math.max(1, math.min(pages, requested or 1))
  return {cols=cols, capacity=capacity, pages=pages, page=page,
    first=(page-1)*capacity+1, cellW=math.floor((width-cols+1)/cols)}
end

function shellui.install(OS, prefs)
  local oldKey, oldHit = OS.handleKey, OS.hit
  local oldOverlays = OS.renderShellOverlays
  local oldChrome = OS.renderChrome
  local descriptions = {messages="Conversations privees", contacts="Votre carnet d'adresses",
    network="Connexion AstralNet", files="Documents personnels", security="Protection du poste",
    notes="Ecrire et sauvegarder", calculator="Calculs rapides", terminal="Console CraftOS",
    settings="Personnaliser LinkOS", about="Version et raccourcis", hacker="Acces operateur"}
  local badges = {messages=colors.cyan, contacts=colors.blue, network=colors.lime,
    files=colors.orange, security=colors.purple, notes=colors.yellow,
    calculator=colors.green, terminal=colors.gray, settings=colors.lightBlue,
    about=colors.blue, hacker=colors.red}

  function OS:renderChrome(target, l)
    oldChrome(self, target, l)
    -- Replace the crowded second row with a clean breadcrumb and clock.
    local t = self:theme()
    draw.fill(target, 1, 2, l.w, 1, colors.black)
    local app = shellui.find(self.app, self:isOperatorUI())
    draw.text(target, 2, 2, "Astralium / " .. (app and app.title or "Bureau"), t.muted, colors.black, math.max(1,l.w-10))
    draw.text(target, math.max(1,l.w-5), 2, textutils.formatTime(os.time(),true), t.accent, colors.black, 5)
    for i=#self.buttons,1,-1 do
      if self.buttons[i].id == "quick:update" then table.remove(self.buttons,i) end
    end
  end

  function OS:renderHome(target, l)
    local t = self:theme()
    local bottom = math.max(3, l.h - 1)
    shellui.wallpaper(target, 1, 1, l.w, bottom, prefs.get("wallpaper","fluent"), t.accent)

    draw.text(target, 2, 2, "LINKOS", t.accent, colors.black, math.max(1,l.w-3))
    draw.text(target, 2, 3,
      self.service.online and "AstralNet connecte" or "Mode hors-ligne",
      self.service.online and t.good or t.warn, colors.black, math.max(1,l.w-3))

    local apps = {}
    for _, app in ipairs(shellui.apps(self:isOperatorUI())) do
      if app.id ~= "home" then apps[#apps+1] = app end
    end

    local p = shellui.page(apps, math.max(1,l.w-3), math.max(1,l.h-6), self.desktopPage, 2)
    self.desktopPage, self.desktopPages = p.page, p.pages
    local x, y = 2, 5

    for index=p.first,math.min(#apps,p.first+p.capacity-1) do
      local app=apps[index]
      local n=index-p.first
      local bx=x+(n%p.cols)*(p.cellW+1)
      local by=y+math.floor(n/p.cols)*3
      if by+1 < bottom then
        local badge=badges[app.id] or t.accent
        draw.fill(target,bx,by,p.cellW,2,colors.black)
        draw.fill(target,bx,by,2,2,badge)
        draw.text(target,bx,by,app.icon or "+",colors.white,badge,2)
        draw.text(target,bx+3,by,app.title,t.text,colors.black,math.max(1,p.cellW-3))
        draw.text(target,bx+3,by+1,descriptions[app.id] or "",t.muted,colors.black,math.max(1,p.cellW-3))
        self:addButton("desktop:"..app.id,bx,by,p.cellW,2,function() self:openApp(app.id) end)
      end
    end
  end

  function OS:renderStartMenu(target,l)
    if not self.startMenuOpen then return end
    local t=self:theme()
    local panelW=math.min(math.max(30,math.floor(l.w*0.72)),l.w-3)
    local x=2
    local y=2
    local h=math.max(10,l.h-3)
    self.shellOverlay={x=x,y=y,w=panelW,h=h}
    self.buttons={}

    draw.fill(target,x,y,panelW,h,t.elevated)
    draw.text(target,x+2,y,"Demarrer",t.text,t.elevated,panelW-4)

    local query=self.launcherQuery or ""
    fluent.searchBox(target,x+2,y+2,panelW-4,query,"Rechercher une application",t.accent)
    self:addButton("launcher:search",x+2,y+2,panelW-4,1,function() end)

    local mode=self.startAllApps and "all" or "pinned"
    local tabRects=ccui.tabs(target,x+2,y+4,panelW-4,{
      {id="pinned",label="Epinglees"},
      {id="all",label="Toutes"}
    },mode,t)
    for _,r in ipairs(tabRects) do
      self:addButton("launcher:"..r.id,r.x,r.y,r.w,r.h,function()
        self.startAllApps=(r.id=="all")
        self.launcherIndex=1
      end)
    end

    local available=shellui.apps(self:isOperatorUI())
    local map={}
    for _,app in ipairs(available) do if app.id~="home" then map[app.id]=app end end

    local apps={}
    local q=query:lower()
    if q~="" then
      for _,app in ipairs(available) do
        if app.id~="home" and
          (app.title:lower():find(q,1,true) or app.id:lower():find(q,1,true)) then
          apps[#apps+1]=app
        end
      end
      table.sort(apps,function(a,b) return a.title:lower()<b.title:lower() end)
    elseif self.startAllApps then
      for _,app in ipairs(available) do if app.id~="home" then apps[#apps+1]=app end end
      table.sort(apps,function(a,b) return a.title:lower()<b.title:lower() end)
    else
      local seen={}
      local preferred={}
      for _,id in ipairs(prefs.get("taskbar_pins",{})) do preferred[#preferred+1]=id end
      for _,id in ipairs(prefs.get("desktop_shortcuts",{})) do preferred[#preferred+1]=id end
      for _,id in ipairs({"settings","calculator","store"}) do preferred[#preferred+1]=id end
      for _,id in ipairs(preferred) do
        if map[id] and not seen[id] and #apps<6 then
          apps[#apps+1]=map[id]
          seen[id]=true
        end
      end
    end

    self.launcherApps=apps
    self.launcherIndex=math.max(1,math.min(math.max(1,#apps),self.launcherIndex or 1))

    local listY=y+7
    local footer=y+h-2
    local pageSize=math.max(1,math.floor((footer-listY)/2))
    local page=math.floor((self.launcherIndex-1)/pageSize)
    local first=page*pageSize+1
    local last=math.min(#apps,first+pageSize-1)

    for i=first,last do
      local app=apps[i]
      local row=i-first
      local by=listY+row*2
      local selected=i==self.launcherIndex
      local bg=selected and t.selection or t.elevated
      draw.fill(target,x+2,by,panelW-4,2,bg)
      fluent.drawMiniIcon(target,app.id,x+3,by,selected,bg)
      draw.text(target,x+7,by,app.title,selected and t.text or t.muted,bg,panelW-12)
      draw.text(target,x+7,by+1,selected and "Ouvrir" or "",t.accent,bg,panelW-12)
      self:addButton("launcher:"..app.id,x+2,by,panelW-4,2,function() self:openApp(app.id) end)
    end

    if #apps==0 then
      draw.text(target,x+3,listY+1,"Aucune application trouvee",t.muted,t.elevated,panelW-6)
    end

    local pages=math.max(1,math.ceil(#apps/pageSize))
    if pages>1 then
      local pageText=tostring(page+1).."/"..tostring(pages)
      draw.text(target,x+panelW-#pageText-2,footer-1,pageText,t.muted,t.elevated,#pageText)
      if page>0 then
        ccui.button(target,x+2,footer-1,5,"<",t,{compact=true})
        self:addButton("launcher:prev",x+2,footer-1,5,1,function()
          self.launcherIndex=math.max(1,(page-1)*pageSize+1)
        end)
      end
      if page<pages-1 then
        ccui.button(target,x+8,footer-1,5,">",t,{compact=true})
        self:addButton("launcher:next",x+8,footer-1,5,1,function()
          self.launcherIndex=math.min(#apps,(page+1)*pageSize+1)
        end)
      end
    end

    draw.fill(target,x,footer,panelW,2,t.surface)
    local label=(os.getComputerLabel and os.getComputerLabel()) or ("PC #"..tostring(os.getComputerID and os.getComputerID() or "?"))
    draw.text(target,x+2,footer,"@",t.accent,t.surface,1)
    draw.text(target,x+4,footer,label,t.text,t.surface,math.max(1,panelW-23))

    ccui.button(target,x+panelW-19,footer,10,"REGLAGES",t,{compact=true})
    self:addButton("launcher:settings",x+panelW-19,footer,10,1,function() self:openApp("settings") end)
    ccui.button(target,x+panelW-8,footer,7,"POWER",t,{danger=true})
    self:addButton("launcher:power",x+panelW-8,footer,7,1,function()
      if self:confirm("Redemarrer ce PC ?") then os.reboot() end
    end)
  end
  function OS:renderQuickPanel(target,l)
    if not self.quickPanelOpen then return end
    local t=self:theme()
    local x,y,w,h=shellui.quickPanelRect(l)
    self.shellOverlay={x=x,y=y,w=w,h=h}
    self.buttons={}

    draw.fill(target,x,y,w,h,t.elevated)
    draw.fill(target,x,y,w,1,t.surface)
    draw.text(target,x+2,y,"Systeme",t.text,t.surface,w-4)

    local row=y+2
    local function line(label,value,colour)
      draw.text(target,x+2,row,label,t.muted,t.elevated,math.max(1,w-14))
      local v=tostring(value)
      draw.text(target,math.max(x+12,x+w-#v-2),row,v,colour or t.text,t.elevated,#v)
      row=row+2
    end

    line("AstralNet",self.service.online and "Connecte" or "Hors-ligne",
      self.service.online and t.good or t.danger)
    line("Messages",tostring(self.service.unread or 0),
      (self.service.unread or 0)>0 and t.warn or t.text)
    line("Ecran",self.active and self.active.label or "-",t.text)

    local footer=y+h-2
    draw.fill(target,x,footer,w,2,t.surface)
    self:button(target,"quick:settings",x+2,footer,9,"REGLAGES",function() self:openApp("settings") end)
    if self.securityEnabled and self:securityEnabled() and w>=28 then
      self:button(target,"quick:lock",x+12,footer,7,"LOCK",function()
        self.quickPanelOpen=false
        self:lockSession()
      end)
    end
    self:button(target,"quick:desktop",x+w-9,footer,7,"BUREAU",function() self:openApp("home") end)
  end

  function OS:renderShellOverlays(target,l)
    self.shellOverlay=nil
    if self.startMenuOpen then
      self:renderStartMenu(target,l)
    elseif self.quickPanelOpen then
      self:renderQuickPanel(target,l)
    else
      oldOverlays(self,target,l)
    end
  end

  function OS:hit(x,y)
    local r=self.shellOverlay
    if r and (x<r.x or x>=r.x+r.w or y<r.y or y>=r.y+r.h) then
      self.startMenuOpen,self.quickPanelOpen=false,false
      return true
    end
    return oldHit(self,x,y)
  end

  function OS:handleKey(key)
    if self.startMenuOpen then
      local apps=self.launcherApps or {}
      local cols=math.max(1,self.launcherCols or 1)
      local index=self.launcherIndex or 1
      if key==keys.right or key==keys.tab then
        self.launcherIndex=math.min(#apps,index+1)
      elseif key==keys.left then
        self.launcherIndex=math.max(1,index-1)
      elseif key==keys.down then
        self.launcherIndex=math.min(#apps,index+cols)
      elseif key==keys.up then
        self.launcherIndex=math.max(1,index-cols)
      elseif key==keys.home then
        self.launcherIndex=1
      elseif key==keys["end"] then
        self.launcherIndex=math.max(1,#apps)
      elseif key==keys.backspace then
        self.launcherQuery=(self.launcherQuery or ""):sub(1,-2)
        self.launcherIndex=1
      elseif key==keys.enter then
        local app=apps[self.launcherIndex or 1]
        if app then self:openApp(app.id) end
      elseif key==keys.escape or key==keys.f10 then
        self.startMenuOpen=false
      end
      return
    end
    if self.app=="home" and (key==keys.left or key==keys.right) then
      self.desktopPage=math.max(1,math.min(self.desktopPages or 1,
        (self.desktopPage or 1)+(key==keys.right and 1 or -1)))
      return
    end
    return oldKey(self,key)
  end
end

return shellui
