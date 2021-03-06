local F, C, L = unpack(select(2, ...))


local module = F:RegisterModule("cooldown")

function module:OnLogin()
	if not C.misc.cooldown then return end

	local FONT = { "Interface\\AddOns\\FreeUI\\assets\\font\\supereffective.ttf", 16, "OUTLINEMONOCHROME" }
	local MIN_DURATION = 2.5                    -- the minimum duration to show cooldown text for
	local MIN_SCALE = 0.5                       -- the minimum scale we want to show cooldown counts at, anything below this will be hidden
	local ICON_SIZE = 36
	local hideNumbers = {}

	-- stops the timer
	local function Timer_Stop(self)
		self.enabled = nil
		self:Hide()
	end

	-- forces the given timer to update on the next frame
	local function Timer_ForceUpdate(self)
		self.nextUpdate = 0
		self:Show()
	end

	-- adjust font size whenever the timer's parent size changes, hide if it gets too tiny
	local function Timer_OnSizeChanged(self, width)
		local fontScale = floor(width + 0.5) / ICON_SIZE
		if fontScale == self.fontScale then return end
		self.fontScale = fontScale

		if fontScale < MIN_SCALE then
			self:Hide()
		else
			self.text:SetFont(unpack(FONT))
			self.text:SetShadowColor(0, 0, 0, 0)
			--F.SetFS(self.text)
			self.text:SetPoint("BOTTOM", 2, 2)

			if self.enabled then
				Timer_ForceUpdate(self)
			end
		end
	end

	-- update timer text, if it needs to be, hide the timer if done
	local function Timer_OnUpdate(self, elapsed)
		if self.nextUpdate > 0 then
			self.nextUpdate = self.nextUpdate - elapsed
		else
			local remain = self.duration - (GetTime() - self.start)
			if remain > 0 then
				local time, nextUpdate = F.FormatTime(remain)
				self.text:SetText(time)
				self.nextUpdate = nextUpdate
			else
				Timer_Stop(self)
			end
		end
	end

	-- returns a new timer object
	local function Timer_Create(self)
		local scaler = CreateFrame("Frame", nil, self)
		scaler:SetAllPoints(self)

		local timer = CreateFrame("Frame", nil, scaler)
		timer:Hide()
		timer:SetAllPoints(scaler)
		timer:SetScript("OnUpdate", Timer_OnUpdate)

		local text = timer:CreateFontString(nil, "BACKGROUND")
		text:SetPoint("CENTER", 2, 0)
		text:SetJustifyH("CENTER")
		timer.text = text

		Timer_OnSizeChanged(timer, scaler:GetSize())
		scaler:SetScript("OnSizeChanged", function(_, ...) 
			Timer_OnSizeChanged(timer, ...) 
		end)

		self.timer = timer
		return timer
	end

	local function Timer_Start(self, start, duration)
		if self:IsForbidden() or self.noOCC or hideNumbers[self] then return end

		if start > 0 and duration > MIN_DURATION then
			local timer = self.timer or Timer_Create(self)
			timer.start = start
			timer.duration = duration
			timer.enabled = true
			timer.nextUpdate = 0

			-- wait for blizz to fix itself
			local parent = self:GetParent()
			local charge = parent and parent.chargeCooldown
			local chargeTimer = charge and charge.timer
			if chargeTimer and chargeTimer ~= timer then
				Timer_Stop(chargeTimer)
			end

			if timer.fontScale >= MIN_SCALE then 
				timer:Show()
			end
		elseif self.timer then
			Timer_Stop(self.timer)
		end
	end

	local function hideCooldownNumbers(self, hide)
		if hide then
			hideNumbers[self] = true
			if self.timer then Timer_Stop(self.timer) end
		else
			hideNumbers[self] = nil
		end
	end

	local cooldownIndex = getmetatable(ActionButton1Cooldown).__index
	hooksecurefunc(cooldownIndex, "SetCooldown", Timer_Start)
	--hooksecurefunc(cooldownIndex, "SetHideCountdownNumbers", hideCooldownNumbers)
	hooksecurefunc("CooldownFrame_SetDisplayAsPercentage", function(self)
		hideCooldownNumbers(self, true)
	end)

	-- action buttons hook
	local active, hooked = {}, {}

	local function Cooldown_OnShow(self)
		active[self] = true
	end

	local function Cooldown_OnHide(self)
		active[self] = nil
	end

	local function Cooldown_ShouldUpdateTimer(self, start)
		local timer = self.timer
		if not timer then
			return true
		end
		return timer.start ~= start
	end

	local function Cooldown_Update(self)
		local button = self:GetParent()
		local start, duration = GetActionCooldown(button.action)

		if Cooldown_ShouldUpdateTimer(self, start) then
			Timer_Start(self, start, duration)
		end
	end

	F:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN", function()
		for cooldown in pairs(active) do
			Cooldown_Update(cooldown)
		end
	end)

	local function ActionButton_Register(frame)
		local cooldown = frame.cooldown
		if not hooked[cooldown] then
			cooldown:HookScript("OnShow", Cooldown_OnShow)
			cooldown:HookScript("OnHide", Cooldown_OnHide)
			hooked[cooldown] = true
		end
	end

	if _G["ActionBarButtonEventsFrame"].frames then
		for _, frame in pairs(_G["ActionBarButtonEventsFrame"].frames) do
			ActionButton_Register(frame)
		end
	end
	hooksecurefunc("ActionBarButtonEventsFrame_RegisterFrame", ActionButton_Register)

	-- Hide Default Cooldown
	SetCVar("countdownForCooldowns", 0)
	F.HideOption(InterfaceOptionsActionBarsPanelCountdownCooldowns)
end
