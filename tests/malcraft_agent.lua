-- Offline state-machine tests for the ROM Malcraft agent.
-- These scenarios execute ghostlinkd.lua in one-shot mode without LinkOS.

local function runCase(opts)
  local saved = {
    ["astralium.malcraft.infected"] = opts.local_infected == true,
    ["astralium.malcraft.spread"] = opts.local_spread == true,
    ["astralium.malcraft.source"] = opts.local_source,
    ["astralium.malcraft.clean_lock"] = opts.clean_lock == true
  }
  local calls = {infect=0, heartbeat=0, ack=0}
  local marker = opts.carrier == true
  local diskContent = "ASTRALIUM_MALCRAFT_CARRIER_V1\ndisk=7\nsource=99\n"

  local env = {}
  setmetatable(env,{__index=_G})

  env.settings = {
    get=function(k,default)
      local v=saved[k]
      if v==nil then return default end
      return v
    end,
    set=function(k,v) saved[k]=v end,
    unset=function(k) saved[k]=nil end,
    save=function() return true end
  }

  env.textutils = {
    unserializeJSON=function(raw)
      if raw=="clean" then return {known=true,infected=false,spread=false,source="cleaned"} end
      if raw=="infected" then return {known=true,infected=true,spread=true,source="bridge"} end
      if raw=="unknown" then return {known=false,infected=false,spread=false} end
      return nil
    end,
    serializeJSON=function() return "{}" end
  }

  env.require=function(name)
    if name=="computer_link_policy" then
      return {
        hack_operator_ids={[0]=true},
        ghostlink_immune_ids={[0]=true},
        ghostlink_proximity_spread=false,
        malcraft_auto_infect_disks=false,
        malcraft_operator_proximity_emitter=false
      }
    end
    error("unexpected require "..tostring(name))
  end

  env.os = setmetatable({
    getComputerID=function() return 42 end,
    getComputerLabel=function() return "ROM-ONLY-TEST" end,
    time=function() return 12 end,
    clock=function() return 1 end,
    epoch=function() return 1000 end,
    startTimer=function() return 1 end,
    queueEvent=function() end,
    pullEvent=function() error("one-shot should not wait for events") end
  },{__index=os})

  env.peripheral = {
    getNames=function() return marker and {"left"} or {} end,
    getType=function(name) return name=="left" and "drive" or nil end,
    wrap=function() return nil end,
    isPresent=function(name) return marker and name=="left" end,
    getMethods=function() return {} end
  }

  env.disk = {
    isPresent=function() return marker end,
    hasData=function() return marker end,
    getID=function() return 7 end,
    getMountPath=function() return "disk" end,
    getLabel=function() return "CARRIER" end
  }

  env.fs = {
    combine=function(a,b)
      if a=="" then return b end
      if a:sub(-1)=="/" then return a..b end
      return a.."/"..b
    end,
    exists=function(path)
      if path=="disk/.malcraft/carrier.dat" then return marker end
      if path=="/computer-link" then return false end
      return false
    end,
    isDir=function() return false end,
    makeDir=function() end,
    open=function(path,mode)
      if path=="disk/.malcraft/carrier.dat" and mode=="r" and marker then
        return {readAll=function() return diskContent end,close=function() end}
      end
      return nil
    end
  }

  env.rednet = {
    isOpen=function() return false end,
    open=function() end,
    lookup=function() return nil end
  }

  env.malcraft_bus = {
    state=function() return opts.bridge_state or "unknown" end,
    infectSelf=function(source)
      calls.infect=calls.infect+1
      calls.infect_source=source
      return true
    end,
    heartbeat=function(spread,source)
      calls.heartbeat=calls.heartbeat+1
      calls.heartbeat_spread=spread
      calls.heartbeat_source=source
      return true
    end,
    acknowledgeClean=function()
      calls.ack=calls.ack+1
      return true
    end
  }

  local chunk=assert(loadfile(
    "server-datapack/data/computercraft/lua/rom/programs/ghostlinkd.lua",
    "t",
    env
  ))
  chunk("--oneshot")
  return saved,calls
end

-- Remote clean while target was offline, no carrier: local state is cleaned
-- and the tombstone can be acknowledged immediately.
do
  local state,calls=runCase{
    bridge_state="clean",
    local_infected=true,
    local_spread=true
  }
  assert(state["astralium.malcraft.infected"]==false)
  assert(state["astralium.malcraft.spread"]==false)
  assert(calls.infect==0)
  assert(calls.ack==1)
  assert(state["astralium.malcraft.clean_lock"]==nil)
end

-- Remote clean while a contaminated disk is still inserted: the bridge clean
-- wins, no reinfection is accepted, and the tombstone remains until removal.
do
  local state,calls=runCase{
    bridge_state="clean",
    carrier=true,
    local_infected=true,
    local_spread=true
  }
  assert(state["astralium.malcraft.infected"]==false)
  assert(calls.infect==0)
  assert(calls.ack==0)
  assert(state["astralium.malcraft.clean_lock"]==true)
end

-- Unknown host + carrier is a first/new infection, even without LinkOS.
do
  local state,calls=runCase{
    bridge_state="unknown",
    carrier=true,
    local_infected=false
  }
  assert(state["astralium.malcraft.infected"]==true)
  assert(state["astralium.malcraft.spread"]==true)
  assert(calls.infect>=1)
  assert(tostring(calls.infect_source):match("^disk:7"))
end

-- Persistent server-side infection restores a ROM-only Computer after boot.
do
  local state,calls=runCase{
    bridge_state="infected",
    local_infected=false
  }
  assert(state["astralium.malcraft.infected"]==true)
  assert(state["astralium.malcraft.spread"]==true)
  assert(calls.heartbeat==1)
  assert(calls.infect==0)
end

print("PASS: Malcraft ROM clean/carrier/restore state machine")
