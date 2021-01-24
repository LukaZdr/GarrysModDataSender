FILE_PATH = "data_collector/storage.txt"
FOLDER_NAME = "data_collector"
players_alive = {}

function Initialize() -- creates a data_collector directory on server start if there is none
  if not file.IsDir(FOLDER_NAME, "DATA") then
    file.CreateDir(FOLDER_NAME, "DATA")
  end
  if not file.Exists(FILE_PATH, "DATA") then
    file.Write(FILE_PATH, "// Initial Row // \n")
  end
end

function ServerStart() -- saves server starting information
  local action = 'server_start'
  local action_table = {
    ['action'] = action,
    ['time'] = os.time()
  }
  add_table_to_file(action_table)
end

function PlayerJoin(ply) -- saves player join information
  local action = 'player_join'
  local user_info = extract_player_table(ply)
  local action_table = {
    ['action'] = action,
    ['user'] = user_info,
    ['time'] = os.time()
  }
  add_table_to_file(action_table)
end

function WeaponPickedUp(weapon, ply)
  local action = 'weapon_pickup'
  local weapon_info = extract_equipment_table(weapon)
  local action_table = {
    ['action'] = action,
    ['user_steam_id'] = ply:SteamID(),
    ['weapon'] = weapon_info,
    ['time'] = os.time()
  }
  add_table_to_file(action_table)
end

function RoundBegin()
  players_alive = player.GetAll()
  local action = 'round_start'
  players = {}
  for _, ply in pairs(players_alive) do
    if ply:Team() == TEAM_SPECTATOR then
      role = 'spectator' -- spectator roles are also innocent thats the wroason for this workaround
    else
      role = ply:GetRoleString()
    end
    local user = {
      ['user_steam_id'] = ply:SteamID(),
      ['karma'] = ply:GetLiveKarma(),
      ['role'] = role
    }
    players = table.ForceInsert(players, user)
  end

  local action_table = {
    ['action'] = action,
    ['time'] = os.time(),
    ['players'] = players,
    ['map'] = game.GetMap()
  }
  add_table_to_file(action_table)
end

function RoundEnd(result)
  local action = 'round_end'
  win_reason = ''
  if result == WIN_TRAITOR then
    win_reason = 'win_traitor'
  elseif result == WIN_INNOCENT then
    win_reason = 'win_innocent'
  else
    win_reason = 'win_timelimit'
  end
  local action_table = {
    ['action'] = action,
    ['time'] = os.time(),
    ['result'] = win_reason
  }
  add_table_to_file(action_table)
end

function EquipmentBought(ply, equipment, is_item)
  local action = 'equipment_bought'
  -- local user_info = extract_player_table(ply)
  local equipment_info = {
    ['name'] = equipment, -- returns class_name if weapon || returns id if equipment
    ['role'] = ply:GetRoleString()
  }
  local action_table = {
    ['action'] = action,
    ['user_steam_id'] = ply:SteamID(),
    ['equipment'] = equipment_info,
    ['is_item'] = is_item       -- returns equipment_id if eqipment || returns nil if weapon
  }
  add_table_to_file(action_table)
end

function CorpseSearch(ply, corpse, is_covert, is_long_range, was_traitor)
  local action = 'corpse_searched'
  local action_table = {
    ['action'] = action,
    ['user_steam_id'] = ply:SteamID(),
    ['corpse_steam_id'] = corpse.sid,
    ['is_covert'] = is_covert,
    ['is_long_range'] = is_long_range,
    ['was_traitor'] = was_traitor
  }
  add_table_to_file(action_table)
end

function FoundDNA(ply, dna_owner, ent)
  local action = 'found_dna'
  local action_table = {
    ['action'] = action,
    ['user_steam_id'] = ply:SteamID(),
    ['suspect_steam_id'] = dna_owner:SteamID(),
  }
  add_table_to_file(action_table)
end

gameevent.Listen('player_disconnect')
hook.Add( 'player_disconnect', 'player_disconnect_example', function(data)
  local action = 'player_disconnect'
  local user = {
    ['steam_id'] = data.networkid,
    ['name'] =  data.name,
    ['reason'] =  data.reason,
    ['user_id'] =  data.userid,
    ['bot'] = data.bot
  }
  local action_table = {
    ['action'] = action,
    ['user'] =  user,
    ['time'] = os.time()
  }
  add_table_to_file(action_table)
end )

gameevent.Listen( "player_hurt" )
hook.Add( "player_hurt", "player_hurt", function(data)
  local action = 'player_hurt'
  local user = {
    ['health'] = data.health,
    ['user_id'] = data.userid, -- Same as Player:UserID()
    ['attacker_id'] = data.attacker -- Same as Player:UserID()
  }
  local action_table = {
    ['action'] = action,
    ['user'] =  user,
    ['time'] = os.time()
  }
  add_table_to_file(action_table)
end )

hook.Add( "EntityTakeDamage", "EntityDamageExample2", function(target, dmginfo )
  -- test with mineturtels and stuff
  -- check if player == target
  -- determine damgage inflictor, if possible inflictor user
  -- handle case where damage inflictor != user
  -- get user.health information
  print(target)
  print(dmginfo:GetInflictor())
  print(util.WeaponFromDamage(dmginfo))



  -- local user = {
  --   ['weapon_index'] = ents.GetByIndex(data.entindex_inflictor),
  --   ['attacker_index'] = ents.GetByIndex(data.entindex_attacker):Name(), -- data.entindex_attacker
  --   ['damagebits'] = data.damagebits,
  --   ['victim_index'] = ents.GetByIndex(data.entindex_killed):Name() -- data.entindex_killed
  -- }
  -- local action_table = {
  --   ['action'] = action,
  --   ['user'] =  user,
  --   ['time'] = os.time()
  -- }
  -- add_table_to_file(action_table)
end )

-- //////   [ hooks ]   //////
hook.Add('Initialize', 'InitializeFile', Initialize)
hook.Add('Initialize', 'ServerStart', ServerStart)
hook.Add('PlayerInitialSpawn', 'PlayerJoin', PlayerJoin)
hook.Add('WeaponEquip', 'WeaponEquipExample', WeaponPickedUp)
hook.Add('TTTBeginRound', 'round_begin', RoundBegin)
hook.Add('TTTEndRound', 'round_end', RoundEnd)
hook.Add('TTTOrderedEquipment', 'equipment_bought', EquipmentBought)
hook.Add('TTTCanSearchCorpse', 'corpse_searched', CorpseSearch)
hook.Add('TTTFoundDNA', 'found_dna', FoundDNA)

-- //////   [helpers]   //////

function add_table_to_file(table)
  local json = util.TableToJSON(table)
  local string = json .. '\n'
  file.Append(FILE_PATH, string)
end

function extract_player_table(ply)
  local user_info = {
    ['steam_id'] = ply:SteamID(),
    ['name'] =  ply:GetName(),
    ['bot'] = ply:IsBot(),
    ['user_id'] = ply:UserID()
  }
  return user_info
end

function extract_equipment_table(equip)
  local equipment_info = {
    ['name'] = equip:GetClass(),
    ['index'] = equip:EntIndex()
  }
  return equipment_info
end



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

  ragdolls:
  rag.player_ragdoll : bool -- true if player ragdoll else false


  Eigenene Hooks Können mit:
  hook.Run("HOOK_NAME", parameter...)

  ENT:
  :Initalize() -- Konstruktor funktionen???
  self:Function() -- selbst aufruf
  ]]