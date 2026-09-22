--[[
    MATCHA RAGEBOT v4 — RIVALS (FFA)
    PlaceId: 17625359962 | Nosniy Games
    
    One-liner:
    loadstring(game:HttpGet("https://raw.githubusercontent.com/yoh4424-cell/matcharagebotrivals/main/rivals_ragebot.lua"))()
    
    F8 = toggle ON/OFF
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UIS = game:GetService("UserInputService")
local lp = Players.LocalPlayer

local F8 = 0x77
local ON = true
local f8Debounce = 0
local orbitAngle = 0
local lastFire = 0
local lastPickup = 0
local lastSwitch = 0
local curTarget = nil
local respawnTick = tick()

pcall(function() notify("v4 loaded - F8 toggles", "Ragebot", 4) end)
print("[ragebot] v4 started")

-- ══════════════════════════════════════════════════════════════
-- HUD INDICATOR (always visible on screen)
-- ══════════════════════════════════════════════════════════════
local hud = Drawing.new("Text")
hud.Position = Vector2.new(20, 20)
hud.Size = 18
hud.Font = Drawing.Fonts.Monospace
hud.Outline = true
hud.OutlineColor = Color3.new(0, 0, 0)
hud.Visible = true

local hudTarget = Drawing.new("Text")
hudTarget.Position = Vector2.new(20, 42)
hudTarget.Size = 14
hudTarget.Font = Drawing.Fonts.Monospace
hudTarget.Outline = true
hudTarget.OutlineColor = Color3.new(0, 0, 0)
hudTarget.Visible = true

local function UpdateHUD()
    if ON then
        hud.Text = "[ RAGEBOT: ON ]"
        hud.Color = Color3.new(0, 1, 0)
    else
        hud.Text = "[ RAGEBOT: OFF ]"
        hud.Color = Color3.new(1, 0.2, 0.2)
    end
    if curTarget and ON then
        local n = ""
        pcall(function() n = curTarget.Name end)
        local d = 0
        local ok, pp = pcall(function() return Part(curTarget.Character) end)
        if ok and pp and pp.Position then
            local mr = Root(lp.Character)
            if mr then d = math.floor((pp.Position - mr.Position).Magnitude) end
        end
        hudTarget.Text = "Target: " .. n .. " [" .. d .. "m]"
        hudTarget.Color = Color3.new(1, 1, 0)
    else
        hudTarget.Text = "Target: none"
        hudTarget.Color = Color3.new(0.6, 0.6, 0.6)
    end
end

-- Hardcoded config (no menu dependency)
local FD = 0.13   -- fire delay
local MD = 3500    -- max dist
local SD = 3.5     -- stick dist
local SH = 1.5     -- stick height
local EV = true    -- evasion on
local ER = 4.5     -- evasion radius
local ES = 9.0     -- evasion speed
local EJ = 1.8     -- evasion jitter

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
    for _, n in ipairs({"Head", "HumanoidRootPart", "UpperTorso", "Torso"}) do
        local ok, p = pcall(function() return c:FindFirstChild(n) end)
        if ok and p and p.Position then return p end
    end
    return nil
end

local function Alive(plr)
    if plr == lp then return false end
    local c = plr.Character
    if not c then return false end
    local h = Hum(c)
    if h then
        local ok, hp = pcall(function() return h.Health end)
        if ok and hp and hp <= 0 then return false end
    end
    local r = Root(c)
    return r and r.Position and true or false
end

local function Nearest(pos)
    local best, bestP, bestD = nil, nil, MD
    for _, plr in ipairs(Players:GetPlayers()) do
        local ok, alive = pcall(function() return Alive(plr) end)
        if ok and alive then
            local p = Part(plr.Character)
            if p and p.Position then
                local d = (p.Position - pos).Magnitude
                if d < bestD then
                    bestD = d
                    best = plr
                    bestP = p
                end
            end
        end
    end
    return best, bestP, bestD
end

local function AimAt(pos)
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local ok = pcall(function() cam:SetRotation(pos) end)
    if not ok then
        pcall(function() cam.lookAt(cam.Position, pos) end)
    end
end

-- ══════════════════════════════════════════════════════════════
-- MOVEMENT: velocity-based fly + position jitter
-- ══════════════════════════════════════════════════════════════
local function FlyToTarget(root, tPos)
    local myPos = root.Position
    local delta = tPos - myPos
    local dist = delta.Magnitude

    -- desired offset: keep SD studs away at SH height above target
    local dir = delta.Unit
    local desired = tPos - dir * SD + Vector3.new(0, SH, 0)

    -- Orbit evasion (add offset to desired)
    if EV then
        orbitAngle = orbitAngle + ES * 0.03
        local ox = math.cos(orbitAngle) * ER
        local oz = math.sin(orbitAngle) * ER
        local oy = math.sin(orbitAngle * 2.7) * EJ
        desired = desired + Vector3.new(ox, oy, oz)
    end

    local moveDelta = desired - myPos
    local moveDist = moveDelta.Magnitude

    if moveDist < 0.5 then return end

    -- Method 1: Set velocity (continuous push — server can't fully correct)
    local vel = moveDelta.Unit * math.clamp(moveDist * 4, 20, 300)
    pcall(function() root.AssemblyLinearVelocity = vel end)

    -- Method 2: Position jitter (rapid small teleports — creates blur motion)
    -- Only do this when close (last 50 studs) for the "snap on target" effect
    if moveDist < 50 then
        local jitter = Vector3.new(
            (math.random() - 0.5) * 2,
            (math.random() - 0.5) * 1,
            (math.random() - 0.5) * 2
        )
        pcall(function() root.Position = desired + jitter end)
    end
end

-- ══════════════════════════════════════════════════════════════
-- PICKUP: teleport grab (works because it's a one-frame snap)
-- ══════════════════════════════════════════════════════════════
local HP_KW = {"health","medkit","med","heal","hp","bandage","kit","restore"}
local AM_KW = {"ammo","bullet","mag","clip","round","shell","supply"}

local function IsPickup(obj, kw)
    if not obj or not obj:IsA("BasePart") then return false end
    local n = string.lower(obj.Name or "")
    for _, k in ipairs(kw) do
        if string.find(n, k) then return true end
    end
    return false
end

local function DoPickup()
    local now = tick()
    if now - lastPickup < 0.15 then return end
    local myRoot = Root(lp.Character)
    if not myRoot then return end
    local myPos = myRoot.Position
    local bestObj, bestD = nil, 50

    local ok, desc = pcall(function() return Workspace:GetDescendants() end)
    if not ok then return end

    for _, obj in ipairs(desc) do
        if IsPickup(obj, HP_KW) or IsPickup(obj, AM_KW) then
            local ok2, pos = pcall(function() return obj.Position end)
            if ok2 and pos then
                local d = (pos - myPos).Magnitude
                if d < bestD then
                    bestD = d
                    bestObj = obj
                end
            end
        end
    end

    if bestObj and bestD > 2 then
        local ok3, bpos = pcall(function() return bestObj.Position end)
        if ok3 and bpos then
            lastPickup = now
            -- snap to pickup, then snap back next frame
            pcall(function() myRoot.Position = bpos + Vector3.new(0, 2, 0) end)
        end
    end
end

-- ══════════════════════════════════════════════════════════════
-- F8 TOGGLE (two methods)
-- ══════════════════════════════════════════════════════════════
spawn(function()
    while true do
        local ok, held = pcall(function() return iskeypressed(F8) end)
        if ok and held then
            local now = tick()
            if now - f8Debounce > 0.4 then
                f8Debounce = now
                ON = not ON
                pcall(function() notify("Ragebot: " .. (ON and "ON" or "OFF"), "Rivals", 2) end)
                print("[ragebot] toggled:", ON)
            end
        end
        wait()
    end
end)

pcall(function()
    UIS.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == Enum.KeyCode.F8 then
            local now = tick()
            if now - f8Debounce > 0.4 then
                f8Debounce = now
                ON = not ON
                pcall(function() notify("Ragebot: " .. (ON and "ON" or "OFF"), "Rivals", 2) end)
                print("[ragebot] toggled UIS:", ON)
            end
        end
    end)
end)

pcall(function()
    lp.CharacterAdded:Connect(function()
        respawnTick = tick()
        curTarget = nil
    end)
end)

print("[ragebot] F8 registered, main loop starting")

-- ══════════════════════════════════════════════════════════════
-- MAIN LOOP
-- ══════════════════════════════════════════════════════════════
while true do
    if ON then
        local myRoot = Root(lp.Character)
        if myRoot and myRoot.Position then
            local myPos = myRoot.Position

            -- Respawn cooldown (1.8s)
            if (tick() - respawnTick) < 1.8 then
                -- skip
            else
                -- Pickups
                DoPickup()

                -- Target switch (every 0.3s or if dead)
                local now = tick()
                if now - lastSwitch > 0.3 or not curTarget or not Alive(curTarget) then
                    local t = Nearest(myPos)
                    if t then
                        curTarget = t
                        lastSwitch = now
                    end
                end

                -- Attack
                if curTarget and Alive(curTarget) then
                    local part = Part(curTarget.Character)
                    if part and part.Position then
                        local tPos = part.Position

                        -- Fly to target (velocity + jitter)
                        FlyToTarget(myRoot, tPos)

                        -- Lock camera on target
                        AimAt(tPos)

                        -- Auto fire
                        if now - lastFire >= FD then
                            lastFire = now
                            pcall(function() mouse1click() end)
                        end
                    end
                end
            end
        end
    end
    pcall(UpdateHUD)
    wait()
end
