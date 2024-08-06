local addonName, ns = ...

function ns.math_min(a, b)
    if a < b then
        return a
    else
        return b
    end
end