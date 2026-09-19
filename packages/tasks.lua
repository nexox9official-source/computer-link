-- LinkOS package tasks 1.0
local path='/user/tasks.db'
local function save(items)
  local f=assert(fs.open(path,'w'),'Sauvegarde impossible')
  f.write(textutils.serialize(items));f.close()
end
return {draw=function(ctx)
  local d=ctx.data
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
  ctx.draw.text(ctx.target,2,2,'MES TACHES',colors.cyan,colors.black,ctx.w-3)
  ctx.button('tasks:add',2,4,12,'+ AJOUTER',function()
    local text=ctx.prompt('Nouvelle tache','Sauvegardee dans /user/tasks.db')
    if text~='' then d.items[#d.items+1]={text=text,done=false};save(d.items) end
  end)
  local page=d.page or 1
  local count=8
  local pages=math.max(1,math.ceil(#d.items/count))
  page=math.min(page,pages);d.page=page
  for i=(page-1)*count+1,math.min(#d.items,page*count) do
    local item=d.items[i]
    ctx.button('tasks:'..i,2,6+(i-1)%count*2,ctx.w-3,(item.done and '[x] ' or '[ ] ')..item.text,function()
      item.done=not item.done;save(d.items)
    end)
  end
  ctx.button('tasks:prev',2,23,6,'<',function() d.page=math.max(1,page-1) end)
  ctx.draw.text(ctx.target,10,23,page..'/'..pages,colors.white,colors.black,6)
  ctx.button('tasks:next',18,23,6,'>',function() d.page=math.min(pages,page+1) end)
end}
