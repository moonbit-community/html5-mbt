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

// ============================================================================
// WHATWG 13.2.6.4 Tree construction dispatcher - Insertion modes
// ============================================================================

///|
/// 13.2.6.4.1 Initial insertion mode
fn TreeBuilder::process_initial_mode(self : TreeBuilder, token : Token) -> Bool {
  match token {
    Character(c) if is_whitespace_char(c) =>
      // Ignore whitespace
      false
    Comment(text) => {
      self.insert_comment_at_document(text)
      false
    }
    DOCTYPE(name~, public_id~, system_id~, force_quirks~) => {
      // Check for parse errors
      if name != Some("html") ||
        public_id is Some(_) ||
        (system_id is Some(_) && system_id != Some("about:legacy-compat")) {
        self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      }
      self.insert_doctype(name, public_id, system_id)
      // Set document mode (quirks detection per WHATWG 13.2.6.4.1)
      self.document.quirks_mode = self.determine_quirks_mode(
        name,
        public_id,
        system_id,
        force_quirks,
      )
      self.mode = BeforeHtml
      false
    }
    _ => {
      // Parse error: no DOCTYPE - set quirks mode per WHATWG 13.2.6.4.1
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      self.document.quirks_mode = Quirks
      self.mode = BeforeHtml
      true // Reprocess
    }
  }
}

///|
/// 13.2.6.4.2 Before html insertion mode
fn TreeBuilder::process_before_html_mode(
  self : TreeBuilder,
  token : Token,
) -> Bool {
  match token {
    DOCTYPE(_) => {
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      false
    }
    Comment(text) => {
      self.insert_comment_at_document(text)
      false
    }
    Character(c) if is_whitespace_char(c) =>
      // Ignore whitespace
      false
    StartTag(name~, attrs~, ..) if name == "html" => {
      let _ = self.insert_html_element(name, attrs)
      self.mode = BeforeHead
      false
    }
    EndTag(name~) if name == "head" ||
      name == "body" ||
      name == "html" ||
      name == "br" => {
      // Act as if a start tag "html" was seen
      let _ = self.insert_html_element("html", [])
      self.mode = BeforeHead
      true // Reprocess
    }
    EndTag(_) => {
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      false
    }
    _ => {
      // Create html element and reprocess
      let _ = self.insert_html_element("html", [])
      self.mode = BeforeHead
      true // Reprocess
    }
  }
}

///|
/// 13.2.6.4.3 Before head insertion mode
fn TreeBuilder::process_before_head_mode(
  self : TreeBuilder,
  token : Token,
) -> Bool {
  match token {
    Character(c) if is_whitespace_char(c) =>
      // Ignore whitespace
      false
    Comment(text) => {
      self.insert_comment(text)
      false
    }
    DOCTYPE(_) => {
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      false
    }
    StartTag(name~, attrs~, ..) if name == "html" =>
      // Process using InBody rules
      self.process_in_body_mode(token)
    StartTag(name~, attrs~, ..) if name == "head" => {
      let _ = self.insert_html_element(name, attrs)
      self.mode = InHead
      false
    }
    EndTag(name~) if name == "head" ||
      name == "body" ||
      name == "html" ||
      name == "br" => {
      // Insert head element and reprocess
      let _ = self.insert_html_element("head", [])
      self.mode = InHead
      true // Reprocess
    }
    EndTag(_) => {
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      false
    }
    _ => {
      // Insert head element and reprocess
      let _ = self.insert_html_element("head", [])
      self.mode = InHead
      true // Reprocess
    }
  }
}

///|
/// 13.2.6.4.4 In head insertion mode
fn TreeBuilder::process_in_head_mode(self : TreeBuilder, token : Token) -> Bool {
  match token {
    Character(c) if is_whitespace_char(c) => {
      self.insert_character(c)
      false
    }
    Comment(text) => {
      self.insert_comment(text)
      false
    }
    DOCTYPE(_) => {
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      false
    }
    StartTag(name~, attrs~, ..) if name == "html" =>
      self.process_in_body_mode(token)
    StartTag(name~, attrs~, ..) if name == "base" ||
      name == "basefont" ||
      name == "bgsound" ||
      name == "link" => {
      let _ = self.insert_html_element(name, attrs)
      let _ = self.pop_element()
      false
    }
    StartTag(name~, attrs~, ..) if name == "meta" => {
      let _ = self.insert_html_element(name, attrs)
      let _ = self.pop_element()
      // TODO: Check charset attribute
      false
    }
    StartTag(name~, attrs~, ..) if name == "title" => {
      self.parse_rcdata(name, attrs)
      false
    }
    StartTag(name~, attrs~, ..) if name == "noscript" && self.scripting => {
      self.parse_rawtext(name, attrs)
      false
    }
    StartTag(name~, attrs~, ..) if name == "noframes" || name == "style" => {
      self.parse_rawtext(name, attrs)
      false
    }
    StartTag(name~, attrs~, ..) if name == "noscript" && not(self.scripting) => {
      let _ = self.insert_html_element(name, attrs)
      self.mode = InHeadNoscript
      false
    }
    StartTag(name~, attrs~, ..) if name == "script" => {
      self.parse_script(name, attrs)
      false
    }
    EndTag(name~) if name == "head" => {
      let _ = self.pop_element()
      self.mode = AfterHead
      false
    }
    EndTag(name~) if name == "body" || name == "html" || name == "br" => {
      let _ = self.pop_element()
      self.mode = AfterHead
      true // Reprocess
    }
    StartTag(name~, attrs~, ..) if name == "template" => {
      let _ = self.insert_html_element(name, attrs)
      self.push_formatting_marker()
      self.frameset_ok = false
      self.mode = InTemplate
      self.template_modes.push(InTemplate)
      false
    }
    EndTag(name~) if name == "template" => {
      if not(self.has_element_in_stack("template")) {
        self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
        return false
      }
      self.generate_implied_end_tags_thoroughly()
      if self.current_node().tag_name != "template" {
        self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      }
      self.pop_until("template")
      self.clear_active_formatting_to_marker()
      let _ = self.template_modes.pop()
      self.reset_insertion_mode()
      false
    }
    StartTag(name~, ..) if name == "head" => {
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      false
    }
    EndTag(_) => {
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      false
    }
    _ => {
      let _ = self.pop_element()
      self.mode = AfterHead
      true // Reprocess
    }
  }
}

///|
/// 13.2.6.4.5 In head noscript insertion mode
fn TreeBuilder::process_in_head_noscript_mode(
  self : TreeBuilder,
  token : Token,
) -> Bool {
  match token {
    DOCTYPE(_) => {
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      false
    }
    StartTag(name~, ..) if name == "html" => self.process_in_body_mode(token)
    EndTag(name~) if name == "noscript" => {
      let _ = self.pop_element()
      self.mode = InHead
      false
    }
    Character(c) if is_whitespace_char(c) => self.process_in_head_mode(token)
    Comment(_) => self.process_in_head_mode(token)
    StartTag(name~, ..) if name == "basefont" ||
      name == "bgsound" ||
      name == "link" ||
      name == "meta" ||
      name == "noframes" ||
      name == "style" => self.process_in_head_mode(token)
    EndTag(name~) if name == "br" => {
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      let _ = self.pop_element()
      self.mode = InHead
      true // Reprocess
    }
    StartTag(name~, ..) if name == "head" || name == "noscript" => {
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      false
    }
    EndTag(_) => {
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      false
    }
    _ => {
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      let _ = self.pop_element()
      self.mode = InHead
      true // Reprocess
    }
  }
}

