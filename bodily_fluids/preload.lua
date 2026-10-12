gdebug.log_info("Bodily Fluids: preload")
local mod = game.mod_runtime[game.current_mod]
local storage = game.mod_storage[game.current_mod]

-- Register the hook (5 turns duration is a hack to make sure we aren't applying pressure when moving, but also ends up being good balance. with higher skill you're unlikely to bleed out, but still possible)
gapi.add_on_every_x_hook(TimeDuration.from_turns(1), function() mod.every_turn() end)

gapi.register_action_menu_entry({
  id = "bodily_fluids:relieve_yourself",
  name = "Relieve yourself",
  category = "misc",
  hotkey = "d",
  fn = function()
    local ui = UiList.new()
    ui:title("Relieve yourself")
    ui:add(1, "Urinate")
    ui:add(2, "Defecate")
    local query = ui:query()
    if query == 1 then
      mod.attempt_urinate()
    elseif query == 2 then
      mod.attempt_defecate()
    end
  end,
})

---@param params { user: Character, pos: TripointBubMs }
game.examine_functions["BODILY_FLUIDS_TOILET"] = function(params) mod.examine_toilet(params) end

sidebar.register_widget({
  id = "bodily_fluids",
  name = "Bodily Fluids",
  height = 1,
  order = 8,
  always_draw = true,
  ---@param w integer
  ---@param h integer
  draw = function(w, h)
    local avatar = gapi.get_avatar()
    if not avatar then return {} end

    ---@param key string
    local function clamp_stat(key)
      local raw = tonumber(avatar:get_value(key))
      raw = raw or 0
      raw = math.max(0, math.min(100, raw))
      return math.floor(raw)
    end

    local bladder = clamp_stat("bladder")
    local stomach = clamp_stat("stomach")

    ---@param value number
    local function urgency_color(value)
      if value >= 90 then
        return "c_light_red"
      elseif value >= 70 then
        return "c_red"
      elseif value >= 50 then
        return "c_yellow"
      end
      return "c_light_green"
    end

    ---@param value number
    local function colored_value(value)
      local formatted = string.format("%3d", value)
      return [[<color_]] .. urgency_color(value) .. [[>]] .. formatted .. [[</color>]] .. [[%]]
    end

    local def_text = "Bowels: " .. colored_value(stomach)
    local uri_text = "Bladder: " .. colored_value(bladder)

    ---@param line string
    ---@param width integer
    local function align_center(line, width)
      width = math.max(1, width)
      if #line >= width then return line end
      local pad = width - #line
      local left = math.floor(pad / 2)
      return string.rep(" ", left) .. line
    end

    local widget_width = math.max(1, w)
    local between_count = math.max(2, math.floor(widget_width / 4))
    local spacer = string.rep(" ", between_count)
    local combined = def_text .. spacer .. uri_text
    combined = align_center(combined, widget_width)

    return { { text = combined, color = "c_light_gray" } }
  end,
})
