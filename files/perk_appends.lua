function perk_pickup(entity_item, entity_who_picked, item_name, do_cosmetic_fx, kill_other_perks, no_perk_entity_)
    -- fetch perk info ---------------------------------------------------

    local no_perk_entity = no_perk_entity_ or false
    local pos_x, pos_y

    if no_perk_entity then
        pos_x, pos_y = EntityGetTransform(entity_who_picked)
    else
        pos_x, pos_y = EntityGetTransform(entity_item)
    end

    local perk_name = "PERK_NAME_NOT_DEFINED"
    local perk_desc = "PERK_DESCRIPTION_NOT_DEFINED"

    local perk_id = ""

    if no_perk_entity then
        perk_id = item_name
    else
        edit_component(entity_item, "VariableStorageComponent", function(comp, vars)
            perk_id = ComponentGetValue(comp, "value_string")
        end)
    end

    local perk_data = get_perk_with_id(perk_list, perk_id)
    if perk_data == nil then
        return
    end

    -- Get perk's flag name

    local flag_name = get_perk_picked_flag_name(perk_id)

    -- update how many times the perk has been picked up this run -----------------

    local pickup_count = tonumber(GlobalsGetValue(flag_name .. "_PICKUP_COUNT", "0"))
    pickup_count = pickup_count + 1
    GlobalsSetValue(flag_name .. "_PICKUP_COUNT", tostring(pickup_count))

    -- load perk for entity_who_picked -----------------------------------
    local add_progress_flags = not GameHasFlagRun("no_progress_flags_perk")

    if add_progress_flags then
        local flag_name_persistent = string.lower(flag_name)
        if (not HasFlagPersistent(flag_name_persistent)) then
            GameAddFlagRun("new_" .. flag_name_persistent)
        end
        AddFlagPersistent(flag_name_persistent)
    end
    GameAddFlagRun(flag_name)

    -- certain other perks may be marked as picked-up
    if perk_data.remove_other_perks ~= nil then
        for i, v in ipairs(perk_data.remove_other_perks) do
            local f = get_perk_picked_flag_name(v)
            GameAddFlagRun(f)

            -- NOTE( Petri ): 8.8.2023 - Thank you to Noita community for this fix.
            -- this should remove the related perks from the perk pool. 4realz.
            local remove_perk_pickup_count = tonumber(GlobalsGetValue(f .. "_PICKUP_COUNT", "0"))
            remove_perk_pickup_count = remove_perk_pickup_count + 1
            GlobalsSetValue(f .. "_PICKUP_COUNT", tostring(remove_perk_pickup_count))
        end
    end

    give_perk_to_enemy(perk_data, entity_who_picked, entity_item, 0, 0, pickup_count)

    perk_name = GameTextGetTranslatedOrNot(perk_data.ui_name)
    perk_desc = GameTextGetTranslatedOrNot(perk_data.ui_description)

    -- cosmetic fx -------------------------------------------------------
    if do_cosmetic_fx then
        local enemies_killed = tonumber(StatsBiomeGetValue("enemies_killed"))

        if (enemies_killed ~= 0) then
            EntityLoad("data/entities/particles/image_emitters/perk_effect.xml", pos_x, pos_y)
        else
            EntityLoad("data/entities/particles/image_emitters/perk_effect_pacifist.xml", pos_x, pos_y)
        end

        GamePrintImportant(GameTextGet("$log_pickedup_perk", GameTextGetTranslatedOrNot(perk_name)), perk_desc)
    end

    -- disable the perk rerolling machine --------------------------------
    local x, y = EntityGetTransform(entity_who_picked)
    local rerolls = EntityGetInRadiusWithTag(x, y, 200, "perk_reroll_machine")
    local other_perks = EntityGetInRadiusWithTag(x, y, 200, "item_perk")

    print("Other perks: " .. tostring(#other_perks) .. ", " .. tostring(kill_other_perks))

    local disable_reroll = false

    if (#other_perks <= 1) then
        disable_reroll = true
    end

    -- remove all perk items (also this one!) ----------------------------
    if kill_other_perks then
        local perk_destroy_chance = tonumber(GlobalsGetValue("TEMPLE_PERK_DESTROY_CHANCE", "100"))
        SetRandomSeed(pos_x, pos_y)

        if (Random(1, 100) <= perk_destroy_chance) then
            -- removes all the perks
            local all_perks = EntityGetWithTag("perk")
            disable_reroll = true

            if (#all_perks > 0) then
                for i, entity_perk in ipairs(all_perks) do
                    if entity_perk ~= entity_item then
                        EntityKill(entity_perk)
                    end
                end
            end
        end
    end

    if disable_reroll then
        for i, rid in ipairs(rerolls) do
            local reroll_comp = EntityGetFirstComponent(rid, "ItemCostComponent")

            if (reroll_comp ~= nil) then
                EntitySetComponentIsEnabled(rid, reroll_comp, false)
            end

            reroll_comp = EntityGetComponent(rid, "SpriteComponent", "shop_cost")

            if (reroll_comp ~= nil) then
                for a, b in ipairs(reroll_comp) do
                    EntitySetComponentIsEnabled(rid, b, false)
                end
            end

            EntitySetComponentsWithTagEnabled(rid, "perk_reroll_disable", false)
        end
    end

    if (no_perk_entity == false) then
        EntityKill(entity_item) -- entity item should always be killed, hence we don't kill it in the above loop
    end
end