///|
/// 13.2.6.4.6 After head insertion mode
fn TreeBuilder::process_after_head_mode(
  self : TreeBuilder,
  token : Token,
) -> Bool {
  match token {
    Character(c) if is_whitespace_char(c) => {
      self.insert_character(c)
      false
    }
    Comment(text) => {
      self.insert_comment(text)
      false
    }
    DOCTYPE(_) => {
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      false
    }
    StartTag(name~, ..) if name == "html" => self.process_in_body_mode(token)
    StartTag(name~, attrs~, ..) if name == "body" => {
      let _ = self.insert_html_element(name, attrs)
      self.frameset_ok = false
      self.mode = InBody
      false
    }
    StartTag(name~, attrs~, ..) if name == "frameset" => {
      let _ = self.insert_html_element(name, attrs)
      self.mode = InFrameset
      false
    }
    StartTag(name~, ..) if name == "base" ||
      name == "basefont" ||
      name == "bgsound" ||
      name == "link" ||
      name == "meta" ||
      name == "noframes" ||
      name == "script" ||
      name == "style" ||
      name == "template" ||
      name == "title" => {
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      self.open_elements.push({
        node_id: self.head_element,
        tag_name: "head",
        ns: HTML,
      })
      let result = self.process_in_head_mode(token)
      // Remove head from stack
      self.remove_from_stack(self.head_element)
      result
    }
    EndTag(name~) if name == "template" => self.process_in_head_mode(token)
    EndTag(name~) if name == "body" || name == "html" || name == "br" => {
      let _ = self.insert_html_element("body", [])
      self.mode = InBody
      true // Reprocess
    }
    StartTag(name~, ..) if name == "head" => {
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      false
    }
    EndTag(_) => {
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      false
    }
    _ => {
      let _ = self.insert_html_element("body", [])
      self.mode = InBody
      true // Reprocess
    }
  }
}

