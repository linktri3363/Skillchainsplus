--[[
Copyright © 2017, Ivaar
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright
  notice, this list of conditions and the following disclaimer.
* Redistributions in binary form must reproduce the above copyright
  notice, this list of conditions and the following disclaimer in the
  documentation and/or other materials provided with the distribution.
* Neither the name of SkillChains nor the
  names of its contributors may be used to endorse or promote products
  derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL IVAAR BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
]]
_addon.author  = 'Ivaar, Cypan, Linktri'
_addon.command = 'sc'
_addon.name    = 'SkillchainsPlus'
_addon.version = '3.0'

require('luau')
require('pack')
require('actions')

file    = require('files')
nukes   = require('nukes')
skills  = require('skills')
res     = require('resources')
Display = require('display')

-- ===========================================================================
-- Static data
-- ===========================================================================
local ALL_JOBS = S{'WAR','MNK','WHM','BLM','RDM','THF','PLD','DRK','BST','BRD','RNG',
                   'SAM','NIN','DRG','SMN','BLU','COR','PUP','DNC','SCH','GEO','RUN'}
local PET_JOBS = S{'SMN','BST','SCH'}

rangedws = S{'Flaming Arrow','Piercing Arrow','Dulling Arrow','Sidewinder','Blast Arrow',
             'Arching Arrow','Empyreal Arrow','Refulgent Arrow','Apex Arrow','Namas Arrow',
             'Jishnu\'s Radiance','Sarv','Hot Shot','Split Shot','Sniper Shot','Slug Shot',
             'Blast Shot','Heavy Shot','Detonator','Numbing Shot','Last Stand','Coronach',
             'Wildfire','Trueflight','Leaden Salute','Terminus'}
ignoretp = S{}

-- Sleep, Petrify, Stun, Charm, Amnesia, Charm, Sleep, Terror, Impairment
local WS_BLOCK = S{2,7,10,14,16,17,19,28,156}

local message_ids    = S{110,185,187,317,802}
local skillchain_ids = S{288,289,290,291,292,293,294,295,296,297,298,299,300,301,
                         385,386,387,388,389,390,391,392,393,394,395,396,397,767,768,769,770}
local buff_dur = {[163]=40,[164]=30,[470]=60}

local lightchains = S{'Light','Fragmentation','Fusion','Liquefaction','Transfixion','Detonation','Impaction','Radiance'}
local darkchains  = S{'Darkness','Gravitation','Distortion','Compression','Induration','Reverberation','Scission','Umbra'}

local sc_info = {
    Radiance      = {'Fire','Wind','Lightning','Light', lvl=4},
    Umbra         = {'Earth','Ice','Water','Dark', lvl=4},
    Light         = {'Fire','Wind','Lightning','Light', Light={4,'Light','Radiance'}, lvl=3},
    Darkness      = {'Earth','Ice','Water','Dark', Darkness={4,'Darkness','Umbra'}, lvl=3},
    Gravitation   = {'Earth','Dark', Distortion={3,'Darkness'}, Fragmentation={2,'Fragmentation'}, lvl=2},
    Fragmentation = {'Wind','Lightning', Fusion={3,'Light'}, Distortion={2,'Distortion'}, lvl=2},
    Distortion    = {'Ice','Water', Gravitation={3,'Darkness'}, Fusion={2,'Fusion'}, lvl=2},
    Fusion        = {'Fire','Light', Fragmentation={3,'Light'}, Gravitation={2,'Gravitation'}, lvl=2},
    Compression   = {'Darkness', Transfixion={1,'Transfixion'}, Detonation={1,'Detonation'}, lvl=1},
    Liquefaction  = {'Fire', Impaction={2,'Fusion'}, Scission={1,'Scission'}, lvl=1},
    Induration    = {'Ice', Reverberation={2,'Fragmentation'}, Compression={1,'Compression'}, Impaction={1,'Impaction'}, lvl=1},
    Reverberation = {'Water', Induration={1,'Induration'}, Impaction={1,'Impaction'}, lvl=1},
    Transfixion   = {'Light', Scission={2,'Distortion'}, Reverberation={1,'Reverberation'}, Compression={1,'Compression'}, lvl=1},
    Scission      = {'Earth', Liquefaction={1,'Liquefaction'}, Reverberation={1,'Reverberation'}, Detonation={1,'Detonation'}, lvl=1},
    Detonation    = {'Wind', Compression={2,'Gravitation'}, Scission={1,'Scission'}, lvl=1},
    Impaction     = {'Lightning', Liquefaction={1,'Liquefaction'}, Detonation={1,'Detonation'}, lvl=1},
}

local chainbound = {}
chainbound[1] = L{'Compression','Liquefaction','Induration','Reverberation','Scission'}
chainbound[2] = L{'Gravitation','Fragmentation','Distortion'} + chainbound[1]
chainbound[3] = L{'Light','Darkness'} + chainbound[2]

local aeonic_weapon = {
    [20515] = 'Godhands',          [20594] = 'Aeneas',      [20695] = 'Sequence',
    [20843] = 'Chango',            [20890] = 'Anguta',      [20935] = 'Trishula',
    [20977] = 'Heishi Shorinken',  [21025] = 'Dojikiri Yasutsuna',
    [21082] = 'Tishtrya',          [21147] = 'Khatvanga',   [21485] = 'Fomalhaut',
    [21694] = 'Lionheart',         [21753] = 'Tri-edge',    [22117] = 'Fail-Not',
    [22131] = 'Fail-Not',          [22143] = 'Fomalhaut',
}

-- Magic burst command (nukes.lua) for each closing property
local MB_CMD = {
    Light = 'lightmb', Radiance = 'lightmb', Darkness = 'darknessmb', Umbra = 'darknessmb',
    Gravitation = 'gravmb', Fragmentation = 'fragmb', Distortion = 'distomb', Fusion = 'fusionmb',
    Compression = 'darkmb', Liquefaction = 'firemb', Induration = 'blizzardmb',
    Reverberation = 'watermb', Transfixion = 'holymb', Scission = 'stonemb',
    Detonation = 'aeromb', Impaction = 'thundermb',
}
local ONGO_PROPS = S{'Scission','Gravitation','Darkness','Umbra'}

