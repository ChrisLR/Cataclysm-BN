local mod = game.mod_runtime[game.current_mod]
local ui = require("lib.ui")
local common = require("civ_common")

local ITM_TYPE_COMESTIBLE = ItypeId.new("COMESTIBLE")
local ITM_CAT_DRUGS = "drugs"
local ITM_COM_TYPE_FOOD = "FOOD"
local ITM_COM_TYPE_DRINK = "DRINK"
local ITM_COM_TYPE_MED = "MED"
local ITM_MAT_ALCOHOL = MaterialTypeId.new("alcohol")

---@param item Item
---@param likes_alcohol boolean
---@param likes_drugs boolean
---@return boolean
local function filter_comestible(item, likes_alcohol, likes_drugs)
    local item_type_id = item:get_type()
    local item_type = item_type_id:obj()
    local item_comest_type_str = item_type:slot_comestible().comest_type
    if item_type_id:str() ~= "COMESTIBLE" then return false end
    if item:is_made_of(ITM_MAT_ALCOHOL) and not likes_alcohol then return false end
    if item_comest_type_str == ITM_COM_TYPE_MED then return false end
    -- TODO Support drugs
    return true
end

---@param avatar Character
---@param civ Monster
local function exam_offer_food(avatar, civ)
  gdebug.log_info("called")
  ---@type Item[]
  local consumables = {}
  local civ_type_str = civ:get_type():str()
  local civ_likes_alcohol = common.CIVILIANS[civ_type_str].likes_alcohol
  local civ_likes_drugs = common.CIVILIANS[civ_type_str].likes_drugs
  local all_items = avatar:get_items_if({ is_food = true })
  for _, item in ipairs(all_items) do
      gdebug.log_info("filtering item")
    if filter_comestible(item, civ_likes_alcohol, civ_likes_drugs) then
      table.insert(consumables, item)
      gdebug.log_info("had food")
    end
  end
  local menu = UiList.new()
  menu:title(locale.gettext("Offer which item?"))
  for i, item in ipairs(consumables) do
      menu:add(i, item:display_name(1))
  end
  local result = menu:query()
  if result <= 0 then return end
    local offered_item = consumables[result]
    local item_name = offered_item:display_name(1)
  if offered_item.charges > 1 then
      offered_item.charges = offered_item.charges - 1
  else
      avatar:remove_item(offered_item)
  end

  gapi.add_msg(string.format("%s consumes %s.", civ:get_name(), item_name))
end

mod.on_examine_menu_entry_civ = function(params)
    ---@type Character
    local avatar = params.avatar
    ---@type Monster
    local civ = params.monster
    local entry = params.entry
    gdebug.log_info(string.format("Had entry %s", entry))
    if entry == "offer_food" then
        gdebug.log_info("inside")
        exam_offer_food(avatar, civ)
    end
end

mod.get_examine_menu_entries_civ = function(params)
    gdebug.log_info("Get exa")
    ---@type Character
    local avatar = params.avatar
    ---@type Monster
    local civ = params.monster
    local civ_stats = common.get_civ_stats(civ)
    local civ_data = common.CIVILIANS[civ:get_type():str()]
    local entries = {}

    table.insert(
        entries,
        {
            menu_id = "persuade",
            menu_label = string.format("Persuade (%s%%)", civ_stats.trust),
        }
    )
    table.insert(
        entries,
        { menu_id = "offer_food", menu_label = string.format("Offer Food (%s%%)", civ_stats.anger) }
    )
    table.insert(
        entries,
        { menu_id = "heal", menu_label = string.format("Heal (%s%%)", civ_stats.trust) }
    )
    table.insert(
        entries,
        { menu_id = "promote", menu_label = string.format("Promote (%s%%)", civ_stats.exp) }
    )

    return entries
end
