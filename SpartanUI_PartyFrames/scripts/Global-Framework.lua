local spartan = LibStub("AceAddon-3.0"):GetAddon("SpartanUI");
local addon = spartan:GetModule("PartyFrames");
----------------------------------------------------------------------------------------------------
local default = {showAuras = 1,partyLock = 1,castbar = 1, castbartext = 1, HidePartyInRaid = 1, HideParty = 0, HidePlayer = 1, HideSolo = 1, Anchors = { point = "TOPLEFT", relativeTo = "UIParent", relativePoint = "TOPLEFT", xOfs = 10, yOfs = -20 }, };
suiChar.PartyFrames = suiChar.PartyFrames or {};
for k,v in pairs(default) do if not suiChar.PartyFrames[k] then suiChar.PartyFrames[k] = v end end
setmetatable(suiChar.PartyFrames,{__index = default});

local colors = setmetatable({},{__index = oUF.colors});
for k,v in pairs(oUF.colors) do if not colors[k] then colors[k] = v end end
colors.health = {0/255,255/255,50/255};
local base_plate = [[Interface\AddOns\SpartanUI_PartyFrames\media\base_plate1]]
local base_ring = [[Interface\AddOns\SpartanUI_PartyFrames\media\base_ring1]]

local menu = function(self)
	if (not self.id) then self.id = self.unit:match"^.-(%d+)" end
	local unit = string.gsub(self.unit,"(.)",string.upper,1);
	if (_G[unit..'FrameDropDown']) then
		ToggleDropDownMenu(1, nil, _G[unit..'FrameDropDown'], 'cursor')
	elseif ( (self.unit:match('party')) and (not self.unit:match('partypet')) ) then
		ToggleDropDownMenu(1, nil, _G["PartyMemberFrame"..self.id.."DropDown"], "cursor")
	else
		FriendsDropDown.unit = self.unit
		FriendsDropDown.id = self.id
		FriendsDropDown.initialize = RaidFrameDropDown_Initialize
		ToggleDropDownMenu(1, nil, FriendsDropDown, 'cursor')
	end
end

local simple = function(val)
	if (val >= 1e6) then -- 1 million
		return ("%.1f m"):format(val/1e6);
	else
		return val
	end
end

local threat = function(self,event,unit)
	if (not self.Portrait) then return; end
	if (not self.Portrait:IsObjectType("Texture")) then return; end
	unit = string.gsub(self.unit,"(.)",string.upper,1) or string.gsub(unit,"(.)",string.upper,1)
	local status
	if UnitExists(unit) then status = UnitThreatSituation(unit) else status = 0; end
--	print(unit..' '..status) -- Debug code
	if (status and status > 0) then
		local r,g,b = GetThreatStatusColor(status);
		self.Portrait:SetVertexColor(r,g,b);
	else
		self.Portrait:SetVertexColor(1,1,1);
	end
end

local petinfo = function(self,event)
	if self.Name then self.Name:UpdateTag(self.unit); end
	if self.Level then self.Level:UpdateTag(self.unit); end
end

local PostUpdateAura = function(self,unit)
	if UnitIsConnected(unit) then
		if suiChar and suiChar.PartyFrames and suiChar.PartyFrames.showAuras == 0 then
			self:Hide();
		else
			self:Show();
		end
	end
end

local PostUpdateHealth = function(bar, unit, min, max)
	if UnitIsConnected(unit) then
		if(UnitIsDead(unit)) then
			bar:SetValue(0);
			bar.value:SetText"Dead"
			bar.ratio:SetText""
		elseif(UnitIsGhost(unit)) then
			bar:SetValue(0)
			bar.value:SetText"Ghost"
			bar.ratio:SetText""
		else
			if ( unit:match('partypet') ) then
				bar.value:SetFormattedText("%s", simple(min))
			else
				bar.value:SetFormattedText("%s / %s", min,max)
			end
			bar.ratio:SetFormattedText("%d%%",(min/max)*100);
		end
	else
		
	end
end

