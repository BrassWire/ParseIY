using System;
namespace ParseIY.Text;
public static
{
	public static Parsed<StringView> ReadSpacing(this ParserData p) {
		p.Start();

		var ret = false;
		while (p.SkipExactly(' ', '\t', '\n', '\r', '\f'))
			ret = true;

		if (!ret) return p.Mismatch;
		return p.Ok(p.LengthSinceStart);
	}

	public static Parsed<StringView> ReadInlineSpacing(this ParserData p) {
		p.Start();

		var ret = false;
		while (p.SkipExactly(' ', '\t'))
			ret = true;

		if (!ret) return p.Mismatch;
		return p.Ok(p.LengthSinceStart);
	}

	[Inline]
	public static Parsed<int> ReadDigit(this ParserData p) {
		if (p.InlineTry(p.Start(), p.ReadChar().HasMatch(let ch) && ch >= '0' && ch <= '9')) {
			return .OkUntracked(ch - '0');
		}
		return .MismatchUntracked;
	}

	public static Parsed<int64> ReadNumberAsInt(this ParserData p) {
		p.Start("number_as_int64");
			
		int64 val = 0;
		var isNegative = false;
		var unread = true;
		var outOfRange = false;
		while (true) {
			if (unread && p.LengthLeft > 0 && (p.source[p.pos] == '-' || p.source[p.pos] == '+'))
				isNegative = (p.source[p.pos++] == '-');

			if (p.ReadDigit().HasMatch(let digit)) {
				int64 newVal = ?;
				if (isNegative) {
					newVal = 10*val - digit;
					outOfRange |= newVal > val;
				} else {
					newVal = 10*val + digit;
					outOfRange |= newVal < val;
				}

				val = newVal;
			} else if (unread) {
				return p.Mismatch;
			} else {
				if (outOfRange) { p.LogWarning("Number is too large"); }
				return p.Ok(val);
			}
			unread = false;
		}
	}

	public static Parsed<double> ReadNumberAsDouble(this ParserData p, out bool encounteredPoint) {
		p.Start("number_as_double");
		
		var isNegative = false, unread = true;
		var postPointPos = 0;
		double val = 0;
		encounteredPoint = false;
		while (true) {
			if (unread && p.LengthLeft > 0 && (p.source[p.pos] == '-' || p.source[p.pos] == '+'))
				isNegative = (p.source[p.pos++] == '-');

			if (p.ReadDigit().HasMatch(let digit)) {
				if (postPointPos == 0) {
					val = 10*val + digit;
				} else {
					val = val + digit*Math.Pow(10.0, postPointPos--);
				}
			} else if (postPointPos == 0 && p.SkipExactly('.')) {
				encounteredPoint = true;
				postPointPos = -1;
			} else if (unread) {
				return p.Mismatch;
			} else {
				return p.Ok(isNegative? -val:val);
			}
			unread = false;
		}
	}

	public static Parsed<StringView> ReadKeyword(this ParserData p, StringView name, params Span<StringView> names) {
		if (p.ReadKeyword(name).HasMatch(let r)) {
			return .OkUntracked(r);
		}
		for (let n in names) if (p.ReadKeyword(n).HasMatch(let ret)) {
			return .OkUntracked(ret);
		}
		return .MismatchUntracked;
	}

	public static Parsed<StringView> ReadKeyword(this ParserData p, StringView name) {
		p.Start();
		if (p.SkipExactly(name) && !p.InlineTry(p.Start(), (p.ReadChar8().HasMatch(let ch) && (ch.IsLetterOrDigit || ch == '_'))))
			return p.Ok(name);
		return p.Mismatch;
	}

	public static Parsed<StringView> ReadQuotedText(this ParserData p, StringView quote, bool singleLine = false) {
		p.Start();

		if (!p.SkipExactly(quote)) {
			return p.Mismatch;
		}

		while (true) {
			if (p.SkipExactly(quote)) {
				return p.Ok(p.source.Substring((p.saves.Back.pos + quote.Length) ..< (p.pos - quote.Length)));
			} else if (!p.ReadChar().HasMatch(let ch)) {
				p.LogError("Quotation did not end");
				return p.Mismatch;
			} else if (singleLine && ch == '\n') {
				p.LogError("This quotation type does not expect a line break");
				return p.Mismatch;
			}
		}
	}
}
