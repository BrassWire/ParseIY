## About
ParseIY provides few simple types that were refined over multiple years and make writing parsers a lot easier

Supports both binary and UTF8 text as inputs

```beef
/// Scannerless top-down parser for reading 'number 123'
public static Parsed<int> ReadMyNumber(this ParserData p) {
	p.Start(); // Save-point for backtracking on mismatch

	if (!p.ReadKeyword("number").HasMatch) { return p.Mismatch; }
	p.ReadSpacing();
	if (!p.ReadNumberAsInt().HasMatch(var number) {
		// We were sure that we're using a correct subparser. This means we're reading a malformed symbol.
		// Instead of backtracking, we log an error, and possibly jump over bad section before exiting.
		p.LogError("Expected an integer");
		number = 0;
	}

	return p.End(number); // Return correct or malformed result
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

## Addressing performance concerns
Q: Is there a measurable overhead?

A: Most overhead usually comes not from parsing algorithm itself, but from whichever allocator you've used to allocate a final result of parsing. Which is why it's recommended to use arena allocation.

Q: Don't top-down parsers have exponential time complexity?

A: Theoretically, yes. In practice though, you are the one writing a parser algorithm, so it's up to you whether it's O(n) or O(exp(exp(exp(N))))

Q: What if I don't want to have any overhead that comes with backtracking approach?

A: Internals of your parsing algorithm can be arbitrary, you can even make use of a lexer. The only thing that's required of it - is to advance ParserData pos appropriately once it's done.
