using System;
using System.Collections;
using System.Text;
using System.Diagnostics;
namespace ParseIY;

/// Mutable state used by parsers for text or binaries.
/// Provides utilities for mismatch backtracking, syntax highlighting, and reporting oddities in symbols.
public class ParserData {
	/// For displaying currently parsed position into a debugger watch.
	static String mDebuggerWatchBuffer;

	/// char8 or byte sequence to be parsed
	public StringView		source;

	/// Check-points for backtracking and debuggability
	/// (own)
	public List<SavePoint>	saves;

	/// Logged errors, warnings, suggestions, symbol highlights.
	/// (own)
	public List<LogEntry>	logs;

	/// Position that's about to be parsed from
	public int         		pos;

	/// Usually used for syntax highlighting, or otherwise for debugging
	public bool				autologNamedSymbols;

	public ~this() {
		Debug.Assert(saves.Count == 0);
		delete saves;
		DeleteContainerAndItems!(logs);
	}
	
	[AllowAppend]
	public this(StringView raw, int startPos = 0) {
		pos = startPos;
		source = raw;
		saves = new .(16);
		logs = new .(16);
	}

	[Inline] public StringView LengthSinceStart => source[saves.Back.pos..<pos];

	[Inline] public int LengthLeft => source.Length - pos;

	public int LengthLeftUntilTerminator(uint8 terminatorByte) {
		let length = source.Length;
		var i = pos;
		while (i < length && terminatorByte != (.)source[i]) {
			i++;
		}
		return i - pos;
	}
	
	public void Start(String name = null) {
		saves.Add(.(pos, name));
	}

	/// Should be returned if symbol was recognized. It includes both correct and malformed symbols.
	[NoDiscard]
	public Parsed<T> Ok<T>(T v) {
		if (autologNamedSymbols && saves.Count > 0 && saves.Back.name != null) {
			logs.Add(new LogEntry(.Symbol, null, saves.Back, pos...pos));
		}
		saves.PopBack();
		return .OkUntracked(v);
	}

	/// Should be returned if symbol was not recognized. Triggers backtrack.
	public MismatchIndicator Mismatch {
		get {
			Backtrack();
			return MismatchIndicator();
		}
	}

	/// Intended for use inside cycle conditions, eliminating a need for a separate parser function to be declared.
	/// First argument expects `p.Start()` call, and second - `p.<function>().HasMatch` or `p.<function>().HasMatch(let symbol)`
	public bool InlineTry(void starter, bool v) {
		if (v) {
			saves.PopBack();
		} else {
			Backtrack();
		}
		return v;
	}

	/// Triggers backtrack. Not recommended for external use.
	public void Backtrack() {
		let lastSave = saves.PopBack();
		for (var i = logs.Count - 1; i >= 0; i--) {
			if (lastSave == logs.Back.lastSave) {
				delete logs.PopBack();
			} else {
				break;
			}
		}
		pos = lastSave.pos;
	}

	/// To be used in a debugger, inside watch expression. Shows what text is it going to parse next.
	[AlwaysInclude]
	public StringView mDebuggerWatch(int previewDistance = -1, char32 cursor = '⚈') {
		delete mDebuggerWatchBuffer;
		let prev = source.Substring((previewDistance < 0? 0 : Math.Max(0, pos-previewDistance))..<pos);
		return mDebuggerWatchBuffer = new String(prev)..Append(cursor)..Append(source.Substring(pos));
	}

#region Basic built-in parsers
	public bool SkipExactly(char8 char) {
		if (pos < source.Length && source[pos] == char) {
			pos++;
			return true;
		}
		return false;
	}

	public bool SkipExactly(char32 char)
		=> SkipExactly(scope String(4)..Append(char));

	public bool SkipExactlyLowercase(StringView substring) {
		if (pos + substring.Length > source.Length)
			return false;

		for (let i < substring.Length) if (substring[i] != source[pos+i].ToLower) {
			return false;
		}

		pos += substring.Length;
		return true;
	}

	public bool SkipExactly(StringView substring) {
		if (pos + substring.Length > source.Length)
			return false;

		for (let i < substring.Length) if (substring[i] != source[pos+i]) {
			return false;
		}

		pos += substring.Length;
		return true;
	}

	public bool SkipExactly(params Span<char8> options) {
		for (let i < options.Length) if (SkipExactly(options[i])) {
			return true;
		}
		return false;
	}

	public Parsed<char8> ReadExactly(params Span<char8> options) {
		for (let i < options.Length) if (SkipExactly(options[i])) {
			return .OkUntracked(options[i]);
		}
		return .MismatchUntracked;
	}

