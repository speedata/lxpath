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
        { "( 6 + 4 ) * 2", { 20.0 } },
        { "(1,2)", { 1.0, 2.0 } },
        { "(1,2) = (2,3)", { true } },
        { "(1,2) = (3,4)", { false } },
        { "(1,2) != (2,3)", { true } },
        { "(1,2) != (1,2)", { true } },
        { "(1,2) != (3,4)", { true } },
        { "(1,1) != (1,1)", { false } },
        { "()", {} },
        { "( () )", {} },
        { "3,3", { 3, 3 } },
        { "(3,3)", { 3, 3 } },
        { "(1,2)[true()]", { 1.0, 2.0 } },
        { "(1,2)[false()]", {} },
        { "( (),2 )[1]", { 2.0 } },
        { "string(/root/@one)", { "1" } },
        { "abs( - 2 )", { 2.0 } },
        { "abs( -3.7 )", { 3.7 } },
        { "abs( -1.0e-7 )", { 1.0e-7 } },
        { "boolean( 0 )", { false } },
        { "boolean( 1 )", { true } },
        { "boolean( false() )", { false } },
        { "boolean( ((true())))", { true } },
        { "boolean( true() )", { true } },
        { "boolean( '' )", { false } },
        { "boolean( () )", { false } },
        { "boolean( (()) )", { false } },
        { "boolean( 'false' )", { true } },
        { "count(/root/sub)", { 3.0 } },
        { "contains( '', '' )", { true } },
        { "contains( (), 'a' )", { false } },
        { "contains( '', 'a' )", { false } },
        { "contains( 'Shakespeare', '' )", { true } },
        { "contains( 'Shakespeare', 'spear' )", { true } },
        { "string-to-codepoints( 'hellö' )", { 104, 101, 108, 108, 246 } },
        { "codepoints-to-string( (65,33*2,67) )", { "ABC" } },
        { "codepoints-to-string( reverse(  string-to-codepoints( 'Hellö' ) ) )", { "ölleH" } },
        { "ceiling(1.0)", { 1.0 } },
        { "ceiling(1.5)", { 2.0 } },
        { "ceiling( 17 div 3 )", { 6.0 } },
        { "ceiling( -3 )", { -3.0 } },
        { "ceiling( -8.2e0 )", { -8.0e0 } },
        { "string(ceiling( 'ZZZ' ))", { 'NaN' } },
        { "empty( () )", { true } },
        { "empty( /root/sub )", { false } },
        { "empty( /root/doesnotexist )", { true } },
        { "empty( /root/@doesnotexist )", { true } },
        { "floor(1.0)", { 1.0 } },
        { "floor(1.5)", { 1.0 } },
        { "floor( 17 div 3 )", { 5.0 } },
        { "floor( -3 )", { -3.0 } },
        { "floor( -8.2e0 )", { -9.0 } },
        { "floor( -0.5e0 )", { -1.0 } },
        { "max(  ( 1,2,3) )", { 3.0 } },
        { "local-name(/root)", { "root" } },
        { "/root/local-name()", { "root" } },
        { "local-name(/)", { "" } },
        { "/local-name()", { "" } },
        { "max(  ( ) )", {} },
        { "min(  ( 1,2,3) )", { 1.0 } },
        { "min(  ( ) )", {} },
        { "normalize-space(  '   foo bar    baz     ' )", { "foo bar baz" } },
        { "normalize-space(  '   foo \n bar    baz     ' )", { "foo bar baz" } },
        { "not( 3 < 6 )", { false } },
        { "not( 6 < 3 )", { true } },
        { "reverse( ( 1,2,3 ) )", { 3.0, 2.0, 1.0 } },
        { "round( 3.2 )", { 3.0 } },
        { "round( 2.4999 )", { 2.0 } },
        { "round( 2.5 )", { 3.0 } },
        { "round( -7.5 )", { -7.0 } },
        { "round( -7.50001 )", { -8.0 } },
        { "string-join( ( 'a','b', 'c'),', '  )", { "a, b, c" } },
        { "string-length( 'a' )", { 1 } },
        { "string-length( 'ä' )", { 1 } },
        { "upper-case( 'aäÄ' )", { "AäÄ" } },
        { "upper-case( () )", { "" } },
        { "lower-case( 'Aa' )", { "aa" } },
        { "string-length( () )", { 0 } },
        { "/root/other/string()", { "\n  contents subsub other\n", "\n  contents subsub other2\n" } },
        { "substring( 'öäü', 2 )", { "äü" } },
        { "substring( 'Goldfarb', 5 )", { "farb" } },
        { "substring( 'Goldfarb', 5,3 )", { "far" } },
        { "count( /root/sub[@foo='bar'] )", { 2 } },
        { "count( /root/sub[@foo='doesnotexist'] )", { 0 } },
        { "( 'str', /root/@doesnotexist )[1] = 'str'", { true } },
        { "(/root/sub[@foo='bar']/last())[1]", { 2 } },
        { "string( /root/other[1] )", { "\n  contents subsub other\n" } },
        { "/root/sub[2]/string-length()", { 4 } },
        { "/root/sub/position()", { 1, 2, 3 } },
        { "count( /root/sub[position() mod 2 = 0])", { 1 } },
        { "count( /root/sub[position() mod 2 = 1])", { 2 } },
        { "string(/root/sub[position() mod 2 = 0]/@foo) ", { 'bar' } },
        { "count(/root/sub[3]) ", { 1 } },
        { "count(/root/sub[4]) ", { 0 } },
        { "count(/root/sub[3][1]) ", { 1 } },
        { "/root/sub/last() ", { 3, 3, 3 } },
        { "(1,2),(3,4)[2] ", { 1, 2, 4 } },
        { "( (1,2),(3,4)) [2] ", { 2 } },
        { " ( (),2 )[position() = 1] ", { 2 } },
        { " count(/root/a/*) ", { 4 } },
        { " for $i in (1,2,3) return $i * 2 ", { 2.0, 4.0, 6.0 } },
        { " if ( false() ) then 'a' else 'b' ", { 'b' } },
        { " if ( true() ) then 'a' else 'b' ", { 'a' } },
        { " /root/@one < 2 and /root/@one >= 1 ", { true } },
        { " /root/@one > 2 and /root/@one <= 1 ", { false } },
        { " matches('abracadabra', 'bra') ", { true } },
        { " 123 castable as xs:double ", { true } },
        { " '123' castable as xs:double ", { true } },
        { " 123 castable as xs:string ", { true } },
        { " 'abc' castable as xs:double ", { false } },
        { " string(/root/other[last()]/@foo) ", { 'other2' } },
        -- { " replace('abracadabra', 'bra') ", { true } },

    }

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
