///|
/// # MoonBit HTML5 Parser - API Specification
///
/// A WHATWG-compliant HTML5 parser with tokenizer, tree builder, and serializer.

// =============================================================================
// CORE PARSING API
// =============================================================================

///|
/// Parse an HTML string into a Document.
///
/// This is the main entry point for parsing HTML. The parser follows the
/// WHATWG HTML5 specification and handles malformed HTML gracefully.
///
/// Example:
/// ```
/// let doc = parse("<html><body><p>Hello</p></body></html>")
/// ```
#declaration_only
pub fn parse(input : String) -> Document {
  ...
}

///|
/// Parse HTML and return both the document and any parse errors encountered.
///
/// Use this when you need to report or log parsing errors for diagnostics.
///
/// Example:
/// ```
/// let (doc, errors) = parse_with_errors("<p>Test</p attr>")
/// // errors contains parse error information
/// ```
#declaration_only
pub fn parse_with_errors(input : String) -> (Document, Array[ParseError]) {
  ...
}

///|
/// Parse HTML with scripting enabled.
///
/// When scripting is enabled, the content inside `<noscript>` tags is treated
/// as raw text rather than being parsed as HTML.
#declaration_only
pub fn parse_with_scripting(input : String) -> Document {
  ...
}

///|
/// Tokenize HTML without building a tree.
///
/// Returns an array of tokens and any parse errors. Useful for syntax
/// highlighting, linting, or custom tree construction.
///
/// Example:
/// ```
/// let (tokens, errors) = tokenize("<div>Hello</div>")
/// // tokens[0] = StartTag(name="div", ...)
/// ```
#declaration_only
pub fn tokenize(input : String) -> (Array[Token], Array[ParseError]) {
  ...
}

// =============================================================================
// DOCUMENT METHODS
// =============================================================================

///|
/// Create a new empty document.
#declaration_only
pub fn Document::new() -> Document {
  ...
}

///|
/// Serialize the document to an HTML string.
///
/// Produces valid HTML5 output with proper escaping of text content
/// and attribute values.
///
/// Example:
/// ```
/// let doc = parse("<p>Hello & World</p>")
/// doc.to_html() // "<html><head></head><body><p>Hello &amp; World</p></body></html>"
/// ```
#declaration_only
pub fn Document::to_html(self : Document) -> String {
  ...
}

///|
/// Pretty-print the document tree for debugging.
///
/// Returns a human-readable indented representation of the DOM tree.
#declaration_only
pub fn Document::dump(self : Document) -> String {
  ...
}

///|
/// Get child node IDs for a given node.
#declaration_only
pub fn Document::get_children(self : Document, node_id : Int) -> Array[Int] {
  ...
}

///|
/// Get the parent node ID. Returns NO_NODE (-1) if no parent.
#declaration_only
pub fn Document::get_parent(self : Document, node_id : Int) -> Int {
  ...
}

///|
/// Get the tag name of an element node.
#declaration_only
pub fn Document::get_tag_name(self : Document, node_id : Int) -> String? {
  ...
}

///|
/// Get an attribute value by name.
#declaration_only
pub fn Document::get_attribute(
  self : Document,
  node_id : Int,
  name : String
) -> String? {
  ...
}

///|
/// Check if an element has a specific attribute.
#declaration_only
pub fn Document::has_attribute(
  self : Document,
  node_id : Int,
  name : String
) -> Bool {
  ...
}

///|
/// Set an attribute on an element.
#declaration_only
pub fn Document::set_attribute(
  self : Document,
  node_id : Int,
  name : String,
  value : String
) -> Unit {
  ...
}

///|
/// Get the concatenated text content of a node and its descendants.
#declaration_only
pub fn Document::get_text_content(self : Document, node_id : Int) -> String {
  ...
}

///|
/// Get the namespace of an element node.
#declaration_only
pub fn Document::get_ns(self : Document, node_id : Int) -> Namespace? {
  ...
}

///|
/// Get the Element struct for a node, if it is an element.
#declaration_only
pub fn Document::get_element(self : Document, node_id : Int) -> Element? {
  ...
}

///|
/// Get the raw Node for a given node ID.
#declaration_only
pub fn Document::get_node(self : Document, node_id : Int) -> Node? {
  ...
}

