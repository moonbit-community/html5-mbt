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
/// 25 tree construction insertion modes (WHATWG 13.2.6)
pub(all) enum InsertionMode {
  Initial
  BeforeHtml
  BeforeHead
  InHead
  InHeadNoscript
  AfterHead
  InBody
  Text
  InTable
  InTableText
  InCaption
  InColumnGroup
  InTableBody
  InRow
  InCell
  InSelect
  InSelectInTable
  InTemplate
  AfterBody
  InFrameset
  AfterFrameset
  AfterAfterBody
  AfterAfterFrameset
  // Special modes for foreign content
  InForeignContent
}

///|
/// Entry in the stack of open elements
pub struct StackEntry {
  node_id : Int
  tag_name : String
  ns : Namespace
}

///|
/// Marker or Element entry in the active formatting elements list
pub enum FormattingEntry {
  Marker
  Element(
    node_id~ : Int,
    tag_name~ : String,
    attributes~ : Array[(String, String)]
  )
}

///|
/// The HTML tree builder (WHATWG 13.2.6)
pub struct TreeBuilder {
  tokenizer : Tokenizer
  document : Document
  // Stack of open elements (WHATWG 13.2.4.2)
  open_elements : Array[StackEntry]
  // Active formatting elements (WHATWG 13.2.4.3)
  active_formatting : Array[FormattingEntry]
  // Current insertion mode
  mut mode : InsertionMode
  // Original insertion mode (for "text" and "in table text" modes)
  mut original_mode : InsertionMode
  // Template insertion modes stack
  template_modes : Array[InsertionMode]
  // Head element pointer
  mut head_element : Int
  // Form element pointer
  mut form_element : Int
  // Scripting flag (for noscript handling)
  scripting : Bool
  // Frameset-ok flag
  mut frameset_ok : Bool
  // Foster parenting mode
  mut foster_parenting : Bool
  // Pending table character tokens
  pending_table_chars : Array[Char]
  // Skip newline flag after <pre>, <textarea>, <listing>
  mut skip_next_newline : Bool
  // Parsing errors
  errors : Array[ParseError]
}

///|
/// Create a new tree builder for parsing HTML
pub fn TreeBuilder::new(html : String) -> TreeBuilder {
  {
    tokenizer: Tokenizer::new(html),
    document: Document::new(),
    open_elements: [],
    active_formatting: [],
    mode: Initial,
    original_mode: Initial,
    template_modes: [],
    head_element: NO_NODE,
    form_element: NO_NODE,
    scripting: false,
    frameset_ok: true,
    foster_parenting: false,
    pending_table_chars: [],
    skip_next_newline: false,
    errors: [],
  }
}

///|
/// Parse the document and return it
pub fn TreeBuilder::parse(self : TreeBuilder) -> Document {
  // Main parsing loop
  while true {
    let mut token = self.tokenizer.next_token()
    // Process token, reprocessing if needed
    while true {
      let reprocess = self.process_token(token)
      if not(reprocess) {
        break
      }
      // Reprocess same token in new mode
    }
    // Handle EOF
    match token {
      EOF => break
      _ => ()
    }
  }
  // Collect tokenizer errors
  for err in self.tokenizer.errors {
    self.errors.push(err)
  }
  self.document
}

