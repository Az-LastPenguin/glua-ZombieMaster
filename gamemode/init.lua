AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

AddCSLuaFile("cl_killicons.lua")
AddCSLuaFile("cl_utility.lua")
AddCSLuaFile("cl_scoreboard.lua")
AddCSLuaFile("cl_dermaskin.lua")

AddCSLuaFile("cl_hud.lua")
AddCSLuaFile("cl_zombie.lua")

AddCSLuaFile("sh_networking.lua")

AddCSLuaFile("sh_weapons.lua")
AddCSLuaFile("sh_players.lua")
AddCSLuaFile("sh_entites.lua")
AddCSLuaFile("sh_zombies.lua")

AddCSLuaFile("sh_sounds.lua")
AddCSLuaFile("sh_zm_globals.lua")
AddCSLuaFile("sh_utility.lua")
AddCSLuaFile("sh_zm_options.lua")

AddCSLuaFile("cl_zm_options.lua")
AddCSLuaFile("cl_targetid.lua")
AddCSLuaFile("cl_entites.lua")

AddCSLuaFile("vgui/dpingmeter.lua")
AddCSLuaFile("vgui/dteamcounter.lua")
AddCSLuaFile("vgui/dteamheading.lua")
AddCSLuaFile("vgui/dzombiepanel.lua")
AddCSLuaFile("vgui/dpowerpanel.lua")
AddCSLuaFile("vgui/dmodelselector.lua")

include("sv_zm_options.lua")
include("sh_players.lua")
include("sv_players.lua")
include("sv_entites.lua")
include("sv_npc.lua")
include("shared.lua")

DEFINE_BASECLASS("gamemode_base")

GM.RoundsPlayed = 0
GM.UnReadyPlayers = {}
GM.DeadPlayers = {}
GM.ReadyTimer = 0
GM.DontConvertProps = true
GM.PostMapSetup = false

GM.Income_Time = 0

if file.Exists(GM.FolderName.."/gamemode/maps/"..game.GetMap()..".lua", "LUA") then
	include("maps/"..game.GetMap()..".lua")
end

function GM:InitPostEntity()
	RunConsoleCommand("mapcyclefile", "mapcycle_zombiemaster.txt")
	hook.Call("InitPostEntityMap", self)
	
	local ammotbl = hook.Call("GetCustomAmmo", GAMEMODE)
	if #ammotbl > 0 then
		CreateConVar("zm_maxammo_"..ammotbl.Type, ammotbl.MaxCarry, FCVAR_REPLICATED, "Max "..ammotbl.Type.." ammo that players can hold.")
		game.AddAmmoType({name = ammotbl.Type, dmgtype = ammotbl.DmgType, tracer = ammotbl.TracerType, plydmg = 0, npcdmg = 0, force = 2000, maxcarry = ammotbl.MaxCarry})
	end
	
	--[[
	if not file.Exists("maps/"..game.GetMap()..".ain", "GAME") then
		MsgC(Color(255, 0, 0), "A NavMesh was not found for this map, generating one now. Please allow for up to 1 second to 3 minutes for it to finish.")
		navmesh.BeginGeneration()
		
		timer.Create("NavMeshGenCheck", 0, 0, function()
			if not navmesh.IsGenerating() then
				navmesh.Save()
				timer.Remove("NavMeshGenCheck")
			end
		end)
	end
	--]]
end

function GM:InitPostEntityMap()
	self:SetupAmmo()
	
	if not self.DontConvertProps then
		for _, ent in pairs(ents.FindByClass("prop_physics")) do
			self:ConvertEntTo(ent, "prop_physics_multiplayer")
		end
		
		for _, ent in pairs(ents.FindByClass("func_physbox")) do
			self:ConvertEntTo(ent, "func_physbox_multiplayer")
		end
	end
	
	self.PostMapSetup = true
end

function GM:SetupAmmo()
	local ammotbl = ents.FindByClass("item_ammo_*")
	table.Add(ammotbl, ents.FindByClass("item_box_*"))
	
	for _, ammo in pairs(ammotbl) do
		if ammo:GetClass() == "item_ammo_revolver" then continue end
		
		local ammotype = self.AmmoClass[ammo:GetClass()]
		if ammotype then
			local ent = ents.Create("item_zm_ammo")
			if IsValid(ent) then
				ent:SetPos(ammo:GetPos())
				ent:SetAngles(ammo:GetAngles())
				
				ent.ClassName = ammo:GetClass()
				ent.Model = ammo:GetModel()
				ent.AmmoAmount = self.AmmoCache[ammotype]
				ent.AmmoType = ammotype
				ent:Spawn()
				
				if not self.AmmoModels[ammo:GetClass()] then
					self.AmmoModels[ammo:GetClass()] = ammo:GetModel()
				end
				
				ammo:Remove()
			end
		end
	end
end

function GM:ConvertAmmo(ammo)
	if not IsValid(ammo) then return end
	if ammo:GetClass() == "item_ammo_revolver" then return end

	local ammotype = self.AmmoClass[ammo:GetClass()]
	if ammotype then
		local ent = ents.Create("item_zm_ammo")
		if IsValid(ent) then
			ent:SetPos(ammo:GetPos())
			ent:SetAngles(ammo:GetAngles())
			
			ent.ClassName = ammo:GetClass()
			ent.Model = self.AmmoModels[ammo:GetClass()]
			ent.AmmoAmount = self.AmmoCache[ammotype]
			ent.AmmoType = ammotype
			ent:Spawn()
			
			ent:SetVelocity(ammo:GetVelocity())
			
			ammo:Remove()
		end
	end
end

local WepsToConvert = {
	["weapon_357"] = "weapon_zm_revolver",
	["weapon_pistol"] = "weapon_zm_pistol",
	["weapon_shotgun"] = "weapon_zm_shotgun",
	["weapon_smg1"] = "weapon_zm_mac10",
	["weapon_crossbow"] = "weapon_zm_rifle",
	["weapon_grenade"] = "weapon_zm_molotov",
	["weapon_ar2"] = "weapon_zm_mac10",
	["weapon_rpg"] = "weapon_zm_rifle",
	["weapon_crowbar"] = "weapon_zm_improvised",
	["weapon_bugbait"] = "weapon_zm_molotov"
}
function GM:ConvertWeapon(wep)
	if not IsValid(wep) then return end
	if not WepsToConvert[wep:GetClass()] then return end

	local ent = ents.Create(WepsToConvert[wep:GetClass()])
	if IsValid(ent) then
		ent:SetPos(wep:GetPos())
		ent:SetAngles(wep:GetAngles())
		ent:Spawn()
		
		ent:SetSolid(SOLID_BBOX)
		ent:SetCollisionBounds(ent:OBBMins() * 4, ent:OBBMaxs() * 4)
		
		wep:Remove()
	end
end

