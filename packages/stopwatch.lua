-- LinkOS package stopwatch 1.0
return {draw=function(ctx)
  local d=ctx.data
  local elapsed=(d.elapsed or 0)+(d.started and os.clock()-d.started or 0)
  ctx.draw.text(ctx.target,2,2,'CHRONOMETRE',colors.cyan,colors.black,ctx.w-3)
  ctx.draw.text(ctx.target,2,4,string.format('%02d:%02d',math.floor(elapsed/60),math.floor(elapsed%60)),colors.white,colors.black,ctx.w-3)
  ctx.button('chrono:toggle',2,7,13,d.started and 'PAUSE' or 'DEMARRER',function()
    if d.started then d.elapsed=(d.elapsed or 0)+os.clock()-d.started;d.started=nil
    else d.started=os.clock() end
  end)
  ctx.button('chrono:reset',16,7,9,'ZERO',function() d.started=nil;d.elapsed=0 end)
  ctx.draw.text(ctx.target,2,10,'Fermer la fenetre remet le chrono a zero.',colors.lightGray,colors.black,ctx.w-3)
end}
