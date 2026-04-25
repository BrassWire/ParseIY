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

	/// Logged errors, warnings, suggestions.
	/// (own)
	public List<LogEntry>	logs;

	/// Position that's about to be parsed from
	public int         		pos;

	public bool tracingIsEnabled;

	public ~this() {
		Debug.Assert(saves.Count == 0);
		delete saves;
		DeleteContainerAndDisposeItems!(logs);
	}
	
	[AllowAppend]
	public this(StringView raw, int startPos = 0) {
		pos = startPos;
		source = raw;
		saves = new .(16);
		logs = new .(16);
	}

	[Inline] public StringView Substring() => source[saves.Back.pos..<pos];

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
		if (tracingIsEnabled && saves.Count > 0 && saves.Back.name != null) {
			logs.Add(LogEntry(.Trace, null, saves.Back, saves.Back.pos...(Math.Max(saves.Back.pos, pos - 1))));
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
				logs.PopBack().Dispose();
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
	public Parsed<T> ReadBytes<T>() where T: ValueType {
		if (sizeof(T) > LengthLeft)
			return .MismatchUntracked;
		return .OkUntracked(BitConverter.Convert<uint8[sizeof(T)], T>(readBytes<const sizeof(T)>()));
	}

	/// Reads struct directly from reversed order (big-endian) binary
	public Parsed<T> ReadBackwardBytes<T>() where T: ValueType {
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
	public void LogError(StringView description, ClosedRange range = default)
		=> logs.Add(LogEntry(.Error, new  .(description), saves.Back, range != default ? range : pos...pos));

	public void LogWarning(StringView description, ClosedRange range = default)
		=> logs.Add(LogEntry(.Warning, new .(description), saves.Back, range != default ? range : pos...pos));

	public void LogSuggestion(StringView description, ClosedRange range = default)
		=> logs.Add(LogEntry(.Suggestion, new .(description), saves.Back, range != default ? range : pos...pos));

	public struct LogEntry : IDisposable {
		public SavePoint lastSave;
		public int min, max;
		public String info;
		public LogEntry.Type logType;

		public this(LogEntry.Type logType, String desc, SavePoint lastSave, ClosedRange range) {
			this.logType = logType;
			this.lastSave = lastSave;
			this.min = range.Start;
			this.max = range.End;
			this.info = desc;
		}

		public void Dispose() {
			delete info;
		}

		public enum Type {
			case Trace, Suggestion, Warning, Error;
			public override void ToString(String strBuffer) {
				switch (this) {
				case Trace:			strBuffer += "TRACE";
				case Suggestion:	strBuffer += "SUGGESTION";
				case Warning:		strBuffer += "WARNING";
				case Error:			strBuffer += "ERROR";
				}
			}
		}
	}

	public void ToLogsForBinarySource(String result, StringView sourceName = default, int bytesPerLine = 16, int groupSize = 1) {
		var i = 0;
		for (let entry in logs) {
			if (entry.logType == .Trace) { continue; }
			let lineStart = entry.max - entry.max % bytesPerLine;

			result += i++ > 0 ? "\n\n" : "";
			result += entry.logType;
			result += ": ";
			result += entry.info == null ? "Unknown" : entry.info;
			result += " at offset ";
			entry.max.ToString(result, "X", null);
			result += sourceName.IsEmpty ? "" : " in ";
			result += sourceName.IsEmpty ? "" : sourceName;
			result += "\n\n";
			getHexLine(result, entry, bytesPerLine, groupSize, lineStart - bytesPerLine);
			getHexLine(result, entry, bytesPerLine, groupSize, lineStart);
		}
	}

	private void getHexLine(String result, LogEntry marker, int bytesPerLine, int groupSize, int lineStart) {
		let lineEnd = lineStart + bytesPerLine;
		if (lineEnd <= 0 || lineStart >= source.Length) { return; }

		lineStart.ToString(result, "X8", null);
		result += "  ";
		let mark = scope String(' ', 10);

		var leftOver = 0;
		for (let i < bytesPerLine) {
			let idx = lineStart + i;
			mark += marker.min <= idx && idx <= marker.max ? "^^" : "  ";
			if (0 <= idx && idx < source.Length) {
				((uint8)source[idx]).ToString(result, "X2", null);
			} else {
				result.Append("  ");
			}
			if (++leftOver >= groupSize) {
				result += ' ';
				mark += ' ';
				leftOver -= groupSize;
			}
		}

		result += "  |";
		result += source[Math.Max(0, lineStart) ..< Math.Min(source.Length, lineEnd)];
		result += "|\n";
		result += mark;
		result += '\n';
	}

	public void ToLogsForTextSource(String result, StringView sourceName = default) {
		var i = 0;
		for (let entry in logs) {
			if (entry.logType == .Trace) { continue; }
			let (lineStart, lineEnd, line, column) = getLineInfo(entry.max);

			result += i++ > 0 ? "\n\n" : "";
			result += entry.logType;
			result += ": ";
			result += entry.info == null ? "Unknown" : entry.info;
			result += " at line ";
			result += line + 1;
			result += ':';
			result += column + 1;
			result += sourceName.IsEmpty ? "" : " in ";
			result += sourceName.IsEmpty ? "" : sourceName;
			result += '\n';
			result += source[lineStart ..< lineEnd];
			result += '\n';

			for (var idx in lineStart ..< lineEnd) {
				result += entry.min <= idx && idx <= entry.max ? '^' : ' ';
			}
		}
	}

	private (int, int, int, int) getLineInfo(int pos) {
		var lineStart = -1, lineEnd = source.IndexOf('\n', pos), line = 0, column = 0;


		for (var i = pos - 1; i >= 0; i--) {
			if (source[i] == '\n') {
				line++;
				if (lineStart < 0) { lineStart = i + 1; }
			}
		}

		if (lineStart < 0) { lineStart = 0; }
		if (lineEnd < 0) { lineEnd = source.Length; }

		for (let ch in source[lineStart ..< pos].DecodedChars) {
			column++; // Because of non-ASCII chars
		}

		return (lineStart, lineEnd, line, column);
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