///|
/// 13.2.6.4.7 In body insertion mode
fn TreeBuilder::process_in_body_mode(self : TreeBuilder, token : Token) -> Bool {
  match token {
    Character('\u{0000}') => {
      self.emit_error(UnexpectedNullCharacter)
      false
    }
    Character(c) if is_whitespace_char(c) => {
      self.reconstruct_active_formatting()
      self.insert_character(c)
      false
    }
    Character(c) => {
      self.reconstruct_active_formatting()
      self.insert_character(c)
      self.frameset_ok = false
      false
    }
    Comment(text) => {
      self.insert_comment(text)
      false
    }
    DOCTYPE(_) => {
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      false
    }
    StartTag(name~, attrs~, ..) if name == "html" => {
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      if self.has_element_in_stack("template") {
        return false
      }
      // Add attributes to html element
      if self.open_elements.length() > 0 {
        let html_id = self.open_elements[0].node_id
        for attr in attrs {
          if not(self.document.has_attribute(html_id, attr.name)) {
            self.document.set_attribute(html_id, attr.name, attr.value)
          }
        }
      }
      false
    }
    StartTag(name~, ..) if name == "base" ||
      name == "basefont" ||
      name == "bgsound" ||
      name == "link" ||
      name == "meta" ||
      name == "noframes" ||
      name == "script" ||
      name == "style" ||
      name == "template" ||
      name == "title" => self.process_in_head_mode(token)
    EndTag(name~) if name == "template" => self.process_in_head_mode(token)
    StartTag(name~, attrs~, ..) if name == "body" => {
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      if self.open_elements.length() < 2 {
        return false
      }
      if self.open_elements[1].tag_name != "body" {
        return false
      }
      if self.has_element_in_stack("template") {
        return false
      }
      self.frameset_ok = false
      // Add attributes to body element
      let body_id = self.open_elements[1].node_id
      for attr in attrs {
        if not(self.document.has_attribute(body_id, attr.name)) {
          self.document.set_attribute(body_id, attr.name, attr.value)
        }
      }
      false
    }
    StartTag(name~, attrs~, ..) if name == "frameset" => {
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      if self.open_elements.length() < 2 ||
        self.open_elements[1].tag_name != "body" {
        return false
      }
      if not(self.frameset_ok) {
        return false
      }
      // Remove body from parent
      let body_id = self.open_elements[1].node_id
      let parent = self.document.get_parent(body_id)
      if parent != NO_NODE {
        self.document.remove_child(parent, body_id)
      }
      // Pop all until html
      while self.open_elements.length() > 1 {
        let _ = self.pop_element()

      }
      let _ = self.insert_html_element(name, attrs)
      self.mode = InFrameset
      false
    }
    EOF => {
      if self.template_modes.length() > 0 {
        return self.process_in_template_mode(token)
      }
      // Check for open elements that shouldn't be there
      for entry in self.open_elements {
        match entry.tag_name {
          "dd"
          | "dt"
          | "li"
          | "optgroup"
          | "option"
          | "p"
          | "rb"
          | "rp"
          | "rt"
          | "rtc"
          | "tbody"
          | "td"
          | "tfoot"
          | "th"
          | "thead"
          | "tr"
          | "body"
          | "html" => ()
          _ => {
            self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
            break
          }
        }
      }
      false
    }
    EndTag(name~) if name == "body" => {
      if not(self.in_default_scope("body")) {
        self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
        return false
      }
      // Check for unexpected open elements
      for entry in self.open_elements {
        match entry.tag_name {
          "dd"
          | "dt"
          | "li"
          | "optgroup"
          | "option"
          | "p"
          | "rb"
          | "rp"
          | "rt"
          | "rtc"
          | "tbody"
          | "td"
          | "tfoot"
          | "th"
          | "thead"
          | "tr"
          | "body"
          | "html" => ()
          _ => {
            self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
            break
          }
        }
      }
      self.mode = AfterBody
      false
    }
    EndTag(name~) if name == "html" => {
      if not(self.in_default_scope("body")) {
        self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
        return false
      }
      self.mode = AfterBody
      true // Reprocess
    }
    StartTag(name~, attrs~, ..) if name == "address" ||
      name == "article" ||
      name == "aside" ||
      name == "blockquote" ||
      name == "center" ||
      name == "details" ||
      name == "dialog" ||
      name == "dir" ||
      name == "div" ||
      name == "dl" ||
      name == "fieldset" ||
      name == "figcaption" ||
      name == "figure" ||
      name == "footer" ||
      name == "header" ||
      name == "hgroup" ||
      name == "main" ||
      name == "menu" ||
      name == "nav" ||
      name == "ol" ||
      name == "p" ||
      name == "search" ||
      name == "section" ||
      name == "summary" ||
      name == "ul" => {
      if self.in_button_scope("p") {
        self.close_p_element()
      }
      let _ = self.insert_html_element(name, attrs)
      false
    }
    StartTag(name~, attrs~, ..) if name == "h1" ||
      name == "h2" ||
      name == "h3" ||
      name == "h4" ||
      name == "h5" ||
      name == "h6" => {
      if self.in_button_scope("p") {
        self.close_p_element()
      }
      let current = self.current_node()
      if current.tag_name == "h1" ||
        current.tag_name == "h2" ||
        current.tag_name == "h3" ||
        current.tag_name == "h4" ||
        current.tag_name == "h5" ||
        current.tag_name == "h6" {
        self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
        let _ = self.pop_element()

      }
      let _ = self.insert_html_element(name, attrs)
      false
    }
    StartTag(name~, attrs~, ..) if name == "pre" || name == "listing" => {
      if self.in_button_scope("p") {
        self.close_p_element()
      }
      let _ = self.insert_html_element(name, attrs)
      self.skip_next_newline = true
      self.frameset_ok = false
      false
    }
    StartTag(name~, attrs~, ..) if name == "form" => {
      if self.form_element != NO_NODE &&
        not(self.has_element_in_stack("template")) {
        self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
        return false
      }
      if self.in_button_scope("p") {
        self.close_p_element()
      }
      let id = self.insert_html_element(name, attrs)
      if not(self.has_element_in_stack("template")) {
        self.form_element = id
      }
      false
    }
    StartTag(name~, attrs~, ..) if name == "li" => {
      self.frameset_ok = false
      // Walk the stack
      for i = self.open_elements.length() - 1; i >= 0; i = i - 1 {
        let entry = self.open_elements[i]
        if entry.tag_name == "li" {
          self.generate_implied_end_tags("li")
          if self.current_node().tag_name != "li" {
            self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
          }
          self.pop_until("li")
          break
        }
        if is_special_element(entry.tag_name) &&
          entry.tag_name != "address" &&
          entry.tag_name != "div" &&
          entry.tag_name != "p" {
          break
        }
      }
      if self.in_button_scope("p") {
        self.close_p_element()
      }
      let _ = self.insert_html_element(name, attrs)
      false
    }
    StartTag(name~, attrs~, ..) if name == "dd" || name == "dt" => {
      self.frameset_ok = false
      for i = self.open_elements.length() - 1; i >= 0; i = i - 1 {
        let entry = self.open_elements[i]
        if entry.tag_name == "dd" {
          self.generate_implied_end_tags("dd")
          if self.current_node().tag_name != "dd" {
            self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
          }
          self.pop_until("dd")
          break
        }
        if entry.tag_name == "dt" {
          self.generate_implied_end_tags("dt")
          if self.current_node().tag_name != "dt" {
            self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
          }
          self.pop_until("dt")
          break
        }
        if is_special_element(entry.tag_name) &&
          entry.tag_name != "address" &&
          entry.tag_name != "div" &&
          entry.tag_name != "p" {
          break
        }
      }
      if self.in_button_scope("p") {
        self.close_p_element()
      }
      let _ = self.insert_html_element(name, attrs)
      false
    }
    StartTag(name~, attrs~, ..) if name == "plaintext" => {
      if self.in_button_scope("p") {
        self.close_p_element()
      }
      let _ = self.insert_html_element(name, attrs)
      self.tokenizer.state = PLAINTEXT
      false
    }
    StartTag(name~, attrs~, ..) if name == "button" => {
      if self.in_default_scope("button") {
        self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
        self.generate_implied_end_tags("")
        self.pop_until("button")
      }
      self.reconstruct_active_formatting()
      let _ = self.insert_html_element(name, attrs)
      self.frameset_ok = false
      false
    }
    EndTag(name~) if name == "address" ||
      name == "article" ||
      name == "aside" ||
      name == "blockquote" ||
      name == "button" ||
      name == "center" ||
      name == "details" ||
      name == "dialog" ||
      name == "dir" ||
      name == "div" ||
      name == "dl" ||
      name == "fieldset" ||
      name == "figcaption" ||
      name == "figure" ||
      name == "footer" ||
      name == "header" ||
      name == "hgroup" ||
      name == "listing" ||
      name == "main" ||
      name == "menu" ||
      name == "nav" ||
      name == "ol" ||
      name == "pre" ||
      name == "search" ||
      name == "section" ||
      name == "summary" ||
      name == "ul" => {
      if not(self.in_default_scope(name)) {
        self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
        return false
      }
      self.generate_implied_end_tags("")
      if self.current_node().tag_name != name {
        self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      }
      self.pop_until(name)
      false
    }
    EndTag(name~) if name == "form" => {
      if not(self.has_element_in_stack("template")) {
        let form_id = self.form_element
        self.form_element = NO_NODE
        if form_id == NO_NODE || not(self.in_default_scope("form")) {
          self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
          return false
        }
        self.generate_implied_end_tags("")
        if self.current_node().node_id != form_id {
          self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
        }
        self.remove_from_stack(form_id)
      } else {
        if not(self.in_default_scope("form")) {
          self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
          return false
        }
        self.generate_implied_end_tags("")
        if self.current_node().tag_name != "form" {
          self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
        }
        self.pop_until("form")
      }
      false
    }
    EndTag(name~) if name == "p" => {
      if not(self.in_button_scope("p")) {
        self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
        let _ = self.insert_html_element("p", [])

      }
      self.close_p_element()
      false
    }
    EndTag(name~) if name == "li" => {
      if not(self.in_list_item_scope("li")) {
        self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
        return false
      }
      self.generate_implied_end_tags("li")
      if self.current_node().tag_name != "li" {
        self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      }
      self.pop_until("li")
      false
    }
    EndTag(name~) if name == "dd" || name == "dt" => {
      if not(self.in_default_scope(name)) {
        self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
        return false
      }
      self.generate_implied_end_tags(name)
      if self.current_node().tag_name != name {
        self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      }
      self.pop_until(name)
      false
    }
    EndTag(name~) if name == "h1" ||
      name == "h2" ||
      name == "h3" ||
      name == "h4" ||
      name == "h5" ||
      name == "h6" => {
      if not(self.in_default_scope("h1")) &&
        not(self.in_default_scope("h2")) &&
        not(self.in_default_scope("h3")) &&
        not(self.in_default_scope("h4")) &&
        not(self.in_default_scope("h5")) &&
        not(self.in_default_scope("h6")) {
        self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
        return false
      }
      self.generate_implied_end_tags("")
      if self.current_node().tag_name != name {
        self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      }
      // Pop until any heading
      while self.open_elements.length() > 0 {
        let entry = self.pop_element()
        if entry.tag_name == "h1" ||
          entry.tag_name == "h2" ||
          entry.tag_name == "h3" ||
          entry.tag_name == "h4" ||
          entry.tag_name == "h5" ||
          entry.tag_name == "h6" {
          break
        }
      }
      false
    }
    StartTag(name~, attrs~, ..) if name == "a" => {
      // Check for existing a in formatting
      match self.find_formatting_element("a") {
        Some(Element(node_id~, ..)) => {
          self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
          self.run_adoption_agency("a")
          // Remove from formatting list and stack
          self.remove_from_active_formatting(node_id)
          self.remove_from_stack(node_id)
        }
        _ => ()
      }
      self.reconstruct_active_formatting()
      let id = self.insert_html_element(name, attrs)
      self.push_active_formatting(id, name, attrs)
      false
    }
    StartTag(name~, attrs~, ..) if name == "b" ||
      name == "big" ||
      name == "code" ||
      name == "em" ||
      name == "font" ||
      name == "i" ||
      name == "s" ||
      name == "small" ||
      name == "strike" ||
      name == "strong" ||
      name == "tt" ||
      name == "u" => {
      self.reconstruct_active_formatting()
      let id = self.insert_html_element(name, attrs)
      self.push_active_formatting(id, name, attrs)
      false
    }
    StartTag(name~, attrs~, ..) if name == "nobr" => {
      self.reconstruct_active_formatting()
      if self.in_default_scope("nobr") {
        self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
        self.run_adoption_agency("nobr")
        self.reconstruct_active_formatting()
      }
      let id = self.insert_html_element(name, attrs)
      self.push_active_formatting(id, name, attrs)
      false
    }
    EndTag(name~) if name == "a" ||
      name == "b" ||
      name == "big" ||
      name == "code" ||
      name == "em" ||
      name == "font" ||
      name == "i" ||
      name == "nobr" ||
      name == "s" ||
      name == "small" ||
      name == "strike" ||
      name == "strong" ||
      name == "tt" ||
      name == "u" => {
      self.run_adoption_agency(name)
      false
    }
    StartTag(name~, attrs~, ..) if name == "applet" ||
      name == "marquee" ||
      name == "object" => {
      self.reconstruct_active_formatting()
      let _ = self.insert_html_element(name, attrs)
      self.push_formatting_marker()
      self.frameset_ok = false
      false
    }
    EndTag(name~) if name == "applet" || name == "marquee" || name == "object" => {
      if not(self.in_default_scope(name)) {
        self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
        return false
      }
      self.generate_implied_end_tags("")
      if self.current_node().tag_name != name {
        self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      }
      self.pop_until(name)
      self.clear_active_formatting_to_marker()
      false
    }
    StartTag(name~, attrs~, ..) if name == "table" => {
      // In quirks mode, don't close p element (table goes inside p)
      if self.document.quirks_mode != Quirks && self.in_button_scope("p") {
        self.close_p_element()
      }
      let _ = self.insert_html_element(name, attrs)
      self.frameset_ok = false
      self.mode = InTable
      false
    }
    EndTag(name~) if name == "br" => {
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      self.reconstruct_active_formatting()
      let _ = self.insert_html_element("br", [])
      let _ = self.pop_element()
      self.frameset_ok = false
      false
    }
    StartTag(name~, attrs~, ..) if name == "area" ||
      name == "br" ||
      name == "embed" ||
      name == "img" ||
      name == "keygen" ||
      name == "wbr" => {
      self.reconstruct_active_formatting()
      let _ = self.insert_html_element(name, attrs)
      let _ = self.pop_element()
      self.frameset_ok = false
      false
    }
    StartTag(name~, attrs~, ..) if name == "input" => {
      self.reconstruct_active_formatting()
      let _ = self.insert_html_element(name, attrs)
      let _ = self.pop_element()
      // Check for type=hidden
      let is_hidden = attrs
        .iter()
        .any(fn(a) { a.name == "type" && a.value.to_lower() == "hidden" })
      if not(is_hidden) {
        self.frameset_ok = false
      }
      false
    }
    StartTag(name~, attrs~, ..) if name == "param" ||
      name == "source" ||
      name == "track" => {
      let _ = self.insert_html_element(name, attrs)
      let _ = self.pop_element()
      false
    }
    StartTag(name~, attrs~, ..) if name == "hr" => {
      if self.in_button_scope("p") {
        self.close_p_element()
      }
      let _ = self.insert_html_element(name, attrs)
      let _ = self.pop_element()
      self.frameset_ok = false
      false
    }
    StartTag(name~, attrs~, ..) if name == "image" => {
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      // Treat as <img>
      self.reconstruct_active_formatting()
      let _ = self.insert_html_element("img", attrs)
      let _ = self.pop_element()
      self.frameset_ok = false
      false
    }
    StartTag(name~, attrs~, ..) if name == "textarea" => {
      let _ = self.insert_html_element(name, attrs)
      self.skip_next_newline = true
      self.tokenizer.state = RCDATA
      self.original_mode = self.mode
      self.frameset_ok = false
      self.mode = Text
      false
    }
    StartTag(name~, attrs~, ..) if name == "xmp" => {
      if self.in_button_scope("p") {
        self.close_p_element()
      }
      self.reconstruct_active_formatting()
      self.frameset_ok = false
      self.parse_rawtext(name, attrs)
      false
    }
    StartTag(name~, attrs~, ..) if name == "iframe" => {
      self.frameset_ok = false
      self.parse_rawtext(name, attrs)
      false
    }
    StartTag(name~, attrs~, ..) if name == "noembed" => {
      self.parse_rawtext(name, attrs)
      false
    }
    StartTag(name~, attrs~, ..) if name == "noscript" && self.scripting => {
      self.parse_rawtext(name, attrs)
      false
    }
    StartTag(name~, attrs~, ..) if name == "select" => {
      self.reconstruct_active_formatting()
      let _ = self.insert_html_element(name, attrs)
      self.frameset_ok = false
      match self.mode {
        InTable | InCaption | InTableBody | InRow | InCell =>
          self.mode = InSelectInTable
        _ => self.mode = InSelect
      }
      false
    }
    StartTag(name~, attrs~, ..) if name == "optgroup" || name == "option" => {
      if self.current_node().tag_name == "option" {
        let _ = self.pop_element()

      }
      self.reconstruct_active_formatting()
      let _ = self.insert_html_element(name, attrs)
      false
    }
    StartTag(name~, attrs~, ..) if name == "rb" || name == "rtc" => {
      if self.in_default_scope("ruby") {
        self.generate_implied_end_tags("")
        if self.current_node().tag_name != "ruby" {
          self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
        }
      }
      let _ = self.insert_html_element(name, attrs)
      false
    }
    StartTag(name~, attrs~, ..) if name == "rp" || name == "rt" => {
      if self.in_default_scope("ruby") {
        self.generate_implied_end_tags("rtc")
        if self.current_node().tag_name != "rtc" &&
          self.current_node().tag_name != "ruby" {
          self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
        }
      }
      let _ = self.insert_html_element(name, attrs)
      false
    }
    StartTag(name~, attrs~, self_closing~) if name == "math" => {
      self.reconstruct_active_formatting()
      // Adjust MathML attributes
      let _ = self.insert_foreign_element(name, attrs, MathML)
      // If self-closing, pop the element immediately
      if self_closing {
        let _ = self.pop_element()
      }
      false
    }
    StartTag(name~, attrs~, self_closing~) if name == "svg" => {
      self.reconstruct_active_formatting()
      // Adjust SVG attributes
      let _ = self.insert_foreign_element(name, attrs, SVG)
      // If self-closing, pop the element immediately
      if self_closing {
        let _ = self.pop_element()
      }
      false
    }
    StartTag(name~, ..) if name == "caption" ||
      name == "col" ||
      name == "colgroup" ||
      name == "frame" ||
      name == "head" ||
      name == "tbody" ||
      name == "td" ||
      name == "tfoot" ||
      name == "th" ||
      name == "thead" ||
      name == "tr" => {
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      false
    }
    StartTag(name~, attrs~, ..) => {
      self.reconstruct_active_formatting()
      let _ = self.insert_html_element(name, attrs)
      false
    }
    EndTag(name~) => {
      self.process_any_other_end_tag(name)
      false
    }
  }
}

