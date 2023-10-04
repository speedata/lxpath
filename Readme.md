## Pure Lua XPath 2.0 parser

Work in progress, not usable at the moment.

This will be part of the [speedata Publisher](https://github.com/speedata/publisher/) version 5.


The XML is expected to be defined in a table. For example the following XML

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

