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
  assert_true(errors.length() is 0)
  assert_true(
    tokens
    is [
      StartTag(name="div", attrs=[], self_closing=false),
      Character('h'),
      Character('e'),
      Character('l'),
      Character('l'),
      Character('o'),
      EndTag(name="div"),
      EOF,
    ],
  )
}

///|
test "tokenize with attributes" {
  let html = "<div class=\"foo\" id=\"bar\">text</div>"
  let (tokens, _) = tokenize(html)
  match tokens[0] {
    StartTag(name~, attrs~, self_closing~) => {
      assert_true(name is "div")
      assert_true(self_closing is false)
      assert_true(attrs.length() is 2)
      assert_true(attrs[0].name is "class")
      assert_true(attrs[0].value is "foo")
      assert_true(attrs[1].name is "id")
      assert_true(attrs[1].value is "bar")
    }
    _ => fail("Expected StartTag")
  }
}

///|
test "tokenize self-closing tag" {
  let (tokens, _) = tokenize("<br/>")
  match tokens[0] {
    StartTag(name~, self_closing~, ..) => {
      assert_true(name is "br")
      assert_true(self_closing is true)
    }
    _ => fail("Expected StartTag")
  }
}

///|
test "tokenize comment" {
  let (tokens, _) = tokenize("<!-- hello world -->")
  match tokens[0] {
    Comment(text) => assert_true(text is " hello world ")
    _ => fail("Expected Comment")
  }
}

///|
test "tokenize DOCTYPE" {
  let (tokens, _) = tokenize("<!DOCTYPE html>")
  match tokens[0] {
    DOCTYPE(name~, public_id~, system_id~, force_quirks~) => {
      assert_true(name is Some("html"))
      assert_true(public_id is None)
      assert_true(system_id is None)
      assert_true(force_quirks is false)
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
  assert_true(chars is ['&', '<', '>'])
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
  assert_true(chars is ['A', 'A'])
}

///|
test "error recovery - unclosed tag" {
  let (tokens, errors) = tokenize("<div")
  // Should emit EOF with error
  assert_true((errors.length() > 0) is true)
  match tokens[tokens.length() - 1] {
    EOF => ()
    _ => fail("Expected EOF")
  }
}

///|
test "error recovery - null character" {
  let (tokens, errors) = tokenize("hello\u{0000}world")
  // Null should be emitted as-is per WHATWG spec (tree builder ignores it)
  assert_true((errors.length() > 0) is true)
  let has_null = tokens
    .iter()
    .any(fn(t) {
      match t {
        Character('\u{0000}') => true
        _ => false
      }
    })
  assert_true(has_null is true)
}

///|
test "tokenize attribute with single quotes" {
  let (tokens, _) = tokenize("<div class='foo'>")
  match tokens[0] {
    StartTag(attrs~, ..) => assert_true(attrs[0].value is "foo")
    _ => fail("Expected StartTag")
  }
}

///|
test "tokenize unquoted attribute" {
  let (tokens, _) = tokenize("<div class=foo>")
  match tokens[0] {
    StartTag(attrs~, ..) => assert_true(attrs[0].value is "foo")
    _ => fail("Expected StartTag")
  }
}

///|
test "tokenize multiple attributes" {
  let html = "<input type=text name=field value=\"hello world\">"
  let (tokens, _) = tokenize(html)
  match tokens[0] {
    StartTag(attrs~, ..) => {
      assert_true(attrs.length() is 3)
      assert_true(attrs[0].name is "type")
      assert_true(attrs[0].value is "text")
      assert_true(attrs[1].name is "name")
      assert_true(attrs[1].value is "field")
      assert_true(attrs[2].name is "value")
      assert_true(attrs[2].value is "hello world")
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
  assert_true(has_nested_error is true)
}
