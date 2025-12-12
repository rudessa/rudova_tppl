local main = require("main")

local examples = {
    {
        name = "Example 1: Empty program",
        code = [[
BEGIN
END.
        ]]
    },
    {
        name = "Example 2: Arithmetic expressions",
        code = [[
BEGIN
    x:= 2 + 3 * (2 + 3);
    y:= 2 / 2 - 2 + 3 * ((1 + 1) + (1 + 1))
END.
        ]]
    },
    {
        name = "Example 3: Nested blocks",
        code = [[
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
        ]]
    }
}

print("       Pascal Interpreter                ")

for i, example in ipairs(examples) do
    print("\n" .. string.rep("-", 40))
    print(example.name)
    print(string.rep("-", 40))
    print("Program code:")
    print(example.code)
    
    local success, result = pcall(function()
        return main.interpret(example.code)
    end)
    
    if success then
        print("\nExecution result:")
        if next(result) == nil then
            print("  (no variables)")
        else
            for name, value in pairs(result) do
                print(string.format("  %s = %s", name, tostring(value)))
            end
        end
    else
        print("\nERROR during execution:")
        print("  " .. result)
    end
end