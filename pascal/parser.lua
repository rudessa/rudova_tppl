local Parser = {}
Parser.__index = Parser

function Parser.new(lexer, TokenType, AST)
    if type(lexer) ~= "table" then
        error("Parser.new: lexer must be a table, got " .. type(lexer))
    end
    if type(lexer.get_next_token) ~= "function" then
        error("Parser.new: lexer.get_next_token must be a function")
    end
    
    local self = {}
    setmetatable(self, Parser)
    
    self.lexer = lexer
    self.TokenType = TokenType
    self.AST = AST
    self.current_token = self.lexer:get_next_token()
    
    return self
end

function Parser:eat(token_type)
    if self.current_token.type == token_type then
        self.current_token = self.lexer:get_next_token()
    else
        error("Syntax Error:  " .. token_type .. ", got " .. self.current_token.type)
    end
end

function Parser:program()
    local node = self:compound_statement()
    self:eat(self.TokenType.DOT)
    return node
end

function Parser:compound_statement()
    self:eat(self.TokenType.BEGIN)
    local nodes = self:statement_list()
    self:eat(self.TokenType.END)
    
    local root = self.AST.Compound()
    for _, node in ipairs(nodes) do
        table.insert(root.children, node)
    end
    
    return root
end

function Parser:statement_list()
    local node = self:statement()
    local results = {}
    
    if node.type ~= "NoOp" then
        table.insert(results, node)
    end
    
    while self.current_token.type == self.TokenType.SEMI do
        self:eat(self.TokenType.SEMI)
        node = self:statement()
        if node.type ~= "NoOp" then
            table.insert(results, node)
        end
    end
    
    return results
end

function Parser:statement()
    if self.current_token.type == self.TokenType.BEGIN then
        return self:compound_statement()
    elseif self.current_token.type == self.TokenType.ID then
        return self:assignment_statement()
    else
        return self:empty()
    end
end

function Parser:assignment_statement()
    local left = self:variable()
    local token = self.current_token
    self:eat(self.TokenType.ASSIGN)
    local right = self:expr()
    return self.AST.Assign(left, token, right)
end

function Parser:variable()
    local node = self.AST.Var(self.current_token)
    self:eat(self.TokenType.ID)
    return node
end

function Parser:empty()
    return self.AST.NoOp()
end

function Parser:expr()
    local node = self:term()
    
    while self.current_token.type == self.TokenType.PLUS or
          self.current_token.type == self.TokenType.MINUS do
        local token = self.current_token
        if token.type == self.TokenType.PLUS then
            self:eat(self.TokenType.PLUS)
        elseif token.type == self.TokenType.MINUS then
            self:eat(self.TokenType.MINUS)
        end
        node = self.AST.BinOp(node, token, self:term())
    end
    
    return node
end

function Parser:term()
    local node = self:factor()
    
    while self.current_token.type == self.TokenType.MUL or
          self.current_token.type == self.TokenType.DIV do
        local token = self.current_token
        if token.type == self.TokenType.MUL then
            self:eat(self.TokenType.MUL)
        elseif token.type == self.TokenType.DIV then
            self:eat(self.TokenType.DIV)
        end
        node = self.AST.BinOp(node, token, self:factor())
    end
    
    return node
end

function Parser:factor()
    local token = self.current_token
    
    if token.type == self.TokenType.PLUS then
        self:eat(self.TokenType.PLUS)
        return self.AST.UnaryOp(token, self:factor())
    elseif token.type == self.TokenType.MINUS then
        self:eat(self.TokenType.MINUS)
        return self.AST.UnaryOp(token, self:factor())
    elseif token.type == self.TokenType.INTEGER then
        self:eat(self.TokenType.INTEGER)
        return self.AST.Num(token)
    elseif token.type == self.TokenType.REAL then
        self:eat(self.TokenType.REAL)
        return self.AST.Num(token)
    elseif token.type == self.TokenType.LPAREN then
        self:eat(self.TokenType.LPAREN)
        local node = self:expr()
        self:eat(self.TokenType.RPAREN)
        return node
    else
        return self:variable()
    end
end

function Parser:parse()
    local node = self:program()
    if self.current_token.type ~= self.TokenType.EOF then
        error("Error: Unexpected token after program completion")
    end
    return node
end

return Parser