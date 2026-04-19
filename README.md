This library lets you write parsers for text or for binary inputs.<br>
It does offer an approach for writing parsers, but does not require you to follow it. Overhead is minimal, and can be further bypassed via hot loop unrolling and other techniques, if performance is top-priority for your use-case.<br>
It went through many iterations over many months, so it's battle-hardened by now. 

Library introduces these types:
- ParserData - holds parser position. Supports backtracking, syntax highlighting and logging errors/warnings/suggestions. Offers couple basic built-in parser functions.
- Parsed<T> - used as return in parser functions. Holds a parsed value if parser had matched correct or erroneous symbol, or holds no value if parser could not be applied and backtrack should be triggered.
- IndentedLineBuffer - helps to convert AST back into raw text by applying indentations via `using (buffer.Shifted)` syntax.
- ExpressionReader<TNode> - abstract type for quickly making expression parsers. It implements general algorithm for parsing binary (and not only) expression trees, while allowing developer to override any detail.  

This library also ships couple simple extra parsers in separate namespaces.

## Parser examples
(To be done)
