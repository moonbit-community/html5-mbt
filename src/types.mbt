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
/// HTML5 Token types per WHATWG spec
pub(all) enum Token {
  /// DOCTYPE token: <!DOCTYPE name PUBLIC "public" "system">
  DOCTYPE(
    name~ : String?,
    public_id~ : String?,
    system_id~ : String?,
    force_quirks~ : Bool
  )
  /// Start tag: <tagname attr="value">
  StartTag(name~ : String, attrs~ : Array[Attribute], self_closing~ : Bool)
  /// End tag: </tagname>
  EndTag(name~ : String)
  /// Character token
  Character(Char)
  /// Comment: <!-- text -->
  Comment(String)
  /// End of file marker
  EOF
} derive(Debug, Eq)

///|
/// Document quirks mode (WHATWG 3.1.4)
pub(all) enum QuirksMode {
  NoQuirks
  Quirks
  LimitedQuirks
} derive(Debug, Eq)

///|
/// Attribute in a start/end tag
pub(all) struct Attribute {
  name : String
  value : String
} derive(Debug, Eq)

///|
/// All 80 WHATWG tokenizer states
pub(all) enum State {
  // ===== Data states (5) =====
  Data
  RCDATA
  RAWTEXT
  ScriptData
  PLAINTEXT

  // ===== Tag states (4) =====
  TagOpen
  EndTagOpen
  TagName
  SelfClosingStartTag

  // ===== RCDATA states (3) =====
  RCDATALessThanSign
  RCDATAEndTagOpen
  RCDATAEndTagName

  // ===== RAWTEXT states (3) =====
  RAWTEXTLessThanSign
  RAWTEXTEndTagOpen
  RAWTEXTEndTagName

  // ===== Script data states (13) =====
  ScriptDataLessThanSign
  ScriptDataEndTagOpen
  ScriptDataEndTagName
  ScriptDataEscapeStart
  ScriptDataEscapeStartDash
  ScriptDataEscaped
  ScriptDataEscapedDash
  ScriptDataEscapedDashDash
  ScriptDataEscapedLessThanSign
  ScriptDataEscapedEndTagOpen
  ScriptDataEscapedEndTagName
  ScriptDataDoubleEscapeStart
  ScriptDataDoubleEscaped
  ScriptDataDoubleEscapedDash
  ScriptDataDoubleEscapedDashDash
  ScriptDataDoubleEscapedLessThanSign
  ScriptDataDoubleEscapeEnd

  // ===== Attribute states (8) =====
  BeforeAttributeName
  AttributeName
  AfterAttributeName
  BeforeAttributeValue
  AttributeValueDoubleQuoted
  AttributeValueSingleQuoted
  AttributeValueUnquoted
  AfterAttributeValueQuoted

  // ===== Comment states (11) =====
  BogusComment
  MarkupDeclarationOpen
  CommentStart
  CommentStartDash
  Comment
  CommentLessThanSign
  CommentLessThanSignBang
  CommentLessThanSignBangDash
  CommentLessThanSignBangDashDash
  CommentEndDash
  CommentEnd
  CommentEndBang

  // ===== DOCTYPE states (16) =====
  DOCTYPE
  BeforeDOCTYPEName
  DOCTYPEName
  AfterDOCTYPEName
  AfterDOCTYPEPublicKeyword
  BeforeDOCTYPEPublicIdentifier
  DOCTYPEPublicIdentifierDoubleQuoted
  DOCTYPEPublicIdentifierSingleQuoted
  AfterDOCTYPEPublicIdentifier
  BetweenDOCTYPEPublicAndSystemIdentifiers
  AfterDOCTYPESystemKeyword
  BeforeDOCTYPESystemIdentifier
  DOCTYPESystemIdentifierDoubleQuoted
  DOCTYPESystemIdentifierSingleQuoted
  AfterDOCTYPESystemIdentifier
  BogusDOCTYPE

  // ===== CDATA states (3) =====
  CDATASection
  CDATASectionBracket
  CDATASectionEnd