	public bool SkipExactly(params Span<char32> options) {
		for (let i < options.Length) if (SkipExactly(options[i])) {
			return true;
		}
		return false;
	}

	public Parsed<char32> ReadExactly(params Span<char32> options) {
		for (let i < options.Length) if (SkipExactly(options[i])) {
			return .OkUntracked(options[i]);
		}
		return .MismatchUntracked;
	}

	public bool SkipExactly(params Span<StringView> options) {
		for (let i < options.Length) if (SkipExactly(options[i])) {
			return true;
		}
		return false;
	}

	public Parsed<StringView> ReadExactly(params Span<StringView> options) {
		for (let i < options.Length) if (SkipExactly(options[i])) {
			return .OkUntracked(options[i]);
		}
		return .MismatchUntracked;
	}

	[Inline] 
	public Parsed<char32> ReadChar() {
		if (pos >= source.Length)
			return .MismatchUntracked;

		let res = TrySilent!(UTF8.TryDecode(&source[pos], source.Length));
		pos += res.1;
		return .OkUntracked(res.0);
	}

	public Parsed<char32> ReadChar(char32 min, char32 max)
		=> ReadChar((min, max));

	public Parsed<char32> ReadChar(params Span<(char32,char32)> charSpans) {
		Start();
		if (ReadChar().HasMatch(let charA)) {
			for (let charSpan in charSpans)
				if (charSpan.0 <= charA && charA <= charSpan.1)
					return Ok(charA);
		}
		return Mismatch;
	}

	[Inline] 
	public Parsed<uint8> ReadByte() {
		if (pos >= source.Length)
			return .MismatchUntracked;
		return .OkUntracked((uint8)source[pos++]);
	}

	public Parsed<char8> ReadChar8() {
		if (pos >= source.Length)
			return .MismatchUntracked;
		return .OkUntracked(source[pos++]);
	}

	public bool SkipByte(uint8 byte)
		=> SkipExactly((char8) byte);

	/// Reads struct directly from binary
	public Parsed<T> ReadRaw<T>() where T: ValueType {
		if (sizeof(T) > LengthLeft)
			return .MismatchUntracked;
		return .OkUntracked(BitConverter.Convert<uint8[sizeof(T)], T>(readBytes<const sizeof(T)>()));
	}

	/// Reads struct directly from reversed order (big-endian) binary
	public Parsed<T> ReadBackwardRaw<T>() where T: ValueType {
		if (LengthLeft >= sizeof(T)) {
			var bytes = readBytes<const sizeof(T)>();
			endianSwap(&bytes, sizeof(T));
			return .OkUntracked(BitConverter.Convert<uint8[sizeof(T)], T>(bytes));
		}
		return .MismatchUntracked;
	}

	private uint8[N] readBytes<N>()
	where N:const int {
		uint8[N] ret = ?;
		let pos_ = pos;
		for (var i = 0; i < N; i++)
			ret[i] = (.)source[pos_ + i];

		pos = pos_ + N;
		return ret;
	}

	private static void endianSwap(void* ptr, int length) {
		let bytes = (uint8*) ptr;
		for (var i = 0; i <= (length-1)/2; i++)
			Swap!(ref bytes[i], ref bytes[length-1-i]);
	}
#endregion

#region Logging
	public void LogError(StringView description)
		=> logs.Add(new LogEntry(.Error, new  .(description), saves.Back, pos...pos));

	public void LogWarning(StringView description)
		=> logs.Add(new LogEntry(.Warning, new .(description), saves.Back, pos...pos));

	public void LogSuggestion(StringView description)
		=> logs.Add(new LogEntry(.Suggestion, new .(description), saves.Back, pos...pos));

	public class LogEntry {
		public String info ~ delete _;
		public SavePoint lastSave;
		public int min;
		public int max;
		public LogEntry.Type logType;

		public this(LogEntry.Type logType, String desc, SavePoint lastSave, ClosedRange range) {
			this.logType = logType;
			this.lastSave = lastSave;
			this.min = range.Start;
			this.max = range.End;
			this.info = desc;
		}

		public enum Type {
			case Symbol, Suggestion, Warning, Error;
			public void ToLogRerpesentation(String strBuffer) {
				switch (this) {
				case Symbol:		strBuffer += "SYMBOL";
				case Suggestion:	strBuffer += "SUGGESTION";
				case Warning:		strBuffer += "WARNING";
				case Error:			strBuffer += "ERROR";
				}
			}
		}
	}

