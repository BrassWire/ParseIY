namespace ParseIY.Text;

using System.Collections;

/// TNode - expression node. AddArg() is called on parsed operators/functions to sequentially attach operands/arguments.
public abstract class ExpressionReader<TNode> {
	protected ParserData p;

	public this(ParserData p) {
		this.p = p;
	}

	public virtual Parsed<TNode> ReadExpression() {
		p.Start("expression");
		var trimEnd = p.pos;

		if (!ReadOperand().HasMatch(var operand)) { return p.Mismatch; }

		trimEnd = p.pos;
		SkipTrivia();
		if (ReadDistfix(operand).HasMatch(let r)) { return p.Ok(r); }

		let infixQueue = scope List<TNode>();
		while (ReadInfix().HasMatch(let nextInfix)) {
			if (infixQueue.IsEmpty || !LeftInfixPrecedes(infixQueue.Back, nextInfix)) {
				AddArg(nextInfix, operand);
				infixQueue.Add(nextInfix);
			} else {
				AddArg(infixQueue.Back, operand);
				for (var i = infixQueue.Count - 2; i >= 0 && LeftInfixPrecedes(infixQueue[i], nextInfix); i--) {
					AddArg(infixQueue[i], infixQueue.PopBack());
				}

				AddArg(nextInfix, infixQueue.Back);
				infixQueue.Back = nextInfix;
			}

			trimEnd = p.pos;
			SkipTrivia();
			if (!ReadOperand().HasMatch(out operand)) {
				p.LogError("Expected operand");
				for (let exp in infixQueue) { DisposeOfNode(exp); }
				return p.Ok((TNode) default);
			}
			trimEnd = p.pos;
			SkipTrivia();
		}

		if (infixQueue.IsEmpty) { return p.Ok(operand); }

		AddArg(infixQueue.Back, operand);
		for (var i = infixQueue.Count - 2; i >= 0; i--) {
			AddArg(infixQueue[i], infixQueue[i + 1]);
		}
		p.pos = trimEnd;
		return p.Ok(infixQueue[0]);
	}

	public virtual Parsed<TNode> ReadParenthesizedExpression() {
		p.Start("parenthesized_expression");

		if (!p.SkipExactly('(')) {
			return p.Mismatch;
		}

		SkipTrivia();
		if (!ReadExpression().HasMatch(let expression)) { p.LogError("Expected expression"); }
		SkipTrivia();
		if (!p.SkipExactly(')')) { p.LogError("Expected ')'"); }
		return p.Ok(expression);
	}

	/// Parses atom possibly wrapped into unary (prefix/postfix) operators
	public virtual Parsed<TNode> ReadOperand() {
		p.Start("operand");
		var trimEnd = p.pos;

		TNode firstPrefix = default;
		TNode lastPrefix = default;
		while (ReadPrefix().HasMatch(let temp)) {
			SkipTrivia();

			if (lastPrefix != default) {
				AddArg(lastPrefix, temp);
			}
			lastPrefix = temp;
			if (firstPrefix == default) {
				firstPrefix = temp;
			}
		}
		
		TNode tail;
		if (!(ReadAtom().HasMatch(out tail) || ReadParenthesizedExpression().HasMatch(out tail))) {
			return p.Mismatch;
		}

		trimEnd = p.pos;
		SkipTrivia();
		while (ReadPostfix(tail).HasMatch(let temp)) {
			tail = temp;
			trimEnd = p.pos;
			SkipTrivia();
		}

		if (firstPrefix != default) {
			AddArg(lastPrefix, tail);
			tail = firstPrefix;
		}

		p.pos = trimEnd;
		return p.Ok(tail);
	}

	/// Infix operators: +, -, *, /, &&, &, ||, |
	public abstract Parsed<TNode> ReadInfix();

	/// Rates infix operator on a numeric scale, which is then used by `ExpressionReader.LeftInfixPrecedes()`
	public abstract int GetPrecedence(TNode operation);

	/// Adds argument to an operator (infix, postfix, prefix) node
	public abstract void AddArg(TNode operation, TNode nextOperand);

	/// Deletion of class or disposal of struct
	public abstract void DisposeOfNode(TNode node);

	/// Simplest objects to be operated upon: numbers, varnames, text literals.
	public abstract Parsed<TNode> ReadAtom();

	/// Prefix operators: !a, ~a, &a, ++a
	public virtual Parsed<TNode> ReadPrefix() { return .MismatchUntracked; }

	/// Postfix operators: a[b], a.x, a(b), a++
	public virtual Parsed<TNode> ReadPostfix(TNode tail) { return .MismatchUntracked; }

	/// Multi-operators such as ternaries: `a ? b : c`
	public virtual Parsed<TNode> ReadDistfix(TNode term) { return .MismatchUntracked; }

	/// Spacing and comments
	public virtual bool SkipTrivia() { return p.ReadSpacing().HasMatch; }

	/// Override if you need right to left operators (like assignment)
	public virtual bool LeftInfixPrecedes(TNode left, TNode right) => GetPrecedence(left) >= GetPrecedence(right);
}
