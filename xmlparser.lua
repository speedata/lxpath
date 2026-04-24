-- xmlparser.lua — Pure Lua XML parser producing lxpath-compatible tables
-- Parses well-formed XML with namespace support. No DTD/Schema validation.

local M = {}

local function error_at(str, pos, msg)
    local line = 1
    local col = 1
    for i = 1, pos - 1 do
        if str:sub(i, i) == "\n" then
            line = line + 1
            col = 1
        else
            col = col + 1
        end
    end
    error(string.format("XML parse error at line %d, col %d: %s", line, col, msg), 0)
end

-- Resolve entity and character references in text/attribute values
local builtin_entities = {
    amp = "&",
    lt = "<",
    gt = ">",
    quot = '"',
    apos = "'"
}

local function resolve_entities(s, str, pos)
    return s:gsub("&(.-);", function(ref)
        if builtin_entities[ref] then
            return builtin_entities[ref]
        end
        if ref:sub(1, 1) == "#" then
            local num
            if ref:sub(2, 2) == "x" then
                num = tonumber(ref:sub(3), 16)
            else
                num = tonumber(ref:sub(2))
            end
            if num then
                -- UTF-8 encode
                if num < 0x80 then
                    return string.char(num)
                elseif num < 0x800 then
                    return string.char(0xC0 + math.floor(num / 64), 0x80 + num % 64)
                elseif num < 0x10000 then
                    return string.char(
                        0xE0 + math.floor(num / 4096),
                        0x80 + math.floor(num / 64) % 64,
                        0x80 + num % 64)
                elseif num < 0x110000 then
                    return string.char(
                        0xF0 + math.floor(num / 262144),
                        0x80 + math.floor(num / 4096) % 64,
                        0x80 + math.floor(num / 64) % 64,
                        0x80 + num % 64)
                end
            end
        end
        error_at(str, pos, "unknown entity reference: &" .. ref .. ";")
    end)
end

-- Skip whitespace, return new position
local function skip_ws(str, pos)
    local _, e = str:find("^%s+", pos)
    return e and e + 1 or pos
end