///|
/// Process a token in the current insertion mode
/// Returns true if the token should be reprocessed
fn TreeBuilder::process_token(self : TreeBuilder, token : Token) -> Bool {
  // Check for foreign content processing
  if self.should_process_in_foreign_content(token) {
    return self.process_in_foreign_content(token)
  }
  // Dispatch to current insertion mode
  match self.mode {
    Initial => self.process_initial_mode(token)
    BeforeHtml => self.process_before_html_mode(token)
    BeforeHead => self.process_before_head_mode(token)
    InHead => self.process_in_head_mode(token)
    InHeadNoscript => self.process_in_head_noscript_mode(token)
    AfterHead => self.process_after_head_mode(token)
    InBody => self.process_in_body_mode(token)
    Text => self.process_text_mode(token)
    InTable => self.process_in_table_mode(token)
    InTableText => self.process_in_table_text_mode(token)
    InCaption => self.process_in_caption_mode(token)
    InColumnGroup => self.process_in_column_group_mode(token)
    InTableBody => self.process_in_table_body_mode(token)
    InRow => self.process_in_row_mode(token)
    InCell => self.process_in_cell_mode(token)
    InSelect => self.process_in_select_mode(token)
    InSelectInTable => self.process_in_select_in_table_mode(token)
    InTemplate => self.process_in_template_mode(token)
    AfterBody => self.process_after_body_mode(token)
    InFrameset => self.process_in_frameset_mode(token)
    AfterFrameset => self.process_after_frameset_mode(token)
    AfterAfterBody => self.process_after_after_body_mode(token)
    AfterAfterFrameset => self.process_after_after_frameset_mode(token)
    InForeignContent => self.process_in_foreign_content(token)
  }
}

///|
/// Check if we should process token in foreign content
fn TreeBuilder::should_process_in_foreign_content(
  self : TreeBuilder,
  token : Token,
) -> Bool {
  // If stack is empty or current node is HTML, don't use foreign content
  if self.open_elements.is_empty() {
    return false
  }
  let current = self.current_node()
  if current.ns == HTML {
    return false
  }
  // Check for MathML text integration point
  if self.is_mathml_text_integration_point(current) {
    match token {
      StartTag(name~, ..) =>
        if name != "mglyph" && name != "malignmark" {
          return false
        }
      Character(_) => return false
      _ => ()
    }
  }
  // Check for annotation-xml with encoding
  if current.tag_name == "annotation-xml" && current.ns == MathML {
    match token {
      StartTag(name~, ..) if name == "svg" => return false
      _ => ()
    }
  }
  // Check for HTML integration point
  if self.is_html_integration_point(current) {
    match token {
      StartTag(_) => return false
      Character(_) => return false
      _ => ()
    }
  }
  // EOF always processed by current mode
  match token {
    EOF => return false
    _ => ()
  }
  true
}

///|
/// Check if element is a MathML text integration point
fn TreeBuilder::is_mathml_text_integration_point(
  self : TreeBuilder,
  entry : StackEntry,
) -> Bool {
  entry.ns == MathML &&
  (
    entry.tag_name == "mi" ||
    entry.tag_name == "mo" ||
    entry.tag_name == "mn" ||
    entry.tag_name == "ms" ||
    entry.tag_name == "mtext"
  )
}

///|
/// Check if element is an HTML integration point
fn TreeBuilder::is_html_integration_point(
  self : TreeBuilder,
  entry : StackEntry,
) -> Bool {
  // SVG foreignObject, desc, title
  if entry.ns == SVG {
    return entry.tag_name == "foreignObject" ||
      entry.tag_name == "desc" ||
      entry.tag_name == "title"
  }
  // MathML annotation-xml with text/html or application/xhtml+xml encoding
  if entry.ns == MathML && entry.tag_name == "annotation-xml" {
    match self.document.get_attribute(entry.node_id, "encoding") {
      Some(enc) => {
        let lower_enc = enc.to_lower()
        return lower_enc == "text/html" || lower_enc == "application/xhtml+xml"
      }
      None => return false
    }
  }
  false
}

// ============================================================================
// Stack of Open Elements operations (WHATWG 13.2.4.2)
// ============================================================================

///|
/// Get the current node (last element in stack)
pub fn TreeBuilder::current_node(self : TreeBuilder) -> StackEntry {
  self.open_elements[self.open_elements.length() - 1]
}

///|
/// Get the adjusted current node (for fragment parsing)
pub fn TreeBuilder::adjusted_current_node(self : TreeBuilder) -> StackEntry {
  // For fragment parsing, if there's only one element and it's the context element,
  // the adjusted current node is the context element
  // For now, just return current node
  self.current_node()
}

