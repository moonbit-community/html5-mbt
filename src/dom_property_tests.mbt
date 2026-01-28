// Copyright 2026 International Digital Economy Academy
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
/// QuickCheck generator for DOM `Document`. Builds an `html`/`head`/`body`
/// skeleton and then sprinkles small random elements, text, and comments while
/// keeping parent/child pointers consistent (including template content
/// fragments).
pub impl @qc_core.Arbitrary for Document with arbitrary(size, rs) {
  let capped_size = clamp_size(size, 0, 24)
  // Base of: document node + optional doctype + html/head/body
  let target_nodes = 5 + capped_size
  let doc = Document::new()
  doc.quirks_mode = random_quirks_mode(rs)

  // Optional doctype before the root element
  if rs.next_double() < 0.8 && doc.nodes.length() < target_nodes {
    let doctype_id = doc.add_node(
      DocumentTypeNode(
        name="html",
        public_id=maybe_doctype_id(rs, capped_size),
        system_id=maybe_doctype_id(rs, capped_size),
      ),
    )
    doc.append_child(0, doctype_id)
  }

  // Required html/head/body scaffold
  let html_id = doc.add_node(ElementNode(Element::new("html", HTML, [])))
  doc.document_element = html_id
  doc.append_child(0, html_id)
  let head_id = doc.add_node(ElementNode(Element::new("head", HTML, [])))
  doc.head_element = head_id
  doc.append_child(html_id, head_id)
  let body_id = doc.add_node(ElementNode(Element::new("body", HTML, [])))
  doc.body_element = body_id
  doc.append_child(html_id, body_id)

  // Grow the tree breadth-first from head/body and any template fragments
  let mut parents : Array[Int] = [body_id, head_id]
  while doc.nodes.length() < target_nodes && parents.length() > 0 {
    let parent_idx = rs.next_positive_int() % parents.length()
    let parent_id = parents[parent_idx]
    let in_head = parent_id == head_id
    let roll = rs.next_double()
    if roll < 0.6 && doc.nodes.length() < target_nodes {
      let ns = random_namespace(rs, in_head)
      let tag = random_tag_name(ns, in_head, rs)
      let attrs = random_attributes(rs, capped_size)
      let elem_id = doc.add_node(ElementNode(Element::new(tag, ns, attrs)))
      doc.append_child(parent_id, elem_id)

      // Template content fragment
      if tag == "template" && ns == HTML && doc.nodes.length() < target_nodes {
        let frag_id = doc.add_node(DocumentFragmentNode(children=[]))
        match doc.nodes[elem_id] {
          ElementNode(elem) => elem.template_content = frag_id
          _ => ()
        }
        parents.push(frag_id)
      }

      // Lightweight inline text for metadata-like tags
      if doc.nodes.length() < target_nodes &&
        (tag == "title" || tag == "script" || tag == "style") {
        let text_id = doc.add_node(TextNode(random_text(rs, capped_size + 6)))
        doc.append_child(elem_id, text_id)
      }
      if !is_likely_leaf(tag) && doc.nodes.length() < target_nodes && !in_head {
        parents.push(elem_id)
      }
    } else if roll < 0.83 && doc.nodes.length() < target_nodes {
      let text_id = doc.add_node(TextNode(random_text(rs, capped_size + 8)))
      doc.append_child(parent_id, text_id)
    } else if doc.nodes.length() < target_nodes {
      let comment_id = doc.add_node(
        CommentNode(random_comment(rs, capped_size + 4)),
      )
      doc.append_child(parent_id, comment_id)
    }
  }
  doc
}

///|
struct HtmlCase {
  html : String
} derive(Show)

///|
/// Generate weird-ish HTML by taking a serialized DOM as a base and then
/// injecting small random "damage" (comments, stray tags, whitespace, etc).
///
/// This keeps test inputs close to what the serializer emits while still
/// exercising the parser on malformed/odd HTML.
pub impl @qc_core.Arbitrary for HtmlCase with arbitrary(size, rs) {
  let capped_size = clamp_size(size, 0, 24)
  let seed_doc : Document = @qc_core.Arbitrary::arbitrary(capped_size, rs)
  let base = seed_doc.to_html()
  let damaged = inject_html_noise(base, rs, capped_size)
  HtmlCase::{ html: damaged }
}

