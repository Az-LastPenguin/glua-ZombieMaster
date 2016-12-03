CreateConVar("zm_physexp_forcedrop_radius", "128", FCVAR_NOTIFY, "Radius in which players are forced to drop what they carry so that the physexp can affect the objects.")
CreateConVar("zm_loadout_disable", "0", FCVAR_NOTIFY, "If set to 1, any info_loadout entity will not hand out weapons. Not recommended unless you're intentionally messing with game balance and playing on maps that support this move.")

CreateConVar("zm_debug_nozombiemaster", "0", FCVAR_NOTIFY + FCVAR_ARCHIVE + FCVAR_SERVER_CAN_EXECUTE, "Used for debug, will not cause players to become the ZM.")
cvars.AddChangeCallback("zm_debug_nozombiemaster", function(convar_name, value_old, value_new)
	timer.Simple(2, function() hook.Call("PreRestartRound", GAMEMODE) end)
	timer.Simple(3, function() hook.Call("RestartRound", GAMEMODE) end)
end)

CreateConVar("zm_roundlimit","2", FCVAR_NOTIFY, "Sets the number of rounds before the server changes map\n" )
CreateConVar("zm_nocollideplayers","0", FCVAR_NOTIFY, "Should players not collide with each other?" )
CreateConVar("zm_banshee_limit", "-1", { FCVAR_ARCHIVE, FCVAR_NOTIFY }, "Sets maximum number of banshees per survivor that the ZM is allowed to have active at once. Set to 0 or lower to remove the cap. Disabled by default since new population system was introduced that in practice includes a banshee limit.")
CreateConVar("zm_trap_triggerrange", "96", FCVAR_NONE, "The range trap trigger points have.")
CreateConVar("zm_spawndelay", "0.75", FCVAR_NOTIFY, "Delay between creation of zombies at zombiespawn.")
CreateConVar("zm_incometime", "5", FCVAR_NOTIFY, "Amount of time in seconds the Zombie Master gains resources.")
CreateConVar("zm_resourcegainperplayerdeathmin", "50", FCVAR_NOTIFY, "Min amount of resources the Zombie Master gains per player death.")
CreateConVar("zm_resourcegainperplayerdeathmax", "100", FCVAR_NOTIFY, "Max amount of resources the Zombie Master gains per player death.")
CreateConVar("zm_notimeslowonwin", "0", FCVAR_NOTIFY, "Disables time slowing down when someone wins a game.")

local function ZM_Power_PhysExplode_SV(ply, command, arguments)
	if (not IsValid(ply)) or (IsValid(ply) and not ply:IsZM()) then
		return
	end

	local vec = string.Explode(" ", arguments[1])
	local mousepos = Vector(vec[1], vec[2], vec[3])
	local tr = util.TraceLine({start = ply:EyePos(), endpos = ply:EyePos() + mousepos * (75 ^ 2), filter = player.GetAll(), mask = MASK_SOLID})
	if not tr.Hit then
		ply:PrintTranslatedMessage(HUD_PRINTTALK, "invalid_surface_for_explosion")
		return
	end
	
	local location = tr.HitPos
	
	if not ply:CanAfford(GetConVar("zm_physexp_cost"):GetInt()) then
		ply:PrintTranslatedMessage(HUD_PRINTTALK, "not_enough_resources")
		return
	end
	
	ply:SetZMPoints(ply:GetZMPoints() - GetConVar("zm_physexp_cost"):GetInt())

	local ent = ents.Create("env_delayed_physexplosion")
	if IsValid(ent) then
		ent:Spawn()
		ent:SetPos(location)
		ent:Activate()
		ent:DelayedExplode( ZM_PHYSEXP_DELAY )
		ply:PrintTranslatedMessage(HUD_PRINTTALK, "explosion_created")
	end
end
concommand.Add("_place_physexplode_zm", ZM_Power_PhysExplode_SV)