  // ===== Character reference states (9) =====
  CharacterReference
  NamedCharacterReference
  AmbiguousAmpersand
  NumericCharacterReference
  HexadecimalCharacterReferenceStart
  DecimalCharacterReferenceStart
  HexadecimalCharacterReference
  DecimalCharacterReference
  NumericCharacterReferenceEnd
} derive(Debug, Eq)

///|
/// Source position for error reporting
pub struct SourcePosition {
  line : Int
  column : Int
  offset : Int
} derive(Debug, Eq)

///|
/// WHATWG HTML5 Parse Errors (49 types per specification)
pub(all) enum ParseErrorCode {
  // ===== Comment errors (5) =====
  AbruptClosingOfEmptyComment
  EofInComment
  IncorrectlyClosedComment
  IncorrectlyOpenedComment
  NestedComment

  // ===== DOCTYPE errors (19) =====
  AbruptDoctypePublicIdentifier
  AbruptDoctypeSystemIdentifier
  EofInDoctype
  InvalidCharacterSequenceAfterDoctypeName
  MissingDoctypeName
  MissingDoctypePublicIdentifier
  MissingDoctypeSystemIdentifier
  MissingQuoteBeforeDoctypePublicIdentifier
  MissingQuoteBeforeDoctypeSystemIdentifier
  MissingWhitespaceAfterDoctypePublicKeyword
  MissingWhitespaceAfterDoctypeSystemKeyword
  MissingWhitespaceBeforeDoctypeName
  MissingWhitespaceBetweenDoctypePublicAndSystemIdentifiers
  UnexpectedCharacterAfterDoctypeSystemIdentifier

  // ===== Tag errors (16) =====
  DuplicateAttribute
  EndTagWithAttributes
  EndTagWithTrailingSolidus
  EofBeforeTagName
  EofInTag
  InvalidFirstCharacterOfTagName
  MissingAttributeValue
  MissingEndTagName
  MissingWhitespaceBetweenAttributes
  NonVoidHtmlElementStartTagWithTrailingSolidus
  UnexpectedCharacterInAttributeName
  UnexpectedCharacterInUnquotedAttributeValue
  UnexpectedEqualsSignBeforeAttributeName
  UnexpectedNullCharacter
  UnexpectedQuestionMarkInsteadOfTagName
  UnexpectedSolidusInTag

  // ===== Character reference errors (8) =====
  AbsenceOfDigitsInNumericCharacterReference
  CharacterReferenceOutsideUnicodeRange
  ControlCharacterReference
  MissingSemicolonAfterCharacterReference
  NoncharacterCharacterReference
  NullCharacterReference
  SurrogateCharacterReference
  UnknownNamedCharacterReference

  // ===== Content errors (6) =====
  CdataInHtmlContent
  ControlCharacterInInputStream
  EofInCdata
  EofInScriptHtmlCommentLikeText
  NoncharacterInInputStream
  SurrogateInInputStream
} derive(Debug, Eq)

///|
/// A parse error with location
pub struct ParseError {
  code : ParseErrorCode
  position : SourcePosition
} derive(Debug, Eq)

///|
/// Namespace for HTML, SVG, MathML
pub(all) enum Namespace {
  HTML
  SVG
  MathML
} derive(Debug, Eq)

///|
pub impl Show for Token with fn output(self, logger) {
  fn output_option_string(s : String?) -> Unit {
    match s {
      None => logger.write_string("None")
      Some(arg) => {
        logger.write_string("Some(")
        logger.write_object(arg)
        logger.write_string(")")
      }
    }
  }
  match self {
    DOCTYPE(name~, public_id~, system_id~, force_quirks~) => {
      logger.write_string("DOCTYPE(name=")
      output_option_string(name)
      logger.write_string(", public_id=")
      output_option_string(public_id)
      logger.write_string(", system_id=")
      output_option_string(system_id)
      logger.write_string(", force_quirks=")
      force_quirks.output(logger)
      logger.write_string(")")
    }
    StartTag(name~, attrs~, self_closing~) => {
      logger.write_string("StartTag(name=")
      name.output(logger)
      logger.write_string(", attrs=")
      logger.write_string(@debug.to_string(attrs))
      logger.write_string(", self_closing=")
      self_closing.output(logger)
      logger.write_string(")")
    }
    EndTag(name~) => {
      logger.write_string("EndTag(name=")
      name.output(logger)
      logger.write_string(")")
    }
    Character(c) => {
      logger.write_string("Character(")
      c.output(logger)
      logger.write_string(")")
    }
    Comment(text) => {
      logger.write_string("Comment(")
      text.output(logger)
      logger.write_string(")")
    }
    EOF => logger.write_string("EOF")
  }
}

