AddCSLuaFile()
DEFINE_BASECLASS("player_basezm")

local PLAYER = {}

function PLAYER:Spawn()
    BaseClass.Spawn(self)
    
    self.Player:Spectate(OBS_MODE_ROAMING)
    self.Player:Flashlight(false)
    self.Player:SetMoveType(MOVETYPE_NOCLIP)
    self.Player:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
    self.Player:RemoveEffects(EF_DIMLIGHT)
    
    self.Player:GodEnable()
end

function PLAYER:CanSuicide()
    return false
end

function PLAYER:PostOnDeath(inflictor, attacker)
    BaseClass.PostOnDeath(self, inflictor, attacker)
    
    timer.Simple(1, function()
        if IsValid(self.Player) and self.Player:IsSpectator() and self.Player:GetObserverMode() ~= OBS_MODE_ROAMING then
            self.Player:Spectate(OBS_MODE_ROAMING)
        end
    end)
end

function PLAYER:KeyPress(key)
    if SERVER then
        if key == IN_RELOAD then
            self.Player:Spectate(OBS_MODE_ROAMING)
            self.Player:SpectateEntity(NULL)
            self.Player.SpectatedPlayerKey = nil
        elseif key == IN_ATTACK then
            if self.Player:GetObserverMode() == OBS_MODE_ROAMING then
                local tr = util.GetPlayerTrace(self.Player)
                tr.filter = function(ent)
                    return ent:IsNPC() or ent:IsPlayer()
                end
                
                local trace = util.TraceLine(tr)
                if IsValid(trace.Entity) then
                    self.Player:Spectate(OBS_MODE_CHASE)
                    self.Player:SpectateEntity(trace.Entity)
                    return
                end
            end
            
            local players = {}
            for _, pl in pairs(player.GetAll()) do
                if pl:Team() ~= TEAM_SPECTATOR and pl:Alive() and pl ~= self.Player then
                    players[#players + 1] = pl
                end
            end
            
            self.Player.SpectatedPlayerKey = (self.Player.SpectatedPlayerKey or 1) + 1
            if self.Player.SpectatedPlayerKey > #players then
                self.Player:Spectate(OBS_MODE_ROAMING)
                self.Player:SpectateEntity(NULL)
                self.Player.SpectatedPlayerKey = 1
            end

            self.Player:StripWeapons()
            local specplayer = players[self.Player.SpectatedPlayerKey]
            if specplayer then
                self.Player:Spectate(OBS_MODE_CHASE)
                self.Player:SpectateEntity(specplayer)
            else
                self.Player:Spectate(OBS_MODE_ROAMING)
                self.Player:SpectateEntity(NULL)
                self.Player.SpectatedPlayerKey = nil
            end
        elseif key == IN_ATTACK2 then
            local players = {}
            for _, pl in pairs(player.GetAll()) do
                if pl:Team() ~= TEAM_SPECTATOR and pl:Alive() and pl ~= self.Player then
                    players[#players + 1] = pl
                end
            end
            
            self.Player.SpectatedPlayerKey = (self.Player.SpectatedPlayerKey or 2) - 1
            if self.Player.SpectatedPlayerKey <= 0 then
                self.Player:Spectate(OBS_MODE_ROAMING)
                self.Player:SpectateEntity(NULL)
                self.Player.SpectatedPlayerKey = #players
            end

            self.Player:StripWeapons()
            local specplayer = players[self.Player.SpectatedPlayerKey]
            if specplayer then
                self.Player:Spectate(OBS_MODE_CHASE)
                self.Player:SpectateEntity(specplayer)
            else
                self.Player:Spectate(OBS_MODE_ROAMING)
                self.Player:SpectateEntity(NULL)
                self.Player.SpectatedPlayerKey = nil
            end
        end
    end
end

function PLAYER:CalcView(view)
    local target = self.Player:GetObserverTarget()
    if IsValid(target) and target:IsNPC() and self.Player:GetObserverMode() ~= OBS_MODE_ROAMING then
        local tr = {
            start = target:WorldSpaceCenter(),
            endpos = target:WorldSpaceCenter() - (view.angles:Forward() * 150),
            filter = {target}
        }
        local trace = util.TraceLine(tr)
        
        view.origin = trace.HitPos + trace.HitNormal * 10
    end
end

function PLAYER:PostThink()
    -- This appears to fix PVS issues with sounds when using OBS_MODE_CHASE
    local target = self.Player:GetObserverTarget()
    if IsValid(target) and self.Player:GetObserverMode() ~= OBS_MODE_ROAMING then
        self.Player:SetPos(target:GetPos())
    end
        
    if SERVER then
        if self.Player:IsOnFire() then
            self.Player:Extinguish()
        end
        
        if not IsValid(target) or not target:Alive() or target:Team() == TEAM_SPECTATOR then
            self.Player:StripWeapons()
            self.Player:Spectate(OBS_MODE_ROAMING)
            self.Player:SpectateEntity(NULL)
        end
    end
end

player_manager.RegisterClass("player_spectator", PLAYER, "player_basezm")