///|
/// Push an element onto the stack
pub fn TreeBuilder::push_element(
  self : TreeBuilder,
  node_id : Int,
  tag_name : String,
  ns : Namespace,
) -> Unit {
  self.open_elements.push({ node_id, tag_name, ns })
}

///|
/// Pop the current element from the stack
pub fn TreeBuilder::pop_element(self : TreeBuilder) -> StackEntry {
  self.open_elements.pop().unwrap()
}

///|
/// Pop elements until we find one with the given tag name
pub fn TreeBuilder::pop_until(self : TreeBuilder, tag_name : String) -> Unit {
  while self.open_elements.length() > 0 {
    let entry = self.pop_element()
    if entry.tag_name == tag_name {
      break
    }
  }
}

///|
/// Pop elements until we find one matching any of the given tags
pub fn TreeBuilder::pop_until_any(
  self : TreeBuilder,
  tags : Array[String],
) -> Unit {
  while self.open_elements.length() > 0 {
    let entry = self.pop_element()
    if tags.contains(entry.tag_name) {
      break
    }
  }
}

///|
/// Check if an element with the given tag is in scope
pub fn TreeBuilder::in_scope(
  self : TreeBuilder,
  tag_name : String,
  scope_elements : Array[String],
) -> Bool {
  for i = self.open_elements.length() - 1; i >= 0; i = i - 1 {
    let entry = self.open_elements[i]
    if entry.tag_name == tag_name && entry.ns == HTML {
      return true
    }
    if scope_elements.contains(entry.tag_name) && entry.ns == HTML {
      return false
    }
  }
  false
}

///|
/// Default scope elements for "in scope" checks
fn default_scope_elements() -> Array[String] {
  [
    "applet", "caption", "html", "table", "td", "th", "marquee", "object", "template",
  ]
}

///|
/// Check if tag is in default scope
pub fn TreeBuilder::in_default_scope(
  self : TreeBuilder,
  tag_name : String,
) -> Bool {
  self.in_scope(tag_name, default_scope_elements())
}

///|
/// Button scope elements
fn button_scope_elements() -> Array[String] {
  let mut elems = default_scope_elements()
  elems.push("button")
  elems
}

///|
/// Check if tag is in button scope
pub fn TreeBuilder::in_button_scope(
  self : TreeBuilder,
  tag_name : String,
) -> Bool {
  self.in_scope(tag_name, button_scope_elements())
}

///|
/// List item scope elements
fn list_item_scope_elements() -> Array[String] {
  let mut elems = default_scope_elements()
  elems.push("ol")
  elems.push("ul")
  elems
}

///|
/// Check if tag is in list item scope
pub fn TreeBuilder::in_list_item_scope(
  self : TreeBuilder,
  tag_name : String,
) -> Bool {
  self.in_scope(tag_name, list_item_scope_elements())
}

///|
/// Table scope elements
fn table_scope_elements() -> Array[String] {
  ["html", "table", "template"]
}

///|
/// Check if tag is in table scope
pub fn TreeBuilder::in_table_scope(
  self : TreeBuilder,
  tag_name : String,
) -> Bool {
  self.in_scope(tag_name, table_scope_elements())
}

///|
/// Select scope - everything except optgroup and option
pub fn TreeBuilder::in_select_scope(
  self : TreeBuilder,
  tag_name : String,
) -> Bool {
  for i = self.open_elements.length() - 1; i >= 0; i = i - 1 {
    let entry = self.open_elements[i]
    if entry.tag_name == tag_name && entry.ns == HTML {
      return true
    }
    if entry.tag_name != "optgroup" && entry.tag_name != "option" {
      return false
    }
  }
  false
}

///|
/// Check if the stack has an element with the given tag name
pub fn TreeBuilder::has_element_in_stack(
  self : TreeBuilder,
  tag_name : String,
) -> Bool {
  for entry in self.open_elements {
    if entry.tag_name == tag_name && entry.ns == HTML {
      return true
    }
  }
  false
}

