-- LinkOS workspace: one retained window per application, no replacement of MER.
local draw=dofile('/computer-link/src/ui/draw.lua')
local fluent=dofile('/computer-link/src/ui/fluent.lua')
local packages=dofile('/computer-link/src/ui/packages.lua')
local M={}
local function clamp(n,lo,hi) return math.max(lo,math.min(hi,n)) end
local function inside(x,y,r) return x>=r.x and y>=r.y and x<r.x+r.w and y<r.y+r.h end

function M.install(OS,shellui,prefs)
  local originalApps=shellui.apps
  function shellui.apps(operator)
    local apps=originalApps(operator)
    apps[#apps+1]={id='store',title='Applications',icon='+',short='STORE'}
    local packageIcons={
      tasks='T',stopwatch='C',units='=',devices='D',
      calendar='J',system='I',redstone='R',gps='G'
    }
    for _,p in ipairs(packages.catalog) do
      if packages.installed(p.id) then
        apps[#apps+1]={
          id='pkg:'..p.id,title=p.title,
          icon=packageIcons[p.id] or '+',
          short=string.upper(string.sub(p.id,1,5))
        }
      end
    end
    return apps
  end
  local originalKey=OS.handleKey
  local renderers={messages='renderMessages',contacts='renderContacts',network='renderNetwork',
    files='renderFiles',security='renderSecurity',settings='renderSettings',about='renderAbout',
    notes='renderNotes',calculator='renderCalculator',terminal='renderTerminal',hacker='renderHacker',store='renderStore'}

  function OS:workspace()
    if not self.windows then self.windows={}; self.app='home'; self.selectedIcon=1 end
    return self.windows
  end

  function OS:recordRecentApp(id)
    if not id or id=='home' then return end
    local recent=prefs.get('recent_apps',{})
    local nextRecent={id}
    for _,value in ipairs(recent) do
      if value~=id and #nextRecent<6 then nextRecent[#nextRecent+1]=value end
    end
    prefs.set('recent_apps',nextRecent)
  end

  function OS:taskbarPins()
    local out,seen={},{}
    for _,id in ipairs(prefs.get('taskbar_pins',{})) do
      local app=shellui.find(id,self:isOperatorUI())
      if app and id~='home' and not seen[id] then
        out[#out+1]=app
        seen[id]=true
      end
    end
    return out
  end
  function OS:persistWindowGeometry(win)
    if not win then return end
    local geometry=prefs.get('window_geometry',{})
    geometry[win.id]={x=win.x,y=win.y,w=win.w,h=win.h}
    prefs.set('window_geometry',geometry)
  end

  function OS:saveWorkspaceSession()
    if self.restoringSession then return end
    local windows={}
    for _,win in ipairs(self:workspace()) do
      windows[#windows+1]={
        id=win.id,
        minimized=win.minimized==true,
        maximized=win.maximized==true,
        scroll=tonumber(win.scroll) or 0
      }
    end
    prefs.set('workspace_session',{
      windows=windows,
      active=self.app or 'home'
    })
  end

  function OS:createWindow(id)
    local list=self:workspace()
    if not shellui.allowed(id,self:isOperatorUI()) then return nil end

    for _,win in ipairs(list) do
      if win.id==id then return win end
    end
    if not self.active or not self.active.target then return nil end

    local w,h=self.active.target.getSize()
    local offset=#list%4
    local defaultW=math.min(w-2,math.max(24,math.floor(w*0.82)))
    local defaultH=math.min(h-2,math.max(8,math.floor((h-1)*0.78)))
    local preferred={
      messages={45,17},files={45,17},settings={45,17},
      calculator={36,17},store={48,18},terminal={38,14},
      notes={45,17},network={40,15},security={40,15}
    }
    local pref=preferred[id]
    if pref then
      defaultW=math.min(w,math.max(24,pref[1]))
      defaultH=math.min(h-1,math.max(8,pref[2]))
    end

    local autoMaximize = w < 70 or h < 22
    local win={
      id=id,x=2+offset*2,y=1+offset,w=defaultW,h=defaultH,
      data={},scroll=0,minimized=false,maximized=autoMaximize
    }

    local saved=prefs.get('window_geometry',{})[id]
    if type(saved)=='table' and type(saved.x)=='number' and type(saved.y)=='number'
      and type(saved.w)=='number' and type(saved.h)=='number' then
      win.x,win.y,win.w,win.h=saved.x,saved.y,saved.w,saved.h
    end

    if id:sub(1,4)=='pkg:' then
      local packageId=id:sub(5)
      if not packages.installed(packageId) then return nil end
      local ok,app=pcall(dofile,packages.path(packageId))
      if not ok or type(app)~='table' or type(app.draw)~='function' then
        self:setNotice('Application invalide: '..tostring(app),colors.red)
        return nil
      end
      win.program=app
    end

    list[#list+1]=win
    return win
  end

  function OS:focusWindow(win,quiet)
    local list=self:workspace()
    for i,v in ipairs(list) do
      if v==win then table.remove(list,i);break end
    end
    list[#list+1]=win
    win.minimized=false
    self.app=win.id
    self.showDesktopSnapshot=nil
    if not quiet then self:saveWorkspaceSession() end
  end

  function OS:restoreWorkspaceSession()
    if self.sessionRestored then return end
    self.sessionRestored=true
    if not prefs.get('restore_session',true) then return end

    local session=prefs.get('workspace_session',{})
    if type(session)~='table' or type(session.windows)~='table' then return end

    self.restoringSession=true
    for _,saved in ipairs(session.windows) do
      if type(saved)=='table' and type(saved.id)=='string'
        and shellui.allowed(saved.id,self:isOperatorUI()) then
        local win=self:createWindow(saved.id)
        if win then
          win.minimized=saved.minimized==true
          win.maximized=saved.maximized==true
          win.scroll=math.max(0,tonumber(saved.scroll) or 0)
        end
      end
    end

    self.app='home'
    local requested=tostring(session.active or 'home')
    for _,win in ipairs(self:workspace()) do
      if win.id==requested and not win.minimized then
        self.app=win.id
      end
    end
    if self.app=='home' then
      for _,win in ipairs(self:workspace()) do
        if not win.minimized then self.app=win.id end
      end
    end
    self.restoringSession=false
  end

  function OS:cycleWindow(delta)
    local list=self:workspace()
    if #list==0 then return false end
    delta=tonumber(delta) or 1

    local current=0
    for i,win in ipairs(list) do
      if win.id==self.app then current=i;break end
    end
    local index=((current-1+delta)%#list)+1
    self:focusWindow(list[index])
    self.taskSwitcherOpen=self.altHeld==true
    return true
  end

  function OS:renderTaskSwitcher(target,w,h)
    if not self.taskSwitcherOpen then return end
    local list=self:workspace()
    if #list==0 then return end

    local t=self:theme()
    -- CC:Tweaked cannot blur the scene behind Alt+Tab, so use a clean
    -- darkened desktop surface. This is far easier to read than stacking the
    -- switcher on top of every open window.
    draw.fill(target,1,1,w,math.max(1,h-1),t.desktop)

    local visible=math.min(5,#list)
    local cardW=w>=48 and 12 or 10
    local mw=math.min(w-4,visible*(cardW+1)+3)
    local mh=8
    local x=math.max(1,math.floor((w-mw)/2)+1)
    local y=math.max(1,math.floor((h-mh)/2))

    draw.fill(target,x,y,mw,mh,t.elevated)
    draw.fill(target,x,y,mw,1,t.surface)
    draw.text(target,x+2,y,"ALT + TAB",t.accent,t.surface,9)
    draw.text(target,x+13,y,"Changer de fenetre",t.text,t.surface,math.max(1,mw-15))

    local first=math.max(1,#list-visible+1)
    local col=0
    for i=first,#list do
      local win=list[i]
      local app=shellui.find(win.id,self:isOperatorUI())
      local active=win.id==self.app and not win.minimized
      local bx=x+2+col*(cardW+1)
      local bg=active and t.selection or t.surface2
      draw.fill(target,bx,y+2,cardW,5,bg)
      fluent.drawIcon(target,win.id,bx+1,y+3,false,bg)
      draw.text(target,bx+5,y+2,app and app.title or win.id,
        active and t.text or t.muted,bg,math.max(1,cardW-6))
      draw.text(target,bx+5,y+3,
        win.minimized and "Minimise" or (active and "Active" or "Ouverte"),
        win.minimized and t.muted or (active and t.accent or t.muted),
        bg,math.max(1,cardW-6))
      if active then
        draw.fill(target,bx,y+6,cardW,1,t.accent)
      end
      col=col+1
    end
  end

  function OS:toggleShowDesktop()
    local list=self:workspace()
    if #list==0 then self.app='home';return end

    if self.showDesktopSnapshot then
      local snapshot=self.showDesktopSnapshot
      self.showDesktopSnapshot=nil
      for _,win in ipairs(list) do
        local state=snapshot.states[win.id]
        win.minimized=state==nil and win.minimized or state
      end
      self.app='home'
      if snapshot.active and snapshot.active~='home' then
        for _,win in ipairs(list) do
          if win.id==snapshot.active and not win.minimized then
            self.app=win.id
            break
          end
        end
      end
    else
      local states={}
      for _,win in ipairs(list) do
        states[win.id]=win.minimized==true
        win.minimized=true
      end
      self.showDesktopSnapshot={states=states,active=self.app}
      self.app='home'
    end
    self:saveWorkspaceSession()
  end

  function OS:openApp(id)
    local list=self:workspace()
    self.startMenuOpen,self.quickPanelOpen=false,false
    self.contextMenu=nil

    if id=='home' then
      self:toggleShowDesktop()
      self:render()
      return
    end
    if not shellui.allowed(id,self:isOperatorUI()) then return end

    if id=='store' and not self.storeCatalogTried then
      self.storeCatalogTried=true
      pcall(packages.refreshCatalog)
    end

    self:recordRecentApp(id)
    for _,win in ipairs(list) do
      if win.id==id then
        self:focusWindow(win)
        self:render()
        return
      end
    end

    local win=self:createWindow(id)
    if not win then
      self:render()
      return
    end
    self:focusWindow(win,true)
    if id=='messages' then self.service:markRead() end
    self:saveWorkspaceSession()
    self:render()
  end

  function OS:closeWindow(win)
    if win.id=='notes' and self.noteDocument and self.noteDocument.dirty then
      local answer=self:prompt('Document modifie','OUI: sauver / NON: abandonner / Echap: annuler'):lower()
      if answer=='oui' then
        self:saveNote()
        if self.noteDocument.dirty then return end
      elseif answer~='non' then
        return
      end
    end

    if win.id=='notes' then self.noteDocument=nil end
    for i,v in ipairs(self:workspace()) do
      if v==win then table.remove(self.windows,i);break end
    end

    self.showDesktopSnapshot=nil
    self.app='home'
    for _,v in ipairs(self.windows) do
      if not v.minimized then self.app=v.id end
    end
    self:saveWorkspaceSession()
  end
  function OS:desktopApps()
    local items,seen={},{}
    local available=shellui.apps(self:isOperatorUI())
    local map={}
    for _,app in ipairs(available) do if app.id~='home' then map[app.id]=app end end

    local shortcuts={}
    for _,id in ipairs(prefs.get('desktop_shortcuts',{})) do
      if map[id] then shortcuts[id]=true end
    end

    for _,id in ipairs(prefs.get('desktop_order',{})) do
      if shortcuts[id] and map[id] and not seen[id] then
        items[#items+1]=map[id]
        seen[id]=true
      end
    end

    for _,id in ipairs(prefs.get('desktop_shortcuts',{})) do
      if map[id] and not seen[id] then
        items[#items+1]=map[id]
        seen[id]=true
      end
    end
    return items
  end

  function OS:isDesktopShortcut(id)
    for _,value in ipairs(prefs.get('desktop_shortcuts',{})) do
      if value==id then return true end
    end
    return false
  end

  function OS:toggleDesktopShortcut(id)
    if not shellui.allowed(id,self:isOperatorUI()) or id=='home' then return false end
    local current=prefs.get('desktop_shortcuts',{})
    local nextShortcuts={}
    local found=false
    for _,value in ipairs(current) do
      if value==id then found=true else nextShortcuts[#nextShortcuts+1]=value end
    end
    if not found and #nextShortcuts<20 then nextShortcuts[#nextShortcuts+1]=id end
    prefs.set('desktop_shortcuts',nextShortcuts)
    self:setNotice(found and 'Raccourci retire du bureau.' or 'Raccourci ajoute au bureau.',
      self:theme().good)
    return true
  end
  function OS:moveIcon(from,to)
    local apps=self:desktopApps()
    from,to=clamp(from,1,#apps),clamp(to,1,#apps)
    local item=table.remove(apps,from);table.insert(apps,to,item)
    local order={};for _,app in ipairs(apps) do order[#order+1]=app.id end
    prefs.set('desktop_order',order);self.selectedIcon=to
  end

  function OS:isTaskbarPinned(id)
    for _,value in ipairs(prefs.get('taskbar_pins',{})) do
      if value==id then return true end
    end
    return false
  end

  function OS:toggleTaskbarPin(id)
    if not shellui.allowed(id,self:isOperatorUI()) or id=='home' then return false end
    local current=prefs.get('taskbar_pins',{})
    local nextPins={}
    local found=false
    for _,value in ipairs(current) do
      if value==id then found=true else nextPins[#nextPins+1]=value end
    end
    if not found and #nextPins<8 then nextPins[#nextPins+1]=id end
    prefs.set('taskbar_pins',nextPins)
    self:setNotice(found and 'Application desepinglee.' or 'Application epinglee.',
      self:theme().good)
    return true
  end

  function OS:openDesktopContext(x,y)
    local targetId=nil

    for _,button in ipairs(self.buttons or {}) do
      if inside(x,y,button) and type(button.id)=='string' then
        if button.id:sub(1,8)=='wm:task:' then
          targetId=button.id:sub(9)
          break
        elseif button.id:sub(1,9)=='launcher:' then
          targetId=button.id:sub(10)
          break
        end
      end
    end

    if not targetId then
      for _,icon in ipairs(self.iconRects or {}) do
        if inside(x,y,icon) then targetId=icon.id;break end
      end
    end

    self.startMenuOpen=false
    self.quickPanelOpen=false
    self.contextMenu={x=x,y=y,targetId=targetId}
  end

  function OS:renderContextMenu(target,w,h)
    local menu=self.contextMenu
    if not menu then return end
    local t=self:theme()
    local mw=20
    local options={}

    local function add(label,action,danger)
      options[#options+1]={label=label,action=action,danger=danger}
    end

    if menu.targetId then
      local app=shellui.find(menu.targetId,self:isOperatorUI())
      add("Ouvrir",function() self:openApp(menu.targetId) end)
      add(self:isTaskbarPinned(menu.targetId) and "Desepingler" or "Epingler",function()
        self:toggleTaskbarPin(menu.targetId)
      end)
      add(self:isDesktopShortcut(menu.targetId) and "Retirer du bureau" or "Ajouter au bureau",function()
        self:toggleDesktopShortcut(menu.targetId)
      end)
      if app and app.id~="store" then add("Voir dans Applications",function() self:openApp("store") end) end
      add("Parametres",function() self:openApp("settings") end)
    else
      add("Actualiser",function() self:render() end)
      add("Fichiers",function() self:openApp("files") end)
      add("Applications",function() self:openApp("store") end)
      add("Personnaliser",function() self:openApp("settings") end)
    end

    local mh=#options+2
    local mx=clamp(menu.x,1,math.max(1,w-mw+1))
    local my=clamp(menu.y,1,math.max(1,h-mh))
    self.shellOverlay={x=mx,y=my,w=mw,h=mh}

    draw.fill(target,mx,my,mw,mh,t.elevated)
    draw.text(target,mx+2,my,menu.targetId and "Application" or "Bureau",t.muted,t.elevated,mw-4)
    for i,item in ipairs(options) do
      local by=my+i
      local bg=t.surface2
      draw.fill(target,mx+1,by,mw-2,1,bg)
      draw.text(target,mx+2,by,item.label,item.danger and t.danger or t.text,bg,mw-4)
      self:addButton("context:"..i,mx+1,by,mw-2,1,function()
        self.contextMenu=nil
        item.action()
      end)
    end
  end

  function OS:renderDesktop(target,w,h)
    local t=self:theme()
    local desktopH=math.max(1,h-1)
    shellui.wallpaper(target,1,1,w,desktopH,prefs.get("wallpaper","fluent"),t.accent)
    self.iconRects={}

    local apps=self:desktopApps()
    local tileW=w>=50 and 12 or (w>=38 and 10 or 8)
    local tileH=5
    local gapX=1
    local gapY=1
    local cols=math.max(1,math.floor((w-2)/(tileW+gapX)))
    local rows=math.max(1,math.floor((desktopH-1)/(tileH+gapY)))
    local capacity=math.max(1,cols*rows)
    self.desktopPages=math.max(1,math.ceil(#apps/capacity))
    self.desktopPage=clamp(self.desktopPage or 1,1,self.desktopPages)
    self.iconCapacity=capacity

    local first=(self.desktopPage-1)*capacity+1
    for i=first,math.min(#apps,first+capacity-1) do
      local n=i-first
      local x=2+(n%cols)*(tileW+gapX)
      local y=2+math.floor(n/cols)*(tileH+gapY)
      local selected=self.selectedIcon==i
      local tileBg=selected and t.selection or t.desktop

      if selected then draw.fill(target,x,y,tileW,tileH,tileBg) end
      local iconX=x+math.max(0,math.floor((tileW-3)/2))
      fluent.drawIcon(target,apps[i].id,iconX,y,selected,tileBg)
      draw.text(target,x,y+4,apps[i].title,t.text,tileBg,tileW)

      self.iconRects[#self.iconRects+1]={x=x,y=y,w=tileW,h=tileH,index=i,id=apps[i].id}
    end

    if self.desktopPages>1 then
      local page=tostring(self.desktopPage).." / "..tostring(self.desktopPages)
      draw.text(target,math.max(1,w-#page-1),desktopH,page,t.muted,t.desktop,#page)
    end
  end

  function OS:appContext(win,target,l)
    local theme=self:theme()
    return {target=target,w=l.w,h=l.h,data=win.data,draw=draw,ui=fluent,theme=theme,
      prompt=function(title,hint) return self:prompt(title,hint) end,
      button=function(id,x,y,width,label,fn) self:button(target,id,x,y,width,label,fn) end,
      notice=function(s) self:setNotice(s,theme.accent) end}
  end
  function OS:renderStore(target,l)
    local t=self:theme()
    local query=tostring(self.storeQuery or "")
    local q=query:lower()

    fluent.sectionTitle(target,2,1,l.w-3,"Applications","Catalogue officiel LinkOS",t.accent)
    fluent.searchBox(target,2,4,math.max(12,l.w-15),query,"Rechercher",t.accent)
    self:addButton("store:search",2,4,math.max(12,l.w-15),1,function()
      self.storeQuery=self:prompt("Rechercher une app","Nom, ID ou description") or ""
    end)
    self:button(target,"store:refresh",math.max(2,l.w-11),4,10,"ACTUALISER",function()
      local ok,result=packages.refreshCatalog()
      self:setNotice(ok and (tostring(result).." apps chargees.") or tostring(result),
        ok and t.good or t.warn)
    end)

    if query~="" then
      self:button(target,"store:clear",math.max(2,l.w-11),5,10,"TOUT AFFICHER",function()
        self.storeQuery=""
      end)
    else
      draw.text(target,2,5,
        packages.catalogSource=="remote" and "Catalogue en ligne" or "Catalogue local hors-ligne",
        packages.catalogSource=="remote" and t.good or t.muted,t.bg,l.w-3)
    end

    local visible={}
    for _,p in ipairs(packages.catalog) do
      local hay=(p.title.." "..p.id.." "..p.description):lower()
      if q=="" or hay:find(q,1,true) then visible[#visible+1]=p end
    end

    if #visible==0 then
      fluent.card(target,2,8,math.max(10,l.w-3),5,{
        bg=t.surface,accent=t.muted,title="Aucune application",
        subtitle="Essaie une autre recherche.",muted=t.muted
      })
      return
    end

    local cols=l.w>=60 and 2 or 1
    local gap=1
    local cardW=math.max(16,math.floor((l.w-3-(cols-1)*gap)/cols))
    local cardH=6
    local top=7

    for i,p in ipairs(visible) do
      local col=(i-1)%cols
      local row=math.floor((i-1)/cols)
      local x=2+col*(cardW+gap)
      local y=top+row*(cardH+1)

      local installed=packages.installed(p.id)
      local installedVersion=installed and packages.installedVersion(p.id) or nil
      local outdated=installed and installedVersion and installedVersion~=p.version
      local stateColour=outdated and t.warn or (installed and t.good or t.accent)
      local stateText=outdated and ("MAJ "..p.version)
        or (installed and ("Installee v"..tostring(installedVersion or "?")) or ("Version "..p.version))

      draw.fill(target,x,y,cardW,cardH,t.surface)
      fluent.drawIcon(target,p.id,x+1,y+1,false,t.surface)
      draw.text(target,x+5,y,p.title,t.text,t.surface,math.max(1,cardW-6))
      draw.text(target,x+5,y+1,stateText,stateColour,t.surface,math.max(1,cardW-6))
      draw.text(target,x+5,y+2,p.description,t.muted,t.surface,math.max(1,cardW-6))

      local installLabel=outdated and "METTRE A JOUR" or (installed and "REINSTALL" or "INSTALLER")
      local installW=math.min(12,math.max(8,cardW-10))
      self:button(target,"store:install:"..p.id,x+1,y+4,installW,installLabel,function()
        local verb=outdated and "Mettre a jour " or "Installer "
        if self:confirm(verb..p.title.." depuis le depot officiel ?") then
          local ok,msg=packages.install(p.id)
          self:setNotice(msg,ok and t.good or t.danger)
        end
      end)

      if installed then
        local openX=x+2+installW
        if openX+6<=x+cardW-1 then
          self:button(target,"store:open:"..p.id,openX,y+4,7,"OUVRIR",function()
            self:openApp("pkg:"..p.id)
          end)
        end
        if cardW>=28 then
          self:button(target,"store:remove:"..p.id,x+cardW-8,y+5,7,"RETIRER",function()
            if self:confirm("Retirer "..p.title.." ? Donnees conservees.") then
              local ok,err=packages.remove(p.id)
              if ok then
                for j=#self.windows,1,-1 do
                  if self.windows[j].id=="pkg:"..p.id then table.remove(self.windows,j) end
                end
              end
              self:setNotice(ok and "Application retiree." or tostring(err),
                ok and t.warn or t.danger)
            end
          end)
        end
      end
    end
  end
  function OS:renderWindow(target,win,w,h)
    local t=self:theme()
    local desktopH=math.max(1,h-1)

    local simpleDisplay = w < 70 or h < 22
    if simpleDisplay then win.maximized=true end
    if win.maximized then win.x,win.y,win.w,win.h=1,1,w,desktopH end
    win.w=clamp(win.w,math.min(24,w),w)
    win.h=clamp(win.h,math.min(8,desktopH),desktopH)
    win.x=clamp(win.x,1,w-win.w+1)
    win.y=clamp(win.y,1,desktopH-win.h+1)

    local app=shellui.find(win.id,self:isOperatorUI())
    local active=self.app==win.id
    local titleBg=active and t.titleActive or t.titleInactive
    local bodyW=math.max(1,win.w-2)
    local bodyH=math.max(1,win.h-2)

    -- Subtle frame/shadow instead of a saturated title bar.
    draw.fill(target,win.x,win.y,win.w,win.h,t.border)
    draw.fill(target,win.x,win.y,win.w,1,titleBg)
    if active then draw.fill(target,win.x,win.y,1,win.h,t.accent) end
    fluent.drawMiniIcon(target,win.id,win.x+1,win.y,active,titleBg)
    draw.text(target,win.x+5,win.y,(app and app.title or win.id),
      active and t.text or t.muted,titleBg,math.max(1,win.w-16))
    draw.fill(target,win.x+1,win.y+1,bodyW,bodyH,t.bg)

    local function control(offset,label,danger,callback)
      local cx=win.x+win.w-offset
      local bg=danger and t.danger or titleBg
      draw.fill(target,cx,win.y,3,1,bg)
      draw.text(target,cx+1,win.y,label,danger and colors.white or t.muted,bg,1)
      self:addButton("win:"..win.id..":"..label,cx,win.y,3,1,callback)
    end

    if simpleDisplay then
      control(3,"X",true,function() self:closeWindow(win) end)
    else
      control(9,"-",false,function()
        win.minimized=true
        self.app="home"
        self.showDesktopSnapshot=nil
        self:saveWorkspaceSession()
      end)
      control(6,win.maximized and "o" or "O",false,function()
        if win.maximized then
          win.maximized=false
          local r=win.restore
          if r then win.x,win.y,win.w,win.h=table.unpack(r) end
        else
          win.restore={win.x,win.y,win.w,win.h}
          win.maximized=true
        end
        self:saveWorkspaceSession()
      end)
      control(3,"X",true,function() self:closeWindow(win) end)
    end

    local virtualH=math.max(30,bodyH)
    if win.id=="store" then
      local storeCols=bodyW>=60 and 2 or 1
      virtualH=math.max(virtualH,math.ceil(#packages.catalog/storeCols)*7+8)
    elseif win.id=="settings" then
      virtualH=math.max(virtualH,38)
    end
    local maxScroll=math.max(0,virtualH-bodyH)
    win.scroll=clamp(win.scroll or 0,0,maxScroll)

    local canvas=window.create(target,1,1,bodyW,virtualH,false)
    local l={w=bodyW,h=virtualH,mode="standard",contentX=2,contentY=2,
      contentW=math.max(1,bodyW-3),contentH=math.max(1,virtualH-5)}

    local savedButtons=self.buttons
    self.buttons={}
    self.drawingWindow=win

    local ok,err=pcall(function()
      if win.program then
        win.program.draw(self:appContext(win,canvas,l))
      elseif renderers[win.id] then
        self[renderers[win.id]](self,canvas,l)
      end
    end)

    self.drawingWindow=nil
    local localButtons=self.buttons
    self.buttons=savedButtons
    win.renderError=not ok and tostring(err) or nil

    if not ok then
      draw.clear(canvas,t.bg,t.text)
      fluent.card(canvas,2,2,math.max(8,bodyW-3),4,{
        bg=t.surface,accent=t.danger,title="Application interrompue",subtitle=tostring(err),muted=t.muted
      })
      localButtons={}
    end

    for row=1,bodyH do
      local text,fg,bg=canvas.getLine(row+win.scroll)
      target.setCursorPos(win.x+1,win.y+row)
      target.blit(text,fg,bg)
    end

    for _,btn in ipairs(localButtons) do
      local by=btn.y-win.scroll
      if btn.x>=1 and btn.x+btn.w-1<=bodyW and by>=1 and by+btn.h-1<=bodyH then
        self:addButton(btn.id,win.x+btn.x,win.y+by,btn.w,btn.h,btn.callback)
      end
    end

    if maxScroll>0 then
      local trackTop=win.y+1
      local trackH=bodyH
      draw.fill(target,win.x+win.w-1,trackTop,1,trackH,t.surface)
      local thumbH=math.max(1,math.floor(trackH*bodyH/virtualH))
      local thumbY=trackTop
      if trackH>thumbH then
        thumbY=trackTop+math.floor((trackH-thumbH)*win.scroll/maxScroll)
      end
      draw.fill(target,win.x+win.w-1,thumbY,1,thumbH,active and t.accent or t.muted)
      self:addButton("scroll:track:"..win.id,win.x+win.w-1,trackTop,1,trackH,function()
        win.scroll=math.min(maxScroll,win.scroll+math.max(1,bodyH-2))
      end)
    end

    if not win.maximized then
      draw.text(target,win.x+win.w-1,win.y+win.h-1,"+",t.muted,t.border,1)
    end
  end

  function OS:render()
    if self.dialogOpen or not self.active then return end
    local t=self:theme()
    self:restoreWorkspaceSession()
    local list=self:workspace()
    if self.renderHijackState and self:renderHijackState() then return end
    if self.renderUserLock and self:renderUserLock() then return end

    local physical=self.active.target
    local w,h=physical.getSize()
    local target=window.create(physical,1,1,w,h,false)
    self.buttons={}
    self.shellOverlay=nil

    self:renderDesktop(target,w,h)

    for _,win in ipairs(list) do
      if not win.minimized and shellui.allowed(win.id,self:isOperatorUI()) then
        for i=#self.buttons,1,-1 do
          local b=self.buttons[i]
          if b.x<win.x+win.w and b.x+b.w>win.x
            and b.y<win.y+win.h and b.y+b.h>win.y then
            table.remove(self.buttons,i)
          end
        end
        self:renderWindow(target,win,w,h)
      end
    end

    -- Simple Windows-like taskbar: obvious Start, apps, then system tray.
    draw.fill(target,1,h,w,1,t.taskbar)

    local startW=7
    local startBg=self.startMenuOpen and t.selection or t.taskbar
    draw.fill(target,1,h,startW,1,startBg)
    draw.text(target,2,h,"START",self.startMenuOpen and t.accent or t.text,startBg,5)
    self:addButton("wm:start",1,h,startW,1,function() self:toggleStartMenu() end)

    local clock=textutils.formatTime(os.time(),true)
    local netText=self.service.online and "NET" or "OFF"
    local trayW=10
    local trayX=math.max(startW+2,w-trayW+1)
    draw.text(target,trayX,h,netText,self.service.online and t.good or t.danger,t.taskbar,3)
    draw.text(target,w-5,h,clock,t.text,t.taskbar,5)
    self:addButton("wm:system",trayX,h,3,1,function() self:toggleQuickPanel() end)
    self:addButton("wm:clock",w-5,h,5,1,function() self:toggleQuickPanel() end)

    local unread=tonumber(self.service.unread) or 0
    if unread>0 and trayX-2>startW then
      draw.text(target,trayX-2,h,tostring(math.min(9,unread)),t.warn,t.taskbar,1)
    end

    local openById={}
    for _,win in ipairs(list) do openById[win.id]=win end

    local taskItems={}
    local seen={}
    for _,app in ipairs(self:taskbarPins()) do
      taskItems[#taskItems+1]={id=app.id,app=app,win=openById[app.id]}
      seen[app.id]=true
    end
    for _,win in ipairs(list) do
      if not seen[win.id] then
        taskItems[#taskItems+1]={id=win.id,app=shellui.find(win.id,self:isOperatorUI()),win=win}
        seen[win.id]=true
      end
    end

    local taskX=startW+1
    local available=math.max(0,trayX-taskX-2)
    local taskW=6
    local maxTasks=math.max(0,math.floor(available/taskW))
    local visible=math.min(#taskItems,maxTasks)

    for i=1,visible do
      local item=taskItems[i]
      local app=item.app
      local active=item.win and item.win.id==self.app and not item.win.minimized
      local bg=active and t.selection or t.taskbar
      local label=(app and (app.short or app.title) or item.id):upper()
      label=label:sub(1,math.max(1,taskW-1))

      draw.fill(target,taskX,h,taskW,1,bg)
      draw.text(target,taskX+1,h,label,active and t.text or t.muted,bg,taskW-1)
      self:addButton("wm:task:"..item.id,taskX,h,taskW,1,function()
        local win=openById[item.id]
        if win then
          if win.id==self.app and not win.minimized then
            win.minimized=true
            self.app="home"
            self.showDesktopSnapshot=nil
            self:saveWorkspaceSession()
          else
            self:focusWindow(win)
          end
        else
          self:openApp(item.id)
        end
      end)
      taskX=taskX+taskW
    end

    if visible<#taskItems and taskX<trayX-1 then
      local hidden=#taskItems-visible
      draw.text(target,taskX,h,"+"..tostring(hidden),t.muted,t.taskbar,
        math.min(3,trayX-taskX-1))
      self:addButton("wm:overflow",taskX,h,math.min(3,trayX-taskX-1),1,
        function() self.startAllApps=true;self:toggleStartMenu() end)
    end

    if self.notice then
      local message=tostring(self.notice)
      local nw=math.min(math.max(22,math.floor(w*0.46)),math.max(18,w-2))
      local nx=math.max(1,w-nw)
      local ny=math.max(1,h-4)
      draw.fill(target,nx,ny,nw,3,t.elevated)
      draw.fill(target,nx,ny,1,3,self.noticeColour or t.accent)
      draw.text(target,nx+2,ny,"LinkOS",t.text,t.elevated,math.max(1,nw-3))
      draw.text(target,nx+2,ny+1,message,self.noticeColour or t.text,t.elevated,math.max(1,nw-3))
      draw.text(target,nx+2,ny+2,"Notification",t.muted,t.elevated,math.max(1,nw-3))
    end

    self:renderShellOverlays(target,{w=w,h=h,mode='standard'})
    if self.contextMenu and not self.startMenuOpen and not self.quickPanelOpen then
      self:renderContextMenu(target,w,h)
    end
    if self.taskSwitcherOpen and not self.startMenuOpen and not self.quickPanelOpen then
      self:renderTaskSwitcher(target,w,h)
    end

    for row=1,h do
      physical.setCursorPos(1,row)
      physical.blit(target.getLine(row))
    end
    self:renderCompanions()
    physical.setCursorBlink(false)
  end

  function OS:hit(x,y)
    local modal=self.shellOverlay
    if modal then
      if not inside(x,y,modal) then
        self.startMenuOpen,self.quickPanelOpen=false,false
        self.contextMenu=nil
        return true
      end
    else
      for i=#self:workspace(),1,-1 do
        local win=self.windows[i]
        if not win.minimized and inside(x,y,win) then
          self:focusWindow(win)
          if y==win.y and x<win.x+win.w-9 then
            local now=os.clock()
            if self.lastTitleWindow==win.id and now-(self.lastTitleClick or 0)<0.40 then
              if win.maximized then
                win.maximized=false
                local r=win.restore
                if r then win.x,win.y,win.w,win.h=table.unpack(r) end
              else
                win.restore={win.x,win.y,win.w,win.h}
                win.maximized=true
              end
              self.lastTitleWindow=nil
              self.lastTitleClick=0
              self:saveWorkspaceSession()
              self:render()
              return true
            end
            self.lastTitleWindow=win.id
            self.lastTitleClick=now
            self.windowDrag={
              win=win,dx=x-win.x,dy=y-win.y,
              original={win.x,win.y,win.w,win.h}
            }
            return true
          elseif x==win.x+win.w-1 and y==win.y+win.h-1 then
            self.windowDrag={win=win,resize=true};return true
          end
          self:render();break
        end
      end
    end
    for i=#self.buttons,1,-1 do
      local b=self.buttons[i]
      if inside(x,y,b) then b.callback();return true end
    end
    if modal then return true end
    for i=#self.windows,1,-1 do if not self.windows[i].minimized and inside(x,y,self.windows[i]) then return true end end
    for _,icon in ipairs(self.iconRects or {}) do
      if inside(x,y,icon) then
        self.selectedIcon=icon.index
        if self.lastIcon==icon.id and os.clock()-(self.lastIconTime or 0)<0.45 then
          self.iconDrag=nil;self:openApp(icon.id)
        else self.iconDrag=icon.index;self.lastIcon=icon.id;self.lastIconTime=os.clock() end
        return true
      end
    end
    return false
  end
  function OS:workspaceEvent(event,a,b,c)
    if (event=='mouse_drag' or event=='mouse_up' or event=='mouse_scroll')
      and self.active.kind~='computer' then return false end
    if event=='key_up' and (a==keys.leftCtrl or a==keys.rightCtrl) then self.ctrlHeld=false;return true end
    if event=='key_up' and (a==keys.leftAlt or a==keys.rightAlt) then
      self.altHeld=false
      self.taskSwitcherOpen=false
      self:render()
      return true
    end
    if event=='key' and (a==keys.leftCtrl or a==keys.rightCtrl) then self.ctrlHeld=true;return true end
    if event=='key' and (a==keys.leftAlt or a==keys.rightAlt) then self.altHeld=true;return true end
    local note=self.noteDocument
    if self.app=='notes' and note and note.editing and not self.startMenuOpen and not self.quickPanelOpen then
      local line=note.lines[note.row] or ''
      local handled=true
      if event=='char' or event=='paste' then
        local text=tostring(a):gsub('[\r\n]',' ')
        if #line+#text<=500 then
          note.lines[note.row]=line:sub(1,note.col-1)..text..line:sub(note.col)
          note.col=note.col+#text;note.dirty=true
        end
      elseif event=='key' then
        if self.ctrlHeld and a==keys.s then self:saveNote()
        elseif a==keys.escape then note.editing=false
        elseif a==keys.enter and #note.lines<500 then
          note.lines[note.row]=line:sub(1,note.col-1)
          table.insert(note.lines,note.row+1,line:sub(note.col));note.row=note.row+1;note.col=1;note.dirty=true
        elseif a==keys.backspace then
          if note.col>1 then note.lines[note.row]=line:sub(1,note.col-2)..line:sub(note.col);note.col=note.col-1
          elseif note.row>1 and #note.lines[note.row-1]+#line<=500 then
            note.col=#note.lines[note.row-1]+1
            note.lines[note.row-1]=note.lines[note.row-1]..line;table.remove(note.lines,note.row);note.row=note.row-1
          end
          note.dirty=true
        elseif a==keys.left then note.col=math.max(1,note.col-1)
        elseif a==keys.right then note.col=math.min(#line+1,note.col+1)
        elseif a==keys.up then note.row=math.max(1,note.row-1);note.col=math.min(note.col,#note.lines[note.row]+1)
        elseif a==keys.down then note.row=math.min(#note.lines,note.row+1);note.col=math.min(note.col,#note.lines[note.row]+1)
        else handled=false end
      else handled=false end
      if handled then
        for _,win in ipairs(self:workspace()) do
          if win.id=='notes' then
            local row=7+(note.row-1)%18
            if row>(win.scroll or 0)+win.h-2 then win.scroll=row-win.h+2
            elseif row<=(win.scroll or 0) then win.scroll=row-1 end
          end
        end
        self:render();return true
      end
    end
    if event=='mouse_drag' then
      local drag=self.windowDrag
      if drag then
        local win=drag.win;win.maximized=false
        if drag.resize then win.w=b-win.x+1;win.h=c-win.y+1 else win.x=b-drag.dx;win.y=c-drag.dy end
      elseif self.iconDrag then self.iconMoved=true end
      self:render();return true
    elseif event=='mouse_up' then
      if self.iconDrag and self.iconMoved then
        for _,icon in ipairs(self.iconRects or {}) do if inside(b,c,icon) then self:moveIcon(self.iconDrag,icon.index);break end end
      end
      if self.windowDrag then
        local drag=self.windowDrag
        local win=drag.win
        local sw,sh=self.active.target.getSize()
        local desktopH=math.max(1,sh-1)

        if not drag.resize then
          if c<=1 then
            win.restore=drag.original or {win.x,win.y,win.w,win.h}
            win.maximized=true
            win.snapped=nil
          elseif b<=1 then
            win.maximized=false
            win.restore=drag.original or win.restore
            win.x,win.y=1,1
            win.w,win.h=math.max(24,math.floor(sw/2)),desktopH
            win.snapped='left'
          elseif b>=sw then
            win.maximized=false
            win.restore=drag.original or win.restore
            win.w,win.h=math.max(24,math.ceil(sw/2)),desktopH
            win.x,win.y=sw-win.w+1,1
            win.snapped='right'
          else
            win.snapped=nil
          end
        end

        self:persistWindowGeometry(win)
        self:saveWorkspaceSession()
      end
      self.iconDrag,self.iconMoved,self.windowDrag=nil,nil,nil
      self:render();return true
    elseif event=='mouse_scroll' and not self.startMenuOpen and not self.quickPanelOpen then
      if self.app~='home' then
        for _,win in ipairs(self:workspace()) do if win.id==self.app then win.scroll=math.max(0,(win.scroll or 0)+a*3) end end
      else self.desktopPage=clamp((self.desktopPage or 1)+a,1,self.desktopPages or 1) end
      self:render();return true
    end
    return false
  end

  function OS:prompt(title,hint,secret)
    local value=''
    self.dialogOpen=true
    local target=self.active.target
    local w,h=target.getSize()
    local dw=math.min(w-2,46);local dh=math.min(h-2,8)
    local x=math.max(1,math.floor((w-dw)/2));local y=math.max(1,math.floor((h-dh)/2))
    local result
    while result==nil do
      draw.fill(target,x,y,dw,dh,colors.gray)
      draw.fill(target,x,y,dw,1,colors.cyan)
      draw.text(target,x+1,y,title,colors.white,colors.cyan,dw-2)
      draw.text(target,x+1,y+2,hint or 'Saisir au clavier du Computer',colors.lightGray,colors.gray,dw-2)
      local text=secret and string.rep('*',#value) or value
      draw.fill(target,x+1,y+3,dw-2,1,colors.black)
      draw.text(target,x+1,y+3,text:sub(-math.max(1,dw-3))..'_',colors.white,colors.black,dw-2)
      local by=y+dh-2
      draw.button(target,x+1,by,8,'VALIDER',colors.white,colors.cyan)
      draw.button(target,x+dw-10,by,9,'ANNULER',colors.white,colors.black)
      local event,a,b,c=os.pullEventRaw()
      if event=='key_up' and (a==keys.leftCtrl or a==keys.rightCtrl) then self.ctrlHeld=false
      elseif event=='char' or event=='paste' then value=(value..tostring(a):gsub('[\r\n]',' ')):sub(1,500)
      elseif event=='key' then
        if a==keys.enter then result=value
        elseif a==keys.escape then result=''
        elseif a==keys.backspace then value=value:sub(1,-2) end
      elseif (event=='mouse_click' and self.active.kind=='computer')
        or (event=='monitor_touch' and a==self.active.name) then
        if c==by and b>=x+1 and b<x+9 then result=value
        elseif c==by and b>=x+dw-10 and b<x+dw-1 then result='' end
      elseif event=='monitor_resize' or event=='term_resize' or event=='peripheral_detach'
        or event=='terminate' or event=='linkos_hacked_state' then result='' end
    end
    self.dialogOpen=false
    self:refreshDisplays();self:render()
    return result
  end
  function OS:promptSecret(title,hint) return self:prompt(title,hint,true) end

  function OS:loadNote(path)
    local text=''
    if fs.exists(path) then
      local f=fs.open(path,'r');if f then text=f.read(65537) or '';f.close() end
    end
    if #text>65536 then self:setNotice('Document trop volumineux (64 Ko maximum).',colors.red);return false end
    local lines={};for line in (text..'\n'):gmatch('(.-)\n') do lines[#lines+1]=line end
    self.noteDocument={path=path,lines=lines,row=1,col=1,editing=false,dirty=false}
    return true
  end
  function OS:saveNote()
    local note=self.noteDocument;if not note then return end
    local ok,err=pcall(function()
      local path=note.path
      local f=assert(fs.open(path..'.saving','w'),'Ecriture impossible')
      f.write(table.concat(note.lines,'\n'));f.close()
      if fs.exists(path) then
        if fs.exists(path..'.backup') then fs.delete(path..'.backup') end
        fs.move(path,path..'.backup')
      end
      local moved,failure=pcall(fs.move,path..'.saving',path)
      if not moved then
        if not fs.exists(path) and fs.exists(path..'.backup') then fs.move(path..'.backup',path) end
        error(failure)
      end
    end)
    if ok then note.dirty=false end
    self:setNotice(ok and 'Document sauvegarde.' or tostring(err),ok and colors.lime or colors.red)
  end
  function OS:renderNotes(target,l)
    if not self.noteDocument then self:loadNote("/user/notes.txt") end
    local note=self.noteDocument
    if not note then return end
    local t=self:theme()

    fluent.sectionTitle(target,2,1,l.w-3,"Notes",
      (note.dirty and "Modifications non enregistrees" or note.path),t.accent)
    self:button(target,"note:edit",2,4,10,note.editing and "EDITION" or "EDITER",
      function() note.editing=not note.editing end)
    self:button(target,"note:save",13,4,11,"SAUVEGARDER",function() self:saveNote() end)

    draw.fill(target,2,6,l.w-3,1,t.surface)
    draw.text(target,3,6,"Entree: ligne  |  Ctrl+S: sauver  |  Esc: quitter l'edition",
      t.muted,t.surface,l.w-5)

    draw.fill(target,2,8,l.w-3,math.max(5,l.h-9),t.surface2)
    local page=math.floor((note.row-1)/18)
    for row=page*18+1,math.min(#note.lines,page*18+18) do
      local text=note.lines[row]
      local active=row==note.row
      if active and note.editing then
        local start=math.max(1,note.col-(l.w-8))
        text=text:sub(start,note.col-1).."|"..text:sub(note.col)
      end
      local y=8+row-page*18-1
      local bg=active and t.selection or t.surface2
      if active then draw.fill(target,2,y,l.w-3,1,bg) end
      draw.text(target,3,y,text,active and t.text or t.muted,bg,l.w-5)
      self:addButton("note:line:"..row,2,y,l.w-3,1,function()
        note.row=row;note.col=#note.lines[row]+1;note.editing=true
      end)
    end
  end

  function OS:handleKey(key)
    if self.startMenuOpen then return originalKey(self,key) end
    local list=self:workspace()
    local focused
    for _,win in ipairs(list) do if win.id==self.app and not win.minimized then focused=win end end

    if self.altHeld and key==keys.tab then
      self:cycleWindow(1)
      return
    end

    if self.ctrlHeld and key==keys.d then
      self:toggleShowDesktop()
      return
    end

    if self.ctrlHeld and focused then
      if key==keys.w then
        self:closeWindow(focused)
      elseif key==keys.m then
        focused.minimized=true
        self.app='home'
        self.showDesktopSnapshot=nil
        self:saveWorkspaceSession()
      elseif key==keys.enter then
        if focused.maximized then
          focused.maximized=false
          if focused.restore then focused.x,focused.y,focused.w,focused.h=table.unpack(focused.restore) end
        else
          focused.restore={focused.x,focused.y,focused.w,focused.h}
          focused.maximized=true
        end
        self:saveWorkspaceSession()
      elseif key==keys.left then
        focused.maximized=false;focused.x=focused.x-1
        self:persistWindowGeometry(focused);self:saveWorkspaceSession()
      elseif key==keys.right then
        focused.maximized=false;focused.x=focused.x+1
        self:persistWindowGeometry(focused);self:saveWorkspaceSession()
      elseif key==keys.up then
        focused.maximized=false;focused.y=focused.y-1
        self:persistWindowGeometry(focused);self:saveWorkspaceSession()
      elseif key==keys.down then
        focused.maximized=false;focused.y=focused.y+1
        self:persistWindowGeometry(focused);self:saveWorkspaceSession()
      end
      return
    end
    if focused and key==keys.tab then
      self.focusIndex=(self.focusIndex or 0)%math.max(1,#self.buttons)+1
      self.keyboardFocusId=self.buttons[self.focusIndex] and self.buttons[self.focusIndex].id
      self:setNotice('Selection: '..tostring(self.keyboardFocusId)..' / Entree')
      return
    elseif focused and key==keys.enter and self.keyboardFocusId then
      for _,b in ipairs(self.buttons) do if b.id==self.keyboardFocusId then b.callback();break end end
      return
    end
    if key==keys.f12 then
      self:cycleWindow(1)
    elseif key==keys.pageUp or key==keys.pageDown then
      for _,win in ipairs(list) do if win.id==self.app then win.scroll=math.max(0,(win.scroll or 0)+(key==keys.pageDown and 4 or -4)) end end
    elseif self.app=='home' and (key==keys.tab or key==keys.enter or key==keys.m) then
      local apps=self:desktopApps()
      if key==keys.tab then
        self.selectedIcon=(self.selectedIcon or 1)%#apps+1
        self.desktopPage=math.floor((self.selectedIcon-1)/(self.iconCapacity or 1))+1
      elseif key==keys.m then
        self.movingIcon=not self.movingIcon
        self:setNotice(self.movingIcon and 'Deplacement: fleches, puis M pour terminer.' or 'Position enregistree.')
      else local app=apps[self.selectedIcon or 1];if app then self:openApp(app.id) end end
    elseif self.app=='home' and self.movingIcon and (key==keys.left or key==keys.right) then
      self:moveIcon(self.selectedIcon or 1,(self.selectedIcon or 1)+(key==keys.right and 1 or -1))
    else return originalKey(self,key) end
  end
end
return M
