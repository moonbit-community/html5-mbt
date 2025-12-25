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
/// 13.2.5.72 Character reference state
fn Tokenizer::run_character_reference_state(self : Tokenizer) -> Token? {
  self.temp_buffer.reset()
  self.temp_buffer.write_char('&')
  match self.peek() {
    Some(c) if is_ascii_alphanumeric(c) => {
      self.state = NamedCharacterReference
      None
    }
    Some('#') => {
      let _ = self.consume()
      self.temp_buffer.write_char('#')
      self.state = NumericCharacterReference
      None
    }
    _ => {
      self.flush_temp_buffer()
      self.state = self.return_state
      None
    }
  }
}

///|
/// 13.2.5.73 Named character reference state
fn Tokenizer::run_named_character_reference_state(self : Tokenizer) -> Token? {
  // Try to find longest matching entity
  let matched = self.try_match_named_entity()
  match matched {
    Some((entity_name, codepoints)) => {
      // Check if we need special handling for attribute values
      let last_char = entity_name.to_array()[entity_name.to_array().length() - 1]
      let in_attribute = self.return_state == AttributeValueDoubleQuoted ||
        self.return_state == AttributeValueSingleQuoted ||
        self.return_state == AttributeValueUnquoted
      if in_attribute && last_char != ';' {
        // Check next input character
        match self.peek() {
          Some('=') => {
            // Don't consume as entity, flush as text
            self.flush_temp_buffer()
            self.state = self.return_state
            return None
          }
          Some(c) if is_ascii_alphanumeric(c) => {
            // Don't consume as entity, flush as text
            self.flush_temp_buffer()
            self.state = self.return_state
            return None
          }
          _ => ()
        }
      }
      // Emit error if entity doesn't end with semicolon
      if last_char != ';' {
        self.emit_error(MissingSemicolonAfterCharacterReference)
      }
      // Clear temp buffer and emit codepoints
      self.temp_buffer.reset()
      for cp in codepoints {
        self.emit_char_to_current_context(Int::unsafe_to_char(cp))
      }
      self.state = self.return_state
      None
    }
    None => {
      // No entity found, flush the & and go to ambiguous state
      self.flush_temp_buffer()
      self.state = AmbiguousAmpersand
      None
    }
  }
}

///|
/// 13.2.5.74 Ambiguous ampersand state
fn Tokenizer::run_ambiguous_ampersand_state(self : Tokenizer) -> Token? {
  match self.consume() {
    Some(c) if is_ascii_alphanumeric(c) => {
      self.emit_char_to_current_context(c)
      None
    }
    Some(';') => {
      self.emit_error(UnknownNamedCharacterReference)
      self.reconsume()
      self.state = self.return_state
      None
    }
    Some(_) => {
      self.reconsume()
      self.state = self.return_state
      None
    }
    None => {
      self.state = self.return_state
      None
    }
  }
}

///|
/// 13.2.5.75 Numeric character reference state
fn Tokenizer::run_numeric_character_reference_state(self : Tokenizer) -> Token? {
  self.char_ref_code = 0
  match self.peek() {
    Some('x') | Some('X') => {
      let c = self.consume().unwrap()
      self.temp_buffer.write_char(c)
      self.state = HexadecimalCharacterReferenceStart
      None
    }
    _ => {
      self.state = DecimalCharacterReferenceStart
      None
    }
  }
}

///|
/// 13.2.5.76 Hexadecimal character reference start state
fn Tokenizer::run_hexadecimal_character_reference_start_state(
  self : Tokenizer,
) -> Token? {
  match self.peek() {
    Some(c) if is_ascii_hex_digit(c) => {
      self.state = HexadecimalCharacterReference
      None
    }
    _ => {
      self.emit_error(AbsenceOfDigitsInNumericCharacterReference)
      self.flush_temp_buffer()
      self.state = self.return_state
      None
    }
  }
}

