--[[
	HappyMid Menu v1.3  (boxy retro dev/admin panel)

	SETUP (Roblox Studio, your own place):
	  1. Explorer > StarterPlayer > StarterPlayerScripts
	  2. Insert a LocalScript and paste this whole file in
	  3. Press Play. Insert key (or the MENU button) hides/shows the menu.

	Fly controls: WASD / thumbstick moves along where the camera looks,
	Space or E = up, LeftCtrl or Q = down.

	Everything runs on the client, so it only affects you in your own game.
	Spawned bricks are local-only too.
]]

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

--------------------------------------------------------------------
-- theme + tiny helpers
--------------------------------------------------------------------
local C = {
	win = Color3.fromRGB(42, 42, 42),
	bar = Color3.fromRGB(30, 30, 30),
	dim = Color3.fromRGB(22, 22, 22),
	row = Color3.fromRGB(34, 34, 34),
	off = Color3.fromRGB(12, 12, 12),
	black = Color3.new(0, 0, 0),
	hi = Color3.fromRGB(90, 90, 90),
	txt = Color3.fromRGB(236, 236, 236),
	mut = Color3.fromRGB(155, 155, 155),
	acc = Color3.fromRGB(57, 255, 20),
	bad = Color3.fromRGB(255, 82, 82),
	blue = Color3.fromRGB(111, 195, 255),
}
local FONT = Enum.Font.Code

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
	return o
end

local function stroke(o, color, thick)
	return new("UIStroke", {
		Color = color or C.black,
		Thickness = thick or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, o)
end

local function isPointer(i)
	return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
end

local function isMove(i)
	return i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch
end

--------------------------------------------------------------------
-- state + character helpers
--------------------------------------------------------------------
local state = { speed = 16, jump = 50 }
local resets = {} -- functions that put a feature back to default

local function getChar() return player.Character end
local function getHum()
	local c = player.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end
local function getRoot()
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function applyStats()
	local h = getHum()
	if not h then return end
	h.WalkSpeed = state.speed
	h.UseJumpPower = true
	h.JumpPower = state.jump
end

player.CharacterAdded:Connect(function(char)
	char:WaitForChild("Humanoid")
	task.wait(0.1)
	applyStats()
end)

--------------------------------------------------------------------
-- console logging (UI is attached further down)
--------------------------------------------------------------------
local consoleScroll
local logLines = {}
local logOrder = 0

local function log(msg, kind)
	if not consoleScroll then return end
	local color = C.txt
	if kind == "ok" then color = C.acc elseif kind == "bad" then color = C.bad elseif kind == "inf" then color = C.blue end
	logOrder += 1
	local l = new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Text = msg,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = FONT,
		TextSize = 13,
		TextColor3 = color,
		LayoutOrder = logOrder,
	}, consoleScroll)
	table.insert(logLines, l)
	if #logLines > 60 then
		table.remove(logLines, 1):Destroy()
	end
	task.defer(function()
		consoleScroll.CanvasPosition = Vector2.new(0, consoleScroll.AbsoluteCanvasSize.Y)
	end)
end

--------------------------------------------------------------------
-- features
--------------------------------------------------------------------
-- Fly
local flyConn
local controls

local function getMoveVector(cam, hum)
	if not controls then
		local ps = player:FindFirstChild("PlayerScripts")
		local pm = ps and ps:FindFirstChild("PlayerModule")
		if pm then
			local ok, res = pcall(function()
				return require(pm):GetControls()
			end)
			if ok then controls = res end
		end
	end
	if controls then
		local ok, v = pcall(function()
			return controls:GetMoveVector()
		end)
		if ok then return v end
	end
	local l = cam.CFrame:VectorToObjectSpace(hum.MoveDirection)
	return Vector3.new(l.X, 0, l.Z)
end