///|
pub impl Show for QuirksMode with fn output(self, logger) {
  logger.write_string(quirks_mode_name(self))
}

///|
pub impl Show for Attribute with fn output(self, logger) {
  logger.write_string("{name: ")
  self.name.output(logger)
  logger.write_string(", value: ")
  self.value.output(logger)
  logger.write_string("}")
}

///|
pub impl Show for State with fn output(self, logger) {
  logger.write_string(state_name(self))
}

///|
pub impl Show for SourcePosition with fn output(self, logger) {
  logger.write_string("{line: ")
  self.line.output(logger)
  logger.write_string(", column: ")
  self.column.output(logger)
  logger.write_string(", offset: ")
  self.offset.output(logger)
  logger.write_string("}")
}

///|
pub impl Show for ParseErrorCode with fn output(self, logger) {
  logger.write_string(parse_error_code_name(self))
}

///|
pub impl Show for ParseError with fn output(self, logger) {
  logger.write_string("{code: ")
  self.code.output(logger)
  logger.write_string(", position: ")
  self.position.output(logger)
  logger.write_string("}")
}

///|
pub impl Show for Namespace with fn output(self, logger) {
  logger.write_string(namespace_name(self))
}

///|
fn quirks_mode_name(mode : QuirksMode) -> String {
  match mode {
    NoQuirks => "NoQuirks"
    Quirks => "Quirks"
    LimitedQuirks => "LimitedQuirks"
  }
}

