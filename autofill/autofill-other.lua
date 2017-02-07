--luacheck: ignore flying_text
local autofill = {}
--autofill.gui = require("gui")
--autofill.default_sets = require("sets/default-sets")
autofill.priorities = {["qty"]="qty", ["max"]="max", ["min"]="min"}
autofill.inv = {ammo=defines.inventory.ammo, fuel=defines.inventory.fuel, main=defines.inventory.player_main, quickbar=defines.inventory.player_quickbar}

require("stdlib/utils/quickstart")
-------------------------------------------------------------------------------
--[[autofill functions]]--

local function get_highest_value(tbl)
  for item, value in table.spairs(tbl, function(t,a,b) return t[b] < t[a] end) do
    if game.item_prototypes[item] then
      return item, value
    end
  end
  return false
end

--Increment the y position for flying text
local function increment_position(position)
  local x = position.x
  local y = position.y - 1
  return function ()
    y=y+1
    return {x=x, y=y}
  end
end

-- local function count_slots(tbl)
--   local categories = {}
--   for i=1, #tbl.slots do
--     local slot = tbl.slots[i]
--     if not categories[slot.type] then
--       categories[slot.type]=1
--       temp[#temp+1]=slot.category
--     else
--       categories[slot.category] = categories[slot.category] + 1
--     end
--   end
--   return categories
-- end

function autofill.fill_entity(entity, pdata, set)
  doDebug("Filling entity -" .. entity.name)

  local player = game.players[pdata.player_index]

  --Increment y position everytime text_pos is called
  local text_pos = increment_position(entity.position)

  --local fuel_slots = pcall(#entity.get_inventory(defines.inventory.fuel))
  -- local duplicate_counts = {}

  --Get inventories
  local main_inventory = player.get_inventory(defines.inventory.player_main)
  local quickbar = player.get_inventory(defines.inventory.player_quickbar)
  local vehicle_inventory
  local ok, _ = pcall(function() vehicle_inventory = player.vehicle.get_inventory(defines.inventory.car_trunk) end)
  if not ok then vehicle_inventory = false end

  --Loop through each slot in the set.
  for i=1, #set.slots do
    local color = defines.colors.red -- Color for fying text
    local item = false -- The item to insert
    local item_count = 0 -- Total count of item in inventory and car inventory
    local insert_count = 0 -- Count of items to insert
    local group_count = 1 -- Num of items in the group. (Hand + Quickbar)

    -- Get the current slot
    local slot = set.slots[i]
    --verify or set existing priority
    local priority = autofill.priorities[slot.priority] or "qty"

    --START Item Count --------------------------------------------------------
    --Get the item list from player or default if no player
    local item_list = pdata.categories[slot.category] or global.default_items[slot.category]

    --No item list or item list is not a table.
    if not item_list or type(item_list) ~= "table" then
      flying_text({"autofill.invalid-category"}, color, text_pos(), entity.surface)
      doDebug("Missing or invalid Category")
      goto break_out
    end

    if player.cheat_mode then
      item = get_highest_value(item_list)
      if item then item_count = 1000000 end
      doDebug("Priority=Cheat ".. item .. "/" .. item_count)
    elseif priority=="qty" then
      for item_name, _ in pairs(item_list) do
        if game.item_prototypes[item_name] then
          if (main_inventory.get_item_count(item_name) > item_count)
          or (vehicle_inventory and main_inventory.get_item_count(item_name) + vehicle_inventory.get_item_count(item_name) > item_count) then
            item = item_name
            item_count = (not vehicle_inventory and main_inventory.get_item_count(item_name) or main_inventory.get_item_count(item_name) + vehicle_inventory.get_item_count(item_name))
          end
        end
      end
      doDebug("Priority=qty ".. item .. "/" .. item_count)
    elseif priority == "max" then
      for item_name, _ in table.spairs(item_list, function(t,a,b) return t[b] < t[a] end) do
        if game.item_prototypes[item_name] and main_inventory.get_item_count(item_name) > 0 or (vehicle_inventory and vehicle_inventory.get_item_count(item_name) > 0) then
          item = item_name
          item_count = main_inventory.get_item_count(item)
          item_count = not vehicle_inventory and item_count or item_count + vehicle_inventory.get_item_count(item)
          break
        end
      end
      doDebug("Priority=max " .. item .. "/" .. item_count)
    elseif priority=="min" then
      for item_name, _ in table.spairs(item_list, function(t,a,b) return t[b] > t[a] end) do
        if game.item_prototypes[item_name] and main_inventory.get_item_count(item_name) > 0 or (vehicle_inventory and vehicle_inventory.get_item_count(item_name) > 0) then
          item = item_name
          item_count = main_inventory.get_item_count(item)
          item_count = not vehicle_inventory and item_count or item_count + vehicle_inventory.get_item_count(item)
          break
        end
      end
      doDebug("Priority=min " .. item .. "/" .. item_count)
    end

    if not item or item_count < 1 then
      local key_table=table.keys(item_list)
      if key_table[1] ~= nil and game.item_prototypes[key_table[1]] then
        flying_text({"autofill.out-of-item", game.item_prototypes[key_table[1]].localised_name }, color, text_pos(), entity.surface)
      elseif key_table[1] ~= nil then
        flying_text({"autofill.invalid-itemname", key_table[1]}, color, text_pos(), entity.surface)
      end
      goto break_out
    end
    --We now have an item, and a count of the amount of items we have.
    ----END Item Count--

    -- --START Limits-------------------------------------------------------------
    -- -- Limit insertion if has limit value
    -- if pdata.limits and slot.limit then
    -- if count > slot.limit then
    -- count = slot.limit
    -- end
    -- end
    -- --END Limits--

    ----START Groups-------------------------------------------------------------
    --Divide stack between group items (only items in quickbar and hand are part of the group)
    --Get count in hands
    if set.group and pdata.groups then
      if player.cursor_stack.valid_for_read then
        group_count = group_count + player.cursor_stack.count
      end
      --Get count of all items in same group in quickbar
      -- for entity_name, set_table in pairs(table.merge(global.default_sets, pdata.sets)) do
      --   if type(set_table) == "table" and set_table.group == set.group then
      --     group_count = group_count + quickbar.get_item_count(entity_name)
      --   end
      -- end
      for entity_name, set_table in pairs(pdata.sets) do
        if type(set_table) == "table" and set_table.group == set.group then
          group_count = group_count + quickbar.get_item_count(entity_name)
        end
      end
      for entity_name, set_table in pairs(global.default_sets) do
        if not pdata.sets[entity_name] and set_table.group == set.group then
          group_count = group_count + quickbar.get_item_count(entity_name)
        end
      end
      doDebug("Group count = " .. group_count)

    end
    --END Groups--

    insert_count = math.max( 1, math.min( item_count, math.floor(item_count / (group_count * (slot.slot_count or 1))) ) )
    insert_count = math.min(insert_count, math.min(slot.limit and pdata.limits and slot.limit or insert_count, game.item_prototypes[item].stack_size))

    -----------------
    -- Test insertion
    -- entity.insert({name=item, count=count})
    -- color=defines.colors.green
    --for i=1, set.slot_count or 1 do
    -- local k = slot.slot_count or 1
    -- repeat
    --   flying_text({"autofill.insertion", insert_count, game.item_prototypes[item].localised_name }, color, text_pos(), entity.surface)
    --   k = k - 1
    -- until(k == 0)
    --end

    if insert_count < game.item_prototypes[item].stack_size * (slot.slot_count or 0) then
      color = defines.colors.yellow
    elseif insert_count >= game.item_prototypes[item].stack_size * (slot.slot_count or 0) then
      color = defines.colors.green
    end

    --Do insertion-------------------------------------------------

    -- inserted = entity.get_item_count(item)
    -- entity.insert({name=item, count=count})
    -- inserted = entity.get_item_count(item) - inserted
    -- if inserted > 0 then
    --   if vehicleinv then
    --     removed = vehicleinv.get_item_count(item)
    --     vehicleinv.remove({name=item, count=inserted})
    --     removed = removed - vehicleinv.get_item_count(item)
    --     if inserted > removed then
    --       maininv.remove({name=item, count=inserted - removed})
    --     end
    --   else
    --     maininv.remove({name=item, count=inserted})
    --   end
    --   if removed then
    --     flying_text({"autofill.insertion-from-vehicle", inserted, game.item_prototypes[item].localised_name, removed, game.entity_prototypes[player.vehicle.name].localised_name}, color, text_pos(), entity.surface)
    --   else
    --     flying_text({"autofill.insertion", inserted, game.item_prototypes[item].localised_name }, color, text_pos(), entity.surface)
    --   end
    -- end

    ::break_out::
  end

end

--list is updated during init and configuration_changed
function autofill.get_items()
  local fuel_all, fuel_high, ammo_list = {}, {}, {}

  -- set the value of coal for fuel fuel_high table
  local min_high_fuel_value = 8000000
  if game.item_prototypes["coal"] then min_high_fuel_value = game.item_prototypes["coal"].fuel_value end

  --Get Ammo's and Fuels
  for _, item in pairs(game.item_prototypes) do

    --Build fuel-all and fuel-high tables
    if item.fuel_value > 0 then
      fuel_all[item.name] = item.fuel_value/1000000
      if item.fuel_value >= min_high_fuel_value then
        fuel_high[item.name] = item.fuel_value/1000000
      end
    end

    --Build Ammo Category tables
    if item.ammo_type then
      if not ammo_list[item.ammo_type.category] then ammo_list[item.ammo_type.category] = {} end
      ammo_list[item.ammo_type.category][item.name]=1
    end
  end

  --increase priority of piercing bullets:
  if ammo_list and ammo_list["bullet"] and ammo_list["bullet"]["piercing-rounds-magazine"] then
    ammo_list["bullet"]["piercing-rounds-magazine"]=10
  end

  -- --Sort fuel list from low to high
  -- local fuelHighToLow = function(a,b)
  -- return game.item_prototypes[a].fuel_value > game.item_prototypes[b].fuel_value
  -- end
  -- table.sort(fuel_all, fuelHighToLow)
  -- table.sort(fuel_high, fuelHighToLow)

  local categories = {["fuel-all"] = fuel_all, ["fuel-high"] = fuel_high}
  for ammo_cat, cat_items in pairs (ammo_list) do
    categories[ammo_cat] = cat_items
  end

  return categories
end

--Is autofill enabled in global, for force, for the player, and NOT paused for player
function autofill.enabled(player_index)
  return ((
      global.enabled and global.force_data[game.players[player_index].force.name].enabled
      and global.player_data[player_index].enabled) and not (global.player_data[player_index].paused))
end

function autofill.register_player_data(player_index)
  local player = game.players[player_index]
  global.player_data[player_index] = {
    player_index = player_index,
    enabled = false,
    paused = false,
    limits = true,
    groups = true,
    categories = {},
    sets = {},
  }
  autofill.gui.init(player)
end

function autofill.register_force_data(force_name)
  if not global.force_data[force_name] then
    global.force_data[force_name] = {
      enabled = true,
      sets = {},
    }
  end
end

-------------------------------------------------------------------------------
--[[autofill events]]--
function autofill.on_built_entity(event)
  local entity = event.created_entity
  local pdata = global.player_data[event.player_index]
  local set = (pdata.sets[entity.name] or global.default_sets[entity.name])
  if set and autofill.enabled(event.player_index) then
    autofill.fill_entity(entity, pdata, set)
  end --enabled with set
end
Event.register(defines.events.on_built_entity, autofill.on_built_entity)

function autofill.hotkey_fill(event)
  local entity = game.players[event.player_index].selected
  local pdata = global.player_data[event.player_index]
  --local set = (pdata.sets[entity.name] or global.default_sets[entity.name])
  if entity and autofill.enabled(event.player_index) then
    local set = (pdata.sets[entity.name] or global.default_sets[entity.name])
    if set then autofill.fill_entity(entity, pdata, set) end
  end
end
script.on_event("autofill-hotkey-fill", autofill.hotkey_fill)

function autofill.toggle_paused(event)
  local player = game.players[event.player_index]
  local pdata = global.player_data[event.player_index]
  pdata.paused = not pdata.paused
  autofill.gui.toggle_paused(game.players[event.player_index], pdata.paused)
  if pdata.paused then
    player.print({"autofill.toggle-paused-on"})
  else
    player.print({"autofill.toggle-paused-off"})
  end
end
script.on_event("autofill-toggle-paused", autofill.toggle_paused)

function autofill.toggle_limits(event)
  local player = game.players[event.player_index]
  local pdata = global.player_data[event.player_index]
  pdata.limits = not pdata.limits
  if pdata.limits then
    player.print({"autofill.toggle-limits-on"})
  else
    player.print({"autofill.toggle-limits-off"})
  end
end
script.on_event("autofill-toggle-limits", autofill.toggle_limits)

function autofill.toggle_groups(event)
  local player = game.players[event.player_index]
  local pdata = global.player_data[event.player_index]
  pdata.groups = not pdata.groups
  if pdata.groups then
    player.print({"autofill.toggle-groups-on"})
  else
    player.print({"autofill.toggle-groups-off"})
  end
end
script.on_event("autofill-toggle-groups", autofill.toggle_groups)

--Player created, set up tables, enable GUI if needed.
function autofill.on_player_created(event)
  doDebug("on_player_created "..event.player_index)
  autofill.register_player_data(event.player_index)
  autofill.register_force_data(game.players[event.player_index].force.name)
  --Testing personal set:
  remote.call("af", "insertset", game.players[event.player_index], "steel-furnace", {group = "furnaces", slots = {{type="fuel", category="fuel-all", priority="max", limit=5}}})
end
Event.register(defines.events.on_player_created, autofill.on_player_created)

function autofill.on_player_joined_game(event)
  doDebug("on_player_joined_game "..event.player_index)
end
Event.register(defines.events.on_player_joined_game, autofill.on_player_joined_game)

--Enable gui when automation research is finished.
function autofill.on_research_finished(event)
  if event.research.name == "automation" then
    for _, player in pairs(event.research.force.players) do
      autofill.gui.init(player, "automation")
    end
  end
end
Event.register(defines.events.on_research_finished, autofill.on_research_finished)

-------------------------------------------------------------------------------
--[[autofill init]]--
function autofill.on_init()
  for index, player in pairs(game.players) do
    autofill.register_player_data(index)
    autofill.register_force_data(player.force.name)
  end
  global.default_items = autofill.get_items()
  global.default_sets = table.deepcopy(autofill.default_sets)
  global.enabled=true
end
Event.register(Event.core_events.init, autofill.on_init)

function autofill.on_configuration_changed(event)
  if event.mod_changes ~= nil then
    --Any MOD has been changed/added/removed, including base game updates.
    --Do prototype updates here

    global.default_items = autofill.get_items()
    local changes = event.mod_changes[MOD.name]
    if changes ~= nil then -- This Mod has changed

      --Upgrade to 2.0.0-------------------------------------------------------
      if changes.old_version < "2.0.0" then
        doDebug("Autofill updated to 2.0.0")
        local global_old = table.deepcopy(global)
        global = {}
        global.enabled = global_old.enabled or true
        global.player_data = {}
        global.force_data = {}
        global.config = _G.AF
        MOD.config = Config.new(global.config) -- We have global init, move config handler to global config
        autofill.on_init()
      end
      -------------------------------------------------------------------------
    end
  end
end
Event.register(Event.core_events.configuration_changed, autofill.on_configuration_changed)

function autofill.on_load()
end
Event.register(Event.core_events.load, autofill.on_load)

-------------------------------------------------------------------------------

return autofill