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
/// 13.2.5.15 Script data less-than sign state
fn Tokenizer::run_script_data_less_than_sign_state(self : Tokenizer) -> Token? {
  match self.consume() {
    Some('/') => {
      self.temp_buffer.reset()
      self.state = ScriptDataEndTagOpen
      None
    }
    Some('!') => {
      self.state = ScriptDataEscapeStart
      self.pending_tokens.push(Character('!'))
      Some(Character('<'))
    }
    Some(_) => {
      self.reconsume()
      self.state = ScriptData
      Some(Character('<'))
    }
    None => {
      self.state = ScriptData
      Some(Character('<'))
    }
  }
}

///|
/// 13.2.5.16 Script data end tag open state
fn Tokenizer::run_script_data_end_tag_open_state(self : Tokenizer) -> Token? {
  match self.peek() {
    Some(c) if is_ascii_alpha(c) => {
      self.reset_tag(true)
      self.state = ScriptDataEndTagName
      None
    }
    _ => {
      self.state = ScriptData
      self.pending_tokens.push(Character('/'))
      Some(Character('<'))
    }
  }
}

///|
/// 13.2.5.17 Script data end tag name state
fn Tokenizer::run_script_data_end_tag_name_state(self : Tokenizer) -> Token? {
  match self.consume() {
    Some(c) if is_whitespace(c) =>
      if self.is_appropriate_end_tag() {
        self.state = BeforeAttributeName
        None
      } else {
        self.emit_temp_buffer_as_chars('<', '/')
        self.state = ScriptData
        None
      }
    Some('/') =>
      if self.is_appropriate_end_tag() {
        self.state = SelfClosingStartTag
        None
      } else {
        self.emit_temp_buffer_as_chars('<', '/')
        self.state = ScriptData
        None
      }
    Some('>') =>
      if self.is_appropriate_end_tag() {
        self.state = Data
        Some(self.emit_current_tag())
      } else {
        self.emit_temp_buffer_as_chars('<', '/')
        self.state = ScriptData
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
    _ => {
      self.reconsume()
      self.emit_temp_buffer_as_chars('<', '/')
      self.state = ScriptData
      None
    }
  }
}

///|
/// 13.2.5.18 Script data escape start state
fn Tokenizer::run_script_data_escape_start_state(self : Tokenizer) -> Token? {
  match self.consume() {
    Some('-') => {
      self.state = ScriptDataEscapeStartDash
      Some(Character('-'))
    }
    Some(_) => {
      self.reconsume()
      self.state = ScriptData
      None
    }
    None => {
      self.state = ScriptData
      None
    }
  }
}

///|
/// 13.2.5.19 Script data escape start dash state
fn Tokenizer::run_script_data_escape_start_dash_state(
  self : Tokenizer,
) -> Token? {
  match self.consume() {
    Some('-') => {
      self.state = ScriptDataEscapedDashDash
      Some(Character('-'))
    }
    Some(_) => {
      self.reconsume()
      self.state = ScriptData
      None
    }
    None => {
      self.state = ScriptData
      None
    }
  }
}

///|
/// 13.2.5.20 Script data escaped state
fn Tokenizer::run_script_data_escaped_state(self : Tokenizer) -> Token? {
  match self.consume() {
    Some('-') => {
      self.state = ScriptDataEscapedDash
      Some(Character('-'))
    }
    Some('<') => {
      self.state = ScriptDataEscapedLessThanSign
      None
    }
    Some('\u{0000}') => {
      self.emit_error(UnexpectedNullCharacter)
      Some(Character('\u{FFFD}'))
    }
    Some(c) => Some(Character(c))
    None => {
      self.emit_error(EofInScriptHtmlCommentLikeText)
      Some(EOF)
    }
  }
}

///|
/// 13.2.5.21 Script data escaped dash state
fn Tokenizer::run_script_data_escaped_dash_state(self : Tokenizer) -> Token? {
  match self.consume() {
    Some('-') => {
      self.state = ScriptDataEscapedDashDash
      Some(Character('-'))
    }
    Some('<') => {
      self.state = ScriptDataEscapedLessThanSign
      None
    }
    Some('\u{0000}') => {
      self.emit_error(UnexpectedNullCharacter)
      self.state = ScriptDataEscaped
      Some(Character('\u{FFFD}'))
    }
    Some(c) => {
      self.state = ScriptDataEscaped
      Some(Character(c))
    }
    None => {
      self.emit_error(EofInScriptHtmlCommentLikeText)
      Some(EOF)
    }
  }
}

///|
/// 13.2.5.22 Script data escaped dash dash state
fn Tokenizer::run_script_data_escaped_dash_dash_state(
  self : Tokenizer,
) -> Token? {
  match self.consume() {
    Some('-') => Some(Character('-'))
    Some('<') => {
      self.state = ScriptDataEscapedLessThanSign
      None
    }
    Some('>') => {
      self.state = ScriptData
      Some(Character('>'))
    }
    Some('\u{0000}') => {
      self.emit_error(UnexpectedNullCharacter)
      self.state = ScriptDataEscaped
      Some(Character('\u{FFFD}'))
    }
    Some(c) => {
      self.state = ScriptDataEscaped
      Some(Character(c))
    }
    None => {
      self.emit_error(EofInScriptHtmlCommentLikeText)
      Some(EOF)
    }
  }
}

///|
/// 13.2.5.23 Script data escaped less-than sign state
fn Tokenizer::run_script_data_escaped_less_than_sign_state(
  self : Tokenizer,
) -> Token? {
  match self.peek() {
    Some('/') => {
      let _ = self.consume()
      self.temp_buffer.reset()
      self.state = ScriptDataEscapedEndTagOpen
      None
    }
    Some(c) if is_ascii_alpha(c) => {
      self.temp_buffer.reset()
      self.state = ScriptDataDoubleEscapeStart
      Some(Character('<'))
    }
    _ => {
      self.state = ScriptDataEscaped
      Some(Character('<'))
    }
  }
}

///|
/// 13.2.5.24 Script data escaped end tag open state
fn Tokenizer::run_script_data_escaped_end_tag_open_state(
  self : Tokenizer,
) -> Token? {
  match self.peek() {
    Some(c) if is_ascii_alpha(c) => {
      self.reset_tag(true)
      self.state = ScriptDataEscapedEndTagName
      None
    }
    _ => {
      self.state = ScriptDataEscaped
      self.pending_tokens.push(Character('/'))
      Some(Character('<'))
    }
  }
}

///|
/// 13.2.5.25 Script data escaped end tag name state
fn Tokenizer::run_script_data_escaped_end_tag_name_state(
  self : Tokenizer,
) -> Token? {
  match self.consume() {
    Some(c) if is_whitespace(c) =>
      if self.is_appropriate_end_tag() {
        self.state = BeforeAttributeName
        None
      } else {
        self.emit_temp_buffer_as_chars('<', '/')
        self.state = ScriptDataEscaped
        None
      }
    Some('/') =>
      if self.is_appropriate_end_tag() {
        self.state = SelfClosingStartTag
        None
      } else {
        self.emit_temp_buffer_as_chars('<', '/')
        self.state = ScriptDataEscaped
        None
      }
    Some('>') =>
      if self.is_appropriate_end_tag() {
        self.state = Data
        Some(self.emit_current_tag())
      } else {
        self.emit_temp_buffer_as_chars('<', '/')
        self.state = ScriptDataEscaped
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
    _ => {
      self.reconsume()
      self.emit_temp_buffer_as_chars('<', '/')
      self.state = ScriptDataEscaped
      None
    }
  }
}

///|
/// 13.2.5.26 Script data double escape start state
fn Tokenizer::run_script_data_double_escape_start_state(
  self : Tokenizer,
) -> Token? {
  match self.consume() {
    Some(c) if is_whitespace(c) || c == '/' || c == '>' => {
      if self.temp_buffer.to_string() == "script" {
        self.state = ScriptDataDoubleEscaped
      } else {
        self.state = ScriptDataEscaped
      }
      Some(Character(c))
    }
    Some(c) if is_ascii_upper_alpha(c) => {
      self.temp_buffer.write_char(to_ascii_lower(c))
      Some(Character(c))
    }
    Some(c) if is_ascii_lower_alpha(c) => {
      self.temp_buffer.write_char(c)
      Some(Character(c))
    }
    Some(_) => {
      self.reconsume()
      self.state = ScriptDataEscaped
      None
    }
    None => {
      self.state = ScriptDataEscaped
      None
    }
  }
}

///|
/// 13.2.5.27 Script data double escaped state
fn Tokenizer::run_script_data_double_escaped_state(self : Tokenizer) -> Token? {
  match self.consume() {
    Some('-') => {
      self.state = ScriptDataDoubleEscapedDash
      Some(Character('-'))
    }
    Some('<') => {
      self.state = ScriptDataDoubleEscapedLessThanSign
      Some(Character('<'))
    }
    Some('\u{0000}') => {
      self.emit_error(UnexpectedNullCharacter)
      Some(Character('\u{FFFD}'))
    }
    Some(c) => Some(Character(c))
    None => {
      self.emit_error(EofInScriptHtmlCommentLikeText)
      Some(EOF)
    }
  }
}

///|
/// 13.2.5.28 Script data double escaped dash state
fn Tokenizer::run_script_data_double_escaped_dash_state(
  self : Tokenizer,
) -> Token? {
  match self.consume() {
    Some('-') => {
      self.state = ScriptDataDoubleEscapedDashDash
      Some(Character('-'))
    }
    Some('<') => {
      self.state = ScriptDataDoubleEscapedLessThanSign
      Some(Character('<'))
    }
    Some('\u{0000}') => {
      self.emit_error(UnexpectedNullCharacter)
      self.state = ScriptDataDoubleEscaped
      Some(Character('\u{FFFD}'))
    }
    Some(c) => {
      self.state = ScriptDataDoubleEscaped
      Some(Character(c))
    }
    None => {
      self.emit_error(EofInScriptHtmlCommentLikeText)
      Some(EOF)
    }
  }
}

///|
/// 13.2.5.29 Script data double escaped dash dash state
fn Tokenizer::run_script_data_double_escaped_dash_dash_state(
  self : Tokenizer,
) -> Token? {
  match self.consume() {
    Some('-') => Some(Character('-'))
    Some('<') => {
      self.state = ScriptDataDoubleEscapedLessThanSign
      Some(Character('<'))
    }
    Some('>') => {
      self.state = ScriptData
      Some(Character('>'))
    }
    Some('\u{0000}') => {
      self.emit_error(UnexpectedNullCharacter)
      self.state = ScriptDataDoubleEscaped
      Some(Character('\u{FFFD}'))
    }
    Some(c) => {
      self.state = ScriptDataDoubleEscaped
      Some(Character(c))
    }
    None => {
      self.emit_error(EofInScriptHtmlCommentLikeText)
      Some(EOF)
    }
  }
}

///|
/// 13.2.5.30 Script data double escaped less-than sign state
fn Tokenizer::run_script_data_double_escaped_less_than_sign_state(
  self : Tokenizer,
) -> Token? {
  match self.consume() {
    Some('/') => {
      self.temp_buffer.reset()
      self.state = ScriptDataDoubleEscapeEnd
      Some(Character('/'))
    }
    Some(_) => {
      self.reconsume()
      self.state = ScriptDataDoubleEscaped
      None
    }
    None => {
      self.state = ScriptDataDoubleEscaped
      None
    }
  }
}

///|
/// 13.2.5.31 Script data double escape end state
fn Tokenizer::run_script_data_double_escape_end_state(
  self : Tokenizer,
) -> Token? {
  match self.consume() {
    Some(c) if is_whitespace(c) || c == '/' || c == '>' => {
      if self.temp_buffer.to_string() == "script" {
        self.state = ScriptDataEscaped
      } else {
        self.state = ScriptDataDoubleEscaped
      }
      Some(Character(c))
    }
    Some(c) if is_ascii_upper_alpha(c) => {
      self.temp_buffer.write_char(to_ascii_lower(c))
      Some(Character(c))
    }
    Some(c) if is_ascii_lower_alpha(c) => {
      self.temp_buffer.write_char(c)
      Some(Character(c))
    }
    Some(_) => {
      self.reconsume()
      self.state = ScriptDataDoubleEscaped
      None
    }
    None => {
      self.state = ScriptDataDoubleEscaped
      None
    }
  }
}
