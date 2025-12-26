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
/// Node index for O(1) parent/sibling access (using Int directly)
/// Sentinel value NO_NODE = -1 indicates "no node"
pub const NO_NODE : Int = -1

///|
/// DOM Element node
pub struct Element {
  tag_name : String
  ns : Namespace
  attributes : Array[(String, String)]
  children : Array[Int]
  mut parent : Int
  // HTML-specific flags for integration points
  is_html_integration_point : Bool
  is_mathml_text_integration_point : Bool
  // Template content (node ID of DocumentFragment, or NO_NODE)
  mut template_content : Int
} derive(Show)

///|
/// Create a new Element
pub fn Element::new(
  tag_name : String,
  ns : Namespace,
  attributes : Array[(String, String)],
) -> Element {
  {
    tag_name,
    ns,
    attributes,
    children: [],
    parent: NO_NODE,
    is_html_integration_point: false,
    is_mathml_text_integration_point: false,
    template_content: NO_NODE,
  }
}

///|
/// DOM Node - sum type for all node kinds
pub enum Node {
  ElementNode(Element)
  TextNode(String)
  CommentNode(String)
  DocumentTypeNode(name~ : String, public_id~ : String, system_id~ : String)
  DocumentNode(children~ : Array[Int])
  DocumentFragmentNode(children~ : Array[Int])
} derive(Show)

///|
/// The complete document owns all nodes in a flat array
pub struct Document {
  nodes : Array[Node]
  // Quick access indices
  mut document_element : Int // The <html> element
  mut head_element : Int // The <head> element
  mut body_element : Int // The <body> element
  // Document mode (quirks, limited-quirks, no-quirks)
  mut quirks_mode : QuirksMode
} derive(Show)

///|
/// Create a new empty document
pub fn Document::new() -> Document {
  let doc = {
    nodes: [],
    document_element: NO_NODE,
    head_element: NO_NODE,
    body_element: NO_NODE,
    quirks_mode: NoQuirks,
  }
  // Add the document node as node 0
  doc.nodes.push(DocumentNode(children=[]))
  doc
}

///|
/// Get a node by ID
pub fn Document::get_node(self : Document, id : Int) -> Node? {
  if id >= 0 && id < self.nodes.length() {
    Some(self.nodes[id])
  } else {
    None
  }
}

///|
/// Get an element by ID (returns None if not an element)
pub fn Document::get_element(self : Document, id : Int) -> Element? {
  match self.get_node(id) {
    Some(ElementNode(elem)) => Some(elem)
    _ => None
  }
}

///|
/// Add a new node and return its ID
pub fn Document::add_node(self : Document, node : Node) -> Int {
  let id = self.nodes.length()
  self.nodes.push(node)
  id
}

///|
/// Append a child node to a parent
pub fn Document::append_child(
  self : Document,
  parent_id : Int,
  child_id : Int,
) -> Unit {
  // Set child's parent
  match self.nodes[child_id] {
    ElementNode(elem) => elem.parent = parent_id
    _ => ()
  }
  // Add to parent's children
  match self.nodes[parent_id] {
    ElementNode(elem) => elem.children.push(child_id)
    DocumentNode(children~) => children.push(child_id)
    DocumentFragmentNode(children~) => children.push(child_id)
    _ => ()
  }
}

///|
/// Insert a child node before another child
pub fn Document::insert_before(
  self : Document,
  parent_id : Int,
  child_id : Int,
  reference_id : Int,
) -> Unit {
  // Set child's parent
  match self.nodes[child_id] {
    ElementNode(elem) => elem.parent = parent_id
    _ => ()
  }
  // Find reference position and insert
  match self.nodes[parent_id] {
    ElementNode(elem) => {
      let mut idx = elem.children.length()
      for i, id in elem.children {
        if id == reference_id {
          idx = i
          break
        }
      }
      elem.children.insert(idx, child_id)
    }
    DocumentNode(children~) => {
      let mut idx = children.length()
      for i, id in children {
        if id == reference_id {
          idx = i
          break
        }
      }
      children.insert(idx, child_id)
    }
    DocumentFragmentNode(children~) => {
      let mut idx = children.length()
      for i, id in children {
        if id == reference_id {
          idx = i
          break
        }
      }
      children.insert(idx, child_id)
    }
    _ => ()
  }
}

