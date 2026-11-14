--[[
	PRECISE MOVEMENT PAD
	Put this in a LocalScript (StarterPlayer > StarterPlayerScripts).

	LEFT   : D-pad. WALKS you (no teleporting) relative to the way you're facing.
	RIGHT  : Smoothly turn left / turn right.
	TOP    : Two increment boxes. MOVE = studs per press, TURN = degrees per press.
	BOTTOM : The bar in the middle toggles everything on/off like the FNAF monitor.
	TIP    : Hold any button to repeat.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

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
local MIN_STEP_TIME = 0.15        -- every step lasts at least this long (tiny steps = slow, exact creep)
local TURN_SPEED = 360            -- degrees per second for big turns

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

local BIND_NAME = "PreciseMovementStep"
local busy = false -- one step at a time

local function getParts()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if hum and root and hum.Health > 0 then
		return hum, root
	end
	return nil, nil
end

-- Runs stepFn(dt) every frame (right AFTER Roblox's own controls, so they can't
-- cancel us) until it returns true.
local function runUntilDone(stepFn)
	local done = false
	RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Input.Value + 1, function(dt)
		if done then
			return
		end
		local ok, finished = pcall(stepFn, dt)
		if not ok or finished then
			done = true
		end
	end)
	while not done do
		task.wait()
	end
	RunService:UnbindFromRenderStep(BIND_NAME)
end

-- Walk moveStep studs. x: +right / -left, z: +back / -forward (relative to where you face)
local function move(x, z)
	if busy then
		return
	end
	local hum, root = getParts()
	if not hum or hum.WalkSpeed <= 0 then
		return
	end

	local look = root.CFrame:VectorToWorldSpace(Vector3.new(x, 0, z))
	local dir = Vector3.new(look.X, 0, look.Z)
	if dir.Magnitude < 0.01 then
		return
	end
	dir = dir.Unit

	busy = true

	local dist = moveStep
	local origin = root.Position
	local oldSpeed, oldRotate = hum.WalkSpeed, hum.AutoRotate

	-- Tiny steps would finish in less than one frame at full speed, so slow the walk
	-- down for the duration of the step. Big steps still walk at your normal speed.
	local duration = math.max(dist / oldSpeed, MIN_STEP_TIME)
	local speed = dist / duration
	local timeout = duration * 2 + 0.5
	local elapsed = 0

	hum.WalkSpeed = speed
	hum.AutoRotate = false -- keeps you facing the same way while strafing/backing up

	runUntilDone(function(dt)
		if hum.Health <= 0 or not root.Parent then
			return true
		end
		elapsed = elapsed + dt
		local remaining = dist - (root.Position - origin):Dot(dir)
		if remaining <= 0.002 or elapsed > timeout then -- done, or you hit a wall
			return true
		end
		-- ease off on the last frame so you stop right on the mark
		local power = math.clamp(remaining / (speed * dt), 0.1, 1)
		hum:Move(dir * power, false)
		return false
	end)

	hum:Move(Vector3.zero, false)
	hum.WalkSpeed = oldSpeed
	hum.AutoRotate = oldRotate
	busy = false
end

-- Smoothly turn turnStep degrees. dir: +1 = left (counter-clockwise), -1 = right
local function turn(dir)
	if busy then
		return
	end
	local hum, root = getParts()
	if not hum then
		return
	end

	busy = true

	local oldRotate = hum.AutoRotate
	hum.AutoRotate = false

	local remaining = math.rad(turnStep) * dir
	local duration = math.max(turnStep / TURN_SPEED, MIN_STEP_TIME)
	local rate = remaining / duration

	runUntilDone(function(dt)
		if hum.Health <= 0 or not root.Parent then
			return true
		end
		local delta = rate * dt
		if math.abs(delta) >= math.abs(remaining) then
			delta = remaining
		end
		root.CFrame = root.CFrame * CFrame.Angles(0, delta, 0)
		remaining = remaining - delta
		return math.abs(remaining) < 1e-4
	end)

	hum.AutoRotate = oldRotate
	busy = false
end

-- Press once to act, hold to keep acting (steps chain back to back)
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

		task.spawn(function()
			action()
			local t0 = os.clock()
			while held and os.clock() - t0 < HOLD_DELAY do
				task.wait()
			end
			while held do
				action()
				task.wait()
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
