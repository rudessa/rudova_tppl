local Lexer = {}
Lexer.__index = Lexer

local TokenType = {
    INTEGER = "INTEGER",
    REAL = "REAL",
    PLUS = "PLUS",
    MINUS = "MINUS",
    MUL = "MUL",
    DIV = "DIV",
    LPAREN = "LPAREN",
    RPAREN = "RPAREN",
    ID = "ID",
    ASSIGN = "ASSIGN",
    BEGIN = "BEGIN",
    END = "END",
    SEMI = "SEMI",
    DOT = "DOT",
    EOF = "EOF"
}

local function Token(type, value)
    return {type = type, value = value}
end

function Lexer.new(text)
    if type(text) ~= "string" then
        error("Lexer.new: text must be a string, got " .. type(text))
    end
    
    local self = {}
    setmetatable(self, Lexer)
    
    self.text = text
    self.pos = 1
    self.current_char = string.len(text) > 0 and string.sub(text, 1, 1) or nil
    
    return self
end

function Lexer:advance()
    self.pos = self.pos + 1
    if self.pos <= string.len(self.text) then
        self.current_char = string.sub(self.text, self.pos, self.pos)
    else
        self.current_char = nil
    end
end

function Lexer:peek()
    local peek_pos = self.pos + 1
    if peek_pos <= string.len(self.text) then
        return string.sub(self.text, peek_pos, peek_pos)
    else
        return nil
    end
end

function Lexer:skip_whitespace()
    while self.current_char and string.match(self.current_char, "%s") do
        self:advance()
    end
end

function Lexer:number()
    local result = ""
    while self.current_char and string.match(self.current_char, "%d") do
        result = result .. self.current_char
        self:advance()
    end
    
    if self.current_char == "." then
        result = result .. self.current_char
        self:advance()
        
        while self.current_char and string.match(self.current_char, "%d") do
            result = result .. self.current_char
            self:advance()
        end
        
        return Token(TokenType.REAL, tonumber(result))
    else
        return Token(TokenType.INTEGER, tonumber(result))
    end
end

function Lexer:_id()
    local result = ""
    while self.current_char and string.match(self.current_char, "[%w_]") do
        result = result .. self.current_char
        self:advance()
    end
    
    local upper_result = string.upper(result)
    if upper_result == "BEGIN" then
        return Token(TokenType.BEGIN, upper_result)
    elseif upper_result == "END" then
        return Token(TokenType.END, upper_result)
    else
        return Token(TokenType.ID, result)
    end
end

function Lexer:get_next_token()
    while self.current_char do
        if string.match(self.current_char, "%s") then
            self:skip_whitespace()
        elseif string.match(self.current_char, "%d") then
            return self:number()
        elseif string.match(self.current_char, "[%a_]") then
            return self:_id()
        elseif self.current_char == ":" then
            self:advance()
            while self.current_char and string.match(self.current_char, "%s") do
                self:advance()
            end
            if self.current_char == "=" then
                self:advance()
                return Token(TokenType.ASSIGN, ":=")
            else
                error("Unresolved symbol: : (expected '=' )")
            end
        elseif self.current_char == ";" then
            self:advance()
            return Token(TokenType.SEMI, ";")
        elseif self.current_char == "+" then
            self:advance()
            return Token(TokenType.PLUS, "+")
        elseif self.current_char == "-" then
            self:advance()
            return Token(TokenType.MINUS, "-")
        elseif self.current_char == "*" then
            self:advance()
            return Token(TokenType.MUL, "*")
        elseif self.current_char == "/" then
            self:advance()
            return Token(TokenType.DIV, "/")
        elseif self.current_char == "(" then
            self:advance()
            return Token(TokenType.LPAREN, "(")
        elseif self.current_char == ")" then
            self:advance()
            return Token(TokenType.RPAREN, ")")
        elseif self.current_char == "." then
            self:advance()
            return Token(TokenType.DOT, ".")
        else
            error("Unresolved symbol " .. self.current_char)
        end
    end
    
    return Token(TokenType.EOF, nil)
end

return {
    Lexer = Lexer,
    TokenType = TokenType
}