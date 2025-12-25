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
/// 13.2.5.41 Bogus comment state
fn Tokenizer::run_bogus_comment_state(self : Tokenizer) -> Token? {
  match self.consume() {
    Some('>') => {
      self.state = Data
      Some(self.emit_current_comment())
    }
    Some('\u{0000}') => {
      self.emit_error(UnexpectedNullCharacter)
      self.current_comment.write_char('\u{FFFD}')
      None
    }
    Some(c) => {
      self.current_comment.write_char(c)
      None
    }
    None => {
      let token = self.emit_current_comment()
      self.pending_tokens.push(EOF)
      Some(token)
    }
  }
}

///|
/// 13.2.5.42 Markup declaration open state
fn Tokenizer::run_markup_declaration_open_state(self : Tokenizer) -> Token? {
  // Check for "--" (comment)
  if self.peek() == Some('-') && self.peek_at(1) == Some('-') {
    let _ = self.consume()
    let _ = self.consume()
    self.reset_comment()
    self.state = CommentStart
    return None
  }
  // Check for "DOCTYPE" (case-insensitive)
  if self.check_ascii_insensitive("DOCTYPE") {
    for _ in 0..<7 {
      let _ = self.consume()

    }
    self.state = DOCTYPE
    return None
  }
  // Check for "[CDATA["
  if self.check_string("[CDATA[") {
    for _ in 0..<7 {
      let _ = self.consume()
    }
    // CDATA is only allowed in foreign content (SVG/MathML)
    if self.in_foreign_content {
      // In foreign content, switch to CDATA section state
      self.state = CDATASection
      return None
    }
    // In HTML content, emit error and treat as bogus comment
    self.emit_error(CdataInHtmlContent)
    self.reset_comment()
    self.current_comment.write_string("[CDATA[")
    self.state = BogusComment
    return None
  }
  // Anything else is incorrectly opened comment
  self.emit_error(IncorrectlyOpenedComment)
  self.reset_comment()
  self.state = BogusComment
  None
}

///|
/// Check if next chars match string (case-insensitive ASCII)
fn Tokenizer::check_ascii_insensitive(self : Tokenizer, s : String) -> Bool {
  let chars = s.to_array()
  for i = 0; i < chars.length(); i = i + 1 {
    match self.peek_at(i) {
      Some(c) => {
        let expected = chars[i]
        let c_lower = to_ascii_lower(c)
        let expected_lower = to_ascii_lower(expected)
        if c_lower != expected_lower {
          return false
        }
      }
      None => return false
    }
  }
  true
}

///|
/// Check if next chars match string exactly
fn Tokenizer::check_string(self : Tokenizer, s : String) -> Bool {
  let chars = s.to_array()
  for i = 0; i < chars.length(); i = i + 1 {
    match self.peek_at(i) {
      Some(c) if c == chars[i] => continue
      _ => return false
    }
  }
  true
}

///|
/// 13.2.5.43 Comment start state
fn Tokenizer::run_comment_start_state(self : Tokenizer) -> Token? {
  match self.consume() {
    Some('-') => {
      self.state = CommentStartDash
      None
    }
    Some('>') => {
      self.emit_error(AbruptClosingOfEmptyComment)
      self.state = Data
      Some(self.emit_current_comment())
    }
    Some(_) => {
      self.reconsume()
      self.state = Comment
      None
    }
    None => {
      self.reconsume()
      self.state = Comment
      None
    }
  }
}

///|
/// 13.2.5.44 Comment start dash state
fn Tokenizer::run_comment_start_dash_state(self : Tokenizer) -> Token? {
  match self.consume() {
    Some('-') => {
      self.state = CommentEnd
      None
    }
    Some('>') => {
      self.emit_error(AbruptClosingOfEmptyComment)
      self.state = Data
      Some(self.emit_current_comment())
    }
    Some(_) => {
      self.current_comment.write_char('-')
      self.reconsume()
      self.state = Comment
      None
    }
    None => {
      self.emit_error(EofInComment)
      let token = self.emit_current_comment()
      self.pending_tokens.push(EOF)
      Some(token)
    }
  }
}

