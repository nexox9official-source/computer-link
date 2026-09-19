-- LinkOS workspace: one retained window per application, no replacement of MER.
local draw=dofile('/computer-link/src/ui/draw.lua')
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
  function OS:focusWindow(win)
    local list=self:workspace()
    for i,v in ipairs(list) do if v==win then table.remove(list,i);break end end
    list[#list+1]=win; win.minimized=false; self.app=win.id
  end
  function OS:openApp(id)
    local list=self:workspace()
    self.startMenuOpen,self.quickPanelOpen=false,false
    if id=='home' then
      for _,v in ipairs(list) do v.minimized=true end
      self.app='home'; self:render(); return
    end
    if not shellui.allowed(id,self:isOperatorUI()) then return end
    for _,v in ipairs(list) do if v.id==id then self:focusWindow(v); self:render(); return end end
    local w,h=self.active.target.getSize()
    local offset=#list%4
    local defaultW=math.min(w-2,math.max(24,math.floor(w*0.82)))
    local defaultH=math.min(h-2,math.max(8,math.floor((h-1)*0.78)))
    local win={id=id,x=2+offset*2,y=1+offset,w=defaultW,h=defaultH,data={},scroll=0}
    local saved=prefs.get('window_geometry',{})[id]
    if type(saved)=='table' and type(saved.x)=='number' and type(saved.y)=='number'
      and type(saved.w)=='number' and type(saved.h)=='number' then
      win.x,win.y,win.w,win.h=saved.x,saved.y,saved.w,saved.h
    end
    if id:sub(1,4)=='pkg:' then
      local ok,app=pcall(dofile,packages.path(id:sub(5)))
      if not ok or type(app)~='table' or type(app.draw)~='function' then
        self:setNotice('Application invalide: '..tostring(app),colors.red); self:render(); return
      end
      win.program=app
    end
    list[#list+1]=win; self.app=id
    if id=='messages' then self.service:markRead() end
    self:render()
  end
  function OS:closeWindow(win)
    if win.id=='notes' and self.noteDocument and self.noteDocument.dirty then
      local answer=self:prompt('Document modifie','OUI: sauver / NON: abandonner / Echap: annuler'):lower()
      if answer=='oui' then self:saveNote();if self.noteDocument.dirty then return end
      elseif answer~='non' then return end
    end
    if win.id=='notes' then self.noteDocument=nil end
    for i,v in ipairs(self:workspace()) do if v==win then table.remove(self.windows,i);break end end
    self.app='home'
    for _,v in ipairs(self.windows) do if not v.minimized then self.app=v.id end end
  end
  function OS:desktopApps()
    local items,seen={},{}
    local available=shellui.apps(self:isOperatorUI())
    local map={}
    for _,app in ipairs(available) do if app.id~='home' then map[app.id]=app end end
    for _,id in ipairs(prefs.get('desktop_order',{})) do
      if map[id] and not seen[id] then items[#items+1]=map[id];seen[id]=true end
    end
    for _,app in ipairs(available) do
      if app.id~='home' and not seen[app.id] then items[#items+1]=app;seen[app.id]=true end
    end
    return items
  end
  function OS:moveIcon(from,to)
    local apps=self:desktopApps()
    from,to=clamp(from,1,#apps),clamp(to,1,#apps)
    local item=table.remove(apps,from);table.insert(apps,to,item)
    local order={};for _,app in ipairs(apps) do order[#order+1]=app.id end
    prefs.set('desktop_order',order);self.selectedIcon=to
  end
  function OS:renderDesktop(target,w,h)
    local t=self:theme()
    local desktopH=math.max(1,h-1)
    shellui.wallpaper(target,1,1,w,desktopH,prefs.get('wallpaper','dots'),t.accent)
    self.iconRects={}

    local apps=self:desktopApps()
    local tileW,tileH=9,3
    local cols=math.max(1,math.floor((w-2)/(tileW+1)))
    local rows=math.max(1,math.floor((desktopH-2)/(tileH+1)))
    local capacity=math.max(1,cols*rows)
    self.desktopPages=math.max(1,math.ceil(#apps/capacity))
    self.desktopPage=clamp(self.desktopPage or 1,1,self.desktopPages)
    self.iconCapacity=capacity

    local palette={
      messages=colors.cyan,contacts=colors.lightBlue,network=colors.lime,
      security=colors.purple,files=colors.orange,notes=colors.yellow,
      calculator=colors.green,terminal=colors.lightGray,store=colors.blue,
      settings=colors.blue,about=colors.cyan,hacker=colors.red
    }

    local first=(self.desktopPage-1)*capacity+1
    for i=first,math.min(#apps,first+capacity-1) do
      local n=i-first
      local x=2+(n%cols)*(tileW+1)
      local y=2+math.floor(n/cols)*(tileH+1)
      local selected=self.selectedIcon==i
      local tileBg=selected and colors.gray or colors.black
      local badge=palette[apps[i].id] or t.accent

      if selected then draw.fill(target,x,y,tileW,tileH,tileBg) end
      draw.fill(target,x+3,y,3,2,badge)
      draw.text(target,x+3,y,apps[i].icon or '+',colors.white,badge,3)
      draw.text(target,x,y+2,apps[i].title,colors.white,tileBg,tileW)

      self.iconRects[#self.iconRects+1]={x=x,y=y,w=tileW,h=tileH,index=i,id=apps[i].id}
    end

    if self.desktopPages>1 then
      local page=tostring(self.desktopPage)..'/'..tostring(self.desktopPages)
      draw.text(target,math.max(1,w-#page-1),1,page,t.muted,colors.black,#page)
    end
  end

  function OS:appContext(win,target,l)
    return {target=target,w=l.w,h=l.h,data=win.data,draw=draw,
      prompt=function(title,hint) return self:prompt(title,hint) end,
      button=function(id,x,y,width,label,fn) self:button(target,id,x,y,width,label,fn) end,
      notice=function(s) self:setNotice(s,colors.cyan) end}
  end
  function OS:renderStore(target,l)
    local t=self:theme()
    draw.text(target,2,1,'Applications',t.text,t.bg,l.w-3)
    draw.text(target,2,2,'Catalogue officiel LinkOS',t.muted,t.bg,l.w-3)

    local row=4
    for _,p in ipairs(packages.catalog) do
      if row+3>l.h then break end
      local installed=packages.installed(p.id)
      draw.fill(target,2,row,l.w-3,3,colors.black)
      draw.fill(target,2,row,2,3,installed and colors.lime or t.accent)
      draw.text(target,5,row,p.title,t.text,colors.black,math.max(1,l.w-16))
      draw.text(target,5,row+1,p.description,t.muted,colors.black,math.max(1,l.w-7))
      draw.text(target,math.max(5,l.w-10),row,installed and 'INSTALLE' or p.version,
        installed and colors.lime or t.muted,colors.black,9)

      self:button(target,'store:install:'..p.id,5,row+2,installed and 10 or 9,
        installed and 'REINSTALL' or 'INSTALLER',function()
          if self:confirm('Installer '..p.title..' depuis le depot officiel ?') then
            local ok,msg=packages.install(p.id)
            self:setNotice(msg,ok and colors.lime or colors.red)
          end
        end)

      if installed then
        self:button(target,'store:open:'..p.id,16,row+2,7,'OUVRIR',function() self:openApp('pkg:'..p.id) end)
        if l.w>=35 then
          self:button(target,'store:remove:'..p.id,24,row+2,8,'RETIRER',function()
            if self:confirm('Retirer '..p.title..' ? Donnees conservees.') then
              local ok,err=packages.remove(p.id)
              if ok then
                for j=#self.windows,1,-1 do
                  if self.windows[j].id=='pkg:'..p.id then table.remove(self.windows,j) end
                end
              end
              self:setNotice(ok and 'Application retiree.' or tostring(err),ok and colors.orange or colors.red)
            end
          end)
        end
      end
      row=row+4
    end
  end

  function OS:renderWindow(target,win,w,h)
    local t=self:theme()
    local desktopH=math.max(1,h-1)

    if win.maximized then win.x,win.y,win.w,win.h=1,1,w,desktopH end
    win.w=clamp(win.w,math.min(24,w),w)
    win.h=clamp(win.h,math.min(8,desktopH),desktopH)
    win.x=clamp(win.x,1,w-win.w+1)
    win.y=clamp(win.y,1,desktopH-win.h+1)

    local app=shellui.find(win.id,self:isOperatorUI())
    local active=self.app==win.id
    local titleBg=active and t.accent or colors.gray
    local bodyW=math.max(1,win.w-2)
    local bodyH=math.max(1,win.h-2)

    draw.fill(target,win.x,win.y,win.w,win.h,colors.gray)
    draw.fill(target,win.x,win.y,win.w,1,titleBg)
    draw.text(target,win.x+1,win.y,(app and (app.icon..'  '..app.title) or win.id),
      colors.white,titleBg,math.max(1,win.w-11))
    draw.fill(target,win.x+1,win.y+1,bodyW,bodyH,colors.black)

    local function control(offset,label,bg,callback)
      local x=win.x+win.w-offset
      draw.fill(target,x,win.y,3,1,bg or titleBg)
      draw.text(target,x+1,win.y,label,colors.white,bg or titleBg,1)
      self:addButton('win:'..win.id..':'..label,x,win.y,3,1,callback)
    end

    control(9,'-',titleBg,function() win.minimized=true;self.app='home' end)
    control(6,'O',titleBg,function()
      if win.maximized then
        win.maximized=false
        local r=win.restore
        if r then win.x,win.y,win.w,win.h=table.unpack(r) end
      else
        win.restore={win.x,win.y,win.w,win.h}
        win.maximized=true
      end
    end)
    control(3,'X',colors.red,function() self:closeWindow(win) end)

    local virtualH=math.max(30,bodyH)
    local maxScroll=math.max(0,virtualH-bodyH)
    win.scroll=clamp(win.scroll or 0,0,maxScroll)

    local canvas=window.create(target,1,1,bodyW,virtualH,false)
    local l={w=bodyW,h=virtualH,mode='standard',contentX=2,contentY=2,
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
      draw.clear(canvas,colors.black,colors.white)
      draw.text(canvas,2,2,'Application interrompue',colors.red,nil,math.max(1,bodyW-3))
      draw.text(canvas,2,4,tostring(err),colors.lightGray,nil,math.max(1,bodyW-3))
      localButtons={}
    end

    for row=1,bodyH do
      local text,fg,bg=canvas.getLine(row+win.scroll)
      target.setCursorPos(win.x+1,win.y+row)
      target.blit(text,fg,bg)
    end

    for _,b in ipairs(localButtons) do
      local by=b.y-win.scroll
      if b.x>=1 and b.x+b.w-1<=bodyW and by>=1 and by+b.h-1<=bodyH then
        self:addButton(b.id,win.x+b.x,win.y+by,b.w,b.h,b.callback)
      end
    end

    if maxScroll>0 then
      local trackTop=win.y+1
      local trackH=bodyH
      draw.fill(target,win.x+win.w-1,trackTop,1,trackH,colors.gray)
      local thumbH=math.max(1,math.floor(trackH*bodyH/virtualH))
      local thumbY=trackTop
      if maxScroll>0 and trackH>thumbH then
        thumbY=trackTop+math.floor((trackH-thumbH)*win.scroll/maxScroll)
      end
      draw.fill(target,win.x+win.w-1,thumbY,1,thumbH,active and t.accent or colors.lightGray)
      self:addButton('scroll:track:'..win.id,win.x+win.w-1,trackTop,1,trackH,function()
        win.scroll=math.min(maxScroll,win.scroll+math.max(1,bodyH-2))
      end)
    end

    if not win.maximized then
      draw.text(target,win.x+win.w-1,win.y+win.h-1,'+',colors.white,colors.gray,1)
    end
  end

  function OS:render()
    if self.dialogOpen or not self.active then return end
    local t=self:theme()
    local list=self:workspace()
    if self:renderHijackState() or self:renderUserLock() then return end

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

    -- One-row Windows-like taskbar. Keep the empty surface visually quiet.
    draw.fill(target,1,h,w,1,colors.black)
    draw.button(target,1,h,5,'LINK',colors.white,t.accent)
    self:addButton('wm:start',1,h,5,1,function() self:toggleStartMenu() end)

    local statusW=10
    local rightX=math.max(7,w-statusW+1)
    local taskX=7
    local available=math.max(0,rightX-taskX-1)
    local total=#list
    local labels=prefs.get('taskbar_labels',false)
    local preferred=labels and 9 or 5
    local taskW=total>0 and math.max(4,math.min(preferred,math.floor(available/math.max(1,total)))) or 0
    local shown=0

    for _,win in ipairs(list) do
      if taskW<=0 or taskX+taskW-1>=rightX then break end
      local app=shellui.find(win.id,self:isOperatorUI())
      local label=(app and (app.icon or app.short) or win.id)
      if labels and taskW>=7 and app then label=label..' '..app.short end
      local active=(win.id==self.app and not win.minimized)
      draw.button(target,taskX,h,taskW,label,colors.white,active and t.accent or colors.black)
      self:addButton('wm:task:'..win.id,taskX,h,taskW,1,function()
        if win.id==self.app and not win.minimized then
          win.minimized=true
          self.app='home'
        else
          self:focusWindow(win)
        end
      end)
      taskX=taskX+taskW
      shown=shown+1
    end

    if shown<total and taskX<rightX then
      local hidden=total-shown
      local ow=math.min(4,rightX-taskX)
      draw.button(target,taskX,h,ow,'+'..tostring(hidden),colors.white,colors.black)
      self:addButton('wm:overflow',taskX,h,ow,1,function() self:toggleStartMenu() end)
    end

    local netLabel=self.service.online and 'ON' or 'OFF'
    draw.text(target,rightX,h,netLabel,self.service.online and colors.lime or colors.red,colors.black,3)
    self:addButton('wm:system',rightX,h,3,1,function() self:toggleQuickPanel() end)
    draw.text(target,w-5,h,textutils.formatTime(os.time(),true),colors.white,colors.black,5)
    self:addButton('wm:clock',w-5,h,5,1,function() self:toggleQuickPanel() end)

    if self.notice then
      local nw=math.min(w-2,math.max(12,#tostring(self.notice)+2))
      local nx=math.max(1,w-nw)
      local ny=math.max(1,h-2)
      draw.fill(target,nx,ny,nw,1,colors.black)
      draw.text(target,nx+1,ny,self.notice,self.noticeColour,colors.black,nw-2)
    end

    self:renderShellOverlays(target,{w=w,h=h,mode='standard'})

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
      if not inside(x,y,modal) then self.startMenuOpen,self.quickPanelOpen=false,false;return true end
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
    if event=='key' and (a==keys.leftCtrl or a==keys.rightCtrl) then self.ctrlHeld=true;return true end
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

        local geometry=prefs.get('window_geometry',{})
        geometry[win.id]={x=win.x,y=win.y,w=win.w,h=win.h}
        prefs.set('window_geometry',geometry)
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
    if not self.noteDocument then self:loadNote('/user/notes.txt') end
    local note=self.noteDocument
    if not note then return end
    draw.text(target,2,1,(note.dirty and '* ' or '')..note.path,colors.cyan,colors.black,l.w-3)
    self:button(target,'note:edit',2,3,10,note.editing and 'EDITION' or 'EDITER',function() note.editing=not note.editing end)
    self:button(target,'note:save',13,3,11,'SAUVEGARDER',function() self:saveNote() end)
    draw.text(target,2,5,'Entree: ligne | Ctrl+S: sauver | Esc: fin',colors.lightGray,colors.black,l.w-3)
    local win=self.drawingWindow
    -- A dedicated text page keeps long notes editable without losing the toolbar.
    local page=math.floor((note.row-1)/18)
    for row=page*18+1,math.min(#note.lines,page*18+18) do
      local text=note.lines[row]
      if row==note.row and note.editing then
        local start=math.max(1,note.col-(l.w-6))
        text=text:sub(start,note.col-1)..'|'..text:sub(note.col)
      end
      local y=7+row-page*18-1
      draw.text(target,2,y,text,colors.white,colors.black,l.w-3)
      self:addButton('note:line:'..row,2,y,l.w-3,1,function()
        note.row=row;note.col=#note.lines[row]+1;note.editing=true
      end)
    end
  end

  function OS:renderFiles(target,l)
    local path=self.filePath or '/user'
    local entries,err=self:listFiles(path)
    draw.text(target,2,1,'FICHIERS / '..path,colors.cyan,colors.black,l.w-3)
    local function newName(title)
      local name=self:prompt(title,'Nom simple, sans /, ni \\')
      if name=='' then return nil end
      if name=='.' or name=='..' or name:find('[/\\]') or name:find('[%c]') or #name>60 then
        self:setNotice('Nom invalide.',colors.red);return nil
      end
      local full=fs.combine(path,name)
      if fs.exists(full) then self:setNotice('Ce nom existe deja.',colors.red);return nil end
      return full
    end
    self:button(target,'explorer:parent',2,3,7,'PARENT',function()
      if path~='/user' then self.filePath=fs.getDir(path);self.explorerPage=1 end
    end)
    self:button(target,'explorer:new',10,3,7,'TEXTE',function()
      if self.noteDocument and self.noteDocument.dirty then
        self:setNotice('Sauvegarde le document ouvert avant de creer un autre texte.',colors.orange);return
      end
      local full=newName('Nouveau fichier texte')
      if full and self:loadNote(full) then self.noteDocument.editing=true;self:openApp('notes') end
    end)
    self:button(target,'explorer:folder',18,3,math.min(8,l.w-18),'DOSSIER',function()
      local full=newName('Nouveau dossier');if full then
        local ok,failure=pcall(fs.makeDir,full);if not ok then self:setNotice(tostring(failure),colors.red) end
      end
    end)
    if err then draw.text(target,2,5,err,colors.red,colors.black,l.w-3);return end
    local page=clamp(self.explorerPage or 1,1,math.max(1,math.ceil(#entries/16)))
    self.explorerPage=page
    for i=(page-1)*16+1,math.min(#entries,page*16) do
      local name=entries[i];local full=fs.combine(path,name);local dir=fs.isDir(full)
      local y=5+(i-1)%16
      self:button(target,'explorer:file:'..i,2,y,l.w-3,(dir and '[+] ' or '    ')..name,function()
        if dir then self.filePath=full;self.explorerPage=1
        elseif self.noteDocument and self.noteDocument.dirty then self:setNotice('Sauvegarde le document ouvert avant de changer.',colors.orange)
        elseif self:loadNote(full) then self:openApp('notes') end
      end)
    end
    self:button(target,'explorer:prev',2,23,7,'<',function() self.explorerPage=math.max(1,page-1) end)
    draw.text(target,11,23,'Page '..page,colors.lightGray,colors.black,10)
    self:button(target,'explorer:next',l.w-7,23,7,'>',function() self.explorerPage=math.min(math.max(1,math.ceil(#entries/16)),page+1) end)
  end
  function OS:handleKey(key)
    if self.startMenuOpen then return originalKey(self,key) end
    local list=self:workspace()
    local focused
    for _,win in ipairs(list) do if win.id==self.app and not win.minimized then focused=win end end
    if self.ctrlHeld and focused then
      if key==keys.w then self:closeWindow(focused)
      elseif key==keys.m then focused.minimized=true;self.app='home'
      elseif key==keys.enter then
        if focused.maximized then
          focused.maximized=false
          if focused.restore then focused.x,focused.y,focused.w,focused.h=table.unpack(focused.restore) end
        else focused.restore={focused.x,focused.y,focused.w,focused.h};focused.maximized=true end
      elseif key==keys.left then focused.maximized=false;focused.x=focused.x-1
      elseif key==keys.right then focused.maximized=false;focused.x=focused.x+1
      elseif key==keys.up then focused.maximized=false;focused.y=focused.y-1
      elseif key==keys.down then focused.maximized=false;focused.y=focused.y+1 end
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
      if #list>0 then local win=table.remove(list,1);list[#list+1]=win;self:focusWindow(win) end
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
