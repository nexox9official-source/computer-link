-- Computer Link server policy.
-- Injected into CraftOS ROM by the Astralium server datapack.
return {
  version = 2,

  github_raw = "https://raw.githubusercontent.com/nexox9official-source/computer-link/main/",

  -- Only these Computer IDs may use intrusion tools.
  hack_operator_ids = {
    [1] = true
  },

  -- MER installation is intentionally not exposed to players.
  allow_public_mer_install = false,
  mer_install_ids = {}
}
