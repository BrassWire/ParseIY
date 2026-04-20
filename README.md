## About
This library lets you write parsers for text or for binary inputs.

It does offer an approach for writing parsers with focus on backtracked variety, but does not require you to follow it. Overhead is minimal, and can be further bypassed via hot loop unrolling and other techniques, if performance is top-priority for your use-case.

Despite being less than 1k lines of code, it went through many iterations over many months and multiyear gaps, so it's all battle-hardened by now. 

## Types
- `ParserData` - holds parser position. Supports backtracking, syntax highlighting and logging errors/warnings/suggestions. Offers couple basic built-in parser functions.
- `Parsed<T>` - used as return in parser functions. Holds a parsed value if parser had matched correct or erroneous symbol, or holds no value if parser could not be applied and backtrack should be triggered.
- `IndentedLineBuffer` - helps to convert AST back into raw text by applying indentations via `using (buffer.Shifted)` syntax.
- `ExpressionReader<TNode>` - abstract type for quickly making expression parsers. It implements general algorithm for parsing binary (and not only) expression trees, while allowing developer to override any detail.  

## Examples
(To be done)
