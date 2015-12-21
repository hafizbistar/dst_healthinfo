------------------------ PART I -------------------------
------------------------ Common -------------------------
--- DS? DST? Host? Dedicated? Who know??
local _G=GLOBAL
local require = GLOBAL.require
local TheNet = _G.rawget(_G,"TheNet")
local show_type = GetModConfigData("show_type")
local divider = GetModConfigData("divider")
local ds = {"-","[","(","{","<"} ds=ds[divider or 0] or ""
local de = {"-","]",")","}",">"} de=de[divider or 0] or ""

local SHOULD_OVERWRITE_ACTION = nil

local function AddString(name,cur,mx) --cur and mx are float!
	if type(name) == "string" then
		if show_type == 0 then
			name = name.." "..ds..math.floor(cur+0.5).." / "..math.floor(mx+0.5) ..de -- +0.5 means round fn
		elseif show_type == 1 then
			name = name.." "..ds..math.floor(cur*100/(mx or 1)+0.5).."%"..de
		else
			name = name.." "..ds..math.floor(cur+0.5).." / "..math.floor(mx+0.5) .." "..math.floor(cur*100/(mx or 1)+0.5).."%"..de
		end
	end
	return name
end


--Small easy tech function for injection
local function InjectFull(comp,fn_name,fn)
	--print("Full Inject: ",tostring(comp),tostring(fn_name),tostring(fn))
	local old = comp[fn_name]
	comp[fn_name] = function(self,...)
		local res = old(self,...)
		return fn(res,self,...)
	end
end

local controller = require "components/playercontroller"
InjectFull(controller,"GetLeftMouseAction",function(lmb)
	if not lmb then
		return lmb
	end
	if not(lmb.target and lmb.invobject == nil and lmb.target ~= lmb.doer) then
		--No DisplayName. We should add info in lmb:GetActionString().
		SHOULD_OVERWRITE_ACTION = true
	end
	return lmb
end)

--Clear overwriting info (just for sure)
InjectFull(controller,"GetRightMouseAction",function(res)
	SHOULD_OVERWRITE_ACTION = nil
	return res
end)
InjectFull(controller,"DoAction",function(res)
	SHOULD_OVERWRITE_ACTION = nil
	return res --j
end)

--local b_action = require "bufferedaction"
InjectFull(_G.BufferedAction,"GetActionString",function(str,self)
	if SHOULD_OVERWRITE_ACTION then
		if self.target then
			if TheNet ~= nil and self.target.health_info then
				--print("OVERWRITE (TheNet)")
				str = AddString(str,self.target.health_info,self.target.health_info_max)
			elseif TheNet == nil and self.target.components.health then
				--print("OVERWRITE (DS)")
				str = AddString(str,self.target.components.health.currenthealth,self.target.components.health.maxhealth)
			end
		end
		SHOULD_OVERWRITE_ACTION = nil
	end
	return str
end)


-------------Mini code for DS version------------
if TheNet == nil then
	--print("THIS IS SINGLE DS VERSION")
	InjectFull(_G.EntityScript,"GetDisplayName",function(name,inst)
		local comp = inst.components.health or inst.components.boathealth
		if comp ~= nil then
			name = AddString(name,comp.currenthealth,comp.maxhealth)
		end
		return name
	end)

	return --EXIT THE MOD if this is DS version.
end

---------------------------- PART II -----------------------
---------------------------- Only DST ----------------------
-- Client? Server? Who knows?


local IsServer = TheNet:GetIsServer()
local IsDedicated = TheNet:IsDedicated()
--print("IS_SERVER = "..tostring(IsServer))
--print("IS_DEDICATED = "..tostring(IsDedicated))

--Very fast decisions.
local BLACK_FILTER_CACHED = {nil,nil,nil,nil,nil,nil,nil,nil,nil,} --no add health_info
local WHITE_FILTER_CACHED = {nil,nil,nil,nil,nil,nil,nil,nil,nil,} --always add health_info

--Our cool filters with black Jack

local function BlackFilter(inst)
	if not (inst.Network ~= nil and inst.Transform ~= nil) then --and inst.prefab == "spider") then
		--print(inst.prefab.." - now in BLACKLIST")
		return true
	end
end

local function WhiteFilter(inst)
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
		--print(inst.prefab.." - WhiteList")
		return true
	end
