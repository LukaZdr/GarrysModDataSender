function Initialize() -- creates a data_collector directory on server start if there is none
  if not file.IsDir("data_collector", "DATA") then
    file.CreateDir("data_collector", "DATA")
  end
  if not file.Exists("data_collector/storage.txt", "DATA") then
    file.Write("data_collector/storage.txt", "// Initial Row // \n")
  end
end

function ServerStart() -- saves server starting information
  action = '[ServerStart]'
  time = CurTime()
  string = action .. ' time: ' .. time .. '\n'
  file.Append("data_collector/storage.txt", string)
end

function PlayerJoin( ply ) -- writes an entry when a user is joining
  action = '[PlayerJoin]'
  player = ply:UniqueID()
  time = CurTime()
  string = action .. ' player: ' .. player .. ', time: ' .. time .. '\n'
  file.Append("data_collector/storage.txt", string)
end

-- //////   [ hooks ]   //////
hook.Add("Initialize", "InitializeFile", Initialize)
hook.Add("Initialize", "ServerStart", ServerStart)
hook.Add("PlayerInitialSpawn", "PlayerJoin", PlayerJoin)