///|
/// Process any other end tag in body mode
fn TreeBuilder::process_any_other_end_tag(
  self : TreeBuilder,
  name : String,
) -> Unit {
  for i = self.open_elements.length() - 1; i >= 0; i = i - 1 {
    let entry = self.open_elements[i]
    if entry.tag_name == name && entry.ns == HTML {
      self.generate_implied_end_tags(name)
      if self.current_node().tag_name != name {
        self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      }
      // Pop until and including this element
      while self.open_elements.length() > i {
        let _ = self.pop_element()

      }
      return
    }
    if is_special_element(entry.tag_name) {
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      return
    }
  }
}

///|
/// 13.2.6.4.8 Text insertion mode
fn TreeBuilder::process_text_mode(self : TreeBuilder, token : Token) -> Bool {
  match token {
    Character(c) => {
      self.insert_character(c)
      false
    }
    EOF => {
      self.emit_error(EofInTag)
      let _ = self.pop_element()
      self.mode = self.original_mode
      true // Reprocess
    }
    EndTag(name~) if name == "script" => {
      // For now, just pop the script element
      let _ = self.pop_element()
      self.mode = self.original_mode
      false
    }
    EndTag(_) => {
      let _ = self.pop_element()
      self.mode = self.original_mode
      false
    }
    _ => false
  }
}

