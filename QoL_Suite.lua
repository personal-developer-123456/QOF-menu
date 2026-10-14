--[[
	✦ QoL SUITE ✦  —  Frutiger Aero quality-of-life menu for Roblox
	Put this in a LocalScript (StarterPlayer > StarterPlayerScripts).

	Features: lag indicator • smart friend notifications • low-data mode • accessibility •
	multi-touch gestures • haptics • floating mini-menu • custom button layout + per-game presets •
	quick graphics • performance / saver mode • jump button tuning • leaderboard • speedometer •
	show-all-players • profile export/import codes • full in-menu guide.

	Menu: tap the glass bubble, or press RightShift (changeable).
	Everything is customizable inside the menu (Style tab = look & feel).

	OPTIONAL server script (for a "true" server speed in the speedometer):
		game.Players.PlayerAdded:Connect(function(p)
			game:GetService("RunService").Heartbeat:Connect(function()
				local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
				if r then p:SetAttribute("ServerSpeed", r.AssemblyLinearVelocity.Magnitude) end
			end)
		end)
]]

--==================================================================
-- SERVICES
--==================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Stats = game:GetService("Stats")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local TextChatService = game:GetService("TextChatService")
local HapticService = game:GetService("HapticService")
local MarketplaceService = game:GetService("MarketplaceService")
local Debris = game:GetService("Debris")

local LP = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui")
local white = Color3.new(1, 1, 1)

--==================================================================
-- DEFAULT CONFIG  (everything in here is editable from the menu)
--==================================================================
local DEFAULTS = {
	ui = { theme = "Aqua", accent = { 0, 170, 255 }, glass = 0.25, corner = 14, gloss = true, scale = 1,
		font = "Gotham", reduceMotion = false, menuKey = "RightShift", bubbleSize = 54 },
	mini = { enabled = true, pos = { x = 0.02, y = 0.4 } },
	lag = { enabled = true, alwaysShow = false, pingWarn = 250, fpsWarn = 25, jitterWarn = 120 },
	alerts = { enabled = true, friendsInServer = true, friendsPlaying = true, poll = 30, duration = 10, sound = true },
	data = { enabled = false, noEffects = true, hideDecals = false, lightingFx = true, lowQuality = true },
	access = { colorblind = "None", cbStrength = 0.8, textScale = 1 },
	sub = { enabled = false, size = 22, bg = 0.45, font = "Gotham", style = "Box", seconds = 6, lines = 3, top = false, names = true },
	gest = { enabled = true, zoomRange = true, zoomMin = 0.5, zoomMax = 128, twoTap = "Toggle Menu",
		swipe = true, swipeFingers = 2, up = "/e wave", down = "/e dance", left = "/e laugh", right = "/e cheer" },
	haptic = { enabled = true, strength = 0.7, jump = true, hit = true, purchase = true },
	layout = {
		jump = { scale = 1, x = 0, y = 0, opacity = 1 },
		thumb = { scale = 1, x = 0, y = 0, opacity = 1 },
		quick = {
			{ on = false, text = "👋", cmd = "/e wave", x = 0.85, y = 0.45, size = 56, opacity = 0.85 },
			{ on = false, text = "⚡", cmd = "@gfx", x = 0.85, y = 0.6, size = 56, opacity = 0.85 },
			{ on = false, text = "📷", cmd = "@screenshot", x = 0.85, y = 0.75, size = 56, opacity = 0.85 },
		},
		slot = 1, autoLoad = true, presets = {},
	},
	gfx = { quality = 0, shadows = true, shadowSoft = 0.2, renderDist = 0, texture = 4 },
	perf = { fpsCap = 0, saver = false, auto = false, autoFps = 20, autoSeconds = 8 },
	speedo = { enabled = false, mode = "Client", unit = "studs/s", horizontal = false, pos = { x = 0.42, y = 0.88 } },
	esp = { enabled = false, highlight = true, lines = false, boxes = true, speed = true, names = true,
		maxDist = 500, teamColor = true, color = { 255, 80, 80 }, fill = 0.7 },
	board = { sort = "Stat 1", desc = true },
}

local function deepCopy(t)
	if type(t) ~= "table" then return t end
	local n = {}
	for k, v in pairs(t) do n[k] = deepCopy(v) end
	return n
end

-- merges src into dst IN PLACE, only for keys that exist with the same type (safe for imports)
local function merge(dst, src)
	if type(src) ~= "table" then return end
	for k, v in pairs(src) do
		local d = dst[k]
		if d ~= nil and type(d) == type(v) then
			if type(v) == "table" then
				if k == "presets" then dst[k] = deepCopy(v) else merge(d, v) end
			else
				dst[k] = v
			end
		end
	end
end

local CFG = deepCopy(DEFAULTS)

--==================================================================
-- SAVE / LOAD / EXPORT CODES
--==================================================================
local FILE = "QoLSuite_config.json"
local canFS = typeof(writefile) == "function" and typeof(readfile) == "function" and typeof(isfile) == "function"

if canFS and isfile(FILE) then
	local ok, data = pcall(function() return HttpService:JSONDecode(readfile(FILE)) end)
	if ok then merge(CFG, data) end
end

local saveQueued = false
local function save()
	if not canFS or saveQueued then return end
	saveQueued = true
	task.delay(1, function()
		saveQueued = false
		pcall(writefile, FILE, HttpService:JSONEncode(CFG))
	end)
end

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function b64enc(s)
	return ((s:gsub(".", function(x)
		local r, b = "", x:byte()
		for i = 8, 1, -1 do r = r .. (b % 2 ^ i - b % 2 ^ (i - 1) > 0 and "1" or "0") end
		return r
	end) .. "0000"):gsub("%d%d%d?%d?%d?%d?", function(x)
		if #x < 6 then return "" end
		local c = 0
		for i = 1, 6 do c = c + (x:sub(i, i) == "1" and 2 ^ (6 - i) or 0) end
		return B64:sub(c + 1, c + 1)
	end) .. ({ "", "==", "=" })[#s % 3 + 1])
end
local function b64dec(data)
	data = data:gsub("[^" .. B64 .. "=]", "")
	return (data:gsub(".", function(x)
		if x == "=" then return "" end
		local r, f = "", (B64:find(x, 1, true) - 1)
		for i = 6, 1, -1 do r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and "1" or "0") end
		return r
	end):gsub("%d%d%d?%d?%d?%d?%d?%d?", function(x)
		if #x ~= 8 then return "" end
		local c = 0
		for i = 1, 8 do c = c + (x:sub(i, i) == "1" and 2 ^ (8 - i) or 0) end
		return string.char(c)
	end))
end

local function exportCode()
	return "QOLS1:" .. b64enc(HttpService:JSONEncode(CFG))
end

--==================================================================
-- THEME ENGINE (Frutiger Aero)
--==================================================================
local THEMES = {
	Aqua = { top = Color3.fromRGB(240, 252, 255), bot = Color3.fromRGB(150, 215, 245), text = Color3.fromRGB(15, 55, 90),
		sub = Color3.fromRGB(60, 100, 130), accent = Color3.fromRGB(0, 170, 255), card = white, cardT = 0.45 },
	Meadow = { top = Color3.fromRGB(242, 255, 238), bot = Color3.fromRGB(150, 226, 150), text = Color3.fromRGB(20, 70, 30),
		sub = Color3.fromRGB(60, 110, 60), accent = Color3.fromRGB(50, 200, 90), card = white, cardT = 0.45 },
	Sunset = { top = Color3.fromRGB(255, 247, 232), bot = Color3.fromRGB(255, 190, 150), text = Color3.fromRGB(90, 40, 20),
		sub = Color3.fromRGB(130, 80, 60), accent = Color3.fromRGB(255, 120, 60), card = white, cardT = 0.45 },
	Midnight = { top = Color3.fromRGB(70, 95, 140), bot = Color3.fromRGB(18, 28, 58), text = Color3.fromRGB(235, 245, 255),
		sub = Color3.fromRGB(170, 190, 220), accent = Color3.fromRGB(90, 180, 255), card = white, cardT = 0.88 },
}
local THEME_NAMES = { "Aqua", "Meadow", "Sunset", "Midnight", "Custom" }

local function c3(t) return Color3.fromRGB(t[1], t[2], t[3]) end

local function theme()
	if CFG.ui.theme == "Custom" then
		local a = c3(CFG.ui.accent)
		return { top = white:Lerp(a, 0.1), bot = white:Lerp(a, 0.5), text = Color3.fromRGB(20, 40, 60),
			sub = Color3.fromRGB(70, 90, 110), accent = a, card = white, cardT = 0.45 }
	end
	return THEMES[CFG.ui.theme] or THEMES.Aqua
end

local function getFont(name)
	local ok, f = pcall(function() return Enum.Font[name or CFG.ui.font] end)
	return ok and f or Enum.Font.Gotham
end

local themed = {}
local function reg(fn)
	table.insert(themed, fn)
	pcall(fn)
	return fn
end
local function applyTheme()
	for _, fn in ipairs(themed) do pcall(fn) end
end

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do o[k] = v end
	if parent then o.Parent = parent end
	return o
end

local function tw(o, props, t)
	if CFG.ui.reduceMotion then
		for k, v in pairs(props) do o[k] = v end
	else
		TweenService:Create(o, TweenInfo.new(t or 0.15, Enum.EasingStyle.Quad), props):Play()
	end
end

--==================================================================
-- ROOT GUI
--==================================================================
local old = PlayerGui:FindFirstChild("QoLSuite")
if old then old:Destroy() end
local gui = new("ScreenGui", { Name = "QoLSuite", ResetOnSpawn = false, IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999 }, PlayerGui)

local APPLY = {}
local refreshers = {}
local function refreshAll() for _, f in ipairs(refreshers) do pcall(f) end end
local function changed(sec)
	if sec and APPLY[sec] then pcall(APPLY[sec]) end
	save()
end

--==================================================================
-- AERO UI BUILDING BLOCKS
--==================================================================
local function glass(parent, props)
	local f = new("Frame", props, parent)
	f.BorderSizePixel = 0
	f.BackgroundColor3 = white
	local corner = new("UICorner", {}, f)
	local grad = new("UIGradient", { Rotation = 90 }, f)
	local stroke = new("UIStroke", { Thickness = 1.5, Transparency = 0.3, Color = white }, f)
	local gl = new("Frame", { BackgroundColor3 = white, BorderSizePixel = 0, Position = UDim2.new(0, 4, 0, 3),
		Size = UDim2.new(1, -8, 0.4, 0) }, f)
	new("UICorner", { CornerRadius = UDim.new(0, 12) }, gl)
	new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) }) }, gl)
	reg(function()
		local t = theme()
		grad.Color = ColorSequence.new(t.top, t.bot)
		f.BackgroundTransparency = CFG.ui.glass
		corner.CornerRadius = UDim.new(0, CFG.ui.corner)
		stroke.Color = white
		gl.Visible = CFG.ui.gloss
	end)
	return f
