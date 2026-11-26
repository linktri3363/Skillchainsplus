--[[
    SkillchainsPlus display, styled after EnemyBar2.

    Two movable groups:
      main  - step header, skillchain window bar, active properties /
              burst elements, and the list of weaponskills that can close
      modes - one line showing which automation modes are on

    Text is bold with a dark stroke and no background box; the timer bar
    uses EnemyBar2's bar textures (images/bg_body.png, fg_body.png).
]]

local texts  = require('texts')
local images = require('images')

local Display = {}

-- ---------------------------------------------------------------------------
-- Palette
-- ---------------------------------------------------------------------------
local STROKE = {width = 2, alpha = 180, red = 50, green = 50, blue = 50}

local COL = {
    header  = {200, 220, 255},
    text    = {235, 235, 235},
    dim     = {150, 150, 160},
    chosen  = {255, 215, 0},
    wait    = {255, 90, 90},
    go      = {80, 255, 128},
    burst   = {120, 170, 255},
    mode_on = {80, 255, 128},
}

-- Element / property colours (originally by Sammeh)
local PROP = {
    Light = {255, 255, 255}, Dark = {110, 110, 255},
    Ice = {0, 255, 255}, Water = {60, 120, 255}, Earth = {200, 140, 60},
    Wind = {102, 255, 102}, Fire = {255, 60, 60}, Lightning = {255, 0, 255},
    Gravitation = {170, 110, 50}, Fragmentation = {250, 156, 247},
    Fusion = {255, 102, 102}, Distortion = {51, 153, 255},
}
PROP.Darkness, PROP.Umbra, PROP.Compression = PROP.Dark, PROP.Dark, PROP.Dark
PROP.Radiance, PROP.Transfixion = PROP.Light, PROP.Light
PROP.Induration, PROP.Reverberation = PROP.Ice, PROP.Water
PROP.Scission, PROP.Detonation = PROP.Earth, PROP.Wind
PROP.Liquefaction, PROP.Impaction = PROP.Fire, PROP.Lightning

local function cs(rgb, s)
    return ('\\cs(%d,%d,%d)%s\\cr'):format(rgb[1], rgb[2], rgb[3], s)
end

local function prop_cs(name)
    return cs(PROP[name] or COL.text, name)
end

Display.prop_color = function(name) return PROP[name] end

-- ---------------------------------------------------------------------------
-- Construction
-- ---------------------------------------------------------------------------
local function new_text(style, scale)
    return texts.new('', {
        pos   = {x = 0, y = 0},
        text  = {size = math.floor(style.font_size * (scale or 1) + 0.5), font = style.font,
                 red = 235, green = 235, blue = 235, stroke = STROKE},
        flags = {bold = true, draggable = false, italic = false},
        bg    = {visible = false},
    })
end

local function new_image(file, w, h, rgb, alpha)
    return images.new({
        pos        = {x = 0, y = 0},
        visible    = false,
        color      = {alpha = alpha or 255, red = rgb[1], green = rgb[2], blue = rgb[3]},
        size       = {width = w, height = h},
        texture    = {path = windower.addon_path .. 'images/' .. file, fit = true},
        repeatable = {x = 1, y = 1},
        draggable  = false,
    })
end

function Display:destroy()
    for _, e in ipairs(self.elements or {}) do
        if e.destroy then e:destroy() end
    end
    self.elements = {}
end

function Display:init(settings)
    self:destroy()
    self.settings = settings
    local st = settings.style
    self.style = st
    self.bar_w = st.bar_width
    self.bar_h = st.font_size + 6
    self.line_h = st.font_size + 8

    self.header   = new_text(st, 1)
    self.bar_bg   = new_image('bg_body.png', self.bar_w, self.bar_h, {0, 0, 0}, 170)
    self.bar_fg   = new_image('fg_body.png', self.bar_w, self.bar_h, COL.go, 220)
    self.timer    = new_text(st, 0.9)
    self.props    = new_text(st, 1)
    self.ws_names = new_text(st, 0.95)
    self.ws_props = new_text(st, 0.95)
    self.modes    = new_text(st, 0.9)

    self.main_group  = {self.header, self.bar_bg, self.bar_fg, self.timer, self.props, self.ws_names, self.ws_props}
    self.modes_group = {self.modes}
    self.elements = {self.header, self.bar_bg, self.bar_fg, self.timer, self.props,
                     self.ws_names, self.ws_props, self.modes}
end

-- ---------------------------------------------------------------------------
-- Main group
-- ---------------------------------------------------------------------------
function Display:hide()
    for _, e in ipairs(self.main_group or {}) do e:hide() end
end

