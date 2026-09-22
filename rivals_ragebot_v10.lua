--[[
    RIVALS RAGE v11 — clean rewrite
    loadstring(game:HttpGet("https://raw.githubusercontent.com/yoh4424-cell/matcharagebotrivals/main/rivals_ragebot_v11.lua"))()

    F3 = rage ON/OFF (starts OFF, nothing moves until you press it)
    F2 = settings GUI
    F8 = destroy script completely
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

-- keys (VK codes, no Enum needed)
local VK_F2, VK_F3, VK_F8 = 0x71, 0x72, 0x77

local ALIVE = true
local rageOn = false -- STARTS OFF so nothing moves until F3
local guiOpen = false
local dF2, dF3, dF8, dClick = 0, 0, 0, 0

local curTarget = nil
local lastFire = 0
local lastSwitch = 0
local lastMods = 0
local respawnTick = tick()
local flyAngle = 0

local function clamp(v, a, b)
    if v < a then return a end
    if v > b then return b end
    return v
end

print("[rage] v11 loaded — press F3 to enable")

-- ══════ CONFIG ══════
local CFG = {
    fireDelay   = 0.05,
    maxDist     = 3500,
    flyOn       = true,
    flySpeed    = 8.0,
    snapOn      = false, -- position snap OFF by default (no random TP)
    keepDist    = 2.5,
    heightOff   = 1.2,
    evasionOn   = true,
    evRadius    = 3.5,
    evSpeed     = 12.0,
    evJitter    = 1.2,
    voidProtect = true,
    voidY       = -30,
    safeY       = 200,
    espOn       = true,
    crossOn     = true,
    rainbowSpd  = 3.0,
    crossSize   = 12,
    meleeBox    = 15,
    dashCD      = 0.05,
    atkCD       = 0.03,
    backstab    = true,
}

-- ══════ HELPERS ══════
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
local function Part(c)
    if not c then return nil end
    for _, n in ipairs({"Head", "HumanoidRootPart", "UpperTorso", "Torso"}) do
        local ok, p = pcall(function() return c:FindFirstChild(n) end)
        if ok and p then
            local ok2 = pcall(function() return p.Position end)
            if ok2 then return p end
        end
    end
    return nil
end
local function Alive(plr)
    if not plr or plr == LP then return false end
    local ok1, c = pcall(function() return plr.Character end)
    if not ok1 or not c then return false end
    local h = Hum(c)
    if h then
        local ok2, hp = pcall(function() return h.Health end)
        if ok2 and hp and hp <= 0 then return false end
    end
    local r = Root(c)
    if not r then return false end
    local ok3 = pcall(function() return r.Position end)
    return ok3
end
local function Nearest(pos)
    local best, bestP, bestD = nil, nil, CFG.maxDist
    local ok, list = pcall(function() return Players:GetPlayers() end)
    if not ok or not list then return nil, nil, nil end
    for _, plr in ipairs(list) do
        if Alive(plr) then
            local p = Part(plr.Character)
            if p then
                local ok2, pp = pcall(function() return p.Position end)
                if ok2 and pp then
                    local d = (pp - pos).Magnitude
                    if d < bestD then bestD = d; best = plr; bestP = p end
                end
            end
        end
    end
    return best, bestP, bestD
end

-- ══════ DRAWINGS ══════
local draws = {}
local function NewDraw(t)
    local d = Drawing.new(t)
    table.insert(draws, d)
    return d
end
local function Txt(pos, size)
    local t = NewDraw("Text")
    t.Position = pos; t.Size = size; t.Font = Drawing.Fonts.Monospace
    t.Outline = true; t.Color = Color3.new(1, 1, 1); t.Visible = true
    return t
end

local hud1 = Txt(Vector2.new(20, 10), 16)
local hud2 = Txt(Vector2.new(20, 30), 13)
local hud3 = Txt(Vector2.new(20, 48), 12)

local espBox = NewDraw("Square")
espBox.Filled = false; espBox.Thickness = 2; espBox.Visible = false
local espName = Txt(Vector2.new(0, 0), 14); espName.Center = true; espName.Visible = false
local espHP = Txt(Vector2.new(0, 0), 12); espHP.Center = true; espHP.Visible = false
local espLine = NewDraw("Line"); espLine.Thickness = 1; espLine.Visible = false

local cross = {}
for i = 1, 4 do
    cross[i] = NewDraw("Line"); cross[i].Thickness = 2; cross[i].Visible = false
end
local crossDot = NewDraw("Circle")
crossDot.Filled = true; crossDot.Radius = 2; crossDot.Visible = false
local crossAng = 0

-- GUI objects
local guiBG = NewDraw("Square")
guiBG.Filled = true; guiBG.Color = Color3.new(0.06, 0.06, 0.1); guiBG.Transparency = 0.93
guiBG.Size = Vector2.new(360, 500); guiBG.Position = Vector2.new(20, 80); guiBG.Visible = false
local guiTitle = Txt(Vector2.new(50, 88), 15); guiTitle.Text = "RAGE SETTINGS"; guiTitle.Visible = false

local sliderDefs = {
    {key = "fireDelay", lbl = "Fire Delay",    mn = 0.01, mx = 0.3, fmt = "%.2f"},
    {key = "atkCD",     lbl = "Melee Speed",   mn = 0.01, mx = 0.3, fmt = "%.2f"},
    {key = "dashCD",    lbl = "Dash CD",       mn = 0.01, mx = 0.5, fmt = "%.2f"},
    {key = "meleeBox",  lbl = "Melee Hitbox",  mn = 1,    mx = 30,  fmt = "%.0f"},
    {key = "flySpeed",  lbl = "Fly Speed",     mn = 1,    mx = 15,  fmt = "%.1f"},
    {key = "keepDist",  lbl = "Keep Dist",     mn = 0.5,  mx = 10,  fmt = "%.1f"},
    {key = "heightOff", lbl = "Height",        mn = -2,   mx = 8,   fmt = "%.1f"},
    {key = "evRadius",  lbl = "Evade Radius",  mn = 0.5,  mx = 10,  fmt = "%.1f"},
    {key = "evSpeed",   lbl = "Evade Speed",   mn = 1,    mx = 20,  fmt = "%.1f"},
    {key = "evJitter",  lbl = "Evade Jitter",  mn = 0,    mx = 5,   fmt = "%.1f"},
    {key = "maxDist",   lbl = "Max Dist",      mn = 100,  mx = 8000, fmt = "%.0f"},
    {key = "crossSize", lbl = "Cross Size",    mn = 4,    mx = 30,  fmt = "%.0f"},
    {key = "rainbowSpd",lbl = "Rainbow Spd",   mn = 0.5,  mx = 10,  fmt = "%.1f"},
}
local sliders = {}
for i, s in ipairs(sliderDefs) do
    local y = 112 + (i - 1) * 25
    local lbl = Txt(Vector2.new(30, y), 11)
    lbl.Color = Color3.new(0.8, 0.8, 0.8); lbl.Text = s.lbl; lbl.Visible = false
    local bg = NewDraw("Square")
    bg.Filled = true; bg.Color = Color3.new(0.15, 0.15, 0.2)
    bg.Size = Vector2.new(130, 8); bg.Position = Vector2.new(175, y + 3); bg.Visible = false
    local fl = NewDraw("Square")
    fl.Filled = true; fl.Color = Color3.fromHSV(i / #sliderDefs, 0.7, 0.9)
    fl.Size = Vector2.new(65, 8); fl.Position = Vector2.new(175, y + 3); fl.Visible = false
    local vv = Txt(Vector2.new(310, y), 10); vv.Text = ""; vv.Visible = false
    sliders[i] = {lbl = lbl, bg = bg, fl = fl, vv = vv, def = s}
end

local togDefs = {
    {key = "flyOn",       lbl = "Fly"},
    {key = "snapOn",      lbl = "Snap TP"},
    {key = "evasionOn",   lbl = "Evasion"},
    {key = "voidProtect", lbl = "Void Save"},
    {key = "espOn",       lbl = "ESP"},
    {key = "crossOn",     lbl = "Crosshair"},
    {key = "backstab",    lbl = "Backstab"},
}
local toggles = {}
for i, tg in ipairs(togDefs) do
    local y = 112 + #sliderDefs * 25 + (i - 1) * 23
    local lbl = Txt(Vector2.new(30, y), 12)
    lbl.Color = Color3.new(0.8, 0.8, 0.8); lbl.Text = tg.lbl; lbl.Visible = false
    local box = NewDraw("Square")
    box.Filled = true; box.Size = Vector2.new(14, 14); box.Position = Vector2.new(290, y - 1)
    box.Color = Color3.new(1, 0, 0); box.Visible = false
    local st = Txt(Vector2.new(310, y - 1), 12); st.Text = "OFF"; st.Visible = false
    toggles[i] = {lbl = lbl, box = box, st = st, def = tg}
end

local function ShowGUI(s)
    guiOpen = s
    guiBG.Visible = s; guiTitle.Visible = s
    for _, sl in ipairs(sliders) do sl.lbl.Visible = s; sl.bg.Visible = s; sl.fl.Visible = s; sl.vv.Visible = s end
    for _, tg in ipairs(toggles) do tg.lbl.Visible = s; tg.box.Visible = s; tg.st.Visible = s end
end
local function RefreshGUI()
    for _, sl in ipairs(sliders) do
        local v = CFG[sl.def.key] or 0
        local pct = clamp((v - sl.def.mn) / (sl.def.mx - sl.def.mn), 0, 1)
        sl.fl.Size = Vector2.new(pct * 130, 8)
        sl.vv.Text = string.format(sl.def.fmt, v)
    end
    for _, tg in ipairs(toggles) do
        local on = CFG[tg.def.key]
        tg.box.Color = on and Color3.new(0, 1, 0) or Color3.new(1, 0, 0)
        tg.st.Text = on and "ON" or "OFF"
    end
end
RefreshGUI()

local function DestroyAll()
    ALIVE = false
    for _, d in ipairs(draws) do pcall(function() d:Remove() end) end
    print("[rage] DESTROYED")
end

-- mouse pos via Matcha-safe method
local function MousePos()
    local ok, m = pcall(function() return LP:GetMouse() end)
    if ok and m then
        local ox, oy = pcall(function() return m.X, m.Y end)
        -- m.X / m.Y access pattern varies; try both
        local okx, x = pcall(function() return m.X end)
        local oky, y = pcall(function() return m.Y end)
        if okx and oky and x and y then return x, y end
    end
    return nil, nil
end

-- ══════ SINGLE MAIN LOOP (no threads, everything polled here) ══════
print("[rage] ready — F3=rage  F2=menu  F8=destroy")

while ALIVE do
    local now = tick()

    -- key polling with debounce
    local f2 = false; pcall(function() f2 = iskeypressed(VK_F2) end)
    local f3 = false; pcall(function() f3 = iskeypressed(VK_F3) end)
    local f8 = false; pcall(function() f8 = iskeypressed(VK_F8) end)

    if f8 and now - dF8 > 0.5 then
        dF8 = now
        DestroyAll()
        break
    end
    if f2 and now - dF2 > 0.4 then
        dF2 = now
        ShowGUI(not guiOpen)
        print("[rage] menu " .. (guiOpen and "OPEN" or "CLOSED"))
    end
    if f3 and now - dF3 > 0.4 then
        dF3 = now
        rageOn = not rageOn
        if not rageOn then
            curTarget = nil
            -- stop velocity when turning off
            local r = Root(LP.Character)
            if r then pcall(function() r.AssemblyLinearVelocity = Vector3.new(0, 0, 0) end) end
        end
        print("[rage] RAGE " .. (rageOn and "ON" or "OFF"))
    end

    -- GUI clicks (only when open)
    if guiOpen then
        local held = false; pcall(function() held = ismouse1pressed() end)
        if held and now - dClick > 0.15 then
            local mx, my = MousePos()
            if mx and my then
                local used = false
                for i, sl in ipairs(sliders) do
                    local bx, by = 175, 112 + (i - 1) * 25 + 3
                    if mx >= bx - 4 and mx <= bx + 134 and my >= by - 6 and my <= by + 14 then
                        local pct = clamp((mx - bx) / 130, 0, 1)
                        local v = sl.def.mn + pct * (sl.def.mx - sl.def.mn)
                        if sl.def.fmt == "%.0f" then v = math.floor(v + 0.5) end
                        CFG[sl.def.key] = v
                        RefreshGUI()
                        dClick = now; used = true
                        print("[rage] " .. sl.def.lbl .. " = " .. v)
                        break
                    end
                end
                if not used then
                    for i, tg in ipairs(toggles) do
                        local tx, ty = 290, 112 + #sliderDefs * 25 + (i - 1) * 23 - 1
                        if mx >= tx - 10 and mx <= tx + 40 and my >= ty - 6 and my <= ty + 20 then
                            CFG[tg.def.key] = not CFG[tg.def.key]
                            RefreshGUI()
                            dClick = now
                            print("[rage] " .. tg.def.lbl .. " = " .. tostring(CFG[tg.def.key]))
                            break
                        end
                    end
                end
            end
        end
    end

    -- combat only when rageOn
    if rageOn then
        -- weapon mods throttled (2x per second, not every frame)
        if now - lastMods > 0.5 then
            lastMods = now
            pcall(function()
                setgc({
                    FireRate = 0, FireCooldown = 0,
                    AttackCooldown = 0, AttackRate = CFG.atkCD,
                    MeleeCooldown = CFG.atkCD, SwingCooldown = 0, SwingRate = 0,
                    DashCooldown = CFG.dashCD,
                    RecoilAmount = 0, SpreadAngle = 0, CameraRecoilMult = 0,
                    AimSpreadPenalty = 0, WeaponSpread = 0, HipSpread = 0,
                    SpreadMultiplier = 0, RecoilVertical = 0, RecoilHorizontal = 0,
                    MeleeRange = CFG.meleeBox, HitboxSize = CFG.meleeBox,
                    AttackRange = CFG.meleeBox, Reach = CFG.meleeBox,
                    ReloadTime = 0, EquipSpeed = 0,
                })
            end)
        end

        local myRoot = Root(LP.Character)
        if myRoot then
            local ok, myPos = pcall(function() return myRoot.Position end)
            if ok and myPos then
                -- void save (only while raging, straight up — no random sideways TP)
                if CFG.voidProtect and myPos.Y < CFG.voidY then
                    pcall(function() myRoot.Position = Vector3.new(myPos.X, CFG.safeY, myPos.Z) end)
                    pcall(function() myRoot.AssemblyLinearVelocity = Vector3.new(0, 0, 0) end)
                    print("[rage] void saved")
                end

                if (now - respawnTick) > 1.0 then
                    if now - lastSwitch > 0.2 or not curTarget or not Alive(curTarget) then
                        local t = Nearest(myPos)
                        if t then curTarget = t; lastSwitch = now else curTarget = nil end
                    end
                    if curTarget and Alive(curTarget) then
                        local part = Part(curTarget.Character)
                        if part then
                            local ok2, tPos = pcall(function() return part.Position end)
                            if ok2 and tPos then
                                -- fly (velocity only; snap only if toggle on)
                                if CFG.flyOn then
                                    local delta = tPos - myPos
                                    if delta.Magnitude > 0.5 then
                                        local dir = delta.Unit
                                        local want = tPos - dir * CFG.keepDist + Vector3.new(0, CFG.heightOff, 0)
                                        if CFG.evasionOn then
                                            flyAngle = flyAngle + CFG.evSpeed * 0.03
                                            want = want + Vector3.new(
                                                math.cos(flyAngle) * CFG.evRadius,
                                                math.sin(flyAngle * 2.7) * CFG.evJitter,
                                                math.sin(flyAngle) * CFG.evRadius
                                            )
                                        end
                                        local mv = want - myPos
                                        if mv.Magnitude > 0.3 then
                                            local vel = mv.Unit * clamp(mv.Magnitude * CFG.flySpeed, 40, 600)
                                            pcall(function() myRoot.AssemblyLinearVelocity = vel end)
                                            if CFG.snapOn and mv.Magnitude < 25 then
                                                pcall(function() myRoot.Position = want end)
                                            end
                                        end
                                    end
                                end
                                -- aim every frame
                                local okc, cp = pcall(function() return Camera.Position end)
                                if okc and cp then pcall(function() Camera.lookAt(cp, tPos) end) end
                                -- fire
                                if now - lastFire >= CFG.fireDelay then
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

    -- HUD
    if rageOn then
        hud1.Text = "[ RAGE: ON ]  F3=off  F2=menu  F8=kill"
        hud1.Color = Color3.new(0, 1, 0)
    else
        hud1.Text = "[ RAGE: OFF ]  F3=on  F2=menu  F8=kill"
        hud1.Color = Color3.new(1, 0.3, 0.3)
    end
    if curTarget and rageOn and Alive(curTarget) then
        local n = "?"; pcall(function() n = curTarget.Name end)
        hud2.Text = "Target: " .. n; hud2.Color = Color3.new(1, 1, 0)
    else
        hud2.Text = rageOn and "Target: none" or "Press F3 to start"
        hud2.Color = Color3.new(0.5, 0.5, 0.5)
    end
    local mhp = "?"; local h = Hum(LP.Character)
    if h then pcall(function() mhp = math.floor(h.Health) end) end
    hud3.Text = "HP: " .. mhp

    -- ESP
    if CFG.espOn and rageOn and curTarget and Alive(curTarget) then
        local char = curTarget.Character
        local hrp = char and Root(char)
        local ok, tPos = hrp and pcall(function() return hrp.Position end)
        if ok and tPos then
            local sp, vis = WorldToScreen(tPos)
            if vis then
                local head = char:FindFirstChild("Head")
                local hy = sp.Y
                if head then
                    local okh, hp2 = pcall(function() return head.Position end)
                    if okh and hp2 then hy = WorldToScreen(hp2 + Vector3.new(0, 1.5, 0)).Y end
                end
                local fs = WorldToScreen(tPos - Vector3.new(0, 3, 0))
                local bH = math.abs(fs.Y - hy); local bW = bH * 0.6
                espBox.Position = Vector2.new(sp.X - bW / 2, hy)
                espBox.Size = Vector2.new(bW, bH)
                espBox.Color = Color3.new(1, 0, 0); espBox.Visible = true
                espName.Position = Vector2.new(sp.X, hy - 16)
                espName.Text = curTarget.Name; espName.Visible = true
                espHP.Position = Vector2.new(sp.X, fs.Y + 4)
                local hh = Hum(char); local hpv, mhv = 100, 100
                if hh then pcall(function() hpv = hh.Health end); pcall(function() mhv = hh.MaxHealth end) end
                local pct = clamp(hpv / mhv, 0, 1)
                espHP.Text = math.floor(hpv) .. "/" .. math.floor(mhv)
                espHP.Color = Color3.new(1 - pct, pct, 0); espHP.Visible = true
                local vp = Camera.ViewportSize
                espLine.From = Vector2.new(vp.X / 2, vp.Y / 2); espLine.To = sp
                espLine.Color = Color3.new(1, 0, 0); espLine.Visible = true
            else
                espBox.Visible = false; espName.Visible = false; espHP.Visible = false; espLine.Visible = false
            end
        else
            espBox.Visible = false; espName.Visible = false; espHP.Visible = false; espLine.Visible = false
        end
    else
        espBox.Visible = false; espName.Visible = false; espHP.Visible = false; espLine.Visible = false
    end

    -- crosshair
    if CFG.crossOn then
        local vp = Camera.ViewportSize
        local cx, cy = vp.X / 2, vp.Y / 2
        crossAng = crossAng + CFG.rainbowSpd * 0.05
        local hue = (crossAng * 0.1) % 1
        for i = 1, 4 do
            local a = crossAng + (i - 1) * math.pi / 2
            cross[i].From = Vector2.new(cx + math.cos(a) * 4, cy + math.sin(a) * 4)
            cross[i].To = Vector2.new(cx + math.cos(a) * (4 + CFG.crossSize), cy + math.sin(a) * (4 + CFG.crossSize))
            cross[i].Color = Color3.fromHSV((hue + (i - 1) * 0.25) % 1, 1, 1)
            cross[i].Visible = true
        end
        crossDot.Position = Vector2.new(cx, cy)
        crossDot.Color = Color3.fromHSV(hue, 1, 1); crossDot.Visible = true
    else
        for i = 1, 4 do cross[i].Visible = false end
        crossDot.Visible = false
    end

    wait()
end
