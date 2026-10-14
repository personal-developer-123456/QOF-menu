--[[
	AERO QoL MENU  (Frutiger Aero style)
	Put in: StarterPlayer > StarterPlayerScripts  (LocalScript)
	Optional (for saving settings): add AeroQoLMenu_Server.lua as a Script in ServerScriptService.

	Tabs: Profile, Controls, Players, Chat, HUD, Style
	Open with the glowing orb (draggable) or press M on PC.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

if playerGui:FindFirstChild("AeroQoLMenu") then
	playerGui.AeroQoLMenu:Destroy()
end

local WIN_W, WIN_H = 480, 330
local WHITE = Color3.new(1, 1, 1)
local usesTCS = TextChatService.ChatVersion == Enum.ChatVersion.TextChatService

------------------------------------------------------------------------
-- THEMES
------------------------------------------------------------------------
local THEMES = {
	["Aero Sky"] = { m1 = Color3.fromRGB(135, 212, 255), m2 = Color3.fromRGB(35, 135, 225), a1 = Color3.fromRGB(140, 240, 120), a2 = Color3.fromRGB(35, 170, 70) },
	["Aqua"] = { m1 = Color3.fromRGB(120, 245, 235), m2 = Color3.fromRGB(15, 145, 185), a1 = Color3.fromRGB(150, 225, 255), a2 = Color3.fromRGB(30, 120, 220) },
	["Meadow"] = { m1 = Color3.fromRGB(180, 240, 140), m2 = Color3.fromRGB(30, 150, 110), a1 = Color3.fromRGB(130, 205, 255), a2 = Color3.fromRGB(40, 110, 220) },
	["Sunset"] = { m1 = Color3.fromRGB(255, 205, 130), m2 = Color3.fromRGB(235, 105, 120), a1 = Color3.fromRGB(255, 235, 130), a2 = Color3.fromRGB(240, 150, 40) },
	["Lavender"] = { m1 = Color3.fromRGB(210, 185, 255), m2 = Color3.fromRGB(100, 90, 215), a1 = Color3.fromRGB(255, 185, 235), a2 = Color3.fromRGB(210, 80, 170) },
}
local THEME_ORDER = { "Aero Sky", "Aqua", "Meadow", "Sunset", "Lavender" }

------------------------------------------------------------------------
-- SETTINGS
------------------------------------------------------------------------
local S = {
	-- style
	opacity = 0.75, scale = 1, orbSize = 56, theme = "Aero Sky", bubbles = true, orbFade = true,
	-- controls
	jumpCustom = false, jumpSize = 90, jumpX = 35, jumpY = 35, jumpAlpha = 0.5,
	autoJump = player.AutoJumpEnabled,
	fov = camera and camera.FieldOfView or 70,
	maxZoom = math.clamp(player.CameraMaxZoomDistance, 10, 128),
	-- chat
	chatWindow = true, chatInput = true, chatBubbles = true,
	chatAlpha = 0.5, chatText = 16, chatW = 0.4, chatH = 0.25,
	-- hud
	backpack = true, playerList = true, health = true, emotes = true,
	showFps = false, showPing = false, shadows = Lighting.GlobalShadows, antiAfk = false,
	-- players
	sortStats = true,
}

if usesTCS then
	pcall(function()
		local w = TextChatService:FindFirstChild("ChatWindowConfiguration")
		if w then
			S.chatWindow = w.Enabled
			S.chatAlpha = w.BackgroundTransparency
			S.chatText = w.TextSize
			if w.Size.X.Scale > 0 then S.chatW = w.Size.X.Scale end
			if w.Size.Y.Scale > 0 then S.chatH = w.Size.Y.Scale end
		end
		local i = TextChatService:FindFirstChild("ChatInputBarConfiguration")
		if i then S.chatInput = i.Enabled end
		local b = TextChatService:FindFirstChild("BubbleChatConfiguration")
		if b then S.chatBubbles = b.Enabled end
	end)
end

local DEFAULTS = table.clone(S)
local touched = {} -- only settings the user changed get applied (we don't override your game's own stuff)
local ALWAYS = { opacity = true, scale = true, orbSize = true, theme = true, bubbles = true, showFps = true, showPing = true }

local applyers = {}
local refreshers = {}

------------------------------------------------------------------------
-- HELPERS
------------------------------------------------------------------------
local function new(class, props, parent)
	local inst = Instance.new(class)
	for k, v in pairs(props) do inst[k] = v end
	inst.Parent = parent
	return inst
end

local function corner(p, r)
	return new("UICorner", { CornerRadius = r and UDim.new(0, r) or UDim.new(1, 0) }, p)
end

local function stroke(p, color, th, tr)
	return new("UIStroke", {
		Color = color or WHITE, Thickness = th or 1.5, Transparency = tr or 0.4,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, p)
end

local function tween(obj, t, props, style)
	TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

local function notify(title, text)
	pcall(function()
		StarterGui:SetCore("SendNotification", { Title = title, Text = text, Duration = 3 })
	end)
end

local function nextOrder(p)
	local n = (p:GetAttribute("n") or 0) + 1
	p:SetAttribute("n", n)
	return n
end

-- theme gradient registry
local gradients = {}
local function reg(g, role)
	table.insert(gradients, { g, role })
	return g
end
local function applyTheme()
	local t = THEMES[S.theme] or THEMES["Aero Sky"]
	local alive = {}
	for _, e in ipairs(gradients) do
		local g, role = e[1], e[2]
		if g.Parent then
			table.insert(alive, e)
			if role == "main" then
				g.Color = ColorSequence.new(t.m1, t.m2)
			else
				g.Color = ColorSequence.new(t.a1, t.a2)
			end
		end
	end
	gradients = alive
end

local function gloss(parent, radius)
	local g = new("Frame", {
		Name = "Gloss", BackgroundColor3 = WHITE, BorderSizePixel = 0,
		Size = UDim2.new(1, -8, 0.5, -3), Position = UDim2.fromOffset(4, 2), ZIndex = 2,
	}, parent)
	corner(g, radius)
	new("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0.92) }),
	}, g)
	return g
end

local function label(parent, text, size, font, xalign)
	return new("TextLabel", {
		BackgroundTransparency = 1, Text = text, TextSize = size or 14, Font = font or Enum.Font.GothamMedium,
		TextColor3 = WHITE, TextStrokeColor3 = Color3.fromRGB(10, 50, 100), TextStrokeTransparency = 0.75,
		TextXAlignment = xalign or Enum.TextXAlignment.Left, Size = UDim2.fromScale(1, 1), ZIndex = 3,
	}, parent)
end

------------------------------------------------------------------------
-- SAVE SYSTEM (works with the optional server script)
------------------------------------------------------------------------
local remote, remoteState = nil, "loading" -- loading | cloud | local
local slots = {}
local saveQueued = false

local function snapshot()
	local v, t = {}, {}
	for k, val in pairs(S) do v[k] = val end
	for k in pairs(touched) do t[k] = true end
	return { v = v, t = t }
end

local function pushSave()
	if not remote or remoteState ~= "cloud" then return end
	pcall(function() remote:InvokeServer("save", { cur = snapshot(), slots = slots }) end)
end

local function queueSave()
	if saveQueued or remoteState ~= "cloud" then return end
	saveQueued = true
	task.delay(2.5, function()
		saveQueued = false
		pushSave()
	end)
end

local function setSetting(key, value)
	S[key] = value
	touched[key] = true
	local f = applyers[key]
	if f then pcall(f, value) end
	queueSave()
end

local function applyAll()
	for k, fn in pairs(applyers) do
		if touched[k] or ALWAYS[k] then pcall(fn, S[k]) end
	end
end

local function refreshAll()
	for _, f in ipairs(refreshers) do pcall(f) end
end

local function resetAll()
	local was = touched
	touched = {}
	for k, v in pairs(DEFAULTS) do S[k] = v end
	for k, fn in pairs(applyers) do
		if was[k] or ALWAYS[k] then pcall(fn, S[k]) end
	end
end

local function applySnapshot(snap)
	resetAll()
	if type(snap.v) == "table" then
		for k, v in pairs(snap.v) do
			if DEFAULTS[k] ~= nil and type(v) == type(DEFAULTS[k]) then S[k] = v end
		end
	end
	if type(snap.t) == "table" then
		for k in pairs(snap.t) do
			if DEFAULTS[k] ~= nil then touched[k] = true end
		end
	end
	applyAll()
	refreshAll()
end

------------------------------------------------------------------------
-- ROOT UI
------------------------------------------------------------------------
local gui = new("ScreenGui", {
	Name = "AeroQoLMenu", ResetOnSpawn = false, IgnoreGuiInset = true,
	DisplayOrder = 50, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)

local window = new("Frame", {
	Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(WIN_W, WIN_H), BackgroundColor3 = WHITE, BackgroundTransparency = 0.25,
	Visible = false, Active = true, ClipsDescendants = true,
}, gui)
corner(window, 22)
stroke(window, WHITE, 2, 0.2)
reg(new("UIGradient", { Rotation = 90 }, window), "main")
local uiScale = new("UIScale", {}, window)
local animVal = Instance.new("NumberValue")
animVal.Value = 0.85

-- floating bubbles
local bubbleLayer = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 1 }, window)
do
	local rng = Random.new(7)
	for _ = 1, 9 do
		local d = rng:NextInteger(18, 84)
		local b = new("Frame", {
			Size = UDim2.fromOffset(d, d),
			Position = UDim2.fromScale(rng:NextNumber(0.02, 0.95), rng:NextNumber(0.1, 0.9)),
			BackgroundColor3 = WHITE, BackgroundTransparency = 0.8, ZIndex = 1,
		}, bubbleLayer)
		corner(b)
		stroke(b, WHITE, 1.5, 0.5)
		new("UIGradient", {
			Rotation = 60,
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0.9) }),
		}, b)
		TweenService:Create(b, TweenInfo.new(rng:NextNumber(4, 8), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Position = b.Position - UDim2.fromScale(0, rng:NextNumber(0.05, 0.18)) }):Play()
	end
