local require = GLOBAL.require
local TheInput = GLOBAL.TheInput
local ThePlayer = GLOBAL.ThePlayer
local IsServer = GLOBAL.TheNet:GetIsServer()
local show_type = GetModConfigData("show_type")

-- for key,value in pairs(GLOBAL.EQUIPSLOTS) do print('4r',key,value) end

function GetHealth(e)  
	if e ~= nil and e.components ~= nil and e.components.health and e.components.healthinfo then
		local str = e.components.healthinfo.text
		local h=e.components.health
		local mx=math.floor(h.maxhealth-h.minhealth)
		local cur=math.floor(h.currenthealth-h.minhealth)

		local i,j = string.find(str, " [", nil, true)
		if i ~= nil and i > 1 then str = string.sub(str, 1, (i-1)) end

		if type( mx ) == "number" and type( cur ) == "number" then
			if show_type == 0 then
				str = "["..cur.." / "..mx .."]"
			elseif show_type == 1 then
				str = "["..math.floor(cur*100/mx).."%]"
			else
				str = "["..cur.." / "..mx .." "..math.floor(cur*100/mx).."%]"
			end
		end

		if e.components.healthinfo then
			e.components.healthinfo:SetText(str)
		end
	end
end

AddClassPostConstruct("components/health_replica", function(self)
	self.SetCurrent = function(self, current)
		GetHealth(self.inst)
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
				--	local name = lmb.target:GetDisplayName() or (lmb.target.components.named and lmb.target.components.named.name)


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

AddGlobalClassPostConstruct('widgets/controls', 'Controls', function(self)
	local original_OnUpdate = self.OnUpdate
	self.OnUpdate = function(self)
		-- original_OnUpdate(self)
		if PerformingRestart then
			self.playeractionhint:SetTarget(nil)
			self.playeractionhint_itemhighlight:SetTarget(nil)
			self.attackhint:SetTarget(nil)
			self.groundactionhint:SetTarget(nil)
			return
		end

		local controller_mode = TheInput:ControllerAttached()
		local controller_id = TheInput:GetControllerID()

		if controller_mode then
			self.mapcontrols:Hide()
		else
			self.mapcontrols:Show()
		end

		for k,v in pairs(self.containers) do
			if v.should_close_widget then
				self.containers[k] = nil
				v:Kill()
			end
		end

		if self.demotimer then
			if GLOBAL.IsGamePurchased() then
				self.demotimer:Kill()
				self.demotimer = nil
			end
		end

		local shownItemIndex = nil
		local itemInActions = false		-- the item is either shown through the actionhint or the groundaction

		if controller_mode and not (self.inv.open or self.crafttabs.controllercraftingopen) and self.owner:IsActionsVisible() then

			local ground_l, ground_r = self.owner.components.playercontroller:GetGroundUseAction()
			local ground_cmds = {}
			if self.owner.components.playercontroller.deployplacer or self.owner.components.playercontroller.placer then
				local placer = self.terraformplacer

				if self.owner.components.playercontroller.deployplacer then
					self.groundactionhint:Show()
					self.groundactionhint:SetTarget(self.owner.components.playercontroller.deployplacer)

					if self.owner.components.playercontroller.deployplacer.components.placer.can_build then
						if TheInput:ControllerAttached() then
							self.groundactionhint.text:SetString(TheInput:GetLocalizedControl(controller_id, GLOBAL.CONTROL_CONTROLLER_ACTION) .. " " .. self.owner.components.playercontroller.deployplacer.components.placer:GetDeployAction():GetActionString().."\n"..TheInput:GetLocalizedControl(controller_id, GLOBAL.CONTROL_CONTROLLER_ALTACTION).." "..GLOBAL.STRINGS.UI.HUD.CANCEL)
						else
							self.groundactionhint.text:SetString(TheInput:GetLocalizedControl(controller_id, GLOBAL.CONTROL_CONTROLLER_ACTION) .. " " .. self.owner.components.playercontroller.deployplacer.components.placer:GetDeployAction():GetActionString())
						end

					else
						self.groundactionhint.text:SetString("")
					end

				elseif self.owner.components.playercontroller.placer then
					self.groundactionhint:Show()
					self.groundactionhint:SetTarget(self.owner)
					self.groundactionhint.text:SetString(TheInput:GetLocalizedControl(controller_id, GLOBAL.CONTROL_CONTROLLER_ACTION) .. " " .. GLOBAL.STRINGS.UI.HUD.BUILD.."\n" .. TheInput:GetLocalizedControl(controller_id, GLOBAL.CONTROL_CONTROLLER_ALTACTION) .. " " .. GLOBAL.STRINGS.UI.HUD.CANCEL.."\n")
				end
			elseif ground_r ~= nil then
				self.groundactionhint:Show()
				self.groundactionhint:SetTarget(self.owner)
				table.insert(ground_cmds, TheInput:GetLocalizedControl(controller_id, GLOBAL.CONTROL_CONTROLLER_ALTACTION) .. " " .. ground_r:GetActionString())
				self.groundactionhint.text:SetString(table.concat(ground_cmds, "\n"))
			else
				self.groundactionhint:Hide()
			end

			local attack_shown = false
			local controller_target = self.owner.components.playercontroller:GetControllerTarget()
			local controller_attack_target = self.owner.components.playercontroller:GetControllerAttackTarget()
			if controller_target ~= nil then
				local cmds = {}
				local textblock = self.playeractionhint.text
				if self.groundactionhint.shown and GLOBAL.distsq(self.owner:GetPosition(), controller_target:GetPosition()) < 1.33 then
					--You're close to your target so we should combine the two text blocks.
					cmds = ground_cmds
					textblock = self.groundactionhint.text
					self.playeractionhint:Hide()
					itemInActions = false
				else
					self.playeractionhint:Show()
					self.playeractionhint:SetTarget(controller_target)
					itemInActions = true
				end

				local l, r = self.owner.components.playercontroller:GetSceneItemControllerAction(controller_target)
				-- table.insert(cmds, " ")
				shownItemIndex = #cmds
				local health = ""
				if controller_target and controller_target.components and controller_target.components.healthinfo and controller_target.components.healthinfo.text ~= '' then
					health = controller_target.components.healthinfo.text
				end
				table.insert(cmds, controller_target:GetDisplayName() .. " " ..health)
				if controller_target == controller_attack_target then
					table.insert(cmds, TheInput:GetLocalizedControl(controller_id, GLOBAL.CONTROL_CONTROLLER_ATTACK) .. " " .. GLOBAL.STRINGS.UI.HUD.ATTACK)
					attack_shown = true
				end
				if self.owner:CanExamine() then
					table.insert(cmds, TheInput:GetLocalizedControl(controller_id, GLOBAL.CONTROL_INSPECT) .. " " .. GLOBAL.STRINGS.UI.HUD.INSPECT)
				end
				if l ~= nil then
					table.insert(cmds, TheInput:GetLocalizedControl(controller_id, GLOBAL.CONTROL_CONTROLLER_ACTION) .. " " .. l:GetActionString())
				end
				if r ~= nil and ground_r == nil then
					table.insert(cmds, TheInput:GetLocalizedControl(controller_id, GLOBAL.CONTROL_CONTROLLER_ALTACTION) .. " " .. r:GetActionString())
				end

				textblock:SetString(table.concat(cmds, "\n"))
			else
				self.playeractionhint:Hide()
				self.playeractionhint:SetTarget(nil)
			end

			if controller_attack_target ~= nil and not attack_shown then
				self.attackhint:Show()
				self.attackhint:SetTarget(controller_attack_target)
				local health = ""
				if controller_attack_target and controller_attack_target.components and controller_attack_target.components.healthinfo and controller_attack_target.components.healthinfo.text ~= '' then
					health = controller_attack_target:GetDisplayName() .. " " .. controller_attack_target.components.healthinfo.text
				end

				self.attackhint.text:SetString(TheInput:GetLocalizedControl(controller_id, GLOBAL.CONTROL_CONTROLLER_ATTACK) .. " " .. GLOBAL.STRINGS.UI.HUD.ATTACK .. " " .. health)
			else
				self.attackhint:Hide()
				self.attackhint:SetTarget(nil)
			end
		else
			self.attackhint:Hide()
			self.attackhint:SetTarget(nil)

			self.playeractionhint:Hide()
			self.playeractionhint:SetTarget(nil)

			self.groundactionhint:Hide()
			self.groundactionhint:SetTarget(nil)
		end

		--default offsets
		self.playeractionhint:SetScreenOffset(0,0)
		self.attackhint:SetScreenOffset(0,0)

		--if we are showing both hints, make sure they don't overlap
		if self.attackhint.shown and self.playeractionhint.shown then

			local w1, h1 = self.attackhint.text:GetRegionSize()
			local x1, y1 = self.attackhint:GetPosition():Get()
			--print (w1, h1, x1, y1)

			local w2, h2 = self.playeractionhint.text:GetRegionSize()
			local x2, y2 = self.playeractionhint:GetPosition():Get()
			--print (w2, h2, x2, y2)

			local sep = (x1 + w1/2) < (x2 - w2/2) or
						(x1 - w1/2) > (x2 + w2/2) or
						(y1 + h1/2) < (y2 - h2/2) or
						(y1 - h1/2) > (y2 + h2/2)

			if not sep then
				local a_l = x1 - w1/2
				local a_r = x1 + w1/2

				local p_l = x2 - w2/2
				local p_r = x2 + w2/2

				if math.abs(p_r - a_l) < math.abs(p_l - a_r) then
					local d = (p_r - a_l) + 20
					self.attackhint:SetScreenOffset(d/2,0)
					self.playeractionhint:SetScreenOffset(-d/2,0)
				else
					local d = (a_r - p_l) + 20
					self.attackhint:SetScreenOffset( -d/2,0)
					self.playeractionhint:SetScreenOffset(d/2,0)
				end
			end
		end

		self:HighlightActionItem(shownItemIndex, itemInActions)
	end
end)

AddPrefabPostInitAny(function(inst)
	if inst.components.healthinfo == nil then
		if  inst:HasTag("hive") or 
			inst:HasTag("eyeturret") or 
			inst:HasTag("houndmound") or 
			inst:HasTag("ghost") or 
			inst:HasTag("insect") or 
			inst:HasTag("spider") or
			inst:HasTag("chess") or 
			inst:HasTag("mech") or
			inst:HasTag("mound") or
			inst:HasTag("shadow") or
			inst:HasTag("tree") or
			inst:HasTag("veggie") or
			inst:HasTag("shell") or
			inst:HasTag("rocky") or
			inst:HasTag("smallcreature") or
			inst:HasTag("largecreature") or
			inst:HasTag("wall") or
			inst:HasTag("character") or
			inst:HasTag("companion") or
			inst:HasTag("glommer") or
			inst:HasTag("animal") or
			inst:HasTag("monster") or
			inst:HasTag("prey") or
			inst:HasTag("scarytoprey") or
			inst:HasTag("player") 
									then

			if inst.components.healthinfo ~= nil then
				inst:AddComponent("healthinfo")
			end
			if inst.components.health then
				GetHealth(inst)
			end
		end
	end
end)