local function ZM_Power_KillZombies(ply)
	if (not IsValid(ply)) or (IsValid(ply) and not ply:IsZM()) then return end
	
	for _, ent in pairs(ents.FindByClass("npc_*")) do
		if ent:GetSharedBool("selected") then
			local dmginfo = DamageInfo()
			dmginfo:SetDamage(ent:Health())
			dmginfo:SetDamageType(DMG_REMOVENORAGDOLL)
			
			ent:TakeDamageInfo(dmginfo) 
		end
	end
	
	ply:PrintTranslatedMessage(HUD_PRINTTALK, "killed_all_zombies")
end
concommand.Add("zm_power_killzombies", ZM_Power_KillZombies, nil, "Kills all selected zombies")

local function ZM_Power_SpotCreate_SV(ply, command, arguments)
	if (not IsValid(ply)) or (IsValid(ply) and not ply:IsZM()) then
		return
	end

	local vec = string.Explode(" ", arguments[1])
	local mousepos = Vector(vec[1], vec[2], vec[3])
	local tr = util.TraceLine({start = ply:EyePos(), endpos = ply:EyePos() + mousepos * (75 ^ 2), filter = player.GetAll(), mask = MASK_SOLID})
	local location = tr.HitPos

	local tr_floor = util.TraceHull({start = location + Vector(0, 0, 25), endpos = location - Vector(0, 0, 25), filter = player.GetAll(), mins = Vector(-13, -13, 0), maxs = Vector(13, 13, 72), mask = MASK_NPCSOLID})
	if tr_floor.Fraction == 1.0 then
		ply:PrintTranslatedMessage(HUD_PRINTCENTER, "zombie_does_not_fit")
		return
	end

	location = tr_floor.HitPos

	if not ply:CanAfford(GetConVar("zm_spotcreate_cost"):GetInt()) then
		ply:PrintTranslatedMessage(HUD_PRINTTALK, "not_enough_resources")
		return
	end
	
	for k, v in pairs( ents.FindByClass( "trigger_blockspotcreate" ) ) do
		if IsValid(v) then
			if v.m_bActive then
				local vecMins = v:OBBMins()
				local vecMaxs = v:OBBMaxs()
				if vecMins.x <= location.x and vecMins.y <= location.y and vecMins.z <= location.z and vecMaxs.x >= location.x and vecMaxs.y >= location.y and vecMaxs.z >= location.z then
					ply:PrintTranslatedMessage( HUD_PRINTTALK, "zombie_cant_be_created" )
					return
				end
			end
		end
	end
	
	for _, pl in pairs(team.GetPlayers(TEAM_SURVIVOR)) do
		if IsValid(pl) then
			if TrueVisible(location, pl:EyePos()) then
				ply:PrintTranslatedMessage(HUD_PRINTCENTER, "human_can_see_location" )
				return
			end
		end
	end
	
	local pZombie = gamemode.Call("SpawnZombie", ply, "npc_zombie", location, ply:EyeAngles(), GetConVar("zm_spotcreate_cost"):GetInt())
	if IsValid(pZombie) then
		ply:PrintTranslatedMessage(HUD_PRINTTALK, "hidden_zombie_spawned")
	end
end
concommand.Add("_place_zombiespot_zm", ZM_Power_SpotCreate_SV)

