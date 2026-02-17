-- benchmark.lua — Synthetic XML tree + benchmark for lxpath
local lxpath = require("lxpath")

---------------------------------------------------------------------------
-- Tree generator
---------------------------------------------------------------------------

local id_counter = 0

local element_names = { "div", "p", "span", "item", "entry", "section", "row", "cell", "title", "ref" }
local attr_keys    = { "id", "class", "type", "lang", "status" }
local attr_values  = { "foo", "bar", "baz", "active", "draft", "en", "de", "fr" }

--- Creates a single element
local function make_element(name, attrs, parent)
    id_counter = id_counter + 1
    local elt = {
        [".__name"]       = name,
        [".__id"]         = id_counter,
        [".__type"]       = "element",
        [".__local_name"] = name,
        [".__namespace"]  = "",
        [".__ns"]         = {},
        [".__attributes"] = attrs or {},
    }
    if parent then
        elt[".__parent"] = parent
    end
    return elt
end

--- Creates a document node
local function make_document()
    id_counter = 0
    return {
        [".__type"] = "document",
    }
end

--- Generates a synthetic tree.
---@param depth    integer  Maximum depth (levels below root)
---@param breadth  integer  Children per element node
---@param textprob number   Probability (0-1) that a text node is inserted
---@return table doc        Document table
---@return integer count    Number of generated elements
local function generate_tree(depth, breadth, textprob)
    textprob = textprob or 0.3
    local total_elements = 0

    local function build(parent_elt, current_depth)
        if current_depth > depth then return end
        for i = 1, breadth do
            -- Pick element name cyclically
            local name = element_names[((current_depth - 1) * breadth + i - 1) % #element_names + 1]

            -- Attributes: 1-2 per element
            local attrs = {}
            local ak = attr_keys[(i % #attr_keys) + 1]
            local av = attr_values[(i % #attr_values) + 1]
            attrs[ak] = av
            if i % 3 == 0 then
                local ak2 = attr_keys[((i + 2) % #attr_keys) + 1]
                attrs[ak2] = attr_values[((i + 3) % #attr_values) + 1]
            end

            local child = make_element(name, attrs, parent_elt)
            total_elements = total_elements + 1

            -- Optional text node before the child
            if (current_depth + i) % 10 < textprob * 10 then
                parent_elt[#parent_elt + 1] = "text content " .. id_counter
            end

            parent_elt[#parent_elt + 1] = child

            -- Recursively create children
            build(child, current_depth + 1)
        end
    end

    local doc = make_document()
    local root = make_element("root", { ["version"] = "1.0" })
    doc[1] = root
    root[".__parent"] = doc
    total_elements = total_elements + 1

    build(root, 1)

    return doc, total_elements
end

---------------------------------------------------------------------------
-- Benchmark infrastructure
---------------------------------------------------------------------------

local function bench(label, iterations, fn)
    -- Warmup
    for _ = 1, math.min(10, iterations) do fn() end

    collectgarbage("collect")
    collectgarbage("collect")
    local start = os.clock()
    for _ = 1, iterations do
        fn()
    end
    local elapsed = os.clock() - start
    local per_iter = elapsed / iterations * 1000 -- ms
    print(string.format("  %-40s %6d iter  %8.3f s  %8.4f ms/iter", label, iterations, elapsed, per_iter))
end

---------------------------------------------------------------------------
-- Benchmarks
---------------------------------------------------------------------------

local function run_benchmarks()
    print("=== Generating trees ===")

    -- Small tree: depth 4, breadth 5 → ~780 elements
    local small_doc, small_count = generate_tree(4, 5, 0.3)
    print(string.format("  Small tree: %d elements", small_count))

    -- Medium tree: depth 5, breadth 5 → ~3900 elements
    local med_doc, med_count = generate_tree(5, 5, 0.3)
    print(string.format("  Medium tree: %d elements", med_count))

    -- Large tree: depth 4, breadth 10 → ~11110 elements
    local big_doc, big_count = generate_tree(4, 10, 0.3)
    print(string.format("  Large tree: %d elements", big_count))

    print()

    -----------------------------------------------------------------------
    -- 1. Tokenizer + Parser
    -----------------------------------------------------------------------
    print("=== Tokenizer + Parser ===")

    local xpaths = {
        "child::div/span[@class = 'foo']",
        "//item[@status = 'active' and @lang = 'de']",
        "descendant-or-self::node()/child::entry[position() > 2]",
        "concat(substring('hello world', 1, 5), ' ', string-length('test'))",
        "sum(//row/cell) div count(//row)",
    }

    for _, xp in ipairs(xpaths) do
        bench("tokenize+parse: " .. string.sub(xp, 1, 35), 5000, function()
            local toks = lxpath.string_to_tokenlist(xp)
            lxpath.parse_xpath(toks)
        end)
    end

    print()

    -----------------------------------------------------------------------
    -- 2. Simple eval expressions
    -----------------------------------------------------------------------
    print("=== Eval (small tree) ===")

    local ctx_small = lxpath.context:new({ xmldoc = small_doc, sequence = { small_doc[1] }, namespaces = {} })

    bench("eval: child::div", 2000, function()
        ctx_small:eval("child::div")
    end)

    bench("eval: div/span", 2000, function()
        ctx_small:eval("div/span")
    end)

    bench("eval: div[@id = 'bar']", 2000, function()
        ctx_small:eval("div[@id = 'bar']")
    end)

    bench("eval: string-length('hello world')", 5000, function()
        ctx_small:eval("string-length('hello world')")
    end)

    bench("eval: 1 + 2 * 3", 5000, function()
        ctx_small:eval("1 + 2 * 3")
    end)

    print()

    -----------------------------------------------------------------------
    -- 3. Descendant axis (the expensive case)
    -----------------------------------------------------------------------
    print("=== Descendant axis ===")

    bench("descendant::* (small tree)", 500, function()
        local c = lxpath.context:new({ xmldoc = small_doc, sequence = { small_doc[1] }, namespaces = {} })
        c:eval("descendant::*")
    end)

    bench("descendant::* (medium tree)", 100, function()
        local c = lxpath.context:new({ xmldoc = med_doc, sequence = { med_doc[1] }, namespaces = {} })
        c:eval("descendant::*")
    end)

    bench("descendant::* (large tree)", 50, function()
        local c = lxpath.context:new({ xmldoc = big_doc, sequence = { big_doc[1] }, namespaces = {} })
        c:eval("descendant::*")
    end)

    bench("descendant-or-self::item (medium)", 100, function()
        local c = lxpath.context:new({ xmldoc = med_doc, sequence = { med_doc[1] }, namespaces = {} })
        c:eval("descendant-or-self::item")
    end)

    bench("//entry (medium tree)", 100, function()
        local c = lxpath.context:new({ xmldoc = med_doc, sequence = { med_doc[1] }, namespaces = {} })
        c:eval("//entry")
    end)

    print()

    -----------------------------------------------------------------------
    -- 4. Complex expressions
    -----------------------------------------------------------------------
    print("=== Complex expressions ===")

    bench("//div[span/@class='foo'] (small)", 500, function()
        local c = lxpath.context:new({ xmldoc = small_doc, sequence = { small_doc[1] }, namespaces = {} })
        c:eval("//div[span/@class='foo']")
    end)

    bench("count(//item) (medium tree)", 100, function()
        local c = lxpath.context:new({ xmldoc = med_doc, sequence = { med_doc[1] }, namespaces = {} })
        c:eval("count(//item)")
    end)

    bench("//section[entry/@status] (large)", 50, function()
        local c = lxpath.context:new({ xmldoc = big_doc, sequence = { big_doc[1] }, namespaces = {} })
        c:eval("//section[entry/@status]")
    end)

    print()
    print("=== Done ===")
end

run_benchmarks()
