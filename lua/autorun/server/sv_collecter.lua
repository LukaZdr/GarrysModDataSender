FILE_PATH = "data_collector/storage.txt"
FOLDER_NAME = "data_collector"

function Initialize() -- creates a data_collector directory on server start if there is none
  if not file.IsDir(FOLDER_NAME, "DATA") then
    file.CreateDir(FOLDER_NAME, "DATA")
  end
  if not file.Exists(FILE_PATH, "DATA") then
    file.Write(FILE_PATH, "// Initial Row // \n")
  end
end

function ServerStart() -- saves server starting information
  action = 'server_start'
  action_table = {
    ['action'] = action,
    ['time'] = os.date()
  }
  add_table_to_file(action_table)
end

function PlayerJoin(ply) -- saves player join information
  action = 'player_join'
  user_info = extract_player_table(ply)
  action_table = {
    ['action'] = action,
    ['user'] = user_info,
    ['time'] = os.date()
  }
  add_table_to_file(action_table)
end

function WeaponPickedUp(weapon, ply)
  action = 'weapon_pickup'
  user_info = extract_player_table(ply)
  weapon_info = extract_equipment_table(weapon)
  action_table = {
    ['action'] = action,
    ['user'] = user_info,
    ['weapon'] = weapon_info,
    ['time'] = os.date()
  }
  add_table_to_file(action_table)
end

function RoundBegin()
  action = 'round_start'
  action_table = {
    ['action'] = action,
    ['time'] = os.time()
  }
  user_roles = {}
  for _, ply in pairs(player.GetAll()) do
    role = ply:GetRoleString()
    if role == 'traitor' then
      user_roles['traitors'] = table.ForceInsert(user_roles['traitors'], ply:SteamID())
    elseif role == 'inocent' then
      user_roles['inocents'] = table.ForceInsert(user_roles['inocents'], ply:SteamID())
    elseif role == 'detective' then
      user_roles['detectives'] = table.ForceInsert(user_roles['detectives'], ply:SteamID())
    end
    print(util.TableToJSON(user_roles))
  end

  add_table_to_file(action_table)
end

function RoundEnd(result)
  print(result)
  action = 'round_end'
  action_table = {
    ['action'] = action,
    ['time'] = os.time(),
    ['result'] = result
  }
  add_table_to_file(action_table)
end

function EquipmentBought(ply, equipment, is_item)
  action = 'equipment_bought'
  user_info = extract_player_table(ply)
  action_table = {
    ['action'] = action,
    ['user'] = user,
    ['equipment'] = equipment,  -- returns class_name if weapon || returns id if equipment
    ['it_item'] = is_item       -- returns equipment_id if eqipment || returns nil if weapon
  }
  add_table_to_file(action_table)
end

function CorpseSearch(ply, corpse, is_covert, is_long_range, was_traitor)
  user_info = extract_player_table(ply)
  -- corpse_info [TODO]
  action_table = {
    ['user'] = user,
    -- ['corpse'] = corpse_info,
    ['is_covert'] = is_covert,
    ['is_long_range'] = is_long_range,
    ['was_traitor'] = was_traitor
  }
  add_table_to_file(action_table)
end

gameevent.Listen('player_disconnect')
hook.Add( 'player_disconnect', 'player_disconnect_example', function(data)
  action = 'player_disconnect'
  user = {
    ['steam_id'] = data.networkid,
    ['name'] =  data.name,
    ['reason'] =  data.reason,
    ['user_id'] =  data.userid,
    ['bot'] = data.bot
  }
  action_table = {
    ['action'] = action,
    ['user'] =  user,
    ['time'] = os.date()
  }
  add_table_to_file(action_table)
end )

gameevent.Listen( "player_hurt" )
hook.Add( "player_hurt", "player_hurt", function(data)
  action = 'player_hurt'
  user = {
    ['health'] = data.health,
    ['user_id'] = data.userid, -- Same as Player:UserID()
    ['attacker_id'] = data.attacker -- Same as Player:UserID()
  }
  action_table = {
    ['action'] = action,
    ['user'] =  user,
    ['time'] = os.date()
  }
  add_table_to_file(action_table)
end )

gameevent.Listen( "entity_killed" )
hook.Add( "entity_killed", "entity_killed_example", function(data)
  action = 'player_dead'
  user = {
    ['weapon_index'] = data.entindex_inflictor,
    ['attacker_index'] = data.entindex_attacker,
    ['damagebits'] = data.damagebits,
    ['victim_index'] = data.entindex_killed
  }
  action_table = {
    ['action'] = action,
    ['user'] =  user,
    ['time'] = os.date()
  }
  add_table_to_file(action_table)
end )

-- //////   [ hooks ]   //////
hook.Add('Initialize', 'InitializeFile', Initialize)
hook.Add('Initialize', 'ServerStart', ServerStart)
hook.Add('PlayerInitialSpawn', 'PlayerJoin', PlayerJoin)
hook.Add('WeaponEquip', 'WeaponEquipExample', WeaponPickedUp)
hook.Add('TTTBeginRound', 'round_begin', RoundBegin)
hook.Add('TTTEndRound', 'round_end', RoundEnd)
hook.Add('TTTOrderedEquipment', 'equipment_bought', EquipmentBought)
hook.Add('TTTCanSearchCorpse ', 'corpse_searched', CorpseSearch)

-- //////   [helpers]   //////

function add_table_to_file(table)
  json = util.TableToJSON(table)
  string = json .. '\n'
  file.Append(FILE_PATH, string)
end

function extract_player_table(ply)
  user_info = {
    ['steam_id'] = ply:SteamID(),
    ['name'] =  ply:GetName(),
    ['bot'] = ply:IsBot(),
    ['user_id'] = ply:UserID()
  }
  return user_info
end

function extract_equipment_table(equip)
  equipment_info = {
    ['name'] = equip:GetClass(),
    ['index'] = equip:EntIndex()
  }
  return equipment_info
end
