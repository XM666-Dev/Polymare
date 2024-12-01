dofile_once("mods/polymare/files/sult.lua")
dofile_once("data/scripts/debug/keycodes.lua")

ModLuaFileAppend("data/scripts/perks/perk.lua", "mods/polymare/files/perk_appends.lua")

local ModTextFileSetContent = ModTextFileSetContent
function polymorph(entity, target)
    local index = ModSettingGet("polymare.index") or 0
    ModSettingSet("polymare.index", index + 1)
    local xml = ("mods/polymare/files/polymorph/%i.xml"):format(index)
    ModTextFileSetContent(xml, ('<Entity><GameEffectComponent effect="POLYMORPH"polymorph_target="%s"frames="-2147483648"/>/>'):format(target))
    return LoadGameEffectEntityTo(entity, xml) + 1
end

function add_polymorphed_player(player)
    EntityAddTag(player, "player_unit")

    local damage_model = EntityGetFirstComponent(player, "DamageModelComponent")
    if damage_model ~= nil then
        local max_hp = math.max(ComponentGetValue2(damage_model, "max_hp"), get_max_hp_old())
        GlobalsSetValue("polymare.max_hp_old", tostring(max_hp))
        max_hp = max_hp + get_max_hp_addition()
        ComponentSetValue2(damage_model, "max_hp", max_hp)
        ComponentSetValue2(damage_model, "hp", max_hp)

        ComponentSetValue2(damage_model, "physics_objects_damage", false)
    end

    local genome = EntityGetFirstComponent(player, "GenomeDataComponent")
    if genome ~= nil then
        ComponentSetValue2(genome, "herd_id", StringToHerdId("player"))
    end

    local character_platforming = EntityGetFirstComponent(player, "CharacterPlatformingComponent")
    if character_platforming ~= nil then
        ComponentSetValue2(character_platforming, "run_velocity", ComponentGetValue2(character_platforming, "run_velocity") * 2)
        ComponentSetValue2(character_platforming, "fly_velocity_x", ComponentGetValue2(character_platforming, "fly_velocity_x") * 2)
        ComponentSetValue2(character_platforming, "fly_smooth_y", false)
    end

    local ai = EntityGetFirstComponentIncludingDisabled(player, "AnimalAIComponent")
    if ai ~= nil then
        local needs_food = ComponentGetValue2(ai, "needs_food")

        if needs_food then
            EntityAddComponent2(player, "IngestionComponent")
        end

        EntityAddComponent2(player, "KickComponent", {
            can_kick = ComponentGetValue2(ai, "attack_melee_enabled"),
            kick_radius = ComponentGetValue2(ai, "attack_melee_max_distance"),
            kick_damage = ComponentGetValue2(ai, "attack_melee_damage_max"),
            kick_knockback = ComponentGetValue2(ai, "attack_knockback_multiplier"),
        })
        local hotspot = EntityAddComponent2(player, "HotspotComponent", { _tags = "kick_pos" })
        ComponentSetValue2(hotspot, "offset", ComponentGetValue2(ai, "attack_melee_offset_x"), ComponentGetValue2(ai, "attack_melee_offset_y"))

        local t
        if not needs_food then
            t = { eating_delay_frames = 0x7FFFFFFF }
        end
        local platform_shooter = EntityAddComponent2(player, "PlatformShooterPlayerComponent", t)
        ComponentSetValue2(platform_shooter, "mDesiredCameraPos", GameGetCameraPos())
        local eating_area_radius_x = ComponentGetValue2(ai, "eating_area_radius_x")
        local eating_area_radius_y = ComponentGetValue2(ai, "eating_area_radius_y")
        local mouth_offset_x = ComponentGetValue2(ai, "mouth_offset_x")
        local mouth_offset_y = ComponentGetValue2(ai, "mouth_offset_y")
        ComponentSetValue2(platform_shooter, "eating_area_min", mouth_offset_x - eating_area_radius_x, mouth_offset_y - eating_area_radius_y)
        ComponentSetValue2(platform_shooter, "eating_area_max", mouth_offset_x + eating_area_radius_x, mouth_offset_y + eating_area_radius_y)
        EntityAddComponent2(player, "Inventory2Component", { full_inventory_slots_x = 16, full_inventory_slots_y = 1 })
        EntityAddComponent2(player, "AudioListenerComponent")
    end

    if EntityGetComponent(player, "ItemPickUpperComponent") == nil then
        EntityAddComponent2(player, "ItemPickUpperComponent", { is_in_npc = true })
    end
    local inventory_full = EntityCreateNew("inventory_full")
    EntityAddChild(player, inventory_full)
