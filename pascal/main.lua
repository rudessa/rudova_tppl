local lexer_module = require("lexer")
local AST = require("ast")
local Parser = require("parser")
local Interpreter = require("interpreter")

local Lexer = lexer_module.Lexer
local TokenType = lexer_module.TokenType

local function interpret(text)
    local lexer = Lexer.new(text)
    local parser = Parser.new(lexer, TokenType, AST)
    local interpreter = Interpreter.new(parser, TokenType)
    return interpreter:interpret()
end

local function print_result(variables)
    print("Interpretation result: ")
    print("{")
    for name, value in pairs(variables) do
        print(string.format("  %s = %s", name, tostring(value)))
    end
    print("}")
end

return {
    interpret = interpret,
    print_result = print_result,
    Lexer = Lexer,
    TokenType = TokenType,
    AST = AST,
    Parser = Parser,
    Interpreter = Interpreter
}