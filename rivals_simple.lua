--[[
    RIVALS MODS ONLY — no teleport, no fly, no aim. Just fast hits.
    loadstring(game:HttpGet("https://raw.githubusercontent.com/yoh4424-cell/matcharagebotrivals/main/rivals_mods.lua"))()
    Runs on execute. F8 = stop.
]]

repeat wait() until game and pcall(function() return game:IsLoaded() end)

local F8 = 0x77
local ALIVE = true

print("[mods] loaded — fast melee/fire/dash active")

while ALIVE do
    local kill = false
    pcall(function() kill = iskeypressed(F8) end)
    if kill then
        ALIVE = false
        print("[mods] stopped")
        break
    end

    pcall(function()
        setgc({
            -- hit super fast: melee
            AttackCooldown = 0,
            MeleeCooldown = 0,
            SwingCooldown = 0,
            AttackRate = 0.01,
            SwingRate = 0,
            -- shoot super fast
            FireRate = 0,
            FireCooldown = 0,
            ReloadTime = 0,
            EquipSpeed = 0,
            -- dash + aim no cooldown
            DashCooldown = 0,
            AimCooldown = 0,
            -- knife hitbox extender
            MeleeRange = 9999,
            AttackRange = 9999,
            Reach = 9999,
            HitboxSize = 9999,
            -- always backstab, map-wide
            IsBackstab = 1,
            BackstabDamage = 999,
            BackstabMultiplier = 10,
            BackstabRange = 9999,
            -- never miss
            SpreadAngle = 0,
            RecoilAmount = 0,
        })
    end)

    wait(0.5)
end
