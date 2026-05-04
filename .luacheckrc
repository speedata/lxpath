std = "max"

exclude_files = {
    "luaunit.lua",
    "inspect.lua",
    "serpent.lua",
}

max_line_length = 140
-- BNF grammar rules from the XPath 2.0 spec are reproduced verbatim in
-- comments and test fixtures; allow generous comment/string widths.
max_comment_line_length = 260
max_string_line_length = 200

-- debug.lua is a stand-alone debugging helper that intentionally defines
-- globals consumed by main.lua / createxmltable.lua via dofile().
files["debug.lua"] = {
    globals = {
        "w", "log", "nexttok", "printtable",
        "showattributes", "tracetable", "nodelist_tostring",
    },
    -- "M", "publisher", "unicode", "node" are expected to exist when this
    -- file is dofile'd inside the speedata Publisher; tolerate them here.
    read_globals = { "M", "publisher", "unicode", "node" },
}

files["main.lua"] = {
    read_globals = { "w" },
}

files["createxmltable.lua"] = {
    read_globals = { "w", "log", "printtable" },
}

files["lxpath_test.lua"] = {
    globals = {
        "TestTokenizer",
        "TestXMLParser",
        "lxpath_dodebug",
    },
    -- LuaUnit test methods conventionally take `self` even when unused.
    ignore = { "212/self" },
    -- Test fixtures are column-aligned tables; relax line length here.
    max_line_length = 200,
}
