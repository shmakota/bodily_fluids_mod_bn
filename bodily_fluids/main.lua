gdebug.log_info("Bodily Fluids: main")
local mod = game.mod_runtime[game.current_mod]

------------------------------------------------------------
-- Every turn
------------------------------------------------------------
function mod.every_turn()
    local avatar = gapi.get_avatar()
    if not avatar then return end

    if not avatar:has_trait(MutationBranchId.new("pee")) then
        avatar:set_mutation(MutationBranchId.new("pee"))
    end

    if not avatar:has_trait(MutationBranchId.new("defecate")) then
        avatar:set_mutation(MutationBranchId.new("defecate"))
    end

    handle_bladder(avatar)
    handle_stomach(avatar)

    --mod.debug_burn(avatar)
end

------------------------------------------------------------
-- BLADDER / PEE
------------------------------------------------------------
function handle_bladder(avatar)
    local bladder = tonumber(avatar:get_value("bladder")) or 0

    bladder = bladder + get_thirst_difference() * 1
    if bladder > 100 then bladder = 100 end
    avatar:set_value("bladder", tostring(bladder))

    if bladder >= 90 and avatar:get_value("bladder_warned_90") ~= "1" then
        if not avatar:has_trait( MutationBranchId.new("incontinent") ) then
            if gapi.get_avatar().current_activity_id ~= ActivityTypeId.NULL_ID then
                gapi.get_avatar():cancel_activity()
            end
            gapi.add_msg(MsgType.bad, "You're about to pee yourself!")
        end
        avatar:set_value("bladder_warned_90", "1")
    elseif bladder >= 75 and bladder < 90 and avatar:get_value("bladder_warned_75") ~= "1" then
        gapi.add_msg(MsgType.info, "You really need to pee soon.")
        avatar:set_value("bladder_warned_75", "1")
    elseif bladder >= 50 and bladder < 75 and avatar:get_value("bladder_warned_50") ~= "1" then
        gapi.add_msg(MsgType.info, "Your bladder is starting to feel full.")
        avatar:set_value("bladder_warned_50", "1")
    end

    if avatar:has_active_mutation(MutationBranchId.new("pee")) or avatar:hp_percentage() <= 5 then
        avatar:deactivate_mutation(MutationBranchId.new("pee"))
        if math.floor(avatar:get_value("bladder", 0 )/10) < 1 or avatar:has_trait( MutationBranchId.new("incontinent") ) then
            gapi.add_msg(MsgType.info, "You don't feel the urge to go yet.")
        else
            expel(avatar, "pee", false)
        end
    end

    if bladder >= 100 then
        expel(avatar, "pee", true)
    end
end

function get_thirst_difference()
    local avatar = gapi.get_avatar()
    if not avatar then return 0 end

    local last_thirst = tonumber(avatar:get_value("last_thirst")) or avatar:get_thirst()
    local thirst_current = avatar:get_thirst() or 0
    local difference = thirst_current - last_thirst

    --gapi.add_msg("[BODILY DEBUG] Thirst difference: " .. tostring(difference))

    avatar:set_value("last_thirst", tostring(thirst_current))
    return difference
end

function get_kcal_difference()
    local avatar = gapi.get_avatar()
    if not avatar then return 0 end

    local last_kcal = tonumber(avatar:get_value("last_kcal")) or avatar:get_stored_kcal()
    local kcal_current = avatar:get_stored_kcal() or 0
    local difference = kcal_current - last_kcal

    --gapi.add_msg("[BODILY DEBUG] Kcal difference: " .. tostring(difference))

    avatar:set_value("last_kcal", tostring(kcal_current))
    return difference
end

