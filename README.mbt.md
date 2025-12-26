# MoonBit HTML Parser

A fully WHATWG-compliant HTML5 parser implemented in MoonBit.

## Features

- Full WHATWG HTML5 specification compliance
- 80 tokenizer states
- 25 tree construction insertion modes
- 49 parse error types with graceful recovery
- 2,231 named character references
- **100% conformance with html5lib tree construction tests (8251/8251 tests passing)**

## Basic Usage

Parse an HTML string and inspect the document tree:

```moonbit check
///|
test "basic parsing" {
  let doc = @html5.parse(
    "<html><head><title>Hello</title></head><body><p>World</p></body></html>",
  )
  inspect(
    doc.dump(),
    content=(
      #|<html>
      #|  <head>
      #|    <title>
      #|      "Hello"
      #|  <body>
      #|    <p>
      #|      "World"
    ),
  )
}
```

## Error Recovery

The parser handles malformed HTML gracefully, just like browsers:

```moonbit check
///|
test "error recovery - unclosed tags" {
  let doc = @html5.parse("<p>First<p>Second<p>Third")
  inspect(
    doc.dump(),
    content=(
      #|<html>
      #|  <head>
      #|  <body>
      #|    <p>
      #|      "First"
      #|    <p>
      #|      "Second"
      #|    <p>
      #|      "Third"
    ),
  )
}
```

```moonbit check
///|
test "error recovery - misnested tags" {
  let doc = @html5.parse("<b><i>Bold and Italic</b> Just Italic</i>")
  inspect(
    doc.dump(),
    content=(
      #|<html>
      #|  <head>
      #|  <body>
      #|    <b>
      #|      <i>
      #|        "Bold and Italic"
      #|    <i>
      #|      " Just Italic"
    ),
  )
}
```

## HTML Serialization

Convert the document back to HTML:

```moonbit check
///|
test "serialize to html" {
  let doc = @html5.parse("<div class=\"container\"><span>Hello</span></div>")
  inspect(
    doc.to_html(),
    content="<html><head></head><body><div class=\"container\"><span>Hello</span></div></body></html>",
  )
}
```

## Parse with Error Collection

Collect parse errors for diagnostics:

```moonbit check
///|
test "parse with errors" {
  let (doc, errors) = @html5.parse_with_errors("<p>Test</p attr>")
  inspect(errors.length() > 0, content="true")
  inspect(
    doc.dump(),
    content=(
      #|<html>
      #|  <head>
      #|  <body>
      #|    <p>
      #|      "Test"
    ),
  )
}
```

## Tokenization

Tokenize HTML without building a tree:

```moonbit check
///|
test "tokenization" {
  let (tokens, _errors) = @html5.tokenize("<div>Hello</div>")
  inspect(
    tokens[0],
    content="StartTag(name=\"div\", attrs=[], self_closing=false)",
  )
  inspect(tokens[1], content="Character('H')")
  inspect(tokens[2], content="Character('e')")
}
```

## DOM Navigation

Access elements and attributes:

```moonbit check
///|
test "dom access" {
  let doc = @html5.parse("<div id=\"main\"><p class=\"text\">Content</p></div>")

  // Get body element
  let body_id = doc.body_element
  let children = doc.get_children(body_id)

  // Get the div
  let div_id = children[0]
  inspect(doc.get_tag_name(div_id), content="Some(\"div\")")
  inspect(doc.get_attribute(div_id, "id"), content="Some(\"main\")")

  // Get the p element
  let p_id = doc.get_children(div_id)[0]
  inspect(doc.get_attribute(p_id, "class"), content="Some(\"text\")")
  inspect(doc.get_text_content(p_id), content="Content")
}
```

## Character References

The parser correctly handles named and numeric character references:

```moonbit check
///|
test "character references" {
  let doc = @html5.parse("<p>&amp; &lt; &gt; &copy; &#169; &#x00A9;</p>")
  let p_id = doc.get_children(doc.body_element)[0]
  inspect(
    doc.get_text_content(p_id),
    content="& < > \u{00A9} \u{00A9} \u{00A9}",
  )
}
```

## Foreign Content (SVG/MathML)

The parser correctly handles SVG and MathML embedded in HTML:

```moonbit check
///|
test "svg support" {
  let doc = @html5.parse(
    "<div><svg><circle cx=\"50\" cy=\"50\" r=\"40\"/></svg></div>",
  )
  inspect(
    doc.dump(),
    content=(
      #|<html>
      #|  <head>
      #|  <body>
      #|    <div>
      #|      <svg svg>
      #|        <svg circle>
      #|          cx="50"
      #|          cy="50"
      #|          r="40"
    ),
  )
}
```

## API Reference

### Main Functions

- `parse(String) -> Document` - Parse HTML and return a Document
- `parse_with_errors(String) -> (Document, Array[ParseError])` - Parse with error collection
- `parse_with_scripting(String) -> Document` - Parse with scripting enabled (affects `<noscript>`)
- `tokenize(String) -> (Array[Token], Array[ParseError])` - Tokenize without tree construction

### Document Methods

- `dump() -> String` - Pretty-print the document tree
- `to_html() -> String` - Serialize to HTML string
- `get_children(Int) -> Array[Int]` - Get child node IDs
- `get_parent(Int) -> Int` - Get parent node ID
- `get_tag_name(Int) -> String?` - Get element tag name
- `get_attribute(Int, String) -> String?` - Get attribute value
- `get_text_content(Int) -> String` - Get text content of a node
