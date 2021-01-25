-- this shall provide some useful commands
--[[
  include("NAME DES RELATIVEN DATEIPFADES") -- einfügen von abhängigkeiten

  isValid()

  ply: (https://github.com/Facepunch/garrysmod/blob/master/garrysmod/gamemodes/terrortown/gamemode/player.lua)
  (https://github.com/Facepunch/garrysmod/blob/master/garrysmod/gamemodes/terrortown/gamemode/player_ext_shd.lua)
  :GetPos()  --
  :GetCredits() -- credits from the player
  :GetEquipmentItems() -- items from the player
  :GetMaxHealth()
  :Health()
  :IsPlayer()  -- KA wo ich das her hab
  :IsActive() -- Spieler noch am Leben?
  :IsTerror() -- Im Spiel?
  :IsSpec() -- Im Spectator
  :IsActiveDetective()
  :IsTraitor()
  :IsDeadTerror()
  :GetVelocity()

  ragdolls:
  rag.player_ragdoll : bool -- true if player ragdoll else false


  util.GetAlivePlayers() -- Alle lebenden Players

  Helper:
  WEPS.TypeForWeapon(wep:GetClass()) == weptype
  

  Eigenene Hooks Können mit:
  hook.Run("HOOK_NAME", parameter...)

  ENT:
  :Initalize() -- Konstruktor funktionen???
  self:Function() -- selbst aufruf
  ]]