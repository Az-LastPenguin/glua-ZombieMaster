ENT.Type = "point"

local SF_ENVTEXT_ALLPLAYERS = 0x0001

function ENT:KeyValue(key, value)
	key = string.lower(key)
	if key == "color" then
		self.Color1 = self.Color1 or string.ToColor(value)
	elseif key == "color2" then
		self.Color2 = self.Color2 or string.ToColor(value)
	elseif key == "x" then
		self.XPos = self.XPos or tonumber(value)
	elseif key == "y" then
		self.YPos = self.YPos or tonumber(value)
	elseif key == "fadein" then
		self.FadeInTime = self.FadeInTime or tonumber(value)
	elseif key == "fadeout" then
		self.FadeOutTime = self.FadeOutTime or tonumber(value)
	elseif key == "holdtime" then
		self.HoldTime = self.HoldTime or tonumber(value)
	elseif key == "message" then
		self.Message = self.Message or value
	end
end

function ENT:AcceptInput(name, caller, activator, arg)
	name = string.lower(name)
	if name == "display" then
		self:InputDisplay(activator)
		return true
	end
end

function ENT:InputDisplay(activator)
	self:Display(activator)
end

function ENT:Display(activator)
	if not self:CanFireForActivator(activator) then
		return
	end

	local messagetab = {
		Color1 = self.Color1,
		Color2 = self.Color2,
		XPos = self.XPos,
		YPos = self.YPos,
		FadeInTime = self.FadeInTime,
		FadeOutTime = self.FadeOutTime,
		HoldTime = self.HoldTime,
		Font = "zm_game_text_small",
		Message = {self.Message}
	}
	if self:MessageToAll() then
		util.PrintMessageBold("GameText_"..self:EntIndex(), messagetab)
	else
		util.PrintMessage("GameText_"..self:EntIndex(), activator, messagetab)
	end
end

function ENT:CanFireForActivator(activator)
	return true
end

function ENT:MessageToAll()
	return self:HasSpawnFlags(SF_ENVTEXT_ALLPLAYERS)
end