///|
/// 13.2.5.77 Decimal character reference start state
fn Tokenizer::run_decimal_character_reference_start_state(
  self : Tokenizer,
) -> Token? {
  match self.peek() {
    Some(c) if is_ascii_digit(c) => {
      self.state = DecimalCharacterReference
      None
    }
    _ => {
      self.emit_error(AbsenceOfDigitsInNumericCharacterReference)
      self.flush_temp_buffer()
      self.state = self.return_state
      None
    }
  }
}

///|
/// 13.2.5.78 Hexadecimal character reference state
fn Tokenizer::run_hexadecimal_character_reference_state(
  self : Tokenizer,
) -> Token? {
  match self.consume() {
    Some(c) if is_ascii_digit(c) => {
      self.char_ref_code = self.char_ref_code * 16 + (c.to_int() - 0x30)
      None
    }
    Some(c) if is_ascii_upper_hex_digit(c) => {
      self.char_ref_code = self.char_ref_code * 16 + (c.to_int() - 0x37)
      None
    }
    Some(c) if is_ascii_lower_hex_digit(c) => {
      self.char_ref_code = self.char_ref_code * 16 + (c.to_int() - 0x57)
      None
    }
    Some(';') => {
      self.state = NumericCharacterReferenceEnd
      None
    }
    Some(_) => {
      self.emit_error(MissingSemicolonAfterCharacterReference)
      self.reconsume()
      self.state = NumericCharacterReferenceEnd
      None
    }
    None => {
      self.emit_error(MissingSemicolonAfterCharacterReference)
      self.state = NumericCharacterReferenceEnd
      None
    }
  }
}

///|
/// 13.2.5.79 Decimal character reference state
fn Tokenizer::run_decimal_character_reference_state(self : Tokenizer) -> Token? {
  match self.consume() {
    Some(c) if is_ascii_digit(c) => {
      self.char_ref_code = self.char_ref_code * 10 + (c.to_int() - 0x30)
      None
    }
    Some(';') => {
      self.state = NumericCharacterReferenceEnd
      None
    }
    Some(_) => {
      self.emit_error(MissingSemicolonAfterCharacterReference)
      self.reconsume()
      self.state = NumericCharacterReferenceEnd
      None
    }
    None => {
      self.emit_error(MissingSemicolonAfterCharacterReference)
      self.state = NumericCharacterReferenceEnd
      None
    }
  }
}

///|
/// 13.2.5.80 Numeric character reference end state
fn Tokenizer::run_numeric_character_reference_end_state(
  self : Tokenizer,
) -> Token? {
  let code = self.char_ref_code
  // Check for errors and apply replacements
  let final_char = if code == 0 {
    self.emit_error(NullCharacterReference)
    '\u{FFFD}'
  } else if code > 0x10FFFF {
    self.emit_error(CharacterReferenceOutsideUnicodeRange)
    '\u{FFFD}'
  } else if code >= 0xD800 && code <= 0xDFFF {
    self.emit_error(SurrogateCharacterReference)
    '\u{FFFD}'
  } else if is_noncharacter(code) {
    self.emit_error(NoncharacterCharacterReference)
    Int::unsafe_to_char(code)
  } else if code == 0x0D ||
    (is_control_char(code) && not(is_ascii_whitespace_code(code))) {
    self.emit_error(ControlCharacterReference)
    // Apply Windows-1252 remapping for 0x80-0x9F
    remap_windows_1252(code)
  } else {
    Int::unsafe_to_char(code)
  }
  self.temp_buffer.reset()
  self.emit_char_to_current_context(final_char)
  self.state = self.return_state
  None
}

///|
/// Helper: flush temp buffer to current context
fn Tokenizer::flush_temp_buffer(self : Tokenizer) -> Unit {
  let buf = self.temp_buffer.to_string()
  for c in buf {
    self.emit_char_to_current_context(c)
  }
}

///|
/// Helper: emit character to current context (attribute value or token stream)
fn Tokenizer::emit_char_to_current_context(self : Tokenizer, c : Char) -> Unit {
  match self.return_state {
    AttributeValueDoubleQuoted
    | AttributeValueSingleQuoted
    | AttributeValueUnquoted => self.current_attr_value.write_char(c)
    _ => self.pending_tokens.push(Character(c))
  }
}

