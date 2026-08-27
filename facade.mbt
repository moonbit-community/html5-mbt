///|
/// Parse an HTML document using the WHATWG tree-construction algorithm.
pub using @html5 {
  parse,
  parse_with_errors,
  parse_with_scripting,
  tokenize,
  lookup_entity,
  is_formatting_element,
  NO_NODE,
  type Attribute,
  type Document,
  type Element,
  type Namespace,
  type Node,
  type ParseError,
  type ParseErrorCode,
  type QuirksMode,
  type SourcePosition,
  type Token,
  type Tokenizer,
  type TreeBuilder,
}
