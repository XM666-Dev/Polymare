dofile_once("mods/polymare/files/tactic.lua")
dofile_once("mods/polymare/files/input.lua")
local nxml = dofile_once("mods/polymare/files/nxml.lua")

ModLuaFileAppend("data/scripts/perks/perk.lua", "mods/polymare/files/perk_appends.lua")

local ModTextFileSetContent = ModTextFileSetContent
function polymorph(entity, target)
    local index = ModSettingGet("polymare.index") or 0
    ModSettingSet("polymare.index", index + 1)
    local xml = ("mods/polymare/files/polymorph/%i.xml"):format(index)
    ModTextFileSetContent(xml, ('<Entity><GameEffectComponent effect="POLYMORPH"polymorph_target="%s"frames="-2147483648"/>/>'):format(target))
    return LoadGameEffectEntityTo(entity, xml) + 1
end

function add_polymorphed_player(player, max_hp, money, inventory_quick, inventory_full)
    EntityAddTag(player, "player_unit")

    local damage_model = EntityGetFirstComponent(player, "DamageModelComponent")
    if damage_model ~= nil then
        local base = tonumber(GlobalsGetValue("polymare.max_hp_base")) or 0
        local base_new = math.max(ComponentGetValue2(damage_model, "max_hp"), base)
        GlobalsSetValue("polymare.max_hp_base", ("%.16a"):format(base_new))
        local max_hp_new = base_new + max_hp - base
        ComponentSetValue2(damage_model, "max_hp", max_hp_new)
        ComponentSetValue2(damage_model, "hp", max_hp_new)

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
            --kick_knockback = ComponentGetValue2(ai, "attack_knockback_multiplier") * 0.8,
        })
        local hotspot = EntityAddComponent2(player, "HotspotComponent", { _tags = "kick_pos" })
        ComponentSetValue2(hotspot, "offset", ComponentGetValue2(ai, "attack_melee_offset_x"), ComponentGetValue2(ai, "attack_melee_offset_y"))

        local platform_shooter = EntityAddComponent2(player, "PlatformShooterPlayerComponent", not needs_food and { eating_delay_frames = 0x7FFFFFFF } or nil)
        local eating_area_radius_x = ComponentGetValue2(ai, "eating_area_radius_x")
        local eating_area_radius_y = ComponentGetValue2(ai, "eating_area_radius_y")
        local mouth_offset_x = ComponentGetValue2(ai, "mouth_offset_x")
        local mouth_offset_y = ComponentGetValue2(ai, "mouth_offset_y")
        ComponentSetValue2(platform_shooter, "eating_area_min", mouth_offset_x - eating_area_radius_x, mouth_offset_y - eating_area_radius_y)
        ComponentSetValue2(platform_shooter, "eating_area_max", mouth_offset_x + eating_area_radius_x, mouth_offset_y + eating_area_radius_y)
        ComponentSetValue2(platform_shooter, "mDesiredCameraPos", GameGetCameraPos())
    end
    EntityAddComponent2(player, "GunComponent")

    EntityAddComponent2(player, "Inventory2Component", { full_inventory_slots_x = 16, full_inventory_slots_y = 1 })
    EntityAddComponent2(player, "WalletComponent", { money = money })
    local pick_upper = EntityGetFirstComponent(player, "ItemPickUpperComponent")
    ComponentSetValue2(pick_upper or EntityAddComponent2(player, "ItemPickUpperComponent"), "is_in_npc", false)
    inventory_quick = inventory_quick or pick_upper ~= nil and EntityCreateNew("inventory_quick") or nil
    if inventory_quick ~= nil then
        EntityAddChild(player, inventory_quick)
    end
    if inventory_full ~= nil then
        EntityAddChild(player, inventory_full)
    end

    EntityAddComponent2(player, "AudioListenerComponent")
end

function load_polymorph(x, y)
    EntityLoad("data/entities/particles/polymorph_explosion.xml", x, y)
    GamePlaySound("data/audio/Desktop/misc.bank", "game_effect/polymorph/create", x, y)
end

function load_illusion(x, y)
    EntityLoad("data/entities/particles/poof_blue.xml", x, y)
    GamePlaySound("data/audio/Desktop/animals.bank", "animals/illusion/create", x, y)
end

function get_money(entity)
    local wallet = EntityGetFirstComponent(entity, "WalletComponent")
    if wallet ~= nil then
        return ComponentGetValue2(wallet, "money")
    end
    return 0
end

function OnPlayerSpawned(player)
    if has_flag_run_or_add("polymare.player_spawned_once") then return end

    local money = get_money(player)
    local polymorphed_player = polymorph(player, "data/entities/animals/longleg.xml")
    add_polymorphed_player(polymorphed_player, ModSettingGet("polymare.extra_health"), money, nil, EntityCreateNew("inventory_full"))
end

