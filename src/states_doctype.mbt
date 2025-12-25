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
/// 13.2.5.53 DOCTYPE state
fn Tokenizer::run_doctype_state(self : Tokenizer) -> Token? {
  match self.consume() {
    Some(c) if is_whitespace(c) => {
      self.state = BeforeDOCTYPEName
      None
    }
    Some('>') => {
      self.reconsume()
      self.state = BeforeDOCTYPEName
      None
    }
    Some(_) => {
      self.emit_error(MissingWhitespaceBeforeDoctypeName)
      self.reconsume()
      self.state = BeforeDOCTYPEName
      None
    }
    None => {
      self.emit_error(EofInDoctype)
      self.reset_doctype()
      self.current_doctype_force_quirks = true
      let token = self.emit_current_doctype()
      self.pending_tokens.push(EOF)
      Some(token)
    }
  }
}

///|
/// 13.2.5.54 Before DOCTYPE name state
fn Tokenizer::run_before_doctype_name_state(self : Tokenizer) -> Token? {
  match self.consume() {
    Some(c) if is_whitespace(c) => None // Ignore whitespace
    Some(c) if is_ascii_upper_alpha(c) => {
      self.reset_doctype()
      self.current_doctype_name.write_char(to_ascii_lower(c))
      self.state = DOCTYPEName
      None
    }
    Some('\u{0000}') => {
      self.emit_error(UnexpectedNullCharacter)
      self.reset_doctype()
      self.current_doctype_name.write_char('\u{FFFD}')
      self.state = DOCTYPEName
      None
    }
    Some('>') => {
      self.emit_error(MissingDoctypeName)
      self.reset_doctype()
      self.current_doctype_force_quirks = true
      self.state = Data
      Some(self.emit_current_doctype())
    }
    Some(c) => {
      self.reset_doctype()
      self.current_doctype_name.write_char(c)
      self.state = DOCTYPEName
      None
    }
    None => {
      self.emit_error(EofInDoctype)
      self.reset_doctype()
      self.current_doctype_force_quirks = true
      let token = self.emit_current_doctype()
      self.pending_tokens.push(EOF)
      Some(token)
    }
  }
}

///|
/// 13.2.5.55 DOCTYPE name state
fn Tokenizer::run_doctype_name_state(self : Tokenizer) -> Token? {
  match self.consume() {
    Some(c) if is_whitespace(c) => {
      self.state = AfterDOCTYPEName
      None
    }
    Some('>') => {
      self.state = Data
      Some(self.emit_current_doctype())
    }
    Some(c) if is_ascii_upper_alpha(c) => {
      self.current_doctype_name.write_char(to_ascii_lower(c))
      None
    }
    Some('\u{0000}') => {
      self.emit_error(UnexpectedNullCharacter)
      self.current_doctype_name.write_char('\u{FFFD}')
      None
    }
    Some(c) => {
      self.current_doctype_name.write_char(c)
      None
    }
    None => {
      self.emit_error(EofInDoctype)
      self.current_doctype_force_quirks = true
      let token = self.emit_current_doctype()
      self.pending_tokens.push(EOF)
      Some(token)
    }
  }
}

///|
/// 13.2.5.56 After DOCTYPE name state
fn Tokenizer::run_after_doctype_name_state(self : Tokenizer) -> Token? {
  match self.consume() {
    Some(c) if is_whitespace(c) => None // Ignore whitespace
    Some('>') => {
      self.state = Data
      Some(self.emit_current_doctype())
    }
    Some(_) => {
      // Check for PUBLIC or SYSTEM
      self.reconsume()
      if self.check_ascii_insensitive("PUBLIC") {
        for _ in 0..<6 {
          let _ = self.consume()

        }
        self.state = AfterDOCTYPEPublicKeyword
        None
      } else if self.check_ascii_insensitive("SYSTEM") {
        for _ in 0..<6 {
          let _ = self.consume()

        }
        self.state = AfterDOCTYPESystemKeyword
        None
      } else {
        let _ = self.consume()
        self.emit_error(InvalidCharacterSequenceAfterDoctypeName)
        self.current_doctype_force_quirks = true
        self.state = BogusDOCTYPE
        None
      }
    }
    None => {
      self.emit_error(EofInDoctype)
      self.current_doctype_force_quirks = true
      let token = self.emit_current_doctype()
      self.pending_tokens.push(EOF)
      Some(token)
    }
  }
}