-- Blue Magic skillchain properties (fallback when skills.lua lacks a spell)
local blue_magic_properties = {
    ['Thrashing Assault'] = {'Fusion'},          ['Vertical Cleave'] = {'Gravitation'},
    ['Amorphic Spikes']   = {'Gravitation'},     ['Tail Slap']       = {'Reverberation'},
    ['Disseverment']      = {'Distortion'},      ['Frenetic Rip']    = {'Induration'},
    ['Claw Cyclone']      = {'Scission'},        ['Hysteric Barrage'] = {'Detonation'},
    ['Cannonball']        = {'Fusion'},          ['Quadrastrike']    = {'Liquefaction','Scission','Impaction'},
    ['Heavy Strike']      = {'Fragmentation','Transfixion'},
    ['Sudden Lunge']      = {'Detonation'},      ['Spiral Spin']     = {'Transfixion'},
    ['Delta Thrust']      = {'Liquefaction','Detonation'},
    ['Barbed Crescent']   = {'Distortion','Scission'},
    ['Paralyzing Triad']  = {'Gravitation'},     ['Glutinous Dart']  = {'Fragmentation'},
    ['Sinker Drill']      = {'Gravitation','Reverberation'},
    ['Saurian Slide']     = {'Fragmentation','Distortion'},
    ['Tourbillion']       = {'Light','Fragmentation'},
    ['Bilgestorm']        = {'Darkness','Gravitation'},
    ['Bloodrake']         = {'Darkness','Distortion'},
}

-- ===========================================================================
-- Modes
-- ===========================================================================
-- key = command name; var = field in m; label = on-screen tag; on = other
-- modes forced when this one turns on.
local MODES = {
    {key='auto',         label='AUTO',    desc='Auto Skillchain',       on={spam=false}},
    {key='spam',         label='SPAM',    desc='Spam Weaponskill',      on={auto=false, open=false, close=false}},
    {key='cleave',       label='CLEAVE',  desc='Cleave Weaponskill',    on={spam=true, auto=false, open=false, close=false}},
    {key='mb',           label='MB',      desc='MB Skillchain'},
    {key='am',           label='AM3',     desc='Aftermath Skillchain'},
    {key='buddy',        label='BUDDY',   desc='Buddy Skillchain'},
    {key='prefer',       label='PREFER',  desc='Preferred Skillchain'},
    {key='strict',       label='STRICT',  desc='Strict Weaponskill'},
    {key='endless',      label='ENDLESS', desc='Endless Skillchain'},
    {key='ultimate',     label='ULT',     desc='Ultimate'},
    {key='open',         label='OPEN',    desc='Open Skillchain',       on={close=false}},
    {key='close',        label='CLOSE',   desc='Close Skillchain',      on={open=false}},
    {key='starter',      label='STARTER', desc='Starter Weaponskill'},
    {key='melee',        label='MELEE',   desc='Melee Skillchain',      on={ranged=false}},
    {key='ranged',       label='RANGED',  desc='Ranged Skillchain',     on={melee=false}},
    {key='light',        label='LIGHT',   desc='Light Skillchain',      on={dark=false}},
    {key='dark',         label='DARK',    desc='Dark Skillchain',       on={light=false}},
    {key='autonuke',     label='NUKE',    desc='Autonuke Magicburst'},
    {key='ongo',         label='ONGO',    desc='Ongo'},
    {key='chaff',        label='CHAFF',   desc='Chain Affinity'},
    {key='innin',        label='INNIN',   desc='Innin'},
    {key='yonin',        label='YONIN',   desc='Yonin'},
    {key='whilecasting', label='W/CAST',  desc='While Casting',         on={spam=true, auto=false, open=false, close=false}},
    {key='whilereadies', label='W/READY', desc='While Readying',        on={spam=true, auto=false, open=false, close=false}},
}
local MODE = {}
for _, def in ipairs(MODES) do MODE[def.key] = def end

local COMBOS = {
    party   = {'buddy', 'auto'},
    partyam = {'buddy', 'auto', 'am'},
    partymb = {'buddy', 'auto', 'mb'},
}

m = {}  -- current mode flags (booleans)

-- ===========================================================================
-- Runtime state
-- ===========================================================================
info       = {}
resonating = {}
buffs      = {}

local st = {sicdelay = 0, bpdelay = 0, tagtime = 0, wstime = 0, pettime = 0, cafftime = 0}
                        -- transient automation state, reset by varclean()
current_frame, interval = 0, 0.1 -- overwritten by jobvar()
local autosc, petsc     -- closer chosen for the current resonance
local wstrigger = 0
local ws_cache, range_cache = {}, {}
local targ_id
local next_frame = os.clock()
local moving, drag = false, nil
local last_modes

local function say(msg)
    windower.add_to_chat(207, ('%s: %s'):format(_addon.name, msg))
end

function varclean()
    for _, def in ipairs(MODES) do m[def.key] = false end
    st = {
        disabled = false, amthree = false, tagin = false, nuking = false, started = false,
        wsdelay = false, tpdelay = false, petdelay = false, caffdelay = false,
        sicdelay = 0, bpdelay = 0, faw = false,
        tagtime = os.clock(), wstime = 0, pettime = 0, cafftime = 0,
    }
    openws, petopen, initws, overws, zergws, aoews, automb = nil, nil, nil, nil, nil, nil, nil
    autosc, petsc = nil, nil
    jobvar()
end

-- ===========================================================================
-- Configuration
-- ===========================================================================
default = {}
default.Show = {burst=ALL_JOBS, pet=S{'BST','SMN'}, props=ALL_JOBS, spell=S{'SCH','BLU'}, step=ALL_JOBS, timer=ALL_JOBS, weapon=ALL_JOBS}
default.UpdateFrequency = 0.2
default.aeonic = false
default.display = {pos = {x = 400, y = 300}}
default.modes   = {show = true, anchored = true, pos = {x = 400, y = 270}}
default.style   = {font = 'Arial', font_size = 10, bar_width = 220, max_rows = 8}

