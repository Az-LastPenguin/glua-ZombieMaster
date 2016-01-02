include("shared.lua")
include("cl_killicons.lua")
include("cl_utility.lua")
include("cl_scoreboard.lua")
include("cl_dermaskin.lua")

include("cl_zm_options.lua")
include("cl_targetid.lua")
include("cl_hud.lua")
include("cl_zombie.lua")

include("vgui/dpingmeter.lua")
include("vgui/dteamcounter.lua")
include("vgui/dteamheading.lua")
include("vgui/dzmhud.lua")

include("vgui/dexnotificationslist.lua")
include("vgui/dexroundedframe.lua")

local circleMaterial 	   = Material("SGM/playercircle")
local healthcircleMaterial = Material("effects/zm_healthring")
local healtheffect		   = Material("effects/yellowflare")
local gradient 		 = surface.GetTextureID("gui/gradient")
local gradient_up	 = surface.GetTextureID("gui/gradient_up")
local gradient_down	 = surface.GetTextureID("gui/gradient_down")

local zombieMenu	  = nil

mouseX, mouseY  = 0, 0
traceX, traceY  = 0, 0
isDragging 	    = false
holdTime 	    = CurTime()

local nightVision_ColorMod = {
	["$pp_colour_addr"] 		= -1,
	["$pp_colour_addg"] 		= -0.35,
	["$pp_colour_addb"] 		= -1,
	["$pp_colour_brightness"] 	= 0.8,
	["$pp_colour_contrast"]		= 1.1,
	["$pp_colour_colour"] 		= 0,
	["$pp_colour_mulr"] 		= 0 ,
	["$pp_colour_mulg"] 		= 0.028,
	["$pp_colour_mulb"] 		= 0
}

w, h = ScrW(), ScrH()

MySelf = MySelf or NULL
hook.Add("InitPostEntity", "GetLocal", function()
	MySelf = LocalPlayer()

	GAMEMODE.HookGetLocal = GAMEMODE.HookGetLocal or (function(g) end)
	gamemode.Call("HookGetLocal", MySelf)
	RunConsoleCommand("initpostentity")
end)

local function TraceLongDistance(vector)
	local data = {}
	data.start = MySelf:GetShootPos()
	data.endpos = data.start +(vector *9999999999999)
	data.filter = MySelf
	
	return util.TraceLine(data)
end

function GM:InitPostEntity()
	self.HUDShouldDraw = self._HUDShouldDraw
	self.HUDPaint = self._HUDPaint
	self.PostPlayerDraw = self._PostPlayerDraw
	self.PrePlayerDraw = self._PrePlayerDraw
end

function GM:_PrePlayerDraw(ply)
	return not ply:IsSurvivor()
end

function GM:_PostPlayerDraw(pl)
	if MySelf:Team() == TEAM_ZOMBIEMASTER and pl:Team() == TEAM_SURVIVOR then
		local plHealth, plMaxHealth = pl:Health(), pl:GetMaxHealth()
		local pos = pl:GetPos() + Vector(0, 0, 2)
		local colour = Color(0, 0, 0, 125)
		local healthfrac = math.max(plHealth, 0) / plMaxHealth
		
		colour.r = math.Approach(255, 20, math.abs(255 - 20) * healthfrac)
		colour.g = math.Approach(0, 255, math.abs(0 - 255) * healthfrac)
		colour.b = math.Approach(0, 20, math.abs(0 - 20) * healthfrac)
		
		render.SetMaterial(healthcircleMaterial)
		render.DrawQuadEasy(pos, Vector(0, 0, 1), 40, 40, colour)
		render.DrawQuadEasy(pos, Vector(0, 0, -1), 40, 40, colour)
		
		render.SetMaterial(healtheffect)
		render.DrawQuadEasy(pos, Vector(0, 0, 1), 38, 28, Color(255, 255, 255))
		render.DrawQuadEasy(pos, Vector(0, 0, -1), 38, 28, Color(255, 255, 255))
	end
