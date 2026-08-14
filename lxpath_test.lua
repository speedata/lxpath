local luaunit = require("luaunit")
local lxpath = require("lxpath")
local xmltab = dofile("xmltable.lua")

TestTokenizer = {}


-- private functions
function TestTokenizer:test_get_qname()
    local testdata = {
        { "aaa",         "aaa" },
        { "aaa:foo",     "aaa:foo" },
        { "aaa:foo:bar", "aaa:foo" },
        -- '*' is only valid as a wildcard at the beginning of a name or
        -- directly after the namespace prefix separator ':'.
        { "*",           "*" },
        { "*:local",     "*:local" },
        { "ns:*",        "ns:*" },
        -- '*' in the middle of a name terminates the qname (operator follows).
        { "a*b",         "a" },
        { "a*",          "a" },
        { "ns:foo*bar",  "ns:foo" },
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
        { nil,              {} },
        { "",               {} },
        { "'abc'",          { { "abc", "tokString" } } },
        { "123.4",          { { 123.4, "tokNumber" } } },
        { " 2 +2",          { { 2, "tokNumber" }, { '+', "tokOperator" }, { 2, "tokNumber" } } },
        { "$a*$b",          { { "a", "tokVarname" }, { '*', "tokOperator" }, { "b", "tokVarname" } } },
        { "$a* $b",         { { "a", "tokVarname" }, { '*', "tokOperator" }, { "b", "tokVarname" } } },
        { " abc // def ",   { { "abc", "tokQName" }, { '//', "tokOperator" }, { "def", "tokQName" } } },
        { " false() ",      { { "false", "tokQName" }, { '(', "tokOpenParen" }, { ')', "tokCloseParen" } } },
        { "a('-')",         { { "a", "tokQName" }, { '(', "tokOpenParen" }, { "-", "tokString" }, { ')', "tokCloseParen" } } },
        { [[ a("a",'/') ]], { { "a", "tokQName" }, { '(', "tokOpenParen" }, { "a", "tokString" }, { ",", "tokComma" }, { "/", "tokString" }, { ')', "tokCloseParen" } } },
    }

    for _, tc in ipairs(testdata) do
        luaunit.assertEquals(lxpath.string_to_tokenlist(tc[1]), tc[2])
    end
end

