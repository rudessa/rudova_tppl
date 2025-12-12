local main = require("main")
local interpret = main.interpret

local function assert_equals(actual, expected, test_name)
    if actual ~= expected then
        error(string.format("Test '%s' failed: expected %s, got %s",
            test_name, tostring(expected), tostring(actual)))
    end
    print(string.format("OK Test '%s' passed", test_name))
end

local function assert_table_equals(actual, expected, test_name)
    for key, value in pairs(expected) do
        if actual[key] ~= value then
            error(string.format("Test '%s' failed: for variable '%s' expected %s, got %s",
                test_name, key, tostring(value), tostring(actual[key])))
        end
    end
    for key, value in pairs(actual) do
        if expected[key] == nil then
            error(string.format("Test '%s' failed: unexpected variable '%s' with value %s",
                test_name, key, tostring(value)))
        end
    end
    print(string.format("OK Test '%s' passed", test_name))
end

local function assert_error(func, test_name, expected_error_pattern)
    local success, err = pcall(func)
    if success then
        error(string.format("Test '%s' failed: expected error but function succeeded", test_name))
    end
    if expected_error_pattern and not string.find(tostring(err), expected_error_pattern) then
        error(string.format("Test '%s' failed: expected error containing '%s', got '%s'",
            test_name, expected_error_pattern, tostring(err)))
    end
    print(string.format("OK Test '%s' passed (error caught)", test_name))
end

local function test_lexer()
    print("\n=== Lexer tests ===")
    local Lexer = main.Lexer
    local TokenType = main.TokenType
    
    local lexer = Lexer.new("123 45.67")
    local token1 = lexer:get_next_token()
    assert_equals(token1.type, TokenType.INTEGER, "Lexer: integer (type)")
    assert_equals(token1.value, 123, "Lexer: integer (value)")
    
    local token2 = lexer:get_next_token()
    assert_equals(token2.type, TokenType.REAL, "Lexer: real number (type)")
    assert_equals(token2.value, 45.67, "Lexer: real number (value)")
    
    local token3 = lexer:get_next_token()
    assert_equals(token3.type, TokenType.EOF, "Lexer: EOF token")
    
    lexer = Lexer.new("+ - * / := ( ) ; .")
    local ops = {
        {TokenType.PLUS, "+"},
        {TokenType.MINUS, "-"},
        {TokenType.MUL, "*"},
        {TokenType.DIV, "/"},
        {TokenType.ASSIGN, ":="},
        {TokenType.LPAREN, "("},
        {TokenType.RPAREN, ")"},
        {TokenType.SEMI, ";"},
        {TokenType.DOT, "."}
    }
    
    for i, op in ipairs(ops) do
        local token = lexer:get_next_token()
        assert_equals(token.type, op[1], "Lexer: operator " .. op[2])
    end
    
    lexer = Lexer.new("BEGIN END begin end BeGiN eNd")
    assert_equals(lexer:get_next_token().type, TokenType.BEGIN, "Lexer: BEGIN")
    assert_equals(lexer:get_next_token().type, TokenType.END, "Lexer: END")
    assert_equals(lexer:get_next_token().type, TokenType.BEGIN, "Lexer: begin (lowercase)")
    assert_equals(lexer:get_next_token().type, TokenType.END, "Lexer: end (lowercase)")
    assert_equals(lexer:get_next_token().type, TokenType.BEGIN, "Lexer: BeGiN (mixed case)")
    assert_equals(lexer:get_next_token().type, TokenType.END, "Lexer: eNd (mixed case)")
    
    lexer = Lexer.new("x y123 _var abc_123 _")
    assert_equals(lexer:get_next_token().type, TokenType.ID, "Lexer: identifier x")
    assert_equals(lexer:get_next_token().type, TokenType.ID, "Lexer: identifier y123")
    assert_equals(lexer:get_next_token().type, TokenType.ID, "Lexer: identifier _var")
    assert_equals(lexer:get_next_token().type, TokenType.ID, "Lexer: identifier abc_123")
    assert_equals(lexer:get_next_token().type, TokenType.ID, "Lexer: identifier _")
    
    lexer = Lexer.new("  \t\n  123  \n  456  ")
    local t1 = lexer:get_next_token()
    assert_equals(t1.value, 123, "Lexer: whitespace before number")
    local t2 = lexer:get_next_token()
    assert_equals(t2.value, 456, "Lexer: whitespace between numbers")
    
    lexer = Lexer.new("3.14 2.5 0.0")
    assert_equals(lexer:get_next_token().value, 3.14, "Lexer: real 3.14")
    assert_equals(lexer:get_next_token().value, 2.5, "Lexer: real 2.5")
    assert_equals(lexer:get_next_token().value, 0.0, "Lexer: real 0.0")
    
    lexer = Lexer.new(":  =")
    local assign_token = lexer:get_next_token()
    assert_equals(assign_token.type, TokenType.ASSIGN, "Lexer: := with spaces")
    
    lexer = Lexer.new(":\t\n =")
    assign_token = lexer:get_next_token()
    assert_equals(assign_token.type, TokenType.ASSIGN, "Lexer: := with tabs/newlines")
    
    lexer = Lexer.new("")
    assert_equals(lexer:get_next_token().type, TokenType.EOF, "Lexer: empty string EOF")
    
    assert_error(function()
        Lexer.new(123)
    end, "Lexer: non-string input", "must be a string")
    
    assert_error(function()
        local l = Lexer.new("@")
        l:get_next_token()
    end, "Lexer: invalid character @", "Unresolved symbol")
    
    assert_error(function()
        local l = Lexer.new("#")
        l:get_next_token()
    end, "Lexer: invalid character #", "Unresolved symbol")
    
    assert_error(function()
        local l = Lexer.new(": ")
        l:get_next_token()
    end, "Lexer: colon without equals", "expected '='")
    
    assert_error(function()
        local l = Lexer.new(":x")
        l:get_next_token()
    end, "Lexer: colon followed by letter", "expected '='")
    
    lexer = Lexer.new("123")
    assert_equals(lexer:peek(), "2", "Lexer: peek next char")
    lexer:advance()
    assert_equals(lexer:peek(), "3", "Lexer: peek after advance")
    lexer:advance()
    lexer:advance()
    assert_equals(lexer:peek(), nil, "Lexer: peek at end")
