// Copyright 2025 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
/// Smoke tests to verify basic parser functionality
/// Run with: moon test -f smoke

///|
test "smoke/tokenizer/simple_text" {
  let (tokens, _) = tokenize("Hello")
  inspect(
    tokens,
    content="[Character('H'), Character('e'), Character('l'), Character('l'), Character('o'), EOF]",
  )
}

///|
test "smoke/tokenizer/simple_tag" {
  let (tokens, _) = tokenize("<div>")
  inspect(
    tokens,
    content="[StartTag(name=\"div\", attrs=[], self_closing=false), EOF]",
  )
}

///|
test "smoke/tokenizer/tag_with_text" {
  let (tokens, _) = tokenize("<p>Hello</p>")
  inspect(
    tokens,
    content="[StartTag(name=\"p\", attrs=[], self_closing=false), Character('H'), Character('e'), Character('l'), Character('l'), Character('o'), EndTag(name=\"p\"), EOF]",
  )
}

///|
test "smoke/tokenizer/self_closing" {
  let (tokens, _) = tokenize("<br/>")
  inspect(
    tokens,
    content="[StartTag(name=\"br\", attrs=[], self_closing=true), EOF]",
  )
}

///|
test "smoke/tokenizer/attribute" {
  let (tokens, _) = tokenize("<div class=\"foo\">")
  inspect(
    tokens,
    content="[StartTag(name=\"div\", attrs=[{name: \"class\", value: \"foo\"}], self_closing=false), EOF]",
  )
}

///|
test "smoke/tokenizer/comment" {
  let (tokens, _) = tokenize("<!-- comment -->")
  inspect(tokens, content="[Comment(\" comment \"), EOF]")
}

///|
test "smoke/tokenizer/doctype" {
  let (tokens, _) = tokenize("<!DOCTYPE html>")
  inspect(
    tokens,
    content="[DOCTYPE(name=Some(\"html\"), public_id=None, system_id=None, force_quirks=false), EOF]",
  )
}

///|
test "smoke/tree/simple_html" {
  let doc = parse("<html><head></head><body></body></html>")
  // Just verify it doesn't crash and creates nodes
  inspect(doc.nodes.length() > 0, content="true")
}

///|
test "smoke/tree/implicit_html" {
  let doc = parse("<p>Hello</p>")
  // Parser should create implicit html, head, body
  inspect(doc.nodes.length() > 0, content="true")
}

///|
test "smoke/tree/basic_structure" {
  let doc = parse(
    "<!DOCTYPE html><html><head><title>Test</title></head><body><p>Hello</p></body></html>",
  )
  inspect(doc.nodes.length() > 0, content="true")
}

///|
test "smoke/tree/script_unclosed_with_comment" {
  // Regression test for reprocess loop bug
  let doc = parse("<script><!--<")
  inspect(doc.nodes.length() > 0, content="true")
}

///|
test "smoke/tree/adoption_agency" {
  // Test adoption agency algorithm produces correct tree
  let doc = parse("<a><p></a></p>")
  inspect(
    doc.dump(),
    content=(
      #|<html>
      #|  <head>
      #|  <body>
      #|    <a>
      #|    <p>
      #|      <a>
    ),
  )
}

///|
test "smoke/tree/foster_parenting" {
  let doc = parse("<table><a>1<p>2</a>3</p>")
  inspect(
    doc.dump(),
    content=(
      #|<html>
      #|  <head>
      #|  <body>
      #|    <a>
      #|      "1"
      #|    <p>
      #|      <a>
      #|        "2"
      #|      "3"
      #|    <table>
    ),
  )
}

///|
test "smoke/tree/malformed_end_tag" {
  // Test end tag with attribute-like content (no closing >)
  let doc = parse("</b test")
  inspect(doc.nodes.length() > 0, content="true")
}

///|
test "smoke/tree/script_with_style_endtag" {
  let doc = parse("<script></style></script>")
  inspect(
    doc.dump(),
    content=(
      #|<html>
      #|  <head>
      #|    <script>
      #|      "</style>"
      #|  <body>
    ),
  )
}

///|
test "smoke/tree/malformed_url_tag" {
  let doc = parse("<rdar://problem/6869687>")
  inspect(
    doc.dump(),
    content=(
      #|<html>
      #|  <head>
      #|  <body>
      #|    <rdar:>
      #|      6869687=""
      #|      problem=""
    ),
  )
}

///|
test "smoke/tree/body_attr_merge" {
  let doc = parse("<body foo='bar'><body foo='baz' yo='mama'>")
  inspect(
    doc.dump(),
    content=(
      #|<html>
      #|  <head>
      #|  <body>
      #|    foo="bar"
      #|    yo="mama"
    ),
  )
}