end

local function text(parent, str, size, kind, props)
	local l = new("TextLabel", { BackgroundTransparency = 1, Text = str, TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true, Size = UDim2.new(1, 0, 0, 20) }, parent)
	for k, v in pairs(props or {}) do l[k] = v end
	reg(function()
		local t = theme()
		l.TextColor3 = kind == "sub" and t.sub or (kind == "accent" and t.accent or t.text)
		l.Font = getFont()
		l.TextSize = size * CFG.access.textScale
	end)
	return l
end

local function aeroButton(parent, str, props, ts, tint, round)
	local b = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = white, BorderSizePixel = 0,
		Size = UDim2.fromOffset(100, 30) }, parent)
	for k, v in pairs(props or {}) do b[k] = v end
	local corner = new("UICorner", {}, b)
	local grad = new("UIGradient", { Rotation = 90 }, b)
	local stroke = new("UIStroke", { Color = white, Transparency = 0.25, Thickness = 1.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
	local gl = new("Frame", { BackgroundColor3 = white, BorderSizePixel = 0, Position = UDim2.new(0, 3, 0, 2),
		Size = UDim2.new(1, -6, 0.48, 0), ZIndex = 1 }, b)
	local glc = new("UICorner", {}, gl)
	new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0.85) }) }, gl)
	local lbl = new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = str, ZIndex = 2,
		TextColor3 = white, TextStrokeColor3 = Color3.fromRGB(0, 40, 70), TextStrokeTransparency = 0.7,
		TextWrapped = true }, b)
	reg(function()
		local a = tint or theme().accent
		grad.Color = ColorSequence.new(a:Lerp(white, 0.4), a:Lerp(Color3.new(0, 0, 0), 0.12))
		local r = round and UDim.new(1, 0) or UDim.new(0, math.max(6, CFG.ui.corner - 4))
		corner.CornerRadius = r
		glc.CornerRadius = r
		gl.Visible = CFG.ui.gloss
		lbl.Font = getFont()
		lbl.TextSize = (ts or 14) * CFG.access.textScale
	end)
	b.MouseEnter:Connect(function() tw(stroke, { Transparency = 0 }) end)
	b.MouseLeave:Connect(function() tw(stroke, { Transparency = 0.25 }) end)
	return b, lbl
end

local function makeDraggable(handle, target, onDrop, scaleFn)
	local dragging, startIn, startPos, moved = false, nil, nil, false
	handle.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging, startIn, startPos, moved = true, i.Position, target.Position, false
			i.Changed:Connect(function()
				if i.UserInputState == Enum.UserInputState.End then
					dragging = false
					if onDrop then onDrop(moved) end
				end
			end)
		end
	end)
	UIS.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - startIn
			if d.Magnitude > 6 then moved = true end
			local s = scaleFn and scaleFn() or 1
			target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X / s, startPos.Y.Scale, startPos.Y.Offset + d.Y / s)
		end
	end)
end

local function savePos(target, tbl)
	local vp = gui.AbsoluteSize
	tbl.x = math.clamp(target.AbsolutePosition.X / vp.X, 0, 0.98)
	tbl.y = math.clamp(target.AbsolutePosition.Y / vp.Y, 0, 0.98)
	target.Position = UDim2.fromScale(tbl.x, tbl.y)
	save()
end

--==================================================================
-- TOASTS / NOTIFICATIONS
--==================================================================
local toastHolder = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 56), Size = UDim2.fromOffset(290, 400) }, gui)
new("UIListLayout", { Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Right,
	SortOrder = Enum.SortOrder.LayoutOrder }, toastHolder)

local function notify(title, body, btnText, cb, dur)
	local t = glass(toastHolder, { Size = UDim2.new(1, 0, 0, btnText and 92 or 62) })
	text(t, title, 15, "text", { Size = UDim2.new(1, -36, 0, 20), Position = UDim2.new(0, 12, 0, 6), Font = Enum.Font.GothamBold })
	text(t, body or "", 13, "sub", { Size = UDim2.new(1, -24, 0, 30), Position = UDim2.new(0, 12, 0, 26) })
	local x, xl = aeroButton(t, "✕", { Size = UDim2.fromOffset(22, 22), Position = UDim2.new(1, -28, 0, 6) }, 12,
		Color3.fromRGB(230, 90, 90), true)
	x.Activated:Connect(function() t:Destroy() end)
	if btnText then
		local b = aeroButton(t, btnText, { Size = UDim2.new(1, -24, 0, 26), Position = UDim2.new(0, 12, 1, -32) }, 14)
		b.Activated:Connect(function() t:Destroy() if cb then cb() end end)
	end
	if CFG.alerts.sound then
		pcall(function()
			local s = new("Sound", { SoundId = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.4 }, gui)
			s:Play() Debris:AddItem(s, 2)
		end)
	end
	Debris:AddItem(t, dur or CFG.alerts.duration)
	return t
end

--==================================================================
-- SHARED RUNTIME STATE
--==================================================================
local fps = 60
local function getPing()
	local ok, v = pcall(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
	if ok and v then return v end
	local ok2, p = pcall(function() return LP:GetNetworkPing() * 2000 end)
	return ok2 and p or 0
end
local function myRoot()
	local c = LP.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function sendChat(msg)
	pcall(function()
		local ch = TextChatService:FindFirstChild("TextChannels")
		ch = ch and ch:FindFirstChild("RBXGeneral")
		if ch then ch:SendAsync(msg) end
	end)
end

local toggleMenu
local Gfx, Perf = {}, {}

local function screenshot()
	gui.Enabled = false
	local restored = false
	local function back() if not restored then restored = true gui.Enabled = true end end
	local ok = pcall(function()
		game:GetService("CaptureService"):CaptureScreenshot(function() back() end)
	end)
	task.delay(ok and 2 or 0.2, back)
	if not ok then
		task.delay(0.3, function() notify("Screenshot", "Capture isn't available from scripts here. Use Roblox's built-in capture button.") end)
	end
end

local function rejoin()
	notify("Rejoining…", "Hang tight!")
	task.wait(0.3)
	if #Players:GetPlayers() <= 1 then
		TeleportService:Teleport(game.PlaceId, LP)
	else
		TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP)
	end
end

local ACTIONS = {
	["@menu"] = function() toggleMenu() end,
	["@screenshot"] = screenshot,
	["@rejoin"] = rejoin,
	["@gfx"] = function() Gfx.cycle() end,
}
local function runCommand(c)
	if not c or c == "" then return end
	local a = ACTIONS[c:lower()]
	if a then task.spawn(a) else sendChat(c) end
end

--==================================================================
-- MODULE: GRAPHICS (quick toggle, shadows, render distance, texture)
--==================================================================
local PRESETS = {
	{ name = "Potato", quality = 1, shadows = false, shadowSoft = 0, renderDist = 250, texture = 0 },
	{ name = "Low", quality = 3, shadows = false, shadowSoft = 0.1, renderDist = 500, texture = 1 },
	{ name = "Medium", quality = 5, shadows = true, shadowSoft = 0.3, renderDist = 1000, texture = 2 },
	{ name = "High", quality = 8, shadows = true, shadowSoft = 0.2, renderDist = 0, texture = 3 },
	{ name = "Ultra", quality = 10, shadows = true, shadowSoft = 0.1, renderDist = 0, texture = 4 },
}
local origLighting = { Shadows = Lighting.GlobalShadows, FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart,
	Soft = Lighting.ShadowSoftness }
local autoSaver = false

local function effectiveGfx()
	local g = table.clone(CFG.gfx)
	local clamp = (CFG.data.enabled and CFG.data.lowQuality) or CFG.perf.saver or autoSaver
	if clamp then
		g.quality = math.min(g.quality == 0 and 3 or g.quality, 2)
		g.shadows = false
		g.texture = math.min(g.texture, 1)
		g.renderDist = (g.renderDist == 0 or g.renderDist > 400) and 400 or g.renderDist
	end
	return g
end

function Gfx.apply()
	local g = effectiveGfx()
	pcall(function()
		if g.quality == 0 then
			settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
		else
			settings().Rendering.QualityLevel = Enum.QualityLevel["Level" .. string.format("%02d", math.clamp(g.quality * 2 - 1, 1, 21))]
		end
	end)
	pcall(function() Lighting.GlobalShadows = g.shadows end)
	pcall(function() Lighting.ShadowSoftness = g.shadowSoft end)
	if g.renderDist > 0 then
		Lighting.FogEnd = g.renderDist
		Lighting.FogStart = g.renderDist * 0.55
	else
		Lighting.FogEnd = origLighting.FogEnd
		Lighting.FogStart = origLighting.FogStart
	end
	pcall(function() settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel["Level0" .. g.texture] end)
end

function Gfx.preset(i)
	for k, v in pairs(PRESETS[i]) do
		if k ~= "name" then CFG.gfx[k] = v end
	end
	Gfx.idx = i
	Gfx.apply()
	refreshAll()
	save()
end

function Gfx.cycle()
	local i = (Gfx.idx or 3) % #PRESETS + 1
	Gfx.preset(i)
	notify("Graphics → " .. PRESETS[i].name, "Switched without leaving the game.", nil, nil, 3)
end
APPLY.gfx = Gfx.apply

--==================================================================
-- MODULE: PERFORMANCE (fps cap, saver)
--==================================================================
function Perf.apply()
	local cap = CFG.perf.fpsCap
	if (CFG.perf.saver or autoSaver) and (cap == 0 or cap > 30) then cap = 30 end
	if typeof(setfpscap) == "function" then pcall(setfpscap, cap == 0 and 999 or cap) end
	Gfx.apply()
end
APPLY.perf = Perf.apply

--==================================================================
-- MODULE: LOW-DATA MODE
--==================================================================
local stash = setmetatable({}, { __mode = "k" })
local dataConn
local FX_CLASSES = { "ParticleEmitter", "Trail", "Beam", "Smoke", "Fire", "Sparkles" }
local LIGHT_FX = { "BloomEffect", "SunRaysEffect", "BlurEffect", "DepthOfFieldEffect" }

local function trim(i)
	if CFG.data.noEffects then
		for _, c in ipairs(FX_CLASSES) do
			if i:IsA(c) then
				if not stash[i] then stash[i] = { "Enabled", i.Enabled } end
				i.Enabled = false
				return
			end
		end
	end
	if CFG.data.hideDecals and (i:IsA("Decal") or i:IsA("Texture")) then
		if not stash[i] then stash[i] = { "Transparency", i.Transparency } end
		i.Transparency = 1
	end
