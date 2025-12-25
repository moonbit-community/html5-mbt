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
/// 13.2.5.1 Data state
fn Tokenizer::run_data_state(self : Tokenizer) -> Token? {
  match self.consume() {
    Some('&') => {
      self.return_state = Data
      self.state = CharacterReference
      None
    }
    Some('<') => {
      self.state = TagOpen
      None
    }
    Some('\u{0000}') => {
      self.emit_error(UnexpectedNullCharacter)
      Some(Character('\u{FFFD}'))
    }
    Some(c) => Some(Character(c))
    None => Some(EOF)
  }
}

///|
/// 13.2.5.2 RCDATA state
fn Tokenizer::run_rcdata_state(self : Tokenizer) -> Token? {
  match self.consume() {
    Some('&') => {
      self.return_state = RCDATA
      self.state = CharacterReference
      None
    }
    Some('<') => {
      self.state = RCDATALessThanSign
      None
    }
    Some('\u{0000}') => {
      self.emit_error(UnexpectedNullCharacter)
      Some(Character('\u{FFFD}'))
    }
    Some(c) => Some(Character(c))
    None => Some(EOF)
  }
}

///|
/// 13.2.5.3 RAWTEXT state
fn Tokenizer::run_rawtext_state(self : Tokenizer) -> Token? {
  match self.consume() {
    Some('<') => {
      self.state = RAWTEXTLessThanSign
      None
    }
    Some('\u{0000}') => {
      self.emit_error(UnexpectedNullCharacter)
      Some(Character('\u{FFFD}'))
    }
    Some(c) => Some(Character(c))
    None => Some(EOF)
  }
}

///|
/// 13.2.5.4 Script data state
fn Tokenizer::run_script_data_state(self : Tokenizer) -> Token? {
  match self.consume() {
    Some('<') => {
      self.state = ScriptDataLessThanSign
      None
    }
    Some('\u{0000}') => {
      self.emit_error(UnexpectedNullCharacter)
      Some(Character('\u{FFFD}'))
    }
    Some(c) => Some(Character(c))
    None => Some(EOF)
  }
}

///|
/// 13.2.5.5 PLAINTEXT state
fn Tokenizer::run_plaintext_state(self : Tokenizer) -> Token? {
  match self.consume() {
    Some('\u{0000}') => {
      self.emit_error(UnexpectedNullCharacter)
      Some(Character('\u{FFFD}'))
    }
    Some(c) => Some(Character(c))
    None => Some(EOF)
  }
}

///|
/// 13.2.5.6 Tag open state
fn Tokenizer::run_tag_open_state(self : Tokenizer) -> Token? {
  match self.consume() {
    Some('!') => {
      self.state = MarkupDeclarationOpen
      None
    }
    Some('/') => {
      self.state = EndTagOpen
      None
    }
    Some(c) if is_ascii_alpha(c) => {
      self.reset_tag(false)
      self.reconsume()
      self.state = TagName
      None
    }
    Some('?') => {
      self.emit_error(UnexpectedQuestionMarkInsteadOfTagName)
      self.reset_comment()
      self.reconsume()
      self.state = BogusComment
      None
    }
    Some(_) => {
      self.emit_error(InvalidFirstCharacterOfTagName)
      self.reconsume()
      self.state = Data
      Some(Character('<'))
    }
    None => {
      self.emit_error(EofBeforeTagName)
      self.pending_tokens.push(EOF)
      Some(Character('<'))
    }
  }
}

///|
/// 13.2.5.7 End tag open state
fn Tokenizer::run_end_tag_open_state(self : Tokenizer) -> Token? {
  match self.consume() {
    Some(c) if is_ascii_alpha(c) => {
      self.reset_tag(true)
      self.reconsume()
      self.state = TagName
      None
    }
    Some('>') => {
      self.emit_error(MissingEndTagName)
      self.state = Data
      None
    }
    Some(_) => {
      self.emit_error(InvalidFirstCharacterOfTagName)
      self.reset_comment()
      self.reconsume()
      self.state = BogusComment
      None
    }
    None => {
      self.emit_error(EofBeforeTagName)
      self.pending_tokens.push(Character('/'))
      self.pending_tokens.push(EOF)
      Some(Character('<'))
    }
  }
}

