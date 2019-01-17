GM.Name = "Zombie Master"
GM.Author = "Forrest Mark X"
GM.Email = "forrestmarkx@outlook.com"
GM.Website = "http://steamcommunity.com/id/ForrestMarkX/"
GM.TeamBased = true

include("sh_translate.lua")
include("sh_sounds.lua")
include("sh_zm_globals.lua")
include("sh_utility.lua")
include("sh_zerolag.lua")

include("sh_zm_options.lua")

include("sh_weapons.lua")
include("sh_players.lua")
include("sh_entites.lua")
include("sh_zombies.lua")
include("sh_npc.lua")

include("player_class/player_basezm.lua")
include("player_class/player_survivor.lua")
include("player_class/player_zombiemaster.lua")
include("player_class/player_spectator.lua")

GM.NetworkVarCallbacks = {}
GM.iZombieList = {}

function GM:Initialize()
    hook.Call("SetupCustomItems", self)
    
    for _, mdl in pairs(file.Find("models/zombie/*.mdl", "GAME")) do
        util.PrecacheModel(mdl)
    end
    
    game.AddAmmoType({ name = "pistol", dmgtype = DMG_BULLET, tracer = TRACER_LINE_AND_WHIZ, plydmg = GetConVar("sk_plr_dmg_pistol"):GetInt(), npcdmg = GetConVar("sk_npc_dmg_pistol"):GetInt(), maxcarry = GetConVar("zm_maxammo_pistol"):GetInt(), force = 1225 })
    game.AddAmmoType({ name = "smg1", dmgtype = DMG_BULLET, tracer = TRACER_LINE_AND_WHIZ, plydmg = GetConVar("sk_plr_dmg_smg1"):GetInt(), npcdmg = GetConVar("sk_npc_dmg_smg1"):GetInt(), maxcarry = GetConVar("zm_maxammo_smg1"):GetInt(), force = 1225 })
    game.AddAmmoType({ name = "357", dmgtype = DMG_BULLET, tracer = TRACER_LINE_AND_WHIZ, plydmg = GetConVar("sk_plr_dmg_357"):GetInt(), npcdmg = GetConVar("sk_npc_dmg_357"):GetInt(), maxcarry = GetConVar("zm_maxammo_357"):GetInt(), force = 5000 })
    game.AddAmmoType({ name = "buckshot", dmgtype = bit.bor(DMG_BULLET, DMG_BUCKSHOT), tracer = TRACER_LINE_AND_WHIZ, plydmg = GetConVar("sk_plr_dmg_buckshot"):GetInt(), npcdmg = GetConVar("sk_npc_dmg_buckshot"):GetInt(), maxcarry = GetConVar("zm_maxammo_buckshot"):GetInt(), force = 1200 })
    game.AddAmmoType({ name = "revolver", dmgtype = DMG_BULLET, tracer = TRACER_LINE_AND_WHIZ, plydmg = 0, npcdmg = 0, maxcarry = GetConVar("zm_maxammo_revolver"):GetInt(), force = 5000 })
    game.AddAmmoType({ name = "molotov", dmgtype = DMG_BURN, tracer = TRACER_NONE, plydmg = 0, npcdmg = 0, maxcarry = GetConVar("zm_maxammo_molotov"):GetInt(), force = 0 })
    
    hook.Call("BuildZombieDataTable", self)
    hook.Call("SetupNetworkingCallbacks", self)
end

function GM:SetupCustomItems()
end

function GM:SetupNetworkingCallbacks()
    self:AddNetworkingCallbacks("holding", function(ent, value) ent.bIsHolding = value end)
    self:AddNetworkingCallbacks("selected", function(ent, value) ent.bIsSelected = value end)
    self:AddNetworkingCallbacks("bClingingCeiling", function(ent, value) ent.m_bClinging = value end)
    self:AddNetworkingCallbacks("bIsEngineNPC", function(ent, value) ent.IsEngineNPC = value end)
    self:AddNetworkingCallbacks("bSkinReplacmentIndex", function(ent, value) ent.bSkinReplacmentIndex = value end)
    self:AddNetworkingCallbacks("bSkinReplacmentMat", function(ent, value) ent.bSkinReplacmentMat = value end)
end

function GM:CreateTeams()
    TEAM_SURVIVOR = 1
    team.SetUp(TEAM_SURVIVOR, Either(CLIENT, translate.Get("team_survivor_l"), "Survivors"), Color(255, 64, 64, 255)) 
    team.SetSpawnPoint(TEAM_SURVIVOR, "info_player_deathmatch")
    
    TEAM_ZOMBIEMASTER = 2
    team.SetUp(TEAM_ZOMBIEMASTER, Either(CLIENT, translate.Get("team_zombiemaster_l"), "Zombie Master"), Color(153, 255, 153, 255))
    team.SetSpawnPoint(TEAM_ZOMBIEMASTER, "info_player_zombiemaster")
    
    team.SetUp(TEAM_SPECTATOR, Either(CLIENT, translate.Get("team_spectators_l"), "Spectators"), Color(120, 120, 120, 255))
    team.SetSpawnPoint(TEAM_SPECTATOR, {"info_player_deathmatch", "info_player_zombiemaster", "worldspawn"})
end

