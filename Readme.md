## Pure Lua XPath 2.0 parser

Work in progress, not usable at the moment.

This will be part of the [speedata Publisher](https://github.com/speedata/publisher/) version 5.


### Using the library

The API is subject to change!

```lua
-- crate a context with variables, namespaces and an XML document
local ctxvalue = {
    namespaces = {
        myns = "http://a.name-space"
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

-- toks is a token list
local toks, msg = lxpath.string_to_tokenlist(str)
if toks == nil then
    print(msg)
    os.exit(-1)
end

-- ef is a function which executes the parsed xpath on a context.
-- you can reuse ef()
local ef, err = lxpath.parse_xpath(toks)
if err ~= nil then
    -- handle error string err
end

local seq, errmsg = ef(ctx)
-- seq is the resulting sequence (a table) of zero or more items.
-- Each item can be a sequence, a string or a number.
```

## Running the tests

```
lua lxpath_test.lua
```

## XML representation

Since the xpath library is not parsing the XML file, it has to be represented in a tree like data structure.

Each element (a table) has zero or more children, either a string or another element. The element table has this representation:

```lua
{
    [".__name"] = "elementname",
    [".__type"] = "element",
    [".__local_name"] = "elementname",
    [".__namespace"] = "",
    [".__ns"] = {
        -- some predefined name spaces
        ["myprefix"] = "http://a.name.space",
    },
    [".__attributes"] = {
        ["key"] = "value",
    },
    [1] = "a string for example",
    [2] = { --  a table for an element
        },
    [3] = "perhaps another string",
}
```

For example the following XML

```xml
<data>
    <child attname="attvalue">
        some text
    </child>

    mixed content
</data>
```


must be encoded in Lua as:


```lua
tbl = {
    [".__type"] = "document",
    {
        [1] = {
            [".__name"] = "data",
            [".__type"] = "element",
            [".__local_name"] = "data",
            [".__namespace"] = "",
            [".__ns"] = {
            },
            [1] = "\n    ",
            [2] = {
                [".__name"] = "child",
                [".__type"] = "element",
                [".__local_name"] = "child",
                [".__namespace"] = "",
                [".__ns"] = {
                },
                [".__attributes"] = { ["attname"] = "attvalue", },
                [1] = "\n        some text\n    ",
            },
            [3] = "\n\n    mixed content\n",
        },
    },
}
```