///|
/// 13.2.5.45 Comment state
fn Tokenizer::run_comment_state(self : Tokenizer) -> Token? {
  match self.consume() {
    Some('<') => {
      self.current_comment.write_char('<')
      self.state = CommentLessThanSign
      None
    }
    Some('-') => {
      self.state = CommentEndDash
      None
    }
    Some('\u{0000}') => {
      self.emit_error(UnexpectedNullCharacter)
      self.current_comment.write_char('\u{FFFD}')
      None
    }
    Some(c) => {
      self.current_comment.write_char(c)
      None
    }
    None => {
      self.emit_error(EofInComment)
      let token = self.emit_current_comment()
      self.pending_tokens.push(EOF)
      Some(token)
    }
  }
}

///|
/// 13.2.5.46 Comment less-than sign state
fn Tokenizer::run_comment_less_than_sign_state(self : Tokenizer) -> Token? {
  match self.consume() {
    Some('!') => {
      self.current_comment.write_char('!')
      self.state = CommentLessThanSignBang
      None
    }
    Some('<') => {
      self.current_comment.write_char('<')
      None
    }
    Some(_) => {
      self.reconsume()
      self.state = Comment
      None
    }
    None => {
      self.reconsume()
      self.state = Comment
      None
    }
  }
}

///|
/// 13.2.5.47 Comment less-than sign bang state
fn Tokenizer::run_comment_less_than_sign_bang_state(self : Tokenizer) -> Token? {
  match self.consume() {
    Some('-') => {
      self.state = CommentLessThanSignBangDash
      None
    }
    Some(_) => {
      self.reconsume()
      self.state = Comment
      None
    }
    None => {
      self.reconsume()
      self.state = Comment
      None
    }
  }
}

///|
/// 13.2.5.48 Comment less-than sign bang dash state
fn Tokenizer::run_comment_less_than_sign_bang_dash_state(
  self : Tokenizer,
) -> Token? {
  match self.consume() {
    Some('-') => {
      self.state = CommentLessThanSignBangDashDash
      None
    }
    Some(_) => {
      self.reconsume()
      self.state = CommentEndDash
      None
    }
    None => {
      self.reconsume()
      self.state = CommentEndDash
      None
    }
  }
}

///|
/// 13.2.5.49 Comment less-than sign bang dash dash state
fn Tokenizer::run_comment_less_than_sign_bang_dash_dash_state(
  self : Tokenizer,
) -> Token? {
  match self.peek() {
    Some('>') | None => {
      self.state = CommentEnd
      None
    }
    Some(_) => {
      self.emit_error(NestedComment)
      self.state = CommentEnd
      None
    }
  }
}

///|
/// 13.2.5.50 Comment end dash state
fn Tokenizer::run_comment_end_dash_state(self : Tokenizer) -> Token? {
  match self.consume() {
    Some('-') => {
      self.state = CommentEnd
      None
    }
    Some(_) => {
      self.current_comment.write_char('-')
      self.reconsume()
      self.state = Comment
      None
    }
    None => {
      self.emit_error(EofInComment)
      let token = self.emit_current_comment()
      self.pending_tokens.push(EOF)
      Some(token)
    }
  }
}

///|
/// 13.2.5.51 Comment end state
fn Tokenizer::run_comment_end_state(self : Tokenizer) -> Token? {
  match self.consume() {
    Some('>') => {
      self.state = Data
      Some(self.emit_current_comment())
    }
    Some('!') => {
      self.state = CommentEndBang
      None
    }
    Some('-') => {
      self.current_comment.write_char('-')
      None
    }
    Some(_) => {
      self.current_comment.write_string("--")
      self.reconsume()
      self.state = Comment
      None
    }
    None => {
      self.emit_error(EofInComment)
      let token = self.emit_current_comment()
      self.pending_tokens.push(EOF)
      Some(token)
    }
  }
}

///|
/// 13.2.5.52 Comment end bang state
fn Tokenizer::run_comment_end_bang_state(self : Tokenizer) -> Token? {
  match self.consume() {
    Some('-') => {
      self.current_comment.write_string("--!")
      self.state = CommentEndDash
      None
    }
    Some('>') => {
      self.emit_error(IncorrectlyClosedComment)
      self.state = Data
      Some(self.emit_current_comment())
    }
    Some(_) => {
      self.current_comment.write_string("--!")
      self.reconsume()
      self.state = Comment
      None
    }
    None => {
      self.emit_error(EofInComment)
      let token = self.emit_current_comment()
      self.pending_tokens.push(EOF)
      Some(token)
    }
  }
}