end

function GM:SpawnMenuEnabled()
	return false
end

function GM:SpawnMenuOpen()
	return false
end

function GM:ContextMenuOpen()
	return false
end

function GM:GetCurrentZombieGroups()
	return self.ZombieGroups == {} and nil or self.ZombieGroups
end

function GM:GetCurrentZombieGroup()
	return self.SelectedZombieGroups
end

local placingShockWave = false
function GM:SetPlacingShockwave(b)
	placingShockwave = b
end

local placingZombie = false
function GM:SetPlacingSpotZombie(b)
	placingZombie = b
end

local placingRally = false
function GM:SetPlacingRallyPoint(b)
	placingRally = b
end

local placingTrap = false
function GM:SetPlacingTrapEntity(b)
	placingTrap = b
end

function surface.CreateLegacyFont(font, size, weight, antialias, additive, name, shadow, outline, blursize)
	surface.CreateFont(name, {font = font, size = size, weight = weight, antialias = antialias, additive = additive, shadow = shadow, outline = outline, blursize = blursize})
end

function GM:CreateFonts()
	local fontfamily = "Typenoksidi"
	
	local screenscale = BetterScreenScale()
	surface.CreateLegacyFont("zmweapons", screenscale * 36, 100, true, false, "ZMDeathFonts", false, true)
	
	surface.CreateLegacyFont(fontfamily, screenscale * 16, fontweight, fontaa, false, "ZSHUDFontTiny", fontshadow, fontoutline)
	surface.CreateLegacyFont(fontfamily, screenscale * 20, fontweight, fontaa, false, "ZSHUDFontSmallest", fontshadow, fontoutline)
	surface.CreateLegacyFont(fontfamily, screenscale * 22, fontweight, fontaa, false, "ZSHUDFontSmaller", fontshadow, fontoutline)
	surface.CreateLegacyFont(fontfamily, screenscale * 28, fontweight, fontaa, false, "ZSHUDFontSmall", fontshadow, fontoutline)
	surface.CreateLegacyFont(fontfamily, screenscale * 42, fontweight, fontaa, false, "ZSHUDFont", fontshadow, fontoutline)
	surface.CreateLegacyFont(fontfamily, screenscale * 72, fontweight, fontaa, false, "ZSHUDFontBig", fontshadow, fontoutline)
	surface.CreateLegacyFont(fontfamily, screenscale * 16, fontweight, fontaa, false, "ZSHUDFontTinyBlur", false, false, 8)
	surface.CreateLegacyFont(fontfamily, screenscale * 22, fontweight, fontaa, false, "ZSHUDFontSmallerBlur", false, false, 8)
	surface.CreateLegacyFont(fontfamily, screenscale * 28, fontweight, fontaa, false, "ZSHUDFontSmallBlur", false, false, 8)
	surface.CreateLegacyFont(fontfamily, screenscale * 42, fontweight, fontaa, false, "ZSHUDFontBlur", false, false, 8)
	surface.CreateLegacyFont(fontfamily, screenscale * 72, fontweight, fontaa, false, "ZSHUDFontBigBlur", false, false, 8)
	
	surface.CreateLegacyFont(fontfamily, 32, fontweight, true, false, "ZSScoreBoardTitle", false, true)
	surface.CreateLegacyFont(fontfamily, 22, fontweight, true, false, "ZSScoreBoardSubTitle", false, true)
	surface.CreateLegacyFont(fontfamily, 16, fontweight, true, false, "ZSScoreBoardPlayer", false, true)
	surface.CreateLegacyFont(fontfamily, 24, fontweight, true, false, "ZSScoreBoardHeading", false, false)
	surface.CreateLegacyFont("arial", 20, 0, true, false, "ZSScoreBoardPlayerSmall", false, true)
	
	-- Default, DefaultBold, DefaultSmall, etc. were changed when gmod13 hit. These are renamed fonts that have the old values.
	surface.CreateFont("DefaultFontVerySmall", {font = "tahoma", size = 10, weight = 0, antialias = false})
	surface.CreateFont("DefaultFontSmall", {font = "tahoma", size = 11, weight = 0, antialias = false})
	surface.CreateFont("DefaultFontSmallDropShadow", {font = "tahoma", size = 11, weight = 0, shadow = true, antialias = false})
	surface.CreateFont("DefaultFont", {font = "tahoma", size = 13, weight = 500, antialias = false})
	surface.CreateFont("DefaultFontBold", {font = "tahoma", size = 13, weight = 1000, antialias = false})
	surface.CreateFont("DefaultFontLarge", {font = "tahoma", size = 16, weight = 0, antialias = false})
	
	surface.CreateLegacyFont("Consolas", 20, 700, true, false, "zm_hud_font", false, true)
	surface.CreateLegacyFont("Consolas", 16, 700, true, false, "zm_hud_font2", false, true)