end

local function test_parser()
    print("\n=== Parser tests ===")
    local Lexer = main.Lexer
    local TokenType = main.TokenType
    local AST = main.AST
    local Parser = main.Parser
    
    local lexer = Lexer.new("BEGIN END.")
    local parser = Parser.new(lexer, TokenType, AST)
    local ast = parser:parse()
    assert_equals(ast.type, "Compound", "Parser: empty block")
    assert_equals(#ast.children, 0, "Parser: empty block (children count)")
    
    lexer = Lexer.new("BEGIN x := 5 END.")
    parser = Parser.new(lexer, TokenType, AST)
    ast = parser:parse()
    assert_equals(ast.type, "Compound", "Parser: block with assignment")
    assert_equals(#ast.children, 1, "Parser: one statement")
    assert_equals(ast.children[1].type, "Assign", "Parser: assignment statement type")
    
    lexer = Lexer.new("BEGIN x := 2 + 3 * 4 END.")
    parser = Parser.new(lexer, TokenType, AST)
    ast = parser:parse()
    assert_equals(ast.children[1].right.type, "BinOp", "Parser: arithmetic expression")
    
    lexer = Lexer.new("BEGIN a := 1; b := 2; c := 3 END.")
    parser = Parser.new(lexer, TokenType, AST)
    ast = parser:parse()
    assert_equals(#ast.children, 3, "Parser: three statements")
    
    lexer = Lexer.new("BEGIN BEGIN x := 1 END END.")
    parser = Parser.new(lexer, TokenType, AST)
    ast = parser:parse()
    assert_equals(ast.type, "Compound", "Parser: outer compound")
    assert_equals(ast.children[1].type, "Compound", "Parser: inner compound")
    
    lexer = Lexer.new("BEGIN ; ; END.")
    parser = Parser.new(lexer, TokenType, AST)
    ast = parser:parse()
    assert_equals(#ast.children, 0, "Parser: empty statements filtered out")
    
    lexer = Lexer.new("BEGIN x := (1 + 2) * 3 END.")
    parser = Parser.new(lexer, TokenType, AST)
    ast = parser:parse()
    assert_equals(ast.children[1].right.type, "BinOp", "Parser: parenthesized expression")
    
    lexer = Lexer.new("BEGIN x := -5 END.")
    parser = Parser.new(lexer, TokenType, AST)
    ast = parser:parse()
    assert_equals(ast.children[1].right.type, "UnaryOp", "Parser: unary minus")
    
    lexer = Lexer.new("BEGIN x := +5 END.")
    parser = Parser.new(lexer, TokenType, AST)
    ast = parser:parse()
    assert_equals(ast.children[1].right.type, "UnaryOp", "Parser: unary plus")
    
    lexer = Lexer.new("BEGIN a := 1; b := a END.")
    parser = Parser.new(lexer, TokenType, AST)
    ast = parser:parse()
    assert_equals(ast.children[2].right.type, "Var", "Parser: variable in expression")
    
    lexer = Lexer.new("BEGIN x := 1 + 2 - 3 * 4 / 5 END.")
    parser = Parser.new(lexer, TokenType, AST)
    ast = parser:parse()
    assert_equals(ast.children[1].type, "Assign", "Parser: complex expression")
    
    lexer = Lexer.new("BEGIN x := 1; END.")
    parser = Parser.new(lexer, TokenType, AST)
    ast = parser:parse()
    assert_equals(#ast.children, 1, "Parser: trailing semicolon")
    
    assert_error(function()
        Parser.new("not a table", TokenType, AST)
    end, "Parser: invalid lexer type", "must be a table")
    
    assert_error(function()
        Parser.new({}, TokenType, AST)
    end, "Parser: lexer without get_next_token", "must be a function")
    
    assert_error(function()
        local l = Lexer.new("BEGIN x := 5")
        local p = Parser.new(l, TokenType, AST)
        p:parse()
    end, "Parser: missing END", "Syntax Error")
    
    assert_error(function()
        local l = Lexer.new("BEGIN END")
        local p = Parser.new(l, TokenType, AST)
        p:parse()
    end, "Parser: missing DOT", "Syntax Error")
    
    assert_error(function()
        local l = Lexer.new("BEGIN x = 5 END.")
        local p = Parser.new(l, TokenType, AST)
        p:parse()
    end, "Parser: wrong assignment operator", "Unresolved symbol")
    
    assert_error(function()
        local l = Lexer.new("BEGIN x := END.")
        local p = Parser.new(l, TokenType, AST)
        p:parse()
    end, "Parser: incomplete assignment", "Syntax Error")
    
    assert_error(function()
        local l = Lexer.new("BEGIN x := ( END.")
        local p = Parser.new(l, TokenType, AST)
        p:parse()
    end, "Parser: unclosed parenthesis", "Syntax Error")
    
    assert_error(function()
        local l = Lexer.new("BEGIN x := 5 END. extra")
        local p = Parser.new(l, TokenType, AST)
        p:parse()
    end, "Parser: unexpected token after program", "Unexpected token")
end

local function test_interpreter()
    print("\n=== Interpreter tests ===")
    
    local result = interpret("BEGIN END.")
    assert_table_equals(result, {}, "Interpreter: empty program")
    
    result = interpret("BEGIN x := 5 END.")
    assert_table_equals(result, {x = 5}, "Interpreter: simple assignment")
    
    result = interpret("BEGIN x := 2 + 3 END.")
    assert_table_equals(result, {x = 5}, "Interpreter: addition")
    
    result = interpret("BEGIN x := 10 - 3 END.")
    assert_table_equals(result, {x = 7}, "Interpreter: subtraction")
    
    result = interpret("BEGIN x := 4 * 5 END.")
    assert_table_equals(result, {x = 20}, "Interpreter: multiplication")
    
    result = interpret("BEGIN x := 20 / 4 END.")
    assert_table_equals(result, {x = 5}, "Interpreter: division")
    
    result = interpret("BEGIN x := 15 / 2 END.")
    assert_equals(result.x, 7.5, "Interpreter: division with decimal result")
    
    result = interpret("BEGIN x := 2 + 3 * 4 END.")
    assert_table_equals(result, {x = 14}, "Interpreter: operator precedence")
    
    result = interpret("BEGIN x := 2 * 3 + 4 END.")
    assert_table_equals(result, {x = 10}, "Interpreter: operator precedence (reverse)")
    
    result = interpret("BEGIN x := 10 - 2 - 3 END.")
    assert_table_equals(result, {x = 5}, "Interpreter: left associativity subtraction")
    
    result = interpret("BEGIN x := 20 / 4 / 2 END.")
    assert_table_equals(result, {x = 2.5}, "Interpreter: left associativity division")
    
    result = interpret("BEGIN x := (2 + 3) * 4 END.")
    assert_table_equals(result, {x = 20}, "Interpreter: parentheses")
    
    result = interpret("BEGIN x := 2 * (3 + 4) END.")
    assert_table_equals(result, {x = 14}, "Interpreter: parentheses (reverse)")
    
    result = interpret("BEGIN x := ((1 + 2) * (3 + 4)) END.")
    assert_table_equals(result, {x = 21}, "Interpreter: nested parentheses")
    
    result = interpret("BEGIN x := -5 END.")
    assert_table_equals(result, {x = -5}, "Interpreter: unary minus")
    
    result = interpret("BEGIN x := +5 END.")
    assert_table_equals(result, {x = 5}, "Interpreter: unary plus")
    
    result = interpret("BEGIN x := -(-5) END.")
    assert_table_equals(result, {x = 5}, "Interpreter: double unary minus")
    
    result = interpret("BEGIN x := -(3 + 2) END.")
    assert_table_equals(result, {x = -5}, "Interpreter: unary minus with expression")
    
    result = interpret("BEGIN x := 10 + -5 END.")
    assert_table_equals(result, {x = 5}, "Interpreter: unary minus in expression")
    
    result = interpret("BEGIN x := 1; y := 2; z := 3 END.")
    assert_table_equals(result, {x = 1, y = 2, z = 3}, "Interpreter: multiple variables")
    
    result = interpret("BEGIN x := 5; y := x + 3 END.")
    assert_table_equals(result, {x = 5, y = 8}, "Interpreter: using variables")
    
    result = interpret("BEGIN x := 5; y := x; z := y END.")
    assert_table_equals(result, {x = 5, y = 5, z = 5}, "Interpreter: variable chain")
    
    result = interpret("BEGIN x := 2; y := 3; z := x + y END.")
    assert_table_equals(result, {x = 2, y = 3, z = 5}, "Interpreter: multiple variables in expression")
    
    result = interpret("BEGIN x := 2; x := x + 3 END.")
    assert_table_equals(result, {x = 5}, "Interpreter: variable reassignment")
    
    result = interpret("BEGIN x := 3.14 END.")
    assert_equals(result.x, 3.14, "Interpreter: real number")
    
    result = interpret("BEGIN x := 1.5 + 2.5 END.")
    assert_equals(result.x, 4.0, "Interpreter: real number addition")
    
    result = interpret("BEGIN x := 10.0 / 4.0 END.")
    assert_equals(result.x, 2.5, "Interpreter: real number division")
    
    result = interpret([[
        BEGIN
            x := 1;
            BEGIN
                y := 2
            END;
            z := 3
        END.
    ]])
    assert_table_equals(result, {x = 1, y = 2, z = 3}, "Interpreter: nested blocks")
    
    result = interpret([[
        BEGIN
            BEGIN
                BEGIN
                    x := 1
                END
            END
        END.
    ]])
    assert_table_equals(result, {x = 1}, "Interpreter: deeply nested blocks")
    
    result = interpret("BEGIN x := 2 + 3 * 4 - 5 / 5 END.")
    assert_equals(result.x, 13, "Interpreter: complex expression")
    
    result = interpret("BEGIN x := (2 + 3) * (4 - 1) END.")
    assert_equals(result.x, 15, "Interpreter: multiple parenthesized groups")
    
    assert_error(function()
        interpret("BEGIN x := y END.")
    end, "Interpreter: undefined variable", "undefined")
    
    assert_error(function()
        interpret("BEGIN x := y + 1 END.")
    end, "Interpreter: undefined variable in expression", "undefined")
    
    assert_error(function()
        interpret("BEGIN a := b; b := 1 END.")
    end, "Interpreter: using variable before definition", "undefined")

    local function dummy_program(node_type)
        return [[
            BEGIN
                x := 10
            END.
        ]]
    end
    
    local function mock_parse()
        return {
            type = "UnknownNodeType"
        }
    end

    local function mock_lexer()
        return {
            get_next_token = function()
                return {type = main.TokenType.EOF, value = nil}
            end
        }
    end

    local function mock_parser()
        return {
            parse = mock_parse
        }
    end

    assert_error(function()
        local interpreter = main.Interpreter.new(mock_parser(), main.TokenType)
        interpreter:interpret()
    end, "Interpreter: Undefined AST method", "Undefined methods visit_UnknownNodeType")

    assert_error(function()
        interpret("BEGIN y := x + 1 END.")
    end, "Interpreter: Undefined variable", "Variable is undefined")

    result = interpret("BEGIN f := 3.14 + 1.86 END.")
    assert_equals(result.f, 5.0, "Interpreter: Real numbers addition")
end

local function test_ast()
    print("\n=== AST tests ===")
    local AST = main.AST
    local TokenType = main.TokenType
    
    local token = {type = TokenType.INTEGER, value = 42}
    local num_node = AST.Num(token)
    assert_equals(num_node.type, "Num", "AST: Num type")
    assert_equals(num_node.value, 42, "AST: Num value")
    
    local left = AST.Num({type = TokenType.INTEGER, value = 2})
    local right = AST.Num({type = TokenType.INTEGER, value = 3})
    local op = {type = TokenType.PLUS, value = "+"}
    local binop_node = AST.BinOp(left, op, right)
    assert_equals(binop_node.type, "BinOp", "AST: BinOp type")
    assert_equals(binop_node.left.value, 2, "AST: BinOp left")
    assert_equals(binop_node.right.value, 3, "AST: BinOp right")
    
    local expr = AST.Num({type = TokenType.INTEGER, value = 5})
    local unary_op = {type = TokenType.MINUS, value = "-"}
    local unaryop_node = AST.UnaryOp(unary_op, expr)
    assert_equals(unaryop_node.type, "UnaryOp", "AST: UnaryOp type")
    assert_equals(unaryop_node.expr.value, 5, "AST: UnaryOp expr")
    
    local compound_node = AST.Compound()
    assert_equals(compound_node.type, "Compound", "AST: Compound type")
    assert_equals(#compound_node.children, 0, "AST: Compound empty children")
    
    local var = AST.Var({type = TokenType.ID, value = "x"})
    local assign_op = {type = TokenType.ASSIGN, value = ":="}
    local value = AST.Num({type = TokenType.INTEGER, value = 10})
    local assign_node = AST.Assign(var, assign_op, value)
    assert_equals(assign_node.type, "Assign", "AST: Assign type")
    assert_equals(assign_node.left.value, "x", "AST: Assign left")
    assert_equals(assign_node.right.value, 10, "AST: Assign right")
    
    local var_token = {type = TokenType.ID, value = "myvar"}
    local var_node = AST.Var(var_token)
    assert_equals(var_node.type, "Var", "AST: Var type")
    assert_equals(var_node.value, "myvar", "AST: Var value")
    
    local noop_node = AST.NoOp()
    assert_equals(noop_node.type, "NoOp", "AST: NoOp type")
end

local function test_examples()
    print("\n=== Assignment examples tests ===")
    
    local result = interpret("BEGIN END.")
    assert_table_equals(result, {}, "Example 1: empty program")
    
    result = interpret([[
        BEGIN
            x:= 2 + 3 * (2 + 3);
            y:= 2 / 2 - 2 + 3 * ((1 + 1) + (1 + 1))
        END.
    ]])
    assert_equals(result.x, 17, "Example 2: x")
    assert_equals(result.y, 11, "Example 2: y")
    
    result = interpret([[
        BEGIN
            y: = 2;
            BEGIN
                a := 3;
                a := a;
                b := 10 + a + 10 * y / 4;
                c := a - b
            END;
            x := 11
        END.
    ]])
    assert_equals(result.y, 2, "Example 3: y")
    assert_equals(result.a, 3, "Example 3: a")
    assert_equals(result.b, 18, "Example 3: b")
    assert_equals(result.c, -15, "Example 3: c")
    assert_equals(result.x, 11, "Example 3: x")
end

local function test_edge_cases()
    print("\n=== Edge cases tests ===")
    
    local result = interpret("BEGIN a := 1; b := 2; c := a + b END.")
    assert_equals(result.c, 3, "Edge: single char identifiers")
    
    result = interpret("BEGIN very_long_variable_name := 100 END.")
    assert_equals(result.very_long_variable_name, 100, "Edge: long identifier")
    
    result = interpret("BEGIN x := 0; y := 0.0 END.")
    assert_equals(result.x, 0, "Edge: integer zero")
    assert_equals(result.y, 0.0, "Edge: real zero")
    
    result = interpret("BEGIN x := 999999 END.")
    assert_equals(result.x, 999999, "Edge: large integer")
    
    result = interpret("BEGIN x := 1+1+1+1+1+1+1+1+1+1 END.")
    assert_equals(result.x, 10, "Edge: many additions")
    
    result = interpret("BEGIN x := ((((1)))) END.")
    assert_equals(result.x, 1, "Edge: deep parentheses nesting")
    
    result = interpret("BEGIN ; x := 1 ; ; y := 2 ; END.")
    assert_table_equals(result, {x = 1, y = 2}, "Edge: empty statements mixed")
    
    result = interpret([[
        BEGIN
            a := 1;
            BEGIN
                b := 2;
                BEGIN
                    c := 3;
                    d := a + b + c
                END
            END
        END.
    ]])
    assert_equals(result.d, 6, "Edge: variables from outer scopes")
end

local function run_all_tests()
    print("Running Pascal Interpreter Tests")
    
    local success, err = pcall(function()
        test_lexer()
        test_parser()
        test_interpreter()
        test_ast()
        test_examples()
        test_edge_cases()
    end)
    
    print("\n" .. string.rep("=", 40))
    if success then
        print("SUCCESS: All tests passed!")
    else
        print("ERROR: Test execution failed:")
        print(err)
    end
    print(string.rep("=", 40))
end

run_all_tests()