local function setFly(on)
	if flyConn then
		flyConn:Disconnect()
		flyConn = nil
	end
	local root = getRoot()
	if root then
		for _, n in ipairs({ "HM_Fly", "HM_FlyAtt" }) do
			local o = root:FindFirstChild(n)
			if o then o:Destroy() end
		end
	end
	if not on then return end

	flyConn = RunService.RenderStepped:Connect(function()
		local r, h, cam = getRoot(), getHum(), workspace.CurrentCamera
		if not (r and h and cam) then return end

		local lv = r:FindFirstChild("HM_Fly")
		if not lv then
			local att = new("Attachment", { Name = "HM_FlyAtt" }, r)
			lv = new("LinearVelocity", {
				Name = "HM_Fly",
				Attachment0 = att,
				MaxForce = math.huge,
				VelocityConstraintMode = Enum.VelocityConstraintMode.Vector,
				RelativeTo = Enum.ActuatorRelativeTo.World,
				VectorVelocity = Vector3.zero,
			}, r)
		end

		local mv = getMoveVector(cam, h)
		local dir = cam.CFrame.LookVector * -mv.Z + cam.CFrame.RightVector * mv.X
		local vert = 0
		if UIS:IsKeyDown(Enum.KeyCode.Space) or UIS:IsKeyDown(Enum.KeyCode.E) then vert += 1 end
		if UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.Q) then vert -= 1 end
		dir += Vector3.new(0, vert, 0)
		if dir.Magnitude > 0 then dir = dir.Unit end
		lv.VectorVelocity = dir * math.clamp(state.speed * 2.5, 40, 300)
	end)
end

-- Noclip
local noclipConn
local noclipOrig = {}

local function setNoclip(on)
	if noclipConn then
		noclipConn:Disconnect()
		noclipConn = nil
	end
	if on then
		noclipConn = RunService.Stepped:Connect(function()
			local c = getChar()
			if not c then return end
			for _, p in ipairs(c:GetDescendants()) do
				if p:IsA("BasePart") then
					if noclipOrig[p] == nil then noclipOrig[p] = p.CanCollide end
					p.CanCollide = false
				end
			end
		end)
	else
		for p, v in pairs(noclipOrig) do
			if p.Parent then p.CanCollide = v end
		end
		table.clear(noclipOrig)
	end
end

-- Infinite jump
local jumpConn
local function setInfJump(on)
	if jumpConn then
		jumpConn:Disconnect()
		jumpConn = nil
	end
	if on then
		jumpConn = UIS.JumpRequest:Connect(function()
			local h = getHum()
			if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
		end)
	end
end

-- ESP (Highlight + name tag on other players)
local espConns = {}

local function clearESP()
	for _, p in ipairs(Players:GetPlayers()) do
		local c = p.Character
		if c then
			for _, n in ipairs({ "HM_ESP", "HM_ESPTag" }) do
				local o = c:FindFirstChild(n)
				if o then o:Destroy() end
			end
		end
	end
end

local function addESP(plr)
	if plr == player then return end
	local c = plr.Character
	if not c or c:FindFirstChild("HM_ESP") then return end
	new("Highlight", {
		Name = "HM_ESP",
		Adornee = c,
		FillColor = Color3.fromRGB(255, 60, 60),
		OutlineColor = Color3.new(1, 1, 1),
		FillTransparency = 0.6,
		DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
	}, c)
	local head = c:FindFirstChild("Head")
	if head then
		local bb = new("BillboardGui", {
			Name = "HM_ESPTag",
			Adornee = head,
			Size = UDim2.fromOffset(120, 20),
			StudsOffset = Vector3.new(0, 2.5, 0),
			AlwaysOnTop = true,
		}, c)
		new("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = plr.DisplayName,
			TextColor3 = Color3.fromRGB(255, 60, 60),
			TextStrokeTransparency = 0,
			Font = FONT,
			TextSize = 14,
		}, bb)
	end
end

local function hookESP(plr)
	table.insert(espConns, plr.CharacterAdded:Connect(function()
		task.wait(0.5)
		addESP(plr)
	end))
	addESP(plr)
end

local function setESP(on)
	for _, c in ipairs(espConns) do c:Disconnect() end
	table.clear(espConns)
	clearESP()
	if on then
		for _, p in ipairs(Players:GetPlayers()) do hookESP(p) end
		table.insert(espConns, Players.PlayerAdded:Connect(hookESP))
	end
end

-- Fullbright
local lightOrig
local function setFullbright(on)
	if on then
		lightOrig = lightOrig or {
			Brightness = Lighting.Brightness,
			ClockTime = Lighting.ClockTime,
			FogEnd = Lighting.FogEnd,
			GlobalShadows = Lighting.GlobalShadows,
			Ambient = Lighting.Ambient,
			OutdoorAmbient = Lighting.OutdoorAmbient,
		}
		Lighting.Brightness = 2
		Lighting.ClockTime = 14
		Lighting.FogEnd = 1e6
		Lighting.GlobalShadows = false
		Lighting.Ambient = Color3.fromRGB(178, 178, 178)
		Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
	elseif lightOrig then
		for k, v in pairs(lightOrig) do Lighting[k] = v end
		lightOrig = nil
	end
