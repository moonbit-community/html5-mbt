///|
/// Keeps trait methods available through dot syntax.
pub extend Element with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Element with Eq::{not_equal, equal}

///|
pub extend Node with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Node with Eq::{not_equal, equal}

///|
pub extend Document with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Document with Eq::{not_equal, equal}

///|
pub extend Element with Show::{to_string, output}

///|
pub extend Node with Show::{to_string, output}

///|
pub extend Document with Show::{to_string, output}

///|
pub extend Token with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Token with Eq::{not_equal, equal}

///|
pub extend QuirksMode with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend QuirksMode with Eq::{not_equal, equal}

///|
pub extend Attribute with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Attribute with Eq::{not_equal, equal}

///|
pub extend State with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend State with Eq::{not_equal, equal}

///|
pub extend SourcePosition with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend SourcePosition with Eq::{not_equal, equal}

///|
pub extend ParseErrorCode with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ParseErrorCode with Eq::{not_equal, equal}

///|
pub extend ParseError with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ParseError with Eq::{not_equal, equal}

///|
pub extend Namespace with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Namespace with Eq::{not_equal, equal}

///|
pub extend Token with Show::{to_string, output}

///|
pub extend QuirksMode with Show::{to_string, output}

///|
pub extend Attribute with Show::{to_string, output}

///|
pub extend State with Show::{to_string, output}

///|
pub extend SourcePosition with Show::{to_string, output}

///|
pub extend ParseErrorCode with Show::{to_string, output}

///|
pub extend ParseError with Show::{to_string, output}

///|
pub extend Namespace with Show::{to_string, output}

///|
pub extend Document with @moonbitlang/core/quickcheck.Arbitrary::{arbitrary}

///|
pub extend HtmlCase with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend HtmlCase with @moonbitlang/core/quickcheck.Arbitrary::{arbitrary}
