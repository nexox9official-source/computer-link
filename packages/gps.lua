-- LinkOS package gps 1.1
local ui=dofile('/computer-link/src/ui/fluent.lua')
return {draw=function(ctx)
  local d=ctx.data
  local t=ctx.theme or ui.theme('blue')
  ui.sectionTitle(ctx.target,2,2,ctx.w-3,'GPS','Position du Computer',t.accent)
  ctx.button('gps:locate',2,5,12,'LOCALISER',function()
    if not gps or not gps.locate then d.error='API GPS indisponible.';return end
    local x,y,z=gps.locate(2,false)
    if not x then d.error='Aucune tour GPS detectee.';d.pos=nil
    else d.error=nil;d.pos={x=x,y=y,z=z} end
  end)
  if d.pos then
    ui.card(ctx.target,2,8,ctx.w-3,8,{bg=t.surface,accent=t.good,title='Position trouvee',
      subtitle='Coordonnees Minecraft',muted=t.muted})
    ctx.draw.text(ctx.target,4,11,string.format('X   %.1f',d.pos.x),t.text,t.surface,ctx.w-7)
    ctx.draw.text(ctx.target,4,12,string.format('Y   %.1f',d.pos.y),t.text,t.surface,ctx.w-7)
    ctx.draw.text(ctx.target,4,13,string.format('Z   %.1f',d.pos.z),t.text,t.surface,ctx.w-7)
  elseif d.error then
    ui.card(ctx.target,2,8,ctx.w-3,5,{bg=t.surface,accent=t.warn,title='Localisation impossible',
      subtitle=d.error,muted=t.muted})
  else
    ui.card(ctx.target,2,8,ctx.w-3,5,{bg=t.surface,accent=t.accent,title='Pret',
      subtitle='Appuie sur LOCALISER pour obtenir la position.',muted=t.muted})
  end
end}