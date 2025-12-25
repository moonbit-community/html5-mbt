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
/// HTML5 Tokenizer per WHATWG Living Standard
pub struct Tokenizer {
  // Input
  input : Array[Char]
  mut pos : Int
  mut line : Int
  mut column : Int
  mut saw_eof : Bool // Track if last consume returned EOF

  // State machine
  mut state : State
  mut return_state : State // For character reference

  // Error collection
  errors : Array[ParseError]

  // Current tag being built
  current_tag_name : StringBuilder
  mut current_tag_is_end : Bool
  mut current_tag_self_closing : Bool
  current_attrs : Array[Attribute]
  current_attr_name : StringBuilder
  current_attr_value : StringBuilder

  // Current comment/doctype being built
  current_comment : StringBuilder
  current_doctype_name : StringBuilder
  current_doctype_public_id : StringBuilder
  current_doctype_system_id : StringBuilder
  mut current_doctype_force_quirks : Bool
  mut current_doctype_public_id_set : Bool
  mut current_doctype_system_id_set : Bool

  // Character reference
  mut char_ref_code : Int
  temp_buffer : StringBuilder

  // For appropriate end tag check
  mut last_start_tag_name : String

  // Pending tokens (some states emit multiple)
  pending_tokens : Array[Token]
}

///|
/// Create a tokenizer from a string
pub fn Tokenizer::new(input : String) -> Tokenizer {
  {
    input: input.to_array(),
    pos: 0,
    line: 1,
    column: 1,
    saw_eof: false,
    state: Data,
    return_state: Data,
    errors: [],
    current_tag_name: StringBuilder::new(),
    current_tag_is_end: false,
    current_tag_self_closing: false,
    current_attrs: [],
    current_attr_name: StringBuilder::new(),
    current_attr_value: StringBuilder::new(),
    current_comment: StringBuilder::new(),
    current_doctype_name: StringBuilder::new(),
    current_doctype_public_id: StringBuilder::new(),
    current_doctype_system_id: StringBuilder::new(),
    current_doctype_force_quirks: false,
    current_doctype_public_id_set: false,
    current_doctype_system_id_set: false,
    char_ref_code: 0,
    temp_buffer: StringBuilder::new(),
    last_start_tag_name: "",
    pending_tokens: [],
  }
}

///|
/// Check if at end of input
fn Tokenizer::is_eof(self : Tokenizer) -> Bool {
  self.pos >= self.input.length()
}

///|
/// Get current source position
pub fn Tokenizer::get_position(self : Tokenizer) -> SourcePosition {
  { line: self.line, column: self.column, offset: self.pos }
}

///|
/// Peek at current character without consuming
/// Returns LF for CR (normalization)
fn Tokenizer::peek(self : Tokenizer) -> Char? {
  if self.pos < self.input.length() {
    let c = self.input[self.pos]
    // Normalize CR to LF when peeking
    if c == '\r' {
      Some('\n')
    } else {
      Some(c)
    }
  } else {
    None
  }
}

///|
/// Peek at character at offset from current position
fn Tokenizer::peek_at(self : Tokenizer, offset : Int) -> Char? {
  let idx = self.pos + offset
  if idx >= 0 && idx < self.input.length() {
    Some(self.input[idx])
  } else {
    None
  }
}

///|
/// Consume and return current character
/// Normalizes CR and CRLF to LF per WHATWG spec
fn Tokenizer::consume(self : Tokenizer) -> Char? {
  if self.pos < self.input.length() {
    self.saw_eof = false
    let mut c = self.input[self.pos]
    self.pos += 1
    // Normalize CR to LF (WHATWG preprocessing)
    if c == '\r' {
      c = '\n'
      // Skip following LF if present (CRLF -> single LF)
      if self.pos < self.input.length() && self.input[self.pos] == '\n' {
        self.pos += 1
      }
    }
    if c == '\n' {
      self.line += 1
      self.column = 1
    } else {
      self.column += 1
    }
    Some(c)
  } else {
    self.saw_eof = true
    None
  }
}

///|
/// Reconsume current character (go back one position)
/// If we're at EOF, stay at EOF (don't go back to last char)
fn Tokenizer::reconsume(self : Tokenizer) -> Unit {
  // If we just saw EOF, don't go back - we want to stay at EOF
  if self.saw_eof {
    return
  }
  if self.pos > 0 {
    self.pos -= 1
    // Adjust line/column tracking
    if self.input[self.pos] == '\n' {
      self.line -= 1
      // Column is approximate here, but rarely matters for error messages
      self.column = 1
    } else {
      self.column -= 1
    }
  }
}