end

local function dataApply()
	if dataConn then dataConn:Disconnect() dataConn = nil end
	if CFG.data.enabled then
		task.spawn(function()
			local n = 0
			for _, d in ipairs(workspace:GetDescendants()) do
				pcall(trim, d)
				n += 1
				if n % 400 == 0 then task.wait() end
			end
		end)
		dataConn = workspace.DescendantAdded:Connect(function(d) pcall(trim, d) end)
		if CFG.data.lightingFx then
			for _, c in ipairs(Lighting:GetChildren()) do
				for _, cls in ipairs(LIGHT_FX) do
					if c:IsA(cls) then
						if not stash[c] then stash[c] = { "Enabled", c.Enabled } end
						c.Enabled = false
					end
				end
			end
		end
	else
		for i, v in pairs(stash) do pcall(function() i[v[1]] = v[2] end) end
		table.clear(stash)
	end
	Gfx.apply()
end
APPLY.data = dataApply

--==================================================================
-- MODULE: ACCESSIBILITY (colour filters + subtitles)
--==================================================================
local CB = {
	Protanopia = { tint = Color3.fromRGB(255, 244, 230), sat = 0.12, con = 0.10 },
	Deuteranopia = { tint = Color3.fromRGB(255, 236, 236), sat = 0.14, con = 0.10 },
	Tritanopia = { tint = Color3.fromRGB(232, 244, 255), sat = 0.12, con = 0.10 },
	Monochrome = { tint = white, sat = -1, con = 0.10 },
	["High Contrast"] = { tint = white, sat = 0.25, con = 0.35 },
}
local CB_NAMES = { "None", "Protanopia", "Deuteranopia", "Tritanopia", "Monochrome", "High Contrast" }

APPLY.access = function()
	local fx = Lighting:FindFirstChild("QoL_CB") or new("ColorCorrectionEffect", { Name = "QoL_CB" }, Lighting)
	local p = CB[CFG.access.colorblind]
	if not p then fx.Enabled = false else
		local s = CFG.access.cbStrength
		fx.Enabled = true
		fx.TintColor = white:Lerp(p.tint, s)
		fx.Saturation = p.sat * s
		fx.Contrast = p.con * s
	end
	applyTheme() -- text scale
end

local subFrame = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -90), Size = UDim2.new(0.7, 0, 0, 220) }, gui)
new("UIListLayout", { VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, subFrame)

APPLY.sub = function()
	if CFG.sub.top then
		subFrame.AnchorPoint = Vector2.new(0.5, 0)
		subFrame.Position = UDim2.new(0.5, 0, 0, 70)
		subFrame:FindFirstChildOfClass("UIListLayout").VerticalAlignment = Enum.VerticalAlignment.Top
	else
		subFrame.AnchorPoint = Vector2.new(0.5, 1)
		subFrame.Position = UDim2.new(0.5, 0, 1, -90)
		subFrame:FindFirstChildOfClass("UIListLayout").VerticalAlignment = Enum.VerticalAlignment.Bottom
	end
end

local subOrder = 0
local function addSub(name, msg)
	if not CFG.sub.enabled then return end
	msg = tostring(msg):gsub("<[^>]+>", "")
	local line = (CFG.sub.names and name ~= "" and (name .. ": ") or "") .. msg
	subOrder += 1
	local l = new("TextLabel", { Text = line, BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0,
		BackgroundTransparency = CFG.sub.style == "Box" and CFG.sub.bg or 1, TextColor3 = white, TextWrapped = true,
		Font = getFont(CFG.sub.font), TextSize = CFG.sub.size, AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(0, 0, 0, 0), LayoutOrder = subOrder,
		TextStrokeTransparency = CFG.sub.style == "Outline" and 0 or (CFG.sub.style == "Shadow" and 0.5 or 1) }, subFrame)
	new("UICorner", { CornerRadius = UDim.new(0, 8) }, l)
	new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }, l)
	new("UISizeConstraint", { MaxSize = Vector2.new(720, 220) }, l)
	Debris:AddItem(l, CFG.sub.seconds)
	local kids = {}
	for _, c in ipairs(subFrame:GetChildren()) do if c:IsA("TextLabel") then table.insert(kids, c) end end
	table.sort(kids, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
	while #kids > CFG.sub.lines do table.remove(kids, 1):Destroy() end
end
pcall(function()
	TextChatService.MessageReceived:Connect(function(m)
		addSub(m.TextSource and m.TextSource.Name or "", m.Text)
	end)
end)

--==================================================================
-- MODULE: HAPTICS
--==================================================================
local function pulse(strength, dur)
	if not CFG.haptic.enabled then return end
	local pad = Enum.UserInputType.Gamepad1
	local ok, sup = pcall(function() return HapticService:IsVibrationSupported(pad) end)
	if ok and sup then
		pcall(function()
			HapticService:SetMotor(pad, Enum.VibrationMotor.Large, math.clamp(strength * CFG.haptic.strength, 0, 1))
			task.delay(dur, function() pcall(function() HapticService:SetMotor(pad, Enum.VibrationMotor.Large, 0) end) end)
		end)
	end
end

local function hookCharacter(char)
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum then return end
	local lastHp = hum.Health
	hum.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Jumping and CFG.haptic.jump then pulse(0.35, 0.08) end
	end)
	hum.HealthChanged:Connect(function(hp)
		if hp < lastHp and CFG.haptic.hit then pulse(math.clamp((lastHp - hp) / 30, 0.3, 1), 0.2) end
		lastHp = hp
	end)
end
LP.CharacterAdded:Connect(hookCharacter)
if LP.Character then task.spawn(hookCharacter, LP.Character) end
pcall(function()
	local function bought(ok) if ok and CFG.haptic.purchase then pulse(0.6, 0.25) end end
	MarketplaceService.PromptPurchaseFinished:Connect(function(_, _, ok) bought(ok) end)
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(_, _, ok) bought(ok) end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(_, _, ok) bought(ok) end)
end)

--==================================================================
-- MODULE: GESTURES
--==================================================================
local gestDebounce = 0
APPLY.gest = function()
	if CFG.gest.zoomRange then
		LP.CameraMinZoomDistance = CFG.gest.zoomMin
		LP.CameraMaxZoomDistance = CFG.gest.zoomMax
	end
end

local function twoFingerAction()
	local a = CFG.gest.twoTap
	if a == "Toggle Menu" then toggleMenu()
	elseif a == "Screenshot" then screenshot()
	elseif a == "Quick Graphics" then Gfx.cycle() end
end

local starts, recent = {}, {}
UIS.TouchStarted:Connect(function(input, gpe)
	if gpe then return end
	starts[input] = { t = os.clock(), pos = input.Position }
end)
UIS.TouchEnded:Connect(function(input)
	local s = starts[input]
	starts[input] = nil
	if not s or not CFG.gest.enabled then return end
	local now = os.clock()
	if now - s.t < 0.3 and (input.Position - s.pos).Magnitude < 25 then
		for i = #recent, 1, -1 do
			local r = recent[i]
			if now - r.e < 0.2 and math.abs(s.t - r.s) < 0.2 then
				recent = {}
				twoFingerAction()
				return
			end
		end
		table.insert(recent, { s = s.t, e = now })
		if #recent > 6 then table.remove(recent, 1) end
	end
end)

UIS.TouchSwipe:Connect(function(dir, n, gpe)
	if gpe or not (CFG.gest.enabled and CFG.gest.swipe) or n ~= CFG.gest.swipeFingers then return end
	if os.clock() - gestDebounce < 0.8 then return end
	gestDebounce = os.clock()
	local map = { [Enum.SwipeDirection.Up] = "up", [Enum.SwipeDirection.Down] = "down",
		[Enum.SwipeDirection.Left] = "left", [Enum.SwipeDirection.Right] = "right" }
	local k = map[dir]
	if k then runCommand(CFG.gest[k]) end
end)

--==================================================================
-- MODULE: CONTROL LAYOUT (jump / thumbstick / quick buttons / presets)
--==================================================================
local Layout = {}
local origUI = setmetatable({}, { __mode = "k" })
local editing = false

local function touchParts()
	local tg = PlayerGui:FindFirstChild("TouchGui")
	local frame = tg and tg:FindFirstChild("TouchControlFrame")
	if not frame then return end
	return frame, frame:FindFirstChild("JumpButton"),
		frame:FindFirstChild("DynamicThumbstickFrame") or frame:FindFirstChild("ThumbstickFrame")
end

local function applyTouch(inst, cfg, withOpacity)
	if not inst then return end
	local o = origUI[inst]
	if not o then
		o = { size = inst.Size, pos = inst.Position }
		origUI[inst] = o
	elseif inst.Size ~= o.aSize or inst.Position ~= o.aPos then
		o.size, o.pos = inst.Size, inst.Position -- Roblox reset it; take new base
	end
	local s = cfg.scale
	o.aSize = UDim2.new(o.size.X.Scale * s, o.size.X.Offset * s, o.size.Y.Scale * s, o.size.Y.Offset * s)
	o.aPos = UDim2.new(o.pos.X.Scale, o.pos.X.Offset + cfg.x, o.pos.Y.Scale, o.pos.Y.Offset + cfg.y)
	inst.Size, inst.Position = o.aSize, o.aPos
	if withOpacity then
		if inst:IsA("GuiButton") or inst:IsA("ImageLabel") then inst.ImageTransparency = 1 - cfg.opacity end
		for _, d in ipairs(inst:GetDescendants()) do
			if d:IsA("ImageLabel") or d:IsA("ImageButton") then d.ImageTransparency = 1 - cfg.opacity end
		end
	end
end

function Layout.applyTouch()
	local _, jump, thumb = touchParts()
	applyTouch(jump, CFG.layout.jump, true)
	applyTouch(thumb, CFG.layout.thumb, thumb and thumb.Name == "ThumbstickFrame")
end

local quickBtns = {}
local editDrag
for i = 1, 3 do
	local b, lbl = aeroButton(gui, "", { AnchorPoint = Vector2.new(0.5, 0.5), Visible = false }, 24, nil, true)
	quickBtns[i] = { b = b, lbl = lbl }
	b.Activated:Connect(function()
		if not editing then runCommand(CFG.layout.quick[i].cmd) end
	end)
	b.InputBegan:Connect(function(inp)
		if editing and (inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch) then
			editDrag = { kind = "quick", i = i }
			inp.Changed:Connect(function() if inp.UserInputState == Enum.UserInputState.End then editDrag = nil save() end end)
		end
	end)
end

