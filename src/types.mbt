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
} derive(Show, Eq)

///|
/// Document quirks mode (WHATWG 3.1.4)
pub(all) enum QuirksMode {
  NoQuirks
  Quirks
  LimitedQuirks
} derive(Show, Eq)

///|
/// Attribute in a start/end tag
pub struct Attribute {
  name : String
  value : String
} derive(Show, Eq)

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
} derive(Show, Eq)

///|
/// Source position for error reporting
pub struct SourcePosition {
  line : Int
  column : Int
  offset : Int
} derive(Show, Eq)

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
} derive(Show, Eq)

///|
/// A parse error with location
pub struct ParseError {
  code : ParseErrorCode
  position : SourcePosition
} derive(Show, Eq)

///|
/// Namespace for HTML, SVG, MathML
pub(all) enum Namespace {
  HTML
  SVG
  MathML
} derive(Show, Eq)