///|
/// Remove a child from its parent
pub fn Document::remove_child(
  self : Document,
  parent_id : Int,
  child_id : Int,
) -> Unit {
  match self.nodes[parent_id] {
    ElementNode(elem) =>
      for i, id in elem.children {
        if id == child_id {
          let _ = elem.children.remove(i)
          break
        }
      }
    DocumentNode(children~) =>
      for i, id in children {
        if id == child_id {
          let _ = children.remove(i)
          break
        }
      }
    _ => ()
  }
  // Clear parent reference
  match self.nodes[child_id] {
    ElementNode(elem) => elem.parent = NO_NODE
    _ => ()
  }
}

///|
/// Get the tag name of an element node
pub fn Document::get_tag_name(self : Document, id : Int) -> String? {
  match self.get_node(id) {
    Some(ElementNode(elem)) => Some(elem.tag_name)
    _ => None
  }
}

///|
/// Get the namespace of an element node
pub fn Document::get_ns(self : Document, id : Int) -> Namespace? {
  match self.get_node(id) {
    Some(ElementNode(elem)) => Some(elem.ns)
    _ => None
  }
}

///|
/// Check if a node is an element with the given tag name and namespace
pub fn Document::is_element(
  self : Document,
  id : Int,
  tag_name : String,
  ns : Namespace,
) -> Bool {
  match self.get_node(id) {
    Some(ElementNode(elem)) => elem.tag_name == tag_name && elem.ns == ns
    _ => false
  }
}

///|
/// Check if a node is an HTML element with the given tag name
pub fn Document::is_html_element(
  self : Document,
  id : Int,
  tag_name : String,
) -> Bool {
  self.is_element(id, tag_name, HTML)
}

///|
/// Get an attribute value from an element
pub fn Document::get_attribute(
  self : Document,
  id : Int,
  attr_name : String,
) -> String? {
  match self.get_node(id) {
    Some(ElementNode(elem)) => {
      for pair in elem.attributes {
        if pair.0 == attr_name {
          return Some(pair.1)
        }
      }
      None
    }
    _ => None
  }
}

///|
/// Set an attribute on an element
pub fn Document::set_attribute(
  self : Document,
  id : Int,
  attr_name : String,
  attr_value : String,
) -> Unit {
  match self.nodes[id] {
    ElementNode(elem) => {
      // Check if attribute exists
      for i, pair in elem.attributes {
        if pair.0 == attr_name {
          elem.attributes[i] = (attr_name, attr_value)
          return
        }
      }
      // Add new attribute
      elem.attributes.push((attr_name, attr_value))
    }
    _ => ()
  }
}

///|
/// Get the parent of a node
pub fn Document::get_parent(self : Document, id : Int) -> Int {
  match self.get_node(id) {
    Some(ElementNode(elem)) => elem.parent
    _ => NO_NODE
  }
}

///|
/// Get the template content of a template element
pub fn Document::get_template_content(self : Document, id : Int) -> Int {
  match self.get_node(id) {
    Some(ElementNode(elem)) => elem.template_content
    _ => NO_NODE
  }
}

///|
/// Get children of a node
pub fn Document::get_children(self : Document, id : Int) -> Array[Int] {
  match self.get_node(id) {
    Some(ElementNode(elem)) => elem.children.copy()
    Some(DocumentNode(children~)) => children.copy()
    Some(DocumentFragmentNode(children~)) => children.copy()
    _ => []
  }
}

///|
/// Check if an element has a specific attribute
pub fn Document::has_attribute(
  self : Document,
  id : Int,
  attr_name : String,
) -> Bool {
  self.get_attribute(id, attr_name) is Some(_)
}