///|
/// 13.2.5.57 After DOCTYPE public keyword state
fn Tokenizer::run_after_doctype_public_keyword_state(
  self : Tokenizer,
) -> Token? {
  match self.consume() {
    Some(c) if is_whitespace(c) => {
      self.state = BeforeDOCTYPEPublicIdentifier
      None
    }
    Some('"') => {
      self.emit_error(MissingWhitespaceAfterDoctypePublicKeyword)
      self.current_doctype_public_id.reset()
      self.current_doctype_public_id_set = true
      self.state = DOCTYPEPublicIdentifierDoubleQuoted
      None
    }
    Some('\'') => {
      self.emit_error(MissingWhitespaceAfterDoctypePublicKeyword)
      self.current_doctype_public_id.reset()
      self.current_doctype_public_id_set = true
      self.state = DOCTYPEPublicIdentifierSingleQuoted
      None
    }
    Some('>') => {
      self.emit_error(MissingDoctypePublicIdentifier)
      self.current_doctype_force_quirks = true
      self.state = Data
      Some(self.emit_current_doctype())
    }
    Some(_) => {
      self.emit_error(MissingQuoteBeforeDoctypePublicIdentifier)
      self.current_doctype_force_quirks = true
      self.reconsume()
      self.state = BogusDOCTYPE
      None
    }
    None => {
      self.emit_error(EofInDoctype)
      self.current_doctype_force_quirks = true
      let token = self.emit_current_doctype()
      self.pending_tokens.push(EOF)
      Some(token)
    }
  }
}

///|
/// 13.2.5.58 Before DOCTYPE public identifier state
fn Tokenizer::run_before_doctype_public_identifier_state(
  self : Tokenizer,
) -> Token? {
  match self.consume() {
    Some(c) if is_whitespace(c) => None // Ignore whitespace
    Some('"') => {
      self.current_doctype_public_id.reset()
      self.current_doctype_public_id_set = true
      self.state = DOCTYPEPublicIdentifierDoubleQuoted
      None
    }
    Some('\'') => {
      self.current_doctype_public_id.reset()
      self.current_doctype_public_id_set = true
      self.state = DOCTYPEPublicIdentifierSingleQuoted
      None
    }
    Some('>') => {
      self.emit_error(MissingDoctypePublicIdentifier)
      self.current_doctype_force_quirks = true
      self.state = Data
      Some(self.emit_current_doctype())
    }
    Some(_) => {
      self.emit_error(MissingQuoteBeforeDoctypePublicIdentifier)
      self.current_doctype_force_quirks = true
      self.reconsume()
      self.state = BogusDOCTYPE
      None
    }
    None => {
      self.emit_error(EofInDoctype)
      self.current_doctype_force_quirks = true
      let token = self.emit_current_doctype()
      self.pending_tokens.push(EOF)
      Some(token)
    }
  }
}

///|
/// 13.2.5.59 DOCTYPE public identifier (double-quoted) state
fn Tokenizer::run_doctype_public_identifier_double_quoted_state(
  self : Tokenizer,
) -> Token? {
  match self.consume() {
    Some('"') => {
      self.state = AfterDOCTYPEPublicIdentifier
      None
    }
    Some('\u{0000}') => {
      self.emit_error(UnexpectedNullCharacter)
      self.current_doctype_public_id.write_char('\u{FFFD}')
      None
    }
    Some('>') => {
      self.emit_error(AbruptDoctypePublicIdentifier)
      self.current_doctype_force_quirks = true
      self.state = Data
      Some(self.emit_current_doctype())
    }
    Some(c) => {
      self.current_doctype_public_id.write_char(c)
      None
    }
    None => {
      self.emit_error(EofInDoctype)
      self.current_doctype_force_quirks = true
      let token = self.emit_current_doctype()
      self.pending_tokens.push(EOF)
      Some(token)
    }
  }
}

///|
/// 13.2.5.60 DOCTYPE public identifier (single-quoted) state
fn Tokenizer::run_doctype_public_identifier_single_quoted_state(
  self : Tokenizer,
) -> Token? {
  match self.consume() {
    Some('\'') => {
      self.state = AfterDOCTYPEPublicIdentifier
      None
    }
    Some('\u{0000}') => {
      self.emit_error(UnexpectedNullCharacter)
      self.current_doctype_public_id.write_char('\u{FFFD}')
      None
    }
    Some('>') => {
      self.emit_error(AbruptDoctypePublicIdentifier)
      self.current_doctype_force_quirks = true
      self.state = Data
      Some(self.emit_current_doctype())
    }
    Some(c) => {
      self.current_doctype_public_id.write_char(c)
      None
    }
    None => {
      self.emit_error(EofInDoctype)
      self.current_doctype_force_quirks = true
      let token = self.emit_current_doctype()
      self.pending_tokens.push(EOF)
      Some(token)
    }
  }
}