local sprite_xmls = {}
local polymorph_table_variant = {}
function OnWorldPreUpdate()
    local player = EntityGetWithTag("polymorphed_player")[1] or EntityGetWithTag("player_unit")[1]
    if player == nil then return end

    local x, y = EntityGetTransform(player)
    local player_filename = EntityGetFilename(player)
    local player_damage_model = EntityGetFirstComponent(player, "DamageModelComponent")
    local polymorph_table = PolymorphTableGet()
    local polymorph_table_rare = PolymorphTableGet(true)

    local function get_weight(entity)
        local damage_model = EntityGetFirstComponent(entity, "DamageModelComponent")
        return damage_model and ComponentGetValue2(damage_model, "hp") + ComponentGetValue2(damage_model, "max_hp") or 0
    end
    local function is_closer(a, b)
        local a_x, a_y = EntityGetTransform(a)
        local b_x, b_y = EntityGetTransform(b)
        return get_distance2(a_x, a_y, x, y) < get_distance2(b_x, b_y, x, y)
    end

    local controls = EntityGetFirstComponent(player, "ControlsComponent")
    local sprite = EntityGetFirstComponent(player, "SpriteComponent")
    if controls ~= nil and sprite ~= nil then
        local image_file = ComponentGetValue2(sprite, "image_file")
        if sprite_xmls[image_file] == nil then
            sprite_xmls[image_file] = nxml.parse_file(image_file)
        end
        local frame = GameGetFrameNum()

        local throw = true
        for animation in sprite_xmls[image_file]:each_of("RectAnimation") do
            if animation.attr.name == "throw" then
                throw = false
                break
            end
        end
        local inventory = EntityGetFirstComponent(player, "Inventory2Component")
        if inventory ~= nil then
            local item = validate(ComponentGetValue2(inventory, "mActiveItem"))
            if item ~= nil then
                local ability = EntityGetFirstComponentIncludingDisabled(item, "AbilityComponent")
                if ability ~= nil and ComponentGetValue2(ability, "throw_as_item") and ComponentGetValue2(controls, "mButtonFrameThrow") == frame and throw then
                    GamePlayAnimation(player, "attack_ranged", 2)
                end
            end
        end

        local entity = 0
        local inventory_quick = table.find(EntityGetAllChildren(player), function(child) return EntityGetName(child) == "inventory_quick" end)
        if inventory_quick == nil then
            entity = table.iterate(table.filter(EntityGetInRadius(0, 0, math.huge), function(v)
                local item = EntityGetFirstComponent(v, "ItemComponent")
                return item ~= nil and ComponentGetValue2(item, "preferred_inventory") ~= "QUICK" and ComponentGetValue2(item, "auto_pickup")
            end), is_closer) or 1
        end
        local pick_upper = EntityGetFirstComponent(player, "ItemPickUpperComponent")
        if pick_upper ~= nil then
            ComponentSetValue2(pick_upper, "only_pick_this_entity", entity)
        end

        local frame_wait
        for animation in sprite_xmls[image_file]:each_of("RectAnimation") do
            if animation.attr.name == "attack" then
                frame_wait = animation.attr.frame_wait
                break
            end
        end
        local kick = EntityGetFirstComponent(player, "KickComponent")
        local ai = EntityGetFirstComponentIncludingDisabled(player, "AnimalAIComponent")
        if kick ~= nil and ComponentGetValue2(kick, "can_kick") and ComponentGetValue2(controls, "mButtonFrameKick") == frame and ai ~= nil then
            ComponentSetValue2(controls, "mButtonFrameKick", frame + ComponentGetValue2(ai, "attack_melee_action_frame") * frame_wait * 60 - 18)
            GamePlayAnimation(player, "attack", 2)
        end
    end

    local enemies = table.filter(EntityGetInRadiusWithTag(x, y, 32, "mortal"), function(v)
        local filename = EntityGetFilename(v)
        if not filename:find("^data") and not filename:find("^mods") or filename == player_filename then return false end
        local variant = polymorph_table_variant[filename]
        local find = table.find(polymorph_table, filename) or table.find(polymorph_table_rare, filename) or variant
        if not find and variant == nil then
            local xml = nxml.parse_file(filename)
            local base = xml:first_of("Base")
            find = base ~= nil and (table.find(polymorph_table, base.attr.file) or table.find(polymorph_table_rare, base.attr.file)) ~= nil
            if find then
                local base_xml = nxml.parse_file(base.attr.file)
                xml.attr.name = base_xml.attr.name
                ModTextFileSetContent("mods/polymare/files/entities/" .. filename, tostring(xml))
            end
            polymorph_table_variant[filename] = find
        end
        return find
    end)
    local player_weight = get_weight(player) * (2 + GameGetOrbCountThisRun() * 0.5)
    local enemy = table.iterate(table.filter(enemies, function(v)
        return not ModSettingGet("polymare.polymorph_cap") or get_weight(v) <= player_weight
    end), is_closer)
    if read_input_just(tostring(ModSettingGet("polymare.polymorph_key"))) then
        if enemy == nil then
            enemy = table.iterate(enemies, is_closer)
            if enemy ~= nil then
                load_illusion(x, y)
                load_illusion(EntityGetTransform(enemy))
            end
        else
            local max_hp = player_damage_model ~= nil and ComponentGetValue2(player_damage_model, "max_hp") or 0
            local money = get_money(player)
            local inventory_quick = table.find(EntityGetAllChildren(player), function(child) return EntityGetName(child) == "inventory_quick" end)
            local inventory_full = table.find(EntityGetAllChildren(player), function(child) return EntityGetName(child) == "inventory_full" end)
            EntityRemoveFromParent(inventory_quick)
            EntityRemoveFromParent(inventory_full)

            local effect = get_game_effect(player, "POLYMORPH")
            if effect ~= nil then
                set_component_enabled(effect, false)
            end
            EntityRemoveTag(player, "polymorphed")
            EntityRemoveTag(player, "polymorphable_NOT")
            local filename = EntityGetFilename(enemy)
            local filename_variant = "mods/polymare/files/entities/" .. filename
            local polymorphed_player = polymorph(player, ModDoesFileExist(filename_variant) and filename_variant or filename)
            add_polymorphed_player(polymorphed_player, max_hp, money, inventory_quick, inventory_full)
            load_polymorph(x, y)
            load_polymorph(EntityGetTransform(enemy))
        end
    end
end