///|
/// Get text content of a node (concatenation of all text descendants)
pub fn Document::get_text_content(self : Document, id : Int) -> String {
  let buf = StringBuilder::new()
  self.collect_text_content(id, buf)
  buf.to_string()
}

///|
fn Document::collect_text_content(
  self : Document,
  id : Int,
  buf : StringBuilder,
) -> Unit {
  match self.get_node(id) {
    Some(TextNode(text)) => buf.write_string(text)
    Some(ElementNode(elem)) =>
      for child_id in elem.children {
        self.collect_text_content(child_id, buf)
      }
    Some(DocumentNode(children~)) | Some(DocumentFragmentNode(children~)) =>
      for child_id in children {
        self.collect_text_content(child_id, buf)
      }
    _ => ()
  }
}

///|
/// Serialize document to HTML string
pub fn Document::to_html(self : Document) -> String {
  let buf = StringBuilder::new()
  // Start from document children
  match self.nodes[0] {
    DocumentNode(children~) =>
      for child_id in children {
        self.serialize_node(child_id, buf)
      }
    _ => ()
  }
  buf.to_string()
}

///|
fn Document::serialize_node(
  self : Document,
  id : Int,
  buf : StringBuilder,
) -> Unit {
  match self.get_node(id) {
    Some(DocumentTypeNode(name~, ..)) => {
      buf.write_string("<!DOCTYPE ")
      buf.write_string(name)
      buf.write_string(">")
    }
    Some(TextNode(text)) => buf.write_string(escape_html_text(text))
    Some(CommentNode(text)) => {
      buf.write_string("<!--")
      buf.write_string(text)
      buf.write_string("-->")
    }
    Some(ElementNode(elem)) => {
      buf.write_string("<")
      buf.write_string(elem.tag_name)
      for pair in elem.attributes {
        buf.write_string(" ")
        buf.write_string(pair.0)
        buf.write_string("=\"")
        buf.write_string(escape_html_attr(pair.1))
        buf.write_string("\"")
      }
      if is_void_element(elem.tag_name) && elem.children.length() == 0 {
        buf.write_string(">")
      } else {
        buf.write_string(">")
        for child_id in elem.children {
          self.serialize_node(child_id, buf)
        }
        buf.write_string("</")
        buf.write_string(elem.tag_name)
        buf.write_string(">")
      }
    }
    _ => ()
  }
}

///|
/// Check if tag is a void element (no closing tag)
fn is_void_element(tag : String) -> Bool {
  match tag {
    "area"
    | "base"
    | "br"
    | "col"
    | "embed"
    | "hr"
    | "img"
    | "input"
    | "link"
    | "meta"
    | "param"
    | "source"
    | "track"
    | "wbr" => true
    _ => false
  }
}

///|
/// Escape HTML text content
fn escape_html_text(s : String) -> String {
  let buf = StringBuilder::new()
  for c in s {
    match c {
      '&' => buf.write_string("&amp;")
      '<' => buf.write_string("&lt;")
      '>' => buf.write_string("&gt;")
      _ => buf.write_char(c)
    }
  }
  buf.to_string()
}

///|
/// Escape HTML attribute value
fn escape_html_attr(s : String) -> String {
  let buf = StringBuilder::new()
  for c in s {
    match c {
      '&' => buf.write_string("&amp;")
      '"' => buf.write_string("&quot;")
      _ => buf.write_char(c)
    }
  }
  buf.to_string()
}

///|
/// Dump document in html5lib-tests format for conformance testing
pub fn Document::dump(self : Document) -> String {
  let buf = StringBuilder::new()
  // Start from document children (node 0 is the document)
  match self.nodes[0] {
    DocumentNode(children~) =>
      for child_id in children {
        self.dump_node(child_id, 0, buf)
      }
    _ => ()
  }
  // Remove trailing newline to match html5lib-tests format
  let s = buf.to_string()
  let len = s.length()
  if len > 0 && s[len - 1] == 10 { // '\n' == 10
    // Build string without trailing newline
    let buf2 = StringBuilder::new()
    for i = 0; i < len - 1; i = i + 1 {
      buf2.write_char(Int::unsafe_to_char(s[i].to_int()))
    }
    buf2.to_string()
  } else {
    s
  }
}