end

local windowGloss = gloss(window, 22)
windowGloss.Size = UDim2.new(1, -10, 0.38, 0)
windowGloss.Position = UDim2.fromOffset(5, 4)
windowGloss.ZIndex = 2

-- title bar
local titleBar = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), ZIndex = 4 }, window)
local titleLbl = label(titleBar, "✦  Aero Menu", 17, Enum.Font.GothamBold)
titleLbl.Position = UDim2.fromOffset(16, 0)
titleLbl.Size = UDim2.new(1, -70, 1, 0)
titleLbl.ZIndex = 5

-- content layout
local tabList = new("ScrollingFrame", {
	BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(8, 46),
	Size = UDim2.fromOffset(100, WIN_H - 54), ScrollBarThickness = 0, CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 3,
}, window)
new("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, tabList)

local content = new("Frame", {
	BackgroundColor3 = WHITE, BackgroundTransparency = 0.88, Position = UDim2.fromOffset(116, 46),
	Size = UDim2.fromOffset(WIN_W - 124, WIN_H - 54), ClipsDescendants = true, ZIndex = 3,
}, window)
corner(content, 14)
stroke(content, WHITE, 1.2, 0.6)
new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 6), PaddingBottom = UDim.new(0, 4), PaddingRight = UDim.new(0, 2) }, content)

-- floating orb
local orb = new("CanvasGroup", {
	Name = "Orb", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.96, 0.38),
	Size = UDim2.fromOffset(S.orbSize, S.orbSize), BackgroundTransparency = 1, Active = true,
}, gui)
corner(orb)
local orbBody = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE }, orb)
corner(orbBody)
reg(new("UIGradient", { Rotation = 90 }, orbBody), "main")
stroke(orbBody, WHITE, 2.5, 0.1)
gloss(orbBody)
local orbIcon = label(orbBody, "✦", 26, Enum.Font.GothamBold, Enum.TextXAlignment.Center)

