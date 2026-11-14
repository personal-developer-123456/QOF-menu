--[[
	PRECISE MOVEMENT PAD
	Put this in a LocalScript (StarterPlayer > StarterPlayerScripts).

	LEFT   : D-pad. WALKS you (no teleporting) relative to the way you're facing.
	RIGHT  : Smoothly turn left / turn right.
	TOP    : Two increment boxes. MOVE = studs per press, TURN = degrees per press.
	BOTTOM : The bar in the middle toggles everything on/off like the FNAF monitor.
	TIP    : Hold a button to keep going. Hold a D-pad button AND a turn button together to curve.
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

local MIN_STEP_TIME = 0.1         -- every step lasts at least this long (lower = faster tiny steps)
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
local EPS = 1e-6

-- One "channel" per button.
--   held = finger/mouse is down on it
--   left = how much of the current step (studs or radians) is still committed.
-- A tap commits exactly one increment. Holding keeps starting the next increment
-- the instant the last one ends, so there are no gaps or stops.
local function newChannel()
	return { held = false, left = 0 }
end

local ch = {
	fwd = newChannel(),
	back = newChannel(),
	strafeL = newChannel(),
	strafeR = newChannel(),
	turnL = newChannel(),
	turnR = newChannel(),
}

local function getMoveStep()
	return moveStep
end

local function getTurnStep()
	return math.rad(turnStep)
end

local function isActive(c)
	return c.held or c.left > EPS
end

-- how hard this channel pushes this frame (0..1); eases off on the last frame of a step
local function power(c, travel)
	if c.held then
		return 1
	end
	if c.left > EPS then
		return math.min(1, c.left / travel)
	end
	return 0
end

local function consume(c, used, stepSize)
	c.left = c.left - used
	while c.held and c.left <= EPS do
		c.left = c.left + stepSize -- chain straight into the next step
	end
	if not c.held and c.left < EPS then
		c.left = 0
	end
end

local function releaseAll()
	for _, c in pairs(ch) do
		c.held = false
	end
end

local function getParts()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if hum and root and hum.Health > 0 and hum.SeatPart == nil then
		return hum, root
	end
	return nil, nil
end

local saved = nil -- { hum, speed, rotate } while we're driving the character
local moving = false

local function disengage()
	if not saved then
		return
	end
	local hum = saved.hum
	if moving then
		hum:Move(Vector3.zero, false)
	end
	hum.WalkSpeed = saved.speed
	hum.AutoRotate = saved.rotate
	saved = nil
	moving = false
end

-- Runs every frame, right AFTER Roblox's own controls so they can't cancel us.
local function update(dt)
	local hum, root = getParts()
	if not hum then
		saved = nil
		moving = false
		for _, c in pairs(ch) do
			c.left = 0
		end
		return
	end
	if saved and saved.hum ~= hum then
		saved = nil
		moving = false
	end

	local wantMove = isActive(ch.fwd) or isActive(ch.back) or isActive(ch.strafeL) or isActive(ch.strafeR)
	local wantTurn = isActive(ch.turnL) or isActive(ch.turnR)
	if not (wantMove or wantTurn) then
		disengage()
		return
	end

	if not saved then
		saved = { hum = hum, speed = hum.WalkSpeed, rotate = hum.AutoRotate }
		hum.AutoRotate = false -- stops Roblox from spinning you toward your walking direction
	end

	---------------- TURN ----------------
	if wantTurn then
		local stepRad = math.rad(turnStep)
		local stepTime = math.max(turnStep / TURN_SPEED, MIN_STEP_TIME)
		local travel = (stepRad / stepTime) * dt

		local pL = power(ch.turnL, travel)
		local pR = power(ch.turnR, travel)
		consume(ch.turnL, pL * travel, stepRad)
		consume(ch.turnR, pR * travel, stepRad)

		local delta = (pL - pR) * travel
		if delta ~= 0 then
			root.CFrame = root.CFrame * CFrame.Angles(0, delta, 0)
		end
	end

	---------------- MOVE ----------------
	local movingNow = false
	if wantMove then
		if saved.speed <= 0 then
			-- the game froze your walkspeed, so don't fight it
			ch.fwd.left, ch.back.left, ch.strafeL.left, ch.strafeR.left = 0, 0, 0, 0
		else
			local stepTime = math.max(moveStep / saved.speed, MIN_STEP_TIME)
			local speed = moveStep / stepTime -- tiny steps walk slowly, big steps walk at your normal speed
			local travel = speed * dt

			local pF = power(ch.fwd, travel)
			local pB = power(ch.back, travel)
			local pL = power(ch.strafeL, travel)
			local pR = power(ch.strafeR, travel)

			local vx, vz = pR - pL, pB - pF
			local mag = math.sqrt(vx * vx + vz * vz)
			local s = (mag > 1) and (1 / mag) or 1 -- diagonals aren't faster

			consume(ch.fwd, pF * s * travel, moveStep)
			consume(ch.back, pB * s * travel, moveStep)
			consume(ch.strafeL, pL * s * travel, moveStep)
			consume(ch.strafeR, pR * s * travel, moveStep)

			if mag > 0.0001 then
				-- direction is re-read every frame, so turning while walking makes you curve
				local cf = root.CFrame
				local right = Vector3.new(cf.RightVector.X, 0, cf.RightVector.Z)
				local back = Vector3.new(-cf.LookVector.X, 0, -cf.LookVector.Z)
				if right.Magnitude > 0.01 and back.Magnitude > 0.01 then
					local dir = right.Unit * (vx * s) + back.Unit * (vz * s)
					hum.WalkSpeed = speed
					hum:Move(dir, false)
					movingNow = true
				end
			end
		end
	end

	if movingNow then
		moving = true
	elseif moving then
		hum:Move(Vector3.zero, false)
		hum.WalkSpeed = saved.speed
		moving = false
	end
end

-- Each button gets its own channel, and every touch is tracked separately, so you can
-- hold a D-pad button and a turn button at the same time.
local function bindChannel(button, chan, getStep)
	button.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then
			return
		end

		chan.held = true
		chan.left = chan.left + getStep() -- every tap = one full increment

		local conn
		conn = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				chan.held = false
				conn:Disconnect()
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

gui.Destroying:Connect(function()
	pcall(function()
		RunService:UnbindFromRenderStep(BIND_NAME)
	end)
	disengage()
end)

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

bindChannel(upBtn,    ch.fwd,     getMoveStep)
bindChannel(downBtn,  ch.back,    getMoveStep)
bindChannel(leftBtn,  ch.strafeL, getMoveStep)
bindChannel(rightBtn, ch.strafeR, getMoveStep)

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

bindChannel(turnLeftBtn,  ch.turnL, getTurnStep)
bindChannel(turnRightBtn, ch.turnR, getTurnStep)

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
	if not open then
		releaseAll()
	end

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

-- start the movement loop (unbind first in case the script is run twice)
pcall(function()
	RunService:UnbindFromRenderStep(BIND_NAME)
end)
RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Input.Value + 1, update)