local PostUpdatePower = function(bar, unit, min, max)
	if (UnitIsDead(unit) or UnitIsGhost(unit) or not UnitIsConnected(unit) or max == 0) then
		bar.value:SetText""
		bar.ratio:SetText""
	else
		if ( unit:match('partypet') ) then
			bar.value:SetFormattedText("%s", simple(min));
		else
			bar.value:SetFormattedText("%s / %s", min,max)
		end
		bar.ratio:SetFormattedText("%d%%",(min/max)*100);
	end
end

local PostCastStop = function(self)
	if self.Time then self.Time:SetTextColor(1,1,1); end
end

local PostCastStart = function(self,unit,name,rank,text,castid)
	self:SetStatusBarColor(1,0.7,0);
end

local PostChannelStart = function(self,unit,name,rank,text,castid)
	self:SetStatusBarColor(1,0.2,0.7);
	-- self:SetStatusBarColor(0,1,0); --B3
end

local OnCastbarUpdate = function(self,elapsed)
	if self.casting then
		self.duration = self.duration + elapsed
		if (self.duration >= self.max) then
			self.casting = nil;
			self:Hide();
			if PostCastStop then PostCastStop(self:GetParent()); end
			return;
		end
		if self.Time then
			if self.delay ~= 0 then self.Time:SetTextColor(1,0,0); else self.Time:SetTextColor(1,1,1); end
			if suiChar.PartyFrames.castbartext == 1 then
				self.Time:SetFormattedText("%.1f",self.max - self.duration);
			else
				self.Time:SetFormattedText("%.1f",self.duration);
			end
		end
		if suiChar.PartyFrames.castbar == 1 then
			self:SetValue(self.max-self.duration)
		else
			self:SetValue(self.duration)
		end
	elseif self.channeling then
		self.duration = self.duration - elapsed;
		if (self.duration <= 0) then
			self.channeling = nil;
			self:Hide();
			if PostChannelStop then PostChannelStop(self:GetParent()); end
			return;
		end
		if self.Time then
			if self.delay ~= 0 then self.Time:SetTextColor(1,0,0); else self.Time:SetTextColor(1,1,1); end
			self.Time:SetFormattedText("%.1f",self.max-self.duration);
		end
		if suiChar.PartyFrames.castbar == 1 then
			self:SetValue(self.duration)
		else
			self:SetValue(self.max-self.duration)
		end
	else
		self.unitName = nil;
		self.channeling = nil;
		self:SetValue(1);
		self:Hide();
	end
end