-- FPS / ping overlay
local statsHud = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.fromOffset(170, 24),
	BackgroundColor3 = Color3.fromRGB(20, 80, 140), BackgroundTransparency = 0.45, Visible = false,
}, gui)
corner(statsHud)
stroke(statsHud, WHITE, 1.2, 0.4)
local statsLabel = label(statsHud, "", 13, Enum.Font.GothamBold, Enum.TextXAlignment.Center)

------------------------------------------------------------------------
-- WIDGET BUILDERS
------------------------------------------------------------------------
local function rowFrame(page, h)
	local r = new("Frame", {
		Size = UDim2.new(1, 0, 0, h), BackgroundColor3 = WHITE, BackgroundTransparency = 0.82,
		LayoutOrder = nextOrder(page), ZIndex = 3,
	}, page)
	corner(r, 12)
	stroke(r, WHITE, 1, 0.65)
	return r
end

local function section(page, text)
	local l = new("TextLabel", {
		BackgroundTransparency = 1, Text = string.upper(text), Font = Enum.Font.GothamBold, TextSize = 11,
		TextColor3 = Color3.fromRGB(235, 250, 255), TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 18), LayoutOrder = nextOrder(page), ZIndex = 3,
	}, page)
	new("UIPadding", { PaddingLeft = UDim.new(0, 4) }, l)
end

local function info(page, text)
	local l = new("TextLabel", {
		BackgroundTransparency = 1, Text = text, Font = Enum.Font.Gotham, TextSize = 12,
		TextColor3 = Color3.fromRGB(235, 250, 255), TextStrokeColor3 = Color3.fromRGB(10, 50, 100), TextStrokeTransparency = 0.8,
		TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = nextOrder(page), ZIndex = 3,
	}, page)
	new("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }, l)
	return l
end

local function button(parent, text, callback, kind, size)
	local b = new("TextButton", {
		Text = "", AutoButtonColor = false, BackgroundColor3 = WHITE,
		Size = size or UDim2.new(1, 0, 0, 34), LayoutOrder = nextOrder(parent), ZIndex = 3,
	}, parent)
	corner(b)
	stroke(b, WHITE, 1.5, 0.2)
	if kind == "danger" then
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 150, 140), Color3.fromRGB(205, 55, 65)) }, b)
	else
		reg(new("UIGradient", { Rotation = 90 }, b), kind == "btn" and "main" or "accent")
	end
	gloss(b)
	local l = label(b, text, 13, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
	local sc = new("UIScale", {}, b)
	b.MouseButton1Down:Connect(function() sc.Scale = 0.95 end)
	b.MouseButton1Up:Connect(function() sc.Scale = 1 end)
	b.MouseLeave:Connect(function() sc.Scale = 1 end)
	b.Activated:Connect(function() if callback then callback() end end)
	return b, l
end

local function confirmButton(page, text, kind, action)
	local armed = false
	local lbl
	local b
	b, lbl = button(page, text, function()
		if armed then
			armed = false
			lbl.Text = text
			action()
		else
			armed = true
			lbl.Text = "Tap again to confirm"
			task.delay(3, function()
				if armed then armed = false; lbl.Text = text end
			end)
		end
	end, kind)
	return b
end

local function toggle(page, text, key)
	local row = rowFrame(page, 40)
	local lbl = label(row, text, 13)
	lbl.Position = UDim2.fromOffset(10, 0)
	lbl.Size = UDim2.new(1, -70, 1, 0)
	lbl.TextWrapped = true
	local track = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(46, 24),
		BackgroundColor3 = WHITE, ZIndex = 3,
	}, row)
	corner(track)
	stroke(track, WHITE, 1, 0.4)
	local grad = reg(new("UIGradient", { Rotation = 90 }, track), "accent")
	local knob = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(20, 20), Position = UDim2.new(0, 12, 0.5, 0),
		BackgroundColor3 = WHITE, ZIndex = 4,
	}, track)
	corner(knob)
	stroke(knob, Color3.fromRGB(60, 100, 150), 1, 0.6)
	local hit = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 6 }, row)
	local function refresh(animate)
		local on = S[key]
		grad.Enabled = on
		track.BackgroundColor3 = on and WHITE or Color3.fromRGB(95, 125, 155)
		track.BackgroundTransparency = on and 0 or 0.35
		local target = UDim2.new(0, on and 34 or 12, 0.5, 0)
		if animate then tween(knob, 0.15, { Position = target }) else knob.Position = target end
	end
	hit.Activated:Connect(function()
		setSetting(key, not S[key])
		refresh(true)
	end)
	table.insert(refreshers, function() refresh(false) end)
	refresh(false)
	return row
end