--[[ view = {
    step, name,                  -- header
    phase = 'wait'|'go'|'burst', remaining, frac,
    props = {...} | bound = n,   -- active properties or Chainbound level
    elements = {...},            -- burst elements (step > 1)
    entries = {{name, lvl, prop}, ...}, chosen = name,
    show = {step, timer, props, burst},
} ]]
function Display:render(view)
    if not self.header then return end
    local pos = self.settings.display.pos
    local x, y = pos.x, pos.y
    local show = view.show or {}

    -- Header: Step 2 -> Savage Blade
    if show.step and view.step then
        self.header:text(('%s %s  %s  %s'):format(cs(COL.dim, 'Step'), cs(COL.header, tostring(view.step)),
            cs(COL.dim, '→'), cs(COL.text, view.name or '')))
        self.header:pos(x, y)
        self.header:show()
        y = y + self.line_h
    else
        self.header:hide()
    end

    -- Timer bar
    if show.timer and view.phase then
        local rgb = COL[view.phase]
        local frac = math.max(0, math.min(1, view.frac or 0))
        self.bar_bg:pos(x, y)
        self.bar_fg:pos(x, y)
        self.bar_fg:color(rgb[1], rgb[2], rgb[3])
        self.bar_fg:width(math.max(1, math.floor(frac * self.bar_w)))
        self.bar_bg:show()
        if frac > 0 then self.bar_fg:show() else self.bar_fg:hide() end

        local label = view.phase == 'wait' and 'Wait' or view.phase == 'go' and 'Go!' or 'Burst'
        self.timer:text(('%s  %.1fs'):format(label, math.max(0, view.remaining or 0)))
        self.timer:color(255, 255, 255)
        self.timer:pos(x + 4, y + math.floor((self.bar_h - self.style.font_size * 1.3) / 2))
        self.timer:show()
        y = y + self.bar_h + 4
    else
        self.bar_bg:hide(); self.bar_fg:hide(); self.timer:hide()
    end

    -- Active properties and burst elements
    local line
    if show.props and view.bound then
        line = cs(COL.header, ('Chainbound Lv.%d'):format(view.bound))
    elseif show.props and view.props and #view.props > 0 then
        local p = {}
        for i, name in ipairs(view.props) do p[i] = prop_cs(name) end
        line = table.concat(p, cs(COL.dim, ' · '))
    end
    if show.burst and view.elements and #view.elements > 0 then
        local e = {}
        for i, name in ipairs(view.elements) do e[i] = prop_cs(name) end
        local burst = cs(COL.dim, 'MB ') .. table.concat(e, ' ')
        line = line and (line .. '   ' .. burst) or burst
    end
    if line then
        self.props:text(line)
        self.props:pos(x, y)
        self.props:show()
        y = y + self.line_h
    else
        self.props:hide()
    end

    -- Weaponskills that close (two aligned columns)
    local entries = view.entries or {}
    if #entries > 0 then
        local names, levels = {}, {}
        local max_rows = self.style.max_rows or 8
        for i = 1, math.min(#entries, max_rows) do
            local e = entries[i]
            local chosen = view.chosen and e.name == view.chosen
            names[i]  = chosen and cs(COL.chosen, '» ' .. e.name) or cs(COL.text, '   ' .. e.name)
            levels[i] = cs(COL.dim, ('Lv.%d '):format(e.lvl)) .. prop_cs(e.prop)
        end
        self.ws_names:text(table.concat(names, '\n'))
        self.ws_props:text(table.concat(levels, '\n'))
        self.ws_names:pos(x, y)
        self.ws_props:pos(x + math.floor(self.bar_w * 0.62), y)
        self.ws_names:show()
        self.ws_props:show()
    else
        self.ws_names:hide()
        self.ws_props:hide()
    end
end

-- ---------------------------------------------------------------------------
-- Modes group
-- ---------------------------------------------------------------------------
function Display:render_modes(active)
    if not self.modes then return end
    local cfg = self.settings.modes
    if not cfg.show then self.modes:hide() return end
    local parts = {cs(COL.header, 'SC+')}
    if #active == 0 then
        parts[2] = cs(COL.dim, 'idle')
    else
        for i, m in ipairs(active) do parts[i + 1] = cs(COL.mode_on, m) end
    end
    self.modes:text(table.concat(parts, '  '))
    self.modes:pos(cfg.pos.x, cfg.pos.y)
    self.modes:show()
end

-- ---------------------------------------------------------------------------
-- Move mode
-- ---------------------------------------------------------------------------
function Display:demo()
    self:render({
        step = 2, name = 'Savage Blade', phase = 'go', remaining = 5.2, frac = 0.65,
        props = {'Fusion'}, elements = {'Fire', 'Light'},
        entries = {
            {name = 'Savage Blade', lvl = 3, prop = 'Light'},
            {name = 'Requiescat', lvl = 2, prop = 'Gravitation'},
            {name = 'Circle Blade', lvl = 1, prop = 'Impaction'},
        },
        chosen = 'Savage Blade',
        show = {step = true, timer = true, props = true, burst = true},
    })
    local show = self.settings.modes.show
    self.settings.modes.show = true
    self:render_modes({'AUTO', 'BUDDY', 'MB'})
    self.settings.modes.show = show
end

local function group_hover(group, x, y)
    for _, e in ipairs(group) do
        if e:visible() and e:hover(x, y) then return true end
    end
    return false
end

-- Returns the group name under the cursor, or nil
function Display:hit(x, y)
    if self.modes_group and group_hover(self.modes_group, x, y) then return 'modes' end
    if self.main_group and group_hover(self.main_group, x, y) then return 'main' end
end

function Display:move(group, dx, dy)
    local pos = group == 'modes' and self.settings.modes.pos or self.settings.display.pos
    pos.x, pos.y = pos.x + dx, pos.y + dy
    self:demo()
end

return Display
