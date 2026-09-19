-- Official LinkOS application catalogue. Installing never executes the download.
local M = {}
local ROOT = '/computer-link/apps/'
local BASE = 'https://raw.githubusercontent.com/nexox9official-source/computer-link/main/packages/'
M.catalog = {
  {id='tasks',title='Mes taches',version='1.0',description='Checklist personnelle sauvegardee.'},
  {id='stopwatch',title='Chronometre',version='1.0',description='Chrono avec pause et remise a zero.'},
  {id='units',title='Convertisseur',version='1.0',description='Distance, temperature et temps.'},
  {id='devices',title='Peripheriques',version='1.0',description='Inspecter les appareils et inventaires.'}
}
function M.find(id)
  for _,p in ipairs(M.catalog) do if p.id==id then return p end end
end
function M.path(id)
  assert(M.find(id),'Application inconnue')
  return ROOT..id..'.lua'
end
function M.installed(id) return fs.exists(M.path(id)) end
function M.install(id)
  local p=M.find(id)
  if not p then return false,'Application inconnue' end
  if not http or not http.get then return false,'HTTP indisponible' end
  local ok,response,err=pcall(http.get,BASE..id..'.lua')
  if not ok or not response then return false,tostring(err or response or 'Reseau indisponible') end
  local readOK,source=pcall(response.read,65537)
  pcall(response.close)
  if not readOK or type(source)~='string' or #source>65536 then return false,'Paquet invalide ou trop volumineux' end
  if not load(source,'@package:'..id,'t',{}) then return false,'Syntaxe Lua invalide' end
  if not source:find('-- LinkOS package '..id..' '..p.version,1,true) then return false,'Version du paquet incompatible' end
  local path=M.path(id)
  local success,failure=pcall(function()
    fs.makeDir(ROOT)
    local temp=path..'.download'
    local f=assert(fs.open(temp,'w'),'Ecriture impossible')
    f.write(source); f.close()
    if fs.exists(path) then
      -- Keep the previous working version; never delete user data.
      local backup=path..'.backup'
      if fs.exists(backup) then fs.delete(backup) end
      fs.move(path,backup)
    end
    local moved,moveErr=pcall(fs.move,temp,path)
    if not moved then
      if fs.exists(path..'.backup') and not fs.exists(path) then fs.move(path..'.backup',path) end
      error(moveErr)
    end
  end)
  return success,success and 'Application installee' or tostring(failure)
end
function M.remove(id)
  local path=M.path(id)
  if not fs.exists(path) then return true end
  -- Recoverable removal. Personal documents are untouched.
  local removed=path..'.removed'
  if fs.exists(removed) then return false,'Une copie retiree existe deja : reinstaller ou gerer les fichiers.' end
  return pcall(fs.move,path,removed)
end
return M
