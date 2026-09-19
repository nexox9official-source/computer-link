-- Malcraft Bridge service transport tests.
-- Ensures Bridge mode does not require or fall through to rednet.

colors={red=1}
local rednetCalls=0
rednet={
  send=function()
    rednetCalls=rednetCalls+1
    error("rednet must not be used while Malcraft Bridge is authoritative")
  end
}

local fakeConfig={
  VERSION="0.18.0",
  GITHUB_RAW="",
  HACK_PROTOCOL="astralnet.hack.v1",
  PROTOCOL="astralnet.link.v2"
}
local fakeUtil={
  now=function() return 1 end,
  requestId=function() return "req-test" end,
  trim=function(v) return tostring(v or "") end
}
local fakeNetwork={
  open=function() return false,"Modem absent" end,
  findServer=function() return nil end,
  packet=function(kind,payload,id) return {type=kind,payload=payload,request_id=id} end,
  isPacket=function() return false end
}
local fakeStorage={
  load=function() end,
  conversation=function() return {} end,
  recent=function() return {} end,
  add=function() return false end
}
local fakeHack={
  openChannel=function() end,
  handleRednet=function() return false end,
  handleModem=function() return false end,
  isOperator=function() return true end
}

local originalDofile=dofile
local map={
  ["/computer-link/src/common/config.lua"]=fakeConfig,
  ["/computer-link/src/common/util.lua"]=fakeUtil,
  ["/computer-link/src/common/network.lua"]=fakeNetwork,
  ["/computer-link/src/client/storage.lua"]=fakeStorage,
  ["/computer-link/src/client/remote_control.lua"]=fakeHack
}

local env=setmetatable({
  dofile=function(path)
    if map[path] then return map[path] end
    return originalDofile(path)
  end,
  malcraft_bus={
    version=function() return "0.11.0" end,
    listInfected=function() return "infected-list" end,
    listComputers=function() return "live-list" end,
    send=function() return false end
  },
  textutils={
    unserializeJSON=function(raw)
      if raw=="live-list" then
        return {computers={{computer_id=9,label="ROM PC",infected=false}}}
      elseif raw=="infected-list" then
        return {hosts={}}
      end
      return {}
    end,
    serializeJSON=function() return "{}" end
  },
  os=setmetatable({
    getComputerID=function() return 0 end,
    getComputerLabel=function() return "OPERATOR" end,
    setComputerLabel=function() end,
    startTimer=function() return 1 end
  },{__index=os}),
  rednet=rednet
},{__index=_G})

local source=assert(io.open("src/client/service.lua")):read("*a")
local Service=assert(load(source,"@service.lua","t",env))()
local service=Service.new()

assert(service.bridgeAvailable==true)

local computers,err=service:ghostLiveComputers()
assert(not err)
assert(#computers==1 and computers[1].computer_id==9)

local result,remoteErr=service:ghostRemote(9,"status")
assert(result==nil)
assert(tostring(remoteErr):find("Malcraft Bridge",1,true))
assert(rednetCalls==0,"Bridge failure incorrectly fell through to rednet")

local ok,startErr=service:start()
assert(ok==false)
assert(service.bridgeAvailable==true)
assert(tostring(startErr):find("Malcraft Bridge disponible",1,true))
assert(rednetCalls==0)

print("PASS: Malcraft Bridge transport works without rednet fallback")