///|
/// Remove an element from the stack by node id
pub fn TreeBuilder::remove_from_stack(
  self : TreeBuilder,
  node_id : Int,
) -> Unit {
  for i, entry in self.open_elements {
    if entry.node_id == node_id {
      let _ = self.open_elements.remove(i)
      break
    }
  }
}

// ============================================================================
// Element creation and insertion (WHATWG 13.2.6.1)
// ============================================================================

///|
/// Create an element for a token and insert it
pub fn TreeBuilder::insert_element_for_token(
  self : TreeBuilder,
  name : String,
  attrs : Array[Attribute],
  ns : Namespace,
) -> Int {
  let attributes : Array[(String, String)] = attrs.map(fn(a) {
    (a.name, a.value)
  })
  let element = Element::new(name, ns, attributes)
  let node_id = self.document.add_node(ElementNode(element))
  // Insert into the appropriate location
  self.insert_node(node_id)
  // Push onto stack of open elements
  self.push_element(node_id, name, ns)
  // Update document pointers
  if ns == HTML {
    match name {
      "html" => self.document.document_element = node_id
      "head" => {
        self.document.head_element = node_id
        self.head_element = node_id
      }
      "body" => self.document.body_element = node_id
      _ => ()
    }
  }
  node_id
}

///|
/// Insert an HTML element
pub fn TreeBuilder::insert_html_element(
  self : TreeBuilder,
  name : String,
  attrs : Array[Attribute],
) -> Int {
  self.insert_element_for_token(name, attrs, HTML)
}

///|
/// Insert a foreign element
pub fn TreeBuilder::insert_foreign_element(
  self : TreeBuilder,
  name : String,
  attrs : Array[Attribute],
  ns : Namespace,
) -> Int {
  self.insert_element_for_token(name, attrs, ns)
}

///|
/// Insert a node at the appropriate insertion location
fn TreeBuilder::insert_node(self : TreeBuilder, node_id : Int) -> Unit {
  if self.foster_parenting && self.is_foster_parenting_required() {
    self.insert_node_foster_parenting(node_id)
  } else {
    let parent_id = self.appropriate_insertion_point()
    self.document.append_child(parent_id, node_id)
  }
}

///|
/// Get the appropriate insertion point
fn TreeBuilder::appropriate_insertion_point(self : TreeBuilder) -> Int {
  if self.open_elements.is_empty() {
    // Insert into document
    0
  } else {
    // Insert into current node
    self.current_node().node_id
  }
}

///|
/// Check if foster parenting is required
fn TreeBuilder::is_foster_parenting_required(self : TreeBuilder) -> Bool {
  if self.open_elements.is_empty() {
    return false
  }
  let current = self.current_node()
  current.tag_name == "table" ||
  current.tag_name == "tbody" ||
  current.tag_name == "tfoot" ||
  current.tag_name == "thead" ||
  current.tag_name == "tr"
}

///|
/// Insert a node using foster parenting (WHATWG 13.2.6.1)
fn TreeBuilder::insert_node_foster_parenting(
  self : TreeBuilder,
  node_id : Int,
) -> Unit {
  // Find the last table element in the stack
  let mut table_idx = -1
  for i = self.open_elements.length() - 1; i >= 0; i = i - 1 {
    if self.open_elements[i].tag_name == "table" {
      table_idx = i
      break
    }
  }
  if table_idx == -1 {
    // No table found, insert into first element (html)
    if self.open_elements.length() > 0 {
      let parent_id = self.open_elements[0].node_id
      self.document.append_child(parent_id, node_id)
    }
    return
  }
  // If table has a parent, insert before the table
  let table_node_id = self.open_elements[table_idx].node_id
  let parent = self.document.get_parent(table_node_id)
  if parent != NO_NODE {
    self.document.insert_before(parent, node_id, table_node_id)
  } else if table_idx > 0 {
    // Otherwise insert into the element immediately above table in the stack
    let foster_parent = self.open_elements[table_idx - 1].node_id
    self.document.append_child(foster_parent, node_id)
  }
}

