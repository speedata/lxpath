local luaunit = require("luaunit")
local lxpath = require("lxpath")
local xmltab = dofile("xmltable.lua")
lxpath_dodebug = false

TestTokenizer = {}


-- private functions
function TestTokenizer:test_get_qname()
    local testdata = {
        { "aaa",         "aaa" },
        { "aaa:foo",     "aaa:foo" },
        { "aaa:foo:bar", "aaa:foo" },
    }
    for _, td in ipairs(testdata) do
        local runes = lxpath.private.split_chars(td[1])
        luaunit.assertEquals(lxpath.private.get_qname(runes), td[2])
    end
end

function TestTokenizer:test_get_num()
    local testdata = {
        { "123",    123 },
        { "123.3",  123.3 },
        { "123e-2", 123e-2 },
    }

    for _, td in ipairs(testdata) do
        local runes = lxpath.private.split_chars(td[1])
        luaunit.assertEquals(lxpath.private.get_num(runes), td[2])
    end
end

function TestTokenizer:test1()
    local testdata = {
        { nil,            {} },
        { "",             {} },
        { "'abc'",        { { "abc", "tokString" } } },
        { "123.4",        { { 123.4, "tokNumber" } } },
        { " 2 +2",        { { 2, "tokNumber" }, { '+', "tokOperator" }, { 2, "tokNumber" } } },
        { " abc // def ", { { "abc", "tokQName" }, { '//', "tokOperator" }, { "def", "tokQName" } } },
        { " false() ",    { { "false", "tokQName" }, { '(', "tokOpenParen" }, { ')', "tokCloseParen" } } }
    }

    for _, tc in ipairs(testdata) do
        luaunit.assertEquals(lxpath.string_to_tokenlist(tc[1]), tc[2])
    end
end

function TestTokenizer:test_parse_simple()
    local testdata = {
        { "+-+-+2", { 2.0 } },
        { "+-+-+-+ 2", { -2.0 } },
        { "2 = 4", { false } },
        { "2 = 2", { true } },
        { "2 < 2", { false } },
        { "2 < 3", { true } },
        { "3.4 > 3.1", { true } },
        { "3.4 != 3.1", { true } },
        { "'abc' = 'abc'", { true } },
        { "'aA' < 'aa'", { true } },
        { "'aA' != 'aa'", { true } },
        { "false() or true()", { true } },
        { "false()", { false } },
        { "-3.5", { -3.5 } },
        { "5 + 4", { 9.0 } },
        { "1 + 5 * 4", { 21.0 } },
        { "10 div 5", { 2.0 } },
        { "10 idiv 3", { 3.0 } },
        { "3 div -2", { -1.5 } },
        { "3 idiv -2", { -1.0 } },
        { "-3 idiv -2", { 1.0 } },
        { "-3.5 idiv 3", { -1.0 } },
        { "7 div 2 = 3.5", { true } },
        { "8 mod 2 = 0 ", { true } },
        { "4 < 2  or 5 < 7 ", { true } },
        { "concat('abc','def')", { "abcdef" } },
        { "string(number('zzz')) = 'NaN'", { true } },
        { "$foo", { "bar" } },
        { "$onedotfive + 2", { 3.5 } },
        { "$one-two div $a", { 2.4 } },
        { "7 mod 3", { 1.0 } },
        { "9 * 4 div 6", { 6.0 } },
        { "(1,2)", { 1.0, 2.0 } },
        { "(1,2) = (2,3)", { true } },
        { "(1,2) = (3,4)", { false } },
        { "()", {} },
        { "( () )", {} },
        { "3,3", { 3, 3 } },
        { "(3,3)", { 3, 3 } },
        { "(1,2)[true()]", { 1.0, 2.0 } },
        { "(1,2)[false()]", {} },
        { "( (),2 )[1]", { 2.0 } },
        { "count(/root/sub)", { 3.0 } },
        { "local-name(/root)", { "root" } },
        { "/root/local-name()", { "root" } },
        { "local-name(/)", { "" } },
        { "/local-name()", { "" } },
        { "max(  ( 1,2,3) )", { 3.0 } },
        { "max(  ( ) )", {} },
        { "min(  ( 1,2,3) )", { 1.0 } },
        { "min(  ( ) )", {} },
        { "normalize-space(  '   foo bar    baz     ' )", { "foo bar baz" } },
        { "normalize-space(  '   foo \n bar    baz     ' )", { "foo bar baz" } },
        { "not( 3 < 6 )", { false } },
        { "not( 6 < 3 )", { true } },
        { "round( 3.2 )", { 3.0 } },
        { "round( 2.4999 )", { 2.0 } },
        { "round( 2.5 )", { 3.0 } },
        { "round( -7.5 )", { -7.0 } },
        { "round( -7.50001 )", { -8.0 } },
        { "string-join( ( 'a','b', 'c'),', '  )", { "a, b, c" } },
        { "string-length( 'a' )", { 1 } },
        { "string-length( 'ä' )", { 1 } },
        { "string-length( () )", { 0 } },
        { "/root/other/string()", { "\n  contents subsub other\n", "\n  contents subsub other2\n" } },
    }
    -- {`upper-case( 'aäÄ' )`, Sequence{"AÄÄ"}},
    -- {`upper-case( () )`, Sequence{""}},
    -- {`lower-case( "EΛΛAΣ" )`, Sequence{"eλλaσ"}},
    -- {`/root/sub[2]/string-length()`, Sequence{4}},
    -- {`/root/other/string()`, Sequence{"\n\t  contents subsub other\n\t", "\n\t  contents subsub other2\n\t"}},

    for _, td in ipairs(testdata) do
        local ctxvalue = {
            namespaces = {
                fn = lxpath.fnNS
            },
            vars = {
                foo = "bar",
                onedotfive = 1.5,
                a = 5,
                ["one-two"] = 12,
            },
            xmldoc = { xmltab },
            sequence = { xmltab }
        }
        local ctx = lxpath.context:new(ctxvalue)
        local str = td[1]
        local toks, msg = lxpath.string_to_tokenlist(str)
        if toks == nil then
            print(msg)
            os.exit(-1)
        end

        local ef, err = lxpath.parse_xpath(toks)
        if err ~= nil then
            luaunit.fail(err .. td[2])
        end
        if not ef then
            luaunit.fail("function expected, got nil")
        end
        ---@diagnostic disable-next-line
        local seq = ef(ctx)

        luaunit.assertEquals(seq, td[2], td[1])
    end
end

os.exit(luaunit.LuaUnit.run())
