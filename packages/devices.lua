-- LinkOS package devices 1.1
local ui=dofile('/computer-link/src/ui/fluent.lua')
return {draw=function(ctx)
  local t=ctx.theme or ui.theme('blue')
  ui.sectionTitle(ctx.target,2,2,ctx.w-3,'Peripheriques','Materiel connecte au Computer',t.accent)
  local names=peripheral.getNames();table.sort(names)
  if ctx.data.selected then
    local name=ctx.data.selected
    ctx.button('devices:back',2,5,10,'< RETOUR',function() ctx.data.selected=nil;ctx.data.page=1 end)
    ui.card(ctx.target,2,7,ctx.w-3,4,{bg=t.surface,accent=t.accent,title=name,
      subtitle=tostring(peripheral.getType(name) or 'Peripherique'),muted=t.muted})
    local ok,items=pcall(peripheral.call,name,'list')
    if not ok or type(items)~='table' then
      ctx.draw.text(ctx.target,3,13,'Pas un inventaire accessible.',t.muted,t.bg,ctx.w-5)
      return
    end
    local sorted={}
    for slot,item in pairs(items) do sorted[#sorted+1]={slot=slot,item=item} end
    table.sort(sorted,function(a,b) return a.slot<b.slot end)
    local pages=math.max(1,math.ceil(#sorted/10))
    local page=math.min(ctx.data.page or 1,pages)
    local y=13
    for i=(page-1)*10+1,math.min(#sorted,page*10) do
      local row=sorted[i]
      ctx.draw.fill(ctx.target,2,y,ctx.w-3,1,t.surface2)
      ctx.draw.text(ctx.target,3,y,tostring(row.slot),t.accent,t.surface2,3)
      ctx.draw.text(ctx.target,7,y,tostring(row.item.count)..'x '..tostring(row.item.name),t.text,t.surface2,ctx.w-9)
      y=y+1
    end
    ctx.button('devices:prev',2,25,6,'<',function() ctx.data.page=math.max(1,page-1) end)
    ctx.draw.text(ctx.target,10,25,page..' / '..pages,t.muted,t.bg,8)
    ctx.button('devices:next',20,25,6,'>',function() ctx.data.page=math.min(pages,page+1) end)
    return
  end
  if #names==0 then
    ui.card(ctx.target,2,6,ctx.w-3,5,{bg=t.surface,accent=t.muted,title='Aucun peripherique',
      subtitle='Connecte un modem, drive, inventory ou autre appareil.',muted=t.muted})
    return
  end
  local pages=math.max(1,math.ceil(#names/10));local page=math.min(ctx.data.page or 1,pages)
  local y=6
  for i=(page-1)*10+1,math.min(#names,page*10) do
    local name=names[i]
    ctx.draw.fill(ctx.target,2,y,ctx.w-3,2,t.surface)
    ctx.draw.text(ctx.target,3,y,name,t.text,t.surface,ctx.w-5)
    ctx.draw.text(ctx.target,3,y+1,tostring(peripheral.getType(name)),t.muted,t.surface,ctx.w-5)
    local id='devices:'..name
    ctx.button(id,2,y,ctx.w-3,name..' / '..tostring(peripheral.getType(name)),function()
      ctx.data.selected=name;ctx.data.page=1
    end)
    y=y+2
  end
  ctx.button('devices:prev',2,27,6,'<',function() ctx.data.page=math.max(1,page-1) end)
  ctx.draw.text(ctx.target,10,27,page..' / '..pages,t.muted,t.bg,8)
  ctx.button('devices:next',20,27,6,'>',function() ctx.data.page=math.min(pages,page+1) end)
end}