end

function GM:PlayerShouldTakeDamage(pl, attacker)
	return pl == attacker or not attacker:IsPlayer() or pl:Team() ~= attacker:Team() or pl.AllowTeamDamage or attacker.AllowTeamDamage
end

local colBlur = Color(0, 0, 0)
function draw.SimpleTextBlurry(text, font, x, y, col, xalign, yalign)
	colBlur.r = col.r
	colBlur.g = col.g
	colBlur.b = col.b
	colBlur.a = col.a * math.Rand(0.35, 0.6)

	draw.SimpleText(text, font.."Blur", x, y, colBlur, xalign, yalign)
	draw.SimpleText(text, font, x, y, col, xalign, yalign)
end

function GM:PostDrawViewModel(vm, pl, wep)
	if wep and wep:IsValid() then
		if wep.UseHands or not wep:IsScripted() then
			local hands = pl:GetHands()
			if hands and hands:IsValid() then
				hands:DrawModel()
			end
		end

		if wep.PostDrawViewModel then
			wep:PostDrawViewModel(vm)
		end
	end
end

function GM:PreDrawViewModel(vm, pl, wep)
	if IsValid(pl) and pl:IsHolding() then return true end

	if IsValid(wep) and wep.PreDrawViewModel then
		return wep:PreDrawViewModel(vm)
	end
end

function GM:GUIMouseReleased(mouseCode, aimVector)
	local tr = TraceLongDistance(aimVector)
	
	if tr.Entity and tr.Entity:IsNPC() then
		isDragging = false
		RunConsoleCommand("zm_selectnpc", tr.Entity:EntIndex())
	end
	
	if isDragging then
		local a, b = gui.ScreenToVector(traceX, traceY), gui.ScreenToVector(mouseX, mouseY)
		local c, d = TraceLongDistance(a), TraceLongDistance(b)
		
		if c.HitPos and d.HitPos then
			RunConsoleCommand("zm_traceselect", tostring(d.HitPos), tostring(c.HitPos))
		end
		
		isDragging = false
		traceX, traceY = 0, 0
	end
end

