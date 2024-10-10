local addonName, ns = ...

ns.Constant = {
    MAX_SAFE_LOOP = 200
}

function ns.isParentNameInHierarchy(parent, nameToMatch, level)
    if not parent then
        return false
    end

    if not level then
        level = 1
    end

    local parentName = parent:GetName()
    if parentName and parentName == nameToMatch then
        ns.Log.debug("Match found at level", level, ":", parentName)
        return true
    end

    -- Recursively call the function for the next parent
    if parent:GetParent() then
        return ns.isParentNameInHierarchy(parent:GetParent(), nameToMatch, level + 1)
    end

    return false
end

function ns.printParentNames(parent, level)
    if not parent then
        return
    end

    if not level then
        level = 1
    end

    local levelText = string.rep("-parent", level - 1) -- Create a level-specific text

    local parentName = parent:GetName()
    if parentName then
        ns.Log.debug("Parent" .. levelText .. " name:", parentName)
    end

    -- Recursively call the function for the next parent
    if parent:GetParent() then
        ns.printParentNames(parent:GetParent(), level + 1)
    end
end

function ns.printObjectDetails(obj)
    -- Create a table to store the keys
    local keys = {}

    -- Insert all keys into the keys table
    for key in pairs(obj) do
        -- Only add string keys to the list to avoid comparison errors
        if type(key) == "string" then
            table.insert(keys, key)
        end
    end

    -- Sort the keys alphabetically
    table.sort(keys)

    -- Print the sorted keys and their corresponding values
    for _, key in ipairs(keys) do
        print(key, obj[key])
    end

    -- Print non-string keys separately without sorting
    for key, value in pairs(obj) do
        if type(key) ~= "string" then
            print(key, value)
        end
    end
end

function ns.containsValue(t, value)
    for index, val in ipairs(t) do
        if val == value then
            return true
        end
    end
    return false
end

function ns.location_string(isGuildBank, bagIndex, slotIndex) 
    local prefix = isGuildBank and "G" or "S"
    return string.format("%s/%d/%d", prefix, bagIndex, slotIndex)
end

function ns.math_min(a, b)
    if a < b then
        return a
    else
        return b
    end
end

function ns.math_max(a, b)
    if a > b then
        return a
    else
        return b
    end
end

function ns.mergeTables(t1, t2)
    local result = {}
    for _, v in ipairs(t1) do
        table.insert(result, v)
    end
    for _, v in ipairs(t2) do
        table.insert(result, v)
    end
    return result
end