///|
/// 13.2.5.8 Tag name state
fn Tokenizer::run_tag_name_state(self : Tokenizer) -> Token? {
  match self.consume() {
    Some(c) if is_whitespace(c) => {
      self.state = BeforeAttributeName
      None
    }
    Some('/') => {
      self.state = SelfClosingStartTag
      None
    }
    Some('>') => {
      self.state = Data
      Some(self.emit_current_tag())
    }
    Some(c) if is_ascii_upper_alpha(c) => {
      self.current_tag_name.write_char(to_ascii_lower(c))
      None
    }
    Some('\u{0000}') => {
      self.emit_error(UnexpectedNullCharacter)
      self.current_tag_name.write_char('\u{FFFD}')
      None
    }
    Some(c) => {
      self.current_tag_name.write_char(c)
      None
    }
    None => {
      self.emit_error(EofInTag)
      Some(EOF)
    }
  }
}

///|
/// 13.2.5.9 RCDATA less-than sign state
fn Tokenizer::run_rcdata_less_than_sign_state(self : Tokenizer) -> Token? {
  match self.peek() {
    Some('/') => {
      let _ = self.consume()
      self.temp_buffer.reset()
      self.state = RCDATAEndTagOpen
      None
    }
    _ => {
      self.state = RCDATA
      Some(Character('<'))
    }
  }
}

///|
/// 13.2.5.10 RCDATA end tag open state
fn Tokenizer::run_rcdata_end_tag_open_state(self : Tokenizer) -> Token? {
  match self.peek() {
    Some(c) if is_ascii_alpha(c) => {
      self.reset_tag(true)
      self.state = RCDATAEndTagName
      None
    }
    _ => {
      self.state = RCDATA
      self.pending_tokens.push(Character('/'))
      Some(Character('<'))
    }
  }
}

///|
/// 13.2.5.11 RCDATA end tag name state
fn Tokenizer::run_rcdata_end_tag_name_state(self : Tokenizer) -> Token? {
  match self.consume() {
    Some(c) if is_whitespace(c) =>
      if self.is_appropriate_end_tag() {
        self.state = BeforeAttributeName
        None
      } else {
        self.emit_temp_buffer_as_chars('<', '/')
        self.pending_tokens.push(Character(c))
        self.state = RCDATA
        None
      }
    Some('/') =>
      if self.is_appropriate_end_tag() {
        self.state = SelfClosingStartTag
        None
      } else {
        self.emit_temp_buffer_as_chars('<', '/')
        self.pending_tokens.push(Character('/'))
        self.state = RCDATA
        None
      }
    Some('>') =>
      if self.is_appropriate_end_tag() {
        self.state = Data
        Some(self.emit_current_tag())
      } else {
        self.emit_temp_buffer_as_chars('<', '/')
        self.pending_tokens.push(Character('>'))
        self.state = RCDATA
        None
      }
    Some(c) if is_ascii_upper_alpha(c) => {
      self.current_tag_name.write_char(to_ascii_lower(c))
      self.temp_buffer.write_char(c)
      None
    }
    Some(c) if is_ascii_lower_alpha(c) => {
      self.current_tag_name.write_char(c)
      self.temp_buffer.write_char(c)
      None
    }
    None =>
      // At EOF, if we have an appropriate end tag, emit it
      if self.is_appropriate_end_tag() {
        self.state = Data
        let token = self.emit_current_tag()
        self.pending_tokens.push(EOF)
        Some(token)
      } else {
        self.emit_temp_buffer_as_chars('<', '/')
        self.state = RCDATA
        None
      }
    _ => {
      self.reconsume()
      self.emit_temp_buffer_as_chars('<', '/')
      self.state = RCDATA
      None
    }
  }
}