local selectringMaterial = CreateMaterial("CommandRingMat", "UnlitGeneric", {
	["$basetexture"] = "effects/zm_ring",
	["$ignorez"] = 1,
	["$additive"] = 1,
	["$vertexalpha"] = 1,
	["$vertexcolor"] = 1,
	["$translucent"] = 1,
	["$nocull"] = 1
})
local rallyringMaterial = CreateMaterial("RallyRingMat", "UnlitGeneric", {
	["$basetexture"] = "effects/zm_arrows",
	["$ignorez"] = 1,
	["$additive"] = 1,
	["$vertexalpha"] = 1,
	["$vertexcolor"] = 1,
	["$translucent"] = 1,
	["$nocull"] = 1
})
local click_delta = 0
local zm_ring_pos = Vector(0, 0, 0)
local zm_ring_ang = Angle(0, 0, 0)
function GM:GUIMousePressed(mouseCode, aimVector)
	if MySelf:Team() == TEAM_ZOMBIEMASTER then
		if mouseCode == MOUSE_LEFT then
			if placingShockwave then
				if zm_placedpoweritem then zm_placedpoweritem = false end
				
				RunConsoleCommand("_place_physexplode_zm", tostring(aimVector))
				placingShockwave = false
				zm_placedpoweritem = true
			elseif placingZombie then
				if zm_placedpoweritem then zm_placedpoweritem = false end
				
				RunConsoleCommand("_place_zombiespot_zm", tostring(aimVector))
				placingZombie = false
				zm_placedpoweritem = true
			elseif placingTrap then
				local hitPos = TraceLongDistance(aimVector).HitPos
				local vector = string.Explode(" ", tostring(hitPos))
			
				RunConsoleCommand("zm_placetrigger", vector[1], vector[2], vector[3], trapTrigger)

				placingTrap = false
			elseif placingRally then
				if zm_placedrally then zm_placedrally = false end
				
				local hitPos = TraceLongDistance(aimVector).HitPos
				local vector = string.Explode(" ", tostring(hitPos))
				
				RunConsoleCommand("zm_placerally", vector[1], vector[2], vector[3], trapTrigger)
				
				placingRally = false			
				zm_placedrally = true
			else
				RunConsoleCommand("zm_deselect")
			end
			
			if zm_placedpoweritem or zm_placedrally then
				click_delta = CurTime()

				local tr = TraceLongDistance(aimVector)
				zm_ring_pos = tr.HitPos
				zm_ring_ang = tr.HitNormal:Angle()
				zm_ring_ang:RotateAroundAxis(zm_ring_ang:Right(), 90)
			end
		end
		
		if mouseCode == MOUSE_LEFT and not placingShockwave and not placingZombie then
			local ent = TraceLongDistance(aimVector).Entity
			if IsValid(ent) then
				local class = ent:GetClass()
				gamemode.Call("SpawnTrapMenu", class, ent)
			end
		elseif mouseCode == MOUSE_RIGHT then
			if zm_rightclicked then zm_rightclicked = false end
			
			click_delta = CurTime()

			local tr = TraceLongDistance(aimVector)
			zm_ring_pos = tr.HitPos
			zm_ring_ang = tr.HitNormal:Angle()
			zm_ring_ang:RotateAroundAxis(zm_ring_ang:Right(), 90)
			
			zm_rightclicked = true
			
			RunConsoleCommand("zm_command_npcgo", tostring(zm_ring_pos))
		end
	end
end

function GM:PlayerBindPress( ply, bind, pressed )
	if string.find(bind, "+menu") then
		if ply:IsSurvivor() then
			if not timer.Exists("dropweapon") then
				timer.Create("dropweapon", 0.1, 1, function() RunConsoleCommand("zm_dropweapon") timer.Remove("dropweapon") end)
			end
		end
		return true
	elseif string.find(bind, "+zoom") then
		if ply:IsSurvivor() then
			if not timer.Exists("dropammo") then
				timer.Create("dropammo", 0.1, 1, function() RunConsoleCommand("zm_dropammo") timer.Remove("dropammo") end)
			end
		end
		return true
	elseif string.find(bind, "impulse 100") then
		if ply:IsZM() then
			RunConsoleCommand("zm_power_nightvision")
		end
	end
end

function GM:CreateGhostEntity(trap, rallyID)
	if trap then
		gamemode.Call("SetPlacingTrapEntity", true)
	else
		gamemode.Call("SetPlacingRallyPoint", true)
		trapTrigger = rallyID
	end
end

function GM:KeyPress( ply, key )
	if ply:Team() == TEAM_ZOMBIEMASTER and key == IN_SPEED then
		gui.EnableScreenClicker(false)
	end
end

function GM:KeyRelease( ply, key )
	if ply:Team() == TEAM_ZOMBIEMASTER and key == IN_SPEED then
		gui.EnableScreenClicker(true)
	end
end