///|
/// Check if code point is a noncharacter
fn is_noncharacter(code : Int) -> Bool {
  (code >= 0xFDD0 && code <= 0xFDEF) ||
  (code & 0xFFFF) == 0xFFFE ||
  (code & 0xFFFF) == 0xFFFF
}

///|
/// Check if code point is a control character
fn is_control_char(code : Int) -> Bool {
  (code >= 0x00 && code <= 0x1F) || (code >= 0x7F && code <= 0x9F)
}

///|
/// Check if code point is ASCII whitespace
fn is_ascii_whitespace_code(code : Int) -> Bool {
  code == 0x09 || code == 0x0A || code == 0x0C || code == 0x0D || code == 0x20
}

///|
/// Windows-1252 remapping for control characters 0x80-0x9F
fn remap_windows_1252(code : Int) -> Char {
  if code >= 0x80 && code <= 0x9F {
    let table : FixedArray[Int] = [
      0x20AC, 0x0081, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, 0x02C6, 0x2030,
      0x0160, 0x2039, 0x0152, 0x008D, 0x017D, 0x008F, 0x0090, 0x2018, 0x2019, 0x201C,
      0x201D, 0x2022, 0x2013, 0x2014, 0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0x009D,
      0x017E, 0x0178,
    ]
    Int::unsafe_to_char(table[code - 0x80])
  } else {
    Int::unsafe_to_char(code)
  }
}

///|
/// Try to match a named character reference
/// Returns (entity_name, codepoints) if found
fn Tokenizer::try_match_named_entity(self : Tokenizer) -> (String, Array[Int])? {
  // Build up the entity name character by character
  let name_buf = StringBuilder::new()
  let mut best_match : (String, Array[Int])? = None
  let mut consumed = 0
  while true {
    match self.peek_at(consumed) {
      Some(c) if is_ascii_alphanumeric(c) || c == ';' => {
        name_buf.write_char(c)
        consumed += 1
        let candidate = name_buf.to_string()
        // Check if this is a valid entity
        match lookup_entity(candidate) {
          Some(cps) => best_match = Some((candidate, cps))
          None => ()
        }
        // Stop at semicolon
        if c == ';' {
          break
        }
      }
      _ => break
    }
    // Safety limit
    if consumed > 32 {
      break
    }
  }
  // Consume the matched characters
  match best_match {
    Some((name, _)) => {
      let len = name.to_array().length()
      for _ in 0..<len {
        let c = self.consume().unwrap()
        self.temp_buffer.write_char(c)
      }
    }
    None => ()
  }
  best_match
}

///|
/// 13.2.5.69 CDATA section state
fn Tokenizer::run_cdata_section_state(self : Tokenizer) -> Token? {
  match self.consume() {
    Some(']') => {
      self.state = CDATASectionBracket
      None
    }
    Some(c) => Some(Character(c))
    None => {
      self.emit_error(EofInCdata)
      Some(EOF)
    }
  }
}

///|
/// 13.2.5.70 CDATA section bracket state
fn Tokenizer::run_cdata_section_bracket_state(self : Tokenizer) -> Token? {
  match self.consume() {
    Some(']') => {
      self.state = CDATASectionEnd
      None
    }
    Some(_) => {
      self.reconsume()
      self.state = CDATASection
      Some(Character(']'))
    }
    None => {
      self.reconsume()
      self.state = CDATASection
      Some(Character(']'))
    }
  }
}

///|
/// 13.2.5.71 CDATA section end state
fn Tokenizer::run_cdata_section_end_state(self : Tokenizer) -> Token? {
  match self.consume() {
    Some(']') => Some(Character(']'))
    Some('>') => {
      self.state = Data
      None
    }
    Some(_) => {
      self.reconsume()
      self.state = CDATASection
      self.pending_tokens.push(Character(']'))
      Some(Character(']'))
    }
    None => {
      self.reconsume()
      self.state = CDATASection
      self.pending_tokens.push(Character(']'))
      Some(Character(']'))
    }
  }
}
