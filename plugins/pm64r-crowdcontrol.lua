local plugin = {}

plugin.name = "PM64R Crowd Control"
plugin.author = "Phantom5800"
plugin.settings = 
{
    { name='slowgoenabled', type='file', label='Slow Go Enabled' },
    { name='sethp', type='file', label='Set HP Value'},
    { name='setfp', type='file', label='Set FP Value'}
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

function math.clamp(n, low, high) return math.min(math.max(n, low), high) end

-- called each frame
function plugin.on_frame(data, settings)
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
        else
            -- force disable slow go badge effect
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
end

return plugin