function TestTokenizer:test_parse_error()
    local testdata = {
        { [[  string-join((1,2)) ]] } -- one argument instead of two
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
        local _, msg = ctx:eval(str)
        luaunit.assertNotIsNil(msg, string.format("test %s should give an error", td[1]))
    end
end

function TestTokenizer:test_parse_simple()
    local testdata = {
        { "+-+-+2",                                                              { 2.0 } },
        { "+-+-+-+ 2",                                                           { -2.0 } },
        { "2 = 4",                                                               { false } },
        { "2 = 2",                                                               { true } },
        { "2 < 2",                                                               { false } },
        { "2 < 3",                                                               { true } },
        { "3.4 > 3.1",                                                           { true } },
        { "3.4 != 3.1",                                                          { true } },
        { "'abc' = 'abc'",                                                       { true } },
        { "'aA' < 'aa'",                                                         { true } },
        { "'aA' != 'aa'",                                                        { true } },
        { "true() = true()",                                                     { true } },
        { "false() = true()",                                                    { false } },
        { "false() or true()",                                                   { true } },
        { "true() and false()",                                                  { false } },
        { "/root/(concat(@foo,@one)) ",                                          { "no1" } },
        { "/root/@foo = 'no' and /root/@one!='2'",                               { true } },
        { "/root/@one >= 1 and /root/@one <= 1",                                 { true } },
        { "/root/@one + /root/@one",                                             { 2.0 }},
        { "if (/root/@one) then string(/root/@one) else ''",                     { "1" } },
        { "if (/root/@doesnotexist) then string(/root/@doesnotexist) else ''",   { "" } },
        { "false()",                                                             { false } },
        { "-3.5",                                                                { -3.5 } },
        { "5 + 4",                                                               { 9.0 } },
        { "1 + 5 * 4",                                                           { 21.0 } },
        { "10 div 5",                                                            { 2.0 } },
        { "10 idiv 3",                                                           { 3.0 } },
        { "3 div -2",                                                            { -1.5 } },
        { "3 idiv -2",                                                           { -1.0 } },
        { "-3 idiv -2",                                                          { 1.0 } },
        { "-3.5 idiv 3",                                                         { -1.0 } },
        { "7 div 2 = 3.5",                                                       { true } },
        { "8 mod 2 = 0 ",                                                        { true } },
        { "4 < 2  or 5 < 7 ",                                                    { true } },
        { "concat('abc','def')",                                                 { "abcdef" } },
        { "concat(4,'/',6)",                                                     { "4/6" } },
        { "string(number('zzz')) = 'NaN'",                                       { true } },
        { "/root/number(x)",                                                     { 1.0 }  },
        { "$foo",                                                                { "bar" } },
        { "$onedotfive + 2",                                                     { 3.5 } },
        { "$one-two div $a",                                                     { 2.4 } },
        -- '*' adjacent to a variable name must tokenize as the multiplication
        -- operator, not be absorbed into the QName.
        { "$a*$a",                                                               { 25.0 } },
        { "$a *$a",                                                              { 25.0 } },
        { "$a* $a",                                                              { 25.0 } },
        { "$a*$onedotfive",                                                      { 7.5 } },
        { "7 mod 3",                                                             { 1.0 } },
        { "9 * 4 div 6",                                                         { 6.0 } },
        { "( 6 + 4 ) * 2",                                                       { 20.0 } },
        { "(1,2)",                                                               { 1.0, 2.0 } },
        { "(1,2) = (2,3)",                                                       { true } },
        { "(1,2) = (3,4)",                                                       { false } },
        { "(1,2) != (2,3)",                                                      { true } },
        { "(1,2) != (1,2)",                                                      { true } },
        { "(1,2) != (3,4)",                                                      { true } },
        { "(1,1) != (1,1)",                                                      { false } },
        { "()",                                                                  {} },
        { "( () )",                                                              {} },
        { "3,3",                                                                 { 3, 3 } },
        { "(3,3)",                                                               { 3, 3 } },
        { "(1,2)[true()]",                                                       { 1.0, 2.0 } },
        { "(1,2)[false()]",                                                      {} },
        { "( (),2 )[1]",                                                         { 2.0 } },
        { "1 to 3",                                                              { 1.0, 2.0, 3.0 } },
        { "for $foo in 1 to 3 return $foo * 2",                                  { 2.0, 4.0, 6.0 } },
        { "string(/root/@one)",                                                  { "1" } },
        { "abs( - 2 )",                                                          { 2.0 } },
        { "abs( -3.7 )",                                                         { 3.7 } },
        { "abs( -1.0e-7 )",                                                      { 1.0e-7 } },
        { "boolean( 0 )",                                                        { false } },
        { "boolean( 1 )",                                                        { true } },
        { "boolean( false() )",                                                  { false } },
        { "boolean( ((true())))",                                                { true } },
        { "boolean( true() )",                                                   { true } },
        { "boolean( '' )",                                                       { false } },
        { "boolean( () )",                                                       { false } },
        { "boolean( (()) )",                                                     { false } },
        { "boolean( 'false' )",                                                  { true } },
        { "boolean(/root)",                                                      { true } },
        { "boolean(/root/sub)",                                                  { true } },
        { "count(/root/sub)",                                                    { 3.0 } },
        { "contains( '', '' )",                                                  { true } },
        { "contains( (), 'a' )",                                                 { false } },
        { "contains( '', 'a' )",                                                 { false } },
        { "contains( 'Shakespeare', '' )",                                       { true } },
        { "contains( 'Shakespeare', 'spear' )",                                  { true } },
        { "string-to-codepoints( 'hellö' )",                                     { 104, 101, 108, 108, 246 } },
        { "codepoints-to-string( (65,33*2,67) )",                                { "ABC" } },
        { "codepoints-to-string( reverse(  string-to-codepoints( 'Hellö' ) ) )", { "ölleH" } },
        { "ceiling(1.0)",                                                        { 1.0 } },
        { "ceiling(1.5)",                                                        { 2.0 } },
        { "ceiling( 17 div 3 )",                                                 { 6.0 } },
        { "ceiling( -3 )",                                                       { -3.0 } },
        { "ceiling( -8.2e0 )",                                                   { -8.0e0 } },
        { "string(ceiling( 'ZZZ' ))",                                            { 'NaN' } },
        { "distinct-values( (1,2,2,3,3,3) )",                                    { 1.0, 2.0, 3.0 } },
        { "distinct-values( ('a','b','a','c','b') )",                            { 'a', 'b', 'c' } },
        { "distinct-values( () )",                                               {} },
        { "empty( () )",                                                         { true } },
        { "empty( /root/sub )",                                                  { false } },
        { "empty( /root/doesnotexist )",                                         { true } },
        { "empty( /root/@doesnotexist )",                                        { true } },
        { "floor(1.0)",                                                          { 1.0 } },
        { "floor(1.5)",                                                          { 1.0 } },
        { "floor( 17 div 3 )",                                                   { 5.0 } },
        { "floor( -3 )",                                                         { -3.0 } },
        { "floor( -8.2e0 )",                                                     { -9.0 } },
        { "floor( -0.5e0 )",                                                     { -1.0 } },
        { "format-number(1234.567, '###,##0.00')",                               { "1,234.57" } },
        { "format-number(1234.5, '00000')",                                      { "01234" } },
        { "format-number(0.123, '0.0%')",                                        { "12.3%" } },
        { "format-number(-42, '###,##0;(#)')",                                   { "(42)" } },
        { "format-number(0.0004, '0.###')",                                      { "0" } },
        { "format-number(0.0004, '0.000')",                                      { "0.000" } },
        { "format-number(12.3456, '#.##')",                                      { "12.35" } },
        { "format-number(12.3, '#.##')",                                         { "12.3" } },
        { "format-number(12, '#.##')",                                           { "12.0" } },
        { "format-number(1000, '#,##0')",                                        { "1,000" } },
        { "format-number(0.5, '0‰')",                                            { "500‰" } },
        { "format-number((), '###,##0.00')",                                     { "NaN" } },
        { "format-number(0 div 0, '0.00')",                                      { "NaN" } },
        { "format-number(1 div 0, '0.00')",                                      { "Infinity" } },
        { "format-number(-1 div 0, '0.00')",                                     { "-Infinity" } },
        { "max(  ( 1,2,3) )",                                                    { 3.0 } },
        { "local-name(/root)",                                                   { "root" } },
        { "local-name(root())",                                                  { "root" } },
        { "root()/local-name()",                                                 { "root" } },
        { "/root/local-name()",                                                  { "root" } },
        { "local-name(/)",                                                       { "" } },
        { "/local-name()",                                                       { "" } },
        { "max(  ( ) )",                                                         {} },
        { "min(  ( 1,2,3) )",                                                    { 1.0 } },
        { "min(  ( ) )",                                                         {} },
        { "normalize-space(  '   foo bar    baz     ' )",                        { "foo bar baz" } },
        { "normalize-space(  '   foo \n bar    baz     ' )",                     { "foo bar baz" } },
        { "not( 3 < 6 )",                                                        { false } },
        { "not( 6 < 3 )",                                                        { true } },
        { "reverse( ( 1,2,3 ) )",                                                { 3.0, 2.0, 1.0 } },
        { "round( 3.2 )",                                                        { 3.0 } },
        { "round( 2.4999 )",                                                     { 2.0 } },
        { "round( 2.5 )",                                                        { 3.0 } },
        { "round( -7.5 )",                                                       { -7.0 } },
        { "round( -7.50001 )",                                                   { -8.0 } },
        { "round-half-to-even( 1.1742,2)",                                       { 1.17 } },
        { "round-half-to-even(1.175,2)",                                         { 1.18 }},
        { "round-half-to-even(2.5,0)",                                           { 2.0 }},
        { "round-half-to-even(273,-1) ",                                         { 270 }},
        { "round-half-to-even(-8500,-3)",                                        { -8000 }},
        { "string-join( ( 'a','b', 'c'),', '  )",                                { "a, b, c" } },
        { "string-join( ('Go','home,', 'Jack!',''),'-')",                        { 'Go-home,-Jack!-' } },
        { "string-length( 'a' )",                                                { 1 } },
        { "string-length( 'ä' )",                                                { 1 } },
        { "upper-case( 'aäÄ' )",                                                 { "AäÄ" } },
        { "upper-case( () )",                                                    { "" } },
        { "lower-case( 'Aa' )",                                                  { "aa" } },
        { "string-length( () )",                                                 { 0 } },
        { "/root/other/string()",                                                { "\n  contents subsub other\n", "\n  contents subsub other2\n" } },
        { "substring( 'öäü', 2 )",                                               { "äü" } },
        { "substring( 'Goldfarb', 5 )",                                          { "farb" } },
        { "substring( 'Goldfarb', 5,3 )",                                        { "far" } },
        { [[ starts-with("$t%attoo", "$t%at") ]],                                { true } },
        { [[ starts-with("tattoo", "tat") ]],                                    { true } },
        { [[ starts-with( (), () ) ]],                                           { true } },
        { [[ starts-with( (), () ) ]],                                           { true } },
        { [[ ends-with( (), () ) ]],                                             { true } },
        { [[ ends-with("tattoo", "too") ]],                                      { true } },
        { [[ ends-with("tatto$o$", "$o$") ]],                                    { true } },
        { [[ substring-after("tattoo", "tat") ]],                                { "too" } },
        { [[ substring-before ( "tattoo", "att") ]],                             { "t" } },
        { [[ translate("abcd", "bd", "XY") ]],                                   { "aXcY" } },
        { [[ translate("hello", "hel", "HE") ]],                                 { "HEo" } },
        { [[ translate("àáâ", "áâ", "") ]],                                      { "à" } },
        { [[ translate("aba", "ab", "BA") ]],                                    { "BAB" } },
        { [[ translate("banana", "ana", "x") ]],                                 { "bxxx" } },
        { [[ translate((), "abc", "ABC") ]],                                     { "" } },
        { [[ translate("mississippi", "is", "xy") ]],                            { "mxyyxyyxppx" } },
        { [[ translate("12345", "135", "AB") ]],                                 { "A2B4" } },
        { [[ translate("xxx", "x", "") ]],                                       { "" } },
        { [[ translate("emoji 😀😃😄", "😀😄", "xy") ]],                           { "emoji x😃y" } },
        { [[ translate("abc", "ab", "WXYZ") ]],                                  { "WXc" } },   -- 'to' longer than 'from' -> excess ignored
        { [[ translate("abc", "abc", "Z") ]],                                    { "Z" } },     -- 'from' longer than 'to' -> b,c removed
        { [[ translate("abac", "aabc", "XYZ") ]],                                { "XZX" } },   -- duplicate 'a' in 'from' -> 2nd ignored; corresponding 'Y' ignored; 'c' deleted
        { [[ translate("aba", "aba", "123") ]],                                  { "121" } },   -- duplicate at pos3 ignored (and '3' ignored)
        { [[ translate("abc", "", "XYZ") ]],                                     { "abc" } },   -- empty 'from' -> unchanged
        { [[ translate("banana", "an", "") ]],                                   { "b" } },     -- third arg empty -> remove all in 'from'
        { [[ translate("foo", "xyz", "123") ]],                                  { "foo" } },   -- none of 'from' present
        { [[ translate("cab", "abc", "xxx") ]],                                  { "xxx" } },   -- many-to-one mapping
        { [[ translate((), "a", "b") ]],                                         { "" } },      -- arg is empty-sequence -> empty string
        { [[ translate("", "abc", "XYZ") ]],                                     { "" } },      -- empty input string
        { [[ translate("ÄÖÜ", "Ä", "a") ]],                                      { "aÖÜ" } },   -- UTF-8: replace only 'Ä'
        { [[ translate("zz", "z", "XY") ]],                                      { "XX" } },    -- 'to' longer: still map to first position only
        { [[ translate("xyz", "yz", "Q") ]],                                     { "xQ" } },    -- 'y'->'Q', 'z' removed (|to|=1)
        { [[ translate(" miss iss ", " ", "") ]],                                { "mississ" } },-- remove spaces
        { [[ translate("mississippi", "is", "x") ]],                             { "mxxxppx" } },-- 'i'->'x', 's' deleted
        { "count( /root/sub[@foo='bar'] )",                                      { 2 } },
        { "count(/root[@foo = 'no' and @one!=2])",                               { 1} },
        { "count(/root[@foo = 'zzz' or @one!=2])",                               { 1} },
        { "count( //sub )",                                                      { 7.0 } },
        { "count( /root/sub[@foo='doesnotexist'] )",                             { 0 } },
        { "/root/@doesnotexist = ''",                                            { false } },
        { "( 'str', /root/@doesnotexist )[1] = 'str'",                           { true } },
        { "(/root/sub[@foo='bar']/last())[1]",                                   { 2 } },
        { "string( /root/other[1] )",                                            { "\n  contents subsub other\n" } },
        { "/root/sub[2]/string-length()",                                        { 4 } },
        { "/root/sub/position()",                                                { 1, 2, 3 } },
        { "count( /root/sub[position() mod 2 = 0])",                             { 1 } },
        { "count( /root/sub[position() mod 2 = 1])",                             { 2 } },
        { "string(/root/sub[position() mod 2 = 0]/@foo) ",                       { 'bar' } },
        { "count(/root/sub[3]) ",                                                { 1 } },
        { "count(/root/sub[4]) ",                                                { 0 } },
        { "count(/root/sub[3][1]) ",                                             { 1 } },
        { "/root/sub/last() ",                                                   { 3, 3, 3 } },
        { "(1,2),(3,4)[2] ",                                                     { 1, 2, 4 } },
        { "( (1,2),(3,4)) [2] ",                                                 { 2 } },
        { " ( (),2 )[position() = 1] ",                                          { 2 } },
        { " count(/root/a/*) ",                                                  { 4 } },
        { " for $i in (1,2,3) return $i * 2 ",                                   { 2.0, 4.0, 6.0 } },
        { " if ( false() ) then 'a' else 'b' ",                                  { 'b' } },
        { " if ( true() ) then 'a' else 'b' ",                                   { 'a' } },
        { " /root/@one < 2 and /root/@one >= 1 ",                                { true } },
        { " /root/@one > 2 and /root/@one <= 1 ",                                { false } },
        { " matches('abracadabra', 'bra') ",                                     { true } },
        { " 123 castable as xs:double ",                                         { true } },
        { " '123' castable as xs:double ",                                       { true } },
        { " 123 castable as xs:string ",                                         { true } },
        { " 'abc' castable as xs:double ",                                       { false } },
        { " string(/root/other[last()]/@foo) ",                                  { 'other2' } },
        { [[ every $i in /root/sub satisfies $i/@foo="bar"]],                    { false } },
        { [[ some $i in /root/sub satisfies $i/@foo="bar"]],                     { true } },
        { [[ some $i in /root/sub satisfies $i/@foo="zzzz"]],                    { false } },
        { [[ some $x in (1, 2, 3), $y in (2, 3) satisfies $x + $y = 4]],         { true } },
        { " count(/root/sub | /root/other) ",                                    { 5 } },
        { " count(/root/sub union /root/other) ",                                { 5 } },
        { " count(/root/sub | /root/sub) ",                                      { 3 } },
        { " count(/root/sub | /root/other | /root/a) ",                          { 7 } },
        -- union result must be in document order (sub precedes other)
        { " string( (/root/other | /root/sub)[1]/@foo ) ",                       { "baz" } },
        { " count( (/root/sub | /root/other) intersect /root/sub ) ",            { 3 } },
        { " count( /root/sub intersect /root/other ) ",                          { 0 } },
        { " count( (/root/sub | /root/other) except /root/sub ) ",               { 2 } },
        { " count( /root/sub except /root/other ) ",                             { 3 } },
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

-- Test arithmetic and comparison on relative attribute references (@attr1 op @attr2)
-- where the context sequence is already positioned on an element.
-- This verifies that evaluating the first operand does not destroy the context
-- for the second operand (the attribute axis mutates ctx.sequence).
function TestTokenizer:test_relative_attr_arithmetic()
    -- root element of xmltab has: one="1", foo="no", empty=""
    local root = xmltab[1]
    local testdata = {
        { "@one + @one",           { 2.0 } },
        { "@one - @one",           { 0.0 } },
        { "@one * @one",           { 1.0 } },
        { "@one div @one",         { 1.0 } },
        { "@one + @one + @one",    { 3.0 } },
        { "@one = @one",           { true } },
        { "@foo != @empty",        { true } },
    }

    for _, td in ipairs(testdata) do
        local ctxvalue = {
            namespaces = { fn = lxpath.fnNS },
            vars = {},
            xmldoc = { root },
            sequence = { root },
        }
        local ctx = lxpath.context:new(ctxvalue)
        local seq, msg = ctx:eval(td[1])
        luaunit.assertIsNil(msg, string.format("expression %s returned error: %s", td[1], tostring(msg)))
        luaunit.assertEquals(seq, td[2], td[1])
    end
end

function TestTokenizer:test_parse_axis()
    local testdata = {
        { [[ /child::root/@foo = 'no']],                                     { true } },
        { [[ count(/root/descendant-or-self::sub) ]],                        { 7.0 } },
        { [[ count(/root/sub/descendant-or-self::sub )]],                    { 3.0 } },
        { [[ count(/root/sub/descendant-or-self::text())]],                  { 4.0 } },
        { [[ /root/sub/descendant-or-self::text()[2] ]],                     { "subsub" } },
        { [[ (/root/*/descendant::sub/@p)[4] = "a2/2" ]],                    { true } },
        { [[ count(/root/*/descendant::sub[1]) ]],                           { 2.0 } },
        { [[ count(/root/a/node()) ]],                                       { 10.0 } },
        { [[ (/root/a/node()[2]/@p)[1] = 'a1/1' ]],                          { true } },
        { [[ count(/root//sub) ]],                                           { 7.0 } },
        { [[ count(/root//sub[1]) ]],                                        { 3.0 } },
        { [[ count(/root//text()) ]],                                        { 26.0 } },
        { [[ count(/root/child::element()) ]],                               { 8.0 } },
        { [[ local-name( (/root/sub[3]/following-sibling::element())[2]) ]], { "other" } },
        { [[ count( /root/sub[3]/following-sibling::element() ) ]],          { 5.0 } },
        { [[ count(/root/sub[3]/following::element() ) ]],                   { 12.0 } },
        { [[ /root/sub[3]/subsub/parent::element()/local-name() ]],          { "sub" } },
        { [[ count(/root/sub[3]/subsub/ancestor::element()) ]],              { 2.0 } },
        { [[ /root/sub[3]/subsub/ancestor::element()/local-name()  ]],       { "root", "sub" } },
        { [[ /root/sub[3]/subsub/ancestor-or-self::element()/local-name()]], { "root", "sub", "subsub" } },
        { [[ /root/sub[3]/preceding-sibling::element()/string(@foo)]],       { "baz", "bar" } },
        { [[ /root/sub[3]/preceding-sibling::element()[1]/string(@foo)]],    { "bar" } },
        { [[ /root/other[1]/preceding::element()/string() ]],                { "123", "sub2", "contents sub3subsub", "subsub" } },
        { [[ /root//subsub[1]/../@self = "sub3" ]],                          { true } },
        { [[ serialize(/root/sub[1]) ]],                                       { '<sub foo="baz" someattr="somevalue">123</sub>' } },
        { [[ serialize(/root/sub[2]) ]],                                       { '<sub attr="baz" foo="bar">sub2</sub>' } },
        { [[ serialize(/root/x) ]],                                            { "<x><y>1</y></x>" } },
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

-- Test string concatenation operator ||
function TestTokenizer:test_string_concat()
    local testdata = {
        { "'hello' || ' ' || 'world'",  { "hello world" } },
        { "1 || 2",                      { "12" } },
        { "$foo || 'baz'",               { "barbaz" } },
        { "'a' || 'b' || 'c' || 'd'",   { "abcd" } },
        { "'' || ''",                    { "" } },
    }
    for _, td in ipairs(testdata) do
        local ctx = lxpath.context:new({
            namespaces = { fn = lxpath.fnNS },
            vars = { foo = "bar" },
            xmldoc = { xmltab },
            sequence = { xmltab },
        })
        local seq, msg = ctx:eval(td[1])
        luaunit.assertIsNil(msg, string.format("expression %s returned error: %s", td[1], tostring(msg)))
        luaunit.assertEquals(seq, td[2], td[1])
    end
end

-- Regression test for issue #3: // after a step yielding a document node must
-- keep the document node, so its children remain reachable ($doc//root)
function TestTokenizer:test_double_slash_after_document_node()
    local testdata = {
        { "count($doc/root)",  { 1 } },
        { "count($doc//root)", { 1 } },
        { "count(//root)",     { 1 } },
        { "count($doc//sub)",  { 7 } },
    }
    for _, td in ipairs(testdata) do
        local ctx = lxpath.context:new({
            namespaces = { fn = lxpath.fnNS },
            vars = { doc = { xmltab } },
            xmldoc = { xmltab },
            sequence = { xmltab },
        })
        local seq, msg = ctx:eval(td[1])
        luaunit.assertIsNil(msg, string.format("expression %s returned error: %s", td[1], tostring(msg)))
        luaunit.assertEquals(seq, td[2], td[1])
    end
end

-- Test tokenizer for new tokens
function TestTokenizer:test_new_tokens()
    local testdata = {
        { "||",  { { "||", "tokOperator" } } },
        { "|",   { { "|", "tokOperator" } } },
        { "{}",  { { "{", "tokOpenCurly" }, { "}", "tokCloseCurly" } } },
        { "[]",  { { "[", "tokOpenBracket" }, { "]", "tokCloseBracket" } } },
    }
    for _, tc in ipairs(testdata) do
        luaunit.assertEquals(lxpath.string_to_tokenlist(tc[1]), tc[2])
    end
end

-- Test arrays
function TestTokenizer:test_arrays()
    local testdata = {
        -- Square bracket constructor
        { "[]",                          { lxpath.make_array({}) } },
        { "[1, 2, 3]",                   { lxpath.make_array({{1},{2},{3}}) } },
        { "['a', 'b']",                  { lxpath.make_array({{"a"},{"b"}}) } },
        -- Curly array constructor
        { "array {}",                    { lxpath.make_array({}) } },
        { "array { 1 to 3 }",           { lxpath.make_array({{1},{2},{3}}) } },
        -- Lookup
        { "[10, 20, 30]?2",             { 20 } },
        { "[10, 20, 30]?1",             { 10 } },
        { "['a', 'b', 'c']?3",          { "c" } },
        -- Wildcard lookup
        { "[10, 20, 30]?*",             { 10, 20, 30 } },
    }
    for _, td in ipairs(testdata) do
        local ctx = lxpath.context:new({
            namespaces = { fn = lxpath.fnNS, array = lxpath.arrayNS },
            vars = {},
            xmldoc = { xmltab },
            sequence = { xmltab },
        })
        local seq, msg = ctx:eval(td[1])
        luaunit.assertIsNil(msg, string.format("expression %s returned error: %s", td[1], tostring(msg)))
        luaunit.assertEquals(seq, td[2], td[1])
    end
end

-- Test maps
function TestTokenizer:test_maps()
    local testdata = {
        -- Empty map
        { "map {}",                      { lxpath.make_map({}) } },
        -- Lookup by name
        { "map { 'a': 1, 'b': 2 }?a",   { 1 } },
        { "map { 'x': 'hello' }?x",     { "hello" } },
        -- Wildcard lookup
    }
    for _, td in ipairs(testdata) do
        local ctx = lxpath.context:new({
            namespaces = { fn = lxpath.fnNS, map = lxpath.mapNS },
            vars = {},
            xmldoc = { xmltab },
            sequence = { xmltab },
        })
        local seq, msg = ctx:eval(td[1])
        luaunit.assertIsNil(msg, string.format("expression %s returned error: %s", td[1], tostring(msg)))
        luaunit.assertEquals(seq, td[2], td[1])
    end
end

-- Test array and map with variables
function TestTokenizer:test_array_map_variables()
    local myarr = lxpath.make_array({{10},{20},{30}})
    local mymap = lxpath.make_map({a = {1}, b = {2}})
    local testdata = {
        { "$arr?1",                      { 10 } },
        { "$arr?3",                      { 30 } },
        { "$map?a",                      { 1 } },
        { "$map?b",                      { 2 } },
    }
    for _, td in ipairs(testdata) do
        local ctx = lxpath.context:new({
            namespaces = { fn = lxpath.fnNS, array = lxpath.arrayNS, map = lxpath.mapNS },
            vars = { arr = myarr, map = mymap },
            xmldoc = { xmltab },
            sequence = { xmltab },
        })
        local seq, msg = ctx:eval(td[1])
        luaunit.assertIsNil(msg, string.format("expression %s returned error: %s", td[1], tostring(msg)))
        luaunit.assertEquals(seq, td[2], td[1])
    end
end

-- Test array functions
function TestTokenizer:test_array_functions()
    local testdata = {
        { "array:size([1, 2, 3])",                 { 3.0 } },
        { "array:size([])",                         { 0.0 } },
        { "array:get([10, 20, 30], 2)",            { 20 } },
        { "array:append([1, 2], 3)?3",             { 3 } },
        { "array:size(array:remove([1, 2, 3], 2))", { 2.0 } },
        { "array:flatten([1, [2, 3]])",            { 1, 2, 3 } },
        { "array:subarray([1, 2, 3, 4], 2, 2)",   { lxpath.make_array({{2},{3}}) } },
    }
    for _, td in ipairs(testdata) do
        local ctx = lxpath.context:new({
            namespaces = { fn = lxpath.fnNS, array = lxpath.arrayNS },
            vars = {},
            xmldoc = { xmltab },
            sequence = { xmltab },
        })
        local seq, msg = ctx:eval(td[1])
        luaunit.assertIsNil(msg, string.format("expression %s returned error: %s", td[1], tostring(msg)))
        luaunit.assertEquals(seq, td[2], td[1])
    end
end

-- Test map functions
function TestTokenizer:test_map_functions()
    local testdata = {
        { "map:size(map { 'a': 1, 'b': 2 })",        { 2.0 } },
        { "map:size(map {})",                          { 0.0 } },
        { "map:get(map { 'x': 42 }, 'x')",            { 42 } },
        { "map:contains(map { 'a': 1 }, 'a')",        { true } },
        { "map:contains(map { 'a': 1 }, 'b')",        { false } },
        { "map:size(map:put(map { 'a': 1 }, 'b', 2))", { 2.0 } },
        { "map:size(map:remove(map { 'a': 1, 'b': 2 }, 'a'))", { 1.0 } },
    }
    for _, td in ipairs(testdata) do
        local ctx = lxpath.context:new({
            namespaces = { fn = lxpath.fnNS, map = lxpath.mapNS },
            vars = {},
            xmldoc = { xmltab },
            sequence = { xmltab },
        })
        local seq, msg = ctx:eval(td[1])
        luaunit.assertIsNil(msg, string.format("expression %s returned error: %s", td[1], tostring(msg)))
        luaunit.assertEquals(seq, td[2], td[1])
    end
end

-- Errors must be reported as the second return value (never as the result),
-- non-numeric arguments must not crash the evaluator
function TestTokenizer:test_error_reporting()
    local errdata = {
        "floor((1,2))",
        "ceiling((1,2))",
        "for $x in floor((1,2)) return $x",
        "(1",
        "array:put([1, 2, 3], 'x', 5)",
        "array:remove([1, 2], 'x')",
        "array:subarray([1, 2, 3], 'x')",
        "codepoints-to-string((65.5))",
        "xyzzy:foo()",
        "doesnotexist()",
        "floor()",
        "floor(1, 2)",
    }
    for _, xp in ipairs(errdata) do
        local ctx = lxpath.context:new({
            namespaces = { fn = lxpath.fnNS, array = lxpath.arrayNS },
            vars = {},
            xmldoc = { xmltab },
            sequence = { xmltab },
        })
        local seq, msg = ctx:eval(xp)
        luaunit.assertIsNil(seq, string.format("expression %s should not return a sequence", xp))
        luaunit.assertNotIsNil(msg, string.format("expression %s should return an error message", xp))
    end
    local okdata = {
        { "substring('hello', 'x')",          { "" } },
        { "substring('hello', 1, 'x')",       { "" } },
        { "codepoints-to-string((104, 105))", { "hi" } },
    }
    for _, td in ipairs(okdata) do
        local ctx = lxpath.context:new({
            namespaces = { fn = lxpath.fnNS },
            vars = {},
            xmldoc = { xmltab },
            sequence = { xmltab },
        })
        local seq, msg = ctx:eval(td[1])
        luaunit.assertIsNil(msg, string.format("expression %s returned error: %s", td[1], tostring(msg)))
        luaunit.assertEquals(seq, td[2], td[1])
    end
end

-- XML Parser tests
local xmlparser = require("xmlparser")

TestXMLParser = {}

function TestXMLParser:test_simple_element()
    local doc = xmlparser.parse("<root/>")
    luaunit.assertEquals(doc[".__type"], "document")
    luaunit.assertEquals(doc[1][".__type"], "element")
    luaunit.assertEquals(doc[1][".__name"], "root")
    luaunit.assertEquals(doc[1][".__local_name"], "root")
    luaunit.assertEquals(doc[1][".__namespace"], "")
    luaunit.assertEquals(doc[1][".__id"], 1)
end

function TestXMLParser:test_attributes()
    local doc = xmlparser.parse('<root foo="bar" baz="123"/>')
    luaunit.assertEquals(doc[1][".__attributes"]["foo"], "bar")
    luaunit.assertEquals(doc[1][".__attributes"]["baz"], "123")
end

function TestXMLParser:test_text_content()
    local doc = xmlparser.parse("<root>hello world</root>")
    luaunit.assertEquals(doc[1][1], "hello world")
end

function TestXMLParser:test_nested_elements()
    local doc = xmlparser.parse("<root><child>text</child></root>")
    luaunit.assertEquals(doc[1][1][".__name"], "child")
    luaunit.assertEquals(doc[1][1][1], "text")
    luaunit.assertEquals(doc[1][1][".__id"], 2)
end

function TestXMLParser:test_mixed_content()
    local doc = xmlparser.parse("<root>before<child/>after</root>")
    luaunit.assertEquals(doc[1][1], "before")
    luaunit.assertEquals(doc[1][2][".__name"], "child")
    luaunit.assertEquals(doc[1][3], "after")
end

function TestXMLParser:test_entities()
    local doc = xmlparser.parse("<root>&amp;&lt;&gt;&quot;&apos;</root>")
    luaunit.assertEquals(doc[1][1], [[&<>"']])
end

function TestXMLParser:test_numeric_entities()
    local doc = xmlparser.parse("<root>&#65;&#x42;</root>")
    luaunit.assertEquals(doc[1][1], "AB")
end

function TestXMLParser:test_cdata()
    local doc = xmlparser.parse("<root><![CDATA[<not>xml</not>]]></root>")
    luaunit.assertEquals(doc[1][1], "<not>xml</not>")
end

function TestXMLParser:test_cdata_merge_text()
    local doc = xmlparser.parse("<root>before<![CDATA[ middle ]]>after</root>")
    luaunit.assertEquals(doc[1][1], "before middle after")
end

function TestXMLParser:test_comments_skipped()
    local doc = xmlparser.parse("<root><!-- comment -->text</root>")
    luaunit.assertEquals(doc[1][1], "text")
end

function TestXMLParser:test_pi_skipped()
    local doc = xmlparser.parse("<?xml version='1.0'?><root><?pi data?></root>")
    luaunit.assertNil(doc[1][1])
end

function TestXMLParser:test_self_closing()
    local doc = xmlparser.parse('<root><br/><hr /></root>')
    luaunit.assertEquals(doc[1][1][".__name"], "br")
    luaunit.assertEquals(doc[1][2][".__name"], "hr")
end

function TestXMLParser:test_default_namespace()
    local doc = xmlparser.parse('<root xmlns="http://example.com"><child/></root>')
    luaunit.assertEquals(doc[1][".__namespace"], "http://example.com")
    luaunit.assertEquals(doc[1][1][".__namespace"], "http://example.com")
end

function TestXMLParser:test_prefixed_namespace()
    local doc = xmlparser.parse('<ns:root xmlns:ns="http://example.com"><ns:child/></ns:root>')
    luaunit.assertEquals(doc[1][".__name"], "ns:root")
    luaunit.assertEquals(doc[1][".__local_name"], "root")
    luaunit.assertEquals(doc[1][".__namespace"], "http://example.com")
    luaunit.assertEquals(doc[1][".__ns"]["ns"], "http://example.com")
    luaunit.assertEquals(doc[1][1][".__namespace"], "http://example.com")
end

function TestXMLParser:test_parent_links()
    local doc = xmlparser.parse("<root><child><sub/></child></root>")
    luaunit.assertEquals(doc[1][".__parent"], doc)
    luaunit.assertEquals(doc[1][1][".__parent"], doc[1])
    luaunit.assertEquals(doc[1][1][1][".__parent"], doc[1][1])
end

function TestXMLParser:test_document_order_ids()
    local doc = xmlparser.parse("<root><a/><b><c/></b></root>")
    luaunit.assertEquals(doc[1][".__id"], 1)
    luaunit.assertEquals(doc[1][1][".__id"], 2)
    luaunit.assertEquals(doc[1][2][".__id"], 3)
    luaunit.assertEquals(doc[1][2][1][".__id"], 4)
end

function TestXMLParser:test_quoted_attributes()
    local doc = xmlparser.parse([[<root a='"text"' b="it's"/>]])
    luaunit.assertEquals(doc[1][".__attributes"]["a"], '"text"')
    luaunit.assertEquals(doc[1][".__attributes"]["b"], "it's")
end

function TestXMLParser:test_whitespace_in_tags()
    local doc = xmlparser.parse('<root  foo = "bar"  ><child  /></root >')
    luaunit.assertEquals(doc[1][".__attributes"]["foo"], "bar")
    luaunit.assertEquals(doc[1][1][".__name"], "child")
end

function TestXMLParser:test_entity_in_attribute()
    local doc = xmlparser.parse('<root val="a&amp;b"/>')
    luaunit.assertEquals(doc[1][".__attributes"]["val"], "a&b")
end

function TestXMLParser:test_mismatched_tag_error()
    luaunit.assertErrorMsgContains("mismatched closing tag", function()
        xmlparser.parse("<root><child></wrong></root>")
    end)
end

-- Edge cases

function TestXMLParser:test_umlauts_in_names()
    local doc = xmlparser.parse('<Bücher><Ärger attribut="schön">Öl</Ärger></Bücher>')
    luaunit.assertEquals(doc[1][".__name"], "Bücher")
    luaunit.assertEquals(doc[1][1][".__name"], "Ärger")
    luaunit.assertEquals(doc[1][1][".__attributes"]["attribut"], "schön")
    luaunit.assertEquals(doc[1][1][1], "Öl")
end

function TestXMLParser:test_empty_document_element()
    local doc = xmlparser.parse("<r></r>")
    luaunit.assertEquals(doc[1][".__name"], "r")
    luaunit.assertNil(doc[1][1])
end

function TestXMLParser:test_deeply_nested()
    local doc = xmlparser.parse("<a><b><c><d><e>deep</e></d></c></b></a>")
    luaunit.assertEquals(doc[1][1][1][1][1][1], "deep")
    luaunit.assertEquals(doc[1][1][1][1][1][".__id"], 5)
end

function TestXMLParser:test_multiple_namespaces()
    local xml = '<root xmlns:a="http://a.example" xmlns:b="http://b.example"><a:x/><b:y/></root>'
    local doc = xmlparser.parse(xml)
    luaunit.assertEquals(doc[1][1][".__namespace"], "http://a.example")
    luaunit.assertEquals(doc[1][1][".__local_name"], "x")
    luaunit.assertEquals(doc[1][2][".__namespace"], "http://b.example")
    luaunit.assertEquals(doc[1][2][".__local_name"], "y")
end

function TestXMLParser:test_namespace_override()
    local xml = '<root xmlns="http://outer"><child xmlns="http://inner"><sub/></child><sibling/></root>'
    local doc = xmlparser.parse(xml)
    luaunit.assertEquals(doc[1][".__namespace"], "http://outer")
    luaunit.assertEquals(doc[1][1][".__namespace"], "http://inner")
    luaunit.assertEquals(doc[1][1][1][".__namespace"], "http://inner")
    luaunit.assertEquals(doc[1][2][".__namespace"], "http://outer")
end

function TestXMLParser:test_doctype_skipped()
    local xml = '<?xml version="1.0"?><!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd"><root/>'
    local doc = xmlparser.parse(xml)
    luaunit.assertEquals(doc[1][".__name"], "root")
end

-- Integration: parse the same XML as xmltable.lua and run an xpath on it
function TestXMLParser:test_integration_with_lxpath()
    local xml = [=[<root empty="" quotationmarks='"text"' one="1" foo="no">
<sub foo="baz" someattr="somevalue">123</sub>
<sub foo="bar" attr="baz">sub2</sub>
<sub foo="bar" self="sub3">contents sub3<subsub foo="bar">subsub</subsub></sub>
<other foo="barbaz">
  <subsub foo="oof">contents subsub other</subsub>
</other>
<other foo="other2">
  <subsub foo="oof">contents subsub other2</subsub>
</other>
<x><y>1</y></x>
<a>
<sub p="a1/1"></sub>
<sub p="a1/2"></sub>
</a>
<a>
<sub  p="a2/1"></sub>
<sub  p="a2/2"></sub>
</a>
</root>]=]

    local doc = xmlparser.parse(xml)
    local ctx = lxpath.context:new({
        namespaces = { fn = lxpath.fnNS },
        vars = {},
        xmldoc = { doc },
        sequence = { doc },
    })

    -- Simple expressions that should work on the parsed document
    local seq, msg = ctx:eval("/root/sub[1]")
    luaunit.assertIsNil(msg)
    luaunit.assertEquals(seq[1][".__attributes"]["foo"], "baz")

    seq, msg = ctx:eval("string(/root/sub[2])")
    luaunit.assertIsNil(msg)
    luaunit.assertEquals(seq[1], "sub2")

    seq, msg = ctx:eval("count(/root/sub)")
    luaunit.assertIsNil(msg)
    luaunit.assertEquals(seq[1], 3)

    seq, msg = ctx:eval("/root/other/subsub")
    luaunit.assertIsNil(msg)
    luaunit.assertEquals(#seq, 2)
end

os.exit(luaunit.LuaUnit.run())
