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
  user_info = {
    ['steam_id'] = ply:SteamID(),
    ['name'] =  ply:GetName(),
    ['bot'] = ply:IsBot(),
    ['user_id'] = ply:UserID()
  }
  action_table = {
    ['action'] = action,
    ['user'] = user_info,
    ['time'] = os.date()
  }
  add_table_to_file(action_table)
end

function WeaponPickedUp(weapon, ply)
  action = 'weapon_pickup'
  user_info = {
    ['steam_id'] = ply:SteamID(),
    ['name'] =  ply:GetName(),
    ['bot'] = ply:IsBot(),
    ['user_id'] = ply:UserID()
  }
  weapon_info = {
    ['name'] = weapon:GetClass(),
    ['index'] = weapon:EntIndex()
  }
  action_table = {
    ['action'] = action,
    ['user'] = user_info,
    ['weapon'] = weapon_info,
    ['time'] = os.date()
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
hook.Add( "WeaponEquip", "WeaponEquipExample", WeaponPickedUp)

-- //////   [helpers]   //////

function add_table_to_file(table)
  json = util.TableToJSON(table)
  string = json .. '\n'
  file.Append(FILE_PATH, string)
end

