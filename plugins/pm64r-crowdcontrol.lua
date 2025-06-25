local plugin = {}

plugin.name = "PM64R Crowd Control"
plugin.author = "Phantom5800"
plugin.settings = 
{
    { name='addcoins',              type='file', label='Add Coins' },
    { name='disableallbadges',      type='file', label='Disable All Badges' },
    { name='disableheartblocks',    type='file', label='Disable Heart Blocks' },
    { name='disablesaveblocks',     type='file', label='Disable Save Blocks' },
    { name='disablespeedyspin',     type='file', label='Disable Speedy Spin' },
    { name='enableberserker',       type='file', label='Berserker Enabled' },
    { name='enableslowgo',          type='file', label='Slow Go Enabled' },
    { name='homewardshroom',        type='file', label='Homeward Shroom' },
    { name='ohkomode',              type='file', label='OHKO Mode' },
    { name='randompitch',           type='file', label='Random Pitch' },
    { name='sethomewardshroom',     type='file', label='Set Homeward Shroom Location' },
    { name='sethp',                 type='file', label='Set HP Value' },
    { name='setfp',                 type='file', label='Set FP Value' },
    { name='togglemirrormode',      type='file', label='Toggle Mirror Mode' }
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

gameStatusAddr          = 0x80074024
gameStatusAreaIdOffset  = 0x86 -- u16
gameStatusMapIdOffset   = 0x8C -- u16
gameStatusEntryIdOffset = 0x8E -- u16

equippedBadgesTableAddr = 0x8010F498
homewardShroomAddr      = 0x80450953
cutsceneValueAddr       = 0x8010EFCA

sqldbStartAddr  = 0x804C0000
startingMapKey  = 0xAF000000
doubleDamageKey = 0xAF020002
quadDamageKey   = 0xAF020003
ohkoModeKey     = 0xAF020004
noSaveBlockKey  = 0xAF020005
noHeartBlockKey = 0xAF020006
speedyKey       = 0xAF040004
ispyKey         = 0xAF040005
peekabooKey     = 0xAF040006
mirrorModeKey   = 0xAF02000D
randomPitchKey  = 0xAF070000

startingMapAddr     = nil
ohkomodeAddr        = nil
noSaveBlockAddr     = nil
noHeartBlockAddr    = nil
speedyAddr          = nil
mirrorModeAddr      = nil
randomPitchAddr     = nil

function math.clamp(n, low, high) return math.min(math.max(n, low), high) end

-- helper function to force specific badges on/off
function plugin.set_badge(badge_id, enabled)
    local isBadgeEnabled = false
    local equippedBadgeAddress = 0
    local shiftBadges = false
    for i=0,63 do -- 64 slots, Lua numeric for loops are inclusive
        local currentAddress = equippedBadgesTableAddr + i * 2 -- equipped badges are 2 byte ids
        local current_badge = memory.read_s16_be(currentAddress)

        -- move current badge into previous slot
        if shiftBadges then
            local previousAddress = currentAddress - 2
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
            -- if badge is supposed to stay on, break out early
            if not shiftBadges then
                break
            end
        end
    end

    -- add badge to equipped list if it is not currently enabled
    if not isBadgeEnabled and enabled then
        for i=0,63 do
            local currentAddress = equippedBadgesTableAddr + i * 2 -- equipped badges are 2 byte ids
            local current_badge = memory.read_s16_be(currentAddress)
            if current_badge == 0 then
                memory.write_s16_be(currentAddress, badge_id) -- write badge into the first empty slot found
                break
            end
        end
    end
end

function plugin.convert_to_valid_entrance(areaId, mapId, entranceId)
    -- if areaId is Toad Town
    if areaId == 1 then
        if mapId == 6 and entranceId == 2 then
            entranceId = 0 -- overwrite whale spout entrance
        end
    -- if areaId is Star Haven
    elseif areaId == 5 then
        if mapId == 4 then
            entranceId = 0 -- outside sanctuary, only use main entrance
        elseif mapId == 5 then
            entranceId = 0 -- inside sanctuary, only use door
        elseif mapId == 7 or mapId == 8 then
            areaId = -1 -- ignore space and flying maps
        elseif mapId == 0 and entranceId == 3 then
            entranceId = 0 -- ignore cutscene entrance
        end
    -- if areaId is KBF
    elseif areaId == 7 then
        if mapId == 0 and entranceId == 5 then
            entranceId = 0 -- overwrite Eldstar cutscene entrance
        end
    -- if areaId is Dry Dry Desert
    elseif areaId == 10 then
        if mapId == 2 then
            if entranceId == 2 or entranceId == 5 or entranceId == 6 or entranceId == 7 then
                entranceId = 0 -- overwrite a bunch of weird entrances outside ruins
            end
        end
    -- if areaId is Boo's Mansion
    elseif areaId == 13 then
        if mapId == 8 and entranceId == 2 then
            entranceId = 0 -- overwrite epilogue Bow's room cutscene
        end
    -- if areaId is Gusty Gulch
    elseif areaId == 14 then
        if mapId == 4 and entranceId == 3 then
            entranceId = 0 -- overwrite suspected Skolar cutscene
        end
    -- if areaId is Jade Jungle
    elseif areaId == 17 then
        -- check for if mapId + entranceId is a water entrance
        if mapId == 8 and entranceId == 1 then
            entranceId = 0 -- red yoshi room overwrite water entrance
        elseif mapId == 5 and entranceId == 1 then
            entranceId = 0 -- power quake room overwrite water entrance
        elseif mapId == 10 then
            areaId = -1 -- blue yoshi room is invalid
        elseif mapId == 9 and entranceId == 2 then
            entranceId = 0 -- water entrance in room with pipe
        end
    -- if areaId is volcano
    elseif areaId == 18 then
        if mapId == 13 then
            if entranceId == 2 or entranceId == 3 then
                entranceId = 0 -- overwrite bad entrances in LP room
            end
        elseif mapId >= 14 and mapId <= 16 then
            areaId = -1 -- ignore volcano escape sequence rooms
        end
    -- if areaId is Flower Fields
    elseif areaId == 19 then
        if mapId == 0 then
            entranceId = 0 -- hub room has a lot of bad entrances
        elseif mapId == 1 and entranceId == 2 then
            entranceId = 0 -- petunia room ignore machine cutscene entrance
        elseif mapId == 2 and entranceId == 1 then
            entranceId = 0 -- posie room ignore machine cutscene entrance
        elseif mapId == 5 and entranceId > 0 then
            entranceId = 0 -- ignore all of lily's cutscenes
        elseif mapId == 7 then
            entranceId = 0 -- ignore rosie machine cutscene entrance
        elseif mapId == 10 then
            entranceId = 0 -- ignore sun machine cutscene
        elseif mapId == 13 then
            entranceId = 0 -- ignore post machine conversation
        elseif mapId == 14 then
            entranceId = 0 -- ignore weird entrances in cloudy climb
        elseif mapId == 18 and entranceId == 2 then
            entranceId = 0 -- ignore bubble berry tree room filling with water
        end
    -- if areaId is Shiver Region
    elseif areaId == 20 then
        if mapId == 9 and entranceId == 2 then
            entranceId = 0 -- ignore star stone cave
        elseif mapId == 11 then
            areaId = -1 -- ignore star stone cave
        elseif mapId == 10 and entranceId == 2 then
            areaId = -1 -- ignore epilogue shiver city cutscene
        elseif mapId == 0 and entranceId == 1 then
            entranceId = 0 -- weird entrance in mayor's house
        end
    -- if areaId is Crystal Palace
    elseif areaId == 21 then
        if mapId == 0 and entranceId == 4 then
            entranceId = 0 -- Kalmar cutscene
        end
    -- if areaId is Bowser's Castle
    elseif areaId == 22 then
        -- check if mapId + entranceId is a water or lava entrance
        if mapId >= 6 and mapId <= 11 then
            areaId = -1 -- ignore lava rooms
        elseif mapId == 23 and entranceId == 2 then
            entranceId = 0 -- outside castle lava entrance
        elseif (mapId == 48 or mapId == 49) and entranceId == 2 then
            entranceId = 0 -- remove flood room water entrances
        end 
    -- if areaId is the Game Over screen
    elseif areaId == 26 then
        areaId = -1
    end

    return areaId, mapId, entranceId
end

function plugin.setup_addresses()
    local isSqlTable = true
    local offset = 0
    while isSqlTable do
        local currentAddress = sqldbStartAddr + offset * 4 * 2 -- size of key + skip over value
        local key = memory.read_u32_be(currentAddress)
        offset = offset + 1

        if (key & 0xA0000000) ~= 0xA0000000 then
            isSqlTable = false
        else
            if key == randomPitchKey then
                randomPitchAddr = currentAddress + 4
            elseif key == mirrorModeKey then
                mirrorModeAddr = currentAddress + 4
            elseif key == speedyKey then
                speedyAddr = currentAddress + 4
            elseif key == noSaveBlockKey then
                noSaveBlockAddr = currentAddress + 4
            elseif key == noHeartBlockKey then
                noHeartBlockAddr = currentAddress + 4
            elseif key == ohkoModeKey then
                ohkomodeAddr = currentAddress + 4
            elseif key == startingMapKey then
                startingMapAddr = currentAddress + 4
            end
        end
    end
end

function plugin.on_game_load(data, settings)
    plugin.setup_addresses()
end

-- called each frame
function plugin.on_frame(data, settings)
    local gamemode = memory.read_s8(0x800A08F1)
    local SPLASH_SCREEN = 1
    local GAMESTATE_WORLD = 4
    local GAMESTATE_BATTLE = 8

    -- code that only needs to run once on startup, like searching for arbitrary memory addresses
    -- can go here
    if gamemode == SPLASH_SCREEN then
        plugin.setup_addresses()
    end

    if gamemode == GAMESTATE_WORLD or gamemode == GAMESTATE_BATTLE then
        -- disable all badges, do before force enabling slow go
        if settings.disableallbadges then
            local foundfile = false
            local fn, err = io.open(settings.disableallbadges, 'r')
            if fn ~= nil then
                foundfile = true
                fn:close()
            end

            if foundfile then
                -- 0 out active badge array 4 bytes at a time
                for i=0,31 do
                    local currentAddress = equippedBadgesTableAddr + i * 4
                    memory.write_s32_be(currentAddress, 0)
                end
                os.remove(settings.disableallbadges)
            end
        end

        -- check if a badge should be enabled
        -- lifetime of these files should be controlled externally
        function enable_badge(setting, badge_id)
            if setting then
                local foundfile = false
                local fn, err = io.open(setting, 'r')
                if fn ~= nil then
                    foundfile = true
                    fn:close()
                end
    
                if foundfile then
                    -- force enable slow go badge effect
                    plugin.set_badge(badge_id, true)
                else
                    -- force disable slow go badge effect
                    plugin.set_badge(badge_id, false)
                end
            end
        end

        enable_badge(settings.enableberserker, 0x101)
        enable_badge(settings.enableslowgo, 0xf7)

        -- check if Random Pitch should be enabled
        -- lifetime of this file should be controlled externally
        if settings.randompitch and randomPitchAddr then
            local foundfile = false
            local fn, err = io.open(settings.randompitch, 'r')
            if fn ~= nil then
                foundfile = true
                fn:close()
            end

            if foundfile then
                -- force enable random pitch
                memory.write_u32_be(randomPitchAddr, 1)
            else
                -- force disable random pitch
                memory.write_u32_be(randomPitchAddr, 0)
            end
        end

        -- toggle mirror mode, this change does not take effect
        -- until entering a loading zone
        if settings.togglemirrormode and mirrorModeAddr then
            local fn, err = io.open(settings.togglemirrormode, 'r')
            if fn ~= nil then
                fn:close()
                os.remove(settings.togglemirrormode)

                local mirrorState = memory.read_u32_be(mirrorModeAddr)
                -- toggle flag, ensure it's not set to random every load
                memory.write_u32_be(mirrorModeAddr, (mirrorState ^ 1) & 0x00000001) 
            end
        end

        -- change homeward shroom's "home" location to the current room
        if settings.sethomewardshroom then
            local fn, err = io.open(settings.sethomewardshroom, 'r')
            if fn ~= nil then
                fn:close()
                local currentArea = memory.read_u16_be(gameStatusAddr + gameStatusAreaIdOffset)
                local currentMap = memory.read_u16_be(gameStatusAddr + gameStatusMapIdOffset)
                local currentEntrance = memory.read_u16_be(gameStatusAddr + gameStatusEntryIdOffset)
                -- ignore water, lava and cutscene entrances. Try to pick another entrance in the same room that is always reachable
                currentArea, currentMap, currentEntrance = plugin.convert_to_valid_entrance(currentArea, currentMap, currentEntrance)
                if currentArea ~= -1 then
                    local currentRoom = currentArea << 16 | currentMap << 8 | currentEntrance
                    os.remove(settings.sethomewardshroom)
                    memory.write_u32_be(startingMapAddr, currentRoom)
                end
            end
        end

        -- force use homeward shroom
        if settings.homewardshroom and gamemode == GAMESTATE_WORLD then
            local fn, err = io.open(settings.homewardshroom, 'r')
            if fn ~= nil then
                fn:close()
                os.remove(settings.homewardshroom)
                -- set a byte that forces the randomizer to trigger a homeward shroom
                memory.write_s8(homewardShroomAddr, 1) 
            end
        end

        -- check if there is a SetHP file
        if settings.sethp then
            local foundfile = false
            local hpvalue = 0
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
            local foundfile = false
            local fpvalue = 0
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
            local foundfile = false
            local coinvalue = 0
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

        if settings.disablesaveblocks and noSaveBlockAddr then
            local foundfile = false
            local fn, err = io.open(settings.disablesaveblocks, 'r')
            if fn ~= nil then
                foundfile = true
                fn:close()
            end

            if foundfile then
                memory.write_u32_be(noSaveBlockAddr, 1)
            else
                memory.write_u32_be(noSaveBlockAddr, 0)
            end
        end

        if settings.disableheartblocks and noHeartBlockAddr then
            local foundfile = false
            local fn, err = io.open(settings.disableheartblocks, 'r')
            if fn ~= nil then
                foundfile = true
                fn:close()
            end

            if foundfile then
                memory.write_u32_be(noHeartBlockAddr, 1)
            else
                memory.write_u32_be(noHeartBlockAddr, 0)
            end
        end

        if settings.ohkomode and ohkomodeAddr then
            local foundfile = false
            local fn, err = io.open(settings.ohkomode, 'r')
            if fn ~= nil then
                foundfile = true
                fn:close()
            end

            if foundfile then
                memory.write_u32_be(ohkomodeAddr, 1)
            else
                memory.write_u32_be(ohkomodeAddr, 0)
            end
        end

        if settings.disablespeedyspin and speedyAddr then
            local foundfile = false
            local fn, err = io.open(settings.disablespeedyspin, 'r')
            if fn ~= nil then
                foundfile = true
                fn:close()
            end

            if foundfile then
                memory.write_u32_be(speedyAddr, 0)
            else
                memory.write_u32_be(speedyAddr, 1)
            end
        end
    end
end

return plugin
