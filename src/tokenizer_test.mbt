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
test "tokenize simple tag" {
  let (tokens, errors) = tokenize("<div>hello</div>")
  inspect(errors.length(), content="0")
  inspect(
    tokens,
    content="[StartTag(name=\"div\", attrs=[], self_closing=false), Character('h'), Character('e'), Character('l'), Character('l'), Character('o'), EndTag(name=\"div\"), EOF]",
  )
}

///|
test "tokenize with attributes" {
  let html = "<div class=\"foo\" id=\"bar\">text</div>"
  let (tokens, _) = tokenize(html)
  match tokens[0] {
    StartTag(name~, attrs~, self_closing~) => {
      inspect(name, content="div")
      inspect(self_closing, content="false")
      inspect(attrs.length(), content="2")
      inspect(attrs[0].name, content="class")
      inspect(attrs[0].value, content="foo")
      inspect(attrs[1].name, content="id")
      inspect(attrs[1].value, content="bar")
    }
    _ => fail("Expected StartTag")
  }
}

///|
test "tokenize self-closing tag" {
  let (tokens, _) = tokenize("<br/>")
  match tokens[0] {
    StartTag(name~, self_closing~, ..) => {
      inspect(name, content="br")
      inspect(self_closing, content="true")
    }
    _ => fail("Expected StartTag")
  }
}

///|
test "tokenize comment" {
  let (tokens, _) = tokenize("<!-- hello world -->")
  match tokens[0] {
    Comment(text) => inspect(text, content=" hello world ")
    _ => fail("Expected Comment")
  }
}

///|
test "tokenize DOCTYPE" {
  let (tokens, _) = tokenize("<!DOCTYPE html>")
  match tokens[0] {
    DOCTYPE(name~, public_id~, system_id~, force_quirks~) => {
      inspect(name, content="Some(\"html\")")
      inspect(public_id, content="None")
      inspect(system_id, content="None")
      inspect(force_quirks, content="false")
    }
    _ => fail("Expected DOCTYPE")
  }
}

///|
test "tokenize character reference" {
  let (tokens, _) = tokenize("&amp;&lt;&gt;")
  // Character references emit individual characters
  let chars = tokens
    .iter()
    .filter_map(fn(t) {
      match t {
        Character(c) => Some(c)
        _ => None
      }
    })
    .collect()
  inspect(chars, content="['&', '<', '>']")
}

///|
test "tokenize numeric character reference" {
  let (tokens, _) = tokenize("&#65;&#x41;")
  let chars = tokens
    .iter()
    .filter_map(fn(t) {
      match t {
        Character(c) => Some(c)
        _ => None
      }
    })
    .collect()
  inspect(chars, content="['A', 'A']")
}

///|
test "error recovery - unclosed tag" {
  let (tokens, errors) = tokenize("<div")
  // Should emit EOF with error
  inspect(errors.length() > 0, content="true")
  match tokens[tokens.length() - 1] {
    EOF => ()
    _ => fail("Expected EOF")
  }
}

///|
test "error recovery - null character" {
  let (tokens, errors) = tokenize("hello\u{0000}world")
  // Null should be replaced with replacement character and emit error
  inspect(errors.length() > 0, content="true")
  let has_replacement = tokens
    .iter()
    .any(fn(t) {
      match t {
        Character('\u{FFFD}') => true
        _ => false
      }
    })
  inspect(has_replacement, content="true")
}

///|
test "tokenize attribute with single quotes" {
  let (tokens, _) = tokenize("<div class='foo'>")
  match tokens[0] {
    StartTag(attrs~, ..) => inspect(attrs[0].value, content="foo")
    _ => fail("Expected StartTag")
  }
}

///|
test "tokenize unquoted attribute" {
  let (tokens, _) = tokenize("<div class=foo>")
  match tokens[0] {
    StartTag(attrs~, ..) => inspect(attrs[0].value, content="foo")
    _ => fail("Expected StartTag")
  }
}

///|
test "tokenize multiple attributes" {
  let html = "<input type=text name=field value=\"hello world\">"
  let (tokens, _) = tokenize(html)
  match tokens[0] {
    StartTag(attrs~, ..) => {
      inspect(attrs.length(), content="3")
      inspect(attrs[0].name, content="type")
      inspect(attrs[0].value, content="text")
      inspect(attrs[1].name, content="name")
      inspect(attrs[1].value, content="field")
      inspect(attrs[2].name, content="value")
      inspect(attrs[2].value, content="hello world")
    }
    _ => fail("Expected StartTag")
  }
}

///|
test "tokenize nested comments error" {
  let (_, errors) = tokenize("<!-- <!-- nested --> -->")
  // Should emit nested comment error
  let has_nested_error = errors
    .iter()
    .any(fn(e) {
      match e.code {
        NestedComment => true
        _ => false
      }
    })
  inspect(has_nested_error, content="true")
}