settings = config.load(default)

local function check_conf()
    if not windower.ffxi.get_info().logged_in then
        print('You have to be logged in to use this addon.')
        return false
    end
    local char_name = windower.ffxi.get_player().name
    local conf_file = file.new('\\' .. char_name .. '.lua')
    if not conf_file:exists() then
        conf_file:create()
        conf_file:write(file.read('data/\\auto.lua'))
    end
    require(char_name)
    return true
end

-- ===========================================================================
-- Ability helpers
-- ===========================================================================
local function get_ws_id(name)
    if ws_cache[name] == nil then
        local ws = res.weapon_skills:with('en', name)
        ws_cache[name] = ws and ws.id or false
    end
    return ws_cache[name] or nil
end

local function list_has(list, value)
    for i = 1, #(list or {}) do
        if list[i] == value then return true end
    end
    return false
end

local function has_ws(name)
    local id = get_ws_id(name)
    return id and list_has(windower.ffxi.get_abilities().weapon_skills, id)
end

local function has_blu_spell(name)
    if info.job ~= 'BLU' then return false end
    local spell = res.spells:with('en', name)
    local mjob = windower.ffxi.get_mjob_data()
    return spell and mjob and list_has(mjob.spells, spell.id) or false
end

local function first_available_ws(list)
    for _, name in ipairs(list or {}) do
        local is_ranged = rangedws:contains(name)
        if m.ranged == is_ranged and has_ws(name) then
            return name
        end
    end
end

local function first_ready_pet_skill(list)
    local owned = S(windower.ffxi.get_abilities().job_abilities or {})
    for _, name in ipairs(list or {}) do
        local ja = res.job_abilities:with('en', name)
        if ja and owned:contains(ja.id) then
            if info.job == 'SMN' and (windower.ffxi.get_ability_recasts()[173] or 0) < 1 then
                return name
            elseif info.job == 'BST' and (st.sicdelay + (ja.mp_cost or 0)) < 4 then
                return name
            end
        end
    end
end

-- Refresh the opener / spam / starter weaponskills from the job config
function check_sc()
    if not windower.ffxi.get_info().logged_in then return false end
    openws  = first_available_ws(defaultws)
    overws  = first_available_ws(tpws)
    zergws  = first_available_ws(spamws)
    initws  = first_available_ws(starterws)
    aoews   = not m.ranged and first_available_ws(cleavews) or nil
    petopen = not m.ranged and first_ready_pet_skill(petws) or nil
    return true
end

local function action_range(name)
    if not name then return 0 end
    if range_cache[name] == nil then
        local ws = res.weapon_skills:with('en', name)
        local sp = not ws and info.job == 'BLU' and res.spells:with('en', name)
        range_cache[name] = (ws and ws.range) or (sp and sp.range) or 3.5
    end
    return range_cache[name]
end

-- ===========================================================================
-- Skillchain resolution
-- ===========================================================================
function update_weapon()
    if not settings.Show.weapon[info.job] then return end
    local main_weapon = windower.ffxi.get_items(info.main_bag, info.main_weapon).id
    if main_weapon ~= 0 then
        info.aeonic = aeonic_weapon[main_weapon] or info.range and aeonic_weapon[windower.ffxi.get_items(info.range_bag, info.range).id]
        return
    end
    if not check_weapon or coroutine.status(check_weapon) ~= 'suspended' then
        check_weapon = coroutine.schedule(update_weapon, 10)
    end
end

local function aeonic_am(step)
    for x = 270, 272 do
        if buffs[info.player][x] then
            return 272 - x < step
        end
    end
    return false
end

local function aeonic_prop(ability, actor)
    if ability.aeonic and (ability.weapon == info.aeonic and actor == info.player or settings.aeonic and info.player ~= actor) then
        return {ability.skillchain[1], ability.skillchain[2], ability.aeonic}
    end
    return ability.skillchain
end

function check_props(old, new)
    for k = 1, #old do
        local combo = sc_info[old[k]]
        for i = 1, #new do
            local result = combo[new[i]]
            if result then
                return unpack(result)
            end
            if #old > 3 and combo.lvl == sc_info[new[i]].lvl then
                break
            end
        end
    end
end

