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
/// 13.2.5.32 Before attribute name state
fn Tokenizer::run_before_attribute_name_state(self : Tokenizer) -> Token? {
  match self.consume() {
    Some(c) if is_whitespace(c) => None // Ignore whitespace
    Some('/') | Some('>') => {
      self.reconsume()
      self.state = AfterAttributeName
      None
    }
    Some('=') => {
      self.emit_error(UnexpectedEqualsSignBeforeAttributeName)
      self.start_new_attribute()
      self.current_attr_name.write_char('=')
      self.state = AttributeName
      None
    }
    Some(_) => {
      self.start_new_attribute()
      self.reconsume()
      self.state = AttributeName
      None
    }
    None => {
      self.reconsume()
      self.state = AfterAttributeName
      None
    }
  }
}

///|
/// 13.2.5.33 Attribute name state
fn Tokenizer::run_attribute_name_state(self : Tokenizer) -> Token? {
  match self.consume() {
    Some(c) if is_whitespace(c) || c == '/' || c == '>' => {
      self.reconsume()
      self.state = AfterAttributeName
      None
    }
    Some('=') => {
      self.state = BeforeAttributeValue
      None
    }
    Some(c) if is_ascii_upper_alpha(c) => {
      self.current_attr_name.write_char(to_ascii_lower(c))
      None
    }
    Some('\u{0000}') => {
      self.emit_error(UnexpectedNullCharacter)
      self.current_attr_name.write_char('\u{FFFD}')
      None
    }
    Some('"') | Some('\'') | Some('<') => {
      self.emit_error(UnexpectedCharacterInAttributeName)
      self.current_attr_name.write_char(self.input[self.pos - 1])
      None
    }
    Some(c) => {
      self.current_attr_name.write_char(c)
      None
    }
    None => {
      self.reconsume()
      self.state = AfterAttributeName
      None
    }
  }
}

///|
/// 13.2.5.34 After attribute name state
fn Tokenizer::run_after_attribute_name_state(self : Tokenizer) -> Token? {
  match self.consume() {
    Some(c) if is_whitespace(c) => None // Ignore whitespace
    Some('/') => {
      self.finish_attribute()
      self.state = SelfClosingStartTag
      None
    }
    Some('=') => {
      self.state = BeforeAttributeValue
      None
    }
    Some('>') => {
      self.finish_attribute()
      self.state = Data
      Some(self.emit_current_tag())
    }
    Some(_) => {
      self.finish_attribute()
      self.start_new_attribute()
      self.reconsume()
      self.state = AttributeName
      None
    }
    None => {
      self.emit_error(EofInTag)
      Some(EOF)
    }
  }
}

///|
/// 13.2.5.35 Before attribute value state
fn Tokenizer::run_before_attribute_value_state(self : Tokenizer) -> Token? {
  match self.consume() {
    Some(c) if is_whitespace(c) => None // Ignore whitespace
    Some('"') => {
      self.state = AttributeValueDoubleQuoted
      None
    }
    Some('\'') => {
      self.state = AttributeValueSingleQuoted
      None
    }
    Some('>') => {
      self.emit_error(MissingAttributeValue)
      self.finish_attribute()
      self.state = Data
      Some(self.emit_current_tag())
    }
    Some(_) => {
      self.reconsume()
      self.state = AttributeValueUnquoted
      None
    }
    None => {
      self.emit_error(EofInTag)
      Some(EOF)
    }
  }
}

///|
/// 13.2.5.36 Attribute value (double-quoted) state
fn Tokenizer::run_attribute_value_double_quoted_state(
  self : Tokenizer,
) -> Token? {
  match self.consume() {
    Some('"') => {
      self.state = AfterAttributeValueQuoted
      None
    }
    Some('&') => {
      self.return_state = AttributeValueDoubleQuoted
      self.state = CharacterReference
      None
    }
    Some('\u{0000}') => {
      self.emit_error(UnexpectedNullCharacter)
      self.current_attr_value.write_char('\u{FFFD}')
      None
    }
    Some(c) => {
      self.current_attr_value.write_char(c)
      None
    }
    None => {
      self.emit_error(EofInTag)
      Some(EOF)
    }
  }
}

///|
/// 13.2.5.37 Attribute value (single-quoted) state
fn Tokenizer::run_attribute_value_single_quoted_state(
  self : Tokenizer,
) -> Token? {
  match self.consume() {
    Some('\'') => {
      self.state = AfterAttributeValueQuoted
      None
    }
    Some('&') => {
      self.return_state = AttributeValueSingleQuoted
      self.state = CharacterReference
      None
    }
    Some('\u{0000}') => {
      self.emit_error(UnexpectedNullCharacter)
      self.current_attr_value.write_char('\u{FFFD}')
      None
    }
    Some(c) => {
      self.current_attr_value.write_char(c)
      None
    }
    None => {
      self.emit_error(EofInTag)
      Some(EOF)
    }
  }
}

///|
/// 13.2.5.38 Attribute value (unquoted) state
fn Tokenizer::run_attribute_value_unquoted_state(self : Tokenizer) -> Token? {
  match self.consume() {
    Some(c) if is_whitespace(c) => {
      self.finish_attribute()
      self.state = BeforeAttributeName
      None
    }
    Some('&') => {
      self.return_state = AttributeValueUnquoted
      self.state = CharacterReference
      None
    }
    Some('>') => {
      self.finish_attribute()
      self.state = Data
      Some(self.emit_current_tag())
    }
    Some('\u{0000}') => {
      self.emit_error(UnexpectedNullCharacter)
      self.current_attr_value.write_char('\u{FFFD}')
      None
    }
    Some('"') | Some('\'') | Some('<') | Some('=') | Some('`') => {
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      self.current_attr_value.write_char(self.input[self.pos - 1])
      None
    }
    Some(c) => {
      self.current_attr_value.write_char(c)
      None
    }
    None => {
      self.emit_error(EofInTag)
      Some(EOF)
    }
  }
}

///|
/// 13.2.5.39 After attribute value (quoted) state
fn Tokenizer::run_after_attribute_value_quoted_state(
  self : Tokenizer,
) -> Token? {
  match self.consume() {
    Some(c) if is_whitespace(c) => {
      self.finish_attribute()
      self.state = BeforeAttributeName
      None
    }
    Some('/') => {
      self.finish_attribute()
      self.state = SelfClosingStartTag
      None
    }
    Some('>') => {
      self.finish_attribute()
      self.state = Data
      Some(self.emit_current_tag())
    }
    Some(_) => {
      self.emit_error(MissingWhitespaceBetweenAttributes)
      self.finish_attribute()
      self.reconsume()
      self.state = BeforeAttributeName
      None
    }
    None => {
      self.emit_error(EofInTag)
      Some(EOF)
    }
  }
}
