## About
ParseIY provides few simple types that were refined over multiple years and make writing parsers a lot easier

Supports both binary and UTF8 text as inputs

```beef
/// Scannerless top-down parser for reading 'number 123'
public static Parsed<int> ReadMyNumber(this ParserData p) {
	p.Start(); // Save-point for backtracking

	if (!p.ReadKeyword("number").HasMatch) { return p.Mismatch; }
	// Past this point, we're sure we are using correct subparser. If error happens, we simply log it. 
	p.ReadSpacing();
	if (!p.ReadNumberAsInt().HasMatch(let number) { p.LogError("Expected an integer"); }

	return p.Ok(number); 
}

// Running parser:
let p = scope ParserData("number a")..ReadMyNumber();
Console.WriteLine(p.ToLogsForTextSource(..scope .()));

// ERROR: Expected an integer at line 1:8
// number a
//        ^
```

## Types
- `ParserData` - holds parser position. Supports backtracking, syntax highlighting and logging errors/warnings/suggestions. Offers couple basic built-in parser functions, and ability to watch parsing progress inside the IDE watch.
- `Parsed<T>` - used as return in parser functions. Holds a parsed value if parser had matched correct or erroneous symbol, or holds no value if parser could not be applied and backtrack should be triggered.
- `ExpressionReader<TNode>` - abstract type helping with making expression tree parsers. It provides a generalized algorithm, while leaving it up to developer what subparsers to use, and what AST node type to use (a single class, a single struct, hierarchy of classes, etc) 
- `IndentedLineBuffer` - helps to convert AST back into raw text by marking indentations via `using (buffer.Shifted)` syntax. While it's not needed for parsing, this type was just too useful to not also include it.
