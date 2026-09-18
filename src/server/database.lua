local config = dofile("/computer-link/src/common/config.lua")
local util = dofile("/computer-link/src/common/util.lua")

local database = {}

local state = {
  schema = 1,
  users = {},
  computers = {},
  inboxes = {}
}

local function normalise()
  state.schema = state.schema or 1
  state.users = state.users or {}
  state.computers = state.computers or {}
  state.inboxes = state.inboxes or {}
end

function database.load()
  util.ensureDir(config.DATA_DIR)
  state = util.loadTable(config.DATABASE_FILE, state)
  normalise()
  return state
end

function database.save()
  normalise()
  return util.saveTable(config.DATABASE_FILE, state)
end

function database.get()
  return state
end

function database.usernameForComputer(computerId)
  return state.computers[tostring(computerId)]
end

function database.getUser(username)
  return state.users[username]
end

function database.register(computerId, username)
  local valid
  valid, username = util.validUsername(username, config.USERNAME_MIN, config.USERNAME_MAX)

  if not valid then
    return false, "Pseudo invalide: " .. config.USERNAME_MIN .. "-" .. config.USERNAME_MAX .. " caracteres, lettres/chiffres/_/-."
  end

  local bound = database.usernameForComputer(computerId)
  if bound then
    if bound == username then
      return true, "Ce PC est deja enregistre sous " .. username .. "."
    end
    return false, "Ce PC est deja lie au compte " .. bound .. "."
  end

  if state.users[username] then
    return false, "Ce pseudo est deja utilise."
  end

  state.users[username] = {
    username = username,
    computer_id = computerId,
    created_at = util.now(),
    last_seen = util.now()
  }

  state.computers[tostring(computerId)] = username
  state.inboxes[username] = state.inboxes[username] or {}

  database.save()
  return true, "Compte " .. username .. " cree."
end

function database.touch(computerId)
  local username = database.usernameForComputer(computerId)
  if username and state.users[username] then
    state.users[username].last_seen = util.now()
  end
  return username
end

function database.listUsers()
  local users = {}

  for username, user in pairs(state.users) do
    users[#users + 1] = {
      username = username,
      computer_id = user.computer_id,
      last_seen = user.last_seen
    }
  end

  table.sort(users, function(a, b)
    return string.lower(a.username) < string.lower(b.username)
  end)

  return users
end

function database.pushMessage(fromUser, toUser, message)
  state.inboxes[toUser] = state.inboxes[toUser] or {}

  local entry = {
    from = fromUser,
    to = toUser,
    message = message,
    sent_at = util.now()
  }

  state.inboxes[toUser][#state.inboxes[toUser] + 1] = entry
  database.save()

  return entry
end

function database.takeInbox(username)
  local messages = state.inboxes[username] or {}
  state.inboxes[username] = {}
  database.save()
  return messages
end

return database