	public void ToLogsForBinarySource(String strBuffer, StringView sourceName = default, int bytesPerLine = 16, int groupSize = 1) {
		var i = 0;
		for (let entry in logs) {
			if (entry.logType == .Symbol) { continue; }
			if (i++ > 0) { strBuffer += "\n\n"; }
			let line = getHexLineInfo(entry.max, bytesPerLine);
			strBuffer += scope $"{entry.logType.ToLogRerpesentation(..scope .())}: {entry.info == null ? "Unknown" : entry.info} at offset {entry.max:X}";
			if (!sourceName.IsEmpty) { strBuffer += scope $" in {sourceName}"; }
			strBuffer += scope $"\n\n{(line.start - bytesPerLine):X8}  ";
			if (getHexLine(strBuffer, (line.start - bytesPerLine) ..< (line.start), groupSize)) {
				strBuffer += "\n\n";
			}

			var utf8 = scope String(16);
			var leftOver = 0;
			let lineStartInStrBuffer = strBuffer.Length;
			var indent = -1;
			strBuffer..Append(scope $"{line.start:X8}  ");
			for (var byteIdx = line.start; byteIdx < line.start + bytesPerLine; byteIdx++) {
				if (byteIdx == entry.max) {
					indent = strBuffer.Length - lineStartInStrBuffer;
				}

				if (byteIdx < line.end) {
					strBuffer += scope $"{((uint8)source[byteIdx]):X2}";
					utf8 += source[byteIdx];
				} else {
					strBuffer += "  ";
				}
				if (++leftOver >= groupSize) {
					strBuffer += ' ';
					leftOver -= groupSize;
				}
			}

			if (indent < 0) {
				indent = strBuffer.Length - lineStartInStrBuffer;
			}

			strBuffer..Append("  |", utf8, "|");
			strBuffer..Append('\n')..Append(scope String(' ', indent), "^^");
		}
	}

	private bool getHexLine(String strBuffer, Range range, int groupSize) {
		if (range.End <= 0 || range.Start >= source.Length) {
			return false;
		}

		var utf8 = scope String(16);
		var leftOver = 0;
		for (var byteIdx in range) {
			if (byteIdx >= source.Length) { break; }
			if (byteIdx >= 0) {
				strBuffer += scope $"{((uint8)source[byteIdx]):X2}";
				utf8 += source[byteIdx];
			} else {
				strBuffer += "  ";
			}
			if (++leftOver >= groupSize) {
				strBuffer += ' ';
				leftOver -= groupSize;
			}
		}
		strBuffer..Append("  |", utf8, "|");
		return true;
	}

	private (int start, int end) getHexLineInfo(int pos, int bytesPerLine) {
		let lineStart = pos - pos % bytesPerLine;
		return (lineStart, Math.Min(lineStart + bytesPerLine, source.Length));
	}

	public void ToLogsForTextSource(String strBuffer, StringView sourceName = default) {
		var i = 0;
		for (let entry in logs) {
			if (entry.logType == .Symbol) { continue; }
			if (i++ > 0) { strBuffer += "\n\n"; }
			let line = getLineInfo(entry.max);
			strBuffer += scope $"{entry.logType.ToLogRerpesentation(..scope .())}: {entry.info == null ? "Unknown" : entry.info} at line {line.idx + 1}:{getCharIdxFromLineStart(entry.max, line.start) + 1}";
			if (!sourceName.IsEmpty) { strBuffer += scope $" in {sourceName}"; }
			strBuffer..Append("\n", source[line.start ..< getLineEnd(entry.max)], "\n");
			strBuffer..Append(scope String(' ', entry.max - line.start), "^");
		}
	}

	private int getCharIdxFromLineStart(int pos, int lineStart) {
		var count = 0;
		for (let ch in source[lineStart ..< pos]) {
			count++;
		}
		return count;
	}

	private (int idx, int start) getLineInfo(int pos) {
		var lineCount = 0, lineStart = 0;
		for (var i = pos - 1; i >= 0; i--) {
			if (source[i] == '\n') {
				lineCount++;
				if (lineStart < 0) {
					lineStart = i + 1;
				}
			}
		}
		return (lineCount, lineStart);
	}

	private int getLineEnd(int pos) {
		var lineEnd = source.IndexOf('\n', pos);
		if (lineEnd < 0) { lineEnd = source.Length; }
		return lineEnd;
	}
#endregion

	public struct SavePoint: this(int pos, String name) {
		public static bool operator ==(Self a, Self b) {
			return a.pos == b.pos && a.name == b.name;
		}
	}

	/// Implicitly converted into a Parsed<T> representing mismatch
	public struct MismatchIndicator {
	}
}