local function slider(page, text, key, min, max, step, fmt)
	local row = rowFrame(page, 54)
	local lbl = label(row, text, 13)
	lbl.Position = UDim2.fromOffset(10, 2)
	lbl.Size = UDim2.new(1, -90, 0, 22)
	local val = label(row, "", 13, Enum.Font.GothamBold, Enum.TextXAlignment.Right)
	val.Position = UDim2.new(1, -90, 0, 2)
	val.Size = UDim2.new(0, 80, 0, 22)
	local hit = new("TextButton", {
		Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
		Size = UDim2.new(1, -16, 0, 28), Position = UDim2.fromOffset(8, 24), ZIndex = 5,
	}, row)
	local track = new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Size = UDim2.new(1, -20, 0, 10),
		BackgroundColor3 = Color3.fromRGB(20, 70, 120), BackgroundTransparency = 0.55, ZIndex = 3,
	}, hit)
	corner(track)
	stroke(track, WHITE, 1, 0.6)
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = WHITE, ZIndex = 4 }, track)
	corner(fill)
	reg(new("UIGradient", { Rotation = 90 }, fill), "accent")
	local knob = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(22, 22), Position = UDim2.fromScale(0, 0.5),
		BackgroundColor3 = WHITE, ZIndex = 6,
	}, track)
	corner(knob)
	stroke(knob, Color3.fromRGB(40, 110, 180), 2, 0.3)

	local function show(v)
		local f = math.clamp((v - min) / (max - min), 0, 1)
		fill.Size = UDim2.fromScale(f, 1)
		knob.Position = UDim2.fromScale(f, 0.5)
		val.Text = fmt and fmt(v) or tostring(v)
	end
	local function fromX(x)
		local f = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		local v = min + f * (max - min)
		v = math.clamp(math.floor(v / step + 0.5) * step, min, max)
		v = tonumber(string.format("%.4f", v))
		if v ~= S[key] then setSetting(key, v) end
		show(v)
	end

	local dragging, dragInput = false, nil
	hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging, dragInput = true, input
			page.ScrollingEnabled = false -- stop the list scrolling while sliding
			fromX(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input == dragInput or input.UserInputType == Enum.UserInputType.MouseMovement) then
			fromX(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if dragging and (input == dragInput or (input.UserInputType == Enum.UserInputType.MouseButton1 and dragInput.UserInputType == Enum.UserInputType.MouseButton1)) then
			dragging = false
			page.ScrollingEnabled = true
		end
	end)

	table.insert(refreshers, function() show(S[key]) end)
	show(S[key])
	return row
end

local function wrapRow(page)
	local f = new("Frame", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = nextOrder(page), ZIndex = 3,
	}, page)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, Wraps = true, Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, f)
	return f
end

local function makeDraggable(handle, target, onTap, lo, hi)
	local dragging, moved, dragInput, startPt, startCenter = false, false, nil, nil, nil
	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging, moved, dragInput = true, false, input
			startPt = input.Position
			startCenter = target.AbsolutePosition + target.AbsoluteSize * target.AnchorPoint
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if not dragging then return end
		if input == dragInput or input.UserInputType == Enum.UserInputType.MouseMovement then
			local d = Vector2.new(input.Position.X - startPt.X, input.Position.Y - startPt.Y)
			if not moved and d.Magnitude < 8 then return end
			moved = true
			local vp = gui.AbsoluteSize
			local c = startCenter + d
			target.Position = UDim2.fromScale(math.clamp(c.X / vp.X, lo, hi), math.clamp(c.Y / vp.Y, lo, hi))
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if dragging and (input == dragInput or (input.UserInputType == Enum.UserInputType.MouseButton1 and dragInput.UserInputType == Enum.UserInputType.MouseButton1)) then
			dragging = false
			if not moved and onTap then onTap() end
		end
	end)
end

------------------------------------------------------------------------
-- WINDOW OPEN / CLOSE / SCALE
------------------------------------------------------------------------
local isOpen = false
local lastWake = os.clock()
local current = "Profile"
local refreshPlayers, refreshProfile -- forward declared

local function autoScale()
	local vp = gui.AbsoluteSize
	if vp.X <= 0 then return 1 end
	return math.clamp(math.min(vp.X * 0.94 / WIN_W, vp.Y * 0.9 / WIN_H), 0.4, 1.3)
end
local function updateScale()
	uiScale.Scale = autoScale() * S.scale * animVal.Value
end
animVal.Changed:Connect(updateScale)
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateScale)

local function setOpen(open)
	isOpen = open
	lastWake = os.clock()
	if open then
		window.Visible = true
		tween(animVal, 0.25, { Value = 1 }, Enum.EasingStyle.Back)
		if refreshPlayers then refreshPlayers() end
		if refreshProfile then refreshProfile() end
	else
		local tw = TweenService:Create(animVal, TweenInfo.new(0.15), { Value = 0.85 })
		tw:Play()
		tw.Completed:Once(function()
			if not isOpen then window.Visible = false end
		end)
	end
end

-- close button
do
	local close = new("TextButton", {
		Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(28, 28), BackgroundColor3 = WHITE, ZIndex = 6,
	}, titleBar)
	corner(close)
	stroke(close, WHITE, 1.5, 0.2)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 150, 140), Color3.fromRGB(205, 55, 65)) }, close)
	gloss(close)
	local x = label(close, "✕", 13, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
	x.ZIndex = 7
	close.Activated:Connect(function() setOpen(false) end)
end

makeDraggable(titleBar, window, nil, 0.1, 0.9)
makeDraggable(orb, orb, function()
	lastWake = os.clock()
	setOpen(not isOpen)
end, 0.04, 0.96)

UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.M then setOpen(not isOpen) end
end)

------------------------------------------------------------------------
-- APPLIERS
------------------------------------------------------------------------
local function setCore(t, v)
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, t, v)
end
local function tcs(name, prop, v)
	local c = TextChatService:FindFirstChild(name)
	if c then pcall(function() c[prop] = v end) end
end

-- style
applyers.opacity = function(v) window.BackgroundTransparency = 1 - v end
applyers.scale = function() updateScale() end
applyers.orbSize = function(v)
	orb.Size = UDim2.fromOffset(v, v)
	orbIcon.TextSize = math.floor(v * 0.48)
end
applyers.theme = function() applyTheme() end
applyers.bubbles = function(v) bubbleLayer.Visible = v end

-- controls
local jumpBtn, jumpOrig
local function findJump()
	local tg = playerGui:FindFirstChild("TouchGui")
	local f = tg and tg:FindFirstChild("TouchControlFrame")
	return f and f:FindFirstChild("JumpButton")
end
local applyJump
local function hookJump(b)
	for _, prop in ipairs({ "Size", "Position", "AnchorPoint" }) do
		b:GetPropertyChangedSignal(prop):Connect(function()
			if S.jumpCustom then applyJump() end -- Roblox re-lays out on rotate/resize; we put it back
		end)
	end