///|
/// 13.2.6.4.9 In table insertion mode
fn TreeBuilder::process_in_table_mode(
  self : TreeBuilder,
  token : Token,
) -> Bool {
  match token {
    Character(_) => {
      let current = self.current_node()
      if current.tag_name == "table" ||
        current.tag_name == "tbody" ||
        current.tag_name == "tfoot" ||
        current.tag_name == "thead" ||
        current.tag_name == "tr" {
        self.pending_table_chars.clear()
        self.original_mode = self.mode
        self.mode = InTableText
        return true // Reprocess
      }
      self.process_in_table_anything_else(token)
    }
    Comment(text) => {
      self.insert_comment(text)
      false
    }
    DOCTYPE(_) => {
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      false
    }
    StartTag(name~, attrs~, ..) if name == "caption" => {
      self.clear_stack_to_table_context()
      self.push_formatting_marker()
      let _ = self.insert_html_element(name, attrs)
      self.mode = InCaption
      false
    }
    StartTag(name~, attrs~, ..) if name == "colgroup" => {
      self.clear_stack_to_table_context()
      let _ = self.insert_html_element(name, attrs)
      self.mode = InColumnGroup
      false
    }
    StartTag(name~, ..) if name == "col" => {
      self.clear_stack_to_table_context()
      let _ = self.insert_html_element("colgroup", [])
      self.mode = InColumnGroup
      true // Reprocess
    }
    StartTag(name~, attrs~, ..) if name == "tbody" ||
      name == "tfoot" ||
      name == "thead" => {
      self.clear_stack_to_table_context()
      let _ = self.insert_html_element(name, attrs)
      self.mode = InTableBody
      false
    }
    StartTag(name~, ..) if name == "td" || name == "th" || name == "tr" => {
      self.clear_stack_to_table_context()
      let _ = self.insert_html_element("tbody", [])
      self.mode = InTableBody
      true // Reprocess
    }
    StartTag(name~, ..) if name == "table" => {
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      if not(self.in_table_scope("table")) {
        return false
      }
      self.pop_until("table")
      self.reset_insertion_mode()
      true // Reprocess
    }
    EndTag(name~) if name == "table" => {
      if not(self.in_table_scope("table")) {
        self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
        return false
      }
      self.pop_until("table")
      self.reset_insertion_mode()
      false
    }
    EndTag(name~) if name == "body" ||
      name == "caption" ||
      name == "col" ||
      name == "colgroup" ||
      name == "html" ||
      name == "tbody" ||
      name == "td" ||
      name == "tfoot" ||
      name == "th" ||
      name == "thead" ||
      name == "tr" => {
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      false
    }
    StartTag(name~, ..) if name == "style" ||
      name == "script" ||
      name == "template" => self.process_in_head_mode(token)
    EndTag(name~) if name == "template" => self.process_in_head_mode(token)
    StartTag(name~, attrs~, ..) if name == "input" => {
      let is_hidden = attrs
        .iter()
        .any(fn(a) { a.name == "type" && a.value.to_lower() == "hidden" })
      if not(is_hidden) {
        return self.process_in_table_anything_else(token)
      }
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      let _ = self.insert_html_element(name, attrs)
      let _ = self.pop_element()
      false
    }
    StartTag(name~, attrs~, ..) if name == "form" => {
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      if self.has_element_in_stack("template") || self.form_element != NO_NODE {
        return false
      }
      let id = self.insert_html_element(name, attrs)
      self.form_element = id
      let _ = self.pop_element()
      false
    }
    EOF => self.process_in_body_mode(token)
    _ => self.process_in_table_anything_else(token)
  }
}

///|
/// Process anything else in table mode (foster parenting)
fn TreeBuilder::process_in_table_anything_else(
  self : TreeBuilder,
  token : Token,
) -> Bool {
  self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
  self.foster_parenting = true
  let result = self.process_in_body_mode(token)
  self.foster_parenting = false
  result
}

///|
/// 13.2.6.4.10 In table text insertion mode
fn TreeBuilder::process_in_table_text_mode(
  self : TreeBuilder,
  token : Token,
) -> Bool {
  match token {
    Character('\u{0000}') => {
      self.emit_error(UnexpectedNullCharacter)
      false
    }
    Character(c) => {
      self.pending_table_chars.push(c)
      false
    }
    _ => {
      // Check if pending chars are all whitespace
      let all_whitespace = self.pending_table_chars
        .iter()
        .all(fn(c) { is_whitespace_char(c) })
      if all_whitespace {
        for c in self.pending_table_chars {
          self.insert_character(c)
        }
      } else {
        // Foster parent the characters using "anything else" rule
        // This reconstructs active formatting elements
        for c in self.pending_table_chars {
          let _ = self.process_in_table_anything_else(Character(c))
        }
      }
      self.pending_table_chars.clear()
      self.mode = self.original_mode
      true // Reprocess
    }
  }
}

///|
/// 13.2.6.4.11 In caption insertion mode
fn TreeBuilder::process_in_caption_mode(
  self : TreeBuilder,
  token : Token,
) -> Bool {
  match token {
    EndTag(name~) if name == "caption" => {
      if not(self.in_table_scope("caption")) {
        self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
        return false
      }
      self.generate_implied_end_tags("")
      if self.current_node().tag_name != "caption" {
        self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      }
      self.pop_until("caption")
      self.clear_active_formatting_to_marker()
      self.mode = InTable
      false
    }
    StartTag(name~, ..) if name == "caption" ||
      name == "col" ||
      name == "colgroup" ||
      name == "tbody" ||
      name == "td" ||
      name == "tfoot" ||
      name == "th" ||
      name == "thead" ||
      name == "tr" => {
      if not(self.in_table_scope("caption")) {
        self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
        return false
      }
      self.generate_implied_end_tags("")
      if self.current_node().tag_name != "caption" {
        self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      }
      self.pop_until("caption")
      self.clear_active_formatting_to_marker()
      self.mode = InTable
      true // Reprocess
    }
    EndTag(name~) if name == "table" => {
      if not(self.in_table_scope("caption")) {
        self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
        return false
      }
      self.generate_implied_end_tags("")
      if self.current_node().tag_name != "caption" {
        self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      }
      self.pop_until("caption")
      self.clear_active_formatting_to_marker()
      self.mode = InTable
      true // Reprocess
    }
    EndTag(name~) if name == "body" ||
      name == "col" ||
      name == "colgroup" ||
      name == "html" ||
      name == "tbody" ||
      name == "td" ||
      name == "tfoot" ||
      name == "th" ||
      name == "thead" ||
      name == "tr" => {
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      false
    }
    _ => self.process_in_body_mode(token)
  }
}

///|
/// 13.2.6.4.12 In column group insertion mode
fn TreeBuilder::process_in_column_group_mode(
  self : TreeBuilder,
  token : Token,
) -> Bool {
  match token {
    Character(c) if is_whitespace_char(c) => {
      self.insert_character(c)
      false
    }
    Comment(text) => {
      self.insert_comment(text)
      false
    }
    DOCTYPE(_) => {
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      false
    }
    StartTag(name~, ..) if name == "html" => self.process_in_body_mode(token)
    StartTag(name~, attrs~, ..) if name == "col" => {
      let _ = self.insert_html_element(name, attrs)
      let _ = self.pop_element()
      false
    }
    EndTag(name~) if name == "colgroup" => {
      if self.current_node().tag_name != "colgroup" {
        self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
        return false
      }
      let _ = self.pop_element()
      self.mode = InTable
      false
    }
    EndTag(name~) if name == "col" => {
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      false
    }
    StartTag(name~, ..) | EndTag(name~) if name == "template" =>
      self.process_in_head_mode(token)
    EOF => self.process_in_body_mode(token)
    _ => {
      if self.current_node().tag_name != "colgroup" {
        self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
        return false
      }
      let _ = self.pop_element()
      self.mode = InTable
      true // Reprocess
    }
  }
}

///|
/// 13.2.6.4.13 In table body insertion mode
fn TreeBuilder::process_in_table_body_mode(
  self : TreeBuilder,
  token : Token,
) -> Bool {
  match token {
    StartTag(name~, attrs~, ..) if name == "tr" => {
      self.clear_stack_to_table_body_context()
      let _ = self.insert_html_element(name, attrs)
      self.mode = InRow
      false
    }
    StartTag(name~, ..) if name == "th" || name == "td" => {
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      self.clear_stack_to_table_body_context()
      let _ = self.insert_html_element("tr", [])
      self.mode = InRow
      true // Reprocess
    }
    EndTag(name~) if name == "tbody" || name == "tfoot" || name == "thead" => {
      if not(self.in_table_scope(name)) {
        self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
        return false
      }
      self.clear_stack_to_table_body_context()
      let _ = self.pop_element()
      self.mode = InTable
      false
    }
    StartTag(name~, ..) if name == "caption" ||
      name == "col" ||
      name == "colgroup" ||
      name == "tbody" ||
      name == "tfoot" ||
      name == "thead" => {
      if not(self.in_table_scope("tbody")) &&
        not(self.in_table_scope("thead")) &&
        not(self.in_table_scope("tfoot")) {
        self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
        return false
      }
      self.clear_stack_to_table_body_context()
      let _ = self.pop_element()
      self.mode = InTable
      true // Reprocess
    }
    EndTag(name~) if name == "table" => {
      if not(self.in_table_scope("tbody")) &&
        not(self.in_table_scope("thead")) &&
        not(self.in_table_scope("tfoot")) {
        self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
        return false
      }
      self.clear_stack_to_table_body_context()
      let _ = self.pop_element()
      self.mode = InTable
      true // Reprocess
    }
    EndTag(name~) if name == "body" ||
      name == "caption" ||
      name == "col" ||
      name == "colgroup" ||
      name == "html" ||
      name == "td" ||
      name == "th" ||
      name == "tr" => {
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      false
    }
    _ => self.process_in_table_mode(token)
  }
}

