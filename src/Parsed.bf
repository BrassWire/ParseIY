using System;
namespace ParseIY;

/// Container for a parse result, initialized via ParserData methods `Ok()` and `Mismatch`.
/// Parsing can either succeed (even if it logged errors), or it can not happen due to complete syntax mismatch; which is reflected by this structure.
public struct Parsed<T> {
	public T MatchedOrDefault;
	public bool HasMatch;

	private this() {
		MatchedOrDefault = ?;
		HasMatch = ?;
	}

	public bool HasMatch(out T value) {
		value = MatchedOrDefault;
		return HasMatch;
	}
		
	public mixin OrExit(ParserData p) {
		if (!HasMatch) { return p.Mismatch; }
		MatchedOrDefault
	}

	public mixin OrBreak() {
		if (!HasMatch) { break; }
		MatchedOrDefault
	}

	public static Parsed<T> MismatchUntracked => default;

	[Inline]
	public static Parsed<T> OkUntracked(T v) {
		return .() {
			MatchedOrDefault = v,
			HasMatch = true
		};
	}
	
	public static implicit operator Parsed<T>(ParserData.MismatchIndicator arg) {
		return default;
	}

	public static Parsed<T> operator implicit <TOther>(Parsed<TOther> arg) where T: operator implicit TOther {
		if (arg.HasMatch(let v)) { return Self.OkUntracked(v); }
		return default;
	}
}

extension Parsed<T> where T: ValueType {
	public static implicit operator Nullable<T>(Parsed<T> arg) {
		Nullable<T> ret = ?;
		ret.[Friend]mValue = arg.MatchedOrDefault;
		ret.[Friend]mHasValue = arg.HasMatch;
		return ret;
	}
}

extension Parsed<T> where T: class {
	public static implicit operator T(Parsed<T> arg)
		=> arg.HasMatch ? arg.MatchedOrDefault : null;
}

extension Parsed<T> where T: void {
	public static implicit operator bool(Parsed<T> arg)
		=> arg.HasMatch;
}