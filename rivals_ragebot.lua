--[[
    MATCHA RAGEBOT v7 — RIVALS (FFA) — FULL FEATURED
    PlaceId: 17625359962 | Nosniy Games
    
    One-liner:
    loadstring(game:HttpGet("https://raw.githubusercontent.com/yoh4424-cell/matcharagebotrivals/main/rivals_ragebot.lua"))()
    
    F2 = open/close settings GUI
    F8 = fully stop & destroy script
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("RunService")
local LP = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local ALIVE = true
local connections = {}
local drawings = {}

local function TrackConn(c) table.insert(connections, c) end
local function TrackDraw(d) table.insert(drawings, d) return d end

-- ══════════════════════════════════════════════════════════════
-- CONFIG (all changeable in GUI)
-- ══════════════════════════════════════════════════════════════
local CFG = {
    -- Combat
    fireDelay   = 0.08,
    maxDist     = 3500,
    -- Movement
    flySpeed    = 6.0,
    keepDist    = 2.5,
    heightOff   = 1.2,
    evasionOn   = true,
    evRadius    = 3.5,
    evSpeed     = 12.0,
    evJitter    = 1.2,
    -- Safety
    voidProtect = true,
    voidY       = -30,
    safeSpotY   = 200,
    safeSpotX   = 0,
    safeSpotZ   = 0,
    -- Visuals
    espOn       = true,
    crosshairOn = true,
    rainbowSpeed = 3.0,
    crossSize   = 12,
    -- Keybinds
    keyToggle   = 0x78,  -- F2 = GUI
    keyDestroy  = 0x77,  -- F8 = destroy
}

-- ══════════════════════════════════════════════════════════════
-- HELPERS
-- ══════════════════════════════════════════════════════════════
local function Root(c)
    if not c then return nil end
    local ok, r = pcall(function() return c:FindFirstChild("HumanoidRootPart") end)
    return ok and r or nil
end

local function Hum(c)
    if not c then return nil end
    local ok, h = pcall(function() return c:FindFirstChildOfClass("Humanoid") end)
    return ok and h or nil
end

local function Part(c)
    if not c then return nil end
    for _, n in ipairs({"Head", "HumanoidRootPart", "UpperTorso", "Torso"}) do
        local ok, p = pcall(function() return c:FindFirstChild(n) end)
        if ok and p and p.Position then return p end
    end
    return nil
end

local function Alive(plr)
    if plr == LP then return false end
    local ok1, c = pcall(function() return plr.Character end)
    if not ok1 or not c then return false end
    local h = Hum(c)
    if h then
        local ok2, hp = pcall(function() return h.Health end)
        if ok2 and hp and hp <= 0 then return false end
    end
    local r = Root(c)
    if not r then return false end
    local ok3, pos = pcall(function() return r.Position end)
    return ok3 and pos ~= nil
end

local function Nearest(pos)
    local best, bestP, bestD = nil, nil, CFG.maxDist
    for _, plr in ipairs(Players:GetPlayers()) do
        local ok, alive = pcall(function() return Alive(plr) end)
        if ok and alive then
            local p = Part(plr.Character)
            if p then
                local ok2, pp = pcall(function() return p.Position end)
                if ok2 and pp then
                    local d = (pp - pos).Magnitude
                    if d < bestD then
                        bestD = d
                        best = plr
                        bestP = p
                    end
                end
            end
        end
    end
    return best, bestP, bestD
end

local function SafeSpot()
    local myRoot = Root(LP.Character)
    local x = CFG.safeSpotX
    local z = CFG.safeSpotZ
    if myRoot then
        local ok, pos = pcall(function() return myRoot.Position end)
        if ok and pos then
            x = pos.X + 50
            z = pos.Z + 50
            CFG.safeSpotX = x
            CFG.safeSpotZ = z
        end
    end
    return Vector3.new(x, CFG.safeSpotY, z)
end

-- ══════════════════════════════════════════════════════════════
-- DESTROY EVERYTHING
-- ══════════════════════════════════════════════════════════════
local function FullDestroy()
    ALIVE = false
    for _, c in ipairs(connections) do
        pcall(function() c:Disconnect() end)
    end
    for _, d in ipairs(drawings) do
        pcall(function() d:Remove() end)
    end
    connections = {}
    drawings = {}
    print("[ragebot] DESTROYED — all objects removed")
end

-- ══════════════════════════════════════════════════════════════
-- ESP: box + name + HP + line
-- ══════════════════════════════════════════════════════════════
local espBox = TrackDraw(Drawing.new("Square"))
espBox.Filled = false
espBox.Thickness = 2
espBox.Visible = false

local espName = TrackDraw(Drawing.new("Text"))
espName.Size = 14
espName.Font = Drawing.Fonts.Monospace
espName.Center = true
espName.Outline = true
espName.Visible = false

local espHP = TrackDraw(Drawing.new("Text"))
espHP.Size = 12
espHP.Font = Drawing.Fonts.Monospace
espHP.Center = true
espHP.Outline = true
espHP.Visible = false

local espLine = TrackDraw(Drawing.new("Line"))
espLine.Thickness = 1
espLine.Visible = false

local curTarget = nil

local function UpdateESP()
    if not CFG.espOn or not curTarget or not Alive(curTarget) then
        espBox.Visible = false
        espName.Visible = false
        espHP.Visible = false
        espLine.Visible = false
        return
    end
    local cam = Camera
    local myRoot = Root(LP.Character)
    if not cam or not myRoot then
        espBox.Visible = false; espName.Visible = false; espHP.Visible = false; espLine.Visible = false
        return
    end
    local char = curTarget.Character
    if not char then
        espBox.Visible = false; espName.Visible = false; espHP.Visible = false; espLine.Visible = false
        return
    end
    local hrp = Root(char)
    if not hrp then
        espBox.Visible = false; espName.Visible = false; espHP.Visible = false; espLine.Visible = false
        return
    end
    local ok, tPos = pcall(function() return hrp.Position end)
    if not ok or not tPos then
        espBox.Visible = false; espName.Visible = false; espHP.Visible = false; espLine.Visible = false
        return
    end
    local screenPos, onScreen = WorldToScreen(tPos)
    if not onScreen then
        espBox.Visible = false; espName.Visible = false; espHP.Visible = false; espLine.Visible = false
        return
    end
    local headPart = char:FindFirstChild("Head")
    local headY = screenPos.Y
    if headPart and headPart.Position then
        local hs = WorldToScreen(headPart.Position + Vector3.new(0, 1.5, 0))
        headY = hs.Y
    end
    local feetS = WorldToScreen(tPos - Vector3.new(0, 3, 0))
    local boxH = math.abs(feetS.Y - headY)
    local boxW = boxH * 0.6

    espBox.Position = Vector2.new(screenPos.X - boxW / 2, headY)
    espBox.Size = Vector2.new(boxW, boxH)
    espBox.Color = Color3.new(1, 0, 0)
    espBox.Visible = true

    espName.Position = Vector2.new(screenPos.X, headY - 16)
    espName.Text = curTarget.Name
    espName.Color = Color3.new(1, 1, 1)
    espName.Visible = true

    local hum = Hum(char)
    local hp, mh = 100, 100
    if hum then
        pcall(function() hp = hum.Health end)
        pcall(function() mh = hum.MaxHealth end)
    end
    local pct = math.clamp(hp / mh, 0, 1)
    espHP.Position = Vector2.new(screenPos.X, feetS.Y + 4)
    espHP.Text = math.floor(hp) .. "/" .. math.floor(mh)
    espHP.Color = Color3.new(1 - pct, pct, 0)
    espHP.Visible = true

    local vp = cam.ViewportSize
    espLine.From = Vector2.new(vp.X / 2, vp.Y / 2)
    espLine.To = screenPos
    espLine.Color = Color3.new(1, 0, 0)
    espLine.Visible = true
end

-- ══════════════════════════════════════════════════════════════
-- HUD: status bar
-- ══════════════════════════════════════════════════════════════
local hud1 = TrackDraw(Drawing.new("Text"))
hud1.Position = Vector2.new(20, 10)
hud1.Size = 16
hud1.Font = Drawing.Fonts.Monospace
hud1.Outline = true
hud1.Visible = true

local hud2 = TrackDraw(Drawing.new("Text"))
hud2.Position = Vector2.new(20, 30)
hud2.Size = 13
hud2.Font = Drawing.Fonts.Monospace
hud2.Outline = true
hud2.Visible = true

local hud3 = TrackDraw(Drawing.new("Text"))
hud3.Position = Vector2.new(20, 48)
hud3.Size = 12
hud3.Font = Drawing.Fonts.Monospace
hud3.Outline = true
hud3.Visible = true

local function UpdateHUD()
    local myHP, myMax = "?", "?"
    local h = Hum(LP.Character)
    if h then
        pcall(function() myHP = math.floor(h.Health) end)
        pcall(function() myMax = math.floor(h.MaxHealth) end)
    end
    hud1.Text = "[ RIVALS RAGEBOT ]  F2=menu  F8=destroy"
    hud1.Color = Color3.fromHSV(tick() * 0.1 % 1, 1, 1)

    if curTarget and Alive(curTarget) then
        local n = ""
        pcall(function() n = curTarget.Name end)
        local d = 0
        local mr = Root(LP.Character)
        local ok, pp = pcall(function() return Part(curTarget.Character) end)
        if ok and pp and pp.Position and mr then
            d = math.floor((pp.Position - mr.Position).Magnitude)
        end
        hud2.Text = "Target: " .. n .. " [" .. d .. "m]"
        hud2.Color = Color3.new(1, 1, 0)
    else
        hud2.Text = "Target: none"
        hud2.Color = Color3.new(0.5, 0.5, 0.5)
    end
    hud3.Text = "HP: " .. myHP .. "/" .. myMax
    hud3.Color = Color3.new(0, 1, 0)
end

-- ══════════════════════════════════════════════════════════════
-- RAINBOW SPINNING CROSSHAIR
-- ══════════════════════════════════════════════════════════════
local crossLines = {}
for i = 1, 4 do
    crossLines[i] = TrackDraw(Drawing.new("Line"))
    crossLines[i].Thickness = 2
    crossLines[i].Visible = false
end
local crossDot = TrackDraw(Drawing.new("Circle"))
crossDot.Filled = true
crossDot.Radius = 2
crossDot.Visible = false

local crossAngle = 0
local function UpdateCrosshair()
    if not CFG.crosshairOn then
        for i = 1, 4 do crossLines[i].Visible = false end
        crossDot.Visible = false
        return
    end
    local vp = Camera.ViewportSize
    local cx, cy = vp.X / 2, vp.Y / 2
    local center = Vector2.new(cx, cy)

    crossAngle = crossAngle + CFG.rainbowSpeed * 0.05
    local hue = (crossAngle * 0.1) % 1
    local col = Color3.fromHSV(hue, 1, 1)
    local sz = CFG.crossSize
    local gap = 4

    for i = 1, 4 do
        local angle = crossAngle + (i - 1) * math.pi / 2
        local inner = Vector2.new(cx + math.cos(angle) * gap, cy + math.sin(angle) * gap)
        local outer = Vector2.new(cx + math.cos(angle) * (gap + sz), cy + math.sin(angle) * (gap + sz))
        crossLines[i].From = inner
        crossLines[i].To = outer
        crossLines[i].Color = Color3.fromHSV((hue + (i - 1) * 0.25) % 1, 1, 1)
        crossLines[i].Visible = true
    end
    crossDot.Position = center
    crossDot.Color = col
    crossDot.Visible = true
end

-- ══════════════════════════════════════════════════════════════
-- SETTINGS GUI (F2)
-- ══════════════════════════════════════════════════════════════
local guiOpen = false
local guiObjs = {}

local function MakeGUI()
    -- Background
    guiObjs.bg = TrackDraw(Drawing.new("Square"))
    guiObjs.bg.Filled = true
    guiObjs.bg.Color = Color3.new(0.08, 0.08, 0.12)
    guiObjs.bg.Transparency = 0.92
    guiObjs.bg.Size = Vector2.new(320, 420)
    guiObjs.bg.Position = Vector2.new(20, 80)
    guiObjs.bg.Visible = false

    guiObjs.title = TrackDraw(Drawing.new("Text"))
    guiObjs.title.Position = Vector2.new(30, 88)
    guiObjs.title.Size = 18
    guiObjs.title.Font = Drawing.Fonts.Monospace
    guiObjs.title.Color = Color3.fromHSV(0, 0, 1)
    guiObjs.title.Outline = true
    guiObjs.title.Text = "=== RAGEBOT SETTINGS ==="
    guiObjs.title.Visible = false

    -- Settings lines
    local items = {
        {key = "fireDelay",    label = "Fire Delay",     min = 0.03, max = 0.5,  fmt = "%.2f"},
        {key = "maxDist",      label = "Max Distance",   min = 100,  max = 8000, fmt = "%.0f", int = true},
        {key = "flySpeed",     label = "Fly Speed",      min = 1,    max = 15,   fmt = "%.1f"},
        {key = "keepDist",     label = "Keep Distance",  min = 0.5,  max = 10,   fmt = "%.1f"},
        {key = "heightOff",    label = "Height Offset",  min = -2,   max = 8,    fmt = "%.1f"},
        {key = "evRadius",     label = "Evasion Radius", min = 0.5,  max = 10,   fmt = "%.1f"},
        {key = "evSpeed",      label = "Evasion Speed",  min = 1,    max = 20,   fmt = "%.1f"},
        {key = "evJitter",     label = "Evasion Jitter", min = 0,    max = 5,    fmt = "%.1f"},
        {key = "safeSpotY",    label = "Void Safe Y",    min = 50,   max = 500,  fmt = "%.0f", int = true},
        {key = "crossSize",    label = "Crosshair Size", min = 4,    max = 30,   fmt = "%.0f", int = true},
        {key = "rainbowSpeed", label = "Rainbow Speed",  min = 0.5,  max = 10,   fmt = "%.1f"},
    }

    guiObjs.lines = {}
    guiObjs.labels = {}
    guiObjs.vals = {}

    for i, item in ipairs(items) do
        local y = 115 + (i - 1) * 26

        guiObjs.labels[i] = TrackDraw(Drawing.new("Text"))
        guiObjs.labels[i].Position = Vector2.new(30, y)
        guiObjs.labels[i].Size = 13
        guiObjs.labels[i].Font = Drawing.Fonts.Monospace
        guiObjs.labels[i].Color = Color3.new(0.8, 0.8, 0.8)
        guiObjs.labels[i].Outline = true
        guiObjs.labels[i].Text = item.label
        guiObjs.labels[i].Visible = false

        -- Slider bar bg
        guiObjs.lines[i] = TrackDraw(Drawing.new("Square"))
        guiObjs.lines[i].Filled = true
        guiObjs.lines[i].Color = Color3.new(0.2, 0.2, 0.25)
        guiObjs.lines[i].Size = Vector2.new(120, 8)
        guiObjs.lines[i].Position = Vector2.new(170, y + 3)
        guiObjs.lines[i].Visible = false

        -- Slider fill
        guiObjs.lines[i].fill = TrackDraw(Drawing.new("Square"))
        guiObjs.lines[i].fill.Filled = true
        guiObjs.lines[i].fill.Color = Color3.fromHSV(i / #items, 0.8, 0.9)
        local val = CFG[item.key] or 0
        local pct = (val - item.min) / (item.max - item.min)
        guiObjs.lines[i].fill.Size = Vector2.new(math.clamp(pct * 120, 0, 120), 8)
        guiObjs.lines[i].fill.Position = Vector2.new(170, y + 3)
        guiObjs.lines[i].fill.Visible = false

        guiObjs.vals[i] = TrackDraw(Drawing.new("Text"))
        guiObjs.vals[i].Position = Vector2.new(295, y)
        guiObjs.vals[i].Size = 12
        guiObjs.vals[i].Font = Drawing.Fonts.Monospace
        guiObjs.vals[i].Color = Color3.new(1, 1, 1)
        guiObjs.vals[i].Outline = true
        guiObjs.vals[i].Text = string.format(item.fmt, val)
        guiObjs.vals[i].Visible = false

        item.idx = i
    end

    -- Toggle lines
    local toggles = {
        {key = "evasionOn",    label = "Evasion"},
        {key = "voidProtect",  label = "Void Protect"},
        {key = "espOn",        label = "ESP"},
        {key = "crosshairOn",  label = "Crosshair"},
    }

    guiObjs.toggles = {}
    guiObjs.togLabels = {}
    for i, tog in ipairs(toggles) do
        local y = 115 + #items * 26 + (i - 1) * 22

        guiObjs.togLabels[i] = TrackDraw(Drawing.new("Text"))
        guiObjs.togLabels[i].Position = Vector2.new(30, y)
        guiObjs.togLabels[i].Size = 13
        guiObjs.togLabels[i].Font = Drawing.Fonts.Monospace
        guiObjs.togLabels[i].Color = Color3.new(0.8, 0.8, 0.8)
        guiObjs.togLabels[i].Outline = true
        guiObjs.togLabels[i].Text = tog.label
        guiObjs.togLabels[i].Visible = false

        guiObjs.toggles[i] = TrackDraw(Drawing.new("Square"))
        guiObjs.toggles[i].Filled = true
        guiObjs.toggles[i].Size = Vector2.new(14, 14)
        guiObjs.toggles[i].Position = Vector2.new(280, y - 1)
        guiObjs.toggles[i].Color = CFG[tog.key] and Color3.new(0, 1, 0) or Color3.new(1, 0, 0)
        guiObjs.toggles[i].Visible = false

        guiObjs.toggles[i].check = TrackDraw(Drawing.new("Text"))
        guiObjs.toggles[i].check.Position = Vector2.new(298, y - 1)
        guiObjs.toggles[i].check.Size = 13
        guiObjs.toggles[i].check.Font = Drawing.Fonts.Monospace
        guiObjs.toggles[i].check.Color = Color3.new(1, 1, 1)
        guiObjs.toggles[i].check.Outline = true
        guiObjs.toggles[i].check.Text = CFG[tog.key] and "ON" or "OFF"
        guiObjs.toggles[i].check.Visible = false

        tog.idx = i
    end

    guiObjs.items = items
    guiObjs.togDefs = toggles
end

MakeGUI()

local function ShowGUI(state)
    guiOpen = state
    guiObjs.bg.Visible = state
    guiObjs.title.Visible = state
    for i = 1, #guiObjs.labels do
        guiObjs.labels[i].Visible = state
        guiObjs.lines[i].Visible = state
        guiObjs.lines[i].fill.Visible = state
        guiObjs.vals[i].Visible = state
    end
    for i = 1, #guiObjs.toggles do
        guiObjs.togLabels[i].Visible = state
        guiObjs.toggles[i].Visible = state
        guiObjs.toggles[i].check.Visible = state
    end
end

local function RefreshGUI()
    for i, item in ipairs(guiObjs.items) do
        local val = CFG[item.key] or 0
        local pct = (val - item.min) / (item.max - item.min)
        guiObjs.lines[i].fill.Size = Vector2.new(math.clamp(pct * 120, 0, 120), 8)
        guiObjs.vals[i].Text = string.format(item.fmt, val)
    end
    for i, tog in ipairs(guiObjs.togDefs) do
        local on = CFG[tog.key]
        guiObjs.toggles[i].Color = on and Color3.new(0, 1, 0) or Color3.new(1, 0, 0)
        guiObjs.toggles[i].check.Text = on and "ON" or "OFF"
    end
end

-- GUI click handling
TrackConn(UIS.InputBegan:Connect(function(input, processed)
    if not ALIVE then return end

    -- F2 toggle GUI
    if input.KeyCode == Enum.KeyCode.F2 then
        ShowGUI(not guiOpen)
        return
    end

    -- F8 destroy
    if input.KeyCode == Enum.KeyCode.F8 then
        FullDestroy()
        return
    end

    -- GUI interactions
    if guiOpen and input.UserInputType == Enum.UserInputType.MouseButton1 then
        local mouse = Vector2.new(input.Position.X, input.Position.Y)

        -- Check sliders
        for i, item in ipairs(guiObjs.items) do
            local barX, barY = 170, 115 + (i - 1) * 26 + 3
            if mouse.X >= barX and mouse.X <= barX + 120 and mouse.Y >= barY and mouse.Y <= barY + 8 then
                local pct = math.clamp((mouse.X - barX) / 120, 0, 1)
                local val = item.min + pct * (item.max - item.min)
                if item.int then val = math.floor(val + 0.5) end
                CFG[item.key] = val
                RefreshGUI()
                print("[ragebot] " .. item.label .. " = " .. val)
            end
        end

        -- Check toggles
        for i, tog in ipairs(guiObjs.togDefs) do
            local togX, togY = 280, 115 + #guiObjs.items * 26 + (i - 1) * 22 - 1
            if mouse.X >= togX and mouse.X <= togX + 14 and mouse.Y >= togY and mouse.Y <= togY + 14 then
                CFG[tog.key] = not CFG[tog.key]
                RefreshGUI()
                print("[ragebot] " .. tog.label .. " = " .. tostring(CFG[tog.key]))
            end
        end
    end
end))

-- ══════════════════════════════════════════════════════════════
-- AIM: lookAt
-- ══════════════════════════════════════════════════════════════
local function AimAt(pos)
    local ok, camPos = pcall(function() return Camera.Position end)
    if ok and camPos then
        pcall(function() Camera.lookAt(camPos, pos) end)
    end
end

-- ══════════════════════════════════════════════════════════════
-- FLY: velocity + snap
-- ══════════════════════════════════════════════════════════════
local flyAngle = 0
local function FlyTo(root, tPos)
    local ok, myPos = pcall(function() return root.Position end)
    if not ok or not myPos then return end

    local delta = tPos - myPos
    local dist = delta.Magnitude
    if dist < 0.5 then return end

    local dir = delta.Unit
    local desired = tPos - dir * CFG.keepDist + Vector3.new(0, CFG.heightOff, 0)

    if CFG.evasionOn then
        flyAngle = flyAngle + CFG.evSpeed * 0.03
        desired = desired + Vector3.new(
            math.cos(flyAngle) * CFG.evRadius,
            math.sin(flyAngle * 2.7) * CFG.evJitter,
            math.sin(flyAngle) * CFG.evRadius
        )
    end

    local moveDelta = desired - myPos
    local moveDist = moveDelta.Magnitude
    if moveDist < 0.3 then return end

    local vel = moveDelta.Unit * math.clamp(moveDist * CFG.flySpeed, 40, 500)
    pcall(function() root.AssemblyLinearVelocity = vel end)

    if moveDist < 80 then
        pcall(function() root.Position = desired end)
    end
end

-- ══════════════════════════════════════════════════════════════
-- GOD MODE + WEAPON MODS
-- ══════════════════════════════════════════════════════════════
local function GodMode()
    local h = Hum(LP.Character)
    if h then
        pcall(function() h.MaxHealth = 99999 end)
        pcall(function() h.Health = 99999 end)
    end
    pcall(function() setgc({Health = 99999, MaxHealth = 99999, RecoilAmount = 0, SpreadAngle = 0, CameraRecoilMult = 0}) end)
end

-- ══════════════════════════════════════════════════════════════
-- VOID PROTECTION: teleport back if falling
-- ══════════════════════════════════════════════════════════════
local function VoidCheck()
    if not CFG.voidProtect then return end
    local myRoot = Root(LP.Character)
    if not myRoot then return end
    local ok, pos = pcall(function() return myRoot.Position end)
    if not ok or not pos then return end
    if pos.Y < CFG.voidY then
        local safe = SafeSpot()
        pcall(function() myRoot.Position = safe end)
        pcall(function() myRoot.AssemblyLinearVelocity = Vector3.new(0, 0, 0) end)
        print("[ragebot] void saved — teleported to safe spot")
    end
end

-- ══════════════════════════════════════════════════════════════
-- MAIN LOOP
-- ══════════════════════════════════════════════════════════════
print("[ragebot] v7 ready — F2=menu  F8=destroy")

while ALIVE do
    -- Always run safety
    pcall(VoidCheck)
    pcall(GodMode)

    -- Combat
    local myRoot = Root(LP.Character)
    if myRoot then
        local ok, myPos = pcall(function() return myRoot.Position end)
        if ok and myPos then
            -- Target switch
            local now = tick()
            if now - lastSwitch > 0.15 or not curTarget or not Alive(curTarget) then
                local t, p, d = Nearest(myPos)
                if t then
                    curTarget = t
                    lastSwitch = now
                else
                    curTarget = nil
                end
            end

            -- Attack
            if curTarget and Alive(curTarget) then
                local part = Part(curTarget.Character)
                if part then
                    local ok2, tPos = pcall(function() return part.Position end)
                    if ok2 and tPos then
                        FlyTo(myRoot, tPos)
                        AimAt(tPos)
                        if now - lastFire >= CFG.fireDelay then
                            lastFire = now
                            pcall(function() mouse1click() end)
                        end
                    end
                end
            end
        end
    end

    -- Visuals
    pcall(UpdateHUD)
    pcall(UpdateESP)
    pcall(UpdateCrosshair)
    wait()
end
