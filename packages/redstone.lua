-- LinkOS package redstone 1.1
local ui=dofile('/computer-link/src/ui/fluent.lua')
return {draw=function(ctx)
  local t=ui.theme('blue')
  ui.sectionTitle(ctx.target,2,2,ctx.w-3,'Redstone','Entrees et sorties locales',t.accent)
  if not redstone or not redstone.getSides then
    ui.card(ctx.target,2,6,ctx.w-3,5,{bg=t.surface,accent=t.warn,title='API indisponible',
      subtitle='Redstone n est pas accessible sur ce Computer.',muted=t.muted})
    return
  end
  local sides=redstone.getSides()
  local y=6
  for _,side in ipairs(sides) do
    local output=redstone.getOutput(side)
    local input=redstone.getInput(side)
    local bg=t.surface
    ctx.draw.fill(ctx.target,2,y,ctx.w-3,3,bg)
    ctx.draw.text(ctx.target,3,y,string.upper(side),t.text,bg,10)
    ctx.draw.text(ctx.target,3,y+1,'Entree '..(input and 'ON' or 'OFF'),input and t.good or t.muted,bg,12)
    ctx.draw.text(ctx.target,16,y+1,'Sortie '..(output and 'ON' or 'OFF'),output and t.accent or t.muted,bg,12)
    ctx.button('redstone:'..side,math.max(2,ctx.w-12),y,10,output and 'DESACTIVER' or 'ACTIVER',function()
      redstone.setOutput(side,not redstone.getOutput(side))
      ctx.notice('Sortie '..side..' modifiee.')
    end)
    y=y+4
  end
end}