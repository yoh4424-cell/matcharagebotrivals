--[[
    SIMPLE RAGE — stick inside nearest player
    loadstring(game:HttpGet("https://raw.githubusercontent.com/yoh4424-cell/matcharagebotrivals/main/rivals_simple.lua"))()
    F2 = ON/OFF
]]

repeat wait() until game and pcall(function() return game:IsLoaded() end)

local Players = nil
for _ = 1, 100 do
    pcall(function() Players = game:GetService("Players") end)
    if Players then break end
    wait()
end
local Workspace = nil
for _ = 1, 100 do
    pcall(function() Workspace = game:GetService("Workspace") end)
    if Workspace then break end
    wait()
end

local LP = nil
for _ = 1, 200 do
    if Players then pcall(function() LP = Players.LocalPlayer end) end
    if LP then break end
    wait()
end
local Camera = nil
pcall(function() Camera = Workspace.CurrentCamera end)

local F2, KEY_X, F8 = 0x71, 0x58, 0x77 -- F2 primary, X backup, F8 destroy
local ON = false
local ALIVE = true
local dKey = 0
local target = nil
local deadFrames = 0
local lastFire = 0
local lastMods = 0

local function Root(c)
    if not c then return nil end
    local ok, r = pcall(function() return c:FindFirstChild("HumanoidRootPart") end)
    if ok then return r end
    return nil
end
local function Hum(c)
    if not c then return nil end
    local ok, h = pcall(function() return c:FindFirstChildOfClass("Humanoid") end)
    if ok then return h end
    return nil
end
local function Alive(p)
    if not p or p == LP then return false end
    local ok, c = pcall(function() return p.Character end)
    if not ok or not c then return false end
    local h = Hum(c)
    if h then
        local ok2, hp = pcall(function() return h.Health end)
        if ok2 and hp and hp <= 0 then return false end
    end
    local r = Root(c)
    if not r then return false end
    return pcall(function() return r.Position end)
end

local hud = Drawing.new("Text")
hud.Position = Vector2.new(20, 20)
hud.Size = 20
hud.Font = Drawing.Fonts.Monospace
hud.Outline = true
hud.Color = Color3.new(1, 0.3, 0.3)
hud.Text = "OFF — F2 or X"
hud.Visible = true

print("[simple] loaded — press F2 or X")

while ALIVE do
    local now = tick()

    -- toggle: F2 primary, X backup (F-keys often don't register in external)
    local kToggle = false
    pcall(function()
        kToggle = iskeypressed(F2) or iskeypressed(KEY_X)
    end)
    if kToggle and now - dKey > 0.4 then
        dKey = now
        ON = not ON
        target = nil
        deadFrames = 0
        if ON then
            hud.Text = "ON"
            hud.Color = Color3.new(0, 1, 0)
            print("[simple] ON")
        else
            hud.Text = "OFF — F2 or X"
            hud.Color = Color3.new(1, 0.3, 0.3)
            print("[simple] OFF")
            local r = Root(LP.Character)
            if r then pcall(function() r.AssemblyLinearVelocity = Vector3.new(0, 0, 0) end) end
        end
    end

    -- F8 = destroy everything (emergency off)
    local kKill = false
    pcall(function() kKill = iskeypressed(F8) end)
    if kKill then
        print("[simple] DESTROYED")
        pcall(function() hud:Remove() end)
        ALIVE = false
        break
    end

    if ON then
        -- instant melee hitspeed (lowest delay possible)
        if now - lastMods > 0.5 then
            lastMods = now
            pcall(function()
                setgc({
                    AttackCooldown = 0,
                    MeleeCooldown = 0,
                    SwingCooldown = 0,
                    AttackRate = 0.01,
                    SwingRate = 0,
                    EquipSpeed = 0,
                    FireRate = 0,
                    FireCooldown = 0,
                    DashCooldown = 0,
                    AimCooldown = 0,
                    ReloadTime = 0,
                    SpreadAngle = 0,
                    RecoilAmount = 0,
                    IsBackstab = 1,
                    BackstabDamage = 999,
                    BackstabMultiplier = 10,
                    BackstabRange = 9999,
                    MeleeRange = 9999,
                    AttackRange = 9999,
                    Reach = 9999,
                    HitboxSize = 9999,
                })
            end)
        end

        local myRoot = Root(LP.Character)
        if myRoot then
            local ok, myPos = pcall(function() return myRoot.Position end)
            if ok and myPos then
                -- sticky target: only drop after 10 bad reads in a row
                -- (one failed read = lag, not death — keeps you glued)
                if target then
                    if Alive(target) then
                        deadFrames = 0
                    else
                        deadFrames = deadFrames + 1
                    end
                    if deadFrames >= 10 then
                        print("[simple] target dead: " .. target.Name)
                        target = nil
                        deadFrames = 0
                    end
                end
                if not target then
                    local bestD = 1e9
                    local okL, list = pcall(function() return Players:GetPlayers() end)
                    if okL and list then
                        for _, p in ipairs(list) do
                            if Alive(p) then
                                local r = Root(p.Character)
                                if r then
                                    local ok2, pp = pcall(function() return r.Position end)
                                    if ok2 and pp then
                                        local d = (pp - myPos).Magnitude
                                        if d < bestD then bestD = d; target = p end
                                    end
                                end
                            end
                        end
                    end
                    if target then print("[simple] target: " .. target.Name) end
                end

                -- stick inside them
                if target and Alive(target) then
                    local tr = Root(target.Character)
                    if tr then
                        local ok2, tp = pcall(function() return tr.Position end)
                        if ok2 and tp then
                            -- glue: teleport inside + kill velocity so server can't fling you back
                            pcall(function() myRoot.Position = tp end)
                            pcall(function() myRoot.AssemblyLinearVelocity = Vector3.new(0, 0, 0) end)
                            pcall(function() myRoot.CanCollide = false end)
                            local okc, cp = pcall(function() return Camera.Position end)
                            if okc and cp then pcall(function() Camera.lookAt(cp, tp) end) end
                            if now - lastFire >= 0.1 then
                                lastFire = now
                                pcall(function() mouse1click() end)
                            end
                            hud.Text = "ON — " .. target.Name
                        end
                    end
                else
                    hud.Text = "ON — no target"
                end
            end
        end
    end

    wait()
end
