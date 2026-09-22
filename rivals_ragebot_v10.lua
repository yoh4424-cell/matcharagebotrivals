--[[
    MATCHA RAGEBOT v9 — RIVALS (FFA)
    Inspired by: Unnamed Enhancement + KiciaHook v3
    PlaceId: 17625359962 | Nosniy Games
    
    One-liner:
    loadstring(game:HttpGet("https://raw.githubusercontent.com/yoh4424-cell/matcharagebotrivals/main/rivals_ragebot.lua"))()
    
    F2 = Settings GUI    F8 = Destroy script
]]

-- Wait for game to load (defensive - Matcha GetService can return nil early)
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

local UIS = nil
pcall(function() UIS = game:GetService("UserInputService") end)

local RS = nil
pcall(function() RS = game:GetService("RunService") end)

local LP = nil
for _ = 1, 200 do
    if not Players then
        pcall(function() Players = game:GetService("Players") end)
    end
    if Players then
        pcall(function() LP = Players.LocalPlayer end)
    end
    if LP then break end
    wait()
end

local Camera = nil
pcall(function() Camera = Workspace.CurrentCamera end)

local ALIVE = true
local allConns = {}
local allDraws = {}

local function AddConn(c) table.insert(allConns, c) end
local function AddDraw(d) table.insert(allDraws, d) return d end

local curTarget = nil
local lastFire = 0
local lastSwitch = 0
local respawnTick = tick()
local flyAngle = 0
local guiOpen = false

print("[ragebot] v9 loading...")

