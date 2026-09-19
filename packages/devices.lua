-- LinkOS package devices 1.0
-- Read-only inspection of peripherals attached to this computer.
return {draw=function(ctx)
  ctx.draw.text(ctx.target,2,2,'PERIPHERIQUES LOCAUX',colors.cyan,colors.black,ctx.w-3)
  local names=peripheral.getNames();table.sort(names)
  if ctx.data.selected then
    ctx.button('devices:back',2,4,12,'< RETOUR',function() ctx.data.selected=nil;ctx.data.page=1 end)
    local name=ctx.data.selected
    ctx.draw.text(ctx.target,2,6,name,colors.white,colors.black,ctx.w-3)
    local ok,items=pcall(peripheral.call,name,'list')
    if not ok or type(items)~='table' then
      ctx.draw.text(ctx.target,2,8,'Pas un inventaire accessible.',colors.lightGray,colors.black,ctx.w-3)
      return
    end
    local sorted={}
    for slot,item in pairs(items) do sorted[#sorted+1]={slot=slot,item=item} end
    table.sort(sorted,function(a,b) return a.slot<b.slot end)
    local pages=math.max(1,math.ceil(#sorted/14))
    local page=math.min(ctx.data.page or 1,pages)
    for i=(page-1)*14+1,math.min(#sorted,page*14) do
      local row=sorted[i]
      ctx.draw.text(ctx.target,2,8+(i-1)%14,tostring(row.slot)..' '..tostring(row.item.count)..'x '..tostring(row.item.name),colors.white,colors.black,ctx.w-3)
    end
    ctx.button('devices:prev',2,24,6,'<',function() ctx.data.page=math.max(1,page-1) end)
    ctx.draw.text(ctx.target,10,24,page..'/'..pages,colors.white,colors.black,8)
    ctx.button('devices:next',20,24,6,'>',function() ctx.data.page=math.min(pages,page+1) end)
    return
  end
  if #names==0 then ctx.draw.text(ctx.target,2,5,'Aucun appareil connecte.',colors.lightGray,colors.black,ctx.w-3) end
  local pages=math.max(1,math.ceil(#names/16));local page=math.min(ctx.data.page or 1,pages)
  for i=(page-1)*16+1,math.min(#names,page*16) do
    local name=names[i]
    ctx.button('devices:'..name,2,5+(i-1)%16,ctx.w-3,name..' / '..tostring(peripheral.getType(name)),function()
      ctx.data.selected=name;ctx.data.page=1
    end)
  end
  ctx.button('devices:prev',2,24,6,'<',function() ctx.data.page=math.max(1,page-1) end)
  ctx.draw.text(ctx.target,10,24,page..'/'..pages,colors.white,colors.black,8)
  ctx.button('devices:next',20,24,6,'>',function() ctx.data.page=math.min(pages,page+1) end)
end}