///|
/// Check if a node is an element with the given tag name and namespace.
#declaration_only
pub fn Document::is_element(
  self : Document,
  node_id : Int,
  tag_name : String,
  ns : Namespace
) -> Bool {
  ...
}

///|
/// Check if a node is an HTML element with the given tag name.
#declaration_only
pub fn Document::is_html_element(
  self : Document,
  node_id : Int,
  tag_name : String
) -> Bool {
  ...
}

// =============================================================================
// DOM MANIPULATION
// =============================================================================

///|
/// Add a new node to the document. Returns the node ID.
#declaration_only
pub fn Document::add_node(self : Document, node : Node) -> Int {
  ...
}

///|
/// Append a child node to a parent node.
#declaration_only
pub fn Document::append_child(
  self : Document,
  parent_id : Int,
  child_id : Int
) -> Unit {
  ...
}

///|
/// Insert a node before a reference node.
#declaration_only
pub fn Document::insert_before(
  self : Document,
  parent_id : Int,
  new_node_id : Int,
  ref_node_id : Int
) -> Unit {
  ...
}

///|
/// Remove a child node from its parent.
#declaration_only
pub fn Document::remove_child(
  self : Document,
  parent_id : Int,
  child_id : Int
) -> Unit {
  ...
}

///|
/// Get the template content node ID for a `<template>` element.
#declaration_only
pub fn Document::get_template_content(self : Document, node_id : Int) -> Int {
  ...
}

// =============================================================================
// ELEMENT CREATION
// =============================================================================

///|
/// Create a new Element with tag name, namespace, and attributes.
#declaration_only
pub fn Element::new(
  tag_name : String,
  ns : Namespace,
  attributes : Array[(String, String)]
) -> Element {
  ...
}

// =============================================================================
// TOKENIZER API
// =============================================================================

///|
/// Create a new tokenizer for the given input string.
#declaration_only
pub fn Tokenizer::new(input : String) -> Tokenizer {
  ...
}

///|
/// Get the next token from the input.
#declaration_only
pub fn Tokenizer::next_token(self : Tokenizer) -> Token {
  ...
}

///|
/// Get all parse errors accumulated during tokenization.
#declaration_only
pub fn Tokenizer::get_errors(self : Tokenizer) -> Array[ParseError] {
  ...
}

///|
/// Get the current source position.
#declaration_only
pub fn Tokenizer::get_position(self : Tokenizer) -> SourcePosition {
  ...
}

///|
/// Switch tokenizer to RCDATA state (for `<title>`, `<textarea>`).
#declaration_only
pub fn Tokenizer::switch_to_rcdata(self : Tokenizer) -> Unit {
  ...
}

///|
/// Switch tokenizer to RAWTEXT state (for `<style>`, `<xmp>`, etc.).
#declaration_only
pub fn Tokenizer::switch_to_rawtext(self : Tokenizer) -> Unit {
  ...
}

///|
/// Switch tokenizer to Script Data state (for `<script>`).
#declaration_only
pub fn Tokenizer::switch_to_script_data(self : Tokenizer) -> Unit {
  ...
}

///|
/// Switch tokenizer to PLAINTEXT state.
#declaration_only
pub fn Tokenizer::switch_to_plaintext(self : Tokenizer) -> Unit {
  ...
}

// =============================================================================
// TREE BUILDER API
// =============================================================================

///|
/// Create a new tree builder for the given input.
#declaration_only
pub fn TreeBuilder::new(input : String) -> TreeBuilder {
  ...
}

///|
/// Create a tree builder with options.
#declaration_only
pub fn TreeBuilder::new_with_options(
  input : String,
  scripting~ : Bool
) -> TreeBuilder {
  ...
}

///|
/// Run the tree construction algorithm and return the document.
#declaration_only
pub fn TreeBuilder::parse(self : TreeBuilder) -> Document {
  ...
}

// =============================================================================
// UTILITY FUNCTIONS
// =============================================================================

///|
/// Look up a named character reference (e.g., "amp" -> [38]).
///
/// Returns the code points for the character reference, or None if not found.
#declaration_only
pub fn lookup_entity(name : String) -> Array[Int]? {
  ...
}

///|
/// Check if a tag name is a formatting element (b, big, code, em, font, etc.).
#declaration_only
pub fn is_formatting_element(tag_name : String) -> Bool {
  ...
}