///|
/// Insert a character node
pub fn TreeBuilder::insert_character(self : TreeBuilder, c : Char) -> Unit {
  let parent_id = self.appropriate_insertion_point()
  // Try to append to existing text node
  let children = self.document.get_children(parent_id)
  if children.length() > 0 {
    let last_child = children[children.length() - 1]
    match self.document.get_node(last_child) {
      Some(TextNode(text)) => {
        // Replace with new text node containing old text + new char
        let new_text = text + c.to_string()
        self.document.nodes[last_child] = TextNode(new_text)
        return
      }
      _ => ()
    }
  }
  // Create new text node
  let node_id = self.document.add_node(TextNode(c.to_string()))
  self.insert_node(node_id)
}

///|
/// Insert a comment node
pub fn TreeBuilder::insert_comment(self : TreeBuilder, text : String) -> Unit {
  let node_id = self.document.add_node(CommentNode(text))
  self.insert_node(node_id)
}

///|
/// Insert a comment at document level
pub fn TreeBuilder::insert_comment_at_document(
  self : TreeBuilder,
  text : String,
) -> Unit {
  let node_id = self.document.add_node(CommentNode(text))
  self.document.append_child(0, node_id)
}

///|
/// Insert a DOCTYPE node
pub fn TreeBuilder::insert_doctype(
  self : TreeBuilder,
  name : String?,
  public_id : String?,
  system_id : String?,
) -> Unit {
  let doctype_name = name.unwrap_or("html")
  let pub_id = public_id.unwrap_or("")
  let sys_id = system_id.unwrap_or("")
  let node_id = self.document.add_node(
    DocumentTypeNode(name=doctype_name, public_id=pub_id, system_id=sys_id),
  )
  self.document.append_child(0, node_id)
}

// ============================================================================
// Error handling
// ============================================================================

///|
/// Emit a parse error
pub fn TreeBuilder::emit_error(
  self : TreeBuilder,
  code : ParseErrorCode,
) -> Unit {
  self.errors.push({ code, position: self.tokenizer.get_position() })
}

// ============================================================================
// Generic RCDATA/RAWTEXT algorithm (WHATWG 13.2.6.2)
// ============================================================================

///|
/// Switch tokenizer to RCDATA and set up text mode parsing
pub fn TreeBuilder::parse_rcdata(
  self : TreeBuilder,
  name : String,
  attrs : Array[Attribute],
) -> Unit {
  let _ = self.insert_html_element(name, attrs)
  self.tokenizer.state = RCDATA
  self.original_mode = self.mode
  self.mode = Text
}

///|
/// Switch tokenizer to RAWTEXT and set up text mode parsing
pub fn TreeBuilder::parse_rawtext(
  self : TreeBuilder,
  name : String,
  attrs : Array[Attribute],
) -> Unit {
  let _ = self.insert_html_element(name, attrs)
  self.tokenizer.state = RAWTEXT
  self.original_mode = self.mode
  self.mode = Text
}

///|
/// Switch tokenizer to script data state
pub fn TreeBuilder::parse_script(
  self : TreeBuilder,
  name : String,
  attrs : Array[Attribute],
) -> Unit {
  let _ = self.insert_html_element(name, attrs)
  self.tokenizer.state = ScriptData
  self.original_mode = self.mode
  self.mode = Text
}

// ============================================================================
// Implied end tags (WHATWG 13.2.6.2)
// ============================================================================

///|
/// Elements with implied end tags
fn implied_end_tag_elements() -> Array[String] {
  ["dd", "dt", "li", "optgroup", "option", "p", "rb", "rp", "rt", "rtc"]
}

///|
/// Generate implied end tags (except for given tag)
pub fn TreeBuilder::generate_implied_end_tags(
  self : TreeBuilder,
  except : String,
) -> Unit {
  let implied = implied_end_tag_elements()
  while self.open_elements.length() > 0 {
    let current = self.current_node()
    if current.tag_name == except {
      break
    }
    if not(implied.contains(current.tag_name)) || current.ns != HTML {
      break
    }
    let _ = self.pop_element()

  }
}