function GM:CreateVGUI()
	holdTime = CurTime()
	isDragging = false
	
	if IsValid(self.trapPanel) then
		trapPanel:Remove()
	end
	
	gui.EnableScreenClicker(true)
	self.powerMenu = vgui.Create("zm_powerpanel")
	
	timer.Simple(0.25, function()
		if not self.powerMenu then
			self.powerMenu = vgui.Create("zm_powerpanel")
		else
			self.powerMenu:SetVisible(true)
		end
	end)
end

function GM:SetDragging(b)
	isDragging = b
	holdTime = CurTime()
end

local SCROLL_THRESHOLD = 8
function GM:Think()
	if input.IsMouseDown(MOUSE_LEFT) and holdTime < CurTime() and not isDragging and MySelf:IsZM() then
		holdTime = CurTime()
		mouseX, mouseY = gui.MousePos()
		
		isDragging = true
	end
	
	if isDragging and not input.IsMouseDown(MOUSE_LEFT) then
		isDragging = false
	end
	
	if not isDragging and MySelf:IsZM() and vgui.CursorVisible() then
		local mousex, mousey = gui.MousePos()	
		if mousex <= SCROLL_THRESHOLD then
			RunConsoleCommand("+left")
			timer.Simple(0, function() RunConsoleCommand("-left") end)
		elseif mousex >= (ScrW() - SCROLL_THRESHOLD) then
			RunConsoleCommand("+right")
			timer.Simple(0, function() RunConsoleCommand("-right") end)
		else
			RunConsoleCommand("-right")
			timer.Simple(0, function() RunConsoleCommand("-left") end)
		end
		
		-- +lookup and +lookdown seem to do nothing
		--[[
		if mousey <= SCROLL_THRESHOLD then
			RunConsoleCommand("+lookup")
			timer.Simple(0, function() RunConsoleCommand("-lookdown") end)
		elseif mousey >= (ScrH() - SCROLL_THRESHOLD) then
			RunConsoleCommand("+lookdown")
			timer.Simple(0, function() RunConsoleCommand("-lookup") end)
		else
			RunConsoleCommand("-lookup")
			timer.Simple(0, function() RunConsoleCommand("-lookdown") end)
		end
		--]]
	end
end

function GM:PostDrawOpaqueRenderables()
	if MySelf:IsZM() then
		cam.Start3D()
			local zombies = ents.FindByClass("npc_*")
		
			for _, entity in pairs(zombies) do
				if IsValid(entity) then
					local Health, MaxHealth = entity:Health(), entity:GetMaxHealth()
					local pos = entity:GetPos() + Vector(0, 0, 2)
					local colour = Color(0, 0, 0, 125)
					local healthfrac = math.max(Health, 0) / MaxHealth
					
					colour.r = math.Approach(255, 20, math.abs(255 - 20) * healthfrac)
					colour.g = math.Approach(0, 255, math.abs(0 - 255) * healthfrac)
					colour.b = math.Approach(0, 20, math.abs(0 - 20) * healthfrac)
					
					render.SetMaterial(healthcircleMaterial)
					render.DrawQuadEasy(pos, Vector(0, 0, 1), 40, 40, colour)
					render.DrawQuadEasy(pos, Vector(0, 0, -1), 40, 40, colour)
					
					if entity:GetNWBool("selected", false) then
						render.SetMaterial(circleMaterial)
						
						render.DrawQuadEasy(pos, Vector(0, 0, 1), 40, 40, colour)
						render.DrawQuadEasy(pos, Vector(0, 0, -1), 40, 40, colour)
					end
				end
			end
		cam.End3D()
		
		if zm_rightclicked then
			cam.Start3D2D(zm_ring_pos, zm_ring_ang, 1)
				local size = 64 * (1 - (CurTime() - click_delta) * 4)
					
				render.SetMaterial(selectringMaterial)
				render.DrawQuadEasy(Vector( 0, 0, 0 ), Vector(0, 0, 1), size, size, Color(255, 255, 255))
				render.DrawQuadEasy(Vector( 0, 0, 0 ), Vector(0, 0, -1), size, size, Color(255, 255, 255))
				
				if size <= 0 then
					zm_rightclicked = false
					didtrace = false
				end
			cam.End3D2D()		
		elseif zm_placedrally then
			cam.Start3D2D(zm_ring_pos, zm_ring_ang, 1)
				local size = 64 * (1 - (CurTime() - click_delta) * 4)
					
				render.SetMaterial(rallyringMaterial)
				render.DrawQuadEasy(Vector( 0, 0, 0 ), Vector(0, 0, 1), size, size, Color(255, 255, 255))
				render.DrawQuadEasy(Vector( 0, 0, 0 ), Vector(0, 0, -1), size, size, Color(255, 255, 255))
				
				if size <= 0 then
					zm_placedrally = false
					didtrace = false
				end
			cam.End3D2D()
		elseif zm_placedpoweritem then
			cam.Start3D2D(zm_ring_pos, zm_ring_ang, 1)
				local size = 1 * ((CurTime() - click_delta) * 350)
					
				render.SetMaterial(selectringMaterial)
				render.DrawQuadEasy(Vector( 0, 0, 0 ), Vector(0, 0, 1), size, size, Color(255, 255, 255), (CurTime() * 250) % 360)
				
				if size >= 128 then
					zm_placedpoweritem = false
					didtrace = false
				end
			cam.End3D2D()
		end
	end