function Layout.refreshQuick()
	local vp = gui.AbsoluteSize
	for i, q in ipairs(CFG.layout.quick) do
		local qb = quickBtns[i]
		qb.b.Visible = q.on
		qb.b.Size = UDim2.fromOffset(q.size, q.size)
		qb.b.Position = UDim2.new(0, q.x * vp.X, 0, q.y * vp.Y)
		qb.b.BackgroundTransparency = 1 - q.opacity
		qb.lbl.Text = q.text
		qb.lbl.TextTransparency = 1 - q.opacity
	end
end

APPLY.layout = function()
	Layout.applyTouch()
	Layout.refreshQuick()
end

-- edit mode with on-screen ghosts
local ghosts, doneBtn = {}, nil
local function makeGhost(target, cfg, label)
	local g = new("Frame", { BackgroundColor3 = Color3.fromRGB(0, 200, 255), BackgroundTransparency = 0.55,
		AnchorPoint = target.AnchorPoint, ZIndex = 50, Active = true, BorderSizePixel = 0,
		Size = target.Size, Position = target.Position }, target.Parent)
	new("UICorner", { CornerRadius = UDim.new(0.2, 0) }, g)
	new("UIStroke", { Color = white, Thickness = 2 }, g)
	new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = label, TextColor3 = white,
		Font = Enum.Font.GothamBold, TextScaled = true, ZIndex = 51 }, g)
	local h = new("TextButton", { Text = "⇲", Size = UDim2.fromOffset(26, 26), AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1), BackgroundColor3 = white, ZIndex = 52, TextColor3 = Color3.fromRGB(0, 90, 140),
		Font = Enum.Font.GothamBold, TextSize = 16 }, g)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, h)
	local function start(kind, inp)
		editDrag = { kind = kind, cfg = cfg, startIn = inp.Position, x = cfg.x, y = cfg.y, scale = cfg.scale,
			w = math.max(target.AbsoluteSize.X, 20) }
		inp.Changed:Connect(function() if inp.UserInputState == Enum.UserInputState.End then editDrag = nil save() refreshAll() end end)
	end
	local function isPress(inp) return inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch end
	g.InputBegan:Connect(function(inp) if isPress(inp) then start("move", inp) end end)
	h.InputBegan:Connect(function(inp) if isPress(inp) then start("size", inp) end end)
	local c = RunService.RenderStepped:Connect(function()
		g.Size, g.Position = target.Size, target.Position
	end)
	table.insert(ghosts, { g = g, c = c })
end

UIS.InputChanged:Connect(function(inp)
	if not editDrag then return end
	if inp.UserInputType ~= Enum.UserInputType.MouseMovement and inp.UserInputType ~= Enum.UserInputType.Touch then return end
	if editDrag.kind == "quick" then
		local vp = gui.AbsoluteSize
		local q = CFG.layout.quick[editDrag.i]
		q.x = math.clamp(inp.Position.X / vp.X, 0, 1)
		q.y = math.clamp(inp.Position.Y / vp.Y, 0, 1)
		Layout.refreshQuick()
	else
		local d = inp.Position - editDrag.startIn
		if editDrag.kind == "move" then
			editDrag.cfg.x = math.floor(editDrag.x + d.X)
			editDrag.cfg.y = math.floor(editDrag.y + d.Y)
		else
			editDrag.cfg.scale = math.clamp(editDrag.scale * (editDrag.w + d.X) / editDrag.w, 0.4, 3)
		end
		Layout.applyTouch()
	end
end)

function Layout.setEdit(on)
	editing = on
	for _, g in ipairs(ghosts) do g.c:Disconnect() g.g:Destroy() end
	ghosts = {}
	if doneBtn then doneBtn:Destroy() doneBtn = nil end
	if on then
		local _, jump, thumb = touchParts()
		if jump then makeGhost(jump, CFG.layout.jump, "JUMP") end
		if thumb then makeGhost(thumb, CFG.layout.thumb, "MOVE") end
		doneBtn = aeroButton(gui, "✔ Done editing", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -20),
			Size = UDim2.fromOffset(170, 36), ZIndex = 100 }, 15, Color3.fromRGB(60, 190, 90))
		doneBtn.Activated:Connect(function() Layout.setEdit(false) end)
		for _, qb in ipairs(quickBtns) do qb.b.Visible = true end
		notify("Edit mode", "Drag controls to move them. Drag the ⇲ corner to resize. Quick buttons can be dragged too.", nil, nil, 6)
	end
	Layout.refreshQuick()
	if toggleMenu then toggleMenu(not on) end
end

local function pid() return tostring(game.PlaceId) end
function Layout.savePreset()
	local L = CFG.layout
	L.presets[pid()] = L.presets[pid()] or {}
	L.presets[pid()][tostring(L.slot)] = deepCopy({ jump = L.jump, thumb = L.thumb, quick = L.quick })
	save()
	notify("Layout saved", "Slot " .. L.slot .. " for this game.", nil, nil, 3)
end
function Layout.loadPreset(silent)
	local L = CFG.layout
	local p = L.presets[pid()] and L.presets[pid()][tostring(L.slot)]
	if not p then
		if not silent then notify("No preset", "Nothing saved in slot " .. L.slot .. " for this game.", nil, nil, 3) end
		return
	end
	merge(L.jump, p.jump) merge(L.thumb, p.thumb) merge(L.quick, p.quick)
	APPLY.layout() refreshAll()
	if not silent then notify("Layout loaded", "Slot " .. L.slot, nil, nil, 3) end
end
function Layout.deletePreset()
	local L = CFG.layout
	if L.presets[pid()] then L.presets[pid()][tostring(L.slot)] = nil end
	save()
	notify("Preset deleted", "Slot " .. L.slot, nil, nil, 3)
end
function Layout.reset()
	merge(CFG.layout.jump, DEFAULTS.layout.jump)
	merge(CFG.layout.thumb, DEFAULTS.layout.thumb)
	merge(CFG.layout.quick, DEFAULTS.layout.quick)
	APPLY.layout() refreshAll() save()
end

task.spawn(function()
	while true do
		task.wait(0.5)
		if not editing then pcall(Layout.applyTouch) end
	end
end)

--==================================================================
-- HUD: LAG INDICATOR
--==================================================================
local lagPill = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), AutomaticSize = Enum.AutomaticSize.X,
	Size = UDim2.fromOffset(0, 30), BorderSizePixel = 0, Visible = false }, gui)
new("UICorner", { CornerRadius = UDim.new(1, 0) }, lagPill)
new("UIStroke", { Color = white, Transparency = 0.2, Thickness = 1.5 }, lagPill)
new("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }, lagPill)
local lagGrad = new("UIGradient", { Rotation = 90 }, lagPill)
local lagLbl = new("TextLabel", { BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 30),
	TextColor3 = white, Font = Enum.Font.GothamBold, TextSize = 14, TextStrokeTransparency = 0.7 }, lagPill)

local function lagColor(c)
	lagGrad.Color = ColorSequence.new(c:Lerp(white, 0.35), c:Lerp(Color3.new(0, 0, 0), 0.15))
end

local pingHist = {}
task.spawn(function()
	while true do
		task.wait(0.5)
		local ping = getPing()
		table.insert(pingHist, ping)
		if #pingHist > 12 then table.remove(pingHist, 1) end
		local mn, mx = math.huge, 0
		for _, p in ipairs(pingHist) do mn = math.min(mn, p) mx = math.max(mx, p) end
		local jitter = mx - mn
		local L = CFG.lag
		local bad, msg
		local devBad, netBad = fps < L.fpsWarn, ping > L.pingWarn
		if devBad and netBad then
			bad, msg = true, ("⚠ Device AND connection are struggling  (%d FPS • %d ms)"):format(fps, ping)
		elseif netBad then
			bad, msg = true, ("⚠ Your connection is the problem  (%d ms ping)"):format(ping)
		elseif devBad then
			bad, msg = true, ("⚠ Your device is lagging, not the server  (%d FPS)"):format(fps)
		elseif jitter > L.jitterWarn and #pingHist >= 6 then
			bad, msg = true, ("⚠ Unstable connection  (±%d ms jitter)"):format(jitter)
		end
		if L.enabled and bad then
			lagLbl.Text = msg lagColor(Color3.fromRGB(235, 90, 60)) lagPill.Visible = true
		elseif L.enabled and L.alwaysShow then
			lagLbl.Text = ("● %d ms • %d FPS"):format(ping, fps) lagColor(Color3.fromRGB(50, 190, 90)) lagPill.Visible = true
		else
			lagPill.Visible = false
		end
	end
end)

--==================================================================
-- HUD: SPEEDOMETER
--==================================================================
local speedFrame = new("Frame", { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 36), BorderSizePixel = 0,
	Visible = false, Active = true }, gui)
new("UICorner", { CornerRadius = UDim.new(1, 0) }, speedFrame)
new("UIStroke", { Color = white, Transparency = 0.2, Thickness = 1.5 }, speedFrame)
new("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }, speedFrame)
local speedGrad = new("UIGradient", { Rotation = 90 }, speedFrame)
local speedLbl = new("TextLabel", { BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 36),
	TextColor3 = white, Font = Enum.Font.GothamBold, TextSize = 17, TextStrokeTransparency = 0.7 }, speedFrame)
reg(function()
	local a = theme().accent
	speedGrad.Color = ColorSequence.new(a:Lerp(white, 0.35), a:Lerp(Color3.new(0, 0, 0), 0.2))
end)
makeDraggable(speedFrame, speedFrame, function() savePos(speedFrame, CFG.speedo.pos) end)

local UNIT = { ["studs/s"] = 1, ["km/h"] = 1.008, ["mph"] = 0.626 }
local cSpeed, lastP = 0, nil
RunService.Heartbeat:Connect(function(dt)
	fps = fps + (1 / math.max(dt, 0.001) - fps) * 0.05
	local r = myRoot()
	if r then
		local p = r.Position
		if lastP then
			local d = p - lastP
			if CFG.speedo.horizontal then d = Vector3.new(d.X, 0, d.Z) end
			cSpeed = cSpeed + (d.Magnitude / dt - cSpeed) * 0.3
		end
		lastP = p
	else
		lastP = nil
	end
end)

local speedAcc = 0
RunService.Heartbeat:Connect(function(dt)
	speedAcc += dt
	if speedAcc < 0.1 then return end
	speedAcc = 0
	if not CFG.speedo.enabled then speedFrame.Visible = false return end
	speedFrame.Visible = true
	local S, v, tag = CFG.speedo, 0, ""
	if S.mode == "Server" then
		local attr = LP:GetAttribute("ServerSpeed")
		local r = myRoot()
		if attr then v, tag = attr, "server"
		elseif r then
			local vel = r.AssemblyLinearVelocity
			if S.horizontal then vel = Vector3.new(vel.X, 0, vel.Z) end
			v, tag = vel.Magnitude, "replicated"
		end
	else
		v, tag = cSpeed, "client"
	end
	speedLbl.Text = ("%.1f %s  •  %s"):format(v * UNIT[S.unit], S.unit, tag)
end)