///|
/// 13.2.6.4.14 In row insertion mode
fn TreeBuilder::process_in_row_mode(self : TreeBuilder, token : Token) -> Bool {
  match token {
    StartTag(name~, attrs~, ..) if name == "th" || name == "td" => {
      self.clear_stack_to_table_row_context()
      let _ = self.insert_html_element(name, attrs)
      self.mode = InCell
      self.push_formatting_marker()
      false
    }
    EndTag(name~) if name == "tr" => {
      if not(self.in_table_scope("tr")) {
        self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
        return false
      }
      self.clear_stack_to_table_row_context()
      let _ = self.pop_element()
      self.mode = InTableBody
      false
    }
    StartTag(name~, ..) if name == "caption" ||
      name == "col" ||
      name == "colgroup" ||
      name == "tbody" ||
      name == "tfoot" ||
      name == "thead" ||
      name == "tr" => {
      if not(self.in_table_scope("tr")) {
        self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
        return false
      }
      self.clear_stack_to_table_row_context()
      let _ = self.pop_element()
      self.mode = InTableBody
      true // Reprocess
    }
    EndTag(name~) if name == "table" => {
      if not(self.in_table_scope("tr")) {
        self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
        return false
      }
      self.clear_stack_to_table_row_context()
      let _ = self.pop_element()
      self.mode = InTableBody
      true // Reprocess
    }
    EndTag(name~) if name == "tbody" || name == "tfoot" || name == "thead" => {
      if not(self.in_table_scope(name)) {
        self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
        return false
      }
      if not(self.in_table_scope("tr")) {
        return false
      }
      self.clear_stack_to_table_row_context()
      let _ = self.pop_element()
      self.mode = InTableBody
      true // Reprocess
    }
    EndTag(name~) if name == "body" ||
      name == "caption" ||
      name == "col" ||
      name == "colgroup" ||
      name == "html" ||
      name == "td" ||
      name == "th" => {
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      false
    }
    _ => self.process_in_table_mode(token)
  }
}

///|
/// 13.2.6.4.15 In cell insertion mode
fn TreeBuilder::process_in_cell_mode(self : TreeBuilder, token : Token) -> Bool {
  match token {
    EndTag(name~) if name == "td" || name == "th" => {
      if not(self.in_table_scope(name)) {
        self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
        return false
      }
      self.generate_implied_end_tags("")
      if self.current_node().tag_name != name {
        self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      }
      self.pop_until(name)
      self.clear_active_formatting_to_marker()
      self.mode = InRow
      false
    }
    StartTag(name~, ..) if name == "caption" ||
      name == "col" ||
      name == "colgroup" ||
      name == "tbody" ||
      name == "td" ||
      name == "tfoot" ||
      name == "th" ||
      name == "thead" ||
      name == "tr" => {
      if not(self.in_table_scope("td")) && not(self.in_table_scope("th")) {
        self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
        return false
      }
      self.close_cell()
      true // Reprocess
    }
    EndTag(name~) if name == "body" ||
      name == "caption" ||
      name == "col" ||
      name == "colgroup" ||
      name == "html" => {
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      false
    }
    EndTag(name~) if name == "table" ||
      name == "tbody" ||
      name == "tfoot" ||
      name == "thead" ||
      name == "tr" => {
      if not(self.in_table_scope(name)) {
        self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
        return false
      }
      self.close_cell()
      true // Reprocess
    }
    _ => self.process_in_body_mode(token)
  }
}

///|
/// 13.2.6.4.16 In select insertion mode
fn TreeBuilder::process_in_select_mode(
  self : TreeBuilder,
  token : Token,
) -> Bool {
  match token {
    Character('\u{0000}') => {
      self.emit_error(UnexpectedNullCharacter)
      false
    }
    Character(c) => {
      self.insert_character(c)
      false
    }
    Comment(text) => {
      self.insert_comment(text)
      false
    }
    DOCTYPE(_) => {
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      false
    }
    StartTag(name~, ..) if name == "html" => self.process_in_body_mode(token)
    StartTag(name~, attrs~, ..) if name == "option" => {
      if self.current_node().tag_name == "option" {
        let _ = self.pop_element()
      }
      // Reconstruct formatting elements before inserting option
      self.reconstruct_active_formatting()
      let _ = self.insert_html_element(name, attrs)
      false
    }
    StartTag(name~, attrs~, ..) if name == "optgroup" => {
      if self.current_node().tag_name == "option" {
        let _ = self.pop_element()

      }
      if self.current_node().tag_name == "optgroup" {
        let _ = self.pop_element()

      }
      let _ = self.insert_html_element(name, attrs)
      false
    }
    StartTag(name~, attrs~, ..) if name == "hr" => {
      if self.current_node().tag_name == "option" {
        let _ = self.pop_element()

      }
      if self.current_node().tag_name == "optgroup" {
        let _ = self.pop_element()

      }
      let _ = self.insert_html_element(name, attrs)
      let _ = self.pop_element()
      false
    }
    EndTag(name~) if name == "optgroup" => {
      if self.current_node().tag_name == "option" &&
        self.open_elements.length() >= 2 &&
        self.open_elements[self.open_elements.length() - 2].tag_name ==
        "optgroup" {
        let _ = self.pop_element()

      }
      if self.current_node().tag_name == "optgroup" {
        let _ = self.pop_element()

      } else {
        self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      }
      false
    }
    EndTag(name~) if name == "option" => {
      if self.current_node().tag_name == "option" {
        let _ = self.pop_element()

      } else {
        self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      }
      false
    }
    EndTag(name~) if name == "select" => {
      if not(self.in_select_scope("select")) {
        self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
        return false
      }
      self.pop_until("select")
      self.reset_insertion_mode()
      false
    }
    StartTag(name~, ..) if name == "select" => {
      // Nested select: close the current one and reset mode
      // Per spec: just pop until select, no scope check needed
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      self.pop_until("select")
      self.reset_insertion_mode()
      false
    }
    StartTag(name~, ..) if name == "input" || name == "textarea" => {
      // These elements close the select and get reprocessed
      // Note: keygen is obsolete and treated as unknown element inside select
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      self.pop_until("select")
      self.reset_insertion_mode()
      true // Reprocess
    }
    StartTag(name~, ..) | EndTag(name~) if name == "script" ||
      name == "template" => self.process_in_head_mode(token)
    StartTag(name~, attrs~, self_closing~) if name == "math" => {
      // Insert MathML element in select (browsers allow this despite spec)
      let _ = self.insert_foreign_element(name, attrs, MathML)
      if self_closing {
        let _ = self.pop_element()
      }
      false
    }
    StartTag(name~, attrs~, self_closing~) if name == "svg" => {
      // Insert SVG element in select (browsers allow this despite spec)
      let _ = self.insert_foreign_element(name, attrs, SVG)
      if self_closing {
        let _ = self.pop_element()
      }
      false
    }
    EOF => self.process_in_body_mode(token)
    StartTag(name~, attrs~, ..) if name == "plaintext" => {
      // Plaintext inside select: insert element AND switch tokenizer to PLAINTEXT
      // This makes </plaintext> become literal text
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      let _ = self.insert_html_element(name, attrs)
      self.tokenizer.state = PLAINTEXT
      false
    }
    StartTag(name~, ..) if name == "caption" ||
      name == "table" ||
      name == "tbody" ||
      name == "tfoot" ||
      name == "thead" ||
      name == "tr" ||
      name == "td" ||
      name == "th" ||
      name == "col" ||
      name == "colgroup" => {
      // Table-related elements in select (not InSelectInTable) should be ignored
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      false
    }
    StartTag(name~, attrs~, self_closing~) => {
      // Browsers insert unknown elements inside select (against spec but matches reality)
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      self.reconstruct_active_formatting()
      let _ = self.insert_html_element(name, attrs)
      if self_closing {
        let _ = self.pop_element()
      }
      // Add to active formatting list if it's a formatting element
      if is_formatting_element(name) {
        self.push_active_formatting(self.current_node().node_id, name, attrs)
      }
      false
    }
    EndTag(name~) => {
      // Per WHATWG 13.2.6.4.16: Unknown end tags in select are parse errors
      // We close matching elements opened inside select, but ignore others
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      // Find matching element in stack (only within select scope)
      for i = self.open_elements.length() - 1; i >= 0; i = i - 1 {
        let entry = self.open_elements[i]
        if entry.tag_name == "select" {
          // Hit the select element - don't look further
          break
        }
        if entry.tag_name == name && entry.ns == HTML {
          // Found matching element, pop until it
          while self.open_elements.length() > i {
            let _ = self.pop_element()
          }
          break
        }
      }
      false
    }
  }
}