end

function GM:RenderScreenspaceEffects()
	if MySelf:Team() == TEAM_SPECTATOR then
		render.SetMaterial( Material( "zm_overlay.png", "smooth unlitgeneric nocull" ) )
		render.DrawScreenQuad()
	elseif MySelf:IsZM() then
		if self.nightVision then
			self.nightVisionCur = self.nightVisionCur or 0.5
			
			if self.nightVisionCur < 0.995 then 
				self.nightVisionCur = self.nightVisionCur + 0.02 *(1 - self.nightVisionCur)
			end
		
			nightVision_ColorMod["$pp_colour_brightness"] = self.nightVisionCur * 0.8
			nightVision_ColorMod["$pp_colour_contrast"]   = self.nightVisionCur * 1.1
		
			DrawColorModify(nightVision_ColorMod)
			DrawBloom(0, self.nightVisionCur * 3.6, 0.1, 0.1, 1, self.nightVisionCur * 0.5, 0, 1, 0)
		end
	end
end

function GM:RestartRound()
	if IsValid(self.trapPanel) then
		trapPanel:Remove()
	end
	
	if IsValid(self.powerMenu) then
		self.powerMenu:Remove()
	end
	
	GAMEMODE.ZombieGroups = nil
	GAMEMODE.SelectedZombieGroups = nil
	
	placingShockWave = false
	placingZombie = false
	placingRally = false
	
	zombieMenu = nil
	
	mouseX, mouseY  = 0, 0
	traceX, traceY  = 0, 0
	isDragging = false
	holdTime = 0
	
	gui.EnableScreenClicker(false)
end

net.Receive("zm_gamemodecall", function(length)
	gamemode.Call(net.ReadString())
end)

net.Receive("zm_centernotify", function(length)
	local tab = net.ReadTable()
	GAMEMODE:CenterNotify(unpack(tab))
end)

net.Receive("zm_topnotify", function(length)
	local tab = net.ReadTable()
	GAMEMODE:TopNotify(unpack(tab))
end)

net.Receive("zm_mapinfo", function(length)
	GAMEMODE.MapInfo = net.ReadString()
end)

net.Receive("zm_sendcurrentgroups", function(length)
	GAMEMODE.ZombieGroups = net.ReadTable()
	GAMEMODE.bUpdateGroups = true
end)

net.Receive("zm_sendselectedgroup", function(length)
	GAMEMODE.SelectedZombieGroups = net.ReadUInt(8)
end)