-- Check if position starts with a given string
local function starts_with(str, pos, prefix)
    return str:sub(pos, pos + #prefix - 1) == prefix
end

-- Read a quoted attribute value, return value and new position
local function read_attr_value(str, pos)
    local quote = str:sub(pos, pos)
    if quote ~= '"' and quote ~= "'" then
        error_at(str, pos, "expected quote for attribute value")
    end
    local close = str:find(quote, pos + 1, true)
    if not close then
        error_at(str, pos, "unterminated attribute value")
    end
    local raw = str:sub(pos + 1, close - 1)
    return resolve_entities(raw, str, pos), close + 1
end

-- Read a Name (element/attribute name)
-- XML names may contain Unicode letters (UTF-8 multibyte sequences with lead byte >= 0xC0)
local function read_name(str, pos)
    local s, e = str:find("^[%a_%z\xC0-\xFF][%w_.:\x80-\xFF-]*", pos)
    if not s then
        error_at(str, pos, "expected XML name")
    end
    return str:sub(s, e), e + 1
end

-- Split a qualified name into prefix and local part
local function split_qname(name)
    local prefix, local_name = name:match("^([^:]+):(.+)$")
    if prefix then
        return prefix, local_name
    end
    return nil, name
end

-- Resolve a prefix to a namespace URI using the namespace stack
local function resolve_ns(ns_stack, prefix)
    for i = #ns_stack, 1, -1 do
        local bindings = ns_stack[i]
        if bindings[prefix] ~= nil then
            return bindings[prefix]
        end
    end
    if prefix then
        return nil -- unresolved prefix
    end
    return "" -- no prefix, no default namespace = empty
end

-- Collect all active namespace bindings from the stack
local function collect_ns(ns_stack)
    local result = {}
    for i = 1, #ns_stack do
        for k, v in pairs(ns_stack[i]) do
            if k ~= false then -- skip default ns marker (stored as false key)
                result[k] = v
            end
        end
    end
    return result
end

function M.parse(xml_string)
    local str = xml_string
    local pos = 1
    local len = #str
    local id_counter = 0

    local ns_stack = {} -- stack of namespace binding tables

    local function next_id()
        id_counter = id_counter + 1
        return id_counter
    end

    -- Skip XML declaration <?xml ... ?>
    local function skip_xml_decl()
        if starts_with(str, pos, "<?xml") then
            local close = str:find("?>", pos, true)
            if not close then
                error_at(str, pos, "unterminated XML declaration")
            end
            pos = close + 2
        end
    end

    -- Skip comment <!-- ... -->
    local function skip_comment()
        local close = str:find("-->", pos + 4, true)
        if not close then
            error_at(str, pos, "unterminated comment")
        end
        pos = close + 3
    end

    -- Skip processing instruction <? ... ?>
    local function skip_pi()
        local close = str:find("?>", pos + 2, true)
        if not close then
            error_at(str, pos, "unterminated processing instruction")
        end
        pos = close + 2
    end

    -- Skip DOCTYPE declaration
    local function skip_doctype()
        -- Simple: find matching '>'  but handle nested brackets
        local depth = 1
        local i = pos + 9 -- skip "<!DOCTYPE"
        while i <= len and depth > 0 do
            local c = str:sub(i, i)
            if c == "<" then
                depth = depth + 1
            elseif c == ">" then
                depth = depth - 1
            elseif c == "[" then
                -- internal subset: skip until ]>
                local close = str:find("%]%s*>", i)
                if close then
                    i = close + (str:find(">", close) - close)
                    depth = depth - 1
                else
                    error_at(str, pos, "unterminated DOCTYPE")
                end
            end
            i = i + 1
        end
        pos = i
    end

    -- Parse text content (up to next '<')
    local function parse_text()
        local start = pos
        local lt = str:find("<", pos, true)
        if not lt then
            lt = len + 1
        end
        if lt == start then
            return nil
        end
        pos = lt
        return resolve_entities(str:sub(start, lt - 1), str, start)
    end

    -- Parse CDATA section
    local function parse_cdata()
        -- pos is at '<![CDATA['
        local cdata_start = pos + 9
        local close = str:find("]]>", cdata_start, true)
        if not close then
            error_at(str, pos, "unterminated CDATA section")
        end
        pos = close + 3
        return str:sub(cdata_start, close - 1)
    end

    -- Parse attributes, separate xmlns declarations from regular attributes
    -- Returns: attributes table, new namespace bindings table
    local function parse_attributes()
        local attrs = {}
        local ns_bindings = {}
        local has_ns = false

        while pos <= len do
            pos = skip_ws(str, pos)
            local c = str:sub(pos, pos)
            if c == ">" or c == "/" then
                break
            end
            if c == "?" then -- for PI-like endings
                break
            end

            local name
            name, pos = read_name(str, pos)
            pos = skip_ws(str, pos)

            if str:sub(pos, pos) ~= "=" then
                error_at(str, pos, "expected '=' after attribute name '" .. name .. "'")
            end
            pos = pos + 1
            pos = skip_ws(str, pos)

            local value
            value, pos = read_attr_value(str, pos)

            -- Check for namespace declaration
            if name == "xmlns" then
                -- Default namespace
                ns_bindings[false] = value
                has_ns = true
            elseif name:sub(1, 6) == "xmlns:" then
                local prefix = name:sub(7)
                ns_bindings[prefix] = value
                has_ns = true
            else
                attrs[name] = value
            end
        end

        return attrs, ns_bindings, has_ns
    end

    local parse_element -- forward declaration

    -- Parse children of an element
    local function parse_children(parent)
        local child_index = 0

        local function add_text(text)
            if not text or text == "" then return end
            -- Merge with previous text node if applicable
            if child_index > 0 and type(parent[child_index]) == "string" then
                parent[child_index] = parent[child_index] .. text
            else
                child_index = child_index + 1
                parent[child_index] = text
            end
        end

        while pos <= len do
            if starts_with(str, pos, "</") then
                return child_index
            end

            if starts_with(str, pos, "<!--") then
                skip_comment()
            elseif starts_with(str, pos, "<![CDATA[") then
                add_text(parse_cdata())
            elseif starts_with(str, pos, "<?") then
                skip_pi()
            elseif str:sub(pos, pos) == "<" then
                local elem = parse_element(parent)
                child_index = child_index + 1
                parent[child_index] = elem
            else
                add_text(parse_text())
            end
        end
        return child_index
    end

    -- Parse a single element
    parse_element = function(parent_node)
        -- pos is at '<'
        pos = pos + 1 -- skip '<'
        local tag_name
        tag_name, pos = read_name(str, pos)

        -- Parse attributes (which may include xmlns declarations)
        local raw_attrs, ns_bindings, has_ns = parse_attributes()

        -- Push namespace bindings
        if has_ns then
            ns_stack[#ns_stack + 1] = ns_bindings
        end

        -- Resolve element namespace
        local prefix, local_name = split_qname(tag_name)
        local ns_uri
        if prefix then
            ns_uri = resolve_ns(ns_stack, prefix)
            if not ns_uri then
                error_at(str, pos, "unresolved namespace prefix: " .. prefix)
            end
        else
            -- Default namespace
            ns_uri = resolve_ns(ns_stack, false) or ""
        end

        -- Resolve attribute namespaces (attributes without prefix have no namespace)
        local resolved_attrs = {}
        for name, value in pairs(raw_attrs) do
            -- For lxpath compatibility, store attributes by their raw name
            resolved_attrs[name] = value
        end

        -- Build the element node
        local elem = {
            [".__name"] = tag_name,
            [".__local_name"] = local_name,
            [".__namespace"] = ns_uri,
            [".__ns"] = collect_ns(ns_stack),
            [".__id"] = next_id(),
            [".__type"] = "element",
            [".__attributes"] = resolved_attrs,
            [".__parent"] = parent_node,
        }

        pos = skip_ws(str, pos)

        if starts_with(str, pos, "/>") then
            -- Self-closing tag
            pos = pos + 2
        elseif str:sub(pos, pos) == ">" then
            pos = pos + 1
            -- Parse children
            parse_children(elem)

            -- Expect closing tag
            if not starts_with(str, pos, "</") then
                error_at(str, pos, "expected closing tag for <" .. tag_name .. ">")
            end
            pos = pos + 2
            local close_name
            close_name, pos = read_name(str, pos)
            if close_name ~= tag_name then
                error_at(str, pos, "mismatched closing tag: expected </" .. tag_name .. ">, got </" .. close_name .. ">")
            end
            pos = skip_ws(str, pos)
            if str:sub(pos, pos) ~= ">" then
                error_at(str, pos, "expected '>' after closing tag")
            end
            pos = pos + 1
        else
            error_at(str, pos, "expected '>' or '/>' in element <" .. tag_name .. ">")
        end

        -- Pop namespace bindings
        if has_ns then
            ns_stack[#ns_stack] = nil
        end

        return elem
    end

    -- Main parse
    local doc = { [".__type"] = "document" }

    pos = skip_ws(str, pos)
    skip_xml_decl()
    pos = skip_ws(str, pos)

    -- Skip comments, PIs, DOCTYPE before root element
    while pos <= len do
        pos = skip_ws(str, pos)
        if starts_with(str, pos, "<!--") then
            skip_comment()
        elseif starts_with(str, pos, "<?") then
            skip_pi()
        elseif starts_with(str, pos, "<!DOCTYPE") then
            skip_doctype()
        else
            break
        end
    end

    if pos > len then
        error("XML parse error: no root element found", 0)
    end

    local root = parse_element(doc)
    doc[1] = root

    return doc
end

return M