///|
/// 13.2.5.12 RAWTEXT less-than sign state
fn Tokenizer::run_rawtext_less_than_sign_state(self : Tokenizer) -> Token? {
  match self.peek() {
    Some('/') => {
      let _ = self.consume()
      self.temp_buffer.reset()
      self.state = RAWTEXTEndTagOpen
      None
    }
    _ => {
      self.state = RAWTEXT
      Some(Character('<'))
    }
  }
}

///|
/// 13.2.5.13 RAWTEXT end tag open state
fn Tokenizer::run_rawtext_end_tag_open_state(self : Tokenizer) -> Token? {
  match self.peek() {
    Some(c) if is_ascii_alpha(c) => {
      self.reset_tag(true)
      self.state = RAWTEXTEndTagName
      None
    }
    _ => {
      self.state = RAWTEXT
      self.pending_tokens.push(Character('/'))
      Some(Character('<'))
    }
  }
}

///|
/// 13.2.5.14 RAWTEXT end tag name state
fn Tokenizer::run_rawtext_end_tag_name_state(self : Tokenizer) -> Token? {
  match self.consume() {
    Some(c) if is_whitespace(c) =>
      if self.is_appropriate_end_tag() {
        self.state = BeforeAttributeName
        None
      } else {
        self.emit_temp_buffer_as_chars('<', '/')
        self.pending_tokens.push(Character(c))
        self.state = RAWTEXT
        None
      }
    Some('/') =>
      if self.is_appropriate_end_tag() {
        self.state = SelfClosingStartTag
        None
      } else {
        self.emit_temp_buffer_as_chars('<', '/')
        self.pending_tokens.push(Character('/'))
        self.state = RAWTEXT
        None
      }
    Some('>') =>
      if self.is_appropriate_end_tag() {
        self.state = Data
        Some(self.emit_current_tag())
      } else {
        self.emit_temp_buffer_as_chars('<', '/')
        self.pending_tokens.push(Character('>'))
        self.state = RAWTEXT
        None
      }
    Some(c) if is_ascii_upper_alpha(c) => {
      self.current_tag_name.write_char(to_ascii_lower(c))
      self.temp_buffer.write_char(c)
      None
    }
    Some(c) if is_ascii_lower_alpha(c) => {
      self.current_tag_name.write_char(c)
      self.temp_buffer.write_char(c)
      None
    }
    None =>
      // At EOF, if we have an appropriate end tag, emit it
      if self.is_appropriate_end_tag() {
        self.state = Data
        let token = self.emit_current_tag()
        self.pending_tokens.push(EOF)
        Some(token)
      } else {
        self.emit_temp_buffer_as_chars('<', '/')
        self.state = RAWTEXT
        None
      }
    _ => {
      self.reconsume()
      self.emit_temp_buffer_as_chars('<', '/')
      self.state = RAWTEXT
      None
    }
  }
}

///|
/// Helper: emit temp buffer contents as character tokens with prefix chars
fn Tokenizer::emit_temp_buffer_as_chars(
  self : Tokenizer,
  prefix1 : Char,
  prefix2 : Char,
) -> Unit {
  self.pending_tokens.push(Character(prefix1))
  self.pending_tokens.push(Character(prefix2))
  let buf = self.temp_buffer.to_string()
  for c in buf {
    self.pending_tokens.push(Character(c))
  }
}

///|
/// 13.2.5.40 Self-closing start tag state
fn Tokenizer::run_self_closing_start_tag_state(self : Tokenizer) -> Token? {
  match self.consume() {
    Some('>') => {
      self.current_tag_self_closing = true
      self.state = Data
      Some(self.emit_current_tag())
    }
    Some(_) => {
      self.emit_error(UnexpectedSolidusInTag)
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
