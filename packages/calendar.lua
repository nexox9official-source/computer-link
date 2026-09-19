-- LinkOS package calendar 1.1
local ui=dofile('/computer-link/src/ui/fluent.lua')
return {draw=function(ctx)
  local t=ctx.theme or ui.theme('blue')
  local day=os.day and os.day() or nil
  local time=textutils.formatTime(os.time(),true)
  ui.sectionTitle(ctx.target,2,2,ctx.w-3,'Calendrier','Temps du monde Minecraft',t.accent)
  ui.card(ctx.target,2,6,ctx.w-3,6,{bg=t.surface,accent=t.accent,title='Heure',
    subtitle='Mise a jour au prochain rafraichissement.',muted=t.muted})
  ctx.draw.text(ctx.target,4,9,time,t.text,t.surface,math.max(1,ctx.w-7))
  if day then
    ui.card(ctx.target,2,14,ctx.w-3,5,{bg=t.surface,accent=t.accent,title='Jour Minecraft',
      subtitle='Jour actuel du monde',muted=t.muted})
    ctx.draw.text(ctx.target,4,17,tostring(day),t.text,t.surface,math.max(1,ctx.w-7))
  end
end}