local CreatePartyFrame = function(self,unit)
	self:SetWidth(250); self:SetHeight(80);
	do -- setup base artwork
		local artwork = CreateFrame("Frame",nil,self);
		artwork:SetFrameStrata("BACKGROUND");
		artwork:SetFrameLevel(0); artwork:SetAllPoints(self);
		
		artwork.bg = artwork:CreateTexture(nil,"BACKGROUND");
		artwork.bg:SetPoint("TOPLEFT",artwork,"TOPLEFT",-2,10);
		artwork.bg:SetTexture(base_plate);
		
		self.Portrait = artwork:CreateTexture(nil,"BORDER");
		self.Portrait:SetWidth(55); self.Portrait:SetHeight(55);
		self.Portrait:SetPoint("LEFT",self,"LEFT",15,0);
		
		self.Threat = CreateFrame("Frame",nil,self);
		self.Threat.Override = threat;
	end
	do -- setup status bars
		do -- cast bar
			local cast = CreateFrame("StatusBar",nil,self);
			cast:SetFrameStrata("BACKGROUND"); cast:SetFrameLevel(2);
			cast:SetWidth(119); cast:SetHeight(16);
			cast:SetPoint("TOPRIGHT",self,"TOPRIGHT",-55,-24);
			
			cast.Text = cast:CreateFontString(nil, "OVERLAY", "SUI_FontOutline10");
			cast.Text:SetWidth(110); cast.Text:SetHeight(11);
			cast.Text:SetJustifyH("LEFT"); cast.Text:SetJustifyV("BOTTOM");
			cast.Text:SetPoint("RIGHT",cast,"RIGHT",-2,0);
			
			cast.Time = cast:CreateFontString(nil, "OVERLAY", "SUI_FontOutline10");
			cast.Time:SetWidth(40); cast.Time:SetHeight(11);
			cast.Time:SetJustifyH("LEFT"); cast.Time:SetJustifyV("BOTTOM");
			cast.Time:SetPoint("LEFT",cast,"RIGHT",2,0);
			
			self.Castbar = cast;
			self.Castbar.OnUpdate = OnCastbarUpdate;
			self.Castbar.PostCastStart = PostCastStart;
			self.Castbar.PostChannelStart = PostChannelStart;
			self.Castbar.PostCastStop = PostCastStop;
		end
		do -- health bar
			local health = CreateFrame("StatusBar",nil,self);
			health:SetFrameStrata("BACKGROUND"); health:SetFrameLevel(2);
			health:SetWidth(121); health:SetHeight(15);
			health:SetPoint("TOPRIGHT",self.Castbar,"BOTTOMRIGHT",0,-2);
			
			health.value = health:CreateFontString(nil, "OVERLAY", "SUI_FontOutline10");
			health.value:SetWidth(110); health.value:SetHeight(11);
			health.value:SetJustifyH("LEFT"); health.value:SetJustifyV("BOTTOM");
			health.value:SetPoint("RIGHT",health,"RIGHT",-2,0);
			
			health.ratio = health:CreateFontString(nil, "OVERLAY", "SUI_FontOutline10");
			health.ratio:SetWidth(40); health.ratio:SetHeight(11);
			health.ratio:SetJustifyH("LEFT"); health.ratio:SetJustifyV("BOTTOM");
			health.ratio:SetPoint("LEFT",health,"RIGHT",2,0);
			
			self.Health = health;
			self.Health.frequentUpdates = true;
			self.Health.colorDisconnected = true;
			self.Health.colorHealth = true;
			self.Health.PostUpdate = PostUpdateHealth;
		end
		do -- power bar
			local power = CreateFrame("StatusBar",nil,self);
			power:SetFrameStrata("BACKGROUND"); power:SetFrameLevel(2);
			power:SetWidth(136); power:SetHeight(14);
			power:SetPoint("TOPRIGHT",self.Health,"BOTTOMRIGHT",0,-2);
			
			power.value = power:CreateFontString(nil, "OVERLAY", "SUI_FontOutline10");
			power.value:SetWidth(110); power.value:SetHeight(11);
			power.value:SetJustifyH("LEFT"); power.value:SetJustifyV("BOTTOM");
			power.value:SetPoint("RIGHT",power,"RIGHT",-2,0);
			
			power.ratio = power:CreateFontString(nil, "OVERLAY", "SUI_FontOutline10");
			power.ratio:SetWidth(40); power.ratio:SetHeight(11);
			power.ratio:SetJustifyH("LEFT"); power.ratio:SetJustifyV("BOTTOM");
			power.ratio:SetPoint("LEFT",power,"RIGHT",2,0);
			
			self.Power = power;
			self.Power.colorPower = true;
			self.Power.frequentUpdates = true;
			self.Power.PostUpdate = PostUpdatePower;
		end
	end
	do -- setup text and icons	
		local ring = CreateFrame("Frame",nil,self);
		ring:SetFrameStrata("BACKGROUND");
		ring:SetAllPoints(self.Portrait); ring:SetFrameLevel(3);
		ring.bg = ring:CreateTexture(nil,"BACKGROUND");
		ring.bg:SetPoint("CENTER",ring,"CENTER",-2,-2);
		ring.bg:SetTexture(base_ring);
		
		self.Name = ring:CreateFontString(nil, "BORDER","SUI_FontOutline11");
		self.Name:SetWidth(150); self.Name:SetHeight(12);
		self.Name:SetJustifyH("LEFT"); self.Name:SetJustifyV("BOTTOM");
		self.Name:SetPoint("TOPRIGHT",self,"TOPRIGHT",-20,-8);
		self:Tag(self.Name, "[name]");
		
		self.Level = ring:CreateFontString(nil,"BORDER","SUI_FontOutline10");
		self.Level:SetWidth(40); self.Level:SetHeight(12);
		self.Level:SetJustifyH("CENTER"); self.Level:SetJustifyV("BOTTOM");
		self.Level:SetPoint("CENTER",self.Portrait,"CENTER",-27,27);
		self:Tag(self.Level, "[level]");
		
		self.SUI_ClassIcon = ring:CreateTexture(nil,"BORDER");
		self.SUI_ClassIcon:SetWidth(20); self.SUI_ClassIcon:SetHeight(20);
		self.SUI_ClassIcon:SetPoint("CENTER",self.Portrait,"CENTER",23,24);
		
		self.Leader = ring:CreateTexture(nil,"BORDER");
		self.Leader:SetWidth(20); self.Leader:SetHeight(20);
		self.Leader:SetPoint("CENTER",self.Portrait,"TOP",-1,6);
		
		self.MasterLooter = ring:CreateTexture(nil,"BORDER");
		self.MasterLooter:SetWidth(18); self.MasterLooter:SetHeight(18);
		self.MasterLooter:SetPoint("CENTER",self.Portrait,"LEFT",-10,0);
		
		self.PvP = ring:CreateTexture(nil,"BORDER");
		self.PvP:SetWidth(50); self.PvP:SetHeight(50);
		self.PvP:SetPoint("CENTER",self.Portrait,"BOTTOMLEFT",5,-10);
		
		self.LFDRole = ring:CreateTexture(nil,"BORDER");
		self.LFDRole:SetWidth(28); self.LFDRole:SetHeight(28);
		self.LFDRole:SetPoint("CENTER",ring,"BOTTOM",-3,-10);
		self.LFDRole:SetTexture[[Interface\AddOns\SpartanUI_PlayerFrames\media\icon_role]];
		
		self.RaidIcon = ring:CreateTexture(nil,"ARTWORK");
		self.RaidIcon:SetWidth(24); self.RaidIcon:SetHeight(24);
		self.RaidIcon:SetPoint("CENTER",self.Portrait,"CENTER");
		
		self.StatusText = ring:CreateFontString(nil, "OVERLAY", "SUI_FontOutline18");
		self.StatusText:SetPoint("CENTER",self.Portrait,"CENTER");
		self.StatusText:SetJustifyH("CENTER");
		self:Tag(self.StatusText, '[afkdnd]');
	end
	do -- setup buffs and debuffs
		self.Auras = CreateFrame("Frame",nil,self);
		self.Auras:SetWidth(17*11); self.Auras:SetHeight(17*1);
		self.Auras:SetPoint("TOPRIGHT",self,"BOTTOMRIGHT",-6,2);
		self.Auras:SetFrameStrata("BACKGROUND");
		self.Auras:SetFrameLevel(4);
		-- settings
		self.Auras.size = 16;
		self.Auras.spacing = 1;
		self.Auras.initialAnchor = "TOPLEFT";
		self.Auras.gap = true; -- adds an empty spacer between buffs and debuffs
		self.Auras.numBuffs = 7;
		self.Auras.numDebuffs = 4;
		
