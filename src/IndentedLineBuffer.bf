namespace ParseIY;

using System;
using System.Collections;

/// Helper class for serializing AST into code with indentations
class IndentedLineBuffer {
	private append String unindentedText = .(1024);
	/// Index - line index, value - number of indents to be made
	private append List<int> indents = .(32);
	private int nextIndent;
	
	public this() { indents.Add(0); }

	public void Clear() {
		unindentedText.Clear();
		indents..Clear()..Add(0);
	}

	public Scope Indent => Scope(this);
	public Scope Indent(bool v) => v ? Scope(this) : (Scope)default;

	/*
	public void Sequence(delegate int() writer, StringView separator) {
		var i = 0;
		for (let res = writer(); res >= 0; ) {
			if (res == 0 && i++ > 0) {
				this += separator;
			}
		}
	}
	*/

	public void operator +=(char32 b) {
		unindentedText += b;
		if (b == '\n') { indents.Add(nextIndent); }
	}

	public void operator +=(StringView b) {
		unindentedText += b;
		for (let i < b.Length) if (b[i] == '\n') { indents.Add(nextIndent); }
	}

	public override void ToString(String strBuffer) {
		ToString(strBuffer, "\t");
	}

	public void ToString(String strBuffer, StringView indentation) {
		for (let i < indents[0]) { strBuffer += indentation; }
		var idx = 1;
		for (let i < unindentedText.Length) {
			strBuffer += unindentedText[i];
			if (unindentedText[i] == '\n') {
				for (let j < indents[idx]) { strBuffer += indentation; }
				idx++;
			}
		}
	}

	/// To be used in `using()` statements
	public struct Scope: IDisposable {
		IndentedLineBuffer buffer;

		public this(IndentedLineBuffer buffer) {
			this.buffer = buffer;
			buffer.nextIndent++;
		}

		public void Dispose() {
			if (buffer != null) { buffer.nextIndent--; }
		}
	}
}