local Interpreter = {}
Interpreter.__index = Interpreter

function Interpreter.new(parser, TokenType)
    local self = setmetatable({}, Interpreter)
    self.parser = parser
    self.TokenType = TokenType
    self.GLOBAL_SCOPE = {}
    return self
end

function Interpreter:visit(node)
    local method_name = "visit_" .. node.type
    local method = self[method_name]
    if not method then
        error("Undefined methods " .. method_name)
    end
    return method(self, node)
end

function Interpreter:visit_Num(node)
    return node.value
end

function Interpreter:visit_BinOp(node)
    local left = self:visit(node.left)
    local right = self:visit(node.right)
    
    if node.op.type == self.TokenType.PLUS then
        return left + right
    elseif node.op.type == self.TokenType.MINUS then
        return left - right
    elseif node.op.type == self.TokenType.MUL then
        return left * right
    elseif node.op.type == self.TokenType.DIV then
        return left / right
    end
end

function Interpreter:visit_UnaryOp(node)
    local expr = self:visit(node.expr)
    
    if node.op.type == self.TokenType.PLUS then
        return expr
    elseif node.op.type == self.TokenType.MINUS then
        return -expr
    end
end

function Interpreter:visit_Compound(node)
    for _, child in ipairs(node.children) do
        self:visit(child)
    end
end

function Interpreter:visit_Assign(node)
    local var_name = node.left.value
    local value = self:visit(node.right)
    self.GLOBAL_SCOPE[var_name] = value
end

function Interpreter:visit_Var(node)
    local var_name = node.value
    local value = self.GLOBAL_SCOPE[var_name]
    if value == nil then
        error("Variable is undefined: " .. var_name)
    end
    return value
end

function Interpreter:visit_NoOp(node)
end

function Interpreter:interpret()
    local tree = self.parser:parse()
    self:visit(tree)
    return self.GLOBAL_SCOPE
end

return Interpreter