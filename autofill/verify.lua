local Verify = {}



function Verify.existing_fill_sets(fill_sets)
    local _valid_entities = function (_, k)
        if game.entity_prototypes[k] then
            return true
        else
            MOD.log("Removing: "..k.." Not a valid entity", 1)
        end
    end


    local meta = getmetatable(fill_sets)
    local obj = table.filter(fill_sets, _valid_entities)
    if meta then setmetatable(obj, meta) end
    return obj
end

function Verify.existing_item_sets(item_sets)
    -- local _valid_items = function (_, k)
    -- if game.item_prototypes[k] then
    -- return true
    -- else
    -- MOD.log("Removing "..k.." Not a valid item", 1)
    -- end
    -- end
    -- local meta = getmetatable(item_sets)
    -- local obj = table.filter(item_sets, _valid_items)
    -- if meta then setmetatable(obj, meta) end
    -- return obj
    return item_sets
end

return Verify