///|
fn state_name(state : State) -> String {
  match state {
    Data => "Data"
    RCDATA => "RCDATA"
    RAWTEXT => "RAWTEXT"
    ScriptData => "ScriptData"
    PLAINTEXT => "PLAINTEXT"
    TagOpen => "TagOpen"
    EndTagOpen => "EndTagOpen"
    TagName => "TagName"
    SelfClosingStartTag => "SelfClosingStartTag"
    RCDATALessThanSign => "RCDATALessThanSign"
    RCDATAEndTagOpen => "RCDATAEndTagOpen"
    RCDATAEndTagName => "RCDATAEndTagName"
    RAWTEXTLessThanSign => "RAWTEXTLessThanSign"
    RAWTEXTEndTagOpen => "RAWTEXTEndTagOpen"
    RAWTEXTEndTagName => "RAWTEXTEndTagName"
    ScriptDataLessThanSign => "ScriptDataLessThanSign"
    ScriptDataEndTagOpen => "ScriptDataEndTagOpen"
    ScriptDataEndTagName => "ScriptDataEndTagName"
    ScriptDataEscapeStart => "ScriptDataEscapeStart"
    ScriptDataEscapeStartDash => "ScriptDataEscapeStartDash"
    ScriptDataEscaped => "ScriptDataEscaped"
    ScriptDataEscapedDash => "ScriptDataEscapedDash"
    ScriptDataEscapedDashDash => "ScriptDataEscapedDashDash"
    ScriptDataEscapedLessThanSign => "ScriptDataEscapedLessThanSign"
    ScriptDataEscapedEndTagOpen => "ScriptDataEscapedEndTagOpen"
    ScriptDataEscapedEndTagName => "ScriptDataEscapedEndTagName"
    ScriptDataDoubleEscapeStart => "ScriptDataDoubleEscapeStart"
    ScriptDataDoubleEscaped => "ScriptDataDoubleEscaped"
    ScriptDataDoubleEscapedDash => "ScriptDataDoubleEscapedDash"
    ScriptDataDoubleEscapedDashDash => "ScriptDataDoubleEscapedDashDash"
    ScriptDataDoubleEscapedLessThanSign => "ScriptDataDoubleEscapedLessThanSign"
    ScriptDataDoubleEscapeEnd => "ScriptDataDoubleEscapeEnd"
    BeforeAttributeName => "BeforeAttributeName"
    AttributeName => "AttributeName"
    AfterAttributeName => "AfterAttributeName"
    BeforeAttributeValue => "BeforeAttributeValue"
    AttributeValueDoubleQuoted => "AttributeValueDoubleQuoted"
    AttributeValueSingleQuoted => "AttributeValueSingleQuoted"
    AttributeValueUnquoted => "AttributeValueUnquoted"
    AfterAttributeValueQuoted => "AfterAttributeValueQuoted"
    BogusComment => "BogusComment"
    MarkupDeclarationOpen => "MarkupDeclarationOpen"
    CommentStart => "CommentStart"
    CommentStartDash => "CommentStartDash"
    Comment => "Comment"
    CommentLessThanSign => "CommentLessThanSign"
    CommentLessThanSignBang => "CommentLessThanSignBang"
    CommentLessThanSignBangDash => "CommentLessThanSignBangDash"
    CommentLessThanSignBangDashDash => "CommentLessThanSignBangDashDash"
    CommentEndDash => "CommentEndDash"
    CommentEnd => "CommentEnd"
    CommentEndBang => "CommentEndBang"
    DOCTYPE => "DOCTYPE"
    BeforeDOCTYPEName => "BeforeDOCTYPEName"
    DOCTYPEName => "DOCTYPEName"
    AfterDOCTYPEName => "AfterDOCTYPEName"
    AfterDOCTYPEPublicKeyword => "AfterDOCTYPEPublicKeyword"
    BeforeDOCTYPEPublicIdentifier => "BeforeDOCTYPEPublicIdentifier"
    DOCTYPEPublicIdentifierDoubleQuoted => "DOCTYPEPublicIdentifierDoubleQuoted"
    DOCTYPEPublicIdentifierSingleQuoted => "DOCTYPEPublicIdentifierSingleQuoted"
    AfterDOCTYPEPublicIdentifier => "AfterDOCTYPEPublicIdentifier"
    BetweenDOCTYPEPublicAndSystemIdentifiers =>
      "BetweenDOCTYPEPublicAndSystemIdentifiers"
    AfterDOCTYPESystemKeyword => "AfterDOCTYPESystemKeyword"
    BeforeDOCTYPESystemIdentifier => "BeforeDOCTYPESystemIdentifier"
    DOCTYPESystemIdentifierDoubleQuoted => "DOCTYPESystemIdentifierDoubleQuoted"
    DOCTYPESystemIdentifierSingleQuoted => "DOCTYPESystemIdentifierSingleQuoted"
    AfterDOCTYPESystemIdentifier => "AfterDOCTYPESystemIdentifier"
    BogusDOCTYPE => "BogusDOCTYPE"
    CDATASection => "CDATASection"
    CDATASectionBracket => "CDATASectionBracket"
    CDATASectionEnd => "CDATASectionEnd"
    CharacterReference => "CharacterReference"
    NamedCharacterReference => "NamedCharacterReference"
    AmbiguousAmpersand => "AmbiguousAmpersand"
    NumericCharacterReference => "NumericCharacterReference"
    HexadecimalCharacterReferenceStart => "HexadecimalCharacterReferenceStart"
    DecimalCharacterReferenceStart => "DecimalCharacterReferenceStart"
    HexadecimalCharacterReference => "HexadecimalCharacterReference"
    DecimalCharacterReference => "DecimalCharacterReference"
    NumericCharacterReferenceEnd => "NumericCharacterReferenceEnd"
  }
}

