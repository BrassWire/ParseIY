## About
ParseIY provides few simple well-refined types that make writing parsers a lot easier

Supports both binary and UTF8 text as inputs

```beef
/// Scannerless top-down parser for reading 'hello world'
public static Parsed<StringView> ReadHelloWorld(this ParserData p) {
	p.Start(); // Save-point for backtracking

	if (!p.ReadKeyword("hello").HasMatch) { return p.Mismatch; }
	// Past this point, we're sure we are using correct subparser. If error happens, we simply log it. 
	p.ReadSpacing();
	if (!p.ReadKeyword("world").HasMatch) { p.LogError("Expected 'world' in hello world"); }

	return p.Ok(p.Substring()); 
}
```

## Types
- `ParserData` - holds parser position. Supports backtracking, syntax highlighting and logging errors/warnings/suggestions. Offers couple basic built-in parser functions.
- `Parsed<T>` - used as return in parser functions. Holds a parsed value if parser had matched correct or erroneous symbol, or holds no value if parser could not be applied and backtrack should be triggered.
- `IndentedLineBuffer` - helps to convert AST back into raw text by applying indentations via `using (buffer.Shifted)` syntax.
- `ExpressionReader<TNode>` - abstract type for quickly making expression parsers. It implements general algorithm for parsing binary (and not only) expression trees, while allowing developer to override any detail.
