local common = require("civ_common")

local ITM_TYPE_COMESTIBLE = ItypeId.new("COMESTIBLE")
local ITM_CAT_DRUGS = "drugs"
local ITM_COM_TYPE_FOOD = "FOOD"
local ITM_COM_TYPE_DRINK = "DRINK"
local ITM_COM_TYPE_MED = "MED"
local ITM_MAT_ALCOHOL = MaterialTypeId.new("alcohol")

---@param civ Monster
---@param item Item
---@return boolean
local function filter_comestible(civ, item)
    if not item:is_food() then return false end
    if item:get_comestible_fun() < 0 then return false end
    --if item:get_category_id
    local civ_data = common.CIVILIANS[civ:get_type():str()]

    local itype = item:get_type():obj()
    if itype ~= ITM_TYPE_COMESTIBLE then return false end
    return true
end

mod.on_examine_menu_entry_civ = function(params)
    ---@type Character
    local avatar = params.avatar
    ---@type Monster
    local civ = params.monster
    local civ_type_str = civ:get_type():str()
    local entry = params.entry
    if entry == "offer_food" then
        local consumables = {}
        local all_items = avatar:get_items_if({ is_food = true })
        for _, item in ipairs(all_items) do
            local item_type_id = item:get_type()
            local item_type = item_type_id:obj()
            local item_comest_type = item_type:slot_comestible()
            if item_type_id:str() == ITM_TYPE_COMESTIBLE then
              if item:is_made_of(ITM_MAT_ALCOHOL) then
                    if common.CIVILIANS[civ_type_str].likes_alcohol then
                        table.insert(consumables, item)
                    end
              elseif item_comest_type.comest_type == ITM_COM_TYPE_FOOD or item_comest_type.comest_type == ITM_COM_TYPE_DRINK  then
                  table.insert(consumables, item)
              end
          end
      end
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