local function ZM_Drop_Ammo(ply)
	if ply.ThrowDelay and ply.ThrowDelay > CurTime() then return end
	
	local wep = ply:GetActiveWeapon()
	
	if not IsValid(wep) then return end
	
	local ammotype = wep.Primary.Ammo
	
	if wep.IsMelee or ammotype == nil or ammotype == "none" or wep.CantThrowAmmo then return end
	
	local amount = GAMEMODE.AmmoCache[ammotype]
	
	if ply:GetAmmoCount(ammotype) == 0 then return end
	
	if ply:GetAmmoCount(ammotype) < amount then
		amount = ply:GetAmmoCount(ammotype)
	end
	
	local ammoclass = ""
	for class, name in pairs(GAMEMODE.AmmoClass) do
		if ammotype == name then
			ammoclass = class
			break
		end
	end
	
	local ent = ents.Create("item_zm_ammo")
	if IsValid(ent) then
		local vecEye = ply:EyePos()
		local angEye = ply:EyeAngles()
		local vForward = angEye:Forward()

		local vecSrc = vecEye + vForward * 60.0
	
		ent.Model = GAMEMODE.AmmoModels[ammoclass]
		ent.AmmoAmount = amount
		ent.AmmoType = GAMEMODE.AmmoClass[ammoclass]
		ent.ClassName = ammoclass
		
		local pObj = ent:GetPhysicsObject()
		
		local vecVelocity = ply:GetAimVector() * 200
		
		if IsValid(pObj) then
			pObj:AddVelocity(vecVelocity)
		else
			ent:SetVelocity(vecVelocity)
		end
	
		ent:SetPos(vecSrc)
		ent:Spawn()
		
		ent.ThrowTime = CurTime() + 1

		ply:RemoveAmmo(amount, ammotype)
	end
	
	ply.ThrowDelay = CurTime() + 0.5
end
concommand.Add("zm_dropammo", ZM_Drop_Ammo, nil, "Drops your current weapons ammo")