end
function applyJump()
	local b = jumpBtn
	if not b or not b.Parent then
		b = findJump()
		jumpBtn = b
		if b then hookJump(b) end
	end
	if not b then return end
	if not jumpOrig then
		jumpOrig = { Size = b.Size, Position = b.Position, AnchorPoint = b.AnchorPoint, Alpha = b.ImageTransparency }
	end
	local size, pos, anchor, alpha
	if S.jumpCustom then
		size = UDim2.fromOffset(S.jumpSize, S.jumpSize)
		pos = UDim2.new(1, -S.jumpX, 1, -S.jumpY)
		anchor = Vector2.new(1, 1)
		alpha = S.jumpAlpha
	else
		size, pos, anchor, alpha = jumpOrig.Size, jumpOrig.Position, jumpOrig.AnchorPoint, jumpOrig.Alpha
	end
	if b.AnchorPoint ~= anchor then b.AnchorPoint = anchor end
	if b.Size ~= size then b.Size = size end
	if b.Position ~= pos then b.Position = pos end
	if b.ImageTransparency ~= alpha then b.ImageTransparency = alpha end
end
for _, k in ipairs({ "jumpCustom", "jumpSize", "jumpX", "jumpY", "jumpAlpha" }) do
	applyers[k] = function() applyJump() end
end
applyers.autoJump = function(v) player.AutoJumpEnabled = v end
applyers.fov = function(v)
	local c = workspace.CurrentCamera
	if c then c.FieldOfView = v end
end
applyers.maxZoom = function(v) player.CameraMaxZoomDistance = v end

-- chat
applyers.chatWindow = function(v)
	if usesTCS then tcs("ChatWindowConfiguration", "Enabled", v) else setCore(Enum.CoreGuiType.Chat, v) end
end
applyers.chatInput = function(v) if usesTCS then tcs("ChatInputBarConfiguration", "Enabled", v) end end
applyers.chatBubbles = function(v) if usesTCS then tcs("BubbleChatConfiguration", "Enabled", v) end end
applyers.chatAlpha = function(v) if usesTCS then tcs("ChatWindowConfiguration", "BackgroundTransparency", v) end end
applyers.chatText = function(v) if usesTCS then tcs("ChatWindowConfiguration", "TextSize", math.floor(v)) end end
local function chatSize()
	if usesTCS then tcs("ChatWindowConfiguration", "Size", UDim2.fromScale(S.chatW, S.chatH)) end
end
applyers.chatW = chatSize
applyers.chatH = chatSize

-- hud
applyers.backpack = function(v) setCore(Enum.CoreGuiType.Backpack, v) end
applyers.playerList = function(v) setCore(Enum.CoreGuiType.PlayerList, v) end
applyers.health = function(v) setCore(Enum.CoreGuiType.Health, v) end
applyers.emotes = function(v) setCore(Enum.CoreGuiType.EmotesMenu, v) end
applyers.showFps = function() statsHud.Visible = S.showFps or S.showPing end
applyers.showPing = applyers.showFps
applyers.shadows = function(v) Lighting.GlobalShadows = v end
local afkConn
applyers.antiAfk = function(v)
	if afkConn then afkConn:Disconnect(); afkConn = nil end
	if v then
		local VU = game:GetService("VirtualUser")
		afkConn = player.Idled:Connect(function()
			VU:CaptureController()
			VU:ClickButton2(Vector2.new())
		end)
	end
end

------------------------------------------------------------------------
-- PAGES + TABS
------------------------------------------------------------------------
local pages, tabButtons = {}, {}

