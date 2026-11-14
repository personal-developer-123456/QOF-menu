--[[
	HEADING SNAP
	Put this in a LocalScript (StarterPlayer > StarterPlayerScripts).

	CLOSED : a tiny pill that shows which way you're facing, live, to two decimals.
	OPEN   : tap the pill and it expands: type a degree in the box, hit SNAP (or Enter)
	         and your character instantly turns to face it.
	DRAG   : press and drag the pill to move it anywhere on screen.

	DEGREES: 0.00 = facing the default forward direction (-Z), going clockwise.
	         90.00 = right, 180.00 = backwards, 270.00 = left.
	         You can type negatives or anything over 360 too (-90 = 270, 450 = 90).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

---------------------------------------------------------------------
-- CONFIG
---------------------------------------------------------------------
local START_OPEN = false                      -- start expanded?
local DEFAULT_POSITION = UDim2.new(0.5, 160, 0, 10) -- where it starts (drag it anywhere after)

local WIDTH = 112
local HEADER_H = 30                           -- height of the closed pill
local OPEN_H = 108                            -- height when expanded
local TWEEN_TIME = 0.2
local DRAG_THRESHOLD = 8                      -- pixels you have to move before a press counts as a drag

local PANEL_COLOR = Color3.fromRGB(35, 35, 40)
local OUTLINE_COLOR = Color3.fromRGB(255, 255, 255)
local ACCENT_COLOR = Color3.fromRGB(0, 120, 215)
local ERROR_COLOR = Color3.fromRGB(255, 70, 70)

---------------------------------------------------------------------
-- HELPERS
---------------------------------------------------------------------
local function make(class, props, parent)
	local inst = Instance.new(class)
	for k, v in pairs(props) do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

-- current heading in degrees (0 <= h < 360), rounded to 2 decimals. nil = no character
local function getHeading()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local look = root.CFrame.LookVector
	local h = math.deg(math.atan2(look.X, -look.Z)) % 360
	local r = math.floor(h * 100 + 0.5) / 100
	if r >= 360 then
		r = 0
	end
	return r
end

local function snapTo(deg)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not (hum and root and hum.Health > 0) then
		return false
	end
	local rad = math.rad(deg)
	local dir = Vector3.new(math.sin(rad), 0, -math.cos(rad))
	local pos = root.Position
	root.CFrame = CFrame.lookAt(pos, pos + dir) -- same spot, new facing
	root.AssemblyAngularVelocity = Vector3.zero
	return true
end

local function parseDegrees(text)
	text = text:gsub("°", "")
	text = text:gsub("%s", "")
	text = text:gsub(",", ".")
	local n = tonumber(text)
	if not n or n ~= n or math.abs(n) == math.huge then
		return nil
	end
	return n % 360
end

---------------------------------------------------------------------
-- GUI
---------------------------------------------------------------------
local old = playerGui:FindFirstChild("HeadingSnap")
if old then
	old:Destroy()
end

local gui = make("ScreenGui", {
	Name = "HeadingSnap",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 11,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)

local widget = make("Frame", {
	Name = "Widget",
	BackgroundColor3 = PANEL_COLOR,
	BackgroundTransparency = 0.1,
	ClipsDescendants = true,
	Position = DEFAULT_POSITION,
	Size = UDim2.new(0, WIDTH, 0, START_OPEN and OPEN_H or HEADER_H),
}, gui)
make("UICorner", { CornerRadius = UDim.new(0, 10) }, widget)
make("UIStroke", {
	Color = OUTLINE_COLOR,
	Transparency = 0.55,
	Thickness = 2,
	ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
}, widget)

-- Top: live degrees. Tap = open/close, press-and-drag = move.
local header = make("TextButton", {
	Name = "Header",
	Text = "--.--°",
	Font = Enum.Font.GothamBold,
	TextSize = 18,
	TextColor3 = Color3.new(1, 1, 1),
	AutoButtonColor = false,
	BackgroundTransparency = 1,
	Size = UDim2.new(1, 0, 0, HEADER_H),
}, widget)

local chevron = make("TextLabel", {
	Text = START_OPEN and "▲" or "▼",
	Font = Enum.Font.GothamBold,
	TextSize = 10,
	TextColor3 = Color3.fromRGB(200, 200, 200),
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -6, 0.5, 0),
	Size = UDim2.new(0, 12, 0, 12),
}, header)

-- Body: input box + Snap button
local body = make("Frame", {
	Name = "Body",
	BackgroundTransparency = 1,
	Visible = START_OPEN,
	Position = UDim2.new(0, 0, 0, HEADER_H),
	Size = UDim2.new(1, 0, 0, OPEN_H - HEADER_H),
}, widget)

local box = make("TextBox", {
	Name = "DegreeBox",
	Text = "",
	PlaceholderText = "degrees",
	PlaceholderColor3 = Color3.fromRGB(140, 140, 140),
	Font = Enum.Font.GothamBold,
	TextSize = 16,
	TextColor3 = Color3.new(1, 1, 1),
	ClearTextOnFocus = false, -- tapping the box keeps what is in it, so you can fine-tune it
	BackgroundColor3 = Color3.fromRGB(15, 15, 18),
	Position = UDim2.new(0, 6, 0, 0),
	Size = UDim2.new(1, -12, 0, 30),
}, body)
make("UICorner", { CornerRadius = UDim.new(0, 8) }, box)
local boxStroke = make("UIStroke", {
	Color = OUTLINE_COLOR,
	Transparency = 0.6,
	Thickness = 1.5,
	ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
}, box)

local snapBtn = make("TextButton", {
	Name = "Snap",
	Text = "Snap",
	Font = Enum.Font.GothamBold,
	TextSize = 16,
	TextColor3 = Color3.new(1, 1, 1),
	BackgroundColor3 = ACCENT_COLOR,
	AutoButtonColor = true,
	Position = UDim2.new(0, 6, 0, 36),
	Size = UDim2.new(1, -12, 0, 30),
}, body)
make("UICorner", { CornerRadius = UDim.new(0, 8) }, snapBtn)

---------------------------------------------------------------------
-- OPEN / CLOSE
---------------------------------------------------------------------
local isOpen = START_OPEN

-- put your current heading in the box so it's never blank, and you can just tweak it
local function fillBoxWithHeading()
	local h = getHeading()
	if h then
		box.Text = string.format("%.2f", h)
	end
end

local function setOpen(open)
	isOpen = open
	chevron.Text = open and "▲" or "▼"
	if open then
		fillBoxWithHeading()
		body.Visible = true
	else
		box:ReleaseFocus()
		body.Visible = false
	end
	TweenService:Create(
		widget,
		TweenInfo.new(TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = UDim2.new(0, WIDTH, 0, open and OPEN_H or HEADER_H) }
	):Play()
end

---------------------------------------------------------------------
-- TAP TO TOGGLE / DRAG TO MOVE
---------------------------------------------------------------------
local dragging = false
local dragInput, dragStart, startPos, moved

header.InputBegan:Connect(function(input)
	local t = input.UserInputType
	if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then
		return
	end
	if dragging then
		return
	end

	dragging = true
	moved = false
	dragInput = input
	dragStart = input.Position
	startPos = widget.AbsolutePosition

	local conn
	conn = input.Changed:Connect(function()
		if input.UserInputState == Enum.UserInputState.End then
			conn:Disconnect()
			dragging = false
			if not moved then
				setOpen(not isOpen) -- it was a tap, not a drag
			end
		end
	end)
end)

UserInputService.InputChanged:Connect(function(input)
	if not dragging then
		return
	end
	if input ~= dragInput and input.UserInputType ~= Enum.UserInputType.MouseMovement then
		return
	end

	local delta = input.Position - dragStart
	if delta.Magnitude > DRAG_THRESHOLD then
		moved = true
	end
	if moved then
		local screen = gui.AbsoluteSize
		local size = widget.AbsoluteSize
		local x = math.clamp(startPos.X + delta.X, 0, math.max(0, screen.X - size.X))
		local y = math.clamp(startPos.Y + delta.Y, 0, math.max(0, screen.Y - size.Y))
		widget.Position = UDim2.fromOffset(x, y)
	end
end)

---------------------------------------------------------------------
-- SNAP
---------------------------------------------------------------------
local function flashError()
	boxStroke.Color = ERROR_COLOR
	boxStroke.Transparency = 0
	TweenService:Create(boxStroke, TweenInfo.new(0.5), {
		Color = OUTLINE_COLOR,
		Transparency = 0.6,
	}):Play()
end

local function trySnap()
	local deg = parseDegrees(box.Text)
	if deg and snapTo(deg) then
		box.Text = string.format("%.2f", deg)
	else
		flashError() -- not a number, or no character to turn
	end
end

snapBtn.Activated:Connect(function()
	box:ReleaseFocus()
	trySnap()
end)
box.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		trySnap()
	end
end)

---------------------------------------------------------------------
-- LIVE READOUT
---------------------------------------------------------------------
local lastText = ""
local readout = RunService.RenderStepped:Connect(function()
	local h = getHeading()
	local text = h and string.format("%.2f°", h) or "--.--°"
	if text ~= lastText then
		lastText = text
		header.Text = text
	end
end)

gui.Destroying:Connect(function()
	readout:Disconnect()
end)

if START_OPEN then
	task.defer(fillBoxWithHeading)
end