--==================================================================
-- HUD: SHOW ALL PLAYERS (highlight / lines / boxes / speed)
--==================================================================
local espLayer = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 0 }, gui)
local espObjs, espPrev = {}, {}

local function espGet(p)
	local o = espObjs[p]
	if o then return o end
	o = {}
	o.box = new("Frame", { BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false }, espLayer)
	o.boxStroke = new("UIStroke", { Thickness = 1.6 }, o.box)
	o.line = new("Frame", { BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Visible = false }, espLayer)
	o.label = new("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 13, TextStrokeTransparency = 0.4,
		AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(160, 34), Visible = false, TextYAlignment = Enum.TextYAlignment.Bottom }, espLayer)
	o.hl = new("Highlight", { Enabled = false, OutlineColor = white }, gui)
	espObjs[p] = o
	return o
end
local function espHide(o)
	o.box.Visible, o.line.Visible, o.label.Visible, o.hl.Enabled = false, false, false, false
end
Players.PlayerRemoving:Connect(function(p)
	local o = espObjs[p]
	if o then o.box:Destroy() o.line:Destroy() o.label:Destroy() o.hl:Destroy() espObjs[p] = nil end
	espPrev[p] = nil
end)

local CORNERS = {}
for _, x in ipairs({ -1, 1 }) do for _, y in ipairs({ -1, 1 }) do for _, z in ipairs({ -1, 1 }) do
	table.insert(CORNERS, Vector3.new(x, y, z))
end end end

local otherSpeed = {}
RunService.RenderStepped:Connect(function(dt)
	local E = CFG.esp
	local cam = workspace.CurrentCamera
	if not cam then return end
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LP then
			local o = espGet(p)
			local ch = p.Character
			local root = ch and ch:FindFirstChild("HumanoidRootPart")
			-- speed tracking (cheap, always on while esp is enabled)
			if root then
				local prev = espPrev[p]
				if prev then otherSpeed[p] = (otherSpeed[p] or 0) + (((root.Position - prev).Magnitude / math.max(dt, 0.001)) - (otherSpeed[p] or 0)) * 0.2 end
				espPrev[p] = root.Position
			end
			if not E.enabled or not root then
				espHide(o)
			else
				local dist = (root.Position - cam.CFrame.Position).Magnitude
				local col = (E.teamColor and p.Team) and p.TeamColor.Color or c3(E.color)
				if dist > E.maxDist then
					espHide(o)
				else
					o.hl.Enabled = E.highlight
					if E.highlight then
						o.hl.Adornee = ch
						o.hl.FillColor = col
						o.hl.FillTransparency = E.fill
					end
					local cf, size = ch:GetBoundingBox()
					local minX, minY, maxX, maxY, visible = math.huge, math.huge, -math.huge, -math.huge, true
					for _, c in ipairs(CORNERS) do
						local sp, on = cam:WorldToViewportPoint((cf * CFrame.new(c * size / 2)).Position)
						if sp.Z <= 0 then visible = false break end
						minX, minY = math.min(minX, sp.X), math.min(minY, sp.Y)
						maxX, maxY = math.max(maxX, sp.X), math.max(maxY, sp.Y)
					end
					if not visible then
						o.box.Visible, o.line.Visible, o.label.Visible = false, false, false
					else
						o.box.Visible = E.boxes
						o.box.Position = UDim2.fromOffset(minX, minY)
						o.box.Size = UDim2.fromOffset(maxX - minX, maxY - minY)
						o.boxStroke.Color = col
						local vp = cam.ViewportSize
						local from, to = Vector2.new(vp.X / 2, vp.Y), Vector2.new((minX + maxX) / 2, maxY)
						local d = to - from
						o.line.Visible = E.lines
						o.line.BackgroundColor3 = col
						o.line.Size = UDim2.fromOffset(d.Magnitude, 2)
						o.line.Position = UDim2.fromOffset((from.X + to.X) / 2, (from.Y + to.Y) / 2)
						o.line.Rotation = math.deg(math.atan2(d.Y, d.X))
						local parts = {}
						if E.names then table.insert(parts, p.DisplayName) end
						if E.speed then table.insert(parts, ("%.0f %s"):format((otherSpeed[p] or 0) * UNIT[CFG.speedo.unit], CFG.speedo.unit)) end
						o.label.Visible = #parts > 0
						o.label.Text = table.concat(parts, "\n")
						o.label.TextColor3 = col
						o.label.Position = UDim2.fromOffset((minX + maxX) / 2, minY - 2)
					end
				end
			end
		end
	end
end)

--==================================================================
-- MODULE: AUTO PERFORMANCE SAVER
--==================================================================
local lowT = 0
RunService.Heartbeat:Connect(function(dt)
	if CFG.perf.auto and not autoSaver and fps < CFG.perf.autoFps then
		lowT += dt
		if lowT > CFG.perf.autoSeconds then
			autoSaver = true
			Perf.apply()
			notify("Performance saver ON", "Your FPS stayed low, so graphics were lowered and FPS capped at 30.", nil, nil, 8)
		end
	else
		lowT = 0
	end
end)

--==================================================================
-- NOTIFICATIONS: FRIENDS
--==================================================================
Players.PlayerAdded:Connect(function(p)
	if not (CFG.alerts.enabled and CFG.alerts.friendsInServer) then return end
	task.spawn(function()
		local ok, isF = pcall(function() return LP:IsFriendsWith(p.UserId) end)
		if ok and isF then notify("👋 " .. p.DisplayName .. " joined", "Your friend is in this server.") end
	end)
end)

task.spawn(function()
	local seen, first = {}, true
	while true do
		if CFG.alerts.enabled and CFG.alerts.friendsPlaying then
			local ok, list = pcall(function() return LP:GetFriendsOnline(200) end)
			if ok and type(list) == "table" then
				local now = {}
				for _, f in ipairs(list) do
					if f.PlaceId and f.GameId then
						now[f.VisitorId] = f.GameId
						if not first and seen[f.VisitorId] ~= f.GameId and f.GameId ~= game.JobId then
							notify("🎮 " .. (f.UserName or "A friend") .. " is playing", f.LastLocation or "Tap to join them", "Join now", function()
								pcall(function() TeleportService:TeleportToPlaceInstance(f.PlaceId, f.GameId, LP) end)
							end)
						end
					end
				end
				seen, first = now, false
			end
		end
		task.wait(math.max(10, CFG.alerts.poll))
	end
end)

--==================================================================
-- MAIN WINDOW
--==================================================================
local win = glass(gui, { Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.72, 0.84), Visible = false, Active = true })
new("UISizeConstraint", { MaxSize = Vector2.new(700, 470), MinSize = Vector2.new(300, 240) }, win)
local winScale = new("UIScale", {}, win)
reg(function() winScale.Scale = CFG.ui.scale end)

local titleBar = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), Active = true }, win)
text(titleBar, "✦ QoL Suite", 20, "text", { Size = UDim2.new(1, -60, 1, 0), Position = UDim2.new(0, 16, 0, 0), Font = Enum.Font.GothamBold })
local closeB = aeroButton(titleBar, "✕", { Size = UDim2.fromOffset(28, 28), Position = UDim2.new(1, -38, 0, 6) }, 14,
	Color3.fromRGB(230, 90, 90), true)
makeDraggable(titleBar, win, nil, function() return CFG.ui.scale end)

local tabBar = new("ScrollingFrame", { BackgroundTransparency = 1, Size = UDim2.new(1, -16, 0, 34), Position = UDim2.new(0, 8, 0, 42),
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.X, ScrollBarThickness = 0,
	ScrollingDirection = Enum.ScrollingDirection.X, BorderSizePixel = 0 }, win)
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Center }, tabBar)
local content = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -12, 1, -86), Position = UDim2.new(0, 6, 0, 80),
	ClipsDescendants = true }, win)

local pages, tabs = {}, {}
local function setPage(name)
	for n, p in pairs(pages) do p.Visible = (n == name) end
	for n, t in pairs(tabs) do tw(t.b, { BackgroundTransparency = n == name and 0 or 0.55 }) end
end
local function newPage(name, icon)
	local sf = new("ScrollingFrame", { Name = name, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4, BorderSizePixel = 0, Visible = false }, content)
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, sf)
	new("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 12) }, sf)
	pages[name] = sf
	local b = aeroButton(tabBar, icon .. " " .. name, { Size = UDim2.fromOffset(#name * 8 + 46, 28), BackgroundTransparency = 0.55 }, 13)
	tabs[name] = { b = b }
	b.Activated:Connect(function() setPage(name) end)
	return sf
end

-- ---------- widgets ----------
local function card(parent, h)
	local f = new("Frame", { Size = UDim2.new(1, 0, 0, h or 40), BorderSizePixel = 0 }, parent)
	local c = new("UICorner", {}, f)
	new("UIStroke", { Color = white, Transparency = 0.5 }, f)
	reg(function()
		local t = theme()
		f.BackgroundColor3, f.BackgroundTransparency = t.card, t.cardT
		c.CornerRadius = UDim.new(0, math.max(6, CFG.ui.corner - 4))
	end)
	return f
end

local function section(page, title)
	local l = text(page, title, 17, "accent", { Size = UDim2.new(1, 0, 0, 28), Font = Enum.Font.GothamBold })
	reg(function() l.Font = Enum.Font.GothamBold end)
	return l
end
local function note(page, str)
	return text(page, str, 12, "sub", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
end

local function toggle(page, label, tbl, key, sec)
	local c = card(page, 40)
	text(c, label, 15, "text", { Size = UDim2.new(1, -74, 1, 0), Position = UDim2.new(0, 12, 0, 0) })
	local pill = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(46, 24), AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0), BorderSizePixel = 0 }, c)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, pill)
	new("UIStroke", { Color = white, Transparency = 0.3 }, pill)
	local knob = new("Frame", { Size = UDim2.fromOffset(18, 18), BackgroundColor3 = white, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 0.5) }, pill)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, knob)
	local function refresh()
		local on = tbl[key]
		tw(knob, { Position = UDim2.new(0, on and 25 or 3, 0.5, 0) }, 0.12)
		pill.BackgroundColor3 = on and theme().accent or Color3.fromRGB(150, 160, 170)
	end
	reg(refresh)
	table.insert(refreshers, refresh)
	pill.Activated:Connect(function() tbl[key] = not tbl[key] refresh() changed(sec) end)
end