end

function load_polymorph(x, y)
    EntityLoad("data/entities/particles/polymorph_explosion.xml", x, y)
    GamePlaySound("data/audio/Desktop/game_effect.bank", "game_effect/polymorph/create", x, y)
end

function get_max_hp_old()
    return tonumber(GlobalsGetValue("polymare.max_hp_old", "0"))
end

function get_max_hp_addition()
    return tonumber(GlobalsGetValue("polymare.max_hp_addition", tostring(ModSettingGet("polymare.extra_health"))))
end

function OnPlayerSpawned(player)
    if has_flag_run_or_add("polymare.player_spawned_once") then return end

    local polymorphed_player = polymorph(player, "data/entities/animals/longleg.xml")
    add_polymorphed_player(polymorphed_player)

    ModSettingSetNextValue("better_polymorph.friendly_fire", false, false)
end

function OnWorldPreUpdate()
    local player = EntityGetWithTag("polymorphed_player")[1]
    if player == nil then return end

    local pick_upper = EntityGetFirstComponent(player, "ItemPickUpperComponent")
    local children = get_children(player)
    local i, inventory_quick = table.find(children, function(v) return EntityGetName(v) == "inventory_quick" end)
    if pick_upper ~= nil and inventory_quick ~= nil then
        ComponentSetValue2(pick_upper, "is_in_npc", false)
    end

    local wallet = EntityGetFirstComponent(player, "WalletComponent") or EntityAddComponent2(player, "WalletComponent", { money = tonumber(GlobalsGetValue("polymare.money", "0")) })
    GlobalsSetValue("polymare.money", ComponentGetValue2(wallet, "money"))

    local controls = EntityGetFirstComponent(player, "ControlsComponent")
    if controls ~= nil then
        ComponentSetValue2(controls, "mButtonDownRun", true)
    end

    local kick = EntityGetFirstComponent(player, "KickComponent")
    local ai = EntityGetFirstComponentIncludingDisabled(player, "AnimalAIComponent")
    if kick ~= nil and ComponentGetValue2(kick, "can_kick") and controls ~= nil and ComponentGetValue2(controls, "mButtonFrameKick") == GameGetFrameNum() and ai ~= nil then
        ComponentSetValue2(controls, "mButtonFrameKick", GameGetFrameNum() + ComponentGetValue2(ai, "attack_melee_action_frame") - 18)
        GamePlayAnimation(player, "attack", 2)
    end

    local x, y = EntityGetTransform(player)
    local player_filename = EntityGetFilename(player)
    local polymorph_table = PolymorphTableGet()
    local polymorph_table_rare = PolymorphTableGet(true)
    local player_damage_model = EntityGetFirstComponent(player, "DamageModelComponent")
    local enemy = table.iterate(EntityGetInRadiusWithTag(x, y, 32, "enemy"), function(a, b)
        local flag = true
        if b ~= nil then
            local a_x, a_y = EntityGetTransform(a)
            local b_x, b_y = EntityGetTransform(b)
            flag = get_distance2(a_x, a_y, x, y) < get_distance2(b_x, b_y, x, y)
        end
        local filename = EntityGetFilename(a)
        local damage_model = EntityGetFirstComponent(a, "DamageModelComponent")
        return filename ~= player_filename and
            (table.find(polymorph_table, function(v) return v == filename end) or table.find(polymorph_table_rare, function(v) return v == filename end)) and
            (not ModSettingGet("polymare.polymorph_cap") or damage_model ~= nil and player_damage_model ~= nil and ComponentGetValue2(damage_model, "hp") < ComponentGetValue2(player_damage_model, "max_hp") * 2) and
            flag
    end)
    local damage_model = EntityGetFirstComponent(player, "DamageModelComponent")
    if InputIsKeyJustDown(Key_p) and enemy ~= nil and damage_model ~= nil then
        GlobalsSetValue("polymare.max_hp_addition", tostring(ComponentGetValue2(damage_model, "max_hp") - get_max_hp_old()))

        GameDropPlayerInventoryItems(player)

        local effect = get_game_effect(player, "POLYMORPH")
        if effect ~= nil then
            set_component_enabled(effect, false)
        end
        EntityRemoveTag(player, "polymorphed")
        local polymorphed_player = polymorph(player, EntityGetFilename(enemy))
        add_polymorphed_player(polymorphed_player)
        load_polymorph(x, y)
    end
end
