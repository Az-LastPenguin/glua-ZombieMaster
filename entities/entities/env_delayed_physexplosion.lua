AddCSLuaFile()

ENT.Type = "anim"

util.PrecacheSound("ZMPower.PhysExplode_Buildup")
util.PrecacheSound("ZMPower.PhysExplode_Boom")

function ENT:DelayedExplode(delay)
	self:SetSolid( SOLID_NONE )
	self:AddEffects( EF_NODRAW )
	self:SetMoveType( MOVETYPE_NONE )
	
	self:CreateDelayEffects(delay)
	self:NextThink(CurTime() + delay)
	self.delayset = true
end

function ENT:Think()
	if self.delayset then
		self:EmitSound("ZMPower.PhysExplode_Boom")

		if SERVER then
			//make players in range drop their stuff, radius is cvar'd
			for _, ent in pairs(ents.FindInSphere(self:LocalToWorld(self:OBBCenter()), GetConVar("zm_physexp_forcedrop_radius"):GetFloat())) do
				if IsValid(ent) and not ent:IsPlayer() then
					DropEntityIfHeld(ent)
				end
			end
		end

		//actual physics explosion
		local entity = ents.Create( "env_physexplosion" )
		if IsValid( entity ) then
			entity:SetPos( self:GetPos() )
			entity:SetKeyValue( "magnitude", ZM_PHYSEXP_DAMAGE )
			entity:SetKeyValue( "radius", ZM_PHYSEXP_RADIUS )
			local spawnflags = bit.bor(SF_PHYSEXPLOSION_NODAMAGE, SF_PHYSEXPLOSION_DISORIENT_PLAYER)
			entity:SetKeyValue( "spawnflags", spawnflags )
			entity:Spawn( )
			entity:Activate()
			entity:Fire( "Explode", "", 0 )
			entity:Fire( "Kill", "", 0.5 )
		end
			
		//another run for good measure
		local effectdata = EffectData()
		effectdata:SetOrigin(self:GetPos())
		effectdata:SetMagnitude(15)
		effectdata:SetScale(3)
		util.Effect("Sparks",effectdata)

		//TGB: clean ourselves up, else we stay around til round end
		self:Remove()
		self.sparks:Remove()
		return true
	end
end

function ENT:CreateDelayEffects(delay)
	self:EmitSound("ZMPower.PhysExplode_Buildup")

	//TGB: we want a particle effect instead
	local effectdata = EffectData()
	effectdata:SetOrigin(self:GetPos())
	effectdata:SetMagnitude(1)
	effectdata:SetScale(5)
	util.Effect("Sparks",effectdata)

	self.sparks = ents.Create("env_spark")
	
	local ent = self.sparks
	if IsValid(ent) then
		local SF_SPARK_START_ON = 64
		local SF_SPARK_GLOW	= 128
		local SF_SPARK_SILENT = 256
		
		local spawnflags = bit.bor(ent:GetSpawnFlags(), SF_SPARK_START_ON, SF_SPARK_GLOW, SF_SPARK_SILENT )

		ent:SetKeyValue("spawnflags", spawnflags)
		ent:SetKeyValue("MaxDelay", 0.1)
		ent:SetKeyValue("Magnitude", 2)
		ent:SetKeyValue("TrailLength", 1.5)

		//modify delay to account for delayed dying of sparker
		delay = delay - 2.2
		ent:SetKeyValue("DeathTime", (CurTime() + delay))

		ent:Spawn()
		ent:SetPos(self:GetPos())
	end
end