///|
/// 13.2.6.4.17 In select in table insertion mode
fn TreeBuilder::process_in_select_in_table_mode(
  self : TreeBuilder,
  token : Token,
) -> Bool {
  match token {
    StartTag(name~, ..) if name == "caption" ||
      name == "table" ||
      name == "tbody" ||
      name == "tfoot" ||
      name == "thead" ||
      name == "tr" ||
      name == "td" ||
      name == "th" => {
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      self.pop_until("select")
      self.reset_insertion_mode()
      true // Reprocess
    }
    EndTag(name~) if name == "caption" ||
      name == "table" ||
      name == "tbody" ||
      name == "tfoot" ||
      name == "thead" ||
      name == "tr" ||
      name == "td" ||
      name == "th" => {
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      if not(self.in_table_scope(name)) {
        return false
      }
      self.pop_until("select")
      self.reset_insertion_mode()
      true // Reprocess
    }
    _ => self.process_in_select_mode(token)
  }
}

///|
/// 13.2.6.4.18 In template insertion mode
fn TreeBuilder::process_in_template_mode(
  self : TreeBuilder,
  token : Token,
) -> Bool {
  match token {
    Character(_) | Comment(_) | DOCTYPE(_) => self.process_in_body_mode(token)
    StartTag(name~, ..) if name == "base" ||
      name == "basefont" ||
      name == "bgsound" ||
      name == "link" ||
      name == "meta" ||
      name == "noframes" ||
      name == "script" ||
      name == "style" ||
      name == "template" ||
      name == "title" => self.process_in_head_mode(token)
    EndTag(name~) if name == "template" => self.process_in_head_mode(token)
    StartTag(name~, ..) if name == "caption" ||
      name == "colgroup" ||
      name == "tbody" ||
      name == "tfoot" ||
      name == "thead" => {
      let _ = self.template_modes.pop()
      self.template_modes.push(InTable)
      self.mode = InTable
      true // Reprocess
    }
    StartTag(name~, ..) if name == "col" => {
      let _ = self.template_modes.pop()
      self.template_modes.push(InColumnGroup)
      self.mode = InColumnGroup
      true // Reprocess
    }
    StartTag(name~, ..) if name == "tr" => {
      let _ = self.template_modes.pop()
      self.template_modes.push(InTableBody)
      self.mode = InTableBody
      true // Reprocess
    }
    StartTag(name~, ..) if name == "td" || name == "th" => {
      let _ = self.template_modes.pop()
      self.template_modes.push(InRow)
      self.mode = InRow
      true // Reprocess
    }
    StartTag(_) => {
      let _ = self.template_modes.pop()
      self.template_modes.push(InBody)
      self.mode = InBody
      true // Reprocess
    }
    EndTag(_) => {
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      false
    }
    EOF => {
      if not(self.has_element_in_stack("template")) {
        // Stop parsing
        return false
      }
      self.emit_error(EofInTag)
      self.pop_until("template")
      self.clear_active_formatting_to_marker()
      let _ = self.template_modes.pop()
      self.reset_insertion_mode()
      true // Reprocess
    }
  }
}

///|
/// 13.2.6.4.19 After body insertion mode
fn TreeBuilder::process_after_body_mode(
  self : TreeBuilder,
  token : Token,
) -> Bool {
  match token {
    Character(c) if is_whitespace_char(c) => self.process_in_body_mode(token)
    Comment(text) => {
      // Insert as last child of html element
      let html_id = self.open_elements[0].node_id
      let node_id = self.document.add_node(CommentNode(text))
      self.document.append_child(html_id, node_id)
      false
    }
    DOCTYPE(_) => {
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      false
    }
    StartTag(name~, ..) if name == "html" => self.process_in_body_mode(token)
    EndTag(name~) if name == "html" => {
      // Fragment case would return here
      self.mode = AfterAfterBody
      false
    }
    EOF =>
      // Stop parsing
      false
    _ => {
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      self.mode = InBody
      true // Reprocess
    }
  }
}

///|
/// 13.2.6.4.20 In frameset insertion mode
fn TreeBuilder::process_in_frameset_mode(
  self : TreeBuilder,
  token : Token,
) -> Bool {
  match token {
    Character(c) if is_whitespace_char(c) => {
      self.insert_character(c)
      false
    }
    Comment(text) => {
      self.insert_comment(text)
      false
    }
    DOCTYPE(_) => {
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      false
    }
    StartTag(name~, ..) if name == "html" => self.process_in_body_mode(token)
    StartTag(name~, attrs~, ..) if name == "frameset" => {
      let _ = self.insert_html_element(name, attrs)
      false
    }
    EndTag(name~) if name == "frameset" => {
      if self.current_node().tag_name == "html" {
        self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
        return false
      }
      let _ = self.pop_element()
      // Fragment case check would go here
      if self.current_node().tag_name != "frameset" {
        self.mode = AfterFrameset
      }
      false
    }
    StartTag(name~, attrs~, ..) if name == "frame" => {
      let _ = self.insert_html_element(name, attrs)
      let _ = self.pop_element()
      false
    }
    StartTag(name~, ..) if name == "noframes" =>
      self.process_in_head_mode(token)
    EOF => {
      if self.current_node().tag_name != "html" {
        self.emit_error(EofInTag)
      }
      false
    }
    _ => {
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      false
    }
  }
}

///|
/// 13.2.6.4.21 After frameset insertion mode
fn TreeBuilder::process_after_frameset_mode(
  self : TreeBuilder,
  token : Token,
) -> Bool {
  match token {
    Character(c) if is_whitespace_char(c) => {
      self.insert_character(c)
      false
    }
    Comment(text) => {
      self.insert_comment(text)
      false
    }
    DOCTYPE(_) => {
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      false
    }
    StartTag(name~, ..) if name == "html" => self.process_in_body_mode(token)
    EndTag(name~) if name == "html" => {
      self.mode = AfterAfterFrameset
      false
    }
    StartTag(name~, ..) if name == "noframes" =>
      self.process_in_head_mode(token)
    EOF =>
      // Stop parsing
      false
    _ => {
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      false
    }
  }
}

///|
/// 13.2.6.4.22 After after body insertion mode
fn TreeBuilder::process_after_after_body_mode(
  self : TreeBuilder,
  token : Token,
) -> Bool {
  match token {
    Comment(text) => {
      self.insert_comment_at_document(text)
      false
    }
    DOCTYPE(_) => self.process_in_body_mode(token)
    Character(c) if is_whitespace_char(c) => self.process_in_body_mode(token)
    StartTag(name~, ..) if name == "html" => self.process_in_body_mode(token)
    EOF =>
      // Stop parsing
      false
    _ => {
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      self.mode = InBody
      true // Reprocess
    }
  }
}

///|
/// 13.2.6.4.23 After after frameset insertion mode
fn TreeBuilder::process_after_after_frameset_mode(
  self : TreeBuilder,
  token : Token,
) -> Bool {
  match token {
    Comment(text) => {
      self.insert_comment_at_document(text)
      false
    }
    DOCTYPE(_) => self.process_in_body_mode(token)
    Character(c) if is_whitespace_char(c) => self.process_in_body_mode(token)
    StartTag(name~, ..) if name == "html" => self.process_in_body_mode(token)
    EOF =>
      // Stop parsing
      false
    StartTag(name~, ..) if name == "noframes" =>
      self.process_in_head_mode(token)
    _ => {
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      false
    }
  }
}

