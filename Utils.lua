local addonName, ns = ...

ns.Constant = {
    MAX_SAFE_LOOP = 200
}

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