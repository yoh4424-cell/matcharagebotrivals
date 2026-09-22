--[[
    MATCHA RAGEBOT v5 — RIVALS (FFA)
    PlaceId: 17625359962 | Nosniy Games
    
    One-liner:
    loadstring(game:HttpGet("https://raw.githubusercontent.com/yoh4424-cell/matcharagebotrivals/main/rivals_ragebot.lua"))()
    
    F8 = toggle ON/OFF
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("RunService")
local lp = Players.LocalPlayer

local F8 = 0x77
local ON = true
local f8Debounce = 0
local orbitAngle = 0
local lastFire = 0
local lastSwitch = 0
local curTarget = nil
local respawnTick = tick()

print("[ragebot] v5 loaded")

-- ══════════════════════════════════════════════════════════════
-- HELPERS (define FIRST so everything else can use them)
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
    if plr == lp then return false end
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
    local best, bestP, bestD = nil, nil, 3500
    for _, plr in ipairs(Players:GetPlayers()) do
        local ok, alive = pcall(function() return Alive(plr) end)
        if ok and alive then
            local c = plr.Character
            local p = Part(c)
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

-- ══════════════════════════════════════════════════════════════
-- HUD (no OutlineColor — Matcha doesn't support it)
-- ══════════════════════════════════════════════════════════════
local hud = Drawing.new("Text")
hud.Position = Vector2.new(20, 20)
hud.Size = 18
hud.Font = Drawing.Fonts.Monospace
hud.Outline = true
hud.Visible = true

local hudTarget = Drawing.new("Text")
hudTarget.Position = Vector2.new(20, 42)
hudTarget.Size = 14
hudTarget.Font = Drawing.Fonts.Monospace
hudTarget.Outline = true
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
        local mr = Root(lp.Character)
        local ok, pp = pcall(function() return Part(curTarget.Character) end)
        if ok and pp and pp.Position and mr then
            d = math.floor((pp.Position - mr.Position).Magnitude)
        end
        hudTarget.Text = "Target: " .. n .. " [" .. d .. "m]"
        hudTarget.Color = Color3.new(1, 1, 0)
    else
        hudTarget.Text = "Target: none"
        hudTarget.Color = Color3.new(0.6, 0.6, 0.6)
    end
end

-- ══════════════════════════════════════════════════════════════
-- AIM: use lookAt (SetRotation doesn't exist in Matcha)
-- ══════════════════════════════════════════════════════════════
local function AimAt(pos)
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local ok, camPos = pcall(function() return cam.Position end)
    if ok and camPos then
        pcall(function() cam.lookAt(camPos, pos) end)
    end
end

-- ══════════════════════════════════════════════════════════════
-- FLY: velocity push + position snap
-- ══════════════════════════════════════════════════════════════
local function FlyTo(root, tPos)
    local ok, myPos = pcall(function() return root.Position end)
    if not ok or not myPos then return end

    local delta = tPos - myPos
    local dist = delta.Magnitude
    if dist < 0.5 then return end

    local dir = delta.Unit
    local desired = tPos - dir * 3.5 + Vector3.new(0, 1.5, 0)

    -- Orbit evasion
    orbitAngle = orbitAngle + 9.0 * 0.03
    local ox = math.cos(orbitAngle) * 4.5
    local oz = math.sin(orbitAngle) * 4.5
    local oy = math.sin(orbitAngle * 2.7) * 1.8
    desired = desired + Vector3.new(ox, oy, oz)

    local moveDelta = desired - myPos
    local moveDist = moveDelta.Magnitude
    if moveDist < 0.5 then return end

    -- Velocity push
    local vel = moveDelta.Unit * math.clamp(moveDist * 4, 20, 300)
    pcall(function() root.AssemblyLinearVelocity = vel end)

    -- Position snap when close
    if moveDist < 60 then
        pcall(function() root.Position = desired end)
    end
end

-- ══════════════════════════════════════════════════════════════
-- F8 TOGGLE
-- ══════════════════════════════════════════════════════════════
spawn(function()
    while true do
        local ok, held = pcall(function() return iskeypressed(F8) end)
        if ok and held then
            local now = tick()
            if now - f8Debounce > 0.4 then
                f8Debounce = now
                ON = not ON
                print("[ragebot] TOGGLED: " .. (ON and "ON" or "OFF"))
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
                print("[ragebot] TOGGLED (UIS): " .. (ON and "ON" or "OFF"))
            end
        end
    end)
end)

pcall(function()
    lp.CharacterAdded:Connect(function()
        respawnTick = tick()
        curTarget = nil
        print("[ragebot] respawned")
    end)
end)

print("[ragebot] ready — F8 to toggle")

-- ══════════════════════════════════════════════════════════════
-- MAIN LOOP
-- ══════════════════════════════════════════════════════════════
while true do
    if ON then
        local myRoot = Root(lp.Character)
        if myRoot then
            local ok, myPos = pcall(function() return myRoot.Position end)
            if ok and myPos then

                -- Respawn cooldown
                if (tick() - respawnTick) > 1.8 then

                    -- Target switch
                    local now = tick()
                    if now - lastSwitch > 0.3 or not curTarget or not Alive(curTarget) then
                        local t, p, d = Nearest(myPos)
                        if t then
                            curTarget = t
                            lastSwitch = now
                            print("[ragebot] target: " .. t.Name .. " [" .. math.floor(d) .. "m]")
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

                                -- Fly
                                FlyTo(myRoot, tPos)

                                -- Lock aim
                                AimAt(tPos)

                                -- Auto fire
                                if now - lastFire >= 0.13 then
                                    lastFire = now
                                    pcall(function() mouse1click() end)
                                end
                            end
                        end
                    end

                end
            end
        end
    end
    pcall(UpdateHUD)
    wait()
end