------------------------------------------------------------
-- STOMACH / DEFECATE
------------------------------------------------------------
function handle_stomach(avatar)
    local stomach = tonumber(avatar:get_value("stomach")) or 0

    stomach = stomach - get_kcal_difference()/20
    if stomach > 100 then stomach = 100 end
    avatar:set_value("stomach", tostring(stomach))

    if stomach >= 90 and avatar:get_value("stomach_warned_90") ~= "1" then
        if not avatar:has_trait( MutationBranchId.new("incontinent") ) then
            if gapi.get_avatar().current_activity_id ~= ActivityTypeId.NULL_ID then
                gapi.get_avatar():cancel_activity()
            end
            gapi.add_msg(MsgType.bad, "You're about to soil yourself!")
        end
        avatar:set_value("stomach_warned_90", "1")
    elseif stomach >= 75 and stomach < 90 and avatar:get_value("stomach_warned_75") ~= "1" then
        gapi.add_msg(MsgType.info, "You really need to defacate soon.")
        avatar:set_value("stomach_warned_75", "1")
    elseif stomach >= 50 and stomach < 75 and avatar:get_value("stomach_warned_50") ~= "1" then
        gapi.add_msg(MsgType.info, "Your bowels are starting to feel full.")
        avatar:set_value("stomach_warned_50", "1")
    end

    if avatar:has_active_mutation(MutationBranchId.new("defecate")) or avatar:hp_percentage() <= 5 then
        avatar:deactivate_mutation(MutationBranchId.new("defecate"))
        if math.floor(avatar:get_value("stomach", 0 )/10) < 1 or avatar:has_trait( MutationBranchId.new("incontinent") ) then
            gapi.add_msg(MsgType.info, "You don't feel the urge to go yet.")
        else
            expel(avatar, "defecate", false)
        end
    end

    if stomach >= 100 then
        expel(avatar, "defecate", true)
    end
end

------------------------------------------------------------
-- Get a descriptive name for the target tile
------------------------------------------------------------
function get_relief_target_name(pos)
    local map = gapi.get_map()

    -- check for toilet or shallow pit
    local furn = map:get_furn_at(pos)
    if furn and furn:str_id():str() == "f_toilet" then
        return "in the toilet"
    end
    local shallow_pit = map:get_ter_at(pos)
    if shallow_pit and shallow_pit:str_id():str() == "t_shallow_pit" then
        return "in the shallow pit"
    end

    -- check for monster
    local mon = gapi.get_monster_at(pos)
    if mon then
        return "on " .. mon:get_name()
    end

    if gapi.get_map():has_field_at(pos, FieldTypeIntId.new( FieldTypeId.new("fd_fire") ) ) then
        return "on the fire, reducing it's intensity"
    end

    -- fallback
    return "on the ground"
end

------------------------------------------------------------
-- Unified expel function (pee or defecate)
------------------------------------------------------------
function expel(avatar, type, forced)
    local pos = avatar:get_pos_ms()
    local is_pee = (type == "pee")
    local stat_name = is_pee and "bladder" or "stomach"
    local item_type = is_pee and "human_urine" or "human_feces"
    local effect_bad = is_pee and "peed_yourself" or "defecated_yourself"
    local self_msg = "You relieve yourself %s."
    local forced_msg = "You soil yourself!"
    local wet_clothing = false
    local place_fluid = true
    local amount = math.floor( avatar:get_value(stat_name, 0)/10 )

    -- Check for diaper
    local diaper_item
    for _, item in pairs(avatar:all_items(true)) do
        if item:get_type() == ItypeId.new("diaper") then
            diaper_item = item
            break
        end
    end

    if forced then
        if diaper_item then
            if avatar:has_trait(MutationBranchId.new("incontinent")) then
                gapi.get_avatar():add_morale(
                    MoraleTypeDataId.new("morale_used_diaper"),
                    5, 5,
                    TimeDuration.from_hours(2),
                    TimeDuration.from_hours(1),
                    false, nil
                )
            end
            diaper_item:convert(ItypeId.new("dirty_diaper"))
            gapi.add_msg(MsgType.info, "You use your diaper.")
            place_fluid = false
        else
            gapi.get_avatar():add_morale(
                MoraleTypeDataId.new("morale_soiled_yourself"),
                -5, -5,
                TimeDuration.from_hours(2),
                TimeDuration.from_hours(1),
                false, nil
            )
            gapi.add_msg(MsgType.bad, forced_msg)
            wet_clothing = true
        end
    else
        if is_pee and avatar.male then
            pos = gapi.choose_adjacent("Pee where?")
        end
        local relief_target = get_relief_target_name(pos)
        local used_toilet = gapi.get_map():get_furn_at(pos):str_id():str() == "f_toilet" or gapi.get_map():get_ter_at(pos):str_id():str() == "t_shallow_pit"
        if used_toilet then
            gapi.get_avatar():add_morale(
                MoraleTypeDataId.new("morale_used_toilet"),
                5, 5,
                TimeDuration.from_hours(2),
                TimeDuration.from_hours(1),
                false, nil
            )
        end

        gapi.add_msg(MsgType.good, string.format(self_msg, relief_target))
    end

    -- Mark clothing as wet if needed
    if wet_clothing then
        for _, item in pairs(gapi.get_avatar():all_items(true)) do
            if item:covers(BodyPartTypeIntId.new(BodyPartTypeId.new("leg_l"))) or
               item:covers(BodyPartTypeIntId.new(BodyPartTypeId.new("leg_r"))) then
                item:set_flag(JsonFlagId.new("WET"))
            end
        end
    end

    -- Create puddle or pile
    if place_fluid then
        gapi.get_map():create_item_at(pos, ItypeId.new(item_type), amount)
        if gapi.get_map():has_field_at(pos, FieldTypeIntId.new( FieldTypeId.new("fd_fire") ) ) then
            -- requires 30% of bladder per intensity level (max is 3)
            gapi.add_msg(tostring(math.floor(amount/3)))
            gapi.get_map():mod_field_int_at(pos, FieldTypeIntId.new( FieldTypeId.new("fd_fire") ), -math.floor(amount/3) )
        end
    end

    -- Reset needs/warnings
    for _, suffix in ipairs({"", "_warned_50", "_warned_75", "_warned_90"}) do
        avatar:set_value(stat_name .. suffix, "0")
    end