///|
fn parse_error_code_name(code : ParseErrorCode) -> String {
  match code {
    AbruptClosingOfEmptyComment => "AbruptClosingOfEmptyComment"
    EofInComment => "EofInComment"
    IncorrectlyClosedComment => "IncorrectlyClosedComment"
    IncorrectlyOpenedComment => "IncorrectlyOpenedComment"
    NestedComment => "NestedComment"
    AbruptDoctypePublicIdentifier => "AbruptDoctypePublicIdentifier"
    AbruptDoctypeSystemIdentifier => "AbruptDoctypeSystemIdentifier"
    EofInDoctype => "EofInDoctype"
    InvalidCharacterSequenceAfterDoctypeName =>
      "InvalidCharacterSequenceAfterDoctypeName"
    MissingDoctypeName => "MissingDoctypeName"
    MissingDoctypePublicIdentifier => "MissingDoctypePublicIdentifier"
    MissingDoctypeSystemIdentifier => "MissingDoctypeSystemIdentifier"
    MissingQuoteBeforeDoctypePublicIdentifier =>
      "MissingQuoteBeforeDoctypePublicIdentifier"
    MissingQuoteBeforeDoctypeSystemIdentifier =>
      "MissingQuoteBeforeDoctypeSystemIdentifier"
    MissingWhitespaceAfterDoctypePublicKeyword =>
      "MissingWhitespaceAfterDoctypePublicKeyword"
    MissingWhitespaceAfterDoctypeSystemKeyword =>
      "MissingWhitespaceAfterDoctypeSystemKeyword"
    MissingWhitespaceBeforeDoctypeName => "MissingWhitespaceBeforeDoctypeName"
    MissingWhitespaceBetweenDoctypePublicAndSystemIdentifiers =>
      "MissingWhitespaceBetweenDoctypePublicAndSystemIdentifiers"
    UnexpectedCharacterAfterDoctypeSystemIdentifier =>
      "UnexpectedCharacterAfterDoctypeSystemIdentifier"
    DuplicateAttribute => "DuplicateAttribute"
    EndTagWithAttributes => "EndTagWithAttributes"
    EndTagWithTrailingSolidus => "EndTagWithTrailingSolidus"
    EofBeforeTagName => "EofBeforeTagName"
    EofInTag => "EofInTag"
    InvalidFirstCharacterOfTagName => "InvalidFirstCharacterOfTagName"
    MissingAttributeValue => "MissingAttributeValue"
    MissingEndTagName => "MissingEndTagName"
    MissingWhitespaceBetweenAttributes => "MissingWhitespaceBetweenAttributes"
    NonVoidHtmlElementStartTagWithTrailingSolidus =>
      "NonVoidHtmlElementStartTagWithTrailingSolidus"
    UnexpectedCharacterInAttributeName => "UnexpectedCharacterInAttributeName"
    UnexpectedCharacterInUnquotedAttributeValue =>
      "UnexpectedCharacterInUnquotedAttributeValue"
    UnexpectedEqualsSignBeforeAttributeName =>
      "UnexpectedEqualsSignBeforeAttributeName"
    UnexpectedNullCharacter => "UnexpectedNullCharacter"
    UnexpectedQuestionMarkInsteadOfTagName =>
      "UnexpectedQuestionMarkInsteadOfTagName"
    UnexpectedSolidusInTag => "UnexpectedSolidusInTag"
    AbsenceOfDigitsInNumericCharacterReference =>
      "AbsenceOfDigitsInNumericCharacterReference"
    CharacterReferenceOutsideUnicodeRange =>
      "CharacterReferenceOutsideUnicodeRange"
    ControlCharacterReference => "ControlCharacterReference"
    MissingSemicolonAfterCharacterReference =>
      "MissingSemicolonAfterCharacterReference"
    NoncharacterCharacterReference => "NoncharacterCharacterReference"
    NullCharacterReference => "NullCharacterReference"
    SurrogateCharacterReference => "SurrogateCharacterReference"
    UnknownNamedCharacterReference => "UnknownNamedCharacterReference"
    CdataInHtmlContent => "CdataInHtmlContent"
    ControlCharacterInInputStream => "ControlCharacterInInputStream"
    EofInCdata => "EofInCdata"
    EofInScriptHtmlCommentLikeText => "EofInScriptHtmlCommentLikeText"
    NoncharacterInInputStream => "NoncharacterInInputStream"
    SurrogateInInputStream => "SurrogateInInputStream"
  }
}

///|
fn namespace_name(ns : Namespace) -> String {
  match ns {
    HTML => "HTML"
    SVG => "SVG"
    MathML => "MathML"
  }
}