local function makePage()
	local p = new("ScrollingFrame", {
		BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ScrollBarThickness = 4,
		ScrollBarImageColor3 = WHITE, ScrollBarImageTransparency = 0.3, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
		Visible = false, ZIndex = 3,
	}, content)
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, p)
	new("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, p)
	return p
end

local function selectTab(name)
	current = name
	for n, p in pairs(pages) do p.Visible = (n == name) end
	for n, t in pairs(tabButtons) do t.set(n == name) end
	if name == "Players" and refreshPlayers then refreshPlayers() end
	if name == "Profile" and refreshProfile then refreshProfile() end
end

local function addTab(name, icon)
	local page = makePage()
	pages[name] = page
	local b = new("TextButton", {
		Text = "", AutoButtonColor = false, Size = UDim2.new(1, -4, 0, 34), BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.7, ZIndex = 3, LayoutOrder = nextOrder(tabList),
	}, tabList)
	corner(b)
	stroke(b, WHITE, 1.2, 0.5)
	local g = reg(new("UIGradient", { Rotation = 90, Enabled = false }, b), "accent")
	gloss(b)
	local l = label(b, icon .. "  " .. name, 13, Enum.Font.GothamBold)
	l.Position = UDim2.fromOffset(10, 0)
	l.Size = UDim2.new(1, -10, 1, 0)
	b.Activated:Connect(function() selectTab(name) end)
	tabButtons[name] = { set = function(on) g.Enabled = on; b.BackgroundTransparency = on and 0 or 0.7 end }
	return page
end

local profilePage = addTab("Profile", "🏠")
local controlsPage = addTab("Controls", "🎮")
local playersPage = addTab("Players", "👥")
local chatPage = addTab("Chat", "💬")
local hudPage = addTab("HUD", "📊")
local stylePage = addTab("Style", "🎨")

local pct = function(v) return math.floor(v * 100 + 0.5) .. "%" end
local px = function(v) return math.floor(v + 0.5) .. " px" end
local num = function(v) return tostring(math.floor(v + 0.5)) end

------------------------------------------------------------------------
-- PROFILE PAGE
------------------------------------------------------------------------
local joinTime = os.time()
local lastFps = 60
local profileInfo, statusLbl, slotLabels

do
	local card = rowFrame(profilePage, 78)
	local av = new("ImageLabel", {
		Size = UDim2.fromOffset(60, 60), Position = UDim2.fromOffset(9, 9), BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.6, ZIndex = 4,
	}, card)
	corner(av)
	stroke(av, WHITE, 2, 0.1)
	task.spawn(function()
		local ok, img = pcall(Players.GetUserThumbnailAsync, Players, player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		if ok and av.Parent then av.Image = img end
	end)
	local n = label(card, player.DisplayName, 17, Enum.Font.GothamBold)
	n.Position = UDim2.fromOffset(78, 10)
	n.Size = UDim2.new(1, -86, 0, 22)
	local sub = label(card, "@" .. player.Name .. "\nAccount age: " .. player.AccountAge .. " days", 12, Enum.Font.Gotham)
	sub.Position = UDim2.fromOffset(78, 34)
	sub.Size = UDim2.new(1, -86, 0, 34)
	sub.TextYAlignment = Enum.TextYAlignment.Top

	section(profilePage, "This session")
	profileInfo = info(profilePage, "")

	section(profilePage, "Saved profiles")
	statusLbl = info(profilePage, "")
	slotLabels = {}
	for i = 1, 3 do
		local row = rowFrame(profilePage, 42)
		local l = label(row, "", 13)
		l.Position = UDim2.fromOffset(10, 0)
		l.Size = UDim2.new(1, -150, 1, 0)
		slotLabels[i] = l
		local load = button(row, "Load", function()
			local snap = slots[tostring(i)]
			if snap then
				applySnapshot(snap)
				queueSave()
				notify("Aero Menu", "Loaded profile " .. i)
			else
				notify("Aero Menu", "Slot " .. i .. " is empty")
			end
		end, "btn", UDim2.fromOffset(60, 28))
		load.AnchorPoint = Vector2.new(1, 0.5)
		load.Position = UDim2.new(1, -8, 0.5, 0)
		local save = button(row, "Save", function()
			slots[tostring(i)] = snapshot()
			pushSave()
			notify("Aero Menu", "Saved profile " .. i)
			refreshAll()
		end, "accent", UDim2.fromOffset(60, 28))
		save.AnchorPoint = Vector2.new(1, 0.5)
		save.Position = UDim2.new(1, -74, 0.5, 0)
	end
	table.insert(refreshers, function()
		for i = 1, 3 do
			slotLabels[i].Text = "Profile " .. i .. "  •  " .. (slots[tostring(i)] and "saved" or "empty")
		end
	end)
	confirmButton(profilePage, "Reset everything to default", "danger", function()
		resetAll()
		refreshAll()
		queueSave()
		notify("Aero Menu", "All settings reset")
	end)
end

local function refreshStatus()
	if remoteState == "cloud" then
		statusLbl.Text = "☁ Your settings auto-save to your account."
	elseif remoteState == "local" then
		statusLbl.Text = "⚠ Saving is off. Add the server script (AeroQoLMenu_Server) to keep settings between sessions."
	else
		statusLbl.Text = "Checking save system..."
	end
end

function refreshProfile()
	local ping = math.floor(player:GetNetworkPing() * 2000)
	local t = os.time() - joinTime
	profileInfo.Text = string.format(
		"👥 %d/%d players   📶 %d ms   🖥 %d FPS\n⏱ In server: %d:%02d:%02d\n🆔 Server %s",
		#Players:GetPlayers(), Players.MaxPlayers, ping, lastFps,
		math.floor(t / 3600), math.floor(t / 60) % 60, t % 60,
		game.JobId ~= "" and string.sub(game.JobId, 1, 8) or "studio"
	)
	refreshStatus()
end

------------------------------------------------------------------------
-- CONTROLS PAGE
------------------------------------------------------------------------
section(controlsPage, "Jump button")
if not UserInputService.TouchEnabled then
	info(controlsPage, "Roblox only shows a jump button on touch devices, so these sliders do nothing on PC.")
end
toggle(controlsPage, "Use custom jump button", "jumpCustom")
slider(controlsPage, "Size", "jumpSize", 50, 160, 5, px)
slider(controlsPage, "Distance from right", "jumpX", 5, 400, 5, px)
slider(controlsPage, "Distance from bottom", "jumpY", 5, 300, 5, px)
slider(controlsPage, "Transparency", "jumpAlpha", 0, 1, 0.05, pct)
button(controlsPage, "Reset jump button", function()
	for _, k in ipairs({ "jumpSize", "jumpX", "jumpY", "jumpAlpha" }) do setSetting(k, DEFAULTS[k]) end
	setSetting("jumpCustom", false)
	refreshAll()
end, "btn")
section(controlsPage, "Movement & camera")
toggle(controlsPage, "Auto-jump over small obstacles", "autoJump")
slider(controlsPage, "Field of view", "fov", 40, 120, 1, num)
slider(controlsPage, "Max zoom-out distance", "maxZoom", 10, 128, 2, num)

------------------------------------------------------------------------
-- PLAYERS PAGE
------------------------------------------------------------------------
local spectating
local stopSpectate
local stopBtn

local function humanoidOf(p)
	local c = p.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end

function stopSpectate()
	spectating = nil
	if stopBtn then stopBtn.Visible = false end
	local h = humanoidOf(player)
	local c = workspace.CurrentCamera
	if h and c then c.CameraSubject = h end
end

local function spectate(p)
	if p == player then stopSpectate() return end
	local h = humanoidOf(p)
	if not h then notify("Spectate", "That player has no character yet.") return end
	spectating = p
	workspace.CurrentCamera.CameraSubject = h
	stopBtn.Visible = true
	notify("Spectating", p.DisplayName)
end

section(playersPage, "Players")
local countLbl = info(playersPage, "")
stopBtn = button(playersPage, "⏹  Stop spectating", stopSpectate, "danger")
stopBtn.Visible = false
toggle(playersPage, "Sort by leaderboard score", "sortStats")
local list = new("Frame", {
	BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
	LayoutOrder = nextOrder(playersPage), ZIndex = 3,
}, playersPage)
new("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, list)
local rows = {}

local function statsOf(p)
	local ls = p:FindFirstChild("leaderstats")
	local parts, first = {}, nil
	if ls then
		for _, v in ipairs(ls:GetChildren()) do
			if v:IsA("ValueBase") then
				table.insert(parts, v.Name .. ": " .. tostring(v.Value))
				if first == nil and type(v.Value) == "number" then first = v.Value end
			end
		end
	end
	return table.concat(parts, "  "), first
end

local function makeRow(p)
	local row = new("Frame", {
		Size = UDim2.new(1, 0, 0, 50), BackgroundColor3 = WHITE, BackgroundTransparency = 0.82, ZIndex = 3,
	}, list)
	corner(row, 12)
	stroke(row, WHITE, 1, 0.65)
	local av = new("ImageLabel", {
		Size = UDim2.fromOffset(38, 38), Position = UDim2.fromOffset(8, 6), BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.6, ZIndex = 4,
	}, row)
	corner(av)
	stroke(av, WHITE, 1.5, 0.2)
	task.spawn(function()
		local ok, img = pcall(Players.GetUserThumbnailAsync, Players, p.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
		if ok and av.Parent then av.Image = img end
	end)
	local name = label(row, p.DisplayName, 14, Enum.Font.GothamBold)
	name.Position = UDim2.fromOffset(54, 6)
	name.Size = UDim2.new(1, -112, 0, 20)
	local sub = label(row, "", 11, Enum.Font.Gotham)
	sub.Position = UDim2.fromOffset(54, 26)
	sub.Size = UDim2.new(1, -112, 0, 18)
	sub.TextTruncate = Enum.TextTruncate.AtEnd
	if p ~= player then
		task.spawn(function()
			local ok, friend = pcall(player.IsFriendsWith, player, p.UserId)
			if ok and friend and name.Parent then name.Text = p.DisplayName .. " ★" end
		end)
		local spec = button(row, "👁", function() spectate(p) end, "btn", UDim2.fromOffset(42, 30))
		spec.AnchorPoint = Vector2.new(1, 0.5)
		spec.Position = UDim2.new(1, -8, 0.5, 0)
	else
		name.Text = p.DisplayName .. " (you)"
	end
	return { row = row, name = name, sub = sub, base = name.Text }
end

function refreshPlayers()
	local all = Players:GetPlayers()
	countLbl.Text = string.format("%d / %d in this server", #all, Players.MaxPlayers)
	for p, r in pairs(rows) do
		if not p.Parent then r.row:Destroy(); rows[p] = nil end
	end
	local entries = {}
	for _, p in ipairs(all) do
		local txt, val = statsOf(p)
		table.insert(entries, { p = p, txt = txt, val = val or -math.huge })
	end
	table.sort(entries, function(a, b)
		if S.sortStats and a.val ~= b.val then return a.val > b.val end
		return string.lower(a.p.DisplayName) < string.lower(b.p.DisplayName)
	end)
	for i, e in ipairs(entries) do
		local r = rows[e.p]
		if not r then r = makeRow(e.p); rows[e.p] = r end
		r.sub.Text = "@" .. e.p.Name .. (e.txt ~= "" and ("  •  " .. e.txt) or "")
		r.row.LayoutOrder = i
		local nm = r.name.Text:gsub("^#%d+ ", "")
		r.name.Text = (S.sortStats and e.val ~= -math.huge) and ("#" .. i .. " " .. nm) or nm
	end
end

Players.PlayerAdded:Connect(function() task.defer(refreshPlayers) end)
Players.PlayerRemoving:Connect(function(p)
	if p == spectating then stopSpectate() end
	task.defer(refreshPlayers)
end)
player.CharacterAdded:Connect(function()
	if spectating then stopSpectate() end
	task.delay(1, applyJump)
end)
table.insert(refreshers, function() if refreshPlayers then refreshPlayers() end end)

------------------------------------------------------------------------
-- CHAT PAGE
------------------------------------------------------------------------
local function sendChat(msg)
	if usesTCS then
		local channels = TextChatService:FindFirstChild("TextChannels")
		local ch = channels and channels:FindFirstChild("RBXGeneral")
		if ch then pcall(function() ch:SendAsync(msg) end) end
	else
		local ev = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
		local say = ev and ev:FindFirstChild("SayMessageRequest")
		if say then say:FireServer(msg, "All") end
	end
end

section(chatPage, "Chat")
if not usesTCS then
	info(chatPage, "This game uses the legacy chat, so only the on/off switch and quick chat work.")
end
toggle(chatPage, "Show chat window", "chatWindow")
toggle(chatPage, "Chat input bar", "chatInput")
toggle(chatPage, "Speech bubbles above heads", "chatBubbles")
slider(chatPage, "Window transparency", "chatAlpha", 0, 1, 0.05, pct)
slider(chatPage, "Text size", "chatText", 10, 24, 1, num)
slider(chatPage, "Window width", "chatW", 0.25, 0.8, 0.05, pct)
slider(chatPage, "Window height", "chatH", 0.15, 0.6, 0.05, pct)
section(chatPage, "Quick chat")
do
	local wrap = wrapRow(chatPage)
	for _, msg in ipairs({ "👋 hi!", "gg", "brb", "thanks!", "help?", "lol", "nice!" }) do
		button(wrap, msg, function() sendChat(msg) end, "btn", UDim2.fromOffset(78, 32))
	end
end

------------------------------------------------------------------------
-- HUD PAGE
------------------------------------------------------------------------
section(hudPage, "Roblox UI")
toggle(hudPage, "Item hotbar", "backpack")
toggle(hudPage, "Leaderboard (player list)", "playerList")
toggle(hudPage, "Health bar", "health")
toggle(hudPage, "Emotes menu", "emotes")
section(hudPage, "Overlays & performance")
toggle(hudPage, "Show FPS", "showFps")
toggle(hudPage, "Show ping", "showPing")
toggle(hudPage, "Shadows (turn off for more FPS)", "shadows")
toggle(hudPage, "Anti-AFK (no 20 min idle kick)", "antiAfk")
section(hudPage, "Session")

local photoBusy = false
button(hudPage, "📸  Photo mode (hide all UI for 6s)", function()
	if photoBusy then return end
	photoBusy = true
	setOpen(false)
	task.wait(0.3)
	local types = { Enum.CoreGuiType.Backpack, Enum.CoreGuiType.PlayerList, Enum.CoreGuiType.Health, Enum.CoreGuiType.EmotesMenu, Enum.CoreGuiType.Chat }
	local saved = {}
	for _, t in ipairs(types) do saved[t] = StarterGui:GetCoreGuiEnabled(t) end
	local chatWas
	if usesTCS then
		local w = TextChatService:FindFirstChild("ChatWindowConfiguration")
		if w then chatWas = w.Enabled; w.Enabled = false end
	end
	gui.Enabled = false
	setCore(Enum.CoreGuiType.All, false)
	task.wait(6)
	setCore(Enum.CoreGuiType.All, true)
	for _, t in ipairs(types) do setCore(t, saved[t]) end
	if usesTCS and chatWas ~= nil then tcs("ChatWindowConfiguration", "Enabled", chatWas) end
	gui.Enabled = true
	photoBusy = false
end, "accent")

confirmButton(hudPage, "Reset character", "btn", function()
	local h = humanoidOf(player)
	if h then h.Health = 0 end
end)
confirmButton(hudPage, "Rejoin game (new server)", "danger", function()
	pcall(function() TeleportService:Teleport(game.PlaceId, player) end)
end)

------------------------------------------------------------------------
-- STYLE PAGE
------------------------------------------------------------------------
section(stylePage, "Menu look")
slider(stylePage, "Menu opacity", "opacity", 0.25, 1, 0.05, pct)
slider(stylePage, "Menu size", "scale", 0.6, 1.3, 0.05, pct)
slider(stylePage, "Menu button size", "orbSize", 36, 90, 2, px)
section(stylePage, "Theme")
do
	local wrap = wrapRow(stylePage)
	local swatches = {}
	for _, name in ipairs(THEME_ORDER) do
		local t = THEMES[name]
		local b = new("TextButton", {
			Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(86, 32), BackgroundColor3 = WHITE,
			LayoutOrder = nextOrder(wrap), ZIndex = 3,
		}, wrap)
		corner(b)
		local st = stroke(b, WHITE, 1.5, 0.3)
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(t.m1, t.m2) }, b)
		gloss(b)
		label(b, name, 12, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
		b.Activated:Connect(function()
			setSetting("theme", name)
			refreshAll()
		end)
		swatches[name] = st
	end
	table.insert(refreshers, function()
		for name, st in pairs(swatches) do
			st.Thickness = (name == S.theme) and 3.5 or 1.5
			st.Transparency = (name == S.theme) and 0 or 0.3
		end
	end)
end
section(stylePage, "Extras")
toggle(stylePage, "Floating bubbles", "bubbles")
toggle(stylePage, "Fade menu button when idle", "orbFade")
button(stylePage, "Reset menu & button position", function()
	window.Position = UDim2.fromScale(0.5, 0.5)
	orb.Position = UDim2.fromScale(0.96, 0.38)
end, "btn")

------------------------------------------------------------------------
-- BACKGROUND LOOPS
------------------------------------------------------------------------
do
	local frames, acc = 0, 0
	RunService.RenderStepped:Connect(function(dt)
		frames += 1
		acc += dt
		if acc >= 0.5 then
			local fps = math.floor(frames / acc + 0.5)
			frames, acc = 0, 0
			lastFps = fps
			if statsHud.Visible then
				local parts = {}
				if S.showFps then table.insert(parts, fps .. " FPS") end
				if S.showPing then table.insert(parts, math.floor(player:GetNetworkPing() * 2000) .. " ms") end
				statsLabel.Text = table.concat(parts, "  •  ")
			end
		end
	end)
end

task.spawn(function()
	local tick = 0
	while gui.Parent do
		task.wait(0.5)
		tick += 1
		-- orb fade
		local desired = (S.orbFade and not isOpen and os.clock() - lastWake > 3) and 0.6 or 0
		if math.abs(orb.GroupTransparency - desired) > 0.01 then
			tween(orb, 0.3, { GroupTransparency = desired })
		end
		-- keep spectate camera attached after respawns
		if spectating then
			local h = humanoidOf(spectating)
			local c = workspace.CurrentCamera
			if h and c and c.CameraSubject ~= h then c.CameraSubject = h end
		end
		if isOpen and tick % 2 == 0 then
			if current == "Players" then refreshPlayers() end
			if current == "Profile" then refreshProfile() end
		end
	end
end)

-- find the mobile jump button (it can appear a moment after join)
task.spawn(function()
	for _ = 1, 60 do
		if jumpBtn and jumpBtn.Parent then break end
		applyJump()
		task.wait(0.5)
	end
end)

-- load saved settings (needs the optional server script)
task.spawn(function()
	remote = ReplicatedStorage:WaitForChild("QoLMenuData", 8)
	if not remote then
		remoteState = "local"
		return
	end
	local ok, data = pcall(function() return remote:InvokeServer("load") end)
	if ok and type(data) == "table" then
		remoteState = "cloud"
		if type(data.slots) == "table" then slots = data.slots end
		if type(data.cur) == "table" then applySnapshot(data.cur) end
		refreshAll()
	else
		remoteState = "local"
	end
	refreshStatus()
end)

------------------------------------------------------------------------
-- START
------------------------------------------------------------------------
applyTheme()
applyAll()
refreshAll()
selectTab("Profile")
updateScale()
refreshStatus()
notify("Aero Menu", "Tap the ✦ button to open the menu!")
