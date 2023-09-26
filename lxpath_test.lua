
local luaunit = require("luaunit")
local tokenize = require("lxpath")
lxpath_dodebug = false

TestTokenizer = {}


-- private functions
function TestTokenizer:test_get_qname()
    local testdata = {
        {"aaa","aaa"},
        {"aaa:foo","aaa:foo"},
        {"aaa:foo:bar","aaa:foo"},
    }
    for _, td in ipairs(testdata) do
        local runes = tokenize.private.split_chars(td[1])
        luaunit.assertEquals(tokenize.private.get_qname(runes),td[2])
    end
end


function TestTokenizer:test_get_num()
    local testdata = {
        {"123",123},
        {"123.3",123.3},
        {"123e-2",123e-2},
    }

    for _, td in ipairs(testdata) do
        local runes = tokenize.private.split_chars(td[1])
        luaunit.assertEquals(tokenize.private.get_num(runes),td[2])
    end
end

function TestTokenizer:test1()
    local testdata = {
        {nil    , {} },
        {""     , {} },
        {"'abc'", { {"abc","tokString"} }},
        {"123.4", { {123.4,"tokNumber"} }},
        {" 2 +2", { {2,"tokNumber"},{'+',"tokOperator"},{2,"tokNumber"} }},
        {" abc // def ", { {"abc","tokQName"},{'//',"tokOperator"},{"def","tokQName"} }},
    }

    for _, tc in ipairs(testdata) do
        luaunit.assertEquals(tokenize.string_to_tokenlist(tc[1]),tc[2])
    end
end


function TestTokenizer:test_parse_simple()
    local testdata = {
        { "-3.5", { -3.5 }},
        { "5 + 4", { 9.0 }},
        { "10 div 5", { 2.0 }},
        { "10 idiv 3", { 3.0 }},
        { "3 idiv -2", { -1.0 }},
        { "-3 idiv -2", { 1.0 }},
        { "-3.5 idiv 3", { -1.0 }},
    }
    for _, td in ipairs(testdata) do
        local str = td[1]
        local toks,msg = tokenize.string_to_tokenlist(str)
        if toks == nil then
            print(msg)
            os.exit(-1)
        end

        local ef, err = tokenize.parse_xpath(toks)
        if err ~= nil then
            luaunit.fail(err)
        end
        if not ef then
            luaunit.fail("function expected, got nil")
        end
        local seq = ef()
        luaunit.assertEquals(seq,td[2])


    end
end


os.exit(luaunit.LuaUnit.run())