end

-- Gravity
local origGravity = workspace.Gravity
local function setLowGravity(on)
	workspace.Gravity = on and 60 or origGravity
end

-- Bricks (client-side only)
local function brickFolder()
	local f = workspace:FindFirstChild("HM_Bricks")
	if not f then
		f = new("Folder", { Name = "HM_Bricks" }, workspace)
	end
	return f
end

local function spawnBrick()
	local root = getRoot()
	if not root then return end
	local p = new("Part", {
		Size = Vector3.new(4, 2, 2),
		Color = Color3.fromHSV(math.random(), 0.8, 1),
		CFrame = root.CFrame * CFrame.new(math.random(-8, 8), 20, -math.random(6, 14)),
	}, brickFolder())
	Debris:AddItem(p, 30)
end

--------------------------------------------------------------------
-- UI
--------------------------------------------------------------------
local old = playerGui:FindFirstChild("HappyMidMenu")
if old then old:Destroy() end

local gui = new("ScreenGui", {
	Name = "HappyMidMenu",
	ResetOnSpawn = false,
	DisplayOrder = 100,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)

local WIN_W, WIN_H, BAR_H = 320, 392, 28

local win = new("Frame", {
	Name = "Window",
	Size = UDim2.fromOffset(WIN_W, WIN_H),
	Position = UDim2.new(0.5, -WIN_W / 2, 0, 60),
	BackgroundColor3 = C.win,
	BorderSizePixel = 0,
	Active = true,
}, gui)
stroke(win, C.black, 2)

local titleBar = new("Frame", {
	Size = UDim2.new(1, 0, 0, BAR_H),
	BackgroundColor3 = C.bar,
	BorderSizePixel = 0,
}, win)
new("TextLabel", {
	Position = UDim2.fromOffset(8, 0),
	Size = UDim2.new(1, -60, 1, 0),
	BackgroundTransparency = 1,
	Text = "HappyMid  v1.3",
	TextXAlignment = Enum.TextXAlignment.Left,
	Font = FONT,
	TextSize = 15,
	TextColor3 = C.acc,
}, titleBar)

local function barButton(text, xFromRight)
	local b = new("TextButton", {
		Size = UDim2.fromOffset(22, 22),
		Position = UDim2.new(1, xFromRight, 0, 3),
		BackgroundColor3 = Color3.fromRGB(58, 58, 58),
		BorderSizePixel = 0,
		Text = text,
		Font = FONT,
		TextSize = 14,
		TextColor3 = C.txt,
	}, titleBar)
	stroke(b, C.black, 2)
	return b
end
local minBtn = barButton("_", -52)
local closeBtn = barButton("X", -26)

local body = new("Frame", {
	Position = UDim2.fromOffset(0, BAR_H),
	Size = UDim2.new(1, 0, 1, -BAR_H),
	BackgroundTransparency = 1,
}, win)

local tabRow = new("Frame", {
	Position = UDim2.fromOffset(6, 6),
	Size = UDim2.new(1, -12, 0, 26),
	BackgroundTransparency = 1,
}, body)
new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 2),
}, tabRow)

local holder = new("Frame", {
	Position = UDim2.fromOffset(6, 34),
	Size = UDim2.new(1, -12, 1, -58),
	BackgroundTransparency = 1,
}, body)

new("TextLabel", {
	Position = UDim2.new(0, 6, 1, -22),
	Size = UDim2.new(1, -12, 0, 18),
	BackgroundTransparency = 1,
	Text = "Insert = hide / show",
	TextXAlignment = Enum.TextXAlignment.Left,
	Font = FONT,
	TextSize = 12,
	TextColor3 = C.mut,
}, body)

-- tabs
local pages, tabBtns = {}, {}

local function selectTab(name)
	for n, p in pairs(pages) do
		p.Visible = (n == name)
	end
	for n, b in pairs(tabBtns) do
		b.TextColor3 = (n == name) and C.acc or C.mut
		b.BackgroundColor3 = (n == name) and C.win or Color3.fromRGB(26, 26, 26)
	end
end