function GM:FindZM()
    return GetGlobalEntity("zm_zombiemaster_player")
end

function GM:PlayerShouldTakeDamage(pl, attacker)
    return player_manager.RunClass(pl, "ShouldTakeDamage", attacker)
end

function GM:IsSpecialPerson(pl, image)
    local img, tooltip
    local steamid = pl:SteamID()

    if steamid == "STEAM_0:0:18807892" then
        img = "icon16/page_white_cplusplus.png"
        tooltip = "ForrestMarkX\nDeveloper!"
    elseif pl:IsAdmin() then
        img = "icon16/shield.png"
        tooltip = "Admin"
    else
        local contributor = self.ContributorList[steamid]
        if contributor then
            img = "icon16/heart.png"
            tooltip = contributor.."\nContributor!"
        end
    end

    if img then
        if CLIENT then
            image:SetImage(img)
            image:SetTooltip(tooltip)
        end

        return true
    end

    return false
end

function GM:GetZMSelection()
    return GetGlobalBool("zm_zmselection_start", false)
end

function GM:GetRoundStart()
    return GetGlobalBool("zm_round_start", false)
end

function GM:GetRoundActive()
    return GetGlobalBool("zm_round_active", false)
end

function GM:GetPreRoundEnd()
    return GetGlobalBool("zm_preround_ended", false)
end

function GM:GetRoundEnd()
    return GetGlobalBool("zm_round_ended", false)
end

function GM:GetRoundsPlayed()
    return GetGlobalInt("zm_rounds_played", 0)
end

function GM:GetReadyCount()
    return GetGlobalInt("zm_ready_counter", -1)
end

function GM:GetGameStarting()
    return GetGlobalBool("zm_game_ready", false)
end

function GM:SetupMove(ply, mv, cmd)
    player_manager.RunClass(ply, "SetupMove", mv, cmd)
end

function GM:AddNetworkingCallbacks(name, func)
    if self.NetworkVarCallbacks[name] then return end
    self.NetworkVarCallbacks[name] = func
end

function GM:EntityNetworkedVarChanged(ent, name, oldval, newval)
    if self.NetworkVarCallbacks[name] ~= nil then self.NetworkVarCallbacks[name](ent, newval) end
    
    if CLIENT and ent.PostNetReceive then
        ent:PostNetReceive(name, oldval, newval)
    end
end

function GM:ShouldCollide(ent1, ent2)
    return not (ent1:IsPlayer() and ent2:IsPlayer())
end

function GM:GravGunPickupAllowed(ply, ent)
    return player_manager.RunClass(ply, "AllowPickup", ent)
end

function GM:PlayerButtonDown(ply, button)
    player_manager.RunClass(ply, "ButtonDown", button)
end

function GM:PlayerButtonUp(ply, button)
    player_manager.RunClass(ply, "ButtonUp", button)
end

function GM:PlayerCanPickupWeapon(pl, ent)
    return player_manager.RunClass(pl, "CanPickupWeapon", ent)
end

function GM:PlayerCanPickupItem(pl, item)
    return player_manager.RunClass(pl, "CanPickupItem", item)
end

function GM:KeyPress(pl, key)
    return player_manager.RunClass(pl, "KeyPress", key)
end

function GM:KeyRelease(pl, key)
    return player_manager.RunClass(pl, "KeyRelease", key)
end

function GM:PlayerPostThink(pl)
    player_manager.RunClass(pl, "PostThink")
end

function GM:CanHiddenZombieBeCreated(ply, pos, mousepos)
    if not IsValid(ply) then return end

    local tr = util.TraceLine({start = pos, endpos = pos + mousepos * (75 ^ 2), filter = player.GetAll(), mask = MASK_SOLID})
    local location = tr.HitPos

    local tr_floor = util.TraceHull({start = location + Vector(0, 0, 25), endpos = location - Vector(0, 0, 25), filter = player.GetAll(), mins = Vector(-13, -13, 0), maxs = Vector(13, 13, 72), mask = MASK_NPCSOLID})
    if tr_floor.Fraction < 0.5 then
        return false, "zombie_does_not_fit"
    end

    location = tr_floor.HitPos

    if not ply:CanAfford(GetConVar("zm_spotcreate_cost"):GetInt()) then
        return false, "not_enough_resources"
    end
    
    local vecHeadTarget = location
    vecHeadTarget.z = vecHeadTarget.z + 64
    
    for k, v in pairs(ents.FindByClass("trigger_blockspotcreate")) do
        if v.m_bActive then
            if v:IsPointInBounds(location) then
                return false, "zombie_cant_be_created"
            end
        end
    end
    
    for _, pl in pairs(team.GetPlayers(TEAM_SURVIVOR)) do
        local tr = util.TraceLine({
            start = location,
            endpos = pl:GetPos(),
            filter = pl,
            mask = MASK_OPAQUE
        })

        local visible = false
        if tr.Fraction == 1 then
            visible = true
        end

        local tr = util.TraceLine({
            start = vecHeadTarget,
            endpos = pl:EyePos(),
            filter = pl,
            mask = MASK_OPAQUE
        })
        if tr.Fraction == 1 then
            visible = true
        end

        if visible then
            return false, "human_can_see_location"
        end
    end
    
    return true, nil, tr
end