end

------------------------------------------------------------
-- DEBUG: Stat Burn Tracking + Time to Fill
------------------------------------------------------------
local debug_stats = {
    bladder_last = 0,
    stomach_last = 0,
    turns = 0,
    bladder_total = 0,
    stomach_total = 0,
}
-- Adjust this if your game uses a different time scale:
-- Example: 1 turn = 6 seconds  → 600 turns/hour
local TURNS_PER_HOUR = 3600
function mod.debug_burn(avatar)
    local bladder = tonumber(avatar:get_value("bladder")) or 0
    local stomach = tonumber(avatar:get_value("stomach")) or 0

    if debug_stats.turns > 0 then
        local delta_bladder = bladder - debug_stats.bladder_last
        local delta_stomach = stomach - debug_stats.stomach_last

        -- Handle rollover if stat reset to 0
        if delta_bladder < 0 then delta_bladder = bladder end
        if delta_stomach < 0 then delta_stomach = stomach end

        debug_stats.bladder_total = debug_stats.bladder_total + delta_bladder
        debug_stats.stomach_total = debug_stats.stomach_total + delta_stomach

        local avg_bladder_rate = debug_stats.bladder_total / debug_stats.turns
        local avg_stomach_rate = debug_stats.stomach_total / debug_stats.turns

        -- Prevent divide-by-zero
        if avg_bladder_rate > 0 then
            local bladder_remaining = 100 - bladder
            local turns_to_fill = bladder_remaining / avg_bladder_rate
            local hours_to_fill = turns_to_fill / TURNS_PER_HOUR
            gdebug.log_info(string.format(
                "[BODILY DEBUG] Bladder: %.2f%% full | +%.4f/turn | ~%.2f hours to 100%%",
                bladder, avg_bladder_rate, hours_to_fill
            ))
        end

        if avg_stomach_rate > 0 then
            local stomach_remaining = 100 - stomach
            local turns_to_fill = stomach_remaining / avg_stomach_rate
            local hours_to_fill = turns_to_fill / TURNS_PER_HOUR
            gdebug.log_info(string.format(
                "[BODILY DEBUG] Stomach: %.2f%% full | +%.4f/turn | ~%.2f hours to 100%%",
                stomach, avg_stomach_rate, hours_to_fill
            ))
        end
    end

    debug_stats.turns = debug_stats.turns + 1
    debug_stats.bladder_last = bladder
    debug_stats.stomach_last = stomach
end
