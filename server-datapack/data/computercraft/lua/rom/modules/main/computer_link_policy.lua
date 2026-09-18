-- Computer Link server policy.
-- Injected into CraftOS ROM by the Astralium server datapack.
return {
  version = 3,

  github_raw = "https://raw.githubusercontent.com/nexox9official-source/computer-link/main/",

  -- Server-side client lockdown. This policy lives in ROM and cannot be edited
  -- from a normal ComputerCraft filesystem.
  lockdown_clients = true,
  require_server_policy = true,

  -- Only these immutable Computer IDs may use LinkSec intrusion tools.
  hack_operator_ids = {
    [0] = true
  },

  -- Computers explicitly forbidden from ever becoming the MER.
  -- PC #0 is the operator workstation, not the central MER.
  deny_mer_ids = {
    [0] = true
  },

  -- Fill this with the real MER Computer ID for absolute MER role enforcement.
  -- Example: [23] = true
  trusted_mer_ids = {},

  -- MER installation is intentionally not exposed to players.
  allow_public_mer_install = false,
  mer_install_ids = {}
}
