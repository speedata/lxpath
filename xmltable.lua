-- <root empty="" quotationmarks='"text"' one="1" foo="no">
-- 	<sub foo="baz" someattr="somevalue">123</sub>
-- 	<sub foo="bar" attr="baz">sub2</sub>
-- 	<sub foo="bar" self="sub3">contents sub3<subsub foo="bar">subsub</subsub></sub>
-- 	<other foo="barbaz">
-- 	  <subsub foo="oof">contents subsub other</subsub>
-- 	</other>
-- 	<other foo="other2">
-- 	  <subsub foo="oof">contents subsub other2</subsub>
-- 	</other>
-- 	<a>
-- 	<sub p="a1/1"></sub>
-- 	<sub p="a1/2"></sub>
-- 	</a>
-- 	<a>
-- 	<sub  p="a2/1"></sub>
-- 	<sub  p="a2/2"></sub>
-- 	</a>
-- </root>
local xmltable = {
    [".__type"] = "document",
    {
        [".__name"] = "root",
        [".__id"] = 1,
        [".__type"] = "element",
        [".__local_name"] = "root",
        [".__namespace"] = "",
        [".__ns"] = {
        },
        [".__attributes"] = { ["empty"] = "", ["quotationmarks"] = "\"text\"", ["one"] = "1", ["foo"] = "no", },
        [1] = "\n",
        [2] = {
            [".__name"] = "sub",
            [".__id"] = 2,
            [".__type"] = "element",
            [".__local_name"] = "sub",
            [".__namespace"] = "",
            [".__ns"] = {
            },
            [".__attributes"] = { ["foo"] = "baz", ["someattr"] = "somevalue", },
            [1] = "123",
        },
        [3] = "\n",
        [4] = {
            [".__name"] = "sub",
            [".__id"] = 3,
            [".__type"] = "element",
            [".__local_name"] = "sub",
            [".__namespace"] = "",
            [".__ns"] = {
            },
            [".__attributes"] = { ["foo"] = "bar", ["attr"] = "baz", },
            [1] = "sub2",
        },
        [5] = "\n",
        [6] = {
            [".__name"] = "sub",
            [".__id"] = 4,
            [".__type"] = "element",
            [".__local_name"] = "sub",
            [".__namespace"] = "",
            [".__ns"] = {
            },
            [".__attributes"] = { ["foo"] = "bar", ["self"] = "sub3", },
            [1] = "contents sub3",
            [2] = {
                [".__name"] = "subsub",
                [".__id"] = 5,
                [".__type"] = "element",
                [".__local_name"] = "subsub",
                [".__namespace"] = "",
                [".__ns"] = {
                },
                [".__attributes"] = { ["foo"] = "bar", },
                [1] = "subsub",
            },
        },
        [7] = "\n",
        [8] = {
            [".__name"] = "other",
            [".__id"] = 6,
            [".__type"] = "element",
            [".__local_name"] = "other",
            [".__namespace"] = "",
            [".__ns"] = {
            },
            [".__attributes"] = { ["foo"] = "barbaz", },
            [1] = "\n  ",
            [2] = {
                [".__name"] = "subsub",
                [".__id"] = 7,
                [".__type"] = "element",
                [".__local_name"] = "subsub",
                [".__namespace"] = "",
                [".__ns"] = {
                },
                [".__attributes"] = { ["foo"] = "oof", },
                [1] = "contents subsub other",
            },
            [3] = "\n",
        },
        [9] = "\n",
        [10] = {
            [".__name"] = "other",
            [".__id"] = 8,
            [".__type"] = "element",
            [".__local_name"] = "other",
            [".__namespace"] = "",
            [".__ns"] = {
            },
            [".__attributes"] = { ["foo"] = "other2", },
            [1] = "\n  ",
            [2] = {
                [".__name"] = "subsub",
                [".__type"] = "element",
                [".__local_name"] = "subsub",
                [".__namespace"] = "",
                [".__ns"] = {
                },
                [".__attributes"] = { ["foo"] = "oof", },
                [1] = "contents subsub other2",
            },
            [3] = "\n",
        },
        [11] = "\n",
        [12] = {
            [".__name"] = "a",
            [".__id"] = 9,
            [".__type"] = "element",
            [".__local_name"] = "a",
            [".__namespace"] = "",
            [".__ns"] = {
            },
            [".__attributes"] = {},
            [1] = "\n",
            [2] = {
                [".__name"] = "sub",
                [".__id"] = 10,
                [".__type"] = "element",
                [".__local_name"] = "sub",
                [".__namespace"] = "",
                [".__ns"] = {
                },
                [".__attributes"] = { ["p"] = "a1/1", },
            },
            [3] = "\n",
            [4] = {
                [".__name"] = "sub",
                [".__id"] = 11,
                [".__type"] = "element",
                [".__local_name"] = "sub",
                [".__namespace"] = "",
                [".__ns"] = {
                },
                [".__attributes"] = { ["p"] = "a1/2", },
            },
            [5] = "\n",
        },
        [13] = "\n",
        [14] = {
            [".__name"] = "a",
            [".__id"] = 12,
            [".__type"] = "element",
            [".__local_name"] = "a",
            [".__namespace"] = "",
            [".__ns"] = {
            },
            [".__attributes"] = {},
            [1] = "\n",
            [2] = {
                [".__name"] = "sub",
                [".__id"] = 13,
                [".__type"] = "element",
                [".__local_name"] = "sub",
                [".__namespace"] = "",
                [".__ns"] = {
                },
                [".__attributes"] = { ["p"] = "a2/1", },
            },
            [3] = "\n",
            [4] = {
                [".__name"] = "sub",
                [".__id"] = 14,
                [".__type"] = "element",
                [".__local_name"] = "sub",
                [".__namespace"] = "",
                [".__ns"] = {
                },
                [".__attributes"] = { ["p"] = "a2/2", },
            },
            [5] = "\n",
        },
        [15] = "\n",
    },
}

return xmltable