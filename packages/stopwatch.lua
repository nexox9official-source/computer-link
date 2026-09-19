-- LinkOS package stopwatch 1.1
local ui=dofile('/computer-link/src/ui/fluent.lua')
return {draw=function(ctx)
  local d=ctx.data
  local t=ctx.theme or ui.theme('blue')
  local elapsed=(d.elapsed or 0)+(d.started and os.clock()-d.started or 0)
  ui.sectionTitle(ctx.target,2,2,ctx.w-3,'Chronometre','Temps ecoule',t.accent)
  ui.card(ctx.target,2,6,ctx.w-3,7,{bg=t.surface,accent=d.started and t.good or t.accent,
    title=d.started and 'En cours' or 'En pause',subtitle='Chronometre LinkOS',muted=t.muted})
  local value=string.format('%02d:%02d',math.floor(elapsed/60),math.floor(elapsed%60))
  ctx.draw.text(ctx.target,math.max(4,math.floor((ctx.w-#value)/2)),9,value,t.text,t.surface,#value)
  ctx.button('chrono:toggle',2,15,13,d.started and 'PAUSE' or 'DEMARRER',function()
    if d.started then d.elapsed=(d.elapsed or 0)+os.clock()-d.started;d.started=nil
    else d.started=os.clock() end
  end)
  ctx.button('chrono:reset',16,15,9,'ZERO',function() d.started=nil;d.elapsed=0 end)
  ctx.draw.text(ctx.target,2,18,'La session du chrono appartient a cette fenetre.',t.muted,t.bg,ctx.w-3)
end}