///|
/// 13.2.5.61 After DOCTYPE public identifier state
fn Tokenizer::run_after_doctype_public_identifier_state(
  self : Tokenizer,
) -> Token? {
  match self.consume() {
    Some(c) if is_whitespace(c) => {
      self.state = BetweenDOCTYPEPublicAndSystemIdentifiers
      None
    }
    Some('>') => {
      self.state = Data
      Some(self.emit_current_doctype())
    }
    Some('"') => {
      self.emit_error(MissingWhitespaceBetweenDoctypePublicAndSystemIdentifiers)
      self.current_doctype_system_id.reset()
      self.current_doctype_system_id_set = true
      self.state = DOCTYPESystemIdentifierDoubleQuoted
      None
    }
    Some('\'') => {
      self.emit_error(MissingWhitespaceBetweenDoctypePublicAndSystemIdentifiers)
      self.current_doctype_system_id.reset()
      self.current_doctype_system_id_set = true
      self.state = DOCTYPESystemIdentifierSingleQuoted
      None
    }
    Some(_) => {
      self.emit_error(MissingQuoteBeforeDoctypeSystemIdentifier)
      self.current_doctype_force_quirks = true
      self.reconsume()
      self.state = BogusDOCTYPE
      None
    }
    None => {
      self.emit_error(EofInDoctype)
      self.current_doctype_force_quirks = true
      let token = self.emit_current_doctype()
      self.pending_tokens.push(EOF)
      Some(token)
    }
  }
}

///|
/// 13.2.5.62 Between DOCTYPE public and system identifiers state
fn Tokenizer::run_between_doctype_public_and_system_identifiers_state(
  self : Tokenizer,
) -> Token? {
  match self.consume() {
    Some(c) if is_whitespace(c) => None // Ignore whitespace
    Some('>') => {
      self.state = Data
      Some(self.emit_current_doctype())
    }
    Some('"') => {
      self.current_doctype_system_id.reset()
      self.current_doctype_system_id_set = true
      self.state = DOCTYPESystemIdentifierDoubleQuoted
      None
    }
    Some('\'') => {
      self.current_doctype_system_id.reset()
      self.current_doctype_system_id_set = true
      self.state = DOCTYPESystemIdentifierSingleQuoted
      None
    }
    Some(_) => {
      self.emit_error(MissingQuoteBeforeDoctypeSystemIdentifier)
      self.current_doctype_force_quirks = true
      self.reconsume()
      self.state = BogusDOCTYPE
      None
    }
    None => {
      self.emit_error(EofInDoctype)
      self.current_doctype_force_quirks = true
      let token = self.emit_current_doctype()
      self.pending_tokens.push(EOF)
      Some(token)
    }
  }
}

///|
/// 13.2.5.63 After DOCTYPE system keyword state
fn Tokenizer::run_after_doctype_system_keyword_state(
  self : Tokenizer,
) -> Token? {
  match self.consume() {
    Some(c) if is_whitespace(c) => {
      self.state = BeforeDOCTYPESystemIdentifier
      None
    }
    Some('"') => {
      self.emit_error(MissingWhitespaceAfterDoctypeSystemKeyword)
      self.current_doctype_system_id.reset()
      self.current_doctype_system_id_set = true
      self.state = DOCTYPESystemIdentifierDoubleQuoted
      None
    }
    Some('\'') => {
      self.emit_error(MissingWhitespaceAfterDoctypeSystemKeyword)
      self.current_doctype_system_id.reset()
      self.current_doctype_system_id_set = true
      self.state = DOCTYPESystemIdentifierSingleQuoted
      None
    }
    Some('>') => {
      self.emit_error(MissingDoctypeSystemIdentifier)
      self.current_doctype_force_quirks = true
      self.state = Data
      Some(self.emit_current_doctype())
    }
    Some(_) => {
      self.emit_error(MissingQuoteBeforeDoctypeSystemIdentifier)
      self.current_doctype_force_quirks = true
      self.reconsume()
      self.state = BogusDOCTYPE
      None
    }
    None => {
      self.emit_error(EofInDoctype)
      self.current_doctype_force_quirks = true
      let token = self.emit_current_doctype()
      self.pending_tokens.push(EOF)
      Some(token)
    }
  }
}

