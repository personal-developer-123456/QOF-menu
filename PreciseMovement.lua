--[[
	PRECISE MOVEMENT PAD
	Put this in a LocalScript (StarterPlayer > StarterPlayerScripts).

	LEFT   : D-pad. Moves you relative to the way you're facing.
	RIGHT  : Turn left / turn right.
	TOP    : Two increment boxes. MOVE = studs per press, TURN = degrees per press.
	BOTTOM : The bar in the middle toggles everything on/off like the FNAF monitor.
	TIP    : Hold any button to repeat.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

---------------------------------------------------------------------
-- CONFIG
---------------------------------------------------------------------
local DEFAULT_MOVE = 0.1          -- studs per press
local DEFAULT_TURN = 5            -- degrees per press
local MIN_MOVE, MAX_MOVE = 0.01, 50
local MIN_TURN, MAX_TURN = 0.1, 180

local HOLD_DELAY = 0.4            -- seconds before hold-repeat kicks in
local HOLD_RATE = 0.07            -- seconds between repeats while holding

local START_OPEN = true           -- start with the pad showing?
local HOVER_TO_TOGGLE = false     -- true = toggle when the mouse touches the bar (FNAF style, PC only)
local SLIDE_TIME = 0.35

local ROTATE_RIGHT_MARGIN = 130   -- gap from right edge (raise if it overlaps the jump button)

local PANEL_COLOR = Color3.fromRGB(35, 35, 40)
local OUTLINE_COLOR = Color3.fromRGB(255, 255, 255)

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

local function fmt(n)
	return string.format("%g", n)
end

local function makeButton(parent, text, size, pos, anchor)
	local b = make("TextButton", {
		Text = text,
		Font = Enum.Font.GothamBold,
		TextSize = 30,
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundColor3 = PANEL_COLOR,
		BackgroundTransparency = 0.15,
		AutoButtonColor = true,
		Size = size,
		Position = pos,
		AnchorPoint = anchor or Vector2.new(0.5, 0.5),
	}, parent)
	make("UICorner", { CornerRadius = UDim.new(0, 12) }, b)
	make("UIStroke", {
		Color = OUTLINE_COLOR,
		Transparency = 0.6,
		Thickness = 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, b)
	return b
end

---------------------------------------------------------------------
-- MOVEMENT
---------------------------------------------------------------------
local moveStep = DEFAULT_MOVE
local turnStep = DEFAULT_TURN

local function getCharacter()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		return char
	end
	return nil
end

local function nudge(offset)
	local char = getCharacter()
	if char then
		char:PivotTo(char:GetPivot() * offset)
	end
end

-- x: +right / -left, z: +back / -forward (relative to where you face)
local function move(x, z)
	nudge(CFrame.new(x * moveStep, 0, z * moveStep))
end

-- dir: +1 = turn left (counter-clockwise), -1 = turn right
local function turn(dir)
	nudge(CFrame.Angles(0, math.rad(turnStep * dir), 0))
end

-- Press once to act, hold to keep acting
local function bindHold(button, action)
	button.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then
			return
		end

		local held = true
		local conn
		conn = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				held = false
				conn:Disconnect()
			end
		end)

		action()

		task.spawn(function()
			task.wait(HOLD_DELAY)
			while held do
				action()
				task.wait(HOLD_RATE)
			end
		end)
	end)
end

---------------------------------------------------------------------
-- GUI
---------------------------------------------------------------------
local old = playerGui:FindFirstChild("PreciseMovement")
if old then
	old:Destroy()
end

local gui = make("ScreenGui", {
	Name = "PreciseMovement",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 10,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)

local groups = {} -- { frame, shown, hidden }

local function addGroup(frame, shown, hidden)
	table.insert(groups, { frame = frame, shown = shown, hidden = hidden })
end

---------------- TOP: increment boxes ----------------
local topGroup = make("Frame", {
	Name = "Increment",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0),
	Size = UDim2.new(0, 280, 0, 70),
}, gui)
addGroup(topGroup, UDim2.new(0.5, 0, 0, 10), UDim2.new(0.5, 0, 0, -90))

local function makeIncrementBox(labelText, xScale, xOffset)
	make("TextLabel", {
		Text = labelText,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.5,
		BackgroundTransparency = 1,
		Size = UDim2.new(0.5, -4, 0, 18),
		Position = UDim2.new(xScale, xOffset, 0, 0),
	}, topGroup)

	local box = make("TextBox", {
		Font = Enum.Font.GothamBold,
		TextSize = 24,
		TextColor3 = Color3.new(1, 1, 1),
		PlaceholderText = "0",
		ClearTextOnFocus = false,
		BackgroundColor3 = PANEL_COLOR,
		BackgroundTransparency = 0.15,
		Size = UDim2.new(0.5, -4, 0, 44),
		Position = UDim2.new(xScale, xOffset, 0, 22),
	}, topGroup)
	make("UICorner", { CornerRadius = UDim.new(0, 10) }, box)
	make("UIStroke", {
		Color = OUTLINE_COLOR,
		Transparency = 0.6,
		Thickness = 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, box)
	return box
end

local function bindBox(box, get, set, min, max)
	box.Text = fmt(get())
	box.FocusLost:Connect(function()
		local n = tonumber(box.Text)
		if n then
			set(math.clamp(n, min, max))
		end
		box.Text = fmt(get()) -- snaps back to the real value if input was invalid
	end)
end

local moveBox = makeIncrementBox("MOVE (studs)", 0, 0)
local turnBox = makeIncrementBox("TURN (degrees)", 0.5, 4)

bindBox(moveBox, function() return moveStep end, function(v) moveStep = v end, MIN_MOVE, MAX_MOVE)
bindBox(turnBox, function() return turnStep end, function(v) turnStep = v end, MIN_TURN, MAX_TURN)

---------------- LEFT: D-pad ----------------
local dpad = make("Frame", {
	Name = "DPad",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0, 1),
	Size = UDim2.new(0, 180, 0, 180),
}, gui)
addGroup(dpad, UDim2.new(0, 20, 1, -40), UDim2.new(0, 20, 1, 220))

local BTN = UDim2.new(0, 56, 0, 56)
local upBtn    = makeButton(dpad, "▲", BTN, UDim2.new(0, 90, 0, 30))
local downBtn  = makeButton(dpad, "▼", BTN, UDim2.new(0, 90, 0, 150))
local leftBtn  = makeButton(dpad, "◀", BTN, UDim2.new(0, 30, 0, 90))
local rightBtn = makeButton(dpad, "▶", BTN, UDim2.new(0, 150, 0, 90))

bindHold(upBtn,    function() move(0, -1) end)
bindHold(downBtn,  function() move(0, 1) end)
bindHold(leftBtn,  function() move(-1, 0) end)
bindHold(rightBtn, function() move(1, 0) end)

---------------- RIGHT: change direction ----------------
local rot = make("Frame", {
	Name = "Rotate",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1, 1),
	Size = UDim2.new(0, 150, 0, 70),
}, gui)
addGroup(rot, UDim2.new(1, -ROTATE_RIGHT_MARGIN, 1, -40), UDim2.new(1, -ROTATE_RIGHT_MARGIN, 1, 200))

