local plugin = {}

plugin.name = "PM64R Crowd Control"
plugin.author = "Phantom5800"
plugin.settings = 
{
    { name='invertcontrols', type='file', label='Invert Controls Enabled' },
    { name='slowgoenabled', type='file', label='Slow Go Enabled' },
    { name='sethp', type='file', label='Set HP Value'},
    { name='setfp', type='file', label='Set FP Value'},
    { name='addcoins', type='file', label='Add Coins'}
}

plugin.description =
[[
    Trigger ingame events for Paper Mario when specific files are created.
]]

playerDataStructAddr    = 0x8010F290
playerDataCurrHPOffset  = 0x2
playerDataMaxHPOffset   = 0x3
playerDataCurrFPOffset  = 0x5
playerDataMaxFPOffset   = 0x6
playerDataCoinOffset    = 0xC
playerDataSPOffset      = 0x10
playerDataParnerOffset  = 0x12

equippedBadgesTableAddr = 0x8010F498

function math.clamp(n, low, high) return math.min(math.max(n, low), high) end

-- helper function to force specific badges on/off
function plugin.set_badge(badge_id, enabled)
    isBadgeEnabled = false
    equippedBadgeAddress = 0
    shiftBadges = false
    for i=0,64 do
        currentAddress = equippedBadgesTableAddr + i * 2 -- equipped badges are 2 byte ids
        current_badge = memory.read_s16_be(currentAddress)

        -- move current badge into previous slot
        if shiftBadges then
            previousAddress = currentAddress - 2
            memory.write_s16_be(previousAddress, current_badge)
            memory.write_s16_be(currentAddress, 0)
        end

        if current_badge == badge_id then
            -- remove equipped badge
            if not enabled then
                memory.write_s16_be(currentAddress, 0)
                shiftBadges = true
            end

            isBadgeEnabled = true
            equippedBadgeAddress = currentAddress
            -- if badge has been removed, remaining badges need to shift over
            if not shiftBadges then
                break
            end
        end
    end

    -- add badge to equipped list if it is not currently enabled
    if not isBadgeEnabled and enabled then
        for i=0,64 do
            currentAddress = equippedBadgesTableAddr + i * 2 -- equipped badges are 2 byte ids
            current_badge = memory.read_s16_be(currentAddress)
            if current_badge == 0 then
                memory.write_s16_be(currentAddress, badge_id) -- write badge into the first empty slot found
                break
            end
        end
    end
end

-- called each frame
function plugin.on_frame(data, settings)
    gamemode = memory.read_s8(0x800A08F1)
    -- game mode 4 is "world"
    -- game mode 8 is "battle"
    if gamemode == 4 or gamemode == 8 then
        -- check if Slow Go should be enabled
        -- lifetime of this file should be controlled externally
        if settings.slowgoenabled then
            foundfile = false
            local fn, err = io.open(settings.slowgoenabled, 'r')
            if fn ~= nil then
                foundfile = true
                fn:close()
            end

            if foundfile then
                -- force enable slow go badge effect
                plugin.set_badge(0xf7, true)
            else
                -- force disable slow go badge effect
                plugin.set_badge(0xf7, false)
            end
        end

        -- check if there is a SetHP file
        if settings.sethp then
            foundfile = false
            hpvalue = 0
            local fn, err = io.open(settings.sethp, 'r')
            if fn ~= nil then
                foundfile = true
                hpvalue = fn:read("*number")
                fn:close()
            end

            if foundfile then
                -- clamp hp and set value
                maxhp = memory.read_s8(playerDataStructAddr + playerDataMaxHPOffset)
                hpvalue = math.clamp(hpvalue, 1, maxhp)
                memory.write_s8(playerDataStructAddr + playerDataCurrHPOffset, hpvalue)
                os.remove(settings.sethp)
            end
        end

        -- check if there is a SetFP file
        if settings.setfp then
            foundfile = false
            fpvalue = 0
            local fn, err = io.open(settings.setfp, 'r')
            if fn ~= nil then
                foundfile = true
                fpvalue = fn:read("*number")
                fn:close()
            end

            if foundfile then
                -- clamp fp and set value
                maxfp = memory.read_s8(playerDataStructAddr + playerDataMaxFPOffset)
                fpvalue = math.clamp(fpvalue, 0, maxfp)
                memory.write_s8(playerDataStructAddr + playerDataCurrFPOffset, fpvalue)
                os.remove(settings.setfp)
            end
        end

        -- check if there is an AddCoins file
        if settings.addcoins then
            foundfile = false
            coinvalue = 0
            local fn, err = io.open(settings.addcoins, 'r')
            if fn ~= nil then
                foundfile = true
                coinvalue = fn:read("*number")
                fn:close()
            end

            if foundfile then
                -- clamp coins and set value (coinvalue could be negative)
                currentcoins = memory.read_s16_be(playerDataStructAddr + playerDataCoinOffset)
                coinvalue = math.clamp(currentcoins + coinvalue, 0, 999)
                memory.write_s16_be(playerDataStructAddr + playerDataCoinOffset, coinvalue)
                os.remove(settings.addcoins)
            end
        end
    end
end

return plugin
