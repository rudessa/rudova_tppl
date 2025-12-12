local AST = {}

function AST.Num(token)
    return {
        type = "Num",
        token = token,
        value = token.value
    }
end

function AST.BinOp(left, op, right)
    return {
        type = "BinOp",
        left = left,
        op = op,
        right = right
    }
end

function AST.UnaryOp(op, expr)
    return {
        type = "UnaryOp",
        op = op,
        expr = expr
    }
end

function AST.Compound()
    return {
        type = "Compound",
        children = {}
    }
end

function AST.Assign(left, op, right)
    return {
        type = "Assign",
        left = left,
        op = op,
        right = right
    }
end

function AST.Var(token)
    return {
        type = "Var",
        token = token,
        value = token.value
    }
end

function AST.NoOp()
    return {
        type = "NoOp"
    }
end

return AST