function GM:SetupNPCZombieModels(ent)
	if not IsValid(ent) then return end
	
	local zombie = self:GetZombieData(ent:GetClass())
	if not zombie then return end
	
	local models = zombie.Model
	if not models then return end
	
	local randmodel = models[math.random(#models)]
	if not randmodel then return end
	
	ent:SetModel(randmodel)
end

function GM:CreateCustomWeapons(ent)
	local weptbl = hook.Call("GetCustomWeapons", GAMEMODE)
	if #weptbl > 0 then
		if math.random() > weptbl[ent:GetClass()].Chance then
			local wep = ents.Create(weptbl[ent:GetClass()].Class)
			if IsValid(wep) then
				wep:SetPos(ent:GetPos())
				wep:SetAngles(ent:GetAngles())
				wep:Spawn()
				wep:SetCollisionBounds(wep:OBBMins() * 2, wep:OBBMaxs() * 2)
				
				return wep
			end
		end
	end
	
	return ent
end

function GM:CreateCustomAmmo(ent)
	local ammotbl = hook.Call("GetCustomAmmo", GAMEMODE)
	if #ammotbl > 0 then
		if math.random() > ammotbl[ent.AmmoType].Chance then
			local ammoent = ents.Create(ammotbl[ent.AmmoType].Class)
			if IsValid(ammoent) then
				ammoent:SetPos(ent:GetPos())
				ammoent:SetAngles(ent:GetAngles())
				ammoent:Spawn()
				ammoent:SetCollisionBounds(ammoent:OBBMins() * 2, ammoent:OBBMaxs() * 2)
				
				return ammoent
			end
		end
	end
	
	return ent
end

function GM:OnEntityCreated(ent)
	if self.PostMapSetup and (string.sub(ent:GetClass(), 1, 10) == "item_ammo_" or string.sub(ent:GetClass(), 1, 9) == "item_box_") then
		timer.Simple(0.335, function() self:ConvertAmmo(ent) end)
	end
	
	if ent:IsWeapon() then
		if not ent.Dropped then ent = hook.Call("CreateCustomWeapons", GAMEMODE, ent) end
		ent:SetSolid(SOLID_BBOX)
		ent:SetCollisionBounds(ent:OBBMins() * 4, ent:OBBMaxs() * 4)
		self:ConvertWeapon(ent)
	end
	
	if ent:GetClass() == "item_zm_ammo" then
		ent = hook.Call("CreateCustomAmmo", GAMEMODE, ent)
	end
	
	if ent:IsNPC() then
		if string.sub(ent:GetClass(), 1, 12) == "npc_headcrab" then
			ent:Remove() 
			return
		end
		
		timer.Simple(0, function()
			if not IsValid(ent) then return end
			
			if string.find(ent:GetClass(), "fastzombie") then
				ent:SetModelScale(0.855)
				ent:SetHullSizeNormal()
			end
			
			if ent.GetNumBodyGroups and ent.SetBodyGroup then
				for k = 0, ent:GetNumBodyGroups() - 1 do
					ent:SetBodyGroup(k, 0)
				end
			end
			
			hook.Call("SetupNPCZombieModels", self, ent)
			ent:SetShouldServerRagdoll(false)
		end)
		
		for _, npc in pairs(ents.FindByClass("npc_*")) do
			hook.Call("AddNPCFriends", self, npc, ent)
		end
	end
end

function GM:AddNPCFriends(npc, ent)
	local zombie = self:GetZombieData(npc:GetClass())
	if not zombie then return end
	
	local zombiefriends = {}
	for _, fri in pairs(zombie.Friends) do
		if fri ~= npc:GetClass() then
			table.Merge(zombiefriends, ents.FindByClass(fri))
		end
	end
	
	for _, zom in pairs(zombiefriends) do
		npc:AddEntityRelationship(zom, D_NU, 99)
	end
end

function GM:PostGamemodeLoaded()
	self:SetRoundStartTime(5)
	self:SetRoundStart(true)
	self:SetRoundActive(false)
	
	self:AddResources()

	util.AddNetworkString("PlayerKilledByNPC")
	
	util.AddNetworkString("zm_gamemodecall")
	util.AddNetworkString("zm_trigger")
	util.AddNetworkString("zm_infostrings")	
	util.AddNetworkString("zm_queue")
	util.AddNetworkString("zm_remove_queue")
	util.AddNetworkString("zm_sendcurrentgroups")
	util.AddNetworkString("zm_sendselectedgroup")
	util.AddNetworkString("zm_spawnclientragdoll")
	util.AddNetworkString("zm_coloredprintmessage")
	
	game.ConsoleCommand("fire_dmgscale 1\nmp_falldamage 1\nsv_gravity 600\n")
	
	local mapinfo = "maps/"..game.GetMap()..".txt"
	if file.Exists(mapinfo, "GAME") then
		self.MapInfo = file.Read(mapinfo, "GAME")
	else
		self.MapInfo = "No objectives found!"
	end
	
	if not file.Exists("zm_info", "DATA") then
		file.CreateDir("zm_info")
	end
	
	if file.Exists("zm_info/help_menu.html", "DATA") then
		self.HelpInfo = file.Read("zm_info/help_menu.html", "DATA")
	else
		self.HelpInfo = "No Info"
	end
end

function GM:OnReloaded()
	if team.NumPlayers(TEAM_ZOMBIEMASTER) > 0 then
		timer.Simple(0.25, function() 
			self.Income_Time = 1
			self:SetRoundActive(true)
			
			if file.Exists("zm_rounds.txt", "DATA") then
				self.RoundsPlayed = tonumber(file.Read("zm_rounds.txt"))
			end
		end)
	end
	
	hook.Call("BuildZombieDataTable", self)
end

function GM:PlayerSpawnAsSpectator(pl)
	pl:StripWeapons()
	pl:SetTeam(TEAM_SPECTATOR)
	pl:Spectate(OBS_MODE_ROAMING)
	
	pl:SendLua([[
		if IsValid(GAMEMODE.powerMenu) then
			GAMEMODE.powerMenu:Remove()
		end
	]])
	
	pl:SetClass("player_spectator")
end

function GM:PlayerDeathThink(pl)
	if player_manager.RunClass(pl, "DeathThink") then return false end
end

function GM:PlayerShouldTaunt(ply, act)
	return player_manager.RunClass(ply, "ShouldTaunt", act)
end

function GM:CanPlayerSuicide(ply)
	return player_manager.RunClass(ply, "CanSuicide")
end

function GM:PlayerInitialSpawn(pl)
	pl:SetTeam(TEAM_UNASSIGNED)
	pl:CrosshairDisable()
	
	if (self:GetRoundActive() and team.NumPlayers(TEAM_SURVIVOR) == 0 and team.NumPlayers(TEAM_ZOMBIEMASTER) >= 1) and not NotifiedRestart then
		PrintTranslatedMessage(HUD_PRINTTALK, "round_restarting")
		timer.Simple(2, function() hook.Call("PreRestartRound", self) end)
		timer.Simple(3, function() hook.Call("RestartRound", self) end)
		NotifiedRestart = true
	end
	
	pl.NextPainSound = 0
	
	if not zm_start_round and not self:GetRoundActive() then
		zm_start_round = true
	end
	
	table.insert(self.UnReadyPlayers, pl)
	
	net.Start("zm_infostrings")
		net.WriteString(self.MapInfo)
		net.WriteString(self.HelpInfo)
	net.Send(pl)	
end

function GM:IncreaseResources(pZM)
	if not IsValid(pZM) then return end
	
	local players = #team.GetPlayers(TEAM_SURVIVOR)
	local resources = pZM:GetZMPoints()
	local increase = GetConVar("zm_maxresource_increase"):GetInt()
	
	increase = increase * math.Clamp(players, 1, 5)
	
	pZM:SetZMPoints(resources + increase)
	pZM:SetZMPointIncome(increase)
end

function GM:PlayerNoClip(ply, desiredState)
	if not desiredState then return true end
	return ply:IsAdmin()
end

function GM:OnNPCKilled(ent, attacker, inflictor)
	self:CallZombieFunction(ent:GetClass(), "OnKilled", ent, attacker, inflictor)
end

function GM:ScaleNPCDamage(npc, hitgroup, dmginfo)
	self:CallZombieFunction(npc:GetClass(), "OnScaledDamage", npc, hitgroup, dmginfo)
end

function GM:PlayerDeath(ply, inflictor, attacker)
	player_manager.RunClass(ply, "PreDeath", inflictor, attacker)
end

function GM:DoPlayerDeath(ply, attacker, dmginfo)
	player_manager.RunClass(ply, "OnDeath", attacker, dmginfo)
end

function GM:PostPlayerDeath(ply)
	player_manager.RunClass(ply, "PostOnDeath")
end

function GM:PlayerHurt(victim, attacker, healthremaining, damage)
	player_manager.RunClass(victim, "OnHurt", attacker, healthremaining, damage)
end

function GM:PostCleanupMap()
	hook.Call("InitPostEntityMap", self)
end

function GM:RestartRound()
	self:RestartLua()
	self:RestartGame()

	net.Start("zm_gamemodecall")
		net.WriteString("RestartRound")
	net.Broadcast()
end

function GM:RestartLua()
	zm_selection_started = false
	zm_zm_left = false
	NotifiedRestart = false
	zm_timer_started = false
	zm_start_round = false
	self.ReadyTimer = 0
	self.Income_Time = 0
	
	table.Empty(self.groups)
	self.currentmaxgroup = 0
	self.selectedgroup = 0
	
	self:SetCurZombiePop(0)
end

function GM:DoRestartGame()
	game.CleanUpMap()
	
	self:SetRoundStart(true)
	self:SetRoundActive(false)
	self:SetRoundEnd(false)
	self:SetRoundStartTime(5)
	self.RoundStarted = 0
	
	zm_start_round = true
	
	table.Empty(self.UnReadyPlayers)
	table.Empty(self.DeadPlayers)
end

function GM:RestartGame()
	for _, pl in pairs(player.GetAll()) do
		if IsValid(pl) then
			pl:StripAmmo()
			pl:SetFrags(0)
			pl:SetDeaths(0)
			pl:SetZMPoints(0)
			
			hook.Call("PlayerSpawnAsSpectator", self, pl)
		end
	end
	
	self.PostMapSetup = false

	timer.Simple(0.25, function() self:DoRestartGame() end)
end

function GM:PlayerSay(sender, text, teamChat)
	if string.lower(text) == "!roundsleft" then
		local roundsleft = GetConVar("zm_roundlimit"):GetInt() - self.RoundsPlayed
		PrintMessage(HUD_PRINTTALK, "There is currently "..roundsleft.." rounds left.")
	end
	
	return BaseClass.PlayerSay(self, sender, text, teamChat)
end

function GM:OnPlayerClassChanged(pl, class)
end

function GM:OnPlayerChangedTeam(ply, oldTeam, newTeam)
	if newTeam == TEAM_SPECTATOR then
		ply:SetPos(ply:EyePos())
	elseif newTeam == TEAM_ZOMBIEMASTER then
		timer.Simple(0.1, function() ply:SendLua("GAMEMODE:CreateVGUI()") end)
	end
	
	if newteam ~= TEAM_SURVIVOR then
		ply:Spectate(OBS_MODE_ROAMING)
		ply:GodEnable()
	else
		ply:GodDisable()
	end
end

-- You can override or hook and return false in case you have your own map change system.
local function RealMap(map)
	return string_match(map, "(.+)%.bsp")
end
function GM:LoadNextMap()
	-- Just in case.
	timer.Simple(5, game.LoadNextMap)
	timer.Simple(10, function() RunConsoleCommand("changelevel", game.GetMap()) end)

	if file.Exists(GetConVarString("mapcyclefile"), "GAME") then
		game.LoadNextMap()
	else
		local maps = file.Find("maps/zm_*.bsp", "GAME")
		table_sort(maps)
		if #maps > 0 then
			local currentmap = game.GetMap()
			for i, map in ipairs(maps) do
				local lowermap = string_lower(map)
				local realmap = RealMap(lowermap)
				if realmap == currentmap then
					if maps[i + 1] then
						local nextmap = RealMap(maps[i + 1])
						if nextmap then
							RunConsoleCommand("changelevel", nextmap)
						end
					else
						local nextmap = RealMap(maps[1])
						if nextmap then
							RunConsoleCommand("changelevel", nextmap)
						end
					end

					break
				end
			end
		end
	end
end

function GM:PreRestartRound()
	for _, pl in pairs(player.GetAll()) do
		pl:StripWeapons()
		pl:Spectate(OBS_MODE_ROAMING)
	end
end

function GM:FinishingRound(won, rounds)
	if self.RoundsPlayed > rounds then
		PrintTranslatedMessage(HUD_PRINTTALK, "map_changing")
	else
		PrintTranslatedMessage(HUD_PRINTTALK, "round_restarting")
	end
end

function GM:CreateGibs(pos, headoffset)
	headoffset = headoffset or 0

	local headpos = Vector(pos.x, pos.y, pos.z + headoffset)
	for i = 1, 2 do
		local ent = ents.Create("prop_playergib")
		if ent:IsValid() then
			ent:SetPos(headpos + VectorRand() * 5)
			ent:SetAngles(VectorRand():Angle())
			ent:SetGibType(i)
			ent:Spawn()
		end
	end

	for i=1, 4 do
		local ent = ents.Create("prop_playergib")
		if ent:IsValid() then
			ent:SetPos(pos + VectorRand() * 12)
			ent:SetAngles(VectorRand():Angle())
			ent:SetGibType(math.random(3, #self.HumanGibs))
			ent:Spawn()
		end
	end
end

function GM:TeamVictorious(won, message)
	if player.GetCount() == 1 then return end
	
	local winscore = Either(won, HUMAN_WIN_SCORE, HUMAN_LOSS_SCORE)
	local winningteam = Either(won, TEAM_SURVIVOR, TEAM_ZOMBIEMASTER)
	for _, ply in pairs(team.GetPlayers(winningteam)) do
		ply:AddFrags(winscore)
	end
	
	self:SetRoundEnd(true)
	hook.Call("IncrementRoundCount", self)
	
	if not GetConVar("zm_notimeslowonwin"):GetBool() and won then
		game.SetTimeScale(0.25)
		timer.Simple(2, function() game.SetTimeScale(1) end)
	end
	
	local rounds = GetConVar("zm_roundlimit"):GetInt()
	if self.RoundsPlayed > rounds then
		timer.Simple(3, function() hook.Call("LoadNextMap", self) end)
	else
		timer.Simple(2, function() hook.Call("PreRestartRound", self) end)
		timer.Simple(3, function() hook.Call("RestartRound", self) end)
	end
	
	for _, ply in pairs(player.GetAll()) do
		if translate.ClientGet(ply, message) ~= "@"..message.."@" then
			ply:PrintTranslatedMessage(HUD_PRINTTALK, message)
		else
			ply:PrintMessage(HUD_PRINTTALK, message)
		end
	end
	
	hook.Call("FinishingRound", self, won, rounds)
end

function GM:IncrementRoundCount()
	self.RoundsPlayed = self.RoundsPlayed + 1
	file.Write("zm_rounds.txt", tostring(self.RoundsPlayed))
end

function GM:SetupPlayer(ply)
	if ply:GetInfoNum("zm_preference", 0) >= 2 then return end
	
	ply:ChangeTeam(TEAM_SURVIVOR)
	ply:SetClass("player_survivor")
	
	ply:UnSpectate()
	ply:Spawn()
	
	ply:SprintDisable()
	if ply:KeyDown(IN_WALK) then
		ply:ConCommand("-walk")
	end
		
	ply:ResetHull()
	ply:SetCanWalk(false)
	ply:SetCanZoom(false)
end

function GM:InitClient(pl)
	if not pl:IsValid() then return end
	table.RemoveByValue(self.UnReadyPlayers, pl)
	
	if self.ReadyTimer == 0 and not zm_timer_started then
		zm_timer_started = true
		self.ReadyTimer = CurTime() + 15
	end
	
	if pl:GetInfoNum("zm_nopreferredmenu", 0) <= 0 then
		pl:SendLua("GAMEMODE:MakePreferredMenu()")
	end
	
	if self.RoundStarted and self.RoundStarted ~= 0 and self:GetRoundActive() then
		if self.RoundStarted + GetConVar("zm_postroundstarttimer"):GetInt() >= CurTime() and not self.DeadPlayers[pl:SteamID()] then
			hook.Call("SetupPlayer", self, pl)
		end
	end
	
	hook.Call("InitPostClient", self, pl)
end

function GM:InitPostClient(pl)
end

function GM:ConvertEntTo(prop, convertto)
	if convertto == "" or convertto == nil then return end
	if not IsValid(prop:GetPhysicsObject()) then return end
	
	local ent = ents.Create(convertto)
	if IsValid(ent) then
		ent:SetName(prop:GetName())
		ent:SetPos(prop:GetPos())
		ent:SetAngles(prop:GetAngles())
		ent:SetModel(prop:GetModel())
		ent:SetMaterial(prop:GetMaterial())
		ent:SetSkin(prop:GetSkin() or 0)
		ent:SetBodyGroups(prop:GetBodyGroups())
		ent:SetCollisionGroup(prop:GetCollisionGroup())
		ent:SetModelScale(prop:GetModelScale() or 1)
		ent:SetParent(prop:GetParent())
		ent:SetOwner(prop:GetOwner())
		ent:SetSolid(prop:GetSolid())
		ent:SetMoveType(prop:GetMoveType())
		ent:SetRenderFX(prop:GetRenderFX())
		ent:SetGravity(prop:GetGravity())
		ent:SetMoveCollide(prop:GetMoveCollide())
		ent:SetNoDraw(prop:GetNoDraw())
		ent:SetNotSolid(prop:IsSolid())
		ent:SetRenderMode(prop:GetRenderMode())
		ent:SetSolidFlags(prop:GetSolidFlags())
		ent:SetSpawnEffect(prop:GetSpawnEffect())
		ent:SetCollisionBounds(prop:GetCollisionBounds())
		ent:SetColor(prop:GetColor())
		ent:SetCustomCollisionCheck(prop:GetCustomCollisionCheck())
		ent:SetFriction(prop:GetFriction())
		ent:SetGroundEntity(prop:GetGroundEntity())
		ent:SetTransmitWithParent(prop:GetTransmitWithParent())
		
		for index, mat in pairs(prop:GetMaterials()) do
			ent:SetSubMaterial(index - 1, mat)
		end
		
		if prop:Health() > 0 then
			ent:SetHealth(prop:Health())
		end
		
		for key, value in pairs(prop:GetKeyValues()) do
			ent:SetKeyValue(key, value)
		end
		
		ent:Spawn()
		ent:Activate()
		
		local phys = prop:GetPhysicsObject()
		if IsValid(phys) then
			local phys2 = ent:GetPhysicsObject()
			if IsValid(phys2) then
				phys2:SetMass(phys:GetMass())
				phys2:SetMaterial(phys:GetMaterial())
				
				if phys:IsMotionEnabled() then
					phys2:Wake()
				else
					phys2:EnableMotion(false)
				end
			end
		end
		
		if string.find(prop:GetClass(), "func_physbox") then
			if not IsValid(ent:GetPhysicsObject()) then
				ent:PhysicsInitBox(prop:OBBMins(), prop:OBBMaxs())
			end
		end
		
		ent:SetTable(prop:GetTable())
		
		prop:Remove()
	end
end

function GM:EntityTakeDamage(ent, dmginfo)
	local attacker, inflictor = dmginfo:GetAttacker(), dmginfo:GetInflictor()
	local damage = dmginfo:GetDamage()
	
	if ent:IsPlayerHolding() and damage > 10 then
		DropEntityIfHeld(ent)
		ent:SetCollisionGroup(ent._OldCG or COLLISION_GROUP_NONE)
		
		dmginfo:SetDamage(0)
		dmginfo:ScaleDamage(0)
		dmginfo:SetDamageType(DMG_BULLET)
		
		return true
	end
	
	if ent:IsNPC() then
		if self:CallZombieFunction(ent:GetClass(), "OnTakeDamage", ent, attacker, inflictor, dmginfo) then return true end
	end
	
	if ent:IsPlayer() then
		if player_manager.RunClass(ent, "OnTakeDamage", attacker, dmginfo) then return true end
	end
	
	if attacker:IsNPC() and string.sub(ent:GetClass(), 1, 12) == "prop_physics" then
		local phys = ent:GetPhysicsObject()
		if IsValid(phys) then
			if phys:IsMotionEnabled() then
				ent:SetPhysicsAttacker(attacker)
			end
		end
	end
	
	local mdlname = ent:GetModel() or ""
	if string.find(mdlname, "explosive") and ent:IsPlayerHolding() then
		dmginfo:SetDamage(0)
		dmginfo:ScaleDamage(0)
		dmginfo:SetDamageType(DMG_BULLET)
		return true
	end
	
    -- We need to stop explosive chains team killing.
    if inflictor:IsValid() then
        local dmgtype = dmginfo:GetDamageType()
        if dmgtype == DMG_BLAST or dmgtype == DMG_BURN or dmgtype == DMG_SLOWBURN then
            if ent:IsPlayer() then
                if inflictor.LastExplosionTeam == ent:Team() and inflictor.LastExplosionAttacker ~= ent and inflictor.LastExplosionTime and CurTime() < inflictor.LastExplosionTime + 10 then -- Player damaged by physics object explosion / fire.
                    dmginfo:SetDamage(0)
                    dmginfo:ScaleDamage(0)
                    return
                end
            elseif inflictor ~= ent and string.sub(ent:GetClass(), 1, 12) == "prop_physics" and string.sub(inflictor:GetClass(), 1, 12) == "prop_physics" then -- Physics object damaged by physics object explosion / fire.
                ent.LastExplosionAttacker = inflictor.LastExplosionAttacker
                ent.LastExplosionTeam = inflictor.LastExplosionTeam
                ent.LastExplosionTime = CurTime()
            end
        elseif inflictor:IsPlayer() and string.sub(ent:GetClass(), 1, 12) == "prop_physics" then -- Physics object damaged by player.
            if inflictor:Team() == TEAM_HUMAN then
                local phys = ent:GetPhysicsObject()
                if phys:IsValid() and phys:HasGameFlag(FVPHYSICS_PLAYER_HELD) and inflictor:GetCarry() ~= ent or ent._LastDropped and CurTime() < ent._LastDropped + 3 and ent._LastDroppedBy ~= inflictor then -- Human player damaged a physics object while it was being carried or recently carried. They weren't the carrier.
                    dmginfo:SetDamage(0)
                    dmginfo:ScaleDamage(0)
                    return
                end
            end

            ent.LastExplosionAttacker = inflictor
            ent.LastExplosionTeam = inflictor:Team()
            ent.LastExplosionTime = CurTime()
        end
    end
end

function GM:SetRoundStartTime(time)
	self.RoundStartTime = time
end

function GM:GetRoundStartTime()
	return self.RoundStartTime or 2
end

function GM:PlayerPostThink(pl)
	player_manager.RunClass(pl, "PostThink")
end

function GM:StartCommand(ply, ucmd)
	if ply:IsSurvivor() and (ucmd:KeyDown(IN_ATTACK) or ucmd:KeyDown(IN_ATTACK2)) then
		if IsValid(ply.HeldObject) then
			ply.HeldObject:SetCollisionGroup(ply.HeldObject._OldCG or COLLISION_GROUP_NONE)
			ply.HeldObject._OldCG = nil
			ply.HeldObject = nil
		end
	end
end

function GM:Tick()
	for _, npc in pairs(ents.FindByClass("npc_*")) do
		self:CallZombieFunction(npc:GetClass(), "Think", npc)
	end
end

local NextTick = 0
function GM:Think()
	local time = CurTime()

	-- Originally from TTT
	-- Why is this type of for loop faster?
	local players = player.GetAll()
	for i= 1, #players do
		local ply = players[i]
		player_manager.RunClass(ply, "Think")
	end
	
	if NextTick <= time then
		NextTick = time + 1
		
		if self:GetRoundActive() and not self:GetRoundEnd() and (team.NumPlayers(TEAM_ZOMBIEMASTER) <= 0 and team.NumPlayers(TEAM_SURVIVOR) >= 1) then
			hook.Call("SetupZombieMasterVolunteers", self, true)
		end
		
		if self.ReadyTimer ~= 0 and CurTime() > self.ReadyTimer then
			table.Empty(self.UnReadyPlayers)
			self.ReadyTimer = 0
		end
		
		if zm_start_round then
			if #self.UnReadyPlayers == 0 and self:GetRoundStart() and not zm_selection_started then
				self:SetZMSelection(true)
				zm_selection_started = true
				zm_start_round = false
				timer.Simple(self:GetRoundStartTime(), function()
					hook.Call("SetupZombieMasterVolunteers", self)
					for _, ent in pairs(ents.FindByClass("info_loadout")) do
						ent:Distribute()
					end
				end)
			end
		end
	end
end

function GM:ShowHelp(pl)
	pl:SendLua("GAMEMODE:ShowHelp()")
end

function GM:ShowTeam(pl)
	pl:SendLua("GAMEMODE:ShowOptions()")
end

function GM:ShowSpare1(pl)
	pl:SendLua("MakepOptions()")
end

function GM:PlayerDisconnected(ply)
	if self:GetRoundActive() then
		timer.Simple(0.1, function()
			if team.NumPlayers(TEAM_ZOMBIEMASTER) <= 0 then
				hook.Call("TeamVictorious", self, true, "zombiemaster_left")
			elseif team.NumPlayers(TEAM_SURVIVOR) <= 0 then
				hook.Call("TeamVictorious", self, false, "all_humans_left")
			end
		end)
	end
	
	self.DeadPlayers[ply:SteamID()] = true
end

function GM:IsSpawnpointSuitable(pl, spawnpointent, bMakeSuitable)
	local Pos = spawnpointent:GetPos()
	local Ents = ents.FindInBox(Pos + Vector(-16, -16, 0), Pos + Vector(16, 16, 64))
	
	if pl:Team() == TEAM_SPECTATOR then return true end
	
	local Blockers = 0
	for k, v in pairs( Ents ) do
		if IsValid(v) and v ~= pl and v:GetClass() == "player" and v:Alive() then
			Blockers = Blockers + 1
		end
	end
	
	if bMakeSuitable then return true end
	if Blockers > 0 then return false end
	
	return true
end

function GM:SetupZombieMasterVolunteers(bSkipToSelection)
	if not bSkipToSelection then
		self:SetZMSelection(false)
		self:SetRoundStart(false)
		self:SetRoundActive(true)
		self.RoundStarted = CurTime()
		
		for _, ply in pairs(player.GetAll()) do
			if IsValid(ply) then
				if ply:IsSpectator() then continue end
				ply.m_iZMPriority = (ply.m_iZMPriority or 0) + 10
			end
		end
		
		game.CleanUpMap(false)
		
		for _, ply in pairs(team.GetPlayers(TEAM_SPECTATOR)) do
			hook.Call("SetupPlayer", self, ply)
		end
	end
	
	if team.NumPlayers(TEAM_ZOMBIEMASTER) == 0 then
		local pl = hook.Call("GetZombieMasterVolunteer", self)
		if IsValid(pl) then
			hook.Call("SetPlayerToZombieMaster", self, pl)
			
			timer.Simple(1, function()
				if IsValid(pl) and pl:Team() ~= TEAM_ZOMBIEMASTER then
					hook.Call("SetPlayerToZombieMaster", self, pl)
				end
			end)
		end
	end
end

function GM:SetPlayerToZombieMaster(pl)
	if team.NumPlayers(TEAM_ZOMBIEMASTER) >= 1 then return end
	
	if not IsValid(pl) then 
		hook.Call("SetupZombieMasterVolunteers", self, true) 
		return
	end
	
	pl:KillSilent()
	pl:SetFrags(0)
	pl:SetDeaths(0)
	pl:Spectate(OBS_MODE_ROAMING)
	pl:ChangeTeam(TEAM_ZOMBIEMASTER)
	pl:SetClass("player_zombiemaster")

	pl.m_iZMPriority = 0

	PrintTranslatedMessage(HUD_PRINTTALK, "x_has_become_the_zombiemaster", pl:Name())
	util.PrintMessageC(pl, translate.ClientGet(pl, "zm_move_instructions"), Color(255, 0, 0))

	pl:SetZMPoints(425)
	hook.Call("IncreaseResources", self, pl)

	self.Income_Time = CurTime() + GetConVar("zm_incometime"):GetInt()

	local spawn = hook.Call("PlayerSelectTeamSpawn", self, TEAM_ZOMBIEMASTER, pl)
	if spawn then
		pl:SetPos(spawn:GetPos())
		pl:SetAngles(spawn:GetAngles())
	end
end

function GM:GetZombieMasterVolunteer()
	if GetConVar("zm_debug_nozombiemaster"):GetBool() then return nil end
	if team.NumPlayers(TEAM_ZOMBIEMASTER) >= 1 then return end
	
	local iHighest = -1
	for _, pl in pairs(player.GetAll()) do
		if IsValid(pl) and pl.m_iZMPriority and pl.m_iZMPriority > iHighest and pl:GetInfoNum("zm_preference", 0) == 1 then
			iHighest = pl.m_iZMPriority
		end
	end
	
	local ZMList = {}
	for _, pl in pairs(player.GetAll()) do
		if IsValid(pl) and pl.m_iZMPriority and pl.m_iZMPriority == iHighest and pl:GetInfoNum("zm_preference", 0) == 1 then
			table.insert(ZMList, pl)
		end
	end
	
	local pl = nil
	if #ZMList > 0 then
		pl = ZMList[math.random(#ZMList)]
	else
		local players = player.GetAll()
		pl = players[math.random(#players)]
	end
	
	return pl
end

function GM:AllowPlayerPickup(pl, ent)
	return false
end

function GM:PlayerCanHearPlayersVoice(listener, talker)
	return true, false
end

function GM:FindUseEntity(ply, defaultEnt)
	if not IsValid(defaultEnt) then
		local tr = util.TraceHull({
			start = ply:EyePos(),
			endpos = ply:EyePos() + ply:EyeAngles():Forward() * 64,
			mins = Vector(-8, -8, -8),
			maxs = Vector(8, 8, 8),	
			mask = bit.bor(MASK_SHOT, CONTENTS_GRATE),
			filter = player.GetAll()
		})
		local ent = tr.Entity
		
		if IsValid(ent) then 
			return ent 
		end
	end
	
	return defaultEnt
end

function GM:PlayerUse(pl, ent)
	if not pl:Alive() or pl:IsZM() or pl:IsSpectator() then return false end
	if ent:IsPlayerHolding() then return false end

	local entclass = ent:GetClass()
	if entclass == "prop_door_rotating" then
		if CurTime() < (ent.m_AntiDoorSpam or 0) then
			return false
		end
		ent.m_AntiDoorSpam = CurTime() + 0.85
    elseif pl:IsSurvivor() then
		local phys = ent:GetPhysicsObject()
		if ent:GetMoveType() == MOVETYPE_VPHYSICS and IsValid(phys) and phys:IsMoveable() and player_manager.RunClass(pl, "AllowPickup", ent) then	
			local washolding = ent:IsPlayerHolding()
			DropEntityIfHeld(ent)
			ent:SetCollisionGroup(ent._OldCG or ent:GetCollisionGroup())
			ent._OldCG = nil
			
			if washolding then return false end
			
            if not ent:IsPlayerHolding() then
				pl:PickupObject(ent)
				pl.HeldObject = ent
				ent._OldCG = ent:GetCollisionGroup()
				ent:SetCollisionGroup(COLLISION_GROUP_WEAPON)
            end
        end
	end

	return true
end

function GM:PlayerSwitchFlashlight(pl, newstate)
	return pl:IsSurvivor()
end

function GM:PlayerCanPickupWeapon(pl, ent)
	return player_manager.RunClass(pl, "CanPickupWeapon", ent)
end

function GM:PlayerCanPickupItem(pl, item)
	return player_manager.RunClass(pl, "CanPickupItem", item)
end

function GM:SetZMSelection(value)
	SetSharedBool("zm_zmselection_start", value)
end

function GM:SetCurZombiePop(amount)
	if amount < 0 then amount = 0 end
	SetSharedInt("m_iZombiePopCount", amount)
end

function GM:SetRoundActive(active)
    SetSharedBool("zm_round_active", active)
end

function GM:SetRoundStart(active)
    SetSharedBool("zm_round_start", active)
end

function GM:SetRoundEnd(active)
    SetSharedBool("zm_round_ended", active)
end

function GM:AddCurZombiePop(amount)
	self:SetCurZombiePop(self:GetCurZombiePop() + amount)
end

function GM:TakeCurZombiePop(amount)
	self:SetCurZombiePop(self:GetCurZombiePop() - amount)
end

function GM:SpawnZombie(pZM, entname, origin, angles, cost, bHidden)
	local tab = self:GetZombieData(entname)
	if not tab then return NULL end
	
	local popcost = tab.PopCost
	if (self:GetCurZombiePop() + popcost) > self:GetMaxZombiePop() then
		pZM:PrintTranslatedMessage(HUD_PRINTCENTER, "population_limit_reached")
		return NULL
	end

	local pZombie = ents.Create(entname)

	if IsValid(pZombie) then
		if tab.SpawnFlags then
			pZombie:SetKeyValue("spawnflags", tab.SpawnFlags)
		end
		
		pZombie:SetKeyValue("crabcount", 0)
		
		pZombie:SetPos(origin)
		pZombie:SetOwner(pZM)
		
		local tr = util.TraceHull({
			start = origin,
			endpos = origin + -angles:Up() * 10000,
			maxs = Vector(13, 13, 72),
			mins = Vector(-13, -13, 0),
			mask = MASK_NPCSOLID
		})
		if tr.Hit and tr.HitWorld and not tr.HitSky then
			pZombie:SetPos(tr.HitPos + Vector(0, 0, 12))
		end
		
		angles.x = 0.0
		angles.z = 0.0
		pZombie:SetAngles(angles)

		pZombie:Spawn()
		pZombie:Activate()
		
		if not bHidden then
			pZombie:Fire("Wake")
			pZombie:SetNPCState(NPC_STATE_ALERT)
			pZombie:CheckForEnemies()
		end
		
		self:CallZombieFunction(entname, "OnSpawned", pZombie)
		
		pZM:TakeZMPoints(cost)
		self:AddCurZombiePop(popcost)

		return pZombie
	end
	
	return NULL
end

function GM:AddResources()
	resource.AddFile( "materials/background01.vtf" )
	resource.AddFile( "materials/bboard/zm_bboard_batt.vmt" )
	resource.AddFile( "materials/bboard/zm_bboard_batt.vtf" )
	resource.AddFile( "materials/bboard/zm_bboard_btyre.vmt" )
	resource.AddFile( "materials/bboard/zm_bboard_btyre.vtf" )
	resource.AddFile( "materials/bboard/zm_bboard_fcan1.vmt" )
	resource.AddFile( "materials/bboard/zm_bboard_fcan1.vtf" )
	resource.AddFile( "materials/bboard/zm_bboard_fcan2.vmt" )
	resource.AddFile( "materials/bboard/zm_bboard_fcan2.vtf" )
	resource.AddFile( "materials/bboard/zm_bboard_ftyre.vmt" )
	resource.AddFile( "materials/bboard/zm_bboard_ftyre.vtf" )
	resource.AddFile( "materials/bboard/zm_bboard_items.vmt" )
	resource.AddFile( "materials/bboard/zm_bboard_items.vtf" )
	resource.AddFile( "materials/concrete/concretefloor010b_nobump.vmt" )
	resource.AddFile( "materials/concrete/concretefloor013c_nobump.vmt" )
	resource.AddFile( "materials/concrete/concretefloor028c_nobump.vmt" )
	resource.AddFile( "materials/concrete/concretefloor037b_nobump.vmt" )
	resource.AddFile( "materials/concrete/concretefloor039a_nobump.vmt" )
	resource.AddFile( "materials/concrete/concretefloor039b_nobump.vmt" )
	resource.AddFile( "materials/concrete/concretewall004b_nobump.vmt" )
	resource.AddFile( "materials/concrete/concretewall004c_nobump.vmt" )
	resource.AddFile( "materials/containers/metalcrate001a.vmt" )
	resource.AddFile( "materials/containers/metalcrate001a.vtf" )
	resource.AddFile( "materials/containers/metalcrate001b.vmt" )
	resource.AddFile( "materials/containers/metalcrate001b.vtf" )
	resource.AddFile( "materials/containers/metalcrate001c.vmt" )
	resource.AddFile( "materials/containers/metalcrate001c.vtf" )
	resource.AddFile( "materials/containers/metalcrate001d.vmt" )
	resource.AddFile( "materials/containers/metalcrate001d.vtf" )
	resource.AddFile( "materials/containers/metalcrate002a.vmt" )
	resource.AddFile( "materials/containers/metalcrate002a.vtf" )
	resource.AddFile( "materials/containers/metalcrate002b.vmt" )
	resource.AddFile( "materials/containers/metalcrate002b.vtf" )
	resource.AddFile( "materials/containers/metalcrate002c.vmt" )
	resource.AddFile( "materials/containers/metalcrate002c.vtf" )
	resource.AddFile( "materials/containers/metalcrate002d.vmt" )
	resource.AddFile( "materials/containers/metalcrate002d.vtf" )
	resource.AddFile( "materials/containers/metalcrate004d.vmt" )
	resource.AddFile( "materials/containers/metalcrate004d.vtf" )
	resource.AddFile( "materials/containers/metalcrate005a.vmt" )
	resource.AddFile( "materials/containers/metalcrate005a.vtf" )
	resource.AddFile( "materials/containers/metalcrate006a.vmt" )
	resource.AddFile( "materials/containers/metalcrate006a.vtf" )
	resource.AddFile( "materials/containers/metalcrate007a.vmt" )
	resource.AddFile( "materials/containers/metalcrate007a.vtf" )
	resource.AddFile( "materials/containers/metalcrate008a.vmt" )
	resource.AddFile( "materials/containers/metalcrate008a.vtf" )
	resource.AddFile( "materials/containers/metalcrate009a.vmt" )
	resource.AddFile( "materials/containers/metalcrate009a.vtf" )
	resource.AddFile( "materials/containers/metalcrate010a.vmt" )
	resource.AddFile( "materials/containers/metalcrate010a.vtf" )
	resource.AddFile( "materials/containers/picrate_512_clean.vmt" )
	resource.AddFile( "materials/containers/picrate_512_clean.vtf" )
	resource.AddFile( "materials/containers/picrate_512_het.vmt" )
	resource.AddFile( "materials/containers/picrate_512_het.vtf" )
	resource.AddFile( "materials/containers/picrate_long.vtf" )
	resource.AddFile( "materials/containers/picrate_long_clean.vmt" )
	resource.AddFile( "materials/containers/picrate_long_clean.vtf" )
	resource.AddFile( "materials/containers/picrate_long_mil.vmt" )
	resource.AddFile( "materials/containers/picrate_long_mil.vtf" )
	resource.AddFile( "materials/containers/warehouse_crate_1.vmt" )
	resource.AddFile( "materials/containers/warehouse_crate_1.vtf" )
	resource.AddFile( "materials/decals/decalgraffiti003a.vtf" )
	resource.AddFile( "materials/decals/decalgraffiti011a.vtf" )
	resource.AddFile( "materials/decals/decalgraffiti012a.vtf" )
	resource.AddFile( "materials/decals/decalgraffiti024a.vtf" )
	resource.AddFile( "materials/decals/decalgraffiti037a.vtf" )
	resource.AddFile( "materials/decals/decalgraffiti056a.vtf" )
	resource.AddFile( "materials/decals/decalgraffiti059a.vtf" )
	resource.AddFile( "materials/decals/decal_posterbreen.vtf" )
	resource.AddFile( "materials/decals/decal_posters002a.vtf" )
	resource.AddFile( "materials/decals/decal_posters003a.vtf" )
	resource.AddFile( "materials/decals/decal_posters005a.vtf" )
	resource.AddFile( "materials/decals/decal_posters006a.vtf" )
	resource.AddFile( "materials/decals/holes64_03.vtf" )
	resource.AddFile( "materials/decals/infwalldetail17.vtf" )
	resource.AddFile( "materials/decals/offpaintingb.vmt" )
	resource.AddFile( "materials/decals/omh_1.vmt" )
	resource.AddFile( "materials/decals/omh_1.vtf" )
	resource.AddFile( "materials/decals/omh_2.vmt" )
	resource.AddFile( "materials/decals/omh_2.vtf" )
	resource.AddFile( "materials/effects/strider_bulge_dudv.vtf" )
	resource.AddFile( "materials/effects/strider_bulge_dudv_dx60.vmt" )
	resource.AddFile( "materials/effects/strider_bulge_dx60.vmt" )
	resource.AddFile( "materials/effects/strider_bulge_normal.vtf" )
	resource.AddFile( "materials/effects/zm_arrows.vmt" )
	resource.AddFile( "materials/effects/zm_arrows.vtf" )
	resource.AddFile( "materials/effects/zm_healthring.vmt" )
	resource.AddFile( "materials/effects/zm_healthring.vtf" )
	resource.AddFile( "materials/effects/zm_nightvis.vmt" )
	resource.AddFile( "materials/effects/zm_nightvis.vtf" )
	resource.AddFile( "materials/effects/zm_refract.vmt" )
	resource.AddFile( "materials/effects/zm_ring.vmt" )
	resource.AddFile( "materials/effects/zm_ring.vtf" )
	resource.AddFile( "materials/effects/zombie_select.vmt" )
	resource.AddFile( "materials/effects/zombie_selection.vtf" )
	resource.AddFile( "materials/effects/zombie_selection_alt.vtf" )
	resource.AddFile( "materials/lawyer/cratewall_1.vmt" )
	resource.AddFile( "materials/lawyer/cratewall_1.vtf" )
	resource.AddFile( "materials/lawyer/cratewall_1_normal.vtf" )
	resource.AddFile( "materials/lawyer/cratewall_2.vmt" )
	resource.AddFile( "materials/lawyer/cratewall_2.vtf" )
	resource.AddFile( "materials/lawyer/cratewall_2_normal.vtf" )
	resource.AddFile( "materials/lawyer/cratewall_3.vmt" )
	resource.AddFile( "materials/lawyer/cratewall_3.vtf" )
	resource.AddFile( "materials/lawyer/cratewall_3_normal.vtf" )
	resource.AddFile( "materials/lawyer/cratewall_4.vmt" )
	resource.AddFile( "materials/lawyer/cratewall_4.vtf" )
	resource.AddFile( "materials/lawyer/cratewall_4_normal.vtf" )
	resource.AddFile( "materials/lawyer/crate_lawyer.vmt" )
	resource.AddFile( "materials/lawyer/crate_lawyer.vtf" )
	resource.AddFile( "materials/lawyer/crate_lawyer_normal.vtf" )
	resource.AddFile( "materials/lawyer/crate_lawyer_top.vmt" )
	resource.AddFile( "materials/lawyer/crate_lawyer_top.vtf" )
	resource.AddFile( "materials/lawyer/crate_lawyer_top_normal.vtf" )
	resource.AddFile( "materials/lawyer/serverroomcarpet.vmt" )
	resource.AddFile( "materials/lawyer/serverroomcarpet.vtf" )
	resource.AddFile( "materials/lawyer/serverroomcarpet_normal.vtf" )
	resource.AddFile( "materials/lawyer.vtf" )
	resource.AddFile( "materials/lostcoast/models/props_monastery/interior_dome_wall_window.vmt" )
	resource.AddFile( "materials/lostcoast/models/props_monastery/interior_dome_wall_window.vtf" )
	resource.AddFile( "materials/lostcoast/models/props_monastery/interior_dome_wall_window_dx60.vmt" )
	resource.AddFile( "materials/lostcoast/models/props_monastery/interior_dome_wall_window_normal.vtf" )
	resource.AddFile( "materials/lostcoast/models/props_monastery/monastery_stain_window001a.vmt" )
	resource.AddFile( "materials/lostcoast/models/props_monastery/monastery_stain_window001a.vtf" )
	resource.AddFile( "materials/lostcoast/models/props_monastery/monastery_stain_window001a_dx60.vmt" )
	resource.AddFile( "materials/lostcoast/models/props_monastery/monastery_stain_window001a_normal.vtf" )
	resource.AddFile( "materials/metal/citadel_metalwall077a_nospec.vmt" )
	resource.AddFile( "materials/metal/citadel_metalwall077a_nospec.vtf" )
	resource.AddFile( "materials/metal/metalcrate001pi.vmt" )
	resource.AddFile( "materials/metal/metalcrate001pi.vtf" )
	resource.AddFile( "materials/metal/metalfilecabinet002a.vmt" )
	resource.AddFile( "materials/metal/metalfilecabinet002a.vtf" )
	resource.AddFile( "materials/metal/metalpipe003a.vmt" )
	resource.AddFile( "materials/metal/metalwall001a_nobump.vmt" )
	resource.AddFile( "materials/metal/metalwall001b_nobump.vmt" )
	resource.AddFile( "materials/metal/metalwall001d_nobump.vmt" )
	resource.AddFile( "materials/metal/metalwall001f_nobump.vmt" )
	resource.AddFile( "materials/metal/metalwall014a_nobump.vmt" )
	resource.AddFile( "materials/metal/metalwall018a_nobump.vmt" )
	resource.AddFile( "materials/metal/metalwall018b_nobump.vmt" )
	resource.AddFile( "materials/metal/metalwall018e_nobump.vmt" )
	resource.AddFile( "materials/metal/metalwall018f_nobump.vmt" )
	resource.AddFile( "materials/metal/metalwall021a_nobump.vmt" )
	resource.AddFile( "materials/metal/metalwall021b_nobump.vmt" )
	resource.AddFile( "materials/metal/metalwall021e_nobump.vmt" )
	resource.AddFile( "materials/metal/metalwall021f_nobump.vmt" )
	resource.AddFile( "materials/metal/metalwall026a_nobump.vmt" )
	resource.AddFile( "materials/metal/metalwall058a.vmt" )
	resource.AddFile( "materials/metal/metalwall058a.vtf" )
	resource.AddFile( "materials/models/blue.vmt" )
	resource.AddFile( "materials/models/blue.vtf" )
	resource.AddFile( "materials/models/glow.vmt" )
	resource.AddFile( "materials/models/glow.vtf" )
	resource.AddFile( "materials/models/glow_orange.vtf" )
	resource.AddFile( "materials/models/gold.vmt" )
	resource.AddFile( "materials/models/gold.vtf" )
	resource.AddFile( "materials/models/humans/female/group01/fem_survivor1.vmt" )
	resource.AddFile( "materials/models/humans/female/group01/fem_survivor2.vmt" )
	resource.AddFile( "materials/models/humans/female/group01/fem_survivor3.vmt" )
	resource.AddFile( "materials/models/humans/female/group01/fem_survivor4.vmt" )
	resource.AddFile( "materials/models/humans/female/group01/fem_survivor6.vmt" )
	resource.AddFile( "materials/models/humans/female/group01/fem_survivor7.vmt" )
	resource.AddFile( "materials/models/humans/female/group02/fem_survivor1.vmt" )
	resource.AddFile( "materials/models/humans/female/group02/fem_survivor1.vtf" )
	resource.AddFile( "materials/models/humans/female/group02/fem_survivor2.vmt" )
	resource.AddFile( "materials/models/humans/female/group02/fem_survivor2.vtf" )
	resource.AddFile( "materials/models/humans/female/group02/fem_survivor3.vmt" )
	resource.AddFile( "materials/models/humans/female/group02/fem_survivor3.vtf" )
	resource.AddFile( "materials/models/humans/female/group02/fem_survivor4.vmt" )
	resource.AddFile( "materials/models/humans/female/group02/fem_survivor4.vtf" )
	resource.AddFile( "materials/models/humans/female/group02/fem_survivor6.vmt" )
	resource.AddFile( "materials/models/humans/female/group02/fem_survivor6.vtf" )
	resource.AddFile( "materials/models/humans/female/group02/fem_survivor7.vmt" )
	resource.AddFile( "materials/models/humans/female/group02/fem_survivor7.vtf" )
	resource.AddFile( "materials/models/humans/male/group02/citizen_sheet_pi.vmt" )
	resource.AddFile( "materials/models/humans/male/group02/citizen_sheet_pi.vtf" )
	resource.AddFile( "materials/models/humans/male/group02/citizen_sheet_pi_normal.vtf" )
	resource.AddFile( "materials/models/humans/male/group02/pi_facemap.vmt" )
	resource.AddFile( "materials/models/humans/male/group02/pi_facemap.vtf" )
	resource.AddFile( "materials/models/items/revolverammo.vmt" )
	resource.AddFile( "materials/models/items/revolverammo.vtf" )
	resource.AddFile( "materials/models/largedoor_right.vmt" )
	resource.AddFile( "materials/models/largedoor_right.vtf" )
	resource.AddFile( "materials/models/null.vmt" )
	resource.AddFile( "materials/models/null.vtf" )
	resource.AddFile( "materials/models/orange.vmt" )
	resource.AddFile( "materials/models/props/bell.vmt" )
	resource.AddFile( "materials/models/props/bell.vtf" )
	resource.AddFile( "materials/models/props/deathball_sheet.vmt" )
	resource.AddFile( "materials/models/props/deathball_sheet.vtf" )
	resource.AddFile( "materials/models/props/metalceiling005a.vmt" )
	resource.AddFile( "materials/models/props/metalceiling005a.vtf" )
	resource.AddFile( "materials/models/props/metalceiling005a_normal.vtf" )
	resource.AddFile( "materials/models/props/pew.vmt" )
	resource.AddFile( "materials/models/props/pew.vtf" )
	resource.AddFile( "materials/models/props_c17/frame002a_skin2.vtf" )
	resource.AddFile( "materials/models/props_c17/frame002a_skin3.vtf" )
	resource.AddFile( "materials/models/props_c17/frame002a_skin4.vtf" )
	resource.AddFile( "materials/models/props_c17/frame002a_skin5.vtf" )
	resource.AddFile( "materials/models/props_c17/frame002a_skin6.vtf" )
	resource.AddFile( "materials/models/props_c17/oil_drum001_splode.vmt" )
	resource.AddFile( "materials/models/props_c17/oil_drum001_splode.vtf" )
	resource.AddFile( "materials/models/props_interiors/sodamachine01a.vmt" )
	resource.AddFile( "materials/models/props_interiors/sodamachine01a.vtf" )
	resource.AddFile( "materials/models/props_junk/garbage003a_01.vtf" )
	resource.AddFile( "materials/models/props_junk/popcan01a.vtf" )
	resource.AddFile( "materials/models/props_junk/popcan02a.vtf" )
	resource.AddFile( "materials/models/props_junk/popcan03a.vtf" )
	resource.AddFile( "materials/models/props_lab/bewaredog.vtf" )
	resource.AddFile( "materials/models/props_lab/clipboard_sheet.vtf" )
	resource.AddFile( "materials/models/props_lab/computer_disp.vtf" )
	resource.AddFile( "materials/models/props_lab/corkboard001_sheet.vtf" )
	resource.AddFile( "materials/models/props_lab/corkboard002_sheet.vtf" )
	resource.AddFile( "materials/models/props_lab/photo_group001a.vtf" )
	resource.AddFile( "materials/models/props_lab/photo_group002a.vtf" )
	resource.AddFile( "materials/models/props_lab/security_screen.vtf" )
	resource.AddFile( "materials/models/props_lab/security_screens.vtf" )
	resource.AddFile( "materials/models/props_lab/workspace_sheet.vtf" )
	resource.AddFile( "materials/models/props_vehicles/apc001.vmt" )
	resource.AddFile( "materials/models/props_vehicles/apc001.vtf" )
	resource.AddFile( "materials/models/props_vehicles/apc_tire001.vmt" )
	resource.AddFile( "materials/models/props_vehicles/apc_tire001.vtf" )
	resource.AddFile( "materials/models/red.vmt" )
	resource.AddFile( "materials/models/red.vtf" )
	resource.AddFile( "materials/models/red2.vmt" )
	resource.AddFile( "materials/models/ship1/largedoor_left.vmt" )
	resource.AddFile( "materials/models/ship1/largedoor_left.vtf" )
	resource.AddFile( "materials/models/ship1/largedoor_right.vmt" )
	resource.AddFile( "materials/models/ship1/largedoor_right.vtf" )
	resource.AddFile( "materials/models/shotgun/casing01.vmt" )
	resource.AddFile( "materials/models/shotgun/casing01.vtf" )
	resource.AddFile( "materials/models/shotgun/shotgun_zm_diffuse.vmt" )
	resource.AddFile( "materials/models/shotgun/shotgun_zm_diffuse.vtf" )
	resource.AddFile( "materials/models/shotgun/shotgun_zm_exp.vtf" )
	resource.AddFile( "materials/models/shotgun/shotgun_zm_normals.vtf" )
	resource.AddFile( "materials/models/shotgun/shotgun_zm_normals_env.vtf" )
	resource.AddFile( "materials/models/shotgun/v_hand_sheet.vmt" )
	resource.AddFile( "materials/models/shotgun/v_hand_sheet.vtf" )
	resource.AddFile( "materials/models/shotgun/v_hand_sheet_normal.vtf" )
	resource.AddFile( "materials/models/silver.vmt" )
	resource.AddFile( "materials/models/silver.vtf" )
	resource.AddFile( "materials/models/weapons/flashlight_zm/flashlight3rd_diffuse.vmt" )
	resource.AddFile( "materials/models/weapons/flashlight_zm/flashlight3rd_diffuse.vtf" )
	resource.AddFile( "materials/models/weapons/flashlight_zm/flashlight_diffuse.vmt" )
	resource.AddFile( "materials/models/weapons/flashlight_zm/flashlight_diffuse.vtf" )
	resource.AddFile( "materials/models/weapons/flashlight_zm/flashlight_normal.vtf" )
	resource.AddFile( "materials/models/weapons/hands_zm/v_hand_sheet.vmt" )
	resource.AddFile( "materials/models/weapons/hands_zm/v_hand_sheet_zm.vmt" )
	resource.AddFile( "materials/models/weapons/hands_zm/v_hand_sheet_zm.vtf" )
	resource.AddFile( "materials/models/weapons/hands_zm/v_hand_sheet_zm_normal.vtf" )
	resource.AddFile( "materials/models/weapons/molotov_zm/fire.vmt" )
	resource.AddFile( "materials/models/weapons/molotov_zm/fireoff.vmt" )
	resource.AddFile( "materials/models/weapons/molotov_zm/fireoff.vtf" )
	resource.AddFile( "materials/models/weapons/molotov_zm/molotovfull_diffuse.vmt" )
	resource.AddFile( "materials/models/weapons/molotov_zm/molotovfull_diffuse.vtf" )
	resource.AddFile( "materials/models/weapons/molotov_zm/molotovfull_normal.vtf" )
	resource.AddFile( "materials/models/weapons/molotov_zm/molotov_3rddiffuse.vmt" )
	resource.AddFile( "materials/models/weapons/molotov_zm/molotov_3rddiffuse.vtf" )
	resource.AddFile( "materials/models/weapons/molotov_zm/molotov_3rdnormalsmap.vtf" )
	resource.AddFile( "materials/models/weapons/pistol_zm/pistol3rd_diffuse.vmt" )
	resource.AddFile( "materials/models/weapons/pistol_zm/pistol3rd_diffuse.vtf" )
	resource.AddFile( "materials/models/weapons/pistol_zm/pistol3rd_normal.vtf" )
	resource.AddFile( "materials/models/weapons/pistol_zm/pistol_diffuse.vmt" )
	resource.AddFile( "materials/models/weapons/pistol_zm/pistol_diffuse.vtf" )
	resource.AddFile( "materials/models/weapons/pistol_zm/pistol_normal.vtf" )
	resource.AddFile( "materials/models/weapons/rifle_zm/rifle_zm_3rd.vmt" )
	resource.AddFile( "materials/models/weapons/rifle_zm/rifle_zm_3rd.vtf" )
	resource.AddFile( "materials/models/weapons/rifle_zm/rifle_zm_3rd_specular_mask.vtf" )
	resource.AddFile( "materials/models/weapons/rifle_zm/rifle_zm_cartridge.vmt" )
	resource.AddFile( "materials/models/weapons/rifle_zm/rifle_zm_cartridge.vtf" )
	resource.AddFile( "materials/models/weapons/rifle_zm/rifle_zm_diffuse.vmt" )
	resource.AddFile( "materials/models/weapons/rifle_zm/rifle_zm_diffuse.vtf" )
	resource.AddFile( "materials/models/weapons/rifle_zm/rifle_zm_normal.vtf" )
	resource.AddFile( "materials/models/weapons/shotgun_zm/shotgun4.vtf" )
	resource.AddFile( "materials/models/weapons/shotgun_zm/shotgun4diffuse.vmt" )
	resource.AddFile( "materials/models/weapons/shotgun_zm/shotgun4diffuse.vtf" )
	resource.AddFile( "materials/models/weapons/sledgehammer_zm/sledgehammer.vmt" )
	resource.AddFile( "materials/models/weapons/sledgehammer_zm/sledgehammer_diffuse.vtf" )
	resource.AddFile( "materials/models/weapons/sledgehammer_zm/sledgehammer_normal.vtf" )
	resource.AddFile( "materials/models/weapons/sledgehammer_zm/sledge_sheet.vmt" )
	resource.AddFile( "materials/models/weapons/sledgehammer_zm/sledge_sheet.vtf" )
	resource.AddFile( "materials/models/weapons/sledgehammer_zm/sledge_sheet_nrml.vtf" )
	resource.AddFile( "materials/models/weapons/v_mac_zm/mac10_sheet.vmt" )
	resource.AddFile( "materials/models/weapons/v_mac_zm/mac10_sheet.vtf" )
	resource.AddFile( "materials/models/weapons/v_mac_zm/mac10_sheet_spec.vtf" )
	resource.AddFile( "materials/models/weapons/v_revolver_zm/v_revolver_sheet.vmt" )
	resource.AddFile( "materials/models/weapons/v_revolver_zm/v_revolver_sheet.vtf" )
	resource.AddFile( "materials/models/weapons/v_revolver_zm/v_revolver_sheet_nrml.vtf" )
	resource.AddFile( "materials/models/weapons/v_shotgun/remington_sheet.vmt" )
	resource.AddFile( "materials/models/weapons/v_shotgun/remington_sheet.vtf" )
	resource.AddFile( "materials/models/weapons/v_shotgun/remington_sheet_spec.vtf" )
	resource.AddFile( "materials/models/weapons/v_slam/new lense.vmt" )
	resource.AddFile( "materials/models/weapons/v_slam/new lense.vtf" )
	resource.AddFile( "materials/models/weapons/v_slam/new light1.vmt" )
	resource.AddFile( "materials/models/weapons/v_slam/new light1.vtf" )
	resource.AddFile( "materials/models/weapons/v_slam/new light2.vmt" )
	resource.AddFile( "materials/models/weapons/v_slam/new light2.vtf" )
	resource.AddFile( "materials/models/weapons/v_slam/new slam.vmt" )
	resource.AddFile( "materials/models/weapons/v_slam/new slam.vtf" )
	resource.AddFile( "materials/models/weapons/v_slam/retexture trigger.vmt" )
	resource.AddFile( "materials/models/weapons/v_slam/retexture trigger.vtf" )
	resource.AddFile( "materials/models/weapons/v_slam/v_slam.vmt" )
	resource.AddFile( "materials/models/weapons/v_slam/v_slam.vtf" )
	resource.AddFile( "materials/models/weapons/v_slam/v_slam_normal.vtf" )
	resource.AddFile( "materials/models/weapons/v_smg/mac10_sheet.vmt" )
	resource.AddFile( "materials/models/weapons/v_smg/mac10_sheet.vtf" )
	resource.AddFile( "materials/models/weapons/v_smg/mac10_spec.vtf" )
	resource.AddFile( "materials/models/weapons/v_stunstick/v_stunstick_diffuse.vmt" )
	resource.AddFile( "materials/models/weapons/v_stunstick/v_stunstick_diffuse.vtf" )
	resource.AddFile( "materials/models/weapons/v_stunstick/v_stunstick_normal.vtf" )
	resource.AddFile( "materials/models/weapons/w_357/w_357.vmt" )
	resource.AddFile( "materials/models/weapons/w_357/w_357.vtf" )
	resource.AddFile( "materials/models/weapons/w_357/w_357_spec.vtf" )
	resource.AddFile( "materials/models/weapons/w_shotgun_zm/w_shotgun_zm.vmt" )
	resource.AddFile( "materials/models/weapons/w_shotgun_zm/w_shotgun_zm.vtf" )
	resource.AddFile( "materials/models/weapons/zm_pistol/pist_fiveseven.vmt" )
	resource.AddFile( "materials/models/weapons/zm_pistol/pist_fiveseven.vtf" )
	resource.AddFile( "materials/models/weapons/zm_pistol/pist_fiveseven_ref.vtf" )
	resource.AddFile( "materials/models/zombie/zombie_classic/art_facemap.vtf" )
	resource.AddFile( "materials/models/zombie/zombie_classic/mike_facemap.vtf" )
	resource.AddFile( "materials/models/zombie/zombie_classic/test_facemap.vtf" )
	resource.AddFile( "materials/models/zombie/zombie_classic_humantest/eyeball_l.vtf" )
	resource.AddFile( "materials/models/zombie/zombie_classic_humantest/pupil_l.vtf" )
	resource.AddFile( "materials/models/zombie_classic/art_facemap.vmt" )
	resource.AddFile( "materials/models/zombie_classic/art_facemap.vtf" )
	resource.AddFile( "materials/models/zombie_classic/citizen_sheet.vmt" )
	resource.AddFile( "materials/models/zombie_classic/citizen_sheet.vtf" )
	resource.AddFile( "materials/models/zombie_classic/citizen_sheet2.vmt" )
	resource.AddFile( "materials/models/zombie_classic/citizen_sheet2.vtf" )
	resource.AddFile( "materials/models/zombie_classic/citizen_sheet3.vmt" )
	resource.AddFile( "materials/models/zombie_classic/citizen_sheet3.vtf" )
	resource.AddFile( "materials/models/zombie_classic/corpse1.vmt" )
	resource.AddFile( "materials/models/zombie_classic/corpse1.vtf" )
	resource.AddFile( "materials/models/zombie_classic/dark_eyeball_l.vmt" )
	resource.AddFile( "materials/models/zombie_classic/dark_eyeball_r.vmt" )
	resource.AddFile( "materials/models/zombie_classic/erdim_cylmap.vmt" )
	resource.AddFile( "materials/models/zombie_classic/erdim_cylmap.vtf" )
	resource.AddFile( "materials/models/zombie_classic/eric_facemap.vmt" )
	resource.AddFile( "materials/models/zombie_classic/eric_facemap.vtf" )
	resource.AddFile( "materials/models/zombie_classic/eyeball_l.vmt" )
	resource.AddFile( "materials/models/zombie_classic/eyeball_l.vtf" )
	resource.AddFile( "materials/models/zombie_classic/eyeball_r.vmt" )
	resource.AddFile( "materials/models/zombie_classic/eyeball_r.vtf" )
	resource.AddFile( "materials/models/zombie_classic/joe_facemap.vmt" )
	resource.AddFile( "materials/models/zombie_classic/joe_facemap.vtf" )
	resource.AddFile( "materials/models/zombie_classic/mike_facemap.vmt" )
	resource.AddFile( "materials/models/zombie_classic/mike_facemap.vtf" )
	resource.AddFile( "materials/models/zombie_classic/pupil_l.vtf" )
	resource.AddFile( "materials/models/zombie_classic/pupil_r.vtf" )
	resource.AddFile( "materials/models/zombie_classic/sandro_facemap.vmt" )
	resource.AddFile( "materials/models/zombie_classic/sandro_facemap.vtf" )
	resource.AddFile( "materials/models/zombie_classic/ted_facemap.vmt" )
	resource.AddFile( "materials/models/zombie_classic/ted_facemap.vtf" )
	resource.AddFile( "materials/models/zombie_classic/vance_facemap.vmt" )
	resource.AddFile( "materials/models/zombie_classic/vance_facemap.vtf" )
	resource.AddFile( "materials/models/zombie_classic/van_facemap.vmt" )
	resource.AddFile( "materials/models/zombie_classic/van_facemap.vtf" )
	resource.AddFile( "materials/models/zombie_fast/corpse1.vmt" )
	resource.AddFile( "materials/models/zombie_fast/corpse1.vtf" )
	resource.AddFile( "materials/nature/blenddirtmud003a_nobump.vmt" )
	resource.AddFile( "materials/nature/rockwall006a_nobump.vmt" )
	resource.AddFile( "materials/plaster/plasterwall034a_nobump.vmt" )
	resource.AddFile( "materials/plaster/plasterwall034b_nobump.vmt" )
	resource.AddFile( "materials/plaster/plasterwall034d_nobump.vmt" )
	resource.AddFile( "materials/plaster/plasterwall034f_nobump.vmt" )
	resource.AddFile( "materials/postprocess/alpha.vtf" )
	resource.AddFile( "materials/postprocess/blend.vmt" )
	resource.AddFile( "materials/postprocess/blurx.vmt" )
	resource.AddFile( "materials/postprocess/blury.vmt" )
	resource.AddFile( "materials/postprocess/nightvision.vmt" )
	resource.AddFile( "materials/props/bell.vmt" )
	resource.AddFile( "materials/props/bell.vtf" )
	resource.AddFile( "materials/props/deathball_sheet.vmt" )
	resource.AddFile( "materials/props/deathball_sheet.vtf" )
	resource.AddFile( "materials/props/metalceiling005a.vmt" )
	resource.AddFile( "materials/props/metalceiling005a.vtf" )
	resource.AddFile( "materials/props/metalceiling005a_normal.vtf" )
	resource.AddFile( "materials/props/metalfilecabinet002a.vmt" )
	resource.AddFile( "materials/props/metalfilecabinet002a.vtf" )
	resource.AddFile( "materials/props/metalladder001.vmt" )
	resource.AddFile( "materials/props/metalladder001.vtf" )
	resource.AddFile( "materials/props/paperposter001a.vtf" )
	resource.AddFile( "materials/props/paperposter001b.vtf" )
	resource.AddFile( "materials/props/paperposter002a.vtf" )
	resource.AddFile( "materials/props/paperposter002b.vtf" )
	resource.AddFile( "materials/props/paperposter003a.vtf" )
	resource.AddFile( "materials/props/paperposter003b.vtf" )
	resource.AddFile( "materials/props/paperposter005a.vtf" )
	resource.AddFile( "materials/sign/redsign.vmt" )
	resource.AddFile( "materials/sign/redsign.vtf" )
	resource.AddFile( "materials/sign/whitesign.vmt" )
	resource.AddFile( "materials/sign/whitesign.vtf" )
	resource.AddFile( "materials/sprites/fire_greyscale.vtf" )
	resource.AddFile( "materials/sprites/fire_vm.vmt" )
	resource.AddFile( "materials/sprites/fire_vm_grey.vmt" )
	resource.AddFile( "materials/sprites/flamefromabove.vmt" )
	resource.AddFile( "materials/sprites/flamefromabove.vtf" )
	resource.AddFile( "materials/sprites/glow.vmt" )
	resource.AddFile( "materials/sprites/glow.vtf" )
	resource.AddFile( "materials/sprites/glow04_noz.vmt" )
	resource.AddFile( "materials/sprites/orangecore1.vmt" )
	resource.AddFile( "materials/sprites/orangecore2.vmt" )
	resource.AddFile( "materials/sprites/orangeflare1.vmt" )
	resource.AddFile( "materials/sprites/orangelight1.vmt" )
	resource.AddFile( "materials/sprites/orangelight1_noz.vmt" )
	resource.AddFile( "materials/sprites/orangetest.vmt" )
	resource.AddFile( "materials/temp/5446d717.vtf" )
	resource.AddFile( "materials/temp/7e52e0ac.vtf" )
	resource.AddFile( "materials/temp/ada7c148.vtf" )
	resource.AddFile( "materials/temp/e4e75983.vtf" )
	resource.AddFile( "materials/tile/tilefloor019a_nobump.vmt" )
	resource.AddFile( "materials/truckpic/truckpic (13).vmt" )
	resource.AddFile( "materials/truckpic/truckpic (14).vtf" )
	resource.AddFile( "materials/truckpic/truckpic.vmt" )
	resource.AddFile( "materials/truckpic/truckpic.vtf" )
	resource.AddFile( "materials/vgui/gfx/vgui/hl2mp_logo.vmt" )
	resource.AddFile( "materials/vgui/gfx/vgui/hl2mp_logo.vtf" )
	resource.AddFile( "materials/vgui/gfx/vgui/not_available.vmt" )
	resource.AddFile( "materials/vgui/gfx/vgui/not_available.vtf" )
	resource.AddFile( "materials/vgui/gfx/vgui/round_corner_ne.vmt" )
	resource.AddFile( "materials/vgui/gfx/vgui/round_corner_ne.vtf" )
	resource.AddFile( "materials/vgui/gfx/vgui/round_corner_nw.vmt" )
	resource.AddFile( "materials/vgui/gfx/vgui/round_corner_nw.vtf" )
	resource.AddFile( "materials/vgui/gfx/vgui/round_corner_se.vmt" )
	resource.AddFile( "materials/vgui/gfx/vgui/round_corner_se.vtf" )
	resource.AddFile( "materials/vgui/gfx/vgui/round_corner_sw.vmt" )
	resource.AddFile( "materials/vgui/gfx/vgui/round_corner_sw.vtf" )
	resource.AddFile( "materials/vgui/gfx/vgui/solid_background.vmt" )
	resource.AddFile( "materials/vgui/gfx/vgui/solid_background.vtf" )
	resource.AddFile( "materials/vgui/gfx/vgui/spray_bullseye.vmt" )
	resource.AddFile( "materials/vgui/gfx/vgui/spray_bullseye.vtf" )
	resource.AddFile( "materials/vgui/gfx/vgui/trans_background.vmt" )
	resource.AddFile( "materials/vgui/gfx/vgui/trans_background.vtf" )
	resource.AddFile( "materials/vgui/loading.vmt" )
	resource.AddFile( "materials/vgui/loading.vtf" )
	resource.AddFile( "materials/vgui/logos/back.vmt" )
	resource.AddFile( "materials/vgui/logos/back.vtf" )
	resource.AddFile( "materials/vgui/logos/brainfork.vmt" )
	resource.AddFile( "materials/vgui/logos/brainfork.vtf" )
	resource.AddFile( "materials/vgui/logos/cross.vmt" )
	resource.AddFile( "materials/vgui/logos/cross.vtf" )
	resource.AddFile( "materials/vgui/logos/decomposing.vmt" )
	resource.AddFile( "materials/vgui/logos/decomposing.vtf" )
	resource.AddFile( "materials/vgui/logos/eat.vmt" )
	resource.AddFile( "materials/vgui/logos/eat.vtf" )
	resource.AddFile( "materials/vgui/logos/no.vmt" )
	resource.AddFile( "materials/vgui/logos/no.vtf" )
	resource.AddFile( "materials/vgui/logos/pent.vmt" )
	resource.AddFile( "materials/vgui/logos/pent.vtf" )
	resource.AddFile( "materials/vgui/logos/pressure.vmt" )
	resource.AddFile( "materials/vgui/logos/pressure.vtf" )
	resource.AddFile( "materials/vgui/logos/repent.vmt" )
	resource.AddFile( "materials/vgui/logos/repent.vtf" )
	resource.AddFile( "materials/vgui/logos/rip.vmt" )
	resource.AddFile( "materials/vgui/logos/rip.vtf" )
	resource.AddFile( "materials/vgui/logos/skull.vmt" )
	resource.AddFile( "materials/vgui/logos/skull.vtf" )
	resource.AddFile( "materials/vgui/logos/spray_canned.vmt" )
	resource.AddFile( "materials/vgui/logos/spray_canned.vtf" )
	resource.AddFile( "materials/vgui/logos/spray_combine.vmt" )
	resource.AddFile( "materials/vgui/logos/spray_combine.vtf" )
	resource.AddFile( "materials/vgui/logos/spray_cop.vmt" )
	resource.AddFile( "materials/vgui/logos/spray_cop.vtf" )
	resource.AddFile( "materials/vgui/logos/spray_dog.vmt" )
	resource.AddFile( "materials/vgui/logos/spray_dog.vtf" )
	resource.AddFile( "materials/vgui/logos/spray_freeman.vmt" )
	resource.AddFile( "materials/vgui/logos/spray_freeman.vtf" )
	resource.AddFile( "materials/vgui/logos/spray_head.vmt" )
	resource.AddFile( "materials/vgui/logos/spray_head.vtf" )
	resource.AddFile( "materials/vgui/logos/spray_lambda.vmt" )
	resource.AddFile( "materials/vgui/logos/spray_lambda.vtf" )
	resource.AddFile( "materials/vgui/logos/spray_plumbed.vmt" )
	resource.AddFile( "materials/vgui/logos/spray_plumbed.vtf" )
	resource.AddFile( "materials/vgui/logos/spray_soldier.vmt" )
	resource.AddFile( "materials/vgui/logos/spray_soldier.vtf" )
	resource.AddFile( "materials/vgui/logos/ui/back.vmt" )
	resource.AddFile( "materials/vgui/logos/ui/brainfork.vmt" )
	resource.AddFile( "materials/vgui/logos/ui/cross.vmt" )
	resource.AddFile( "materials/vgui/logos/ui/decomposing.vmt" )
	resource.AddFile( "materials/vgui/logos/ui/eat.vmt" )
	resource.AddFile( "materials/vgui/logos/ui/no.vmt" )
	resource.AddFile( "materials/vgui/logos/ui/pent.vmt" )
	resource.AddFile( "materials/vgui/logos/ui/pressure.vmt" )
	resource.AddFile( "materials/vgui/logos/ui/repent.vmt" )
	resource.AddFile( "materials/vgui/logos/ui/rip.vmt" )
	resource.AddFile( "materials/vgui/logos/ui/skull.vmt" )
	resource.AddFile( "materials/vgui/logos/ui/spray_canned.vmt" )
	resource.AddFile( "materials/vgui/logos/ui/spray_combine.vmt" )
	resource.AddFile( "materials/vgui/logos/ui/spray_cop.vmt" )
	resource.AddFile( "materials/vgui/logos/ui/spray_dog.vmt" )
	resource.AddFile( "materials/vgui/logos/ui/spray_freeman.vmt" )
	resource.AddFile( "materials/vgui/logos/ui/spray_head.vmt" )
	resource.AddFile( "materials/vgui/logos/ui/spray_lambda.vmt" )
	resource.AddFile( "materials/vgui/logos/ui/walk.vmt" )
	resource.AddFile( "materials/vgui/logos/walk.vmt" )
	resource.AddFile( "materials/vgui/logos/walk.vtf" )
	resource.AddFile( "materials/vgui/miniarrows.vmt" )
	resource.AddFile( "materials/vgui/miniarrows.vtf" )
	resource.AddFile( "materials/vgui/miniceiling.vmt" )
	resource.AddFile( "materials/vgui/miniceiling.vtf" )
	resource.AddFile( "materials/vgui/minicrosshair.vmt" )
	resource.AddFile( "materials/vgui/minicrosshair.vtf" )
	resource.AddFile( "materials/vgui/minideletezombies.vmt" )
	resource.AddFile( "materials/vgui/minideletezombies.vtf" )
	resource.AddFile( "materials/vgui/minieye.vmt" )
	resource.AddFile( "materials/vgui/minieye.vtf" )
	resource.AddFile( "materials/vgui/minifigures.vmt" )
	resource.AddFile( "materials/vgui/minifigures.vtf" )
	resource.AddFile( "materials/vgui/minigroupadd.vmt" )
	resource.AddFile( "materials/vgui/minigroupadd.vtf" )
	resource.AddFile( "materials/vgui/minigroupselect.vmt" )
	resource.AddFile( "materials/vgui/minigroupselect.vtf" )
	resource.AddFile( "materials/vgui/miniselectall.vmt" )
	resource.AddFile( "materials/vgui/miniselectall.vtf" )
	resource.AddFile( "materials/vgui/minishield.vmt" )
	resource.AddFile( "materials/vgui/minishield.vtf" )
	resource.AddFile( "materials/vgui/minishockwave.vmt" )
	resource.AddFile( "materials/vgui/minishockwave.vtf" )
	resource.AddFile( "materials/vgui/miniskull.vmt" )
	resource.AddFile( "materials/vgui/miniskull.vtf" )
	resource.AddFile( "materials/vgui/minispotcreate.vmt" )
	resource.AddFile( "materials/vgui/minispotcreate.vtf" )
	resource.AddFile( "materials/vgui/playermodels/humans/group02/female_01.vmt" )
	resource.AddFile( "materials/vgui/playermodels/humans/group02/female_01.vtf" )
	resource.AddFile( "materials/vgui/playermodels/humans/group02/female_02.vmt" )
	resource.AddFile( "materials/vgui/playermodels/humans/group02/female_02.vtf" )
	resource.AddFile( "materials/vgui/playermodels/humans/group02/female_03.vmt" )
	resource.AddFile( "materials/vgui/playermodels/humans/group02/female_03.vtf" )
	resource.AddFile( "materials/vgui/playermodels/humans/group02/female_04.vmt" )
	resource.AddFile( "materials/vgui/playermodels/humans/group02/female_04.vtf" )
	resource.AddFile( "materials/vgui/playermodels/humans/group02/female_06.vmt" )
	resource.AddFile( "materials/vgui/playermodels/humans/group02/female_06.vtf" )
	resource.AddFile( "materials/vgui/playermodels/humans/group02/female_07.vmt" )
	resource.AddFile( "materials/vgui/playermodels/humans/group02/female_07.vtf" )
	resource.AddFile( "materials/vgui/playermodels/humans/group02/male_01.vmt" )
	resource.AddFile( "materials/vgui/playermodels/humans/group02/male_01.vtf" )
	resource.AddFile( "materials/vgui/playermodels/humans/group02/male_02.vmt" )
	resource.AddFile( "materials/vgui/playermodels/humans/group02/male_02.vtf" )
	resource.AddFile( "materials/vgui/playermodels/humans/group02/male_03.vmt" )
	resource.AddFile( "materials/vgui/playermodels/humans/group02/male_03.vtf" )
	resource.AddFile( "materials/vgui/playermodels/humans/group02/male_04.vmt" )
	resource.AddFile( "materials/vgui/playermodels/humans/group02/male_04.vtf" )
	resource.AddFile( "materials/vgui/playermodels/humans/group02/male_05.vmt" )
	resource.AddFile( "materials/vgui/playermodels/humans/group02/male_05.vtf" )
	resource.AddFile( "materials/vgui/playermodels/humans/group02/male_06.vmt" )
	resource.AddFile( "materials/vgui/playermodels/humans/group02/male_06.vtf" )
	resource.AddFile( "materials/vgui/playermodels/humans/group02/male_07.vmt" )
	resource.AddFile( "materials/vgui/playermodels/humans/group02/male_07.vtf" )
	resource.AddFile( "materials/vgui/playermodels/humans/group02/male_08.vmt" )
	resource.AddFile( "materials/vgui/playermodels/humans/group02/male_08.vtf" )
	resource.AddFile( "materials/vgui/playermodels/humans/group02/male_09.vmt" )
	resource.AddFile( "materials/vgui/playermodels/humans/group02/male_09.vtf" )
	resource.AddFile( "materials/vgui/playermodels/male_lawyer.vmt" )
	resource.AddFile( "materials/vgui/playermodels/male_lawyer.vtf" )
	resource.AddFile( "materials/vgui/playermodels/male_pi.vmt" )
	resource.AddFile( "materials/vgui/playermodels/male_pi.vtf" )
	resource.AddFile( "materials/vgui/zombies/banshee.vtf" )
	resource.AddFile( "materials/vgui/zombies/banshee_small.vtf" )
	resource.AddFile( "materials/vgui/zombies/drifter.vtf" )
	resource.AddFile( "materials/vgui/zombies/drifter_small.vtf" )
	resource.AddFile( "materials/vgui/zombies/hulk.vtf" )
	resource.AddFile( "materials/vgui/zombies/hulk_small.vtf" )
	resource.AddFile( "materials/vgui/zombies/immolator.vtf" )
	resource.AddFile( "materials/vgui/zombies/immolator_small.vtf" )
	resource.AddFile( "materials/vgui/zombies/info_banshee.vmt" )
	resource.AddFile( "materials/vgui/zombies/info_drifter.vmt" )
	resource.AddFile( "materials/vgui/zombies/info_hulk.vmt" )
	resource.AddFile( "materials/vgui/zombies/info_immolator.vmt" )
	resource.AddFile( "materials/vgui/zombies/info_shambler.vmt" )
	resource.AddFile( "materials/vgui/zombies/queue_banshee.vmt" )
	resource.AddFile( "materials/vgui/zombies/queue_drifter.vmt" )
	resource.AddFile( "materials/vgui/zombies/queue_hulk.vmt" )
	resource.AddFile( "materials/vgui/zombies/queue_immolator.vmt" )
	resource.AddFile( "materials/vgui/zombies/queue_shambler.vmt" )
	resource.AddFile( "materials/vgui/zombies/shambler.vtf" )
	resource.AddFile( "materials/vgui/zombies/shambler_small.vtf" )
	resource.AddFile( "materials/wood/woodshelf003a.vmt" )
	resource.AddFile( "materials/wood/woodshelf003a.vtf" )
	resource.AddFile( "materials/zm_overlay.png" )
	resource.AddFile( "models/alphatest.mdl" )
	resource.AddFile( "models/humans/zm_draggy.mdl" )
	resource.AddFile( "models/items/revolverammo.mdl" )
	resource.AddFile( "models/male_pi.mdl" )
	resource.AddFile( "models/manipulatable.mdl" )
	resource.AddFile( "models/props/bell.mdl" )
	resource.AddFile( "models/props/deathball.mdl" )
	resource.AddFile( "models/props/pew.mdl" )
	resource.AddFile( "models/props/zm_metalladder001.mdl" )
	resource.AddFile( "models/props_c17/oildrum001_asplode.mdl" )
	resource.AddFile( "models/props_vehicles/apc001.mdl" )
	resource.AddFile( "models/props_vehicles/apc_tire001.mdl" )
	resource.AddFile( "models/props_vehicles/zmapc001.mdl" )
	resource.AddFile( "models/props_vehicles/zmapc_tire001.mdl" )
	resource.AddFile( "models/rallypoint.mdl" )
	resource.AddFile( "models/spawnnode.mdl" )
	resource.AddFile( "models/trap.mdl" )
	resource.AddFile( "models/weapons/c_fists_zm.mdl" )
	resource.AddFile( "models/weapons/c_flashlight_zm.mdl" )
	resource.AddFile( "models/weapons/c_improvised_zm.mdl" )
	resource.AddFile( "models/weapons/c_mac_zm.mdl" )
	resource.AddFile( "models/weapons/c_molotov_zm.mdl" )
	resource.AddFile( "models/weapons/c_pistol_zm.mdl" )
	resource.AddFile( "models/weapons/c_revolver_zm.mdl" )
	resource.AddFile( "models/weapons/c_rifle_zm.mdl" )
	resource.AddFile( "models/weapons/c_shotgun_zm.mdl" )
	resource.AddFile( "models/weapons/c_sledgehammer_zm.mdl" )
	resource.AddFile( "models/weapons/flashlight3rd_zm.mdl" )
	resource.AddFile( "models/weapons/invisible_vm.mdl" )
	resource.AddFile( "models/weapons/molotov3rd_zm.mdl" )
	resource.AddFile( "models/weapons/pistol3rd_zm.mdl" )
	resource.AddFile( "models/weapons/rifle_zm_3rd.mdl" )
	resource.AddFile( "models/weapons/shotgun_zm_3rd.mdl" )
	resource.AddFile( "models/weapons/sledgehammer3rd_zm.mdl" )
	resource.AddFile( "models/weapons/smg_zm_3rd.mdl" )
	resource.AddFile( "models/weapons/w_null.mdl" )
	resource.AddFile( "models/weapons/w_shotgun_zm.mdl" )
	resource.AddFile( "models/zombie/burnzie.mdl" )
	resource.AddFile( "models/zombie/hulk.mdl" )
	resource.AddFile( "models/zombie/zm_classic.mdl" )
	resource.AddFile( "models/zombie/zm_classic_01.mdl" )
	resource.AddFile( "models/zombie/zm_classic_02.mdl" )
	resource.AddFile( "models/zombie/zm_classic_03.mdl" )
	resource.AddFile( "models/zombie/zm_classic_04.mdl" )
	resource.AddFile( "models/zombie/zm_classic_05.mdl" )
	resource.AddFile( "models/zombie/zm_classic_06.mdl" )
	resource.AddFile( "models/zombie/zm_classic_07.mdl" )
	resource.AddFile( "models/zombie/zm_classic_08.mdl" )
	resource.AddFile( "models/zombie/zm_classic_09.mdl" )
	resource.AddFile( "models/zombie/zm_classic_10.mdl" )
	resource.AddFile( "models/zombie/zm_fast.mdl" )
	resource.AddFile( "models/zombiespawner.mdl" )
	resource.AddFile( "particles/zm_blood.pcf" )
	resource.AddFile( "resource/fonts/typenoksidi.ttf" )
	resource.AddFile( "resource/fonts/zombiemaster.ttf" )
	resource.AddFile( "sound/ambient/lightning.wav" )
	resource.AddFile( "sound/bell/bell1.wav" )
	resource.AddFile( "sound/common/talk.wav" )
	resource.AddFile( "sound/npc/banshee/breathe_loop1.wav" )
	resource.AddFile( "sound/npc/banshee/claw_miss1.wav" )
	resource.AddFile( "sound/npc/banshee/claw_miss2.wav" )
	resource.AddFile( "sound/npc/banshee/claw_strike1.wav" )
	resource.AddFile( "sound/npc/banshee/claw_strike2.wav" )
	resource.AddFile( "sound/npc/banshee/claw_strike3.wav" )
	resource.AddFile( "sound/npc/banshee/foot1.wav" )
	resource.AddFile( "sound/npc/banshee/foot2.wav" )
	resource.AddFile( "sound/npc/banshee/foot3.wav" )
	resource.AddFile( "sound/npc/banshee/foot4.wav" )
	resource.AddFile( "sound/npc/banshee/fz_alert_close1.wav" )
	resource.AddFile( "sound/npc/banshee/fz_alert_far1.wav" )
	resource.AddFile( "sound/npc/banshee/fz_frenzy1.wav" )
	resource.AddFile( "sound/npc/banshee/fz_frenzy2.wav" )
	resource.AddFile( "sound/npc/banshee/fz_frenzy3.wav" )
	resource.AddFile( "sound/npc/banshee/fz_frenzy4.wav" )
	resource.AddFile( "sound/npc/banshee/fz_frenzy5.wav" )
	resource.AddFile( "sound/npc/banshee/fz_frenzy6.wav" )
	resource.AddFile( "sound/npc/banshee/fz_frenzy7.wav" )
	resource.AddFile( "sound/npc/banshee/fz_scream1.wav" )
	resource.AddFile( "sound/npc/banshee/fz_scream2.wav" )
	resource.AddFile( "sound/npc/banshee/fz_scream3.wav" )
	resource.AddFile( "sound/npc/banshee/gurgle_loop1.wav" )
	resource.AddFile( "sound/npc/banshee/idle1.wav" )
	resource.AddFile( "sound/npc/banshee/idle2.wav" )
	resource.AddFile( "sound/npc/banshee/idle3.wav" )
	resource.AddFile( "sound/npc/banshee/leap1.wav" )
	resource.AddFile( "sound/npc/banshee/leap2.wav" )
	resource.AddFile( "sound/npc/banshee/leap3_long.wav" )
	resource.AddFile( "sound/npc/banshee/leap_begin.wav" )
	resource.AddFile( "sound/npc/banshee/test.wav" )
	resource.AddFile( "sound/npc/banshee/wake1.wav" )
	resource.AddFile( "sound/npc/shamblie/claw_miss1.wav" )
	resource.AddFile( "sound/npc/shamblie/claw_miss2.wav" )
	resource.AddFile( "sound/npc/shamblie/claw_strike1.wav" )
	resource.AddFile( "sound/npc/shamblie/claw_strike2.wav" )
	resource.AddFile( "sound/npc/shamblie/claw_strike3.wav" )
	resource.AddFile( "sound/npc/shamblie/foot1.wav" )
	resource.AddFile( "sound/npc/shamblie/foot2.wav" )
	resource.AddFile( "sound/npc/shamblie/foot3.wav" )
	resource.AddFile( "sound/npc/shamblie/foot_slide1.wav" )
	resource.AddFile( "sound/npc/shamblie/foot_slide2.wav" )
	resource.AddFile( "sound/npc/shamblie/foot_slide3.wav" )
	resource.AddFile( "sound/npc/shamblie/growl_0.wav" )
	resource.AddFile( "sound/npc/shamblie/growl_1.wav" )
	resource.AddFile( "sound/npc/shamblie/growl_2.wav" )
	resource.AddFile( "sound/npc/shamblie/growl_3.wav" )
	resource.AddFile( "sound/npc/shamblie/growl_4.wav" )
	resource.AddFile( "sound/npc/shamblie/growl_5.wav" )
	resource.AddFile( "sound/npc/shamblie/growl_6.wav" )
	resource.AddFile( "sound/npc/shamblie/growl_7.wav" )
	resource.AddFile( "sound/npc/shamblie/growl_8.wav" )
	resource.AddFile( "sound/npc/shamblie/hit_0.wav" )
	resource.AddFile( "sound/npc/shamblie/hit_1.wav" )
	resource.AddFile( "sound/npc/shamblie/hit_2.wav" )
	resource.AddFile( "sound/npc/shamblie/hit_3.wav" )
	resource.AddFile( "sound/npc/shamblie/hit_4.wav" )
	resource.AddFile( "sound/npc/shamblie/hit_5.wav" )
	resource.AddFile( "sound/npc/shamblie/hit_6.wav" )
	resource.AddFile( "sound/npc/shamblie/hit_7.wav" )
	resource.AddFile( "sound/npc/shamblie/moan_loop1.wav" )
	resource.AddFile( "sound/npc/shamblie/moan_loop2.wav" )
	resource.AddFile( "sound/npc/shamblie/moan_loop3.wav" )
	resource.AddFile( "sound/npc/shamblie/moan_loop4.wav" )
	resource.AddFile( "sound/npc/shamblie/zombie_alert1.wav" )
	resource.AddFile( "sound/npc/shamblie/zombie_alert2.wav" )
	resource.AddFile( "sound/npc/shamblie/zombie_alert3.wav" )
	resource.AddFile( "sound/npc/shamblie/zombie_die1.wav" )
	resource.AddFile( "sound/npc/shamblie/zombie_die2.wav" )
	resource.AddFile( "sound/npc/shamblie/zombie_die3.wav" )
	resource.AddFile( "sound/npc/shamblie/zombie_hit.wav" )
	resource.AddFile( "sound/npc/shamblie/zombie_pound_door.wav" )
	resource.AddFile( "sound/npc/shamblie/zo_attack1.wav" )
	resource.AddFile( "sound/npc/shamblie/zo_attack2.wav" )
	resource.AddFile( "sound/powers/explosion_3.wav" )
	resource.AddFile( "sound/powers/explosion_3_boom.wav" )
	resource.AddFile( "sound/weapons/1molotov/mtov_break1.wav" )
	resource.AddFile( "sound/weapons/1molotov/mtov_break2.wav" )
	resource.AddFile( "sound/weapons/1molotov/mtov_flame1.wav" )
	resource.AddFile( "sound/weapons/1molotov/mtov_flame2.wav" )
	resource.AddFile( "sound/weapons/1molotov/mtov_flame3.wav" )
	resource.AddFile( "sound/weapons/fists_zm/swing1.wav" )
	resource.AddFile( "sound/weapons/flashlight_zm/flashlight_swing.wav" )
	resource.AddFile( "sound/weapons/flashlight_zm/flashlight_swinghit.wav" )
	resource.AddFile( "sound/weapons/pistol_zm/pistol_zm_empty.wav" )
	resource.AddFile( "sound/weapons/pistol_zm/pistol_zm_fire1.wav" )
	resource.AddFile( "sound/weapons/pistol_zm/pistol_zm_fire1_dist.wav" )
	resource.AddFile( "sound/weapons/pistol_zm/pistol_zm_fire2.wav" )
	resource.AddFile( "sound/weapons/pistol_zm/pistol_zm_fire2_dist.wav" )
	resource.AddFile( "sound/weapons/pistol_zm/pistol_zm_reload1.wav" )
	resource.AddFile( "sound/weapons/revolver_zm/revolver_fire.wav" )
	resource.AddFile( "sound/weapons/revolver_zm/revolver_reload.wav" )
	resource.AddFile( "sound/weapons/rifle_zm/zm_rifle_empty.wav" )
	resource.AddFile( "sound/weapons/rifle_zm/zm_rifle_fire1.wav" )
	resource.AddFile( "sound/weapons/rifle_zm/zm_rifle_fire2.wav" )
	resource.AddFile( "sound/weapons/rifle_zm/zm_rifle_lever.wav" )
	resource.AddFile( "sound/weapons/rifle_zm/zm_rifle_reload1.wav" )
	resource.AddFile( "sound/weapons/rifle_zm/zm_rifle_reload2.wav" )
	resource.AddFile( "sound/weapons/shotgun_zm/shotgun_cock_zm.wav" )
	resource.AddFile( "sound/weapons/shotgun_zm/shotgun_dbl_fire.wav" )
	resource.AddFile( "sound/weapons/shotgun_zm/shotgun_dbl_fire7_zm.wav" )
	resource.AddFile( "sound/weapons/shotgun_zm/shotgun_dbl_fire7_zm_dist.wav" )
	resource.AddFile( "sound/weapons/shotgun_zm/shotgun_empty_zm.wav" )
	resource.AddFile( "sound/weapons/shotgun_zm/shotgun_fire6_zm.wav" )
	resource.AddFile( "sound/weapons/shotgun_zm/shotgun_fire7_zm.wav" )
	resource.AddFile( "sound/weapons/shotgun_zm/shotgun_fire7_zm_dist.wav" )
	resource.AddFile( "sound/weapons/shotgun_zm/shotgun_fire7_zm_dist2.wav" )
	resource.AddFile( "sound/weapons/shotgun_zm/shotgun_reload1_zm.wav" )
	resource.AddFile( "sound/weapons/shotgun_zm/shotgun_reload2_zm.wav" )
	resource.AddFile( "sound/weapons/shotgun_zm/shotgun_reload3_zm.wav" )
	resource.AddFile( "sound/weapons/sledge_zm/sledge_swing.wav" )
	resource.AddFile( "sound/weapons/sledge_zm/sledge_swingalt.wav" )
	resource.AddFile( "sound/weapons/smg_zm/smg_fire.wav" )
	resource.AddFile( "sound/weapons/smg_zm/smg_fire_distancefade.wav" )
	resource.AddFile( "sound/weapons/smg_zm/smg_reload1.wav" )
	resource.AddFile( "sound/weapons/smg_zm/smg_reload2.wav" )
	resource.AddFile( "sound/weapons/smg_zm/smg_reload3.wav" )
end