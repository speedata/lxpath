## Pure Lua XPath 2.0 parser

This is part of the [speedata Publisher](https://github.com/speedata/publisher/).

See the test file to get get idea of the amount of XPath functionality that is implemented.

### Using the library


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
-- Each item can be a sequence, an element, an attribute, a string or a number.
```

You can also run one of the convenience functions:

```lua
sequence, errormessage = ctx:eval("xpath string")
```

and

```lua
sequence, errormessage = ctx:execute("xpath string")
```

The difference is that the `eval()` does not change the context, it only returns the sequence. `execute()` changes self.

## Running the tests

```
lua lxpath_test.lua
```

## Unicode and UTF8

All input is expected to be in UTF8.

This library is not unicode aware! This means for example `upper-case('ä')` is not `Ä`, but `ä`, since there is no lookup table for unicode.

You can provide your own implementations for `string.match` and `string.find` (which might be UTF8 ready) by setting `M.stringmatch` and `M.stringfind`.

## Limitations

* Work in progress: union/except/intersect and date functions are currently missing
* This library is not unicode aware (see above).
* No schema support.
* Since Lua does not have “real” regular expressions, the functions that expect regular expressions are not implemented (`matches()`, `replace()`, `tokenize()`). You should provide your own implementations of these functions.

You can override the XPath functions.

## Registering new XPath functions

You can use the `registerFunction()` function to add your own definitions:

It expects a table with the following fields:

1. function name
2. namespace
3. function (where the arguments are the context and the provided arguments)
4. minimum number of arguments
5. maximum number of arguments (-1 if arbitrary many arguments allowed)

example:

```lua
function fnSubstring(ctx, arg)
    ...
end
registerFunction( { "substring", "http://www.w3.org/2005/xpath-functions", fnSubstring,2, 3 } )
```

## XML representation

Since the xpath library is not parsing the XML file, it has to be represented in a tree like data structure.

Each element (a table) has zero or more children, either a string or another element. The element table has this representation:

```lua
{
    [".__name"] = "elementname",
    [".__id"]  = 1,  -- in document order
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
            [".__id"]  = 1,
            [".__type"] = "element",
            [".__local_name"] = "data",
            [".__namespace"] = "",
            [".__ns"] = {
            },
            [1] = "\n    ",
            [2] = {
                [".__name"] = "child",
                [".__id"]  = 2,
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