///|
fn clamp_size(value : Int, min : Int, max : Int) -> Int {
  if value < min {
    min
  } else if value > max {
    max
  } else {
    value
  }
}

///|
fn random_length(
  rs : @splitmix.RandomState,
  min_len : Int,
  max_len : Int,
) -> Int {
  if max_len <= min_len {
    min_len
  } else {
    min_len + rs.next_positive_int() % (max_len - min_len + 1)
  }
}

///|
fn[T] pick_from_array(choices : Array[T], rs : @splitmix.RandomState) -> T {
  let idx = rs.next_positive_int() % choices.length()
  choices[idx]
}

///|
fn random_ascii_word(
  rs : @splitmix.RandomState,
  min_len : Int,
  max_len : Int,
) -> String {
  let alphabet : Array[Char] = [
    'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p',
    'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z', 'A', 'B', 'C', 'D', 'E', 'F',
    'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V',
    'W', 'X', 'Y', 'Z', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '-', '_',
    '.',
  ]
  let len = random_length(rs, min_len, max_len)
  let buf = StringBuilder::new()
  for _ in 0..<len {
    buf.write_char(pick_from_array(alphabet, rs))
  }
  buf.to_string()
}

///|
fn random_text(rs : @splitmix.RandomState, size_hint : Int) -> String {
  let text_chars : Array[Char] = [
    'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p',
    'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z', 'A', 'B', 'C', 'D', 'E', 'F',
    'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V',
    'W', 'X', 'Y', 'Z', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', ' ', '\t',
    '\n', '.', ',', ';', ':', '-', '_', '/', '?', '!',
  ]
  let max_len = clamp_size(size_hint + 4, 4, 32)
  let len = 1 + rs.next_positive_int() % max_len
  let buf = StringBuilder::new()
  for _ in 0..<len {
    buf.write_char(pick_from_array(text_chars, rs))
  }
  buf.to_string()
}

///|
fn random_comment(rs : @splitmix.RandomState, size_hint : Int) -> String {
  random_text(rs, size_hint)
}

///|
fn random_namespace(rs : @splitmix.RandomState, in_head : Bool) -> Namespace {
  if in_head {
    HTML
  } else {
    match rs.next_positive_int() % 10 {
      0 | 1 | 2 | 3 | 4 | 5 | 6 => HTML
      7 | 8 => SVG
      _ => MathML
    }
  }
}

///|
fn random_tag_name(
  ns : Namespace,
  in_head : Bool,
  rs : @splitmix.RandomState,
) -> String {
  let head_tags : Array[String] = ["meta", "title", "style", "script", "link"]
  let html_tags : Array[String] = [
    "div", "p", "span", "section", "article", "ul", "li", "a", "button", "template",
    "header", "footer", "main", "nav", "pre", "code", "blockquote", "figure",
  ]
  let svg_tags : Array[String] = ["svg", "g", "path", "rect", "circle", "text"]
  let math_tags : Array[String] = ["math", "mi", "mo", "mrow", "msup"]
  match ns {
    HTML =>
      if in_head {
        pick_from_array(head_tags, rs)
      } else {
        pick_from_array(html_tags, rs)
      }
    SVG => pick_from_array(svg_tags, rs)
    MathML => pick_from_array(math_tags, rs)
  }
}

///|
fn random_attributes(
  rs : @splitmix.RandomState,
  size_hint : Int,
) -> Array[(String, String)] {
  let max_attrs = clamp_size(size_hint, 0, 4)
  let count = rs.next_positive_int() % (max_attrs + 1)
  Array::makei(count, _ => (
    random_ascii_word(rs, 2, 8).to_lower(), // html attrs are case-insensitive
    random_ascii_word(rs, 0, 10),
  ))
}

///|
fn maybe_doctype_id(rs : @splitmix.RandomState, size_hint : Int) -> String {
  if rs.next_double() < 0.3 {
    random_ascii_word(rs, 3, clamp_size(size_hint + 4, 4, 12))
  } else {
    ""
  }
}

