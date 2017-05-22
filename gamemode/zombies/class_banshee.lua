NPC.Class = "npc_fastzombie"
NPC.Name = translate.Get("npc_class_banshee")
NPC.Description = translate.Get("npc_description_banshee")
NPC.Icon = "VGUI/zombies/info_banshee"
NPC.Flag = FL_SPAWN_BANSHEE_ALLOWED
NPC.Cost = GetConVar("zm_cost_banshee"):GetInt()
NPC.PopCost = GetConVar("zm_popcost_banshee"):GetInt()
NPC.Health = GetConVar("zm_fastzombie_health"):GetInt()

NPC.Model = "models/zombie/zm_fast.mdl"
NPC.DelaySetModel = true
NPC.DieSound = "NPC_FastZombie.Die"
NPC.CanClingToCeiling = true

if SERVER then
	NPC.Capabilities = bit.bor(CAP_MOVE_GROUND, CAP_MOVE_JUMP, CAP_MOVE_CLIMB, CAP_INNATE_MELEE_ATTACK1, CAP_INNATE_RANGE_ATTACK1, CAP_SKIP_NAV_GROUND_CHECK)
end

function NPC:OnSpawned(npc)
	self.Base.OnSpawned(self, npc)
	
	npc.NextLeap = CurTime()
	npc:SetNW2Bool("bClingingCeiling", false)
	
	timer.Simple(0, function()
		npc:SetModelScale(0.855)
		npc:SetHullSizeNormal()
	end)
end

function NPC:OnKilled(npc, attacker, inflictor)
	self.Base.OnKilled(self, npc, attacker, inflictor)
	npc:SetNW2Bool("bClingingCeiling", false)
end

function NPC:Think(npc)
	local enemy = npc:GetEnemy()
	if IsValid(enemy) then
		local distance = npc:GetPos():Distance(enemy:GetPos())
		if distance < 360 and distance > 72 then
			if npc:HasCondition(COND_SEE_ENEMY) and not npc:HasCondition(COND_FLOATING_OFF_GROUND) and npc.NextLeap < CurTime() then	
				npc.NextLeap = CurTime() + 4
				npc:SetSchedule(SCHED_RANGE_ATTACK1)
			end
		end
	end
end

function NPC:IsCeilingFlat(npc, plane_normal)
	local flat = Vector(0, 0, -1)
	local roofdot = math.abs(plane_normal:Dot(flat))

	if roofdot > 0.95 then
		return true
	end

	return false
end

function NPC:CheckCeiling(npc, maxheight)
	local upwards = Vector(0, 0, maxheight or 375)
	local trace = {start = npc:GetPos(), endpos = npc:GetPos() + upwards, filter = npc, mask = MASK_SOLID}
	local tr = util.TraceLine(trace)

	if tr.Fraction ~= 1.0 and tr.HitWorld and not tr.HitSky then
		if self:IsCeilingFlat(npc, tr.HitNormal) then
			local startpos = npc:GetPos()
			local targetpos = tr.HitPos - Vector(0, 0, 12)
			local targetang = npc:GetAngles()
			targetang.roll = -180
			
			local timername = "npc_gotoceiling:"..npc:EntIndex()
			timer.Create(timername, 0, 0, function()
				if not IsValid(npc) or not npc.m_bClinging then timer.Remove(timername) return end
				
				if npc:GetAngles() == targetang then
					timer.Remove(timername)
				end
				
				local fraction = FrameTime() * 5.0
				local topos = LerpVector(fraction, npc:GetPos(), targetpos)
				local toang = LerpAngle(fraction, npc:GetAngles(), targetang)
				npc:SetPos(topos)
				npc:SetAngles(toang)
			end)
			
			return true
		end
	end

	return false
end

function NPC:GetClingAmbushTarget(npc)
	local count = ents.FindInSphere(npc:GetPos(), 64)
	
	local nearest = NULL
	local nearest_dist = 0
	for _, ent in pairs(count) do
		if not ent:IsPlayer() or not ent:IsSurvivor() then continue end

		local current_dist = npc:GetPos():Distance(ent:GetPos())
		if not IsValid(nearest) or nearest_dist > current_dist then
			nearest = ent
			nearest_dist = current_dist
		end
	end

	return nearest
end

function NPC:OnForceGo(npc)
	if npc.m_bClinging then
		self:DetachFromCeiling(npc)
	end
end

function NPC:DetachFromCeiling(npc)
	npc:SetNW2Bool("bClingingCeiling", false)
	npc:SetMoveType(self.MoveType)
	
	npc:SetPos(npc:GetPos() - Vector(0, 0, npc:OBBMaxs().z * 0.95))
	npc:SetAngles(Angle(0, 0, 0))
end

function NPC:Think(npc)
	self.BaseClass.Think(self, npc)
	
	if npc.m_bClinging and npc.m_flLastClingCheck and npc.m_flLastClingCheck < CurTime() then
		local nearest = self:GetClingAmbushTarget(npc)
		
		if IsValid(nearest) then
			npc:SetEnemy(nearest)
			self:DetachFromCeiling(npc)
			return
		end
		
		npc.m_flLastClingCheck = CurTime() + 1.0
	end
end