local function slider(page, label, tbl, key, mn, mx, step, sec, suffix)
	local c = card(page, 54)
	text(c, label, 14, "text", { Size = UDim2.new(1, -100, 0, 22), Position = UDim2.new(0, 12, 0, 4) })
	local valL = text(c, "", 14, "sub", { Size = UDim2.fromOffset(90, 22), Position = UDim2.new(1, -102, 0, 4), TextXAlignment = Enum.TextXAlignment.Right })
	local track = new("Frame", { Size = UDim2.new(1, -28, 0, 8), Position = UDim2.new(0, 14, 0, 36), BorderSizePixel = 0,
		BackgroundColor3 = Color3.fromRGB(120, 140, 160), BackgroundTransparency = 0.5 }, c)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, track)
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BorderSizePixel = 0, BackgroundColor3 = white }, track)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)
	local knob = new("Frame", { Size = UDim2.fromOffset(20, 20), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5),
		BackgroundColor3 = white, BorderSizePixel = 0 }, track)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, knob)
	local ks = new("UIStroke", { Thickness = 2 }, knob)
	local hit = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 0, 24) }, c)
	local function refresh()
		local v = tbl[key] or mn
		local p = math.clamp((v - mn) / (mx - mn), 0, 1)
		fill.Size, knob.Position = UDim2.fromScale(p, 1), UDim2.fromScale(p, 0.5)
		fill.BackgroundColor3, ks.Color = theme().accent, theme().accent
		valL.Text = tostring(v) .. (suffix or "")
	end
	reg(refresh)
	table.insert(refreshers, refresh)
	local dragging = false
	local function setX(x)
		local p = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		local v = mn + (mx - mn) * p
		v = math.floor(v / step + 0.5) * step
		v = tonumber(string.format("%.4f", math.clamp(v, mn, mx)))
		tbl[key] = v
		refresh()
		changed(sec)
	end
	hit.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			page.ScrollingEnabled = false
			setX(i.Position.X)
		end
	end)
	UIS.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then setX(i.Position.X) end
	end)
	UIS.InputEnded:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			page.ScrollingEnabled = true
		end
	end)
end

local function dropdown(page, label, tbl, key, options, sec)
	local c = card(page, 40)
	text(c, label, 15, "text", { Size = UDim2.new(1, -176, 1, 0), Position = UDim2.new(0, 12, 0, 0) })
	local b, lbl = aeroButton(c, "", { Size = UDim2.fromOffset(150, 28), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0) }, 13)
	local function refresh() lbl.Text = tostring(tbl[key]) .. "  ▾" end
	refresh()
	table.insert(refreshers, refresh)
	b.Activated:Connect(function()
		local idx = (table.find(options, tbl[key]) or 0) % #options + 1
		tbl[key] = options[idx]
		refresh()
		changed(sec)
	end)
end

local function input(page, label, tbl, key, sec, isNumber)
	local c = card(page, 40)
	text(c, label, 15, "text", { Size = UDim2.new(1, -176, 1, 0), Position = UDim2.new(0, 12, 0, 0) })
	local box = new("TextBox", { Size = UDim2.fromOffset(150, 28), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
		BackgroundColor3 = white, BackgroundTransparency = 0.25, TextColor3 = Color3.fromRGB(20, 50, 80), Font = Enum.Font.Gotham,
		TextSize = 14, ClearTextOnFocus = false, Text = tostring(tbl[key]), BorderSizePixel = 0 }, c)
	new("UICorner", { CornerRadius = UDim.new(0, 8) }, box)
	new("UIStroke", { Color = white, Transparency = 0.3 }, box)
	local function refresh() box.Text = tostring(tbl[key]) end
	table.insert(refreshers, refresh)
	box.FocusLost:Connect(function()
		if isNumber then tbl[key] = tonumber(box.Text) or tbl[key] else tbl[key] = box.Text end
		refresh()
		changed(sec)
	end)
end

local function actionBtn(page, str, fn, tint)
	local c = card(page, 40)
	local b = aeroButton(c, str, { Size = UDim2.new(1, -16, 0, 30), Position = UDim2.new(0, 8, 0, 5) }, 14, tint)
	b.Activated:Connect(fn)
end

local function buttonRow(page, items)
	local c = card(page, 40)
	local n = #items
	for i, it in ipairs(items) do
		local b = aeroButton(c, it[1], { Size = UDim2.new(1 / n, -8, 0, 30),
			Position = UDim2.new((i - 1) / n, 5, 0, 5) }, 13)
		b.Activated:Connect(it[2])
	end
end

local function colorPick(page, label, tbl, key, sec)
	slider(page, label .. " – Red", tbl[key], 1, 0, 255, 1, sec)
	slider(page, label .. " – Green", tbl[key], 2, 0, 255, 1, sec)
	slider(page, label .. " – Blue", tbl[key], 3, 0, 255, 1, sec)
end