///|
/// 13.2.6.5 Foreign content
fn TreeBuilder::process_in_foreign_content(
  self : TreeBuilder,
  token : Token,
) -> Bool {
  match token {
    Character('\u{0000}') => {
      self.emit_error(UnexpectedNullCharacter)
      self.insert_character('\u{FFFD}')
      false
    }
    Character(c) if is_whitespace_char(c) => {
      self.insert_character(c)
      false
    }
    Character(c) => {
      self.insert_character(c)
      self.frameset_ok = false
      false
    }
    Comment(text) => {
      self.insert_comment(text)
      false
    }
    DOCTYPE(_) => {
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      false
    }
    StartTag(name~, attrs~, self_closing~) if name == "b" ||
      name == "big" ||
      name == "blockquote" ||
      name == "body" ||
      name == "br" ||
      name == "center" ||
      name == "code" ||
      name == "dd" ||
      name == "div" ||
      name == "dl" ||
      name == "dt" ||
      name == "em" ||
      name == "embed" ||
      name == "h1" ||
      name == "h2" ||
      name == "h3" ||
      name == "h4" ||
      name == "h5" ||
      name == "h6" ||
      name == "head" ||
      name == "hr" ||
      name == "i" ||
      name == "img" ||
      name == "li" ||
      name == "listing" ||
      name == "menu" ||
      name == "meta" ||
      name == "nobr" ||
      name == "ol" ||
      name == "p" ||
      name == "pre" ||
      name == "ruby" ||
      name == "s" ||
      name == "small" ||
      name == "span" ||
      name == "strong" ||
      name == "strike" ||
      name == "sub" ||
      name == "sup" ||
      name == "table" ||
      name == "tt" ||
      name == "u" ||
      name == "ul" ||
      name == "var" => {
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      // Pop until we're back in HTML namespace
      while self.open_elements.length() > 0 {
        let current = self.current_node()
        if current.ns == HTML ||
          self.is_mathml_text_integration_point(current) ||
          self.is_html_integration_point(current) {
          break
        }
        let _ = self.pop_element()

      }
      true // Reprocess
    }
    StartTag(name~, attrs~, self_closing~) if name == "font" => {
      // Check for color, face, or size attributes
      let has_special = attrs
        .iter()
        .any(fn(a) { a.name == "color" || a.name == "face" || a.name == "size" })
      if has_special {
        self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
        while self.open_elements.length() > 0 {
          let current = self.current_node()
          if current.ns == HTML ||
            self.is_mathml_text_integration_point(current) ||
            self.is_html_integration_point(current) {
            break
          }
          let _ = self.pop_element()

        }
        return true // Reprocess
      }
      // Otherwise, insert foreign element
      let current = self.current_node()
      let _ = self.insert_foreign_element(name, attrs, current.ns)
      if self_closing {
        let _ = self.pop_element()

      }
      false
    }
    StartTag(name~, attrs~, self_closing~) => {
      // Insert foreign element in current namespace
      let current = self.current_node()
      let _ = self.insert_foreign_element(name, attrs, current.ns)
      if self_closing {
        let _ = self.pop_element()

      }
      false
    }
    EndTag(name~) if name == "script" &&
      self.current_node().tag_name == "script" &&
      self.current_node().ns == SVG => {
      let _ = self.pop_element()
      // Script execution would go here
      false
    }
    EndTag(name~) => {
      // Search for matching element in stack
      for i = self.open_elements.length() - 1; i >= 0; i = i - 1 {
        let entry = self.open_elements[i]
        if entry.tag_name.to_lower() == name.to_lower() {
          // Pop until and including this element
          while self.open_elements.length() > i {
            let _ = self.pop_element()
          }
          return false
        }
        if entry.ns == HTML {
          // Some end tags in HTML mode can insert elements (e.g., </p>, </br>)
          // For these, we need to pop foreign elements first
          match token {
            EndTag(name~) if name == "p" || name == "br" => {
              while self.open_elements.length() > i + 1 {
                let _ = self.pop_element()
              }
            }
            _ => ()
          }
          return self.process_token_in_html_mode(token)
        }
      }
      false
    }
    _ => false
  }
}

// ============================================================================
// Helper functions
// ============================================================================

///|
/// Check if character is whitespace (for tree builder)
fn is_whitespace_char(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\u{0C}' || c == '\r'
}

///|
/// Check if tag name is a special element
fn is_special_element(tag : String) -> Bool {
  match tag {
    "address"
    | "applet"
    | "area"
    | "article"
    | "aside"
    | "base"
    | "basefont"
    | "bgsound"
    | "blockquote"
    | "body"
    | "br"
    | "button"
    | "caption"
    | "center"
    | "col"
    | "colgroup"
    | "dd"
    | "details"
    | "dir"
    | "div"
    | "dl"
    | "dt"
    | "embed"
    | "fieldset"
    | "figcaption"
    | "figure"
    | "footer"
    | "form"
    | "frame"
    | "frameset"
    | "h1"
    | "h2"
    | "h3"
    | "h4"
    | "h5"
    | "h6"
    | "head"
    | "header"
    | "hgroup"
    | "hr"
    | "html"
    | "iframe"
    | "img"
    | "input"
    | "keygen"
    | "li"
    | "link"
    | "listing"
    | "main"
    | "marquee"
    | "menu"
    | "meta"
    | "nav"
    | "noembed"
    | "noframes"
    | "noscript"
    | "object"
    | "ol"
    | "p"
    | "param"
    | "plaintext"
    | "pre"
    | "script"
    | "search"
    | "section"
    | "select"
    | "source"
    | "style"
    | "summary"
    | "table"
    | "tbody"
    | "td"
    | "template"
    | "textarea"
    | "tfoot"
    | "th"
    | "thead"
    | "title"
    | "tr"
    | "track"
    | "ul"
    | "wbr"
    | "xmp" => true
    _ => false
  }
}

///|
/// Close a p element
fn TreeBuilder::close_p_element(self : TreeBuilder) -> Unit {
  self.generate_implied_end_tags("p")
  if self.current_node().tag_name != "p" {
    self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
  }
  self.pop_until("p")
}

///|
/// Close a table cell
fn TreeBuilder::close_cell(self : TreeBuilder) -> Unit {
  self.generate_implied_end_tags("")
  let current = self.current_node()
  if current.tag_name != "td" && current.tag_name != "th" {
    self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
  }
  // Pop until td or th
  while self.open_elements.length() > 0 {
    let entry = self.pop_element()
    if entry.tag_name == "td" || entry.tag_name == "th" {
      break
    }
  }
  self.clear_active_formatting_to_marker()
  self.mode = InRow
}

///|
/// Clear stack back to table context
fn TreeBuilder::clear_stack_to_table_context(self : TreeBuilder) -> Unit {
  while self.open_elements.length() > 0 {
    let current = self.current_node()
    if current.tag_name == "table" ||
      current.tag_name == "template" ||
      current.tag_name == "html" {
      break
    }
    let _ = self.pop_element()

  }
}

///|
/// Clear stack back to table body context
fn TreeBuilder::clear_stack_to_table_body_context(self : TreeBuilder) -> Unit {
  while self.open_elements.length() > 0 {
    let current = self.current_node()
    if current.tag_name == "tbody" ||
      current.tag_name == "tfoot" ||
      current.tag_name == "thead" ||
      current.tag_name == "template" ||
      current.tag_name == "html" {
      break
    }
    let _ = self.pop_element()

  }
}

///|
/// Clear stack back to table row context
fn TreeBuilder::clear_stack_to_table_row_context(self : TreeBuilder) -> Unit {
  while self.open_elements.length() > 0 {
    let current = self.current_node()
    if current.tag_name == "tr" ||
      current.tag_name == "template" ||
      current.tag_name == "html" {
      break
    }
    let _ = self.pop_element()

  }
}