///|
/// Generate all implied end tags
pub fn TreeBuilder::generate_all_implied_end_tags(self : TreeBuilder) -> Unit {
  self.generate_implied_end_tags("")
}

///|
/// Elements with implied end tags (thoroughly)
fn thorough_implied_end_tag_elements() -> Array[String] {
  [
    "caption", "colgroup", "dd", "dt", "li", "optgroup", "option", "p", "rb", "rp",
    "rt", "rtc", "tbody", "td", "tfoot", "th", "thead", "tr",
  ]
}

///|
/// Generate implied end tags thoroughly
pub fn TreeBuilder::generate_implied_end_tags_thoroughly(
  self : TreeBuilder,
) -> Unit {
  let implied = thorough_implied_end_tag_elements()
  while self.open_elements.length() > 0 {
    let current = self.current_node()
    if not(implied.contains(current.tag_name)) || current.ns != HTML {
      break
    }
    let _ = self.pop_element()

  }
}

// ============================================================================
// Reset insertion mode appropriately (WHATWG 13.2.4.1)
// ============================================================================

///|
/// Reset the insertion mode appropriately
pub fn TreeBuilder::reset_insertion_mode(self : TreeBuilder) -> Unit {
  for i = self.open_elements.length() - 1; i >= 0; i = i - 1 {
    let entry = self.open_elements[i]
    let is_last = i == 0
    // For fragment parsing, first node might be replaced
    match entry.tag_name {
      "select" => {
        if not(is_last) {
          // Walk up to find context
          for j = i - 1; j >= 0; j = j - 1 {
            let ancestor = self.open_elements[j]
            if ancestor.tag_name == "template" {
              break
            }
            if ancestor.tag_name == "table" {
              self.mode = InSelectInTable
              return
            }
          }
        }
        self.mode = InSelect
        return
      }
      "td" | "th" =>
        if not(is_last) {
          self.mode = InCell
          return
        }
      "tr" => {
        self.mode = InRow
        return
      }
      "tbody" | "thead" | "tfoot" => {
        self.mode = InTableBody
        return
      }
      "caption" => {
        self.mode = InCaption
        return
      }
      "colgroup" => {
        self.mode = InColumnGroup
        return
      }
      "table" => {
        self.mode = InTable
        return
      }
      "template" => {
        if self.template_modes.length() > 0 {
          self.mode = self.template_modes[self.template_modes.length() - 1]
        } else {
          self.mode = InTemplate
        }
        return
      }
      "head" =>
        if not(is_last) {
          self.mode = InHead
          return
        }
      "body" => {
        self.mode = InBody
        return
      }
      "frameset" => {
        self.mode = InFrameset
        return
      }
      "html" => {
        if self.head_element == NO_NODE {
          self.mode = BeforeHead
        } else {
          self.mode = AfterHead
        }
        return
      }
      _ => ()
    }
    if is_last {
      self.mode = InBody
      return
    }
  }
}

// ============================================================================
// Acknowledge self-closing flag
// ============================================================================

///|
/// Acknowledge self-closing flag (suppresses error)
pub fn TreeBuilder::acknowledge_self_closing(
  self : TreeBuilder,
  _token : Token,
) -> Unit {
  // If the token is a start tag with self-closing flag, we acknowledge it
  // This suppresses the "non-void element with trailing solidus" error
  ()
}

// ============================================================================
// Parse function - main entry point
// ============================================================================

///|
/// Parse an HTML string and return the document
pub fn parse(html : String) -> Document {
  let builder = TreeBuilder::new(html)
  builder.parse()
}

///|
/// Parse an HTML string and return the document with errors
pub fn parse_with_errors(html : String) -> (Document, Array[ParseError]) {
  let builder = TreeBuilder::new(html)
  let doc = builder.parse()
  (doc, builder.errors)
}