local function guideEntry(page, title, body)
	local c = card(page, 40)
	c.AutomaticSize = Enum.AutomaticSize.Y
	c.Size = UDim2.new(1, 0, 0, 40)
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, c)
	local head, hl = aeroButton(c, "▸ " .. title, { Size = UDim2.new(1, -16, 0, 30), LayoutOrder = 1 }, 14)
	local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2 }, c)
	local body = text(holder, body, 13, "text", { Size = UDim2.new(1, -24, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.new(0, 12, 0, 6), Visible = false }, body)
	new("UIPadding", { PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, c)
	head.Activated:Connect(function()
		body.Visible = not body.Visible
		hl.Text = (body.Visible and "▾ " or "▸ ") .. title
	end)
end

--==================================================================
-- PAGE: STYLE
--==================================================================
do
	local p = newPage("Style", "🎨")
	section(p, "Look & feel (Frutiger Aero)")
	dropdown(p, "Theme", CFG.ui, "theme", THEME_NAMES, "ui")
	note(p, "Pick 'Custom' to use your own accent colour below.")
	colorPick(p, "Custom accent", CFG.ui, "accent", "ui")
	slider(p, "Glass transparency", CFG.ui, "glass", 0, 0.9, 0.05, "ui")
	slider(p, "Corner roundness", CFG.ui, "corner", 4, 28, 1, "ui", " px")
	slider(p, "Menu size", CFG.ui, "scale", 0.6, 1.5, 0.05, "ui", "×")
	dropdown(p, "Menu font", CFG.ui, "font", { "Gotham", "Ubuntu", "Nunito", "FredokaOne", "SourceSans", "Arial", "Cartoon" }, "ui")
	toggle(p, "Gloss shine", CFG.ui, "gloss", "ui")
	toggle(p, "Reduce motion (no animations)", CFG.ui, "reduceMotion", "ui")
	section(p, "Menu access")
	input(p, "Open-menu key (PC)", CFG.ui, "menuKey", "ui")
	toggle(p, "Floating mini-menu bubble", CFG.mini, "enabled", "ui")
	slider(p, "Bubble size", CFG.ui, "bubbleSize", 36, 90, 2, "ui", " px")
	note(p, "On phones the bubble always stays on, so you can never lock yourself out.")
end

--==================================================================
-- PAGE: LAYOUT
--==================================================================
do
	local p = newPage("Layout", "🕹")
	section(p, "Jump button")
	slider(p, "Size", CFG.layout.jump, "scale", 0.4, 3, 0.05, "layout", "×")
	slider(p, "Move left / right", CFG.layout.jump, "x", -500, 500, 5, "layout", " px")
	slider(p, "Move up / down", CFG.layout.jump, "y", -400, 400, 5, "layout", " px")
	slider(p, "Opacity", CFG.layout.jump, "opacity", 0.1, 1, 0.05, "layout")
	section(p, "Thumbstick")
	slider(p, "Size", CFG.layout.thumb, "scale", 0.4, 3, 0.05, "layout", "×")
	slider(p, "Move left / right", CFG.layout.thumb, "x", -500, 500, 5, "layout", " px")
	slider(p, "Move up / down", CFG.layout.thumb, "y", -400, 400, 5, "layout", " px")
	slider(p, "Opacity (classic stick only)", CFG.layout.thumb, "opacity", 0.1, 1, 0.05, "layout")
	actionBtn(p, "✋ Drag & resize on screen", function() Layout.setEdit(true) end, Color3.fromRGB(60, 190, 90))
	section(p, "Quick action buttons")
	note(p, "Your own on-screen buttons. Command can be a chat command like /e wave, or @menu, @gfx, @screenshot, @rejoin.")
	for i = 1, 3 do
		local q = CFG.layout.quick[i]
		toggle(p, "Button " .. i .. " enabled", q, "on", "layout")
		input(p, "  Icon / text", q, "text", "layout")
		input(p, "  Command", q, "cmd", "layout")
		slider(p, "  Size", q, "size", 36, 120, 2, "layout", " px")
		slider(p, "  Opacity", q, "opacity", 0.1, 1, 0.05, "layout")
	end
	section(p, "Saved presets (per game)")
	dropdown(p, "Preset slot", CFG.layout, "slot", { 1, 2, 3 })
	buttonRow(p, { { "💾 Save", Layout.savePreset }, { "📂 Load", function() Layout.loadPreset(false) end }, { "🗑 Delete", Layout.deletePreset } })
	toggle(p, "Auto-load slot when joining this game", CFG.layout, "autoLoad")
	actionBtn(p, "↺ Reset layout", Layout.reset, Color3.fromRGB(230, 120, 70))
end

--==================================================================
-- PAGE: GRAPHICS
--==================================================================
do
	local p = newPage("Graphics", "🖼")
	section(p, "One-tap quality")
	buttonRow(p, { { "Potato", function() Gfx.preset(1) end }, { "Low", function() Gfx.preset(2) end },
		{ "Med", function() Gfx.preset(3) end }, { "High", function() Gfx.preset(4) end }, { "Ultra", function() Gfx.preset(5) end } })
	section(p, "Fine control")
	slider(p, "Quality level (0 = Auto)", CFG.gfx, "quality", 0, 10, 1, "gfx")
	toggle(p, "Shadows", CFG.gfx, "shadows", "gfx")
	slider(p, "Shadow softness", CFG.gfx, "shadowSoft", 0, 1, 0.05, "gfx")
	slider(p, "Render distance (0 = off)", CFG.gfx, "renderDist", 0, 3000, 50, "gfx", " studs")
	slider(p, "Texture / mesh detail", CFG.gfx, "texture", 0, 4, 1, "gfx")
	note(p, "Render distance uses distance fog. Some games lock quality settings, in which case those sliders do nothing.")
	section(p, "Low-data mode")
	toggle(p, "Low-data mode", CFG.data, "enabled", "data")
	toggle(p, "  Disable particles / trails / beams", CFG.data, "noEffects", "data")
	toggle(p, "  Hide decals & textures", CFG.data, "hideDecals", "data")
	toggle(p, "  Turn off bloom / blur / rays", CFG.data, "lightingFx", "data")
	toggle(p, "  Force low quality", CFG.data, "lowQuality", "data")
end

--==================================================================
-- PAGE: PERFORMANCE & LAG
--==================================================================
do
	local p = newPage("Perf", "⚡")
	section(p, "FPS & saver")
	slider(p, "FPS cap (0 = uncapped)", CFG.perf, "fpsCap", 0, 240, 10, "perf")
	toggle(p, "Battery saver (30 FPS + low graphics)", CFG.perf, "saver", "perf")
	toggle(p, "Auto saver when FPS stays low", CFG.perf, "auto", "perf")
	slider(p, "  Trigger below", CFG.perf, "autoFps", 10, 45, 1, "perf", " FPS")
	slider(p, "  …for", CFG.perf, "autoSeconds", 3, 30, 1, "perf", " s")
	actionBtn(p, "Turn auto-saver off for this session", function() autoSaver = false Perf.apply() end)
	note(p, "Roblox doesn't expose battery level or phone temperature to scripts, so the auto saver reacts to sustained low FPS instead (which is what overheating causes). FPS cap needs an environment that supports setfpscap.")
	section(p, "Lag compensation indicator")
	toggle(p, "Show warnings", CFG.lag, "enabled")
	toggle(p, "Always show ping + FPS", CFG.lag, "alwaysShow")
	slider(p, "Ping warning above", CFG.lag, "pingWarn", 80, 800, 10, nil, " ms")
	slider(p, "FPS warning below", CFG.lag, "fpsWarn", 10, 60, 1, nil, " FPS")
	slider(p, "Jitter warning above", CFG.lag, "jitterWarn", 30, 400, 10, nil, " ms")
end

--==================================================================
-- PAGE: ACCESSIBILITY
--==================================================================
do
	local p = newPage("Access", "♿")
	section(p, "Colour & text")
	dropdown(p, "Colour filter", CFG.access, "colorblind", CB_NAMES, "access")
	slider(p, "Filter strength", CFG.access, "cbStrength", 0.1, 1, 0.05, "access")
	slider(p, "Menu text size", CFG.access, "textScale", 0.8, 1.8, 0.05, "access", "×")
	section(p, "Subtitles for chat")
	toggle(p, "Enable subtitles", CFG.sub, "enabled", "sub")
	dropdown(p, "Style", CFG.sub, "style", { "Box", "Outline", "Shadow" })
	slider(p, "Text size", CFG.sub, "size", 12, 48, 1, nil, " px")
	slider(p, "Box opacity (Box style)", CFG.sub, "bg", 0, 1, 0.05)
	dropdown(p, "Font", CFG.sub, "font", { "Gotham", "Ubuntu", "Nunito", "FredokaOne", "SourceSans", "Arial", "Cartoon" })
	slider(p, "Seconds on screen", CFG.sub, "seconds", 2, 20, 1, nil, " s")
	slider(p, "Max lines", CFG.sub, "lines", 1, 6, 1)
	toggle(p, "Show speaker names", CFG.sub, "names")
	toggle(p, "Show at top of screen", CFG.sub, "top", "sub")
end

--==================================================================
-- PAGE: GESTURES & HAPTICS
--==================================================================
do
	local p = newPage("Gestures", "👆")
	section(p, "Touch gestures")
	toggle(p, "Gestures enabled", CFG.gest, "enabled")
	toggle(p, "Custom camera zoom range", CFG.gest, "zoomRange", "gest")
	slider(p, "  Closest zoom", CFG.gest, "zoomMin", 0.5, 20, 0.5, "gest", " studs")
	slider(p, "  Farthest zoom", CFG.gest, "zoomMax", 10, 500, 5, "gest", " studs")
	dropdown(p, "Two-finger tap", CFG.gest, "twoTap", { "Toggle Menu", "Screenshot", "Quick Graphics", "None" })
	toggle(p, "Swipe shortcuts", CFG.gest, "swipe")
	slider(p, "  Fingers needed", CFG.gest, "swipeFingers", 1, 3, 1)
	input(p, "  Swipe up", CFG.gest, "up")
	input(p, "  Swipe down", CFG.gest, "down")
	input(p, "  Swipe left", CFG.gest, "left")
	input(p, "  Swipe right", CFG.gest, "right")
	section(p, "Haptics")
	toggle(p, "Haptic feedback", CFG.haptic, "enabled")
	slider(p, "Strength", CFG.haptic, "strength", 0.1, 1, 0.05)
	toggle(p, "  On jump", CFG.haptic, "jump")
	toggle(p, "  On taking damage", CFG.haptic, "hit")
	toggle(p, "  On purchase", CFG.haptic, "purchase")
	actionBtn(p, "Test vibration", function() pulse(1, 0.3) end)
end

--==================================================================
-- PAGE: ALERTS
--==================================================================
do
	local p = newPage("Alerts", "🔔")
	section(p, "Smarter notifications")
	toggle(p, "Notifications enabled", CFG.alerts, "enabled")
	toggle(p, "Friend joins my server", CFG.alerts, "friendsInServer")
	toggle(p, "Friend starts playing (Join now button)", CFG.alerts, "friendsPlaying")
	slider(p, "Check friends every", CFG.alerts, "poll", 15, 120, 5, nil, " s")
	slider(p, "Show each alert for", CFG.alerts, "duration", 3, 20, 1, nil, " s")
	toggle(p, "Alert sound", CFG.alerts, "sound")
	actionBtn(p, "Send a test notification", function()
		notify("🎮 Test friend is playing", "This is what a Join-now alert looks like.", "Join now", function() end)
	end)
end

--==================================================================
-- PAGE: PLAYERS (speedometer + show-all)
--==================================================================
do
	local p = newPage("Players", "👥")
	section(p, "Speedometer")
	toggle(p, "Show speedometer", CFG.speedo, "enabled")
	dropdown(p, "Source", CFG.speedo, "mode", { "Client", "Server" })
	dropdown(p, "Unit", CFG.speedo, "unit", { "studs/s", "km/h", "mph" })
	toggle(p, "Ignore vertical speed", CFG.speedo, "horizontal")
	note(p, "Client = speed calculated from how far you moved. Server = a server-set attribute if the game has one, otherwise the replicated physics velocity. Drag the speedometer to place it.")
	section(p, "Show all players")
	toggle(p, "Enable overview", CFG.esp, "enabled")
	toggle(p, "  Highlight", CFG.esp, "highlight")
	slider(p, "  Highlight fill", CFG.esp, "fill", 0, 1, 0.05)
	toggle(p, "  Line to player", CFG.esp, "lines")
	toggle(p, "  Box around character", CFG.esp, "boxes")
	toggle(p, "  Names", CFG.esp, "names")
	toggle(p, "  Their speed", CFG.esp, "speed")
	toggle(p, "  Use team colours", CFG.esp, "teamColor")
	colorPick(p, "  Colour", CFG.esp, "color")
	slider(p, "  Max distance", CFG.esp, "maxDist", 50, 3000, 50, nil, " studs")
	note(p, "Intended for your own game, testing and spectating. Using it for an edge in someone else's game may break its rules.")
end

--==================================================================
-- PAGE: LEADERBOARD
--==================================================================
local boardRefresh
do
	local p = newPage("Board", "🏆")
	section(p, "Server leaderboard")
	dropdown(p, "Sort by", CFG.board, "sort", { "Stat 1", "Stat 2", "Stat 3", "Name", "Distance" })
	toggle(p, "Highest first", CFG.board, "desc")
	local head = card(p, 30)
	head.LayoutOrder = 1000000
	local rows, cols = {}, { 0, 0.36, 0.52, 0.68, 0.84 }
	local function mkRow(parent, bold)
		local r = {}
		for i = 1, 5 do
			r[i] = text(parent, "", bold and 13 or 13, bold and "accent" or "text", { Size = UDim2.new(i == 1 and 0.34 or 0.16, 0, 1, 0),
				Position = UDim2.new(cols[i], i == 1 and 10 or 0, 0, 0), TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd,
				Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham })
		end
		return r
	end
	local headCells = mkRow(head, true)
	headCells[1].Text, headCells[5].Text = "Player", "Dist"

	boardRefresh = function()
		local plrs, statNames = Players:GetPlayers(), {}
		for _, pl in ipairs(plrs) do
			local ls = pl:FindFirstChild("leaderstats")
			if ls then
				for _, v in ipairs(ls:GetChildren()) do
					if v:IsA("ValueBase") and not table.find(statNames, v.Name) and #statNames < 3 then table.insert(statNames, v.Name) end
				end
			end
		end
		for i = 1, 3 do headCells[i + 1].Text = statNames[i] or "" end
		local myPos = myRoot() and myRoot().Position
		local data = {}
		for _, pl in ipairs(plrs) do
			local ls = pl:FindFirstChild("leaderstats")
			local d = { p = pl, stats = {} }
			for i, n in ipairs(statNames) do
				local v = ls and ls:FindFirstChild(n)
				d.stats[i] = v and v.Value or 0
			end
			local r = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
			d.dist = (r and myPos) and (r.Position - myPos).Magnitude or math.huge
			table.insert(data, d)
		end
		local s = CFG.board.sort
		local function key(d)
			if s == "Name" then return d.p.Name:lower()
			elseif s == "Distance" then return d.dist
			else return tonumber(d.stats[tonumber(s:sub(-1))]) or 0 end
		end
		table.sort(data, function(a, b)
			local ka, kb = key(a), key(b)
			if ka == kb then return a.p.Name < b.p.Name end
			if CFG.board.desc then return ka > kb else return ka < kb end
		end)
		local alive = {}
		for rank, d in ipairs(data) do
			local row = rows[d.p]
			if not row then
				local f = card(p, 30)
				row = { f = f, cells = mkRow(f, false) }
				rows[d.p] = row
			end
			alive[d.p] = true
			row.f.LayoutOrder = rank
			row.cells[1].Text = (d.p == LP and "★ " or "") .. d.p.DisplayName
			for i = 1, 3 do row.cells[i + 1].Text = statNames[i] and tostring(d.stats[i]) or "" end
			row.cells[5].Text = d.dist == math.huge and "-" or (d.p == LP and "you" or tostring(math.floor(d.dist)))
		end
		for pl, row in pairs(rows) do
			if not alive[pl] then row.f:Destroy() rows[pl] = nil end
		end
	end
	task.spawn(function()
		while true do
			task.wait(1)
			if pages.Board.Visible and win.Visible then pcall(boardRefresh) end
		end
	end)
end

--==================================================================
-- PAGE: PROFILES (export / import)
--==================================================================
local function applyEverything()
	for _, fn in pairs(APPLY) do pcall(fn) end
	applyTheme()
	refreshAll()
	save()
end

do
	local p = newPage("Profiles", "📦")
	section(p, "Share or back up your setup")
	note(p, "Export creates one code containing ALL your settings (including layouts). Paste a code below and press Import to load it.")
	local c = card(p, 110)
	local box = new("TextBox", { Size = UDim2.new(1, -16, 1, -16), Position = UDim2.new(0, 8, 0, 8), BackgroundColor3 = white,
		BackgroundTransparency = 0.3, TextColor3 = Color3.fromRGB(20, 50, 80), Font = Enum.Font.Code, TextSize = 12,
		TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		ClearTextOnFocus = false, MultiLine = true, PlaceholderText = "Your profile code appears here — or paste one to import…",
		Text = "", BorderSizePixel = 0 }, c)
	new("UICorner", { CornerRadius = UDim.new(0, 8) }, box)
	buttonRow(p, {
		{ "📤 Export", function()
			local code = exportCode()
			box.Text = code
			local copied = typeof(setclipboard) == "function" and pcall(setclipboard, code)
			notify("Profile exported", copied and "Copied to your clipboard!" or "Tap the box, select all, and copy.", nil, nil, 5)
		end },
		{ "📥 Import", function()
			local code = box.Text:gsub("%s", "")
			if code:sub(1, 6) ~= "QOLS1:" then notify("Invalid code", "That doesn't look like a QoL Suite profile.", nil, nil, 4) return end
			local ok, data = pcall(function() return HttpService:JSONDecode(b64dec(code:sub(7))) end)
			if not ok or type(data) ~= "table" then notify("Import failed", "The code is damaged or incomplete.", nil, nil, 4) return end
			merge(CFG, data)
			applyEverything()
			notify("Profile imported ✔", "All settings were applied.", nil, nil, 4)
		end },
	})
	actionBtn(p, "↺ Reset EVERYTHING to defaults", function()
		merge(CFG, DEFAULTS)
		CFG.layout.presets = {}
		applyEverything()
		notify("Reset", "All settings are back to default.", nil, nil, 4)
	end, Color3.fromRGB(230, 90, 90))
	note(p, canFS and "Your settings auto-save to " .. FILE .. "." or "This environment can't write files, so settings last for this session. Use Export to keep them.")
end

--==================================================================
-- PAGE: GUIDE
--==================================================================
do
	local p = newPage("Guide", "📖")
	section(p, "How everything works (tap to expand)")
	local G = {
		{ "Opening the menu", "Tap the glass bubble, press your menu key (RightShift by default), or use a two-finger tap if you enabled that. Drag the title bar to move the window. The Style tab changes colours, glass, roundness, fonts and size." },
		{ "Lag indicator", "Every half second it checks your FPS and ping (and ping jitter). Low FPS means YOUR device is the bottleneck; high ping means your connection is. It tells you which one so you know whether to blame the game. Thresholds are adjustable in Perf." },
		{ "Smarter notifications", "Alerts when a friend joins your server, or when a friend starts playing an experience (with a Join now button that teleports you to their exact server). Friend checks run every few seconds you choose." },
		{ "Low-data mode", "Turns off particles, trails, beams, bloom/blur, optionally hides decals/textures and forces low quality, including for anything that loads in later. Roblox decides what actually downloads, so this reduces rendering load and effect usage rather than blocking the network." },
		{ "Accessibility", "Colour filters (protanopia / deuteranopia / tritanopia / monochrome / high contrast) are assistive tints, approximations rather than medical-grade correction. Text size scales the menu. Subtitles mirror chat messages on screen with your own style, size, position and timing." },
		{ "Gestures", "Custom zoom range changes how close/far the camera can go (the normal pinch gesture then uses your range). Two-finger quick tap runs an action you choose. Swipe with N fingers sends a chat command like /e wave for each direction." },
		{ "Haptics", "Vibrates on jump, damage and purchases with adjustable strength. Roblox only exposes vibration for supported controllers, so on a plain phone you may feel nothing. This will light up wherever the device supports it." },
		{ "Mini-menu bubble", "A draggable bubble with shortcuts: settings, rejoin, screenshot and a one-tap graphics cycle. Drag it anywhere; its position is saved. Tap it to expand." },
		{ "Custom button layout", "Layout tab: resize, move and fade the jump button and thumbstick with sliders, or press 'Drag & resize on screen' to do it by hand. Roblox's own chat/menu buttons are protected and can't be moved, so use Quick Action buttons (your own, fully editable) for emotes and shortcuts. Save up to 3 presets per game and auto-load them when you join." },
		{ "Quick graphics", "Potato → Ultra in one tap, plus separate sliders for quality, shadows, softness, render distance (fog) and texture/mesh detail. Games can lock some settings." },
		{ "Performance mode", "FPS cap (where supported) and a battery saver that drops graphics and caps 30 FPS. Auto-saver triggers if FPS stays under your threshold for your chosen time. Roblox gives no battery/temperature info to scripts, so sustained low FPS is used as the heat/low-power signal." },
		{ "Jump button change", "Layout > Jump button: size, left/right, up/down and opacity. If Roblox resets the button after a screen change, your changes re-apply automatically." },
		{ "Leaderboard", "Board tab lists everyone in the server with up to three of their leaderstats, plus distance from you. Sort by any stat, name or distance." },
		{ "Speedometer", "Shows your speed in studs/s, km/h or mph. Client mode computes it from your movement. Server mode uses a ServerSpeed attribute if the game's server sets one (see the optional snippet at the top of the file), otherwise the replicated physics velocity. Drag it to reposition." },
		{ "Show all players", "Highlights, boxes, lines from the bottom of your screen, names and speeds for everyone, with team colours and a max distance. Meant for your own games, testing and spectating; check an experience's rules before using it in others." },
		{ "Profiles", "Export makes one code with every setting and layout; Import applies a code instantly. Great for backing up, moving devices or sharing your style." },
	}
	for _, g in ipairs(G) do guideEntry(p, g[1], g[2]) end
end

--==================================================================
-- FLOATING MINI-MENU BUBBLE
--==================================================================
local bubble = new("Frame", { AnchorPoint = Vector2.new(0, 0), Active = true, BorderSizePixel = 0 }, gui)
new("UICorner", { CornerRadius = UDim.new(1, 0) }, bubble)
local bStroke = new("UIStroke", { Color = white, Thickness = 2, Transparency = 0.1 }, bubble)
local bGrad = new("UIGradient", { Rotation = 90 }, bubble)
local bGloss = new("Frame", { BackgroundColor3 = white, BorderSizePixel = 0, Position = UDim2.new(0.12, 0, 0.06, 0), Size = UDim2.new(0.76, 0, 0.45, 0) }, bubble)
new("UICorner", { CornerRadius = UDim.new(1, 0) }, bGloss)
new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0.9) }) }, bGloss)
local bIcon = new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "✦", TextColor3 = white,
	Font = Enum.Font.GothamBold, TextScaled = true, ZIndex = 3 }, bubble)