local function makeTab(name)
	local b = new("TextButton", {
		Size = UDim2.new(0.25, -2, 1, 0),
		BackgroundColor3 = Color3.fromRGB(26, 26, 26),
		BorderSizePixel = 0,
		Text = name,
		Font = FONT,
		TextSize = 14,
		TextColor3 = C.mut,
	}, tabRow)
	stroke(b, C.black, 2)
	b.Activated:Connect(function() selectTab(name) end)
	tabBtns[name] = b

	local page = new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.dim,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = false,
	}, holder)
	stroke(page, C.black, 2)
	new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, page)
	new("UIPadding", {
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 10),
	}, page)
	pages[name] = page
	return page
end

-- widgets
local function addToggle(page, label, onChange)
	local on = false
	local row = new("TextButton", {
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundColor3 = C.row,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
	}, page)
	stroke(row, C.black, 1)
	local boxF = new("Frame", {
		Size = UDim2.fromOffset(16, 16),
		Position = UDim2.new(0, 6, 0.5, -8),
		BackgroundColor3 = C.off,
		BorderSizePixel = 0,
	}, row)
	local boxStroke = stroke(boxF, C.mut, 2)
	local txt = new("TextLabel", {
		Position = UDim2.fromOffset(30, 0),
		Size = UDim2.new(1, -34, 1, 0),
		BackgroundTransparency = 1,
		Text = label,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = FONT,
		TextSize = 14,
		TextColor3 = C.txt,
	}, row)

	local api = {}
	function api.set(v, quiet)
		on = v
		boxF.BackgroundColor3 = v and C.acc or C.off
		boxStroke.Color = v and C.acc or C.mut
		txt.TextColor3 = v and C.acc or C.txt
		onChange(v)
		if not quiet then
			log("[" .. (v and "+" or "-") .. "] " .. label .. (v and " enabled" or " disabled"), v and "ok" or nil)
		end
	end
	row.Activated:Connect(function() api.set(not on) end)
	table.insert(resets, function() if on then api.set(false, true) end end)
	return api
end

local function addSlider(page, label, min, max, default, onChange)
	local holderF = new("Frame", {
		Size = UDim2.new(1, 0, 0, 46),
		BackgroundColor3 = C.row,
		BorderSizePixel = 0,
	}, page)
	stroke(holderF, C.black, 1)
	local lbl = new("TextLabel", {
		Position = UDim2.fromOffset(6, 2),
		Size = UDim2.new(1, -12, 0, 18),
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = FONT,
		TextSize = 14,
		TextColor3 = C.txt,
		Text = "",
	}, holderF)
	local track = new("TextButton", {
		Position = UDim2.new(0, 8, 0, 26),
		Size = UDim2.new(1, -16, 0, 14),
		BackgroundColor3 = C.off,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
	}, holderF)
	stroke(track, C.black, 2)
	local fill = new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = C.acc,
		BorderSizePixel = 0,
	}, track)

	local value = default
	local function render()
		lbl.Text = label .. ": " .. value
		fill.Size = UDim2.fromScale((value - min) / (max - min), 1)
	end
	render()

	local function setFromX(x)
		local a = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		value = math.floor(min + (max - min) * a + 0.5)
		render()
		onChange(value)
	end

	local dragging = false
	track.InputBegan:Connect(function(i)
		if isPointer(i) then
			dragging = true
			setFromX(i.Position.X)
		end
	end)
	UIS.InputChanged:Connect(function(i)
		if dragging and isMove(i) then setFromX(i.Position.X) end
	end)
	UIS.InputEnded:Connect(function(i)
		if dragging and isPointer(i) then
			dragging = false
			log(label .. " set to " .. value, "ok")
		end
	end)

	table.insert(resets, function()
		value = default
		render()
		onChange(value)
	end)
end

local function addButton(page, text, callback)
	local b = new("TextButton", {
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundColor3 = Color3.fromRGB(58, 58, 58),
		BorderSizePixel = 0,
		Text = text,
		Font = FONT,
		TextSize = 14,
		TextColor3 = C.txt,
	}, page)
	stroke(b, C.black, 2)
	b.Activated:Connect(callback)
	return b
end

-- Player tab
local pPlayer = makeTab("Player")
addSlider(pPlayer, "WalkSpeed", 16, 200, 16, function(v)
	state.speed = v
	applyStats()
end)
addSlider(pPlayer, "JumpPower", 50, 200, 50, function(v)
	state.jump = v
	applyStats()
end)
addToggle(pPlayer, "Fly", setFly)
addToggle(pPlayer, "Noclip", setNoclip)
addToggle(pPlayer, "Infinite Jump", setInfJump)
addButton(pPlayer, "Reset All", function()
	for _, f in ipairs(resets) do f() end
	log("[*] Everything reset to default.", "inf")
end)

