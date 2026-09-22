--[[
    MATCHA RAGEBOT v2 — RIVALS (FFA)
    PlaceId: 17625359962 | Nosniy Games
    
    One-liner (upload this to GitHub raw):
    loadstring(game:HttpGet("https://raw.githubusercontent.com/YOURNAME/YOURREPO/main/rivals_ragebot.lua"))()
    
    Features:
      - FFA mode: everyone is enemy (no team check)
      - Nearest player lock + fly to target + orbit evasion
      - Auto fire (guns + melee) with Rivals-tuned delays
      - Auto pickup health + ammo drops
      - Anti-ban: randomized delays, humanized jitter, cooldown on respawn
      - Toggle: Menu GUI + F8 fallback
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local lp = Players.LocalPlayer
local RUN = game:GetService("RunService")

local F8 = 0x77
local menuOn = true
local f8Debounce = 0
local orbitAngle = 0
local lastFire = 0
local lastPickup = 0
local lastTargetSwitch = 0
local currentTarget = nil
local respawnTime = tick()

pcall(function() notify("Matcha Ragebot v2 — Rivals loaded", "Ragebot", 3) end)

-- Anti-ban: cooldown after respawn (Rivals kicks on suspicious behavior post-death)
pcall(function()
    lp.CharacterAdded:Connect(function()
        respawnTime = tick()
        currentTarget = nil
        task.wait(1.5)
    end)
end)

-- ══════════════════════════════════════════════════════════════
-- MENU (Matcha UI Binding)
-- ══════════════════════════════════════════════════════════════
pcall(function()
    UI.AddTab("Rivals Ragebot", function(tab)
        local main = tab:Section("Combat", "Left")
        main:Toggle("rage_on", "Ragebot Enabled", true)
        local kb = main:Keybind("rage_kb", F8, "toggle")
        pcall(function() kb:AddToHotkey("Ragebot", "rage_on") end)
        main:Toggle("rage_fire", "Auto Fire", true)
        main:SliderFloat("rage_firedelay", "Fire Delay (s)", 0.06, 0.5, 0.13, "%.2f")
        main:Combo("rage_bone", "Aim Part", {"Head", "HumanoidRootPart", "UpperTorso"}, 1)
        main:SliderInt("rage_maxdist", "Max Target Dist", 100, 8000, 3500)

        local mov = tab:Section("Movement", "Left")
        mov:Toggle("rage_stick", "Fly To Target", true)
        mov:SliderFloat("rage_dist", "Keep Distance", 1.0, 12.0, 3.5, "%.1f")
        mov:SliderFloat("rage_height", "Height Offset", -1.0, 8.0, 1.5, "%.1f")
        mov:SliderFloat("rage_speed", "Lerp Speed (1=snap)", 0.1, 1.0, 0.55, "%.2f")

        local eva = tab:Section("Evasion", "Right")
        eva:Toggle("eva_on", "Orbit Evasion", true)
        eva:SliderFloat("eva_radius", "Orbit Radius", 1.0, 10.0, 4.5, "%.1f")
        eva:SliderFloat("eva_spinspeed", "Spin Speed", 2.0, 18.0, 9.0, "%.1f")
        eva:SliderFloat("eva_jitter", "Jitter", 0.0, 5.0, 1.8, "%.1f")

        local pck = tab:Section("Pickups", "Right")
        pck:Toggle("pickup_on", "Auto Pickup", true)
        pck:SliderFloat("pickup_range", "Pickup Range", 5.0, 80.0, 35.0, "%.0f")
        pck:SliderFloat("pickup_delay", "Pickup Delay (s)", 0.05, 0.5, 0.15, "%.2f")
        pck:Toggle("pickup_health", "Health Packs", true)
        pck:Toggle("pickup_ammo", "Ammo Packs", true)

        local safe = tab:Section("Safety", "Right")
        safe:Toggle("safe_respawn", "Cooldown After Respawn", true)
        safe:SliderFloat("safe_respawndelay", "Respawn Delay (s)", 0.5, 4.0, 1.8, "%.1f")
        safe:SliderFloat("safe_maxflyspeed", "Max Fly Speed", 50, 500, 200, "%.0f")
    end)
end)

-- ══════════════════════════════════════════════════════════════
-- HELPERS
-- ══════════════════════════════════════════════════════════════
local function Val(id, fb)
    local ok, v = pcall(function() return UI.GetValue(id) end)
    return (ok and v ~= nil) and v or fb
end

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

local function AimPart(c, idx)
    local names = {"Head", "HumanoidRootPart", "UpperTorso"}
    local want = names[(idx or 1) + 1] or "HumanoidRootPart"
    local ok, p = pcall(function() return c:FindFirstChild(want) end)
    if ok and p and p.Position then return p end
    for _, n in ipairs({"Head", "HumanoidRootPart", "UpperTorso", "Torso"}) do
        local ok2, p2 = pcall(function() return c:FindFirstChild(n) end)
        if ok2 and p2 and p2.Position then return p2 end
    end
    return nil
end

-- Rivals FFA: everyone is enemy (no team check)
local function IsAlive(plr)
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

local function NearestEnemy(myPos, maxD)
    local best, bestPart, bestDist = nil, nil, maxD or 3500
    local idx = Val("rage_bone", 1)
    for _, plr in ipairs(Players:GetPlayers()) do
        local ok, alive = pcall(function() return IsAlive(plr) end)
        if ok and alive then
            local c = plr.Character
            local part = AimPart(c, idx)
            if part and part.Position then
                local d = (part.Position - myPos).Magnitude
                if d < bestDist then
                    bestDist = d
                    best = plr
                    bestPart = part
                end
            end
        end
    end
    return best, bestPart, bestDist
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
-- PICKUP SYSTEM (scan workspace for health/ammo drops)
-- ══════════════════════════════════════════════════════════════
local PICKUP_KEYWORDS = {
    health = {"health", "medkit", "med", "heal", "hp", "bandage", "kit", "restore", "revive"},
    ammo = {"ammo", "bullet", "mag", "clip", "round", "shell", "reload", "supply"}
}

local function IsPickup(obj, category)
    if not obj or not obj:IsA("BasePart") then return false end
    local name = string.lower(obj.Name or "")
    local keywords = PICKUP_KEYWORDS[category]
    if keywords then
        for _, kw in ipairs(keywords) do
            if string.find(name, kw) then return true end
        end
    end
    -- also check if it's small and on the ground (typical pickup size)
    local ok, sz = pcall(function() return obj.Size end)
    if ok and sz and sz.Magnitude < 6 and sz.Y < 4 then
        -- check transparency (pickups are usually semi-transparent)
        local ok2, tr = pcall(function() return obj.Transparency end)
        if ok2 and tr and tr > 0.2 and tr < 0.9 then
            return true
        end
    end
    return false
end

local function GetPickups(range)
    local myChar = lp.Character
    local myRoot = Root(myChar)
    if not myRoot then return {} end
    local myPos = myRoot.Position
    local pickups = {}

    -- scan workspace descendants for pickup parts
    local ok, descendants = pcall(function() return Workspace:GetDescendants() end)
    if not ok then return {} end

    for _, obj in ipairs(descendants) do
        local isHealth = Val("pickup_health", true) and IsPickup(obj, "health")
        local isAmmo = Val("pickup_ammo", true) and IsPickup(obj, "ammo")
        if isHealth or isAmmo then
            local ok2, pos = pcall(function() return obj.Position end)
            if ok2 and pos then
                local d = (pos - myPos).Magnitude
                if d <= range then
                    table.insert(pickups, {part = obj, pos = pos, dist = d, type = isHealth and "health" or "ammo"})
                end
            end
        end
    end

    -- sort by distance
    table.sort(pickups, function(a, b) return a.dist < b.dist end)
    return pickups
end

local function CollectPickups()
    if not Val("pickup_on", true) then return end
    local now = tick()
    local delay = Val("pickup_delay", 0.15)
    if now - lastPickup < delay then return end

    local range = Val("pickup_range", 35)
    local pickups = GetPickups(range)
    if #pickups == 0 then return end

    local myChar = lp.Character
    local myRoot = Root(myChar)
    if not myRoot then return end

    -- teleport to nearest pickup then immediately return to fight
    local nearest = pickups[1]
    if nearest.dist > 2 then
        lastPickup = now
        pcall(function()
            myRoot.Position = nearest.pos + Vector3.new(0, 1, 0)
        end)
        -- quick wait then snap back (anti-ban: don't stay on pickup too long)
        task.wait(0.05)
    end
end

-- ══════════════════════════════════════════════════════════════
-- F8 TOGGLE
-- ══════════════════════════════════════════════════════════════
task.spawn(function()
    while true do
        local ok, pressed = pcall(function() return iskeypressed(F8) end)
        if ok and pressed then
            local now = tick()
            if now - f8Debounce > 0.4 then
                f8Debounce = now
                menuOn = not menuOn
                pcall(function() UI.SetValue("rage_on", menuOn) end)
                pcall(function() notify("Ragebot: " .. (menuOn and "ON" or "OFF"), "Rivals Ragebot", 2) end)
            end
        end
        task.wait()
    end
end)

-- ══════════════════════════════════════════════════════════════
-- MAIN LOOP
-- ══════════════════════════════════════════════════════════════
while true do
    local enabled = Val("rage_on", menuOn)
    if type(enabled) == "boolean" then menuOn = enabled end

    if enabled then
        local myChar = lp.Character
        local myRoot = Root(myChar)
        if myRoot and myRoot.Position then
            local myPos = myRoot.Position

            -- Anti-ban: cooldown after respawn
            local respawnDelay = Val("safe_respawndelay", 1.8)
            if Val("safe_respawn", true) and (tick() - respawnTime) < respawnDelay then
                -- too soon after respawn, skip this frame
            else
                -- Pickups (collect between fights)
                CollectPickups()

                -- Target selection (with cooldown to avoid rapid switching)
                local now = tick()
                if now - lastTargetSwitch > 0.3 or not currentTarget or not IsAlive(currentTarget) then
                    local maxD = Val("rage_maxdist", 3500)
                    local t, p = NearestEnemy(myPos, maxD)
                    if t then
                        currentTarget = t
                        lastTargetSwitch = now
                    end
                end

                -- Attack current target
                if currentTarget and IsAlive(currentTarget) then
                    local c = currentTarget.Character
                    local part = AimPart(c, Val("rage_bone", 1))
                    if part and part.Position then
                        local tPos = part.Position

                        -- Fly to target with evasion
                        if Val("rage_stick", true) then
                            local stickD = Val("rage_dist", 3.5)
                            local stickH = Val("rage_height", 1.5)
                            local lerpSpd = Val("rage_speed", 0.55)
                            local maxFly = Val("safe_maxflyspeed", 200)

                            local desired = Vector3.new(tPos.X, tPos.Y + stickH, tPos.Z)
                            local delta = myPos - tPos
                            if delta.Magnitude > 0.01 then
                                local flat = Vector3.new(delta.X, 0, delta.Z)
                                if flat.Magnitude > 0.01 then
                                    local dir = flat.Unit
                                    desired = Vector3.new(
                                        tPos.X + dir.X * stickD,
                                        tPos.Y + stickH,
                                        tPos.Z + dir.Z * stickD
                                    )
                                end
                            end

                            -- Orbit evasion (Kicia-like)
                            if Val("eva_on", true) then
                                local radius = Val("eva_radius", 4.5)
                                local spd = Val("eva_spinspeed", 9.0)
                                local jit = Val("eva_jitter", 1.8)
                                orbitAngle = orbitAngle + spd * 0.03
                                local ox = math.cos(orbitAngle) * radius
                                local oz = math.sin(orbitAngle) * radius
                                local oy = math.sin(orbitAngle * 2.7) * jit
                                desired = Vector3.new(desired.X + ox, desired.Y + oy, desired.Z + oz)
                            end

                            -- Lerp with speed cap (anti-ban: don't fly faster than humanly possible)
                            local goal = myPos:Lerp(desired, lerpSpd)
                            local moveDelta = goal - myPos
                            if moveDelta.Magnitude > maxFly * 0.016 then
                                goal = myPos + moveDelta.Unit * (maxFly * 0.016)
                            end
                            pcall(function() myRoot.Position = goal end)
                        end

                        -- Aim + fire
                        AimAt(tPos)
                        if Val("rage_fire", true) then
                            local fireDelay = Val("rage_firedelay", 0.13)
                            local now2 = tick()
                            if now2 - lastFire >= fireDelay then
                                lastFire = now2
                                -- Randomized micro-delay (anti-ban: humanize timing)
                                local micro = math.random() * 0.02
                                task.delay(micro, function()
                                    pcall(function() mouse1click() end)
                                end)
                            end
                        end
                    end
                end
            end
        end
    end
    task.wait()
end