--		self.Auras.PreUpdate = PreUpdateAura;
		self.Auras.PostUpdate = PostUpdateAura;
	end
	return self;
end

local CreatePetFrame = function(self,unit)
	self:SetWidth(173); self:SetHeight(75);
	do -- setup base artwork
		local artwork = CreateFrame("Frame",nil,self);
		artwork:SetFrameStrata("BACKGROUND");
		artwork:SetFrameLevel(0); artwork:SetAllPoints(self);
		
		artwork.bg = artwork:CreateTexture(nil,"BACKGROUND");
		artwork.bg:SetWidth(179); artwork.bg:SetHeight(128);
		artwork.bg:SetTexture(base_plate); artwork.bg:SetTexCoord(0.30078125,1,0,1);
		artwork.bg:SetPoint("LEFT",artwork,"LEFT",-2,-15);
		
		self.Portrait = artwork:CreateTexture(nil,"BORDER");
		self.Portrait:SetWidth(55); self.Portrait:SetHeight(55);
		self.Portrait:SetPoint("CENTER",self,"LEFT",0,0);
	end
	do -- setup status bars
		do -- cast bar
			local cast = CreateFrame("StatusBar",nil,self);
			cast:SetFrameStrata("BACKGROUND"); cast:SetFrameLevel(2);
			cast:SetWidth(90); cast:SetHeight(15);
			cast:SetPoint("TOPRIGHT",self,"TOPRIGHT",-55,-24);
			
			cast.Text = cast:CreateFontString(nil, "OVERLAY", "SUI_FontOutline10");
			cast.Text:SetWidth(75); cast.Text:SetHeight(11);
			cast.Text:SetJustifyH("LEFT"); cast.Text:SetJustifyV("BOTTOM");
			cast.Text:SetPoint("RIGHT",cast,"RIGHT",-2,0);
			
			cast.Time = cast:CreateFontString(nil, "OVERLAY", "SUI_FontOutline10");
			cast.Time:SetWidth(40); cast.Time:SetHeight(11);
			cast.Time:SetJustifyH("LEFT"); cast.Time:SetJustifyV("BOTTOM");
			cast.Time:SetPoint("LEFT",cast,"RIGHT",2,0);
			
			self.Castbar = cast;
			self.Castbar.OnUpdate = OnCastbarUpdate;
			self.Castbar.PostCastStart = PostCastStart;
			self.Castbar.PostChannelStart = PostChannelStart;
			self.Castbar.PostCastStop = PostCastStop;
		end
		do -- health bar
			local health = CreateFrame("StatusBar",nil,self);
			health:SetFrameStrata("BACKGROUND"); health:SetFrameLevel(2);
			health:SetWidth(90); health:SetHeight(16);
			health:SetPoint("TOPRIGHT",self.Castbar,"BOTTOMRIGHT",0,-1);
			
			health.value = health:CreateFontString(nil, "OVERLAY", "SUI_FontOutline10");
			health.value:SetWidth(75); health.value:SetHeight(11);
			health.value:SetJustifyH("LEFT"); health.value:SetJustifyV("BOTTOM");
			health.value:SetPoint("RIGHT",health,"RIGHT",-2,0);
			
			health.ratio = health:CreateFontString(nil, "OVERLAY", "SUI_FontOutline10");
			health.ratio:SetWidth(40); health.ratio:SetHeight(11);
			health.ratio:SetJustifyH("LEFT"); health.ratio:SetJustifyV("BOTTOM");
			health.ratio:SetPoint("LEFT",health,"RIGHT",2,0);
			
			self.Health = health;
			self.Health.frequentUpdates = true;
			self.Health.colorDisconnected = true;
			self.Health.colorHealth = true;
			self.Health.PostUpdate = PostUpdateHealth;
		end
		do -- power bar
			local power = CreateFrame("StatusBar",nil,self);
			power:SetFrameStrata("BACKGROUND"); power:SetFrameLevel(2);
			power:SetWidth(100); power:SetHeight(14);
			power:SetPoint("TOPRIGHT",self.Health,"BOTTOMRIGHT",0,-2);
			
			power.value = power:CreateFontString(nil, "OVERLAY", "SUI_FontOutline10");
			power.value:SetWidth(75); power.value:SetHeight(11);
			power.value:SetJustifyH("LEFT"); power.value:SetJustifyV("BOTTOM");
			power.value:SetPoint("RIGHT",power,"RIGHT",-2,0);
			
			power.ratio = power:CreateFontString(nil, "OVERLAY", "SUI_FontOutline10");
			power.ratio:SetWidth(40); power.ratio:SetHeight(11);
			power.ratio:SetJustifyH("LEFT"); power.ratio:SetJustifyV("BOTTOM");
			power.ratio:SetPoint("LEFT",power,"RIGHT",2,0);
			
			self.Power = power;
			self.Power.colorPower = true;
			self.Power.frequentUpdates = true;
			self.Power.PostUpdate = PostUpdatePower;
		end
	end
	do -- setup text and icons
		local ring = CreateFrame("Frame",nil,self);
		ring:SetFrameStrata("BACKGROUND");
		ring:SetAllPoints(self.Portrait); ring:SetFrameLevel(3);
		ring.bg = ring:CreateTexture(nil,"BACKGROUND");
		ring.bg:SetPoint("CENTER",ring,"CENTER",-2,-2);
		ring.bg:SetTexture(base_ring);
		
		self.Name = ring:CreateFontString(nil, "BORDER","SUI_FontOutline11");
		self.Name:SetWidth(115); self.Name:SetHeight(12);
		self.Name:SetJustifyH("LEFT"); self.Name:SetJustifyV("BOTTOM");
		self.Name:SetPoint("TOPRIGHT",self,"TOPRIGHT",-20,-5);
		self:Tag(self.Name, "[name]");
		
		self.Level = ring:CreateFontString(nil,"BORDER","SUI_FontOutline10");
		self.Level:SetWidth(40); self.Level:SetHeight(12);
		self.Level:SetJustifyH("CENTER"); self.Level:SetJustifyV("BOTTOM");
		self.Level:SetPoint("CENTER",self.Portrait,"CENTER",-27,27);
		self:Tag(self.Level, "[level]");
		
		self.SUI_ClassIcon = ring:CreateTexture(nil,"BORDER");
		self.SUI_ClassIcon:SetWidth(20); self.SUI_ClassIcon:SetHeight(20);
		self.SUI_ClassIcon:SetPoint("CENTER",self.Portrait,"CENTER",23,24);
		
		self.PvP = ring:CreateTexture(nil,"BORDER");
		self.PvP:SetWidth(50); self.PvP:SetHeight(50);
		self.PvP:SetPoint("CENTER",self.Portrait,"BOTTOMLEFT",5,-10);
		
		self.RaidIcon = ring:CreateTexture(nil,"ARTWORK");
		self.RaidIcon:SetWidth(24); self.RaidIcon:SetHeight(24);
		self.RaidIcon:SetPoint("CENTER",self.Portrait,"BOTTOM",-2,-10);
	end
	do -- setup buffs and debuffs
		self.Auras = CreateFrame("Frame",nil,self);
		self.Auras:SetWidth(17*9); self.Auras:SetHeight(17*1);
		self.Auras:SetPoint("TOPRIGHT",self,"BOTTOMRIGHT",-6,-2);
		self.Auras:SetFrameStrata("BACKGROUND");
		self.Auras:SetFrameLevel(4);
		-- settings
		self.Auras.size = 16;
		self.Auras.spacing = 1;
		self.Auras.initialAnchor = "TOPLEFT";
		self.Auras.gap = true; -- adds an empty spacer between buffs and debuffs
		self.Auras.numBuffs = 6;
		self.Auras.numDebuffs = 3;
		
--		self.Auras.PreUpdate = PreUpdateAura;
		self.Auras.PostUpdate = PostUpdateAura;
	end
	self:SetScale(0.8);
	self:RegisterEvent("UNIT_PET",petinfo);
	return self;
end

local CreateUnitFrame = function(self,unit)
	self.menu = menu;
	self:SetScript("OnEnter", UnitFrame_OnEnter)
	self:SetScript("OnLeave", UnitFrame_OnLeave)
	self:RegisterForClicks("AnyDown");
--	self:SetAttribute("*type1", "target")
--	self:SetAttribute("*type2", "menu")
	self.colors = colors;
	self:SetClampedToScreen(true)
	return (self:GetAttribute("unitsuffix") == "pet" and CreatePetFrame(self,unit)) or (CreatePartyFrame(self,unit));
end

oUF:RegisterStyle("Spartan_PartyFrames", CreateUnitFrame);