///|
fn Document::dump_node(
  self : Document,
  id : Int,
  depth : Int,
  buf : StringBuilder,
) -> Unit {
  // Prevent infinite recursion from malformed trees
  if depth > 100 {
    return
  }
  let indent = String::make(depth * 2, ' ')
  match self.get_node(id) {
    Some(DocumentTypeNode(name~, public_id~, system_id~)) => {
      buf.write_string(indent)
      buf.write_string("<!DOCTYPE ")
      buf.write_string(name)
      if public_id != "" || system_id != "" {
        buf.write_string(" \"")
        buf.write_string(public_id)
        buf.write_string("\" \"")
        buf.write_string(system_id)
        buf.write_string("\"")
      }
      buf.write_string(">\n")
    }
    Some(CommentNode(text)) => {
      buf.write_string(indent)
      buf.write_string("<!-- ")
      buf.write_string(text)
      buf.write_string(" -->\n")
    }
    Some(TextNode(text)) => {
      buf.write_string(indent)
      buf.write_string("\"")
      buf.write_string(escape_dump_text(text))
      buf.write_string("\"\n")
    }
    Some(ElementNode(elem)) => {
      buf.write_string(indent)
      buf.write_string("<")
      // Add namespace prefix for non-HTML elements (inside angle brackets)
      match elem.ns {
        SVG => buf.write_string("svg ")
        MathML => buf.write_string("math ")
        HTML => ()
      }
      buf.write_string(elem.tag_name)
      buf.write_string(">\n")
      // Dump attributes in sorted order (html5lib-tests requirement)
      // Use lexicographic comparison (MoonBit's String.compare sorts by length first)
      let attrs = elem.attributes.copy()
      attrs.sort_by(fn(a, b) { lex_compare(a.0, b.0) })
      let attr_indent = String::make((depth + 1) * 2, ' ')
      for pair in attrs {
        buf.write_string(attr_indent)
        buf.write_string(pair.0)
        buf.write_string("=\"")
        buf.write_string(pair.1)
        buf.write_string("\"\n")
      }
      // For template elements, dump "content" and its children
      if elem.tag_name == "template" && elem.template_content != NO_NODE {
        let content_indent = String::make((depth + 1) * 2, ' ')
        buf.write_string(content_indent)
        buf.write_string("content\n")
        // Dump the template content's children
        match self.get_node(elem.template_content) {
          Some(DocumentFragmentNode(children~)) =>
            for child_id in children {
              self.dump_node(child_id, depth + 2, buf)
            }
          _ => ()
        }
      } else {
        // Dump regular children
        for child_id in elem.children {
          self.dump_node(child_id, depth + 1, buf)
        }
      }
    }
    _ => ()
  }
}

///|
/// Escape text for dump output (show control chars)
fn escape_dump_text(s : String) -> String {
  let buf = StringBuilder::new()
  for c in s {
    let code = c.to_int()
    if code == 0 {
      buf.write_string("\\u0000")
    } else if code >= 0x80 && code <= 0x9F {
      // C1 controls - escape as \u{XX} so they're visible
      buf.write_string("\\u{")
      buf.write_string(code.to_string(radix=16))
      buf.write_string("}")
    } else {
      buf.write_char(c)
    }
  }
  buf.to_string()
}

///|
/// Lexicographic string comparison (MoonBit's String.compare uses length-first)
fn lex_compare(a : String, b : String) -> Int {
  let a_len = a.length()
  let b_len = b.length()
  let min_len = if a_len < b_len { a_len } else { b_len }
  for i = 0; i < min_len; i = i + 1 {
    let a_char = a[i].to_int()
    let b_char = b[i].to_int()
    if a_char < b_char {
      return -1
    }
    if a_char > b_char {
      return 1
    }
  }
  // All common characters are equal, compare by length
  if a_len < b_len {
    -1
  } else if a_len > b_len {
    1
  } else {
    0
  }
}