-- Appends {name, lvl, prop, kind} for every ability that closes on `active`,
-- highest level first.
local function add_skills(list, abilities, active, resource, AM)
    local by_lvl = {{}, {}, {}, {}}
    for k = 1, #(abilities or {}) do
        local id = abilities[k]
        local skill = skills[resource][id]
        if skill then
            local lv, prop, aeonic = check_props(active, aeonic_prop(skill, info.player))
            if prop then
                local bucket = by_lvl[lv]
                bucket[#bucket + 1] = {name = res[resource][id].name, lvl = lv, prop = AM and aeonic or prop, kind = resource}
            end
        end
    end
    for lv = 4, 1, -1 do
        for k = #by_lvl[lv], 1, -1 do
            list[#list + 1] = by_lvl[lv][k]
        end
    end
    return list
end

local function collect_entries(reson)
    local list = {}
    local job = info.job
    if settings.Show.spell[job] and job == 'SCH' then
        add_skills(list, {0,1,2,3,4,5,6,7}, reson.active, 'elements')
    elseif settings.Show.spell[job] and job == 'BLU' then
        add_skills(list, windower.ffxi.get_mjob_data().spells, reson.active, 'spells')
    elseif settings.Show.pet[job] and windower.ffxi.get_mob_by_target('pet') then
        add_skills(list, windower.ffxi.get_abilities().job_abilities, reson.active, 'job_abilities')
    end
    if settings.Show.weapon[job] then
        add_skills(list, windower.ffxi.get_abilities().weapon_skills, reson.active, 'weapon_skills',
            info.aeonic and aeonic_am(reson.step))
    end
    return list
end

local function light_dark_ok(prop)
    if m.light then return lightchains:contains(prop) end
    if m.dark then return darkchains:contains(prop) end
    return true
end

local function ws_allowed(e)
    local is_ranged = rangedws:contains(e.name)
    if m.ranged then return is_ranged end
    if m.melee then return not is_ranged end
    return true
end

-- Picks the weaponskill (and pet skill) to close with, honouring every mode.
local function choose_closer(entries)
    local pet, ws = nil, {}
    for _, e in ipairs(entries) do
        if e.kind == 'job_abilities' then
            if not pet and first_ready_pet_skill({e.name}) then pet = e.name end
        elseif e.kind == 'weapon_skills' and ws_allowed(e) and light_dark_ok(e.prop) then
            ws[#ws + 1] = e
        end
    end

    local function find(pred)
        for _, e in ipairs(ws) do
            if pred(e) then return e end
        end
    end

    if m.prefer or m.strict then
        for _, name in ipairs(preferws or {}) do
            local pick = find(function(e) return e.name == name end)
            if pick then
                if m.ultimate and pick.lvl ~= 4 then return nil, pet end
                return pick.name, pet
            end
        end
        if m.strict then return nil, pet end
    end

    if m.endless then
        local pick = find(function(e) return e.lvl == 1 or e.lvl == 2 end)
        if pick then return pick.name, pet end
    end

    local one, two = ws[1], ws[2]
    if not one then return nil, pet end
    if m.ultimate then
        return one.lvl == 4 and one.name or nil, pet
    end
    -- Don't end the chain on a Lv.4 if there's another way to continue it
    if two and one.lvl == 4 then return two.name, pet end
    return one.name, pet
end

-- ===========================================================================
-- Actions
-- ===========================================================================
local function ws_delay()
    st.wsdelay, st.tpdelay, st.wstime = true, true, os.clock()
end

local function pet_delay()
    st.petdelay, st.pettime = true, os.clock()
end

function is_chain_affinity_spell(name)
    return list_has(chainaffws, name)
end

function perform_ws(name)
    if not name then return end
    name = name:gsub('[ \t]+%f[\r\n%z]', '')
    if st.tpdelay then return end

    if info.job == 'BLU' and is_chain_affinity_spell(name) then
        if has_blu_spell(name) then
            windower.send_command('input /ma "' .. name .. '" <t>')
            ws_delay()
        else
            say('Blue Magic spell not set: ' .. name)
        end
        return
    end

    if has_ws(name) then
        windower.send_command('input /ws "' .. name .. '" <t>')
        ws_delay()
    else
        say('Unknown weapon skill: ' .. name)
    end
end

function perform_pet(name)
    if not name or st.petdelay then return end
    name = name:gsub('[ \t]+%f[\r\n%z]', '')
    local ja = res.job_abilities:with('en', name)
    if not ja then
        say('Unknown pet skill: ' .. name)
        return
    end
    if info.job == 'BST' and (st.sicdelay + (ja.mp_cost or 0)) < 4 then
        windower.send_command('input /pet "' .. name .. '" <me>')
        pet_delay()
    elseif info.job == 'SMN' and st.bpdelay < 1 then
        windower.send_command('input /pet "' .. name .. '" <t>')
        pet_delay()
    end
end

function perform_spell(cmd)
    if not (m.autonuke and not st.nuking and st.faw and not st.disabled) then return end
    local spell = nukes.get_nuke(cmd)
    if not spell then return end
    st.nuking = true
    if nukeswap and nukeswap ~= '' then
        windower.send_command('input ' .. nukeswap)
    end
    windower.send_command('wait ' .. (fastcast or 0) .. '; input /ma "' .. spell .. '" <t>')
    say('Magic Burst: ' .. spell)
    windower.send_command('wait 3; sc nuking')
end

-- Chain Affinity ------------------------------------------------------------
function chain_affinity_available()
    if info.job ~= 'BLU' then return false end
    local recasts = windower.ffxi.get_ability_recasts()
    return recasts and recasts[181] ~= nil and recasts[181] < 1
end

local function blu_spell_props(name)
    local spell = res.spells:with('en', name)
    local entry = spell and skills.spells[spell.id]
    return entry and entry.skillchain or blue_magic_properties[name]
end

local function available_chain_affinity_spells()
    local available, unavailable = {}, {}
    for _, name in ipairs(chainaffws or {}) do
        if has_blu_spell(name) then
            available[#available + 1] = name
        else
            unavailable[#unavailable + 1] = name
        end
    end
    return available, unavailable
end

-- The set Chain Affinity spell that closes the highest-level skillchain, or nil
local function smart_chain_affinity_spell(reson)
    local available = available_chain_affinity_spells()
    if #available == 0 then return nil end
    if not reson or not reson.active then return available[1] end

    local best, best_lvl = nil, 0
    for _, name in ipairs(available) do
        local props = blu_spell_props(name)
        if props then
            local lvl, prop = check_props(reson.active, props)
            if lvl and lvl > best_lvl and light_dark_ok(prop) then
                best, best_lvl = name, lvl
            end
        end
    end
    return best
end

local function perform_chain_affinity(reson)
    local name = smart_chain_affinity_spell(reson)
    if not name or st.tpdelay or st.caffdelay or not chain_affinity_available() then
        return false
    end
    windower.send_command('input /ja "Chain Affinity" <me>; wait 1.5; input /ma "' .. name .. '" <t>')
    st.caffdelay, st.cafftime = true, os.clock()
    ws_delay()
    say('Chain Affinity + ' .. name)
    return true
end

-- Automation steps ----------------------------------------------------------
local function try_close(reson, tp)
    if m.chaff and info.job == 'BLU' and chainaffws and #chainaffws > 0 then
        if tp > 999 and perform_chain_affinity(reson) then return true end
        if autosc and tp > 999 and not is_chain_affinity_spell(autosc) then perform_ws(autosc) end
        return true -- Chain Affinity mode never falls through to opening
    end
    if autosc and tp > 999 then perform_ws(autosc) return true end
    if petsc and tp < 1000 then perform_pet(petsc) return true end
    return false
end

local function open_chain(tp, allow_default)
    if tp > 2000 and overws then
        perform_ws(overws)
    elseif tp > 999 and openws and allow_default then
        perform_ws(openws)
    elseif petopen then
        perform_pet(petopen)
    end
end

local function keep_aftermath(tp)
    if tp == 3000 and amws then perform_ws(amws) return true end
    return false
end

-- Facing (Innin / Yonin) ------------------------------------------------------
local turn_key = 'init' -- forces one release on the first call

function set_turn(dir)
    if dir == turn_key then return end
    if dir == 'Right' then
        windower.send_command('setkey numpad4 up; setkey numpad6 down')
    elseif dir == 'Left' then
        windower.send_command('setkey numpad6 up; setkey numpad4 down')
    else
        windower.send_command('setkey numpad4 up; setkey numpad6 up')
    end
    turn_key = dir
end

local function facing_diff()
    local me = windower.ffxi.get_mob_by_target('me')
    local mob = windower.ffxi.get_mob_by_target('st') or windower.ffxi.get_mob_by_target('t')
    if not me or not mob or mob.hpp >= 100 then return nil end
    local function norm(d)
        if d < 0 then return -d end
        return 2 * math.pi - d
    end
    return norm(me.facing) - norm(mob.facing)
end

local function face(target_diff)
    local ddir = facing_diff()
    if not ddir then return set_turn(nil) end
    if ddir < target_diff - 0.3 then
        set_turn('Right')
    elseif ddir > target_diff + 0.3 then
        set_turn('Left')
    else
        set_turn(nil)
    end
end

function front()  face(math.pi) end
function behind() face(0) end

-- ===========================================================================
-- Per-tick state
-- ===========================================================================
local function update_party_tag(now, tp)
    if not m.buddy then return end
    local party = windower.ffxi.get_party()
    local my_turn = true
    for i = 1, 5 do
        local pm = party['p' .. i]
        local p_tp, p_status = 0, 0
        if pm then
            local mob = windower.ffxi.get_mob_by_name(pm.name)
            if mob and not mob.is_npc and not ignoretp:contains(pm.name) then
                p_tp, p_status = pm.tp, mob.status
            end
        end
        if not (tp > p_tp or p_tp < 1000 or (tp == 3000 and p_tp == 3000) or p_status ~= 1) then
            my_turn = false
        end
    end
    if my_turn then
        if now - st.tagtime > tagdelay then st.tagin = false end
    else
        st.tagin, st.tagtime = true, now
    end
end

local function update_timers(now, player)
    if st.wsdelay and now - st.wstime > 2.75 then st.wsdelay = false end
    if st.tpdelay and now - st.wstime > 0.5 then st.tpdelay = false end
    if st.petdelay and now - st.pettime > 1.25 then st.petdelay = false end
    if st.caffdelay and now - st.cafftime > 3.0 then st.caffdelay = false end

    local recasts = windower.ffxi.get_ability_recasts()
    if player.main_job == 'BST' then
        local r = recasts[102] or 0
        st.sicdelay = r <= 0 and 0 or r > bstrecast * 2 and 3 or r > bstrecast and 2 or 1
    elseif player.main_job == 'SMN' then
        st.bpdelay = (recasts[173] or 0) > 0 and 1 or 0
    end
end

local function blocked_by(buff_list)
    for _, b in ipairs(buff_list) do
        if WS_BLOCK:contains(b) then return true end
    end
    return false
end

local function active_mode_labels()
    local out = {}
    for _, def in ipairs(MODES) do
        if m[def.key] then out[#out + 1] = def.label end
    end
    return out
end

local function render_modes()
    local labels = active_mode_labels()
    local key = table.concat(labels, ',') .. tostring(settings.modes.show)
    if key ~= last_modes then
        last_modes = key
        Display:render_modes(labels)
    end
end

-- ===========================================================================
-- Main loop
-- ===========================================================================
windower.register_event('target change', function()
    if m.starter then st.started = false end
end)

windower.register_event('prerender', function()
    local now = os.clock()
    if now < next_frame then return end
    next_frame = now + 0.1

    local player = windower.ffxi.get_player()
    if not player or now <= current_frame + interval then return end
    current_frame = now

    for k, v in pairs(resonating) do
        if v.times - now + 10 < 0 then resonating[k] = nil end
    end

    local tp, status = player.vitals.tp, player.status
    st.disabled = blocked_by(player.buffs)
    st.amthree = m.am and not list_has(player.buffs, 272)
    update_party_tag(now, tp)
    update_timers(now, player)

    -- Weaponskill reach
    local ws_name = (autosc and not PET_JOBS[info.job]) and autosc or openws
    local wsrange = action_range(ws_name)
    local mobdist, wsdist = 50, 0
    local tmob = player.target_index and windower.ffxi.get_mob_by_index(player.target_index)
    if tmob then
        mobdist = tmob.distance:sqrt()
        wsdist = m.ranged and 21 or tmob.model_size + wsrange + (0.21 + 0.21 * tmob.model_size)
    end
    wsdist = math.max(wsdist, 3.5)
    local in_range = mobdist < wsdist
    local engaged = status == 1

    if m.innin and engaged and in_range and not (player.main_job == 'NIN' and st.faw) then
        behind()
    elseif m.yonin and not m.innin and engaged and in_range then
        front()
    else
        set_turn(nil)
    end

    local can_act = engaged and not st.disabled and not st.tagin and in_range and not st.nuking

    local targ = windower.ffxi.get_mob_by_target('t', 'bt')
    targ_id = targ and targ.id
    local reson = resonating[targ_id]
    local timer = reson and (reson.times - now) or 0
    local mid_fight = targ and targ.hpp > 0 and targ.hpp < 100

    if targ and targ.hpp > 0 and timer > 0 then
        local phase, remaining, frac
        if not reson.closed then
            if not reson.entries then
                reson.entries = collect_entries(reson)
                autosc, petsc = choose_closer(reson.entries)
            end
            if m.auto and can_act and not m.open and now > reson.delay then
                if not m.mb then
                    if st.amthree then
                        keep_aftermath(tp)
                    elseif not try_close(reson, tp) and not m.close then
                        open_chain(tp, not m.ultimate)
                    end
                elseif timer < bursttime or reson.step == 1 then
                    if st.amthree then
                        if autosc then keep_aftermath(tp) end
                    else
                        try_close(reson, tp)
                    end
                end
            end
            if now < reson.delay then
                phase, remaining = 'wait', reson.delay - now
                frac = remaining / math.max(0.1, reson.delay - reson.start)
            else
                phase, remaining = 'go', timer
                frac = timer / math.max(0.1, reson.times - reson.delay)
            end
        elseif settings.Show.burst[info.job] then
            reson.entries = {}
            autosc, petsc = nil, nil
            if mid_fight and m.auto and not m.mb and can_act and not m.close then
                if st.amthree then keep_aftermath(tp) else open_chain(tp, true) end
            end
            phase, remaining = 'burst', timer
            frac = timer / math.max(0.1, reson.times - reson.start)
        else
            resonating[targ_id] = nil
            return
        end

        st.faw = m.autonuke and ((reson.delay - now) < 1 or reson.step > 1) or false

        if not moving then
            local job = info.job
            local elements
            if reson.step > 1 and settings.Show.burst[job] then
                elements = {}
                for _, e in ipairs(sc_info[reson.active[1]]) do elements[#elements + 1] = e end
            end
            Display:render({
                step = reson.step, name = res[reson.res][reson.id].name,
                phase = phase, remaining = remaining, frac = frac,
                props = not reson.bound and reson.active or nil, bound = reson.bound,
                elements = elements, entries = reson.entries, chosen = autosc,
                show = {step = settings.Show.step[job], timer = settings.Show.timer[job],
                        props = settings.Show.props[job], burst = settings.Show.burst[job]},
            })
        end

        -- Magic burst
        if reson.step > 1 and timer > 1.5 and not reson.bound then
            local prop = reson.active[1]
            local cmd
            if m.ongo then
                cmd = ONGO_PROPS:contains(prop) and 'ongomb' or nil
            else
                cmd = MB_CMD[prop]
            end
            if cmd then
                perform_spell(cmd)
                automb = cmd
            end
        end

    elseif not moving then
        autosc, petsc, automb, st.faw = nil, nil, nil, false
        Display:hide()
        if mid_fight and m.auto and can_act and not m.close then
            if st.amthree then
                keep_aftermath(tp)
            elseif m.starter and not st.started then
                if tp > 999 and initws then
                    perform_ws(initws)
                    st.started = true
                end
            else
                open_chain(tp, true)
            end
        end
    end

    -- Spam / cleave
    if mid_fight and m.spam and engaged and not st.disabled and in_range then
        local gated = m.whilecasting or m.whilereadies
        if not gated or wstrigger == 0 then
            if st.amthree then
                if keep_aftermath(tp) then wstrigger = 1 end
            elseif tp > 999 and m.cleave then
                if aoews then perform_ws(aoews) end
            elseif tp > 999 and (not m.starter or st.started) then
                if zergws then
                    perform_ws(zergws)
                    wstrigger = 1
                end
            elseif tp > 999 and m.starter and not st.started then
                if initws then
                    perform_ws(initws)
                    st.started = true
                    wstrigger = 1
                end
            elseif petopen then
                perform_pet(petopen)
            end
        end
    end

    if not moving then render_modes() end
end)

-- ===========================================================================
-- Chat / buffs / buddy
-- ===========================================================================
windower.register_event('incoming text', function(original, modified, mode)
    local tmob = windower.ffxi.get_mob_by_target('t')
    local tname = tmob and tmob.name
    if tname and original:contains(tname) then
        if m.whilereadies and original:contains(tname .. ' readies') then
            wstrigger = 0
        elseif m.whilecasting and original:contains(tname .. ' starts casting') then
            wstrigger = 0
        end
    end
    return modified, mode
end)

function ignore_player(name)
    if name and not ignoretp:contains(name) then
        ignoretp:add(name)
        say('Added ' .. name .. ' to ignore list')
    end
end

function watch_player(name)
    if name and ignoretp:contains(name) then
        ignoretp:remove(name)
        say('Removed ' .. name .. ' from ignore list')
    end
end

-- Shares Aftermath / WS status with your other characters (Windower IPC)
function buddy_broadcast(msg)
    say(msg)
    local me = windower.ffxi.get_player()
    if me then
        windower.send_ipc_message('scplus|' .. msg .. '|' .. me.name)
    end
end

local function buddy_status(msg, sender)
    if msg:contains('Aftermath Down') or msg:contains('WS Disabled') then
        ignore_player(sender)
    elseif msg:contains('Aftermath Up') or msg:contains('WS Enabled') then
        watch_player(sender)
    end
end

windower.register_event('ipc message', function(message)
    if not m.buddy then return end
    local msg, sender = message:match('^scplus|(.-)|(.+)$')
    if msg then buddy_status(msg, sender) end
end)

windower.register_event('chat message', function(message, sender, mode, gm)
    if m.buddy then buddy_status(message, sender) end
end)

windower.register_event('gain buff', function(id)
    if not m.buddy then return end
    if m.am and id == 272 then buddy_broadcast('Aftermath Up') end
    if WS_BLOCK:contains(id) then buddy_broadcast('WS Disabled') end
end)

windower.register_event('lose buff', function(id)
    if not m.buddy then return end
    if m.am and id == 272 then buddy_broadcast('Aftermath Down') end
    if WS_BLOCK:contains(id) then
        local player = windower.ffxi.get_player()
        local others = {}
        for _, b in ipairs(player.buffs) do
            if b ~= id then others[#others + 1] = b end
        end
        if not blocked_by(others) then buddy_broadcast('WS Enabled') end
    end
end)

-- ===========================================================================
-- Skillchain tracking (action packets)
-- ===========================================================================
local function check_buff(t, i)
    if t[i] == true or t[i] - os.time() > 0 then
        return true
    end
    t[i] = nil
end

local function chain_buff(t)
    local i = t[164] and 164 or t[470] and 470
    if i and check_buff(t, i) then
        t[i] = nil
        return true
    end
    return t[163] and check_buff(t, 163)
end

local categories = S{'weaponskill_finish','spell_finish','job_ability','mob_tp_finish','avatar_tp_finish','job_ability_unblinkable'}

local function apply_properties(target, resource, action_id, properties, delay, step, closed, bound)
    local clock = os.clock()
    resonating[target] = {
        res = resource, id = action_id, active = properties,
        start = clock, delay = clock + delay, times = clock + delay + 8 - step,
        step = step, closed = closed, bound = bound,
    }
    if target == targ_id then
        next_frame = clock
    end
end

local function action_handler(act)
    local actionpacket = ActionPacket.new(act)
    local category = actionpacket:get_category_string()
    if not categories:contains(category) or act.param == 0 then return end

    local actor = actionpacket:get_id()
    local target = actionpacket:get_targets()()
    local action = target:get_actions()()
    local message_id = action:get_message_id()
    local add_effect = action:get_add_effect()
    local param, resource, action_id, interruption, conclusion = action:get_spell()
    local ability = skills[resource] and skills[resource][action_id]

    if add_effect and conclusion and skillchain_ids:contains(add_effect.message_id) then
        local skillchain = add_effect.animation:ucfirst()
        local level = sc_info[skillchain].lvl
        local reson = resonating[target.id]
        local delay = ability and ability.delay or 3
        local step = (reson and reson.step or 1) + 1
        if level == 3 and reson and ability then
            level = check_props(reson.active, aeonic_prop(ability, actor))
        end
        apply_properties(target.id, resource, action_id, {skillchain}, delay, step, level == 4)
    elseif ability and (message_ids:contains(message_id) or message_id == 2 and buffs[actor] and chain_buff(buffs[actor])) then
        apply_properties(target.id, resource, action_id, aeonic_prop(ability, actor), ability.delay or 3, 1)
    elseif message_id == 529 then
        apply_properties(target.id, resource, action_id, chainbound[param], 2, 1, false, param)
    elseif message_id == 100 and buff_dur[param] then
        buffs[actor] = buffs[actor] or {}
        buffs[actor][param] = buff_dur[param] + os.time()
    end
end

ActionPacket.open_listener(action_handler)

windower.register_event('incoming chunk', function(id, data)
    if id == 0x29 and data:unpack('H', 25) == 206 and data:unpack('I', 9) == info.player then
        buffs[info.player][data:unpack('H', 13)] = nil
    elseif id == 0x50 and data:byte(6) == 0 then
        info.main_weapon = data:byte(5)
        info.main_bag = data:byte(7)
        update_weapon()
    elseif id == 0x50 and data:byte(6) == 2 then
        info.range = data:byte(5)
        info.range_bag = data:byte(7)
        update_weapon()
    elseif id == 0x63 and data:byte(5) == 9 then
        local set_buff = {}
        for n = 1, 32 do
            local buff = data:unpack('H', n * 2 + 7)
            if buff_dur[buff] or buff > 269 and buff < 273 then
                set_buff[buff] = true
            end
        end
        buffs[info.player] = set_buff
    end
end)

-- ===========================================================================
-- Move mode (drag the display)
-- ===========================================================================
local function set_moving(on)
    moving = on
    if moving then
        Display:demo()
        say('Move mode on: drag the skillchain display or the mode line. //sc move again to finish.')
    else
        drag = nil
        Display:hide()
        last_modes = nil
        config.save(settings)
        say('Positions saved.')
    end
end

windower.register_event('mouse', function(type, x, y, delta, blocked)
    if blocked or not moving then return end
    if type == 1 then
        local group = Display:hit(x, y)
        if group then
            drag = {group = group, x = x, y = y}
            return true
        end
    elseif type == 0 and drag then
        Display:move(drag.group, x - drag.x, y - drag.y)
        drag.x, drag.y = x, y
        return true
    elseif type == 2 and drag then
        drag = nil
        return true
    end
end)

-- ===========================================================================
-- Commands
-- ===========================================================================
local function toggle_mode(key)
    local def = MODE[key]
    local on = not m[key]
    m[key] = on
    if on and def.on then
        for k, v in pairs(def.on) do m[k] = v end
    end
    if not on and key == 'buddy' then st.tagin = false end
    if not on and key == 'autonuke' then st.nuking = false end
    if on and (key == 'whilecasting' or key == 'whilereadies') then wstrigger = 1 end
    if key == 'ranged' or key == 'melee' then check_sc() end
    say(('%s Mode: %s'):format(def.desc, on and 'On' or 'Off'))
end

local function print_status()
    local labels = active_mode_labels()
    say('Active modes: ' .. (#labels > 0 and table.concat(labels, ', ') or 'none'))
end

local function debug_chain_affinity()
    say('Chain Affinity: mode ' .. (m.chaff and 'on' or 'off') .. ', job ' .. tostring(info.job))
    local recast = (windower.ffxi.get_ability_recasts() or {})[181]
    say('Recast: ' .. tostring(recast) .. 's, available: ' .. tostring(chain_affinity_available()) .. ', delay: ' .. tostring(st.caffdelay))
    local available, unavailable = available_chain_affinity_spells()
    for _, name in ipairs(available) do
        say('  set:     ' .. name .. ' (' .. table.concat(blu_spell_props(name) or {'?'}, ', ') .. ')')
    end
    for _, name in ipairs(unavailable) do
        say('  NOT set: ' .. name .. ' (' .. table.concat(blu_spell_props(name) or {'?'}, ', ') .. ')')
    end
end

local function chain_affinity_coverage()
    local counts = {}
    for _, name in ipairs((available_chain_affinity_spells())) do
        for _, p in ipairs(blu_spell_props(name) or {}) do counts[p] = (counts[p] or 0) + 1 end
    end
    say('Chain Affinity coverage:')
    for prop, n in pairs(counts) do say(('  %s (%d spell%s)'):format(prop, n, n > 1 and 's' or '')) end
end

local function restyle(key, value)
    if key == 'font' then
        settings.style.font = value
    else
        local n = tonumber(value)
        if not n then return say('Usage: //sc ' .. key .. ' <number>') end
        settings.style[key == 'size' and 'font_size' or 'bar_width'] = n
    end
    config.save(settings)
    Display:init(settings)
    last_modes = nil
    if moving then Display:demo() end
    say(('Style: %s %d, bar %d'):format(settings.style.font, settings.style.font_size, settings.style.bar_width))
end

local HELP = {
    'SkillchainsPlus v' .. _addon.version .. ' - //sc <command>',
    ' Display: move | modes [attach] | font <name> | size <n> | width <n> | save [all]',
    '          burst | props | step | timer | weapon | spell | pet | aeonic',
    ' Main:    auto | spam | cleave | autonuke | status | reload',
    ' Modify:  mb | am | buddy | prefer | strict | endless | ultimate | open | close',
    '          starter | melee | ranged | light | dark | ongo | chaff | innin | yonin',
    '          whilecasting | whilereadies | ignore <name> | watch <name>',
    ' Combos:  party | partyam | partymb',
    ' Macros:  autoskill | autoburst | spamskill',
    ' Nukes:   fire | ice | wind | earth | thunder | water | lightness | darkness',
}

windower.register_event('addon command', function(cmd, ...)
    cmd = cmd and cmd:lower()
    local args = {...}

    if not cmd or cmd == 'help' or cmd == '?' then
        for _, line in ipairs(HELP) do windower.add_to_chat(207, line) end

    elseif MODE[cmd] then
        toggle_mode(cmd)

    elseif COMBOS[cmd] then
        for _, key in ipairs(COMBOS[cmd]) do
            if not m[key] then toggle_mode(key) end
        end

    elseif cmd == 'move' then
        set_moving(not moving)

    elseif cmd == 'modes' then
        if args[1] and args[1]:lower() == 'attach' then
            settings.modes.anchored = true
            settings.modes.show = true
            say('Mode line attached above the skillchain display.')
        else
            settings.modes.show = not settings.modes.show
            say('Mode line ' .. (settings.modes.show and 'shown' or 'hidden'))
        end
        config.save(settings)
        last_modes = nil
        if moving then Display:demo() end

    elseif cmd == 'font' or cmd == 'size' or cmd == 'width' then
        if args[1] then restyle(cmd, table.concat(args, ' ')) else say('Usage: //sc ' .. cmd .. ' <value>') end

    elseif cmd == 'save' then
        local all = args[1] and args[1]:lower() == 'all' and 'all' or nil
        config.save(settings, all)
        say(('settings saved to %s character%s.'):format(all or 'current', all and 's' or ''))

    elseif default.Show[cmd] then
        if not default.Show[cmd][info.job] then
            return say(('unable to set %s on %s.'):format(cmd, info.job))
        end
        local on = settings.Show[cmd][info.job]
        if on then settings.Show[cmd]:remove(info.job) else settings.Show[cmd]:add(info.job) end
        config.save(settings)
        say(('%s info will no%s be displayed on %s.'):format(cmd, on and ' longer' or 'w', info.job))

    elseif cmd == 'aeonic' then
        settings.aeonic = not settings.aeonic
        say('aeonic ' .. (settings.aeonic and 'on' or 'off'))

    elseif cmd == 'status' then
        print_status()

    elseif cmd == 'ignore' then
        ignore_player(args[1])

    elseif cmd == 'watch' then
        watch_player(args[1])

    elseif cmd == 'nuking' then
        st.nuking = false

    elseif cmd == 'autoskill' then
        local ws = autosc or openws
        if ws then
            windower.send_command('input /ws "' .. ws .. '" <t>')
        else
            say('No weaponskill available to use.')
        end

    elseif cmd == 'autoburst' then
        if automb then windower.send_command('sc ' .. automb) end

    elseif cmd == 'spamskill' then
        if zergws then windower.send_command('input /ws "' .. zergws .. '" <t>') end

    elseif cmd == 'reload' then
        windower.send_command('lua reload ' .. _addon.name)

    elseif cmd == 'eval' then
        assert(loadstring(table.concat(args, ' ')))()

    elseif cmd == 'chaffdebug' or cmd == 'chaffanalysis' or cmd == 'chaffrecast' then
        debug_chain_affinity()

    elseif cmd == 'chaffcoverage' then
        chain_affinity_coverage()

    elseif cmd == 'allrecasts' then
        local recasts = windower.ffxi.get_ability_recasts()
        say('Active recasts:')
        for i = 1, 1024 do
            if recasts[i] and recasts[i] > 0 then say(('  [%d] %s'):format(i, recasts[i])) end
        end
    end
    -- Element toggles and *mb commands are handled in nukes.lua
end)

-- ===========================================================================
-- Lifecycle
-- ===========================================================================
windower.register_event('tp change', function()
    check_sc()
end)

windower.register_event('job change', function(job)
    job = res.jobs:with('id', job).english_short
    if job ~= info.job then
        info.job = job
        chainaffws, petws = nil, nil
        jobvar()
        check_sc()
    end
end)

windower.register_event('zone change', function()
    varclean()
end)

windower.register_event('load', function()
    if windower.ffxi.get_info().logged_in then
        local equip = windower.ffxi.get_items('equipment')
        info.main_weapon = equip.main
        info.main_bag = equip.main_bag
        info.range = equip.range
        info.range_bag = equip.range_bag
        update_weapon()
        buffs[info.player] = {}
    end
end)

local function shutdown()
    set_turn(nil)
    if check_weapon then coroutine.close(check_weapon) end
end

windower.register_event('unload', function()
    shutdown()
    Display:destroy()
end)

windower.register_event('logout', function()
    shutdown()
    check_weapon = nil
    info, resonating, buffs = {}, {}, {}
    Display:hide()
end)

-- ===========================================================================
-- Startup
-- ===========================================================================
local function start()
    if not check_conf() then return end
    local player = windower.ffxi.get_player()
    info.job, info.player = player.main_job, player.id
    buffs[info.player] = buffs[info.player] or {}
    varclean()
    check_sc()
end

windower.register_event('login', function()
    coroutine.schedule(start, 3)
end)

Display:init(settings)
start()
