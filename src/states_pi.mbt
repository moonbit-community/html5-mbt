// Copyright 2026 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
fn Tokenizer::emit_current_processing_instruction(self : Tokenizer) -> Token {
  ProcessingInstruction(
    target=self.current_pi_target.to_string(),
    data=self.current_pi_data.to_string(),
  )
}

///|
fn Tokenizer::convert_pi_target_to_comment(self : Tokenizer) -> Unit {
  self.reset_comment()
  self.current_comment.write_char('?')
  self.current_comment.write_string(self.temp_buffer.to_string())
}

///|
/// 13.2.5.72 Processing instruction open state
fn Tokenizer::run_processing_instruction_open_state(self : Tokenizer) -> Token? {
  match self.consume() {
    Some(c) if is_ascii_alpha(c) || c == '_' => {
      self.reconsume()
      self.state = ProcessingInstructionTarget
      None
    }
    None => {
      self.emit_error(EofInProcessingInstruction)
      Some(EOF)
    }
    Some(_) => {
      self.emit_error(InvalidFirstCharacterOfProcessingInstructionTarget)
      self.convert_pi_target_to_comment()
      self.reconsume()
      self.state = BogusComment
      None
    }
  }
}

///|
/// 13.2.5.73 Processing instruction target state
fn Tokenizer::run_processing_instruction_target_state(
  self : Tokenizer,
) -> Token? {
  match self.consume() {
    Some(c) if is_whitespace(c) || c == '?' || c == '>' => {
      let target = self.temp_buffer.to_string()
      let target_lower = target.to_lower()
      if target_lower == "xml" || target_lower == "xml-stylesheet" {
        self.emit_error(DisallowedProcessingInstructionTarget)
        self.convert_pi_target_to_comment()
        self.reconsume()
        self.state = BogusComment
      } else {
        self.current_pi_target.reset()
        self.current_pi_target.write_string(target)
        self.current_pi_data.reset()
        self.reconsume()
        self.state = AfterProcessingInstructionTarget
      }
      None
    }
    Some(c) if is_ascii_alphanumeric(c) || c == '-' || c == '_' => {
      self.temp_buffer.write_char(c)
      None
    }
    None => {
      self.emit_error(EofInProcessingInstruction)
      Some(EOF)
    }
    Some(_) => {
      self.emit_error(InvalidProcessingInstructionTarget)
      self.convert_pi_target_to_comment()
      self.reconsume()
      self.state = BogusComment
      None
    }
  }
}

///|
/// 13.2.5.74 After processing instruction target state
fn Tokenizer::run_after_processing_instruction_target_state(
  self : Tokenizer,
) -> Token? {
  match self.consume() {
    Some(c) if is_whitespace(c) => None
    Some(_) => {
      self.reconsume()
      self.state = ProcessingInstructionData
      None
    }
    None => {
      self.emit_error(EofInProcessingInstruction)
      Some(EOF)
    }
  }
}

///|
/// 13.2.5.75 Processing instruction data state
fn Tokenizer::run_processing_instruction_data_state(self : Tokenizer) -> Token? {
  match self.consume() {
    Some('?') => {
      self.state = ProcessingInstructionQuestionable
      None
    }
    Some('>') => {
      self.state = Data
      Some(self.emit_current_processing_instruction())
    }
    None => {
      self.emit_error(EofInProcessingInstruction)
      Some(EOF)
    }
    Some(c) => {
      self.current_pi_data.write_char(c)
      None
    }
  }
}

///|
/// 13.2.5.76 Processing instruction questionable state
fn Tokenizer::run_processing_instruction_questionable_state(
  self : Tokenizer,
) -> Token? {
  match self.consume() {
    Some('>') => {
      self.state = Data
      Some(self.emit_current_processing_instruction())
    }
    None => {
      self.emit_error(EofInProcessingInstruction)
      Some(EOF)
    }
    Some(_) => {
      self.current_pi_data.write_char('?')
      self.reconsume()
      self.state = ProcessingInstructionData
      None
    }
  }
}
