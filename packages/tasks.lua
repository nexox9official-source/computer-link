-- LinkOS package tasks 1.1
local ui=dofile('/computer-link/src/ui/fluent.lua')
local path='/user/tasks.db'
local function save(items)
  local f=assert(fs.open(path,'w'),'Sauvegarde impossible')
  f.write(textutils.serialize(items));f.close()
end
return {draw=function(ctx)
  local d=ctx.data
  local t=ctx.theme or ui.theme('blue')
  if not d.items then
    d.items={}
    if fs.exists(path) then
      local f=fs.open(path,'r')
      if f then
        local ok,v=pcall(textutils.unserialize,f.readAll());f.close()
        if ok and type(v)=='table' then
          for _,item in ipairs(v) do
            if type(item)=='table' and type(item.text)=='string' then d.items[#d.items+1]=item end
          end
        end
      end
    end
  end
  ui.sectionTitle(ctx.target,2,2,ctx.w-3,'Mes taches','Checklist personnelle',t.accent)
  ctx.button('tasks:add',math.max(2,ctx.w-13),2,12,'+ AJOUTER',function()
    local text=ctx.prompt('Nouvelle tache','Sauvegardee dans /user/tasks.db')
    if text and text~='' then d.items[#d.items+1]={text=text,done=false};save(d.items) end
  end)
  local page=d.page or 1
  local count=8
  local pages=math.max(1,math.ceil(#d.items/count))
  page=math.min(page,pages);d.page=page
  if #d.items==0 then
    ui.card(ctx.target,2,6,ctx.w-3,5,{bg=t.surface,accent=t.muted,title='Aucune tache',
      subtitle='Ajoute une tache pour commencer.',muted=t.muted})
  else
    local y=6
    for i=(page-1)*count+1,math.min(#d.items,page*count) do
      local item=d.items[i]
      local bg=item.done and t.surface2 or t.surface
      ctx.draw.fill(ctx.target,2,y,ctx.w-3,2,bg)
      ctx.draw.text(ctx.target,3,y,item.done and '[v]' or '[ ]',
        item.done and t.good or t.accent,bg,3)
      ctx.draw.text(ctx.target,7,y,item.text,item.done and t.muted or t.text,bg,math.max(1,ctx.w-9))
      ctx.draw.text(ctx.target,7,y+1,item.done and 'Terminee' or 'A faire',t.muted,bg,math.max(1,ctx.w-9))
      ctx.button('tasks:'..i,2,y,ctx.w-3,item.done and '  [v]  '..item.text or '  [ ]  '..item.text,function()
        item.done=not item.done;save(d.items)
      end)
      y=y+2
    end
  end
  ctx.button('tasks:prev',2,24,6,'<',function() d.page=math.max(1,page-1) end)
  ctx.draw.text(ctx.target,10,24,page..' / '..pages,t.muted,t.bg,8)
  ctx.button('tasks:next',20,24,6,'>',function() d.page=math.min(pages,page+1) end)
end}