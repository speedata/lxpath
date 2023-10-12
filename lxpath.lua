local M = {
    private = {},
    funcs = {},
    dodebug = false,
    debugindent = "  ",
    fnNS = "http://www.w3.org/2005/xpath-functions",
    xsNS = "http://www.w3.org/2001/XMLSchema",
}

local debuglevel = 0

local nan = 0 / 0

local function unread_rune(tbl)
    tbl.pos = tbl.pos - 1
end

---@return string
---@return boolean
local function read_rune(tbl)
    local r = tbl[tbl.pos]
    tbl.pos = tbl.pos + 1
    if tbl.pos > #tbl + 1 then return r, true end
    return r, false
end

local function is_letter(str)
    return string.match(str, "%w")
end

local function is_digit(str)
    return string.match(str, "[0-9]")
end

local function is_space(str)
    return string.match(str, "%s")
end

---@param runes table
---@return string
local function get_qname(runes)
    local word = {}
    local hasColon = false
    local r, eof
    while true do
        r, eof = read_rune(runes)
        if eof then break end
        if is_letter(r) or is_digit(r) or r == '_' or r == '-' or r == '·' or r == '‿' or r == '⁀' then
            word[#word + 1] = r
        elseif r == ":" then
            if hasColon then
                unread_rune(runes)
                break
            end
            word[#word + 1] = r
            hasColon = true
        else
            unread_rune(runes)
            break
        end
    end
    return table.concat(word)
end
M.private.get_qname = get_qname

---@return string
local function get_delimited_string(tbl)
    local str = {}
    local eof = false
    local r
    local delim = read_rune(tbl)
    while true do
        r, eof = read_rune(tbl)
        if eof then break end
        if r == delim then
            break
        else
            str[#str + 1] = r
        end
    end
    return table.concat(str)
end

---@return string comment
local function get_comment(tbl)
    local level = 1
    local cur, after
    local eof
    local comment = {}
    while true do
        cur, eof = read_rune(tbl)
        if eof then break end
        after, eof = read_rune(tbl)
        if eof then break end
        if cur == ':' and after == ')' then
            level = level - 1
            if level == 0 then
                break
            end
        elseif cur == '(' and after == ':' then
            level = level + 1
        end
        comment[#comment + 1] = cur

        if after == ':' or after == '(' then
            unread_rune(tbl)
        else
            -- add after to comment
            comment[#comment + 1] = after
        end
    end
    return table.concat(comment)
end


---@return number?
local function get_num(runes)
    local tbl = {}
    local eof = false
    local r
    while true do
        r, eof = read_rune(runes)
        if eof then break end
        if '0' <= r and r <= '9' then
            tbl[#tbl + 1] = r
        elseif r == "." or r == "e" or r == "-" then
            tbl[#tbl + 1] = r
        else
            unread_rune(runes)
            break
        end
    end
    return tonumber(table.concat(tbl, ""))
end
M.private.get_num = get_num

---@return table
local function split_chars(str)
    local runes = {}
    for _, c in utf8.codes(str) do
        runes[#runes + 1] = utf8.char(c)
    end
    runes.pos = 1
    return runes
end
M.private.split_chars = split_chars

---@class token


---@class tokenlist
local tokenlist = {}


function tokenlist:new(o)
    o = o or {} -- create object if user does not provide one
    setmetatable(o, self)
    self.__index = self
    self.pos = 1
    self.attributeMode = false
    return o
end

---@return token?
---@return boolean
function tokenlist:peek()
    if self.pos > #self then
        return nil, true
    end
    return self[self.pos], false
end

---@return token?
---@return string?
function tokenlist:read()
    if self.pos > #self then
        return nil, "eof"
    end
    self.pos = self.pos + 1
    return self[self.pos - 1], nil
end

---@return string?
function tokenlist:unread()
    if self.pos == 1 then
        return "eof"
    end
    self.pos = self.pos - 1
    return nil
end

---@param tokvalues table
---@return token?
---@return string?
function tokenlist:readNexttokIfIsOneOfValue(tokvalues)
    if self.pos > #self then
        return nil, nil
    end
    for _, tokvalue in ipairs(tokvalues) do
        if self[self.pos][1] == tokvalue then
            return self:read()
        end
    end
    return nil, nil
end

function tokenlist:nextTokIsType(typ)
    if self.pos > #self then return false end
    local t = self:peek()
    return t[2] == typ
end

---@return boolean true if the next token is the provided type.
function tokenlist:skipType(typ)
    if self.pos > #self then return false end
    local t = self:peek()
    if t[2] == typ then
        self:read()
        return true
    end
end

---@param str string
---@return tokenlist?
---@return string?
function M.string_to_tokenlist(str)
    if str == nil then return {} end
    local tokens = tokenlist:new()
    local nextrune
    local eof
    local runes = split_chars(str)
    while true do
        local r
        r, eof = read_rune(runes)
        if eof then break end
        if '0' <= r and r <= '9' then
            unread_rune(runes)
            local num
            num = get_num(runes)
            if num then
                tokens[#tokens + 1] = { num, "tokNumber" }
            end
        elseif r == '.' then
            nextrune, eof = read_rune(runes)
            if eof then
                tokens[#tokens + 1] = { '.', "tokOperator" }
                break
            end
            if '0' <= nextrune and nextrune <= '9' then
                unread_rune(runes)
                unread_rune(runes)
                local num
                num = get_num(runes)
                tokens[#tokens + 1] = { num, "tokNumber" }
            else
                unread_rune(runes)
                tokens[#tokens + 1] = { '.', "tokOperator" }
            end
        elseif r == '+' or r == '-' or r == '*' or r == '?' or r == '@' or r == '|' or r == '=' then
            tokens[#tokens + 1] = { r, "tokOperator" }
        elseif r == "," then
            tokens[#tokens + 1] = { r, "tokComma" }
        elseif r == '>' or r == '<' then
            nextrune, eof = read_rune(runes)
            if eof then break end
            if nextrune == '=' or nextrune == r then
                tokens[#tokens + 1] = { r .. r, "tokOperator" }
            else
                tokens[#tokens + 1] = { r, "tokOperator" }
                unread_rune(runes)
            end
        elseif r == '!' then
            nextrune, eof = read_rune(runes)
            if eof then break end
            if nextrune == '=' then
                tokens[#tokens + 1] = { "!=", "tokOperator" }
            else
                return nil, string.format("= expected after !, got %s", nextrune)
            end
        elseif r == '/' or r == ':' then
            nextrune, eof = read_rune(runes)
            if eof then
                tokens[#tokens + 1] = { r, "tokOperator" }
                break
            end
            if nextrune == r then
                tokens[#tokens + 1] = { r .. r, "tokOperator" }
            else
                tokens[#tokens + 1] = { r, "tokOperator" }
                unread_rune(runes)
            end
        elseif r == '[' then
            tokens[#tokens + 1] = { r, "tokOpenBracket" }
        elseif r == ']' then
            tokens[#tokens + 1] = { r, "tokCloseBracket" }
        elseif r == '$' then
            local name
            name = get_qname(runes)
            tokens[#tokens + 1] = { name, "tokVarname" }
        elseif is_space(r) then
            -- ignore whitespace
        elseif is_letter(r) then
            unread_rune(runes)
            local name
            name = get_qname(runes)
            nextrune, eof = read_rune(runes)
            if eof then
                tokens[#tokens + 1] = { name, "tokQName" }
                break
            end
            if nextrune == ':' then
                tokens[#tokens + 1] = { string.sub(name, 1, -2), "tokDoubleColon" }
            else
                unread_rune(runes)
                tokens[#tokens + 1] = { name, "tokQName" }
            end
        elseif r == '"' or r == "'" then
            unread_rune(runes)
            str = get_delimited_string(runes)
            tokens[#tokens + 1] = { str, "tokString" }
        elseif r == '(' then
            nextrune, eof = read_rune(runes)
            if eof then
                return tokens, "parse error, unbalanced ( at end"
            end
            if nextrune == ':' then
                get_comment(runes)
            else
                unread_rune(runes)
                tokens[#tokens + 1] = { "(", "tokOpenParen" }
            end
        elseif r == ')' then
            tokens[#tokens + 1] = { ")", "tokCloseParen" }
        else
            return nil, string.format("Invalid char for xpath expression %q", r)
        end
    end
    return tokens
end

--------------------------
local function number_value(sequence)
    if type(sequence) == "number" then
        return sequence
    end
    if not sequence then
        return nil, "empty sequence"
    end
    if #sequence == 0 then
        return nil, "empty sequence"
    end
    if #sequence > 1 then
        return nil, "number value, # must be 1"
    end
    return tonumber(sequence[1]), nil
end

local function boolean_value(seq)
    if #seq == 0 then return false, nil end
    if #seq > 1 then return false, "invalid argument for boolean value" end
    local val = seq[1]
    local ok = false
    if type(val) == "string" then
        ok = (val ~= "")
    elseif type(val) == "number" then
        ok = (val ~= 0 and val == val)
    elseif type(val) == "boolean" then
        ok = val
    end
    return ok, nil
end

local function string_value(seq)
    local ret = {}
    if type(seq) == "string" then return seq end
    for _, itm in ipairs(seq) do
        if tonumber(itm) and itm ~= itm then
            ret[#ret + 1] = 'NaN'
        elseif type(itm) == "table" and itm[".__type"] == "element" then
            for _, cld in ipairs(itm) do
                ret[#ret + 1] = string_value(cld)
            end
        elseif type(itm) == "table" and itm[".__type"] == "attribute" then
            ret[#ret+1] = itm.value
        else
            ret[#ret + 1] = tostring(itm)
        end
    end
    return table.concat(ret)
end

local function docomparestring(op, left, right)
    if op == "=" then
        return left == right, nil
    elseif op == "!=" then
        return left ~= right, nil
    elseif op == "<" then
        return left < right, nil
    elseif op == ">" then
        return left > right, nil
    elseif op == "<=" then
        return left <= right, nil
    elseif op == ">=" then
        return left >= right, nil
    else
        return nil, "not implemented: op " .. op
    end
end


local function docomparenumber(op, left, right)
    if op == "=" then
        return left == right, nil
    elseif op == "!=" then
        return left ~= right, nil
    elseif op == "<" then
        return left < right, nil
    elseif op == ">" then
        return left > right, nil
    elseif op == "<=" then
        return left <= right, nil
    elseif op == ">=" then
        return left >= right, nil
    else
        return nil, "not implemented: op " .. op
    end
end

local function docomparefunc(op, leftitem, rightitem)
    if type(leftitem) == "number" or type(rightitem) == "number" then
        local x, err = docomparenumber(op, tonumber(leftitem), tonumber(rightitem))
        return x, err
    elseif type(leftitem) == "string" or type(rightitem) == "string" then
        local x, err = docomparestring(op, tostring(leftitem), tostring(rightitem))
        return x, err
    end
end

local function docompare(op, lhs, rhs)
    local evaler = function(ctx)
        local left, right, err, ok
        left, err = lhs(ctx)
        if err ~= nil then return nil, err end
        right, err = rhs(ctx)
        if err ~= nil then return nil, err end
        for _, leftitem in ipairs(left) do
            for _, rightitem in ipairs(right) do
                ok, err = docomparefunc(op, leftitem, rightitem)
                if err ~= nil then return nil, err end
                if ok then return { true }, nil end
            end
        end

        return { false }, nil
    end
    return evaler, nil
end

local function fnAbs(cts,seq)
    local firstarg = seq[1]
    local n, err = number_value(firstarg)
    if not n or err then return nil, err end
    return { math.abs(n)},nil
end

local function fnBoolean(cts,seq)
    local firstarg = seq[1]
    local tf, err = boolean_value(firstarg)
    if tf == nil or err then return nil, err end
    return { tf },nil
end

local function fnCeiling(cts,seq)
    local n, err = number_value(seq[1])
    if err then return err end
    if n == nil then return {nan},nil end
    return { math.ceil(n) },nil
end

local function fnConcat(ctx, seq)
    local ret = {}
    for _, itm in ipairs(seq) do
        ret[#ret + 1] = string_value(itm)
    end
    return { table.concat(ret) }
end

local function fnCodepointsToString(ctx,seq)
    local firstarg = seq[1]
    local ret = {}
    for _, itm in ipairs(firstarg) do
        local n,err = number_value(itm)
        if err then
            return nil, err
        end
        ret[#ret+1] = utf8.char(n)
    end

    return {table.concat(ret)}, nil
end

local function fnContains(ctx, seq)
    local firstarg = string_value(seq[1])
    local secondarg = string_value(seq[2])
    local x = string.find(firstarg, secondarg, 1, true)
    return { x ~= nil }, nil
end

local function fnCount(ctx, seq)
    local firstarg = seq[1]
    return { #firstarg }, nil
end

local function fnFalse(ctx, seq)
    return { false }, nil
end

local function fnFloor(cts,seq)
    local n, err = number_value(seq[1])
    if err then return err end
    if n == nil then return {nan},nil end
    return { math.floor(n) },nil
end

local function fnLocalName(ctx, seq)
    local input_seq = ctx.sequence
    if #seq == 1 then
        input_seq = seq[1]
    end
    -- first item
    seq = input_seq
    if #seq == 0 then
        return { "" }, nil
    end
    if #seq > 1 then
        return {}, "sequence too long"
    end
    -- first element
    seq = seq[1]

    if type(seq) == "table" and seq[".__type"] == "element" then
        return { seq[".__local_name"] }, nil
    end

    return { "" }, nil
end

-- Not unicode aware!
local function fnLowerCase(ctx, seq)
    local firstarg = seq[1]
    local x = string_value(firstarg)
    return { string.lower(x) }, nil
end


local function fnMax(ctx, seq)
    local firstarg = seq[1]
    local x
    for _, itm in ipairs(firstarg) do
        if not x then
            x = number_value({ itm })
        else
            local y = number_value({ itm })
            if y > x then x = y end
        end
    end
    return { x }, nil
end

local function fnMin(ctx, seq)
    local firstarg = seq[1]
    local x
    for _, itm in ipairs(firstarg) do
        if not x then
            x = number_value({ itm })
        else
            local y = number_value({ itm })
            if y < x then x = y end
        end
    end
    return { x }, nil
end

local function fnNormalizeSpace(ctx, seq)
    local firstarg = seq[1]
    local x = string_value(firstarg)
    x = x:gsub("^%s+", "")
    x = x:gsub("%s+$", "")
    x = x:gsub("%s+", " ")
    return { x }, nil
end

local function fnNot(ctx, seq)
    local firstarg = seq[1]
    local x, err = boolean_value(firstarg)
    if err then
        return {}, err
    end
    return { not x }, nil
end

local function fnNumber(ctx, seq)
    local x = number_value(seq[1])
    if not x then return { nan }, nil end
    return { x }, nil
end

local function fnReverse(ctx, seq)
    local firstarg = seq[1]
    local ret = {}
    for i = #firstarg, 1, -1 do
        ret[#ret + 1] = firstarg[i]
    end
    return ret, nil
end

local function fnRound(ctx, seq)
    local firstarg = seq[1]
    if #firstarg == 0 then
        return {}, nil
    end
    local n, err = number_value(firstarg)
    if err then
        return nil, err
    end
    return { math.floor(n + 0.5) }, nil
end

local function fnString(ctx, seq)
    local input_seq = ctx.sequence
    if #seq == 1 then
        input_seq = seq[1]
    end
    -- first item
    seq = input_seq
    local x = string_value(seq)
    return { x }, nil
end

local function fnStringJoin(ctx, seq)
    local firstarg = seq[1]
    local secondarg = seq[2]
    if #secondarg ~= 1 then
        return nil, "string-join: second argument should be a string"
    end
    local tab = {}

    for _, itm in ipairs(firstarg) do
        local str = string_value(itm)
        tab[#tab + 1] = str
    end
    return { table.concat(tab, string_value(secondarg[1])) }, nil
end

local function fnStringLength(ctx, seq)
    local firstarg = seq[1]
    local x = string_value(firstarg)
    return { utf8.len(x) }, nil
end

local function fnStringToCodepoints(ctx,seq)
    local str = string_value(seq[1])
    local ret = {}
    for _, c in utf8.codes(str) do
        ret[#ret+1] = c
    end
    return ret, nil
end

local function fnSubstring(ctx, seq)
    local str = string_value(seq[1])
    local pos, err = number_value(seq[2])
    if err then
        return nil, err
    end
    local len = #str
    if #seq > 2 then
        len = number_value(seq[3])
    end
    local ret = {}
    local l = 0
    for i, c in utf8.codes(str) do
        if i >= pos and l < len then
            ret[#ret + 1] = utf8.char(c)
            l = l + 1
        end
    end

    return { table.concat(ret) }, nil
end

local function fnTrue(ctx, seq)
    return { true }, nil
end

-- Not unicode aware!
local function fnUpperCase(ctx, seq)
    local firstarg = seq[1]
    local x = string_value(firstarg)
    return { string.upper(x) }, nil
end

local funcs = {
    -- function name, namespace, function, minarg, maxarg
    { "abs",                  M.fnNS, fnAbs,                1, 1 },
    { "boolean",              M.fnNS, fnBoolean,            1, 1 },
    { "ceiling",              M.fnNS, fnCeiling,            1, 1 },
    { "codepoints-to-string", M.fnNS, fnCodepointsToString, 1, 1 },
    { "concat",               M.fnNS, fnConcat,             0, -1 },
    { "contains",             M.fnNS, fnContains,           2, 2 },
    { "count",                M.fnNS, fnCount,              1, 1 },
    { "false",                M.fnNS, fnFalse,              0, 0 },
    { "floor",                M.fnNS, fnFloor,              1, 1 },
    { "local-name",           M.fnNS, fnLocalName,          0, 1 },
    { "lower-case",           M.fnNS, fnLowerCase,          1, 1 },
    { "max",                  M.fnNS, fnMax,                1, 1 },
    { "min",                  M.fnNS, fnMin,                1, 1 },
    { "normalize-space",      M.fnNS, fnNormalizeSpace,     1, 1 },
    { "not",                  M.fnNS, fnNot,                1, 1 },
    { "number",               M.fnNS, fnNumber,             1, 1 },
    { "reverse",              M.fnNS, fnReverse,            1, 1 },
    { "round",                M.fnNS, fnRound,              1, 1 },
    { "string-join",          M.fnNS, fnStringJoin,         2, 2 },
    { "string-length",        M.fnNS, fnStringLength,       1, 1 },
    { "string-to-codepoints", M.fnNS, fnStringToCodepoints, 1, 1 },
    { "string",               M.fnNS, fnString,             1, 1 },
    { "substring",            M.fnNS, fnSubstring,          2, 3 },
    { "true",                 M.fnNS, fnTrue,               0, 0 },
    { "upper-case",           M.fnNS, fnUpperCase,          1, 1 },
}

local function registerFunction(func)
    M.funcs[func[2] .. " " .. func[1]] = func
end

for _, func in ipairs(funcs) do
    registerFunction(func)
end

M.registerFunction = registerFunction

local function getFunction(namespace, fname)
    return M.funcs[namespace .. " " .. fname]
end

local function callFunction(fname, seq, ctx)
    local fn = {}
    for str in string.gmatch(fname, "([^:]+)") do
        table.insert(fn, str)
    end
    local namespace = M.fnNS
    if #fn == 2 then
        namespace = ctx.namespaces[fn[1]]
        fname = fn[2]
    end
    local func = getFunction(namespace, fname)
    if func then
        return func[3](ctx, seq)
    end

    return {}, "Could not find function " .. fname .. " with name space " .. namespace
end


local function filter(ctx, f)
    local res = {}
    local predicate, err = f(ctx)
    if err then
        return nil, err
    end

    if #predicate == 1 then
        local idx = tonumber(predicate[1])
        if idx then
            if #ctx.sequence >= idx then
                return { ctx.sequence[idx] }, nil
            else
                return {}, nil
            end
        end
    end

    local copysequence = ctx.sequence
    for _, itm in ipairs(copysequence) do
        ctx.sequence = { itm }
        ctx.pos = 1
        predicate, err = f(ctx)
        if err then
            return nil, err
        end
        if boolean_value(predicate) then
            res[#res + 1] = itm
        end
    end
    ctx.sequence = res
    return res, nil
end


-------------------------

---@class context
---@field sequence table
---@field xmldoc table
---@field namespaces table
---@field vars table
local context = {}

function context:new(o)
    o = o or {} -- create object if user does not provide one
    setmetatable(o, self)
    self.__index = self
    return o
end

---@alias xmlelement table

---@return xmlelement?
---@return string? Error message
function context:root()
    for _, elt in ipairs(self.xmldoc) do
        if type(elt) == "table" then
            self.sequence = { elt }
            return elt, nil
        end
    end
    return nil, "no root element found"
end

function context:attributeaixs()
    local seq = {}
    for _, itm in ipairs(self.sequence) do
        if type(itm) == "table" and itm[".__type"] == "element" then
            for key, value in pairs(itm[".__attributes"]) do
                local x = {
                    name = key,
                    value = value,
                    [".__type"] = "attribute",
                }
                seq[#seq+1] = x
            end
        end
    end
    self.sequence = seq
    return seq, nil
end

function context:childaxis()
    local seq = {}
    for _, elt in ipairs(self.sequence) do
        if type(elt) == "table" then
            if elt[".__type"] and elt[".__type"] == "element" then
                for _, cld in ipairs(elt) do
                    seq[#seq + 1] = cld
                end
            elseif elt[".__type"] and elt[".__type"] == "document" then
                for _, cld in ipairs(elt) do
                    seq[#seq + 1] = cld
                end
            else
                assert(false, "table, not element")
            end
        elseif type(elt) == "string" then
            seq[#seq + 1] = elt
        else
            print("something else", type)
        end
    end
    self.sequence = seq
    return seq, nil
end

M.context = context
-------------------------

---@param tl tokenlist
---@param step string
local function enterStep(tl, step)
    if M.dodebug then
        local token, eof = tl:peek()
        if eof then return end
        token = token or { "-", "-" }
        print(string.format("%s%s: {%s,%s}", string.rep(M.debugindent, debuglevel), step, tostring(token[1]), token[2]))
        debuglevel = debuglevel + 1
    end
end

---@param tl tokenlist
---@param step string
local function leaveStep(tl, step)
    if M.dodebug then
        local token, _ = tl:peek()
        token = token or { "-", "-" }
        debuglevel = debuglevel - 1
        print(string.format("%s%s: {%s,%s}", string.rep(M.debugindent, debuglevel), step, tostring(token[1]), token[2]))
    end
end

---------------------------

local parse_expr, parse_expr_single, parse_or_expr, parse_and_expr, parse_comparison_expr, parse_range_expr, parse_additive_expr, parse_multiplicative_expr

---@type table sequence


---@alias evalfunc function(context) sequence?, string?
---@alias testfunc function(context) boolean?, string?

---@param tl tokenlist
---@return evalfunc?
---@return string? error
-- [2] Expr ::= ExprSingle ("," ExprSingle)*
function parse_expr(tl)
    enterStep(tl, "2 parseExpr")
    local efs = {}
    while true do
        local ef, err = parse_expr_single(tl)
        if err ~= nil then
            leaveStep(tl, "2 parseExpr")
            return nil, err
        end
        efs[#efs + 1] = ef
        if not tl:nextTokIsType("tokComma") then
            break
        end
        tl:read()
    end
    if #efs == 1 then
        leaveStep(tl, "2 parseExpr")
        return efs[1], nil
    end
    local evaler = function(ctx)
        local ret = {}
        local seq
        for _, ef in ipairs(efs) do
            seq, err = ef(ctx)
            if err then
                return nil, err
            end
            for _, itm in ipairs(seq) do
                ret[#ret + 1] = itm
            end
        end
        return ret, nil
    end

    leaveStep(tl, "2 parseExpr")
    return evaler, nil
end

-- [3] ExprSingle ::= ForExpr | QuantifiedExpr | IfExpr | OrExpr
--
---@param tl tokenlist
---@return evalfunc?
---@return string? error
function parse_expr_single(tl)
    enterStep(tl, "3 parse_expr_single")
    local efs = {}
    local ef, err = parse_or_expr(tl)
    if err ~= nil then
        leaveStep(tl, "3 parse_expr_single")
        return nil, err
    end
    leaveStep(tl, "3 parse_expr_single")
    return ef, nil
end

-- [8] OrExpr ::= AndExpr ( "or" AndExpr )*
--
---@param tl tokenlist
---@return evalfunc?
---@return string? error
function parse_or_expr(tl)
    enterStep(tl, "8 parse_or_expr")
    local err
    local efs = {}
    while true do
        efs[#efs + 1], err = parse_and_expr(tl)
        if err ~= nil then
            leaveStep(tl, "8 parse_or_expr")
            return nil, err
        end
        if not tl:readNexttokIfIsOneOfValue({ "or" }) then
            break
        end
    end
    if #efs == 1 then
        leaveStep(tl, "8 parse_or_expr")
        return efs[1], nil
    end

    local evaler = function(ctx)
        local seq, err
        for _, ef in ipairs(efs) do
            seq, err = ef(ctx)
            if err ~= nil then
                return nil, err
            end
            local bv
            bv, err = boolean_value(seq)
            if err ~= nil then
                return nil, err
            end
            if bv then return { true }, nil end
        end
        return { false }, nil
    end
    leaveStep(tl, "8 parse_or_expr")
    return evaler, nil
end

-- [9] AndExpr ::= ComparisonExpr ( "and" ComparisonExpr )*
--
---@param tl tokenlist
---@return evalfunc?
---@return string? error
function parse_and_expr(tl)
    enterStep(tl, "9 parse_and_expr")
    local ef, err = parse_comparison_expr(tl)
    if err ~= nil then
        leaveStep(tl, "8 parse_or_expr")
        return nil, err
    end
    leaveStep(tl, "9 parse_and_expr")
    return ef, nil
end

-- [10] ComparisonExpr ::= RangeExpr ( (ValueComp | GeneralComp| NodeComp) RangeExpr )?
--
---@param tl tokenlist
---@return evalfunc?
---@return string? error
function parse_comparison_expr(tl)
    enterStep(tl, "10 parse_comparison_expr")
    local lhs, err = parse_range_expr(tl)
    if err ~= nil then
        leaveStep(tl, "10 parse_comparison_expr")
        return nil, err
    end
    local op
    op, err = tl:readNexttokIfIsOneOfValue({ "=", "<", ">", "<=", ">=", "!=", "eq", "ne", "lt", "le", "gt", "ge", "is",
        "<<", ">>" })
    if err ~= nil then
        leaveStep(tl, "10 parse_comparison_expr")
        return nil, err
    end
    if not op then
        leaveStep(tl, "10 parse_comparison_expr")
        return lhs, nil
    end

    local rhs
    rhs, err = parse_range_expr(tl)
    if err ~= nil then
        leaveStep(tl, "10 parse_comparison_expr")
        return nil, err
    end

    leaveStep(tl, "10 parse_comparison_expr")
    return docompare(op[1], lhs, rhs)
end

-- [11] RangeExpr  ::=  AdditiveExpr ( "to" AdditiveExpr )?
--
---@param tl tokenlist
---@return evalfunc?
---@return string? error
function parse_range_expr(tl)
    enterStep(tl, "11 parse_range_expr")
    local ef, err = parse_additive_expr(tl)
    if err ~= nil then
        leaveStep(tl, "11 parse_range_expr")
        return nil, err
    end

    leaveStep(tl, "11 parse_range_expr")
    return ef, nil
end

-- [12] AdditiveExpr ::= MultiplicativeExpr ( ("+" | "-") MultiplicativeExpr )*
--
---@param tl tokenlist
---@return evalfunc?
---@return string? error
function parse_additive_expr(tl)
    enterStep(tl, "12 parse_additive_expr")
    local efs = {}
    local operators = {}
    while true do
        local ef, err = parse_multiplicative_expr(tl)
        if err ~= nil then
            leaveStep(tl, "12 parse_additive_expr")
            return nil, err
        end
        efs[#efs + 1] = ef
        local op
        op, err = tl:readNexttokIfIsOneOfValue({ "+", "-" })
        if err ~= nil then
            leaveStep(tl, "12 parse_additive_expr")
            return nil, err
        end
        if not op then break end
        operators[#operators + 1] = op[1]
    end
    if #efs == 1 then
        leaveStep(tl, "12 parse_additive_expr (#efs == 1)")
        return efs[1], nil
    end

    local evaler = function(ctx)
        local s0, err = efs[1](ctx)
        if err ~= nil then return nil, err end
        local sum
        sum, err = number_value(s0)
        if err ~= nil then return nil, err end
        for i = 2, #efs do
            s0, err = efs[i](ctx)
            if err ~= nil then return nil, err end
            local val
            val, err = number_value(s0)
            if err ~= nil then return nil, err end

            if operators[i - 1] == "+" then
                sum = sum + val
            else
                sum = sum - val
            end
        end
        return { sum }, nil
    end
    leaveStep(tl, "12 parse_additive_expr")
    return evaler, nil
end

-- [13] MultiplicativeExpr ::=  UnionExpr ( ("*" | "div" | "idiv" | "mod") UnionExpr )*
--
---@param tl tokenlist
---@return evalfunc?
---@return string? error
function parse_multiplicative_expr(tl)
    enterStep(tl, "13 parse_multiplicative_expr")

    local efs = {}
    local operators = {}
    while true do
        local ef, err = parse_union_expr(tl)
        if err ~= nil then
            leaveStep(tl, "13 parse_multiplicative_expr (ue err)")
            return nil, err
        end
        efs[#efs + 1] = ef
        local op
        op, err = tl:readNexttokIfIsOneOfValue({ "*", "mod", "div", "idiv" })
        if err ~= nil then
            leaveStep(tl, "13 parse_multiplicative_expr")
            return nil, err
        end
        if not op then break end
        operators[#operators + 1] = op[1]
    end
    if #efs == 1 then
        leaveStep(tl, "13 parse_multiplicative_expr #efs 1")
        return efs[1], nil
    end

    local evaler = function(ctx)
        local s0, err = efs[1](ctx)
        if err ~= nil then return nil, err end
        local result
        result, err = number_value(s0)
        if err ~= nil then return nil, err end
        if not result then return nil, "number expected" end
        for i = 2, #efs do
            s0, err = efs[i](ctx)
            if err ~= nil then return nil, err end
            local val
            val, err = number_value(s0)
            if err ~= nil then return nil, err end

            if operators[i - 1] == "*" then
                result = result * val
            elseif operators[i - 1] == "div" then
                result = result / val
            elseif operators[i - 1] == "idiv" then
                local d = result / val
                local sign = 1
                if d < 0 then sign = -1 end
                result = math.floor(math.abs(d)) * sign
            elseif operators[i - 1] == "mod" then
                result = result % val
            else
                return nil, "unknown operator in mult expression"
            end
        end
        return { result }, nil
    end

    leaveStep(tl, "13 parse_multiplicative_expr (leave)")
    return evaler, nil
end

-- [14] UnionExpr ::= IntersectExceptExpr ( ("union" | "|") IntersectExceptExpr )*
--
---@param tl tokenlist
---@return evalfunc?
---@return string? error
function parse_union_expr(tl)
    enterStep(tl, "14 parse_union_expr")
    local ef, err = parse_intersect_except_expr(tl)
    if err ~= nil then
        leaveStep(tl, "14 parse_union_expr")
        return nil, err
    end
    leaveStep(tl, "14 parse_union_expr")
    return ef, nil
end

-- [15] IntersectExceptExpr  ::= InstanceofExpr ( ("intersect" | "except") InstanceofExpr )*
--
---@param tl tokenlist
---@return evalfunc?
---@return string? error
function parse_intersect_except_expr(tl)
    enterStep(tl, "15 parse_intersect_except_expr")
    local ef, err = parse_instance_of_expr(tl)
    if err ~= nil then
        leaveStep(tl, "15 parse_intersect_except_expr")
        return nil, err
    end
    leaveStep(tl, "15 parse_intersect_except_expr")
    return ef, nil
end

-- [16] InstanceofExpr ::= TreatExpr ( "instance" "of" SequenceType )?
--
---@param tl tokenlist
---@return evalfunc?
---@return string? error
function parse_instance_of_expr(tl)
    enterStep(tl, "16 parse_instance_of_expr")
    local ef, err = parse_treat_expr(tl)
    if err ~= nil then
        leaveStep(tl, "16 parse_instance_of_expr")
        return nil, err
    end
    leaveStep(tl, "16 parse_instance_of_expr")
    return ef, nil
end

-- [17] TreatExpr ::= CastableExpr ( "treat" "as" SequenceType )?
--
---@param tl tokenlist
---@return evalfunc?
---@return string? error
function parse_treat_expr(tl)
    enterStep(tl, "17 parse_treat_expr")
    local ef, err = parse_castable_expr(tl)
    if err ~= nil then
        leaveStep(tl, "17 parse_treat_expr")
        return nil, err
    end
    leaveStep(tl, "17 parse_treat_expr")
    return ef, nil
end

-- [18] CastableExpr ::= CastExpr ( "castable" "as" SingleType )?
--
---@param tl tokenlist
---@return evalfunc?
---@return string? error
function parse_castable_expr(tl)
    enterStep(tl, "18 parse_castable_expr")
    local ef, err = parse_cast_expr(tl)
    if err ~= nil then
        leaveStep(tl, "18 parse_castable_expr")
        return nil, err
    end
    leaveStep(tl, "18 parse_castable_expr")
    return ef, nil
end

-- [19] CastExpr ::= UnaryExpr ( "cast" "as" SingleType )?
--
---@param tl tokenlist
---@return evalfunc?
---@return string? error
function parse_cast_expr(tl)
    enterStep(tl, "19 parse_cast_expr")
    local ef, err = parse_unary_expr(tl)
    if err ~= nil then
        leaveStep(tl, "19 parse_cast_expr")
        return nil, err
    end
    leaveStep(tl, "19 parse_cast_expr")
    return ef, nil
end

-- [20] UnaryExpr ::= ("-" | "+")* ValueExpr
--
---@param tl tokenlist
---@return evalfunc?
---@return string? error
function parse_unary_expr(tl)
    enterStep(tl, "20 parse_unary_expr")
    local mult = 1
    while true do
        local tok, err = tl:readNexttokIfIsOneOfValue({ "+", "-" })
        if err ~= nil then
            leaveStep(tl, "20 parse_unary_expr (err)")
            return nil, err
        end
        if tok == nil then
            break
        end
        if tok[1] == "-" then mult = mult * -1 end
    end

    local ef, err = parse_value_expr(tl)
    if err ~= nil then
        leaveStep(tl, "20 parse_unary_expr")
        return nil, err
    end
    if ef == nil then
        leaveStep(tl, "20 parse_unary_expr (nil ef)")
        return function() return {}, nil end, nil
    end

    local evaler = function(ctx)
        if mult == -1 then
            local seq, err = ef(ctx)
            if err ~= nil then
                return nil, err
            end
            flt, err = number_value(seq)
            if err ~= nil then
                return nil, err
            end
            return { flt * -1 }, nil
        end
        return ef(ctx)
    end
    leaveStep(tl, "20 parse_unary_expr")
    return evaler, nil
end

-- [21] ValueExpr ::= PathExpr
--
---@param tl tokenlist
---@return evalfunc?
---@return string? error
function parse_value_expr(tl)
    enterStep(tl, "21 parse_value_expr")
    local ef, err = parse_path_expr(tl)
    if err ~= nil then
        leaveStep(tl, "21 parse_value_expr")
        return nil, err
    end
    leaveStep(tl, "21 parse_value_expr")
    return ef, nil
end

-- [25] PathExpr ::= ("/" RelativePathExpr?) | ("//" RelativePathExpr) | RelativePathExpr
--
---@param tl tokenlist
---@return evalfunc?
---@return string? error
function parse_path_expr(tl)
    enterStep(tl, "25 parse_path_expr")

    local op = tl:readNexttokIfIsOneOfValue({ "/", "//" })
    local ef, err = parse_relative_path_expr(tl)
    if err ~= nil then
        leaveStep(tl, "25 parse_path_expr")
        return nil, err
    end
    if op then
        if op[1] == "/" then
            -- print("/")
        else
            assert(false, "nyi")
        end
    end

    leaveStep(tl, "25 parse_path_expr")
    return ef, nil
end

-- [26] RelativePathExpr ::= StepExpr (("/" | "//") StepExpr)*
--
---@param tl tokenlist
---@return evalfunc?
---@return string? error
function parse_relative_path_expr(tl)
    enterStep(tl, "26 parse_relative_path_expr")
    local efs = {}
    while true do
        local ef, err = parse_step_expr(tl)
        if err ~= nil then
            leaveStep(tl, "26 parse_relative_path_expr")
            return nil, err
        end
        efs[#efs + 1] = ef
        if not tl:readNexttokIfIsOneOfValue { "/", "//" } then
            break
        end
    end
    if #efs == 1 then
        leaveStep(tl, "26 parse_relative_path_expr #efs1")
        return efs[1], nil
    end
    local evaler = function(ctx)
        local retseq
        for i = 1, #efs do
            retseq = {}
            local copysequence = ctx.sequence
            local ef = efs[i]
            for _, itm in ipairs(copysequence) do
                ctx.sequence = { itm }
                local seq, err = ef(ctx)
                if err then
                    return nil, err
                end
                for _, val in ipairs(seq) do
                    retseq[#retseq + 1] = val
                end
            end
            ctx.sequence = retseq
        end
        return retseq, nil
    end
    leaveStep(tl, "26 parse_relative_path_expr (last)")
    return evaler, nil
end

-- [27] StepExpr := FilterExpr | AxisStep
--
---@param tl tokenlist
---@return evalfunc?
---@return string? error
function parse_step_expr(tl)
    enterStep(tl, "27 parse_step_expr")
    local ef, err = parse_filter_expr(tl)
    if err ~= nil then
        leaveStep(tl, "27 parse_step_expr (err nil)")
        return nil, err
    end
    if not ef then
        ef, err = parse_axis_step(tl)
        if err ~= nil then
            leaveStep(tl, "27 parse_step_expr")
            return nil, err
        end
    end
    leaveStep(tl, "27 parse_step_expr (leave)")
    return ef, nil
end

-- [28] AxisStep ::= (ReverseStep | ForwardStep) PredicateList
-- [39] PredicateList ::= Predicate*
--
---@param tl tokenlist
---@return evalfunc?
---@return string? error
function parse_axis_step(tl)
    enterStep(tl, "28 parse_axis_step")
    local err = nil
    local ef
    ef, err = parse_forward_step(tl)
    if err ~= nil then
        leaveStep(tl, "28 parse_axis_step")
        return nil, err
    end
    leaveStep(tl, "28 parse_axis_step")
    return ef, nil
end

-- [29] ForwardStep ::= (ForwardAxis NodeTest) | AbbrevForwardStep
-- [31] AbbrevForwardStep ::= "@"? NodeTest
--
---@param tl tokenlist
---@return evalfunc?
---@return string? error
function parse_forward_step(tl)
    enterStep(tl, "29 parse_forward_step")
    local err = nil
    local tf
    local axisChild, axisAttribute = 1, 2
    local stepAxis = axisChild

    if tl:readNexttokIfIsOneOfValue({"@"}) then
        tl.attributeMode = true
        stepAxis = axisAttribute
    else
        tl.attributeMode = false
    end

    tf, err = parse_node_test(tl)
    if err then
        leaveStep(tl, "29 parse_forward_step")
        return nil, err
    end
    if not tf then
        leaveStep(tl, "29 parse_forward_step (nil)")
        return nil, nil
    end
    local evaler = function(ctx)
        if stepAxis == axisChild then
            ctx:childaxis()
        else
            ctx:attributeaixs()
        end
        if not tf then return nil, nil end
        local ret = {}
        for _, itm in ipairs(ctx.sequence) do
            if tf(itm) then
                ret[#ret + 1] = itm
            end
        end
        return ret, nil
    end

    leaveStep(tl, "29 parse_forward_step")

    return evaler, nil
end

-- [35] NodeTest ::= KindTest | NameTest
--
---@param tl tokenlist
---@return evalfunc?
---@return string? error
function parse_node_test(tl)
    enterStep(tl, "35 parse_node_test")
    local tf, err
    tf, err = parse_name_test(tl)
    if err then
        leaveStep(tl, "35 parse_node_test")
        return nil, err
    end
    leaveStep(tl, "35 parse_node_test")
    return tf, nil
end

-- [36] NameTest ::= QName | Wildcard
--
---@param tl tokenlist
---@return evalfunc?
---@return string? error
function parse_name_test(tl)
    enterStep(tl, "36 parse_name_test")
    local tf
    if tl:nextTokIsType("tokQName") then
        local n, err = tl:read()
        if err then
            leaveStep(tl, "36 parse_name_test")
            return nil, err
        end
        if not n then
            return nil, "qname should not be empty"
        end
        if tl.attributeMode then
            tf = function (itm)
                return itm.name == n[1]
            end
        else
            tf = function(itm)
                if type(itm) == "table" and itm[".__type"] == "element" then
                    return itm[".__name"] == n[1]
                end
                return false
            end
        end
    end
    leaveStep(tl, "36 parse_name_test")
    return tf, nil
end

-- [38] FilterExpr ::= PrimaryExpr PredicateList
-- [39] PredicateList ::= Predicate*
--
---@param tl tokenlist
---@return evalfunc?
---@return string? error
function parse_filter_expr(tl)
    enterStep(tl, "38 parse_filter_expr")
    local ef, err = parse_primary_expr(tl)
    if err ~= nil then
        leaveStep(tl, "38 parse_filter_expr")
        return nil, err
    end
    while true do
        if tl:nextTokIsType("tokOpenBracket") then
            tl:read()
            local f, err = parse_expr(tl)
            if err ~= nil then
                leaveStep(tl, "38 parse_filter_expr")
                return nil, err
            end
            if not tl:skipType("tokCloseBracket") then
                leaveStep(tl, "38 parse_filter_expr")
                return nil, "] expected"
            end
            local filterfunc = function(ctx)
                local seq, err = ef(ctx)
                if err then
                    return nil, err
                end

                ctx.sequence = seq
                return filter(ctx, f)
            end
            leaveStep(tl, "38 parse_filter_expr")
            return filterfunc, nil
        end
        break
    end
    leaveStep(tl, "38 parse_filter_expr")
    return ef, nil
end

-- [40] Predicate ::= "[" Expr "]"
-- [41] PrimaryExpr ::= Literal | VarRef | ParenthesizedExpr | ContextItemExpr | FunctionCall
function parse_primary_expr(tl)
    enterStep(tl, "41 parse_primary_expr")
    local nexttok, err = tl:read()
    if err ~= nil then
        leaveStep(tl, "41 parse_primary_expr")
        return nil, err
    end

    -- StringLiteral
    if nexttok[2] == "tokString" then
        leaveStep(tl, "41 parse_primary_expr (sl)")
        local evaler = function(ctx)
            return { nexttok[1] }, nil
        end
        return evaler, nil
    end

    -- NumericLiteral
    if nexttok[2] == "tokNumber" then
        leaveStep(tl, "41 parse_primary_expr (nl)")
        local evaler = function(ctx)
            return { nexttok[1] }, nil
        end
        return evaler, nil
    end

    -- ParenthesizedExpr
    if nexttok[2] == "tokOpenParen" then
        local ef, err = parse_parenthesized_expr(tl)
        if err ~= nil then
            leaveStep(tl, "41 parse_primary_expr")
            return nil, err
        end
        leaveStep(tl, "41 parse_primary_expr (op)")
        return ef, nil
    end


    -- VarRef
    if nexttok[2] == "tokVarname" then
        local evaler = function(ctx)
            return { ctx.vars[nexttok[1]] }, nil
        end
        leaveStep(tl, "41 parse_primary_expr (vr)")
        return evaler, nil
    end


    if nexttok[2] == "tokOperator" and nexttok[1] == "." then
        local evaler = function(ctx)
            return ctx.sequence, nil
        end
        leaveStep(tl, "41 parse_primary_expr (ci)")
        return evaler, nil
    end

    -- FunctionCall
    if nexttok[2] == "tokQName" then
        if tl:nextTokIsType("tokOpenParen") then
            tl:unread()
            local ef
            ef, err = parse_function_call(tl)
            if err ~= nil then
                leaveStep(tl, "41 parse_primary_expr: " .. err)
                return nil, err
            end
            leaveStep(tl, "41 parse_primary_expr (fc)")
            return ef, nil
        end
    end
    tl:unread()
    leaveStep(tl, "41 parse_primary_expr (exit)")
    return nil, nil
end

-- [46] ParenthesizedExpr ::= "(" Expr? ")"
--
---@param tl tokenlist
---@return evalfunc?
---@return string? error
function parse_parenthesized_expr(tl)
    enterStep(tl, "46 parse_parenthesized_expr")
    -- shortcut for empty sequence ():
    if tl:nextTokIsType("tokCloseParen") then
        tl:read()
        return function(ctx) return {}, nil end
    end

    local ef, err = parse_expr(tl)
    if err ~= nil then
        leaveStep(tl, "46 parse_parenthesized_expr (err)")
        return nil, err
    end
    if not tl:skipType("tokCloseParen") then
        leaveStep(tl, "46 parse_parenthesized_expr (err)")
        return nil, err
    end
    local evaler = function(ctx)
        local seq, err = ef(ctx)
        if err ~= nil then
            return nil, err
        end
        return seq, nil
    end
    leaveStep(tl, "46 parse_parenthesized_expr")
    return evaler, nil
end

-- [48] FunctionCall ::= QName "(" (ExprSingle ("," ExprSingle)*)? ")"
--
---@param tl tokenlist
---@return evalfunc?
---@return string? error
function parse_function_call(tl)
    enterStep(tl, "48 parse_function_call")
    local function_name_token, err = tl:read()
    if err ~= nil then
        leaveStep(tl, "48 parse_function_call")
        return nil, err
    end
    if function_name_token == nil then
        return nil, "function name token expected"
    end
    tl:skipType("tokOpenParen")
    if tl:nextTokIsType("tokCloseParen") then
        tl:read()
        local evaler = function(ctx)
            local x, y = callFunction(function_name_token[1], {}, ctx)
            return x, y
        end
        leaveStep(tl, "48 parse_function_call")
        return evaler, nil
    end

    local efs = {}
    while true do
        local es
        es, err = parse_expr_single(tl)
        if err ~= nil then
            leaveStep(tl, "48 parse_function_call")
            return nil, err
        end
        efs[#efs + 1] = es
        if not tl:nextTokIsType("tokComma") then
            leaveStep(tl, "48 parse_function_call")
            break
        end
        tl:read()
    end

    if not tl:skipType("tokCloseParen") then
        return nil, ") expected"
    end

    local evaler = function(ctx)
        local arguments = {}
        -- TODO: save context and restore afterwards
        local seq, err
        for _, ef in ipairs(efs) do
            seq, err = ef(ctx)
            if err ~= nil then return nil, err end
            arguments[#arguments + 1] = seq
        end
        return callFunction(function_name_token[1], arguments, ctx)
    end
    leaveStep(tl, "48 parse_function_call")
    return evaler, nil
end

---@param tl tokenlist
---@return evalfunc?
---@return string? error
function M.parse_xpath(tl)
    local evaler, err = parse_expr(tl)
    if err ~= nil then
        return nil, err
    end
    return evaler, nil
end

return M