new("UIPadding", { PaddingTop = UDim.new(0.2, 0), PaddingBottom = UDim.new(0.2, 0), PaddingLeft = UDim.new(0.2, 0), PaddingRight = UDim.new(0.2, 0) }, bIcon)

local popup = glass(gui, { Size = UDim2.fromOffset(190, 0), AutomaticSize = Enum.AutomaticSize.Y, Visible = false, ZIndex = 5 })
new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, popup)
new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, popup)
local function popBtn(str, fn)
	local b = aeroButton(popup, str, { Size = UDim2.new(1, 0, 0, 32) }, 14)
	b.Activated:Connect(function() popup.Visible = false fn() end)
end
popBtn("⚙ Settings", function() toggleMenu(true) end)
popBtn("↻ Rejoin", rejoin)
popBtn("📷 Screenshot", screenshot)
popBtn("⚡ Quick graphics", function() Gfx.cycle() end)

local function placePopup()
	local vp = gui.AbsoluteSize
	local pos = bubble.AbsolutePosition
	local x = math.clamp(pos.X, 4, vp.X - 200)
	local y = pos.Y + bubble.AbsoluteSize.Y + 8
	if y + 190 > vp.Y then y = math.max(4, pos.Y - 190) end
	popup.Position = UDim2.fromOffset(x, y)
end

makeDraggable(bubble, bubble, function(moved)
	if moved then
		savePos(bubble, CFG.mini.pos)
		popup.Visible = false
	else
		placePopup()
		popup.Visible = not popup.Visible
	end
end)

APPLY.ui = function()
	applyTheme()
	local s = CFG.ui.bubbleSize
	bubble.Size = UDim2.fromOffset(s, s)
	bubble.Position = UDim2.fromScale(CFG.mini.pos.x, CFG.mini.pos.y)
	bubble.Visible = CFG.mini.enabled or not UIS.KeyboardEnabled
	local a = theme().accent
	bGrad.Color = ColorSequence.new(a:Lerp(white, 0.45), a:Lerp(Color3.new(0, 0, 0), 0.15))
end
reg(function() local a = theme().accent bGrad.Color = ColorSequence.new(a:Lerp(white, 0.45), a:Lerp(Color3.new(0, 0, 0), 0.15)) end)

--==================================================================
-- OPEN / CLOSE + KEYBIND
--==================================================================
toggleMenu = function(force)
	local v = force
	if v == nil then v = not win.Visible end
	if v and editing then return end
	if v then
		win.Visible = true
		win.Size = UDim2.fromScale(0.72, 0.84)
		if not CFG.ui.reduceMotion then
			win.Position = UDim2.new(0.5, 0, 0.55, 0)
			tw(win, { Position = UDim2.fromScale(0.5, 0.5) }, 0.2)
		end
		popup.Visible = false
	else
		win.Visible = false
	end
end
closeB.Activated:Connect(function() toggleMenu(false) end)

UIS.InputBegan:Connect(function(i, gpe)
	if gpe or UIS:GetFocusedTextBox() then return end
	if i.UserInputType == Enum.UserInputType.Keyboard then
		local ok, kc = pcall(function() return Enum.KeyCode[CFG.ui.menuKey] end)
		if ok and i.KeyCode == kc then toggleMenu() end
	end
end)

--==================================================================
-- STARTUP
--==================================================================
setPage("Style")
for _, fn in pairs(APPLY) do pcall(fn) end
applyTheme()
refreshAll()
if CFG.layout.autoLoad then task.delay(2, function() Layout.loadPreset(true) end) end
task.delay(1, function()
	notify("✦ QoL Suite ready", UIS.KeyboardEnabled and "Tap the bubble or press " .. CFG.ui.menuKey .. " to open." or "Tap the glass bubble to open the menu.", nil, nil, 6)
end)