///|
/// Get current source position
fn Tokenizer::current_position(self : Tokenizer) -> SourcePosition {
  { line: self.line, column: self.column, offset: self.pos }
}

///|
/// Emit a parse error
fn Tokenizer::emit_error(self : Tokenizer, code : ParseErrorCode) -> Unit {
  self.errors.push({ code, position: self.current_position() })
}

///|
/// Get all parse errors
pub fn Tokenizer::get_errors(self : Tokenizer) -> Array[ParseError] {
  self.errors
}

///|
/// Reset tag building state for a new tag
fn Tokenizer::reset_tag(self : Tokenizer, is_end : Bool) -> Unit {
  self.current_tag_name.reset()
  self.current_tag_is_end = is_end
  self.current_tag_self_closing = false
  self.current_attrs.clear()
  self.current_attr_name.reset()
  self.current_attr_value.reset()
}

///|
/// Start a new attribute
fn Tokenizer::start_new_attribute(self : Tokenizer) -> Unit {
  self.current_attr_name.reset()
  self.current_attr_value.reset()
}

///|
/// Finish current attribute and add to list
fn Tokenizer::finish_attribute(self : Tokenizer) -> Unit {
  let name = self.current_attr_name.to_string()
  let value = self.current_attr_value.to_string()
  // Check for duplicate attribute
  let duplicate = self.current_attrs.iter().any(fn(attr) { attr.name == name })
  if duplicate {
    self.emit_error(DuplicateAttribute)
  } else {
    self.current_attrs.push({ name, value })
  }
}

///|
/// Emit current tag as token
fn Tokenizer::emit_current_tag(self : Tokenizer) -> Token {
  let name = self.current_tag_name.to_string().to_lower()
  if self.current_tag_is_end {
    // End tags shouldn't have attributes or self-closing flag
    if self.current_attrs.length() > 0 {
      self.emit_error(EndTagWithAttributes)
    }
    if self.current_tag_self_closing {
      self.emit_error(EndTagWithTrailingSolidus)
    }
    EndTag(name~)
  } else {
    self.last_start_tag_name = name
    StartTag(
      name~,
      attrs=self.current_attrs.copy(),
      self_closing=self.current_tag_self_closing,
    )
  }
}

///|
/// Emit current comment as token
fn Tokenizer::emit_current_comment(self : Tokenizer) -> Token {
  Comment(self.current_comment.to_string())
}

///|
/// Emit current DOCTYPE as token
fn Tokenizer::emit_current_doctype(self : Tokenizer) -> Token {
  let name = if self.current_doctype_name.to_string().length() > 0 {
    Some(self.current_doctype_name.to_string())
  } else {
    None
  }
  let public_id = if self.current_doctype_public_id_set {
    Some(self.current_doctype_public_id.to_string())
  } else {
    None
  }
  let system_id = if self.current_doctype_system_id_set {
    Some(self.current_doctype_system_id.to_string())
  } else {
    None
  }
  DOCTYPE(
    name~,
    public_id~,
    system_id~,
    force_quirks=self.current_doctype_force_quirks,
  )
}

///|
/// Reset DOCTYPE building state
fn Tokenizer::reset_doctype(self : Tokenizer) -> Unit {
  self.current_doctype_name.reset()
  self.current_doctype_public_id.reset()
  self.current_doctype_system_id.reset()
  self.current_doctype_force_quirks = false
  self.current_doctype_public_id_set = false
  self.current_doctype_system_id_set = false
}

///|
/// Reset comment building state
fn Tokenizer::reset_comment(self : Tokenizer) -> Unit {
  self.current_comment.reset()
}

///|
/// Check if current end tag is appropriate (matches last start tag)
fn Tokenizer::is_appropriate_end_tag(self : Tokenizer) -> Bool {
  self.current_tag_name.to_string().to_lower() == self.last_start_tag_name
}

///|
/// ASCII lowercase a character
fn to_ascii_lower(c : Char) -> Char {
  if c >= 'A' && c <= 'Z' {
    Int::unsafe_to_char(c.to_int() + 32)
  } else {
    c
  }
}