-- Visual tab
local pVisual = makeTab("Visual")
addToggle(pVisual, "ESP Boxes", setESP)
addToggle(pVisual, "Fullbright", setFullbright)
local startFov = workspace.CurrentCamera and workspace.CurrentCamera.FieldOfView or 70
addSlider(pVisual, "Field of View", 40, 120, math.floor(startFov + 0.5), function(v)
	local cam = workspace.CurrentCamera
	if cam then cam.FieldOfView = v end
end)

-- World tab
local pWorld = makeTab("World")
addToggle(pWorld, "Low Gravity", setLowGravity)
addButton(pWorld, "Spawn Brick", function()
	spawnBrick()
	log("[+] Brick spawned", "ok")
end)
addButton(pWorld, "Brick Rain x10", function()
	for i = 1, 10 do
		task.delay(i * 0.12, spawnBrick)
	end
	log("[+] Brick rain x10", "ok")
end)
addButton(pWorld, "Clear Bricks", function()
	local f = workspace:FindFirstChild("HM_Bricks")
	if f then f:ClearAllChildren() end
	log("Bricks cleared.")
end)

-- Console tab (own layout: log on top, clear button under it)
local pConsole = new("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = C.dim,
	BorderSizePixel = 0,
	Visible = false,
}, holder)
stroke(pConsole, C.black, 2)
pages["Console"] = pConsole
local tb = new("TextButton", {
	Size = UDim2.new(1, -4, 0, 26),
	Position = UDim2.new(0, 2, 1, -28),
	BackgroundColor3 = Color3.fromRGB(58, 58, 58),
	BorderSizePixel = 0,
	Text = "Clear Console",
	Font = FONT,
	TextSize = 13,
	TextColor3 = C.txt,
}, pConsole)
stroke(tb, C.black, 2)
tabBtns["Console"] = new("TextButton", {
	Size = UDim2.new(0.25, -2, 1, 0),
	BackgroundColor3 = Color3.fromRGB(26, 26, 26),
	BorderSizePixel = 0,
	Text = "Console",
	Font = FONT,
	TextSize = 14,
	TextColor3 = C.mut,
}, tabRow)
stroke(tabBtns["Console"], C.black, 2)
tabBtns["Console"].Activated:Connect(function() selectTab("Console") end)

consoleScroll = new("ScrollingFrame", {
	Position = UDim2.fromOffset(4, 4),
	Size = UDim2.new(1, -8, 1, -38),
	BackgroundColor3 = C.black,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, pConsole)
new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, consoleScroll)
new("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingTop = UDim.new(0, 2) }, consoleScroll)

tb.Activated:Connect(function()
	for _, l in ipairs(logLines) do l:Destroy() end
	table.clear(logLines)
end)

--------------------------------------------------------------------
-- window behaviour: drag, minimize, hide/show
--------------------------------------------------------------------
local dragging, dragStart, startPos = false, nil, nil
titleBar.InputBegan:Connect(function(i)
	if isPointer(i) then
		dragging = true
		dragStart = i.Position
		startPos = win.Position
	end
end)
UIS.InputChanged:Connect(function(i)
	if dragging and isMove(i) then
		local d = i.Position - dragStart
		win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
	end
end)
UIS.InputEnded:Connect(function(i)
	if isPointer(i) then dragging = false end
end)

local minimized = false
minBtn.Activated:Connect(function()
	minimized = not minimized
	body.Visible = not minimized
	win.Size = UDim2.fromOffset(WIN_W, minimized and BAR_H or WIN_H)
end)

local openBtn = new("TextButton", {
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -10, 1, -10),
	Size = UDim2.fromOffset(72, 30),
	BackgroundColor3 = C.win,
	BorderSizePixel = 0,
	Text = "MENU",
	Font = FONT,
	TextSize = 14,
	TextColor3 = C.acc,
	Visible = false,
}, gui)
stroke(openBtn, C.black, 2)

local function setHidden(h)
	win.Visible = not h
	openBtn.Visible = h
end
closeBtn.Activated:Connect(function() setHidden(true) end)
openBtn.Activated:Connect(function() setHidden(false) end)
UIS.InputBegan:Connect(function(i)
	if i.KeyCode == Enum.KeyCode.Insert then
		setHidden(win.Visible)
	end
end)

--------------------------------------------------------------------
selectTab("Player")
log("HappyMid v1.3 loaded.", "inf")
log("Insert = hide / show menu.", "inf")