end

--We need to decide to add or not to add health_info net variable BEFORE initialization.
--TRUE if we need health_info.
local function CheckInstHasHealth(inst)
	--Check for cached tables.
	if BLACK_FILTER_CACHED[inst.prefab] ~= nil then
		--print("already in black list")
		return
	end
	if WHITE_FILTER_CACHED[inst.prefab] ~= nil then
		return true
	end
	--Try to analyse via our cool filters.
	if BlackFilter(inst) then
		BLACK_FILTER_CACHED[inst.prefab] = true
		return
	end
	if WhiteFilter(inst) then
		WHITE_FILTER_CACHED[inst.prefab] = true
		return true
	end
	--All filter are passed without any result! That's too bad!
	--Decision for ALL unknown prefabs:
	--print("DEFAULT DECISION: "..inst.prefab.." - BLACK LIST")
	BLACK_FILTER_CACHED[inst.prefab] = true
	--Test health component.
	if inst.components.health or inst.components.boathealth then --ERROR! Can't synchronize it without updating the mod!
		print("----------------- HEALTH INFO WARNING ------------------")
		print("Prefab: "..tostring(inst.prefab).." has health component!")
		print("The mod should be fixed to support this prefab.")
		print("Please, show this log message to author of Mod Info mod.")
		print("--------------------------------------------------------")
	end
end

--Two dirty client functions
local function OnHealthInfoDirty(inst)
    inst.health_info = inst.net_health_info:value()
end
local function OnHealthInfoMaxDirty(inst)
    inst.health_info_max = inst.net_health_info_max:value()
end

--[[
local function debug_log(inst,mess)
	if inst.prefab == "rabbit" then
		print(inst.prefab,mess)
	end
end
--]]

--Initialization of all prefabs.
AddPrefabPostInitAny(function(inst)
	--print("NEW PREFAB - ",inst)
	--print("already in white list")
	if CheckInstHasHealth(inst) == nil then
		--debug_log(inst,"Bad prefab")
		return --Do not add health_info!
	end
	inst.health_info = 0
	inst.health_info_max = 0 --should be exact 0 because we will check it later if it's not zero.
	inst.net_health_info = _G.net_ushortint(inst.GUID, "health_info", "health_info_dirty")
	inst.net_health_info_max = _G.net_ushortint(inst.GUID, "health_info_max", "health_info_max_dirty")
	if not IsDedicated then
		--Means client OR host.
		--debug_log(inst,"not dedicated")
		inst:ListenForEvent("health_info_dirty", OnHealthInfoDirty)
		inst:ListenForEvent("health_info_max_dirty", OnHealthInfoMaxDirty)
	end
	if not _G.TheWorld.ismastersim then
		--Meand only client.
		--debug_log(inst,"ismastersim, return")
		return
	end
	--Only server code...
	if inst.components.health then
		--debug_log(inst,"has health "..tostring(inst.components.health.currenthealth).." "..tostring(inst.components.health.maxhealth))
		inst.net_health_info:set(inst.components.health.currenthealth)
		inst.net_health_info_max:set(inst.components.health.maxhealth)
	end
end)

--Inject in DisplayName dunction
InjectFull(_G.EntityScript,"GetDisplayName",function(name,self)
	if self.health_info_max ~= nil and self.health_info_max ~= 0 then
		name = AddString(name,self.health_info,self.health_info_max)
	end
	return name
end)

-----Only Server Side -----
if not IsServer then
	return
end

--------------------------------- PART III ------------------------------
------------------------- Only Server Side code -------------------------


local health = require "components/health"
InjectFull(health,"SetCurrentHealth",function(aaa,self)
	--print("Set health = "..tostring(self.currenthealth))
	if self.inst.health_info ~= nil then
		self.inst.net_health_info:set(self.currenthealth)
	end
end)
InjectFull(health,"SetMaxHealth",function(aaa,self)
	if self.inst.health_info ~= nil then
		self.inst.net_health_info:set(self.currenthealth)
		self.inst.net_health_info_max:set(self.maxhealth)
	end
end)
InjectFull(health,"DoDelta",function(aaa,self)
	if self.inst.health_info ~= nil then
		self.inst.net_health_info:set(self.currenthealth)
	end
end)

