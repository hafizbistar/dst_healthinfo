local require = GLOBAL.require
local TheInput = GLOBAL.TheInput
local ThePlayer = GLOBAL.ThePlayer
local IsServer = GLOBAL.TheNet:GetIsServer()
local show_type = GetModConfigData("show_type")

-- for key,value in pairs(GLOBAL.EQUIPSLOTS) do print('4r',key,value) end

AddClassPostConstruct("components/health_replica", function(self)
	self.SetCurrent = function(self, current)

		if self.inst.components and self.inst.components.health and self.inst.components.healthinfo then
			local str = self.inst.components.healthinfo.text

			if str ~= nil then
				local h=self.inst.components.health
				local mx=math.floor(h.maxhealth-h.minhealth)
				local cur=math.floor(h.currenthealth-h.minhealth)

				local i,j = string.find(str, " [", nil, true)
				if i ~= nil and i > 1 then str = string.sub(str, 1, (i-1)) end

				if show_type == 0 then
					str = "["..cur.." / "..mx .."]"
				elseif show_type == 1 then
					str = "["..math.floor(cur*100/mx).."%]"
				else
					str = "["..cur.." / "..mx .." "..math.floor(cur*100/mx).."%]"
				end

				if self.inst.components.healthinfo then
					self.inst.components.healthinfo:SetText(str)
				end
				-- self.inst.name = str
			end
		end

		if self.classified ~= nil then
			self.classified:SetValue("currenthealth", current)
		end
	end
end)

AddGlobalClassPostConstruct('widgets/hoverer', 'HoverText', function(self)
	self.OnUpdate = function(self)
		local using_mouse = self.owner.components and self.owner.components.playercontroller:UsingMouse()

		if using_mouse ~= self.shown then
			if using_mouse then
				self:Show()
			else
				self:Hide()
			end
		end

		if not self.shown then
			return
		end

		local str = nil
		if self.isFE == false then
			str = self.owner.HUD.controls:GetTooltip() or self.owner.components.playercontroller:GetHoverTextOverride()
		else
			str = self.owner:GetTooltip()
		end

		local secondarystr = nil

		local lmb = nil
		if not str and self.isFE == false then
			lmb = self.owner.components.playercontroller:GetLeftMouseAction()
			if lmb then

				str = lmb:GetActionString()

				if lmb.target and lmb.invobject == nil and lmb.target ~= lmb.doer then
					local name = lmb.target:GetDisplayName() or (lmb.target.components.named and lmb.target.components.named.name)
	            --if lmb.target and lmb.target ~= lmb.doer then
	            --    local name = lmb.target:GetDisplayName() or (lmb.target.components.named and lmb.target.components.named.name)


					if name then
						local adjective = lmb.target:GetAdjective()

						if adjective then
							str = str.. " " .. adjective .. " " .. name
						else
							str = str.. " " .. name
						end

						if lmb.target.replica.stackable ~= nil and lmb.target.replica.stackable:IsStack() then
							str = str .. " x" .. tostring(lmb.target.replica.stackable:StackSize())
						end
						if lmb.target.components.inspectable and lmb.target.components.inspectable.recordview and lmb.target.prefab then
							GLOBAL.ProfileStatsSet(lmb.target.prefab .. "_seen", true)
						end
					end
				end

				if lmb.target and lmb.target ~= lmb.doer and lmb.target.components and lmb.target.components.healthinfo and lmb.target.components.healthinfo.text ~= '' then
					local name = lmb.target:GetDisplayName() or (lmb.target.components.named and lmb.target.components.named.name) or ""
					local i,j = string.find(str, " " .. name, nil, true)
					if i ~= nil and i > 1 then str = string.sub(str, 1, (i-1)) end
					str = str.. " " .. name .. " " .. lmb.target.components.healthinfo.text
				end
			end
			local rmb = self.owner.components.playercontroller:GetRightMouseAction()
			if rmb then
				secondarystr = GLOBAL.STRINGS.RMB .. ": " .. rmb:GetActionString()
			end
		end

		if str then
	    	if self.strFrames == nil then self.strFrames = 1 end

			if self.str ~= self.lastStr then
				--print("new string")
				self.lastStr = self.str
				self.strFrames = SHOW_DELAY
			else
				self.strFrames = self.strFrames - 1
				if self.strFrames <= 0 then
					if lmb and lmb.target and lmb.target:HasTag("player") then
						self.text:SetColour(lmb.target.playercolour)
					else
						self.text:SetColour(1,1,1,1)
					end
					self.text:SetString(str)
					self.text:Show()
				end
			end
		else
			self.text:Hide()
		end

		if secondarystr then
			YOFFSETUP = -80
			YOFFSETDOWN = -50
			self.secondarytext:SetString(secondarystr)
			self.secondarytext:Show()
		else
			self.secondarytext:Hide()
		end

		local changed = (self.str ~= str) or (self.secondarystr ~= secondarystr)
		self.str = str
		self.secondarystr = secondarystr
		if changed then
			local pos = TheInput:GetScreenPosition()
			self:UpdatePosition(pos.x, pos.y)
		end
	end
end)

AddPrefabPostInitAny(function(inst)
	if inst.components.healthinfo == nil then
		inst:AddComponent("healthinfo")
		if inst.components.health then
			str = ""
			local h=inst.components.health
			local mx=math.floor(h.maxhealth-h.minhealth)
			local cur=math.floor(h.currenthealth-h.minhealth)

			-- str = "["..cur.." / "..mx .."]"--.. " ("..math.floor(cur*100/mx).."%%)"

			if show_type == 0 then
				str = "["..cur.." / "..mx .."]"
			elseif show_type == 1 then
				str = "["..math.floor(cur*100/mx).."%]"
			else
				str = "["..cur.." / "..mx .." "..math.floor(cur*100/mx).."%]"
			end
			inst.components.healthinfo:SetText(str)
		end
	end
end)