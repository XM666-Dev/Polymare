dofile("data/scripts/lib/mod_settings.lua")

--#region
local f = loadfile("data/scripts/debug/keycodes.lua")
f()
local env = {}
setfenv(f, env)()
local mouse_buttons = {}
local keys = {}
local joy_buttons = {}
for k, v in pairs(env) do
    if k:find("^Mouse_") then
        mouse_buttons[k] = v
    elseif k:find("^Key_") then
        keys[k] = v
    elseif k:find("^JOY_BUTTON_") then
        joy_buttons[k] = v
    end
end

---@return string? input
function get_any_input()
    for k, v in pairs(mouse_buttons) do
        if InputIsMouseButtonDown(v) then
            return k
        end
    end
    for k, v in pairs(keys) do
        if InputIsKeyDown(v) then
            return k
        end
    end
    for k, v in pairs(joy_buttons) do
        for i = 0, 3 do
            if InputIsJoystickButtonDown(i, v) then
                return k
            end
        end
    end
end

---@param input string
function read_input(input)
    if input:find("^Mouse_") then
        return InputIsMouseButtonDown(mouse_buttons[input])
    elseif input:find("^Key_") then
        return InputIsKeyDown(keys[input])
    elseif input:find("^JOY_BUTTON_") then
        for i = 0, 3 do
            if InputIsJoystickButtonDown(i, joy_buttons[input]) then
                return true
            end
        end
        return false
    end
end

---@param input string
function read_input_just(input)
    if input:find("^Mouse_") then
        return InputIsMouseButtonJustDown(mouse_buttons[input])
    elseif input:find("^Key_") then
        return InputIsKeyJustDown(keys[input])
    elseif input:find("^JOY_BUTTON_") then
        for i = 0, 3 do
            if InputIsJoystickButtonJustDown(i, joy_buttons[input]) then
                return true
            end
        end
        return false
    end
end

local punctuations = {
    MINUS = "-",
    EQUALS = "=",
    LEFTBRACKET = "[",
    RIGHTBRACKET = "]",
    BACKSLASH = "\\",
    NONUSHASH = "#",
    SEMICOLON = ";",
    APOSTROPHE = "'",
    GRAVE = "`",
    COMMA = ",",
    PERIOD = ".",
    SLASH = "/",
    NUMLOCKCLEAR = "NUMLOCK",
    KP_DIVIDE = "/",
    KP_MULTIPLY = "*",
    KP_MINUS = "-",
    KP_PLUS = "+",
    KP_PERIOD = ".",
    NONUSBACKSLASH = "\\",
    APPLICATION = "MENU",
    POWER = "SHUTDOWN",
    KP_EQUALS = "=",
    KP_COMMA = ",",
    KP_EQUALSAS400 = "=",
    KP_LEFTPAREN = "(",
    KP_RIGHTPAREN = ")",
    KP_LEFTBRACE = "{",
    KP_RIGHTBRACE = "}",
    KP_XOR = "^",
    KP_POWER = "SHUTDOWN",
    KP_PERCENT = "%",
    KP_LESS = "<",
    KP_GREATER = ">",
    KP_AMPERSAND = "&",
    KP_DBLAMPERSAND = "&&",
    KP_VERTICALBAR = "|",
    KP_DBLVERTICALBAR = "||",
    KP_COLON = ":",
    KP_HASH = "#",
    KP_AT = "@",
    KP_EXCLAM = "!",
    KP_PLUSMINUS = "+-",
    LCTRL = "LEFT CTRL",
    LSHIFT = "LEFT SHIFT",
    LALT = "LEFT ALT",
    LGUI = "LEFT WINDOWS",
    RCTRL = "RIGHT CTRL",
    RSHIFT = "RIGHT SHIFT",
    RALT = "RIGHT ALT",
    RGUI = "RIGHT WINDOWS",
}
---@param input string
---@return string?
function get_input_text(input)
    if input:find("^Mouse_") then
        return GameTextGet("$input_" .. input:gsub("_", ""):lower()):upper()
    elseif input:find("^Key_") then
        local text = input:sub(5)
        local prefix = ""
        local punctuation = punctuations[text]
        if text:find("^KP_") then
            text = text:sub(4)
            prefix = "KEYPAD "
        elseif text:find("^AC_") then
            text = text:sub(4)
            prefix = "AC "
        end
        if punctuation ~= nil then
            text = punctuation
        end
        return prefix .. text:upper()
    elseif input:find("^JOY_BUTTON_") then
        return GameTextGet("input_xboxbutton_" .. input:sub(12):lower())
    end
end

local detecting_key = false
local disable_button = false
function mod_setting_input(mod_id, gui, in_main_menu, im_id, setting)
    GuiColorSetForNextWidget(gui, 0.436, 0.435, 0.435, 1)
    GuiOptionsAddForNextWidget(gui, GUI_OPTION.Layout_NextSameLine)
    GuiText(gui, mod_setting_group_x_offset, 0, setting.ui_name)

    local text
    if detecting_key then
        text = "$menuoptions_configurecontrols_pressakey"
        local input = get_any_input()
        if input ~= nil then
            detecting_key = false
            if input == "Mouse_left" then
                disable_button = true
            end
            ModSettingSetNextValue(mod_setting_get_id(mod_id, setting), input, false)
        end
    else
        text = get_input_text(ModSettingGetNextValue(mod_setting_get_id(mod_id, setting)))
    end
    if disable_button and InputIsMouseButtonJustUp(Mouse_left) then
        disable_button = false
        GuiOptionsAddForNextWidget(gui, GUI_OPTION.NonInteractive)
    end
    if GuiButton(gui, im_id, mod_setting_group_x_offset + GuiGetTextDimensions(gui, setting.ui_name) + 10, 0, text) then
        detecting_key = true
    end

    mod_setting_tooltip(mod_id, gui, in_main_menu, setting)
end

--#endregion

local mod_id = "polymare"
mod_settings_version = 1
mod_settings =
{
    {
        id = "polymorph_key",
        ui_name = "Polymorph key",
        ui_description = "The key for polymorph.",
        value_default = "Key_p",
        scope = MOD_SETTING_SCOPE_RUNTIME,
        ui_fn = mod_setting_input,
    },
    {
        id = "extra_health",
        ui_name = "Extra starting health",
        ui_description = "Extra HP",
        value_default = 1,
        value_min = 0,
        value_max = 8,
        value_display_multiplier = 25,
        value_display_formatting = " $0 HP",
        scope = MOD_SETTING_SCOPE_RUNTIME,
    },
    {
        id = "polymorph_cap",
        ui_name = "Polymorph cap",
        ui_description = "Only allows polymorphing into creatures with less than twice the player's hp.",
        value_default = true,
        scope = MOD_SETTING_SCOPE_RUNTIME,
    },
}

function ModSettingsUpdate(init_scope)
    mod_settings_update(mod_id, mod_settings, init_scope)
end

function ModSettingsGuiCount()
    return mod_settings_gui_count(mod_id, mod_settings)
end

function ModSettingsGui(gui, in_main_menu)
    mod_settings_gui(mod_id, mod_settings, gui, in_main_menu)
end