///|
/// 13.2.5.64 Before DOCTYPE system identifier state
fn Tokenizer::run_before_doctype_system_identifier_state(
  self : Tokenizer,
) -> Token? {
  match self.consume() {
    Some(c) if is_whitespace(c) => None // Ignore whitespace
    Some('"') => {
      self.current_doctype_system_id.reset()
      self.current_doctype_system_id_set = true
      self.state = DOCTYPESystemIdentifierDoubleQuoted
      None
    }
    Some('\'') => {
      self.current_doctype_system_id.reset()
      self.current_doctype_system_id_set = true
      self.state = DOCTYPESystemIdentifierSingleQuoted
      None
    }
    Some('>') => {
      self.emit_error(MissingDoctypeSystemIdentifier)
      self.current_doctype_force_quirks = true
      self.state = Data
      Some(self.emit_current_doctype())
    }
    Some(_) => {
      self.emit_error(MissingQuoteBeforeDoctypeSystemIdentifier)
      self.current_doctype_force_quirks = true
      self.reconsume()
      self.state = BogusDOCTYPE
      None
    }
    None => {
      self.emit_error(EofInDoctype)
      self.current_doctype_force_quirks = true
      let token = self.emit_current_doctype()
      self.pending_tokens.push(EOF)
      Some(token)
    }
  }
}

///|
/// 13.2.5.65 DOCTYPE system identifier (double-quoted) state
fn Tokenizer::run_doctype_system_identifier_double_quoted_state(
  self : Tokenizer,
) -> Token? {
  match self.consume() {
    Some('"') => {
      self.state = AfterDOCTYPESystemIdentifier
      None
    }
    Some('\u{0000}') => {
      self.emit_error(UnexpectedNullCharacter)
      self.current_doctype_system_id.write_char('\u{FFFD}')
      None
    }
    Some('>') => {
      self.emit_error(AbruptDoctypeSystemIdentifier)
      self.current_doctype_force_quirks = true
      self.state = Data
      Some(self.emit_current_doctype())
    }
    Some(c) => {
      self.current_doctype_system_id.write_char(c)
      None
    }
    None => {
      self.emit_error(EofInDoctype)
      self.current_doctype_force_quirks = true
      let token = self.emit_current_doctype()
      self.pending_tokens.push(EOF)
      Some(token)
    }
  }
}

///|
/// 13.2.5.66 DOCTYPE system identifier (single-quoted) state
fn Tokenizer::run_doctype_system_identifier_single_quoted_state(
  self : Tokenizer,
) -> Token? {
  match self.consume() {
    Some('\'') => {
      self.state = AfterDOCTYPESystemIdentifier
      None
    }
    Some('\u{0000}') => {
      self.emit_error(UnexpectedNullCharacter)
      self.current_doctype_system_id.write_char('\u{FFFD}')
      None
    }
    Some('>') => {
      self.emit_error(AbruptDoctypeSystemIdentifier)
      self.current_doctype_force_quirks = true
      self.state = Data
      Some(self.emit_current_doctype())
    }
    Some(c) => {
      self.current_doctype_system_id.write_char(c)
      None
    }
    None => {
      self.emit_error(EofInDoctype)
      self.current_doctype_force_quirks = true
      let token = self.emit_current_doctype()
      self.pending_tokens.push(EOF)
      Some(token)
    }
  }
}

///|
/// 13.2.5.67 After DOCTYPE system identifier state
fn Tokenizer::run_after_doctype_system_identifier_state(
  self : Tokenizer,
) -> Token? {
  match self.consume() {
    Some(c) if is_whitespace(c) => None // Ignore whitespace
    Some('>') => {
      self.state = Data
      Some(self.emit_current_doctype())
    }
    Some(_) => {
      self.emit_error(UnexpectedCharacterAfterDoctypeSystemIdentifier)
      self.reconsume()
      self.state = BogusDOCTYPE
      None
    }
    None => {
      self.emit_error(EofInDoctype)
      self.current_doctype_force_quirks = true
      let token = self.emit_current_doctype()
      self.pending_tokens.push(EOF)
      Some(token)
    }
  }
}

///|
/// 13.2.5.68 Bogus DOCTYPE state
fn Tokenizer::run_bogus_doctype_state(self : Tokenizer) -> Token? {
  match self.consume() {
    Some('>') => {
      self.state = Data
      Some(self.emit_current_doctype())
    }
    Some('\u{0000}') => {
      self.emit_error(UnexpectedNullCharacter)
      None
    }
    Some(_) => None
    None => {
      let token = self.emit_current_doctype()
      self.pending_tokens.push(EOF)
      Some(token)
    }
  }
}