local function ZM_Drop_Weapon(ply)
	local wep = ply:GetActiveWeapon()
	if IsValid(wep) and not wep.Undroppable then
		ply:DropWeapon(wep)
		
		local weps = ply:GetWeapons()
		local randwep = weps[math.random(#weps)]
		
		if randwep then
			ply:SelectWeapon(randwep:GetClass())
		end
	end
end
concommand.Add("zm_dropweapon", ZM_Drop_Weapon, nil, "Drops your current weapon")

local function ZM_TraceSelect(ply, command, arguments)
	if ply:IsZM() then
		-- Let's try a shitty method with ents.FindInSphere

		local d, c 				= string.Explode(" ", arguments[1]), string.Explode(" ", arguments[2])
		local vectorA, vectorB 	= Vector(d[1], d[2], d[3]), Vector(c[1], c[2], c[3])
		local distance 			= (vectorA:Distance(vectorB)) / 2 -- The distance between vectorA and vectorB for sphere.
		local middle		 	= (vectorA + vectorB) / 2 -- Hopefully this is the right position.
		
		-- Chewgum: Find the entities inside the selection.
		local entities = ents.FindInSphere(middle, distance);

		for _, entity in ipairs(entities) do
			if entity:IsNPC() then
				entity:SetSharedBool("selected", true)
			end
		end
	end
end
concommand.Add("zm_traceselect", ZM_TraceSelect, nil, "Shouldn't be used from console")

local function ZM_Select(ply, command, arguments)
	if ply:IsZM() then
		local entity = ents.GetByIndex(tonumber(arguments[1]))
		
		if not ply:KeyDown(IN_DUCK) then
			for _, npc in pairs(ents.FindByClass("npc_*")) do
				if npc:GetSharedBool("selected") then
					npc:SetSharedBool("selected", false)
				end
			end
		end
	
		if IsValid(entity) and entity:IsNPC() then
			local selected = entity:GetSharedBool("selected")
			
			if selected then
				entity:SetSharedBool("selected", false)
			else
				entity:SetSharedBool("selected", true)
			end
		end
	end
end
concommand.Add("zm_selectnpc", ZM_Select, nil, "Select a group of/single NPC(s)")

local function ZM_Command_NPC(ply, command, arguments)
	if ply:IsZM() then
		local vec = string.Explode(" ", arguments[1])
		local position = Vector(vec[1], vec[2], vec[3])
		
		for _, entity in pairs(ents.FindByClass("npc_*")) do
			if IsValid(entity) and entity:GetSharedBool("selected", false) and entity:IsNPC() then
				entity:ForceGoto(position)
				entity.isMoving = true
			end
		end
	end
end
concommand.Add("zm_command_npcgo", ZM_Command_NPC, nil, "Marks the position the selected NPCs should go")

local function ZM_NPC_Target_Object(ply, command, arguments)
	if ply:IsZM() then
		local vec = string.Explode(" ", arguments[1])
		local position = Vector(vec[1], vec[2], vec[3])
		local ent = Entity(tonumber(arguments[2]))
		
		for _, entity in pairs(ents.FindByClass("npc_*")) do
			if IsValid(entity) and entity:GetSharedBool("selected", false) and entity:IsNPC() then
				if IsValid(ent) then
					entity:ForceSwat(ent, ent:Health() > 0)
				end
			end
		end
	end
end
concommand.Add("zm_npc_target_object", ZM_NPC_Target_Object, nil, "Commands an NPC to interact with an object")

local function ZM_Deselect(ply)
	if ply:IsZM() then
		for _, entity in pairs(ents.FindByClass("npc_*")) do
			entity:SetSharedBool("selected", false)
		end
	end
end
concommand.Add("zm_deselect", ZM_Deselect, nil, "Deselects all NPCs")

concommand.Add("zm_clicktrap", function(ply, command, arguments)
	if ply:IsZM() then
		local entity = ents.GetByIndex(tonumber(arguments[1]))

		if IsValid(entity) then
			entity:Trigger(ply)
			ply:TakeZMPoints(entity:GetCost())
		end
	end
end)

concommand.Add("zm_selectall_zombies", function(ply, command, arguments)
	if ply:IsZM() then
		for _, entity in pairs(ents.FindByClass("npc_*")) do
			if entity:IsNPC() then
				entity:SetSharedBool("selected", true)
			end
		end
		
		ply:PrintTranslatedMessage(HUD_PRINTTALK, "all_zombies_selected")
	end
end)

concommand.Add("zm_placetrigger", function(ply, command, arguments)
	if ply:IsZM() then
		local position = Vector(arguments[1], arguments[2], arguments[3])
		local entity = ents.GetByIndex(tonumber(arguments[4]))
		local cost = entity:GetTrapCost()
		
		if ply:CanAfford(cost) then
			local trigger = ents.Create("info_manipulate_trigger")
			trigger:SetPos(position)
			trigger:Spawn()
			trigger:SetParent(entity)
		
			ply:TakeZMPoints(cost)
			
			ply:PrintTranslatedMessage(HUD_PRINTTALK, "trap_created")
		end
	end
end)

concommand.Add("zm_spawnzombie", function(ply, command, arguments)
	if ply:IsZM() then
		local ent = ents.GetByIndex(tonumber(arguments[1]))
		local zombietype = arguments[2]
		local amount = tonumber(arguments[3])
	
		if IsValid(ent) then
			ent:AddQuery(ply, zombietype, amount)
		end
	end
end)

concommand.Add("zm_rqueue", function(ply, command, arguments)
	if ply:IsZM() then
		local entity = ents.GetByIndex(tonumber(arguments[1]))
		local clear = arguments[2]
	
		if IsValid(entity) then
			if clear == "1" then
				entity:ClearQueue(true)
			else
				entity:ClearQueue()
			end
		end
	end
end)

concommand.Add("zm_placerally", function(ply, command, arguments)
	if ply:IsZM() then
		local position = Vector(arguments[1], arguments[2], arguments[3]) + Vector(0, 0, 7)
		local entity = ents.GetByIndex(tonumber(arguments[4]))
		
		if IsValid(entity) then
			local rally = entity:GetRallyEntity()
			if IsValid(rally) then
				rally:Remove()
			end
			
			local rallyPoint = ents.Create("info_rallypoint")
			rallyPoint:SetPos(position)
			rallyPoint:Spawn()
			rallyPoint:ActivateRallyPoint()

			entity:SetRallyEntity(rallyPoint)
			
			ply:PrintTranslatedMessage(HUD_PRINTTALK, "rally_created")
		end
	end
end)

GM.groups = {}
GM.currentmaxgroup = 0
GM.selectedgroup = 0
concommand.Add("zm_creategroup", function(ply, command, arguments)
	if ply:IsZM() then
		if GAMEMODE.currentmaxgroup >= 9 then return end
		
		table.Empty(GAMEMODE.groups)
		
		currentmaxgroup = GAMEMODE.currentmaxgroup + 1
		GAMEMODE.groups[currentmaxgroup] = {}
		
		local groupadd = GAMEMODE.groups[currentmaxgroup]
		for _, npc in pairs(ents.FindByClass("npc_*")) do
			if npc:GetSharedBool("selected", false) then
				table.insert(groupadd, npc)
			end
		end
		
		GAMEMODE.selectedgroup = currentmaxgroup
		
		ply:PrintTranslatedMessage(HUD_PRINTTALK, "group_created")

		net.Start("zm_sendcurrentgroups")
			net.WriteTable(GAMEMODE.groups)
		net.Send(ply)
		
		net.Start("zm_sendselectedgroup")
			net.WriteUInt(GAMEMODE.selectedgroup, 8)
		net.Send(ply)
	end
end)

concommand.Add("zm_setselectedgroup", function(ply, command, arguments)
	if ply:IsZM() then
		local groupnum = string.Replace(arguments[1], "Group ", "")
		if groups then
			for i, group in pairs(groups) do
				if groupnum == i then
					GAMEMODE.selectedgroup = i
					break
				end
			end
			
			net.Start("zm_sendselectedgroup")
				net.WriteUInt(GAMEMODE.selectedgroup, 8)
			net.Send(ply)
		end
	end
end)

concommand.Add("zm_selectgroup", function(ply, command, arguments)
	if ply:IsZM() then
		local selection = GAMEMODE.groups[GAMEMODE.selectedgroup] or {}
		for i, npc in pairs(selection) do
			if IsValid(npc) and npc:IsNPC() then
				npc:SetSharedBool("selected", true)
			end
		end
		
		ply:PrintTranslatedMessage(HUD_PRINTTALK, "group_selected")
	end
end)

concommand.Add("zm_switch_to_defense", function(ply, command, arguments)
	if ply:IsZM() then
		for _, entity in pairs(ents.FindByClass("npc_*")) do
			if IsValid(entity) and entity:GetSharedBool("selected", false) and entity:IsNPC() then
				entity:SetSchedule(SCHED_AMBUSH)
				entity.isMoving = false
			end
		end
		ply:PrintTranslatedMessage(HUD_PRINTTALK, "set_zombies_to_defensive_mode")
	end
end)

concommand.Add("zm_switch_to_offense", function(ply, command, arguments)
	if ply:IsZM() then
		for _, entity in pairs(ents.FindByClass("npc_*")) do
			if IsValid(entity) and entity:GetSharedBool("selected", false) and entity:IsNPC() then
				entity:SetSchedule(SCHED_ALERT_WALK)
				entity.isMoving = true
			end
		end
		ply:PrintTranslatedMessage(HUD_PRINTTALK, "set_zombies_to_offensive_mode")
	end
end)

concommand.Add("zm_debug_spawn_zombie", function(ply)
	if not ply:IsSuperAdmin() then return end
	
	local tr = util.TraceLine(util.GetPlayerTrace(ply))
	if not tr.Hit then return end
	
	local ent = ents.Create("npc_zombie")
	if IsValid(ent) then
		ent:SetPos(tr.HitPos)
		ent:Spawn()
		ent:Activate()
	end
end)

concommand.Add("zm_player_ready", function(sender, command, arguments)
	if not sender.IsReady then
		sender.IsReady = true
		hook.Call("InitClient", GAMEMODE, sender)
	end
end)