///|
fn random_quirks_mode(rs : @splitmix.RandomState) -> QuirksMode {
  match rs.next_positive_int() % 3 {
    0 => NoQuirks
    1 => Quirks
    _ => LimitedQuirks
  }
}

///|
fn is_likely_leaf(tag : String) -> Bool {
  match tag {
    "meta"
    | "link"
    | "br"
    | "img"
    | "hr"
    | "input"
    | "area"
    | "col"
    | "source"
    | "track"
    | "wbr"
    | "path" => true
    _ => false
  }
}

///|
fn inject_html_noise(
  base : String,
  rs : @splitmix.RandomState,
  size_hint : Int,
) -> String {
  let mut budget = clamp_size(size_hint, 0, 16)
  let buf = StringBuilder::new()

  // Optional prefix junk
  if budget > 0 && rs.next_double() < 0.2 {
    buf.write_string(random_noise_piece(rs, size_hint))
    budget = budget - 1
  }

  for c in base {
    // Occasionally drop a character to create malformed-ish input.
    if budget > 0 && rs.next_double() < 0.01 {
      budget = budget - 1
    } else {
      buf.write_char(c)
    }

    // Occasionally inject noise after tag boundaries.
    if budget > 0 && (c == '>' || c == '<') && rs.next_double() < 0.12 {
      buf.write_string(random_noise_piece(rs, size_hint))
      budget = budget - 1
    }
  }

  // Optional suffix junk
  if budget > 0 && rs.next_double() < 0.2 {
    buf.write_string(random_noise_piece(rs, size_hint))
  }

  buf.to_string()
}

///|
fn random_noise_piece(rs : @splitmix.RandomState, size_hint : Int) -> String {
  let ws_choices : Array[String] = [" ", "\n", "\t", "\n  "]
  let stray_end_tags : Array[String] = [
    "div", "p", "span", "body", "head", "html", "svg", "math", "template",
  ]
  match rs.next_positive_int() % 6 {
    0 => pick_from_array(ws_choices, rs)
    1 => "<!--" + random_comment(rs, size_hint) + "-->"
    2 => "</" + pick_from_array(stray_end_tags, rs) + ">"
    3 => "<" + random_ascii_word(rs, 1, 8) + ">"
    4 => "<!" + random_ascii_word(rs, 1, 8) + ">"
    _ => "<?" + random_ascii_word(rs, 1, 8) + "?>"
  }
}

///|
test "random html 0" {
  let html : HtmlCase = @qc_core.Arbitrary::arbitrary(10, @splitmix.new(seed=42))
  inspect(
    html.html,
    content=(
      "<html><head><meta><script sssxdro=\"J\" a0o3zby6=\"r9SKVg\"ihth=\"H4ANh--\" htptq=\"Qa23\">r<<!sfaIfP>/cript<?C?></head><!YuhHR-fh><body><!--k--><blockquote>sw!cd5_bWUwSH,53<<!--\u{9}i;GY-7?\u{a}y!R-->/blockquote>FrS<!--X\u{a}wb.V--><button ztod0=\"PbGe2BbMX\"><math></math>a5eL cUdwEAR.4kMhwkU4</button></body></html>"
    ),
  )
}

///|
impl @qc.Shrink for HtmlCase

///|
test "property roundtrip parse(to_html(parse(html))) = parse(html)" {
  @qc.quick_check_fn((h : HtmlCase) => {
    let doc = parse(h.html)
    let roundtrip = parse(doc.to_html())
    let lhs = doc.dump()
    let rhs = roundtrip.dump()
    if rhs != lhs {
      println("Original HTML:")
      println(h.html)
      println("Roundtrip HTML:")
      println(doc.to_html())
      println("Original doc:")
      println(lhs)
      println("Roundtrip doc:")
      println(rhs)
      false
    } else {
      true
    }
  }, max_success=2000)
}

///|
test "property canonical html stabilizes" {
  @qc.quick_check_fn((h : HtmlCase) => {
    let html1 = parse(h.html).to_html()
    let html2 = parse(html1).to_html()
    if html2 != html1 {
      println("HTML1:")
      println(html1)
      println("HTML2:")
      println(html2)
      false
    } else {
      true
    }
  }, max_success=2000)
}