local ROT_BTN = UDim2.new(0, 68, 0, 68)
local turnLeftBtn  = makeButton(rot, "↺", ROT_BTN, UDim2.new(0, 0, 0.5, 0), Vector2.new(0, 0.5))
local turnRightBtn = makeButton(rot, "↻", ROT_BTN, UDim2.new(1, 0, 0.5, 0), Vector2.new(1, 0.5))

bindHold(turnLeftBtn,  function() turn(1) end)
bindHold(turnRightBtn, function() turn(-1) end)

---------------- BOTTOM MIDDLE: FNAF-style toggle bar ----------------
local toggleBtn = make("TextButton", {
	Name = "Toggle",
	Text = "▼",
	Font = Enum.Font.GothamBold,
	TextSize = 18,
	TextColor3 = Color3.new(1, 1, 1),
	BackgroundColor3 = PANEL_COLOR,
	BackgroundTransparency = 0.1,
	AutoButtonColor = true,
	AnchorPoint = Vector2.new(0.5, 1),
	Size = UDim2.new(0, 170, 0, 34),
	Position = UDim2.new(0.5, 0, 1, 8), -- bottom 8px tucked off-screen so only the top is rounded
	ZIndex = 5,
}, gui)
make("UICorner", { CornerRadius = UDim.new(0, 10) }, toggleBtn)
make("UIStroke", {
	Color = OUTLINE_COLOR,
	Transparency = 0.5,
	Thickness = 2,
	ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
}, toggleBtn)

local isOpen = START_OPEN
local lastToggle = 0

local function setOpen(open, instant)
	isOpen = open
	toggleBtn.Text = open and "▼" or "▲"

	local info = TweenInfo.new(
		SLIDE_TIME,
		Enum.EasingStyle.Quint,
		open and Enum.EasingDirection.Out or Enum.EasingDirection.In
	)
	for _, g in ipairs(groups) do
		local target = open and g.shown or g.hidden
		if instant then
			g.frame.Position = target
		else
			TweenService:Create(g.frame, info, { Position = target }):Play()
		end
	end
end

local function toggle()
	lastToggle = os.clock()
	setOpen(not isOpen)
end

toggleBtn.Activated:Connect(toggle)

if HOVER_TO_TOGGLE then
	toggleBtn.MouseEnter:Connect(function()
		if os.clock() - lastToggle > 0.6 then
			toggle()
		end
	end)
end

setOpen(START_OPEN, true)