-- ══════════════════════════════════════════════════════════════
-- CONFIG
-- ══════════════════════════════════════════════════════════════
local CFG = {
    fireDelay    = 0.03,
    maxDist      = 3500,
    flySpeed     = 8.0,
    keepDist     = 2.5,
    heightOff    = 1.2,
    evasionOn    = true,
    evRadius     = 3.5,
    evSpeed      = 12.0,
    evJitter     = 1.2,
    voidProtect  = true,
    voidY        = -30,
    safeSpotY    = 200,
    espOn        = true,
    crossOn      = true,
    rainbowSpd   = 3.0,
    crossSize    = 12,
    meleeHitbox  = 15,
    dashSpeed    = 0.05,
    attackSpeed  = 0.03,
    backstab     = true,
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
    for _, n in ipairs({"Head","HumanoidRootPart","UpperTorso","Torso"}) do
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
                    if d < bestD then bestD=d; best=plr; bestP=p end
                end
            end
        end
    end
    return best, bestP, bestD
end

local function SafePos()
    local x, z = 50, 50
    local r = Root(LP.Character)
    if r then
        local ok, pos = pcall(function() return r.Position end)
        if ok and pos then x = pos.X + 50; z = pos.Z + 50 end
    end
    return Vector3.new(x, CFG.safeSpotY, z)
end

-- ══════════════════════════════════════════════════════════════
-- DESTROY
-- ══════════════════════════════════════════════════════════════
local function FullDestroy()
    ALIVE = false
    for _, c in ipairs(allConns) do pcall(function() c:Disconnect() end) end
    for _, d in ipairs(allDraws) do pcall(function() d:Remove() end) end
    allConns = {}
    allDraws = {}
    print("[ragebot] DESTROYED")
end

-- ══════════════════════════════════════════════════════════════
-- DRAWING HELPERS
-- ══════════════════════════════════════════════════════════════
local function MakeText(pos, size, col)
    local t = AddDraw(Drawing.new("Text"))
    t.Position = pos; t.Size = size; t.Font = Drawing.Fonts.Monospace
    t.Outline = true; t.Color = col or Color3.new(1,1,1); t.Visible = true
    return t
end

-- ══════════════════════════════════════════════════════════════
-- HUD
-- ══════════════════════════════════════════════════════════════
local hud1 = MakeText(Vector2.new(20, 10), 16, Color3.new(0,1,0))
local hud2 = MakeText(Vector2.new(20, 30), 13, Color3.new(1,1,0))
local hud3 = MakeText(Vector2.new(20, 48), 12, Color3.new(0,1,0))

local function UpdateHUD()
    hud1.Text = "[ RIVALS RAGE v9 ]  F2=menu  F8=destroy"
    hud1.Color = Color3.fromHSV(tick()*0.1%1, 1, 1)
    if curTarget and Alive(curTarget) then
        local n = ""
        pcall(function() n = curTarget.Name end)
        local d = 0
        local mr = Root(LP.Character)
        local ok, pp = pcall(function() return Part(curTarget.Character) end)
        if ok and pp and pp.Position and mr then d = math.floor((pp.Position - mr.Position).Magnitude) end
        local hp,mh = 100,100
        local h = Hum(curTarget.Character)
        if h then pcall(function() hp=math.floor(h.Health) end); pcall(function() mh=math.floor(h.MaxHealth) end) end
        hud2.Text = n .. " [" .. d .. "m] HP:" .. hp .. "/" .. mh
        hud2.Color = Color3.new(1,1,0)
    else
        hud2.Text = "no target"; hud2.Color = Color3.new(0.5,0.5,0.5)
    end
    local mhp = "?"
    local h = Hum(LP.Character)
    if h then pcall(function() mhp=math.floor(h.Health) end) end
    hud3.Text = "HP: " .. mhp
end

-- ══════════════════════════════════════════════════════════════
-- ESP
-- ══════════════════════════════════════════════════════════════
local espBox = AddDraw(Drawing.new("Square"))
espBox.Filled = false; espBox.Thickness = 2; espBox.Visible = false
local espName = AddDraw(Drawing.new("Text"))
espName.Size = 14; espName.Font = Drawing.Fonts.Monospace; espName.Center = true; espName.Outline = true; espName.Visible = false
local espHP = AddDraw(Drawing.new("Text"))
espHP.Size = 12; espHP.Font = Drawing.Fonts.Monospace; espHP.Center = true; espHP.Outline = true; espHP.Visible = false
local espLine = AddDraw(Drawing.new("Line"))
espLine.Thickness = 1; espLine.Visible = false

local function UpdateESP()
    if not CFG.espOn or not curTarget or not Alive(curTarget) then
        espBox.Visible=false; espName.Visible=false; espHP.Visible=false; espLine.Visible=false; return
    end
    local cam = Camera
    if not cam then return end
    local char = curTarget.Character
    if not char then espBox.Visible=false; espName.Visible=false; espHP.Visible=false; espLine.Visible=false; return end
    local hrp = Root(char)
    if not hrp then espBox.Visible=false; espName.Visible=false; espHP.Visible=false; espLine.Visible=false; return end
    local ok, tPos = pcall(function() return hrp.Position end)
    if not ok or not tPos then espBox.Visible=false; espName.Visible=false; espHP.Visible=false; espLine.Visible=false; return end
    local sp, vis = WorldToScreen(tPos)
    if not vis then espBox.Visible=false; espName.Visible=false; espHP.Visible=false; espLine.Visible=false; return end
    local headPart = char:FindFirstChild("Head")
    local headY = sp.Y
    if headPart and headPart.Position then
        local hs = WorldToScreen(headPart.Position + Vector3.new(0,1.5,0))
        headY = hs.Y
    end
    local fs = WorldToScreen(tPos - Vector3.new(0,3,0))
    local bH = math.abs(fs.Y - headY); local bW = bH * 0.6
    espBox.Position = Vector2.new(sp.X - bW/2, headY); espBox.Size = Vector2.new(bW, bH)
    espBox.Color = Color3.new(1,0,0); espBox.Visible = true
    espName.Position = Vector2.new(sp.X, headY - 16); espName.Text = curTarget.Name
    espName.Color = Color3.new(1,1,1); espName.Visible = true
    local hum = Hum(char); local hp,mh = 100,100
    if hum then pcall(function() hp=hum.Health end); pcall(function() mh=hum.MaxHealth end) end
    local pct = math.clamp(hp/mh,0,1)
    espHP.Position = Vector2.new(sp.X, fs.Y+4); espHP.Text = math.floor(hp).."/"..math.floor(mh)
    espHP.Color = Color3.new(1-pct,pct,0); espHP.Visible = true
    local vp = cam.ViewportSize
    espLine.From = Vector2.new(vp.X/2, vp.Y/2); espLine.To = sp
    espLine.Color = Color3.new(1,0,0); espLine.Visible = true
end

-- ══════════════════════════════════════════════════════════════
-- RAINBOW CROSSHAIR
-- ══════════════════════════════════════════════════════════════
local crossLines = {}
for i = 1, 4 do
    crossLines[i] = AddDraw(Drawing.new("Line"))
    crossLines[i].Thickness = 2; crossLines[i].Visible = false
end
local crossDot = AddDraw(Drawing.new("Circle"))
crossDot.Filled = true; crossDot.Radius = 2; crossDot.Visible = false
local crossAng = 0

local function UpdateCross()
    if not CFG.crossOn then
        for i = 1, 4 do crossLines[i].Visible = false end
        crossDot.Visible = false; return
    end
    local vp = Camera.ViewportSize; local cx,cy = vp.X/2, vp.Y/2
    crossAng = crossAng + CFG.rainbowSpd * 0.05
    local hue = (crossAng * 0.1) % 1
    local sz = CFG.crossSize; local gap = 4
    for i = 1, 4 do
        local a = crossAng + (i-1)*math.pi/2
        crossLines[i].From = Vector2.new(cx+math.cos(a)*gap, cy+math.sin(a)*gap)
        crossLines[i].To = Vector2.new(cx+math.cos(a)*(gap+sz), cy+math.sin(a)*(gap+sz))
        crossLines[i].Color = Color3.fromHSV((hue+(i-1)*0.25)%1, 1, 1)
        crossLines[i].Visible = true
    end
    crossDot.Position = Vector2.new(cx,cy)
    crossDot.Color = Color3.fromHSV(hue,1,1); crossDot.Visible = true
end

-- ══════════════════════════════════════════════════════════════
-- SETTINGS GUI (F2)
-- ══════════════════════════════════════════════════════════════
local guiBG = AddDraw(Drawing.new("Square"))
guiBG.Filled = true; guiBG.Color = Color3.new(0.06,0.06,0.1); guiBG.Transparency = 0.93
guiBG.Size = Vector2.new(360, 520); guiBG.Position = Vector2.new(20, 80); guiBG.Visible = false
local guiTitle = AddDraw(Drawing.new("Text"))
guiTitle.Position = Vector2.new(50, 88); guiTitle.Size = 16; guiTitle.Font = Drawing.Fonts.Monospace
guiTitle.Color = Color3.fromHSV(0,0,1); guiTitle.Outline = true; guiTitle.Text = "RAGEBOT SETTINGS v9"; guiTitle.Visible = false

local sliders = {}
local sliderData = {
    {key="fireDelay",    lbl="Fire Delay (s)",    mn=0.01, mx=0.3,  fmt="%.2f"},
    {key="attackSpeed",  lbl="Melee Speed (s)",   mn=0.01, mx=0.3,  fmt="%.2f"},
    {key="dashSpeed",    lbl="Dash Cooldown (s)",  mn=0.01, mx=0.5,  fmt="%.2f"},
    {key="meleeHitbox",  lbl="Melee Hitbox",       mn=1,    mx=30,   fmt="%.0f"},
    {key="flySpeed",     lbl="Fly Speed",          mn=1,    mx=15,   fmt="%.1f"},
    {key="keepDist",     lbl="Keep Distance",      mn=0.5,  mx=10,   fmt="%.1f"},
    {key="heightOff",    lbl="Height Offset",      mn=-2,   mx=8,    fmt="%.1f"},
    {key="evRadius",     lbl="Evasion Radius",     mn=0.5,  mx=10,   fmt="%.1f"},
    {key="evSpeed",      lbl="Evasion Speed",      mn=1,    mx=20,   fmt="%.1f"},
    {key="evJitter",     lbl="Evasion Jitter",     mn=0,    mx=5,    fmt="%.1f"},
    {key="maxDist",      lbl="Max Distance",       mn=100,  mx=8000, fmt="%.0f"},
    {key="crossSize",    lbl="Crosshair Size",     mn=4,    mx=30,   fmt="%.0f"},
    {key="rainbowSpd",   lbl="Rainbow Speed",      mn=0.5,  mx=10,   fmt="%.1f"},
}

for i, s in ipairs(sliderData) do
    local y = 112 + (i-1)*26
    local lbl = AddDraw(Drawing.new("Text"))
    lbl.Position = Vector2.new(30, y); lbl.Size = 11; lbl.Font = Drawing.Fonts.Monospace
    lbl.Color = Color3.new(0.8,0.8,0.8); lbl.Outline = true; lbl.Text = s.lbl; lbl.Visible = false
    local barBG = AddDraw(Drawing.new("Square"))
    barBG.Filled = true; barBG.Color = Color3.new(0.15,0.15,0.2)
    barBG.Size = Vector2.new(130, 8); barBG.Position = Vector2.new(175, y+3); barBG.Visible = false
    local barFill = AddDraw(Drawing.new("Square"))
    barFill.Filled = true; barFill.Color = Color3.fromHSV(i/#sliderData, 0.7, 0.9)
    local v = CFG[s.key] or 0; local pct = (v-s.mn)/(s.mx-s.mn)
    barFill.Size = Vector2.new(math.clamp(pct*130,0,130), 8); barFill.Position = Vector2.new(175, y+3); barFill.Visible = false
    local val = AddDraw(Drawing.new("Text"))
    val.Position = Vector2.new(310, y); val.Size = 10; val.Font = Drawing.Fonts.Monospace
    val.Color = Color3.new(1,1,1); val.Outline = true; val.Text = string.format(s.fmt, v); val.Visible = false
    sliders[i] = {lbl=lbl, barBG=barBG, barFill=barFill, val=val, data=s}
end

local toggles = {}
local togData = {
    {key="evasionOn",   lbl="Evasion"},
    {key="voidProtect", lbl="Void Protect"},
    {key="espOn",       lbl="ESP"},
    {key="crossOn",     lbl="Crosshair"},
    {key="backstab",    lbl="Always Backstab"},
}
for i, tg in ipairs(togData) do
    local y = 112 + #sliderData*26 + (i-1)*24
    local lbl = AddDraw(Drawing.new("Text"))
    lbl.Position = Vector2.new(30, y); lbl.Size = 12; lbl.Font = Drawing.Fonts.Monospace
    lbl.Color = Color3.new(0.8,0.8,0.8); lbl.Outline = true; lbl.Text = tg.lbl; lbl.Visible = false
    local box = AddDraw(Drawing.new("Square"))
    box.Filled = true; box.Size = Vector2.new(14,14); box.Position = Vector2.new(290, y-1)
    box.Color = CFG[tg.key] and Color3.new(0,1,0) or Color3.new(1,0,0); box.Visible = false
    local stxt = AddDraw(Drawing.new("Text"))
    stxt.Position = Vector2.new(310, y-1); stxt.Size = 12; stxt.Font = Drawing.Fonts.Monospace
    stxt.Color = Color3.new(1,1,1); stxt.Outline = true
    stxt.Text = CFG[tg.key] and "ON" or "OFF"; stxt.Visible = false
    toggles[i] = {lbl=lbl, box=box, stxt=stxt, data=tg}
end

local function ShowGUI(s)
    guiOpen = s; guiBG.Visible = s; guiTitle.Visible = s
    for _, sl in ipairs(sliders) do sl.lbl.Visible=s; sl.barBG.Visible=s; sl.barFill.Visible=s; sl.val.Visible=s end
    for _, tg in ipairs(toggles) do tg.lbl.Visible=s; tg.box.Visible=s; tg.stxt.Visible=s end
end

local function RefreshGUI()
    for _, sl in ipairs(sliders) do
        local v = CFG[sl.data.key] or 0; local pct = (v-sl.data.mn)/(sl.data.mx-sl.data.mn)
        sl.barFill.Size = Vector2.new(math.clamp(pct*130,0,130), 8)
        sl.val.Text = string.format(sl.data.fmt, v)
    end
    for _, tg in ipairs(toggles) do
        tg.box.Color = CFG[tg.data.key] and Color3.new(0,1,0) or Color3.new(1,0,0)
        tg.stxt.Text = CFG[tg.data.key] and "ON" or "OFF"
    end
end

-- ══════════════════════════════════════════════════════════════
-- AIM: perfect lock + silent aim support
-- ══════════════════════════════════════════════════════════════
local function AimAt(pos)
    local ok, cp = pcall(function() return Camera.Position end)
    if ok and cp then
        pcall(function() Camera.lookAt(cp, pos) end)
    end
end

-- ══════════════════════════════════════════════════════════════
-- FLY
-- ══════════════════════════════════════════════════════════════
local function FlyTo(root, tPos)
    local ok, myPos = pcall(function() return root.Position end)
    if not ok or not myPos then return end
    local delta = tPos - myPos
    if delta.Magnitude < 0.5 then return end
    local dir = delta.Unit
    local desired = tPos - dir * CFG.keepDist + Vector3.new(0, CFG.heightOff, 0)
    if CFG.evasionOn then
        flyAngle = flyAngle + CFG.evSpeed * 0.03
        desired = desired + Vector3.new(
            math.cos(flyAngle)*CFG.evRadius,
            math.sin(flyAngle*2.7)*CFG.evJitter,
            math.sin(flyAngle)*CFG.evRadius
        )
    end
    local mv = desired - myPos
    if mv.Magnitude < 0.3 then return end
    local vel = mv.Unit * math.clamp(mv.Magnitude * CFG.flySpeed, 40, 600)
    pcall(function() root.AssemblyLinearVelocity = vel end)
    if mv.Magnitude < 80 then pcall(function() root.Position = desired end) end
end

-- ══════════════════════════════════════════════════════════════
-- WEAPON MODS via setgc (KiciaHook style)
-- ══════════════════════════════════════════════════════════════
local function WeaponMods()
    pcall(function()
        setgc({
            -- Fire rate / cooldowns
            FireRate = 0,
            FireCooldown = 0,
            AttackCooldown = 0,
            AttackRate = CFG.attackSpeed,
            MeleeCooldown = CFG.attackSpeed,
            SwingCooldown = 0,
            SwingRate = 0,
            -- Dash
            DashCooldown = CFG.dashSpeed,
            DashSpeed = 100,
            DashDuration = 0.1,
            -- Recoil / spread (never miss)
            RecoilAmount = 0,
            RecoilVertical = 0,
            RecoilHorizontal = 0,
            CameraRecoilMult = 0,
            SpreadAngle = 0,
            AimSpreadPenalty = 0,
            SpreadMultiplier = 0,
            WeaponSpread = 0,
            HipSpread = 0,
            -- Melee hitbox extender
            MeleeRange = CFG.meleeHitbox,
            HitboxSize = CFG.meleeHitbox,
            MeleeHitboxExpand = CFG.meleeHitbox,
            AttackRange = CFG.meleeHitbox,
            Reach = CFG.meleeHitbox,
            -- Backstab
            IsBackstab = CFG.backstab and 1 or 0,
            BackstabDamage = 999,
            BackstabMultiplier = 10,
            -- General
            Damage = 999,
            HeadshotMultiplier = 10,
            ReloadTime = 0,
            EquipSpeed = 0,
            AimAssist = 1,
        })
    end)
end

-- ══════════════════════════════════════════════════════════════
-- VOID PROTECTION
-- ══════════════════════════════════════════════════════════════
local function VoidCheck()
    if not CFG.voidProtect then return end
    local r = Root(LP.Character)
    if not r then return end
    local ok, pos = pcall(function() return r.Position end)
    if ok and pos and pos.Y < CFG.voidY then
        local sp = SafePos()
        pcall(function() r.Position = sp end)
        pcall(function() r.AssemblyLinearVelocity = Vector3.new(0,0,0) end)
        print("[ragebot] void saved")
    end
end

-- ══════════════════════════════════════════════════════════════
-- INPUT
-- ══════════════════════════════════════════════════════════════
AddConn(UIS.InputBegan:Connect(function(input, gp)
    if not ALIVE then return end
    if input.KeyCode == Enum.KeyCode.F2 then ShowGUI(not guiOpen); return end
    if input.KeyCode == Enum.KeyCode.F8 then FullDestroy(); return end
    if guiOpen and input.UserInputType == Enum.UserInputType.MouseButton1 then
        local mx, my = input.Position.X, input.Position.Y
        for i, sl in ipairs(sliders) do
            local bx, by = 175, 112+(i-1)*26+3
            if mx>=bx and mx<=bx+130 and my>=by and my<=by+8 then
                local pct = math.clamp((mx-bx)/130, 0, 1)
                local v = sl.data.mn + pct*(sl.data.mx-sl.data.mn)
                if sl.data.fmt == "%.0f" then v = math.floor(v+0.5) end
                CFG[sl.data.key] = v; RefreshGUI()
                print("[ragebot] "..sl.data.lbl.." = "..v)
            end
        end
        for i, tg in ipairs(toggles) do
            local tx, ty = 290, 112+#sliderData*26+(i-1)*24-1
            if mx>=tx and mx<=tx+14 and my>=ty and my<=ty+14 then
                CFG[tg.data.key] = not CFG[tg.data.key]; RefreshGUI()
                print("[ragebot] "..tg.data.lbl.." = "..tostring(CFG[tg.data.key]))
            end
        end
    end
end))

-- FIXED: wrap CharacterAdded in pcall + use LP not lp
pcall(function()
    AddConn(LP.CharacterAdded:Connect(function()
        respawnTick = tick()
        curTarget = nil
        print("[ragebot] respawned")
    end))
end)

-- ══════════════════════════════════════════════════════════════
-- MAIN LOOP
-- ══════════════════════════════════════════════════════════════
print("[ragebot] v9 ready — F2=menu  F8=destroy")

while ALIVE do
    pcall(VoidCheck)
    pcall(WeaponMods)

    local myRoot = Root(LP.Character)
    if myRoot then
        local ok, myPos = pcall(function() return myRoot.Position end)
        if ok and myPos then
            local now = tick()
            if (now - respawnTick) > 1.0 then
                if now - lastSwitch > 0.15 or not curTarget or not Alive(curTarget) then
                    local t,p,d = Nearest(myPos)
                    if t then curTarget=t; lastSwitch=now else curTarget=nil end
                end
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
    end

    pcall(UpdateHUD)
    pcall(UpdateESP)
    pcall(UpdateCross)
    wait()
end
