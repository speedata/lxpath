# lxpath — Pure Lua XPath Parser and Evaluator

A pure Lua XPath parser and evaluator supporting XPath 2.0 with selected XPath 3.1 features (arrays, maps, string concatenation). Includes a built-in XML parser — no external dependencies. Part of the [speedata Publisher](https://github.com/speedata/publisher/).

## Quick Start

```lua
local lxpath = require("lxpath")
local xmlparser = require("xmlparser")

-- Parse XML into the table structure lxpath expects
local doc = xmlparser.parse([[
<catalog>
    <book id="1"><title>Lua Programming</title></book>
    <book id="2"><title>XPath Essentials</title></book>
</catalog>
]])

-- Create a context and evaluate XPath expressions
local ctx = lxpath.context:new({
    xmldoc = { doc },
    sequence = { doc },
})

local seq = ctx:eval("//book[@id='2']/title")
print(seq[1][1]) --> "XPath Essentials"
```

## Using the library

### Parsing XML

The included `xmlparser` module parses well-formed XML into the Lua table structure that lxpath expects:

```lua
local xmlparser = require("xmlparser")
local doc = xmlparser.parse(xml_string)
```

The parser supports:
- Elements, attributes, text nodes, self-closing tags
- Namespaces (default and prefixed, with proper scoping)
- CDATA sections (merged into adjacent text nodes)
- Entity references (`&amp;`, `&lt;`, `&gt;`, `&quot;`, `&apos;`) and numeric character references (`&#123;`, `&#x7B;`)
- UTF-8 element and attribute names (e.g. `<Bücher>`)
- XML declarations, comments, processing instructions, DOCTYPE (all skipped)

Not supported: DTD validation, external entities.

You can also construct the table structure manually or supply it from another source — see [XML Representation](#xml-representation) below.

### Evaluating XPath

```lua
local lxpath = require("lxpath")

local ctx = lxpath.context:new({
    namespaces = {
        myns = "http://a.name-space"
    },
    vars = {
        foo = "bar",
        onedotfive = 1.5,
        a = 5,
        ["one-two"] = 12,
    },
    xmldoc = { doc },
    sequence = { doc }
})

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

The difference is that `eval()` does not change the context, it only returns the sequence. `execute()` changes self.

## Supported XPath Syntax

### Expressions

| Expression | Example | Description |
|---|---|---|
| Path | `child/grandchild` | Navigate the XML tree |
| Abbreviated path | `//item` | Descendant-or-self shorthand |
| Filter / Predicate | `item[position() = 1]` | Filter sequences with `[]` |
| Arithmetic | `1 + 2`, `$a * 3` | `+`, `-`, `*`, `div`, `idiv`, `mod` |
| Comparison | `$x = 1`, `$x eq 1` | General (`=`, `!=`, `<`, `>`, `<=`, `>=`) and value (`eq`, `ne`, `lt`, `le`, `gt`, `ge`) comparisons |
| Node comparison | `$a is $b`, `$a << $b` | `is`, `<<`, `>>` |
| Logical | `$a and $b`, `$a or $b` | `and`, `or` |
| Range | `1 to 10` | Integer sequence |
| String concatenation | `'hello' \|\| ' world'` | XPath 3.1 `\|\|` operator |
| Unary | `-$x`, `+$x` | Unary plus/minus |
| Union | `a \| b` | Node set union |
| If/then/else | `if ($x) then 'a' else 'b'` | Conditional |
| For | `for $i in 1 to 5 return $i * 2` | Iteration |
| Quantified | `some $x in (1,2,3) satisfies $x > 2` | `some` / `every` |
| Type | `$x instance of xs:integer` | `instance of`, `cast as`, `castable as`, `treat as` |
| Variable reference | `$varname` | Access context variables |
| Context item | `.` | Current item |

### Axes

| Axis | Abbreviated | Direction |
|---|---|---|
| `child::` | (default) | forward |
| `attribute::` | `@` | forward |
| `self::` | `.` | forward |
| `descendant::` | | forward |
| `descendant-or-self::` | `//` | forward |
| `following::` | | forward |
| `following-sibling::` | | forward |
| `parent::` | `..` | reverse |
| `ancestor::` | | reverse |
| `ancestor-or-self::` | | reverse |
| `preceding::` | | reverse |
| `preceding-sibling::` | | reverse |

### Node Tests

| Test | Description |
|---|---|
| `node()` | Any node |
| `element()` | Element nodes |
| `text()` | Text nodes |
| `comment()` | Comment nodes |
| `processing-instruction()` | PI nodes |
| `*` | Any element (wildcard) |
| `prefix:*` | Any element in namespace |
| `name` | Element by name |

## Built-in Functions

### String Functions

| Function | Description |
|---|---|
| `concat(s1, s2, ...)` | Concatenate strings |
| `contains(s, sub)` | Test if string contains substring |
| `ends-with(s, sub)` | Test if string ends with substring |
| `lower-case(s)` | Convert to lowercase |
| `normalize-space(s)` | Normalize whitespace |
| `starts-with(s, sub)` | Test if string starts with substring |
| `string(item?)` | Convert to string |
| `string-join(seq, sep)` | Join sequence with separator |
| `string-length(s?)` | Length of string |
| `substring(s, start, len?)` | Extract substring |
| `substring-after(s, sub)` | Substring after first occurrence |
| `substring-before(s, sub)` | Substring before first occurrence |
| `translate(s, from, to)` | Character-by-character translation |
| `upper-case(s)` | Convert to uppercase |
| `matches(s, pattern, flags?)` | Regular expression matching (stub — provide your own implementation) |
| `codepoints-to-string(seq)` | Codepoints to string |
| `string-to-codepoints(s)` | String to codepoints |

### Numeric Functions

| Function | Description |
|---|---|
| `abs(n)` | Absolute value |
| `ceiling(n)` | Round up |
| `floor(n)` | Round down |
| `format-number(n, fmt)` | Format number as string |
| `number(item)` | Convert to number |
| `round(n)` | Round to nearest integer |
| `round-half-to-even(n, precision?)` | Banker's rounding |

### Boolean Functions

| Function | Description |
|---|---|
| `boolean(item)` | Convert to boolean |
| `false()` | Boolean false |
| `true()` | Boolean true |
| `not(b)` | Boolean negation |

### Sequence Functions

| Function | Description |
|---|---|
| `count(seq)` | Number of items |
| `distinct-values(seq)` | Remove duplicates |
| `empty(seq)` | Test if empty |
| `max(seq)` | Maximum value |
| `min(seq)` | Minimum value |
| `reverse(seq)` | Reverse order |

### Node Functions

| Function | Description |
|---|---|
| `doc(uri)` | Load document |
| `last()` | Size of current context |
| `local-name(node?)` | Local name of node |
| `name(node?)` | Qualified name of node |
| `namespace-uri(node?)` | Namespace URI |
| `position()` | Position in current context |
| `root(node?)` | Root node |

### Other Functions

| Function | Description |
|---|---|
| `serialize(item)` | Serialize node to XML string |
| `unparsed-text(uri)` | Read file as text |

### Array Functions (`array:`)

Requires namespace declaration: `array = "http://www.w3.org/2005/xpath-functions/array"`

| Function | Description |
|---|---|
| `array:size(a)` | Number of members |
| `array:get(a, pos)` | Get member at position |
| `array:put(a, pos, val)` | Replace member at position |
| `array:append(a, val)` | Append member |
| `array:subarray(a, start, len?)` | Extract sub-array |
| `array:remove(a, pos)` | Remove member at position |
| `array:join(arrays)` | Concatenate arrays |
| `array:flatten(a)` | Flatten nested arrays |

### Map Functions (`map:`)

Requires namespace declaration: `map = "http://www.w3.org/2005/xpath-functions/map"`

| Function | Description |
|---|---|
| `map:size(m)` | Number of entries |
| `map:keys(m)` | All keys |
| `map:get(m, key)` | Get value for key |
| `map:put(m, key, val)` | Add/replace entry |
| `map:remove(m, key)` | Remove entry |
| `map:contains(m, key)` | Test if key exists |
| `map:merge(maps)` | Merge maps |
| `map:entry(key, val)` | Create single-entry map |

## Arrays and Maps (XPath 3.1)

### Constructors

```xpath
(: Square array constructor :)
[1, 2, 3]

(: Curly array constructor — each item becomes a member :)
array { 1 to 5 }

(: Empty map :)
map {}

(: Map with entries :)
map { 'name': 'Alice', 'age': 30 }
```

### Lookup Operator `?`

```xpath
$myarray?1          (: first member :)
$myarray?*          (: all members :)
$mymap?name         (: value for key 'name' :)
$mymap?*            (: all values :)
[10, 20, 30]?2      (: 20 :)
```

## Running the tests

```
lua lxpath_test.lua
```

Run a single test by name:

```
lua lxpath_test.lua TestTokenizer.test_get_qname
```

## Unicode and UTF-8

All input is expected to be in UTF-8.

This library is not unicode aware! This means for example `upper-case('ä')` is not `Ä`, but `ä`, since there is no lookup table for unicode.

You can provide your own implementations for `string.match` and `string.find` (which might be UTF-8 ready) by setting `M.stringmatch` and `M.stringfind`.

## Registering new XPath functions

You can use the `registerFunction()` function to add your own definitions:

It expects a table with the following fields:

1. function name
2. namespace
3. function (where the arguments are the context and the provided arguments)
4. minimum number of arguments
5. maximum number of arguments (-1 if arbitrary many arguments allowed)

Example:

```lua
function fnSubstring(ctx, arg)
    ...
end
lxpath.registerFunction({ "substring", "http://www.w3.org/2005/xpath-functions", fnSubstring, 2, 3 })
```

## XML Representation

The `xmlparser.parse()` function produces this structure automatically. If you want to construct the table manually or supply it from another source, here is the format. Each element (a table) has zero or more children, either a string or another element. The element table has this representation:

```lua
{
    [".__name"] = "elementname",
    [".__id"]  = 1,  -- in document order
    [".__type"] = "element",
    [".__local_name"] = "elementname",
    [".__namespace"] = "",
    [".__ns"] = {
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

## Limitations

* Union/except/intersect operators are only partially implemented
* Date functions are not implemented
* No schema support
* Not unicode aware (see above)
* Since Lua does not have full regular expressions, `matches()` is a stub — provide your own implementation via `registerFunction()`. `replace()` and `tokenize()` are not implemented.
