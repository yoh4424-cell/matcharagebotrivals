--[[
    MATCHA RAGEBOT v3 — RIVALS (FFA) — FIXED
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

-- ══════════════════════════════════════════════════════════════
-- DEBUG: show notification at every step so we know what breaks
-- ══════════════════════════════════════════════════════════════
pcall(function() notify("v3 loaded - F8 toggles", "Ragebot", 4) end)
print("[ragebot] v3 script started")

-- ══════════════════════════════════════════════════════════════
-- SETTINGS (hardcoded defaults — no menu needed)
-- ══════════════════════════════════════════════════════════════
local CFG = {
    fireDelay   = 0.13,
    bone        = 1,          -- 0=Head 1=HRP 2=UpperTorso
    maxDist     = 3500,
    stick       = true,
    stickDist   = 3.5,
    stickHeight = 1.5,
    lerpSpeed   = 0.55,
    maxFly      = 200,
    evasion     = true,
    evRadius    = 4.5,
    evSpeed     = 9.0,
    evJitter    = 1.8,
    pickup      = true,
    pickupRange = 40,
    pickupDelay = 0.15,
    safeRespawn = true,
    safeDelay   = 1.8,
}

-- ══════════════════════════════════════════════════════════════
-- MENU (optional — only if UI Binding exists)
-- ══════════════════════════════════════════════════════════════
local menuLoaded = false
pcall(function()
    UI.AddTab("Rivals Rage", function(tab)
        local c = tab:Section("Combat", "Left")
        c:Toggle("r_on", "Ragebot", true)
        c:Keybind("r_kb", F8, "toggle")
        c:Toggle("r_fire", "Auto Fire", true)
        c:SliderFloat("r_fd", "Fire Delay", 0.06, 0.5, 0.13, "%.2f")
        c:Combo("r_bone", "Aim Part", {"Head", "HRP", "UpperTorso"}, 1)
        c:SliderInt("r_md", "Max Dist", 100, 8000, 3500)

        local m = tab:Section("Movement", "Left")
        m:Toggle("r_fly", "Fly To Target", true)
        m:SliderFloat("r_sd", "Keep Dist", 1.0, 12.0, 3.5, "%.1f")
        m:SliderFloat("r_sh", "Height", -1.0, 8.0, 1.5, "%.1f")
        m:SliderFloat("r_sp", "Lerp", 0.1, 1.0, 0.55, "%.2f")

        local e = tab:Section("Evasion", "Right")
        e:Toggle("r_ev", "Orbit", true)
        e:SliderFloat("r_er", "Radius", 1.0, 10.0, 4.5, "%.1f")
        e:SliderFloat("r_es", "Speed", 2.0, 18.0, 9.0, "%.1f")
        e:SliderFloat("r_ej", "Jitter", 0.0, 5.0, 1.8, "%.1f")

        local p = tab:Section("Pickups", "Right")
        p:Toggle("r_pk", "Auto Pickup", true)
        p:SliderFloat("r_pr", "Range", 5.0, 80.0, 40.0, "%.0f")
    end)
    menuLoaded = true
    print("[ragebot] menu loaded OK")
end)

if not menuLoaded then
    print("[ragebot] menu FAILED — using hardcoded settings")
    pcall(function() notify("Menu unavailable - using defaults", "Ragebot", 3) end)
end

-- ══════════════════════════════════════════════════════════════
-- READ SETTING (menu or hardcoded fallback)
-- ══════════════════════════════════════════════════════════════
local function C(id, fallback)
    if not menuLoaded then return fallback end
    local ok, v = pcall(function() return UI.GetValue(id) end)
    if ok and v ~= nil then return v end
    return fallback
end

-- ══════════════════════════════════════════════════════════════
-- HELPERS
-- ══════════════════════════════════════════════════════════════
local function GetRoot(c)
    if not c then return nil end
    local ok, r = pcall(function() return c:FindFirstChild("HumanoidRootPart") end)
    return ok and r or nil
end

local function GetHum(c)
    if not c then return nil end
    local ok, h = pcall(function() return c:FindFirstChildOfClass("Humanoid") end)
    return ok and h or nil
end

local function GetPart(c, idx)
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

local function Alive(plr)
    if plr == lp then return false end
    local c = plr.Character
    if not c then return false end
    local h = GetHum(c)
    if h then
        local ok, hp = pcall(function() return h.Health end)
        if ok and hp and hp <= 0 then return false end
    end
    local r = GetRoot(c)
    return r and r.Position and true or false
end

local function Nearest(pos, maxD)
    local best, bestP, bestD = nil, nil, maxD
    for _, plr in ipairs(Players:GetPlayers()) do
        local ok, alive = pcall(function() return Alive(plr) end)
        if ok and alive then
            local part = GetPart(plr.Character, C("r_bone", CFG.bone))
            if part and part.Position then
                local d = (part.Position - pos).Magnitude
                if d < bestD then
                    bestD = d
                    best = plr
                    bestP = part
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
-- PICKUP SCANNER
-- ══════════════════════════════════════════════════════════════
local HP_KW = {"health","medkit","med","heal","hp","bandage","kit","restore","revive"}
local AM_KW = {"ammo","bullet","mag","clip","round","shell","reload","supply"}

local function IsPickup(obj, kw)
    if not obj or not obj:IsA("BasePart") then return false end
    local n = string.lower(obj.Name or "")
    for _, k in ipairs(kw) do
        if string.find(n, k) then return true end
    end
    return false
end

local function DoPickup()
    if not C("r_pk", CFG.pickup) then return end
    local now = tick()
    if now - lastPickup < CFG.pickupDelay then return end
    local myRoot = GetRoot(lp.Character)
    if not myRoot then return end
    local myPos = myRoot.Position
    local range = C("r_pr", CFG.pickupRange)
    local bestObj, bestD = nil, range

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
            pcall(function() myRoot.Position = bpos + Vector3.new(0, 1, 0) end)
        end
    end
end

-- ══════════════════════════════════════════════════════════════
-- F8 TOGGLE (two methods for safety)
-- ══════════════════════════════════════════════════════════════

-- Method 1: iskeypressed polling
spawn(function()
    while true do
        local ok, held = pcall(function() return iskeypressed(F8) end)
        if ok and held then
            local now = tick()
            if now - f8Debounce > 0.4 then
                f8Debounce = now
                ON = not ON
                pcall(function() notify("Ragebot: " .. (ON and "ON" or "OFF"), "Rivals", 2) end)
                pcall(function() UI.SetValue("r_on", ON) end)
                print("[ragebot] toggled:", ON)
            end
        end
        wait()
    end
end)

-- Method 2: UserInputService (backup)
pcall(function()
    UIS.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == Enum.KeyCode.F8 then
            local now = tick()
            if now - f8Debounce > 0.4 then
                f8Debounce = now
                ON = not ON
                pcall(function() notify("Ragebot: " .. (ON and "ON" or "OFF"), "Rivals", 2) end)
                pcall(function() UI.SetValue("r_on", ON) end)
                print("[ragebot] toggled via UIS:", ON)
            end
        end
    end)
end)

print("[ragebot] F8 toggle registered")

-- Respawn cooldown
pcall(function()
    lp.CharacterAdded:Connect(function()
        respawnTick = tick()
        curTarget = nil
    end)
end)

-- ══════════════════════════════════════════════════════════════
-- MAIN LOOP
-- ══════════════════════════════════════════════════════════════
print("[ragebot] main loop starting")

while true do
    -- Read from menu if loaded, otherwise use hardcoded + F8 toggle
    local enabled = C("r_on", ON)

    if enabled then
        local myRoot = GetRoot(lp.Character)
        if myRoot and myRoot.Position then
            local myPos = myRoot.Position

            -- Respawn cooldown
            if C("safe_respawn", CFG.safeRespawn) and (tick() - respawnTick) < CFG.safeDelay then
                -- skip
            else
                -- Pickups
                DoPickup()

                -- Target switch
                local now = tick()
                if now - lastSwitch > 0.3 or not curTarget or not Alive(curTarget) then
                    local t, p = Nearest(myPos, C("r_md", CFG.maxDist))
                    if t then
                        curTarget = t
                        lastSwitch = now
                    end
                end

                -- Attack
                if curTarget and Alive(curTarget) then
                    local part = GetPart(curTarget.Character, C("r_bone", CFG.bone))
                    if part and part.Position then
                        local tPos = part.Position

                        -- Fly
                        if C("r_fly", CFG.stick) then
                            local sD = C("r_sd", CFG.stickDist)
                            local sH = C("r_sh", CFG.stickHeight)
                            local lerp = C("r_sp", CFG.lerpSpeed)
                            local mFly = C("safe_maxflyspeed", CFG.maxFly)

                            local desired = Vector3.new(tPos.X, tPos.Y + sH, tPos.Z)
                            local delta = myPos - tPos
                            if delta.Magnitude > 0.01 then
                                local flat = Vector3.new(delta.X, 0, delta.Z)
                                if flat.Magnitude > 0.01 then
                                    local dir = flat.Unit
                                    desired = Vector3.new(tPos.X + dir.X * sD, tPos.Y + sH, tPos.Z + dir.Z * sD)
                                end
                            end

                            -- Orbit evasion
                            if C("r_ev", CFG.evasion) then
                                local rad = C("r_er", CFG.evRadius)
                                local spd = C("r_es", CFG.evSpeed)
                                local jit = C("r_ej", CFG.evJitter)
                                orbitAngle = orbitAngle + spd * 0.03
                                local ox = math.cos(orbitAngle) * rad
                                local oz = math.sin(orbitAngle) * rad
                                local oy = math.sin(orbitAngle * 2.7) * jit
                                desired = Vector3.new(desired.X + ox, desired.Y + oy, desired.Z + oz)
                            end

                            local goal = myPos:Lerp(desired, lerp)
                            local moveD = goal - myPos
                            if moveD.Magnitude > mFly * 0.016 then
                                goal = myPos + moveD.Unit * (mFly * 0.016)
                            end
                            pcall(function() myRoot.Position = goal end)
                        end

                        -- Aim + fire
                        AimAt(tPos)
                        if C("r_fire", true) then
                            local fd = C("r_fd", CFG.fireDelay)
                            if now - lastFire >= fd then
                                lastFire = now
                                pcall(function() mouse1click() end)
                            end
                        end
                    end
                end
            end
        end
    end
    wait()
end