///|
/// Check if character is ASCII alpha
fn is_ascii_alpha(c : Char) -> Bool {
  (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z')
}

///|
/// Check if character is ASCII alphanumeric
fn is_ascii_alphanumeric(c : Char) -> Bool {
  is_ascii_alpha(c) || (c >= '0' && c <= '9')
}

///|
/// Check if character is ASCII upper alpha
fn is_ascii_upper_alpha(c : Char) -> Bool {
  c >= 'A' && c <= 'Z'
}

///|
/// Check if character is ASCII lower alpha
fn is_ascii_lower_alpha(c : Char) -> Bool {
  c >= 'a' && c <= 'z'
}

///|
/// Check if character is ASCII digit
fn is_ascii_digit(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

///|
/// Check if character is ASCII upper hex digit
fn is_ascii_upper_hex_digit(c : Char) -> Bool {
  c >= 'A' && c <= 'F'
}

///|
/// Check if character is ASCII lower hex digit
fn is_ascii_lower_hex_digit(c : Char) -> Bool {
  c >= 'a' && c <= 'f'
}

///|
/// Check if character is ASCII hex digit
fn is_ascii_hex_digit(c : Char) -> Bool {
  is_ascii_digit(c) ||
  is_ascii_upper_hex_digit(c) ||
  is_ascii_lower_hex_digit(c)
}

///|
/// Check if character is whitespace per HTML spec
fn is_whitespace(c : Char) -> Bool {
  c == '\t' || c == '\n' || c == '\u{0C}' || c == ' '
}

///|
/// Switch tokenizer to RCDATA mode (for <textarea>, <title>)
pub fn Tokenizer::switch_to_rcdata(self : Tokenizer) -> Unit {
  self.state = RCDATA
}

///|
/// Switch tokenizer to RAWTEXT mode (for <style>, <xmp>, etc.)
pub fn Tokenizer::switch_to_rawtext(self : Tokenizer) -> Unit {
  self.state = RAWTEXT
}

///|
/// Switch tokenizer to Script Data mode (for <script>)
pub fn Tokenizer::switch_to_script_data(self : Tokenizer) -> Unit {
  self.state = ScriptData
}

///|
/// Switch tokenizer to PLAINTEXT mode (for <plaintext>)
pub fn Tokenizer::switch_to_plaintext(self : Tokenizer) -> Unit {
  self.state = PLAINTEXT
}

///|
/// Read the next token
pub fn Tokenizer::next_token(self : Tokenizer) -> Token {
  // Run state machine until we get a token
  while true {
    // Return pending token if any
    if self.pending_tokens.length() > 0 {
      return self.pending_tokens.remove(0)
    }
    let token : Token? = match self.state {
      // Data states
      Data => self.run_data_state()
      RCDATA => self.run_rcdata_state()
      RAWTEXT => self.run_rawtext_state()
      ScriptData => self.run_script_data_state()
      PLAINTEXT => self.run_plaintext_state()

      // Tag states
      TagOpen => self.run_tag_open_state()
      EndTagOpen => self.run_end_tag_open_state()
      TagName => self.run_tag_name_state()
      SelfClosingStartTag => self.run_self_closing_start_tag_state()

      // RCDATA states
      RCDATALessThanSign => self.run_rcdata_less_than_sign_state()
      RCDATAEndTagOpen => self.run_rcdata_end_tag_open_state()
      RCDATAEndTagName => self.run_rcdata_end_tag_name_state()

      // RAWTEXT states
      RAWTEXTLessThanSign => self.run_rawtext_less_than_sign_state()
      RAWTEXTEndTagOpen => self.run_rawtext_end_tag_open_state()
      RAWTEXTEndTagName => self.run_rawtext_end_tag_name_state()

      // Script data states
      ScriptDataLessThanSign => self.run_script_data_less_than_sign_state()
      ScriptDataEndTagOpen => self.run_script_data_end_tag_open_state()
      ScriptDataEndTagName => self.run_script_data_end_tag_name_state()
      ScriptDataEscapeStart => self.run_script_data_escape_start_state()
      ScriptDataEscapeStartDash =>
        self.run_script_data_escape_start_dash_state()
      ScriptDataEscaped => self.run_script_data_escaped_state()
      ScriptDataEscapedDash => self.run_script_data_escaped_dash_state()
      ScriptDataEscapedDashDash =>
        self.run_script_data_escaped_dash_dash_state()
      ScriptDataEscapedLessThanSign =>
        self.run_script_data_escaped_less_than_sign_state()
      ScriptDataEscapedEndTagOpen =>
        self.run_script_data_escaped_end_tag_open_state()
      ScriptDataEscapedEndTagName =>
        self.run_script_data_escaped_end_tag_name_state()
      ScriptDataDoubleEscapeStart =>
        self.run_script_data_double_escape_start_state()
      ScriptDataDoubleEscaped => self.run_script_data_double_escaped_state()
      ScriptDataDoubleEscapedDash =>
        self.run_script_data_double_escaped_dash_state()
      ScriptDataDoubleEscapedDashDash =>
        self.run_script_data_double_escaped_dash_dash_state()
      ScriptDataDoubleEscapedLessThanSign =>
        self.run_script_data_double_escaped_less_than_sign_state()
      ScriptDataDoubleEscapeEnd =>
        self.run_script_data_double_escape_end_state()

      // Attribute states
      BeforeAttributeName => self.run_before_attribute_name_state()
      AttributeName => self.run_attribute_name_state()
      AfterAttributeName => self.run_after_attribute_name_state()
      BeforeAttributeValue => self.run_before_attribute_value_state()
      AttributeValueDoubleQuoted =>
        self.run_attribute_value_double_quoted_state()
      AttributeValueSingleQuoted =>
        self.run_attribute_value_single_quoted_state()
      AttributeValueUnquoted => self.run_attribute_value_unquoted_state()
      AfterAttributeValueQuoted => self.run_after_attribute_value_quoted_state()

      // Comment states
      BogusComment => self.run_bogus_comment_state()
      MarkupDeclarationOpen => self.run_markup_declaration_open_state()
      CommentStart => self.run_comment_start_state()
      CommentStartDash => self.run_comment_start_dash_state()
      Comment => self.run_comment_state()
      CommentLessThanSign => self.run_comment_less_than_sign_state()
      CommentLessThanSignBang => self.run_comment_less_than_sign_bang_state()
      CommentLessThanSignBangDash =>
        self.run_comment_less_than_sign_bang_dash_state()
      CommentLessThanSignBangDashDash =>
        self.run_comment_less_than_sign_bang_dash_dash_state()
      CommentEndDash => self.run_comment_end_dash_state()
      CommentEnd => self.run_comment_end_state()
      CommentEndBang => self.run_comment_end_bang_state()

      // DOCTYPE states
      DOCTYPE => self.run_doctype_state()
      BeforeDOCTYPEName => self.run_before_doctype_name_state()
      DOCTYPEName => self.run_doctype_name_state()
      AfterDOCTYPEName => self.run_after_doctype_name_state()
      AfterDOCTYPEPublicKeyword => self.run_after_doctype_public_keyword_state()
      BeforeDOCTYPEPublicIdentifier =>
        self.run_before_doctype_public_identifier_state()
      DOCTYPEPublicIdentifierDoubleQuoted =>
        self.run_doctype_public_identifier_double_quoted_state()
      DOCTYPEPublicIdentifierSingleQuoted =>
        self.run_doctype_public_identifier_single_quoted_state()
      AfterDOCTYPEPublicIdentifier =>
        self.run_after_doctype_public_identifier_state()
      BetweenDOCTYPEPublicAndSystemIdentifiers =>
        self.run_between_doctype_public_and_system_identifiers_state()
      AfterDOCTYPESystemKeyword => self.run_after_doctype_system_keyword_state()
      BeforeDOCTYPESystemIdentifier =>
        self.run_before_doctype_system_identifier_state()
      DOCTYPESystemIdentifierDoubleQuoted =>
        self.run_doctype_system_identifier_double_quoted_state()
      DOCTYPESystemIdentifierSingleQuoted =>
        self.run_doctype_system_identifier_single_quoted_state()
      AfterDOCTYPESystemIdentifier =>
        self.run_after_doctype_system_identifier_state()
      BogusDOCTYPE => self.run_bogus_doctype_state()

      // CDATA states
      CDATASection => self.run_cdata_section_state()
      CDATASectionBracket => self.run_cdata_section_bracket_state()
      CDATASectionEnd => self.run_cdata_section_end_state()

      // Character reference states
      CharacterReference => self.run_character_reference_state()
      NamedCharacterReference => self.run_named_character_reference_state()
      AmbiguousAmpersand => self.run_ambiguous_ampersand_state()
      NumericCharacterReference => self.run_numeric_character_reference_state()
      HexadecimalCharacterReferenceStart =>
        self.run_hexadecimal_character_reference_start_state()
      DecimalCharacterReferenceStart =>
        self.run_decimal_character_reference_start_state()
      HexadecimalCharacterReference =>
        self.run_hexadecimal_character_reference_state()
      DecimalCharacterReference => self.run_decimal_character_reference_state()
      NumericCharacterReferenceEnd =>
        self.run_numeric_character_reference_end_state()
    }
    match token {
      Some(t) => return t
      None => continue
    }
  }
  // Unreachable, but needed for type checker
  EOF
}

///|
/// Tokenize entire input and return all tokens
pub fn tokenize(input : String) -> (Array[Token], Array[ParseError]) {
  let tokenizer = Tokenizer::new(input)
  let tokens : Array[Token] = []
  while true {
    let token = tokenizer.next_token()
    tokens.push(token)
    match token {
      EOF => break
      _ => continue
    }
  }
  (tokens, tokenizer.get_errors())
}
