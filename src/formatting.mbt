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

// ============================================================================
// Active formatting elements list (WHATWG 13.2.4.3)
// ============================================================================

///|
/// Check if a tag name is a formatting element (adoption agency applies)
pub fn is_formatting_element(name : String) -> Bool {
  match name {
    "a" | "b" | "big" | "code" | "em" | "font" | "i" | "nobr" | "s" | "small" |
    "strike" | "strong" | "tt" | "u" => true
    _ => false
  }
}

///|
/// Push a formatting marker onto the list
pub fn TreeBuilder::push_formatting_marker(self : TreeBuilder) -> Unit {
  self.active_formatting.push(Marker)
}

///|
/// Push an element onto the active formatting list
pub fn TreeBuilder::push_active_formatting(
  self : TreeBuilder,
  node_id : Int,
  tag_name : String,
  attrs : Array[Attribute],
) -> Unit {
  // Check for existing elements with same tag and attributes (Noah's Ark)
  let mut count = 0
  let mut oldest_idx = -1
  for i = self.active_formatting.length() - 1; i >= 0; i = i - 1 {
    match self.active_formatting[i] {
      Marker => break
      Element(tag_name=entry_tag, attributes~, ..) =>
        if entry_tag == tag_name && attributes_match(attributes, attrs) {
          count += 1
          oldest_idx = i
        }
    }
  }
  // Remove oldest if we already have 3
  if count >= 3 && oldest_idx >= 0 {
    let _ = self.active_formatting.remove(oldest_idx)

  }
  let attributes : Array[(String, String)] = attrs.map(fn(a) {
    (a.name, a.value)
  })
  self.active_formatting.push(Element(node_id~, tag_name~, attributes~))
}

///|
/// Check if two attribute arrays match
fn attributes_match(a : Array[(String, String)], b : Array[Attribute]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for attr in b {
    let found = a
      .iter()
      .any(fn(pair) { pair.0 == attr.name && pair.1 == attr.value })
    if not(found) {
      return false
    }
  }
  true
}

///|
/// Reconstruct the active formatting elements (WHATWG 13.2.4.3)
pub fn TreeBuilder::reconstruct_active_formatting(self : TreeBuilder) -> Unit {
  if self.active_formatting.is_empty() {
    return
  }
  // Check if last entry is a marker or in stack
  let last = self.active_formatting[self.active_formatting.length() - 1]
  match last {
    Marker => return
    Element(node_id~, ..) => if self.is_in_open_elements(node_id) { return }
  }
  // Reconstruct backwards
  let mut idx = self.active_formatting.length() - 1
  // Rewind
  while idx > 0 {
    idx -= 1
    match self.active_formatting[idx] {
      Marker => {
        idx += 1
        break
      }
      Element(node_id~, ..) =>
        if self.is_in_open_elements(node_id) {
          idx += 1
          break
        }
    }
  }
  // Advance and create elements
  while idx < self.active_formatting.length() {
    match self.active_formatting[idx] {
      Marker => ()
      Element(tag_name~, attributes~, ..) => {
        // Create new element
        let attrs : Array[Attribute] = attributes.map(fn(pair) {
          { name: pair.0, value: pair.1 }
        })
        let new_id = self.insert_html_element(tag_name, attrs)
        // Replace entry in list
        self.active_formatting[idx] = Element(
          node_id=new_id,
          tag_name~,
          attributes~,
        )
      }
    }
    idx += 1
  }
}

///|
/// Clear active formatting elements to the last marker
pub fn TreeBuilder::clear_active_formatting_to_marker(
  self : TreeBuilder,
) -> Unit {
  while self.active_formatting.length() > 0 {
    let entry = self.active_formatting.pop()
    match entry {
      Some(Marker) => break
      _ => ()
    }
  }
}

///|
/// Find a formatting element by tag name
pub fn TreeBuilder::find_formatting_element(
  self : TreeBuilder,
  tag_name : String,
) -> FormattingEntry? {
  for i = self.active_formatting.length() - 1; i >= 0; i = i - 1 {
    match self.active_formatting[i] {
      Marker => return None
      Element(tag_name=entry_tag, ..) as entry =>
        if entry_tag == tag_name {
          return Some(entry)
        }
    }
  }
  None
}

///|
/// Remove an element from the active formatting list by node id
pub fn TreeBuilder::remove_from_active_formatting(
  self : TreeBuilder,
  target_id : Int,
) -> Unit {
  for i = self.active_formatting.length() - 1; i >= 0; i = i - 1 {
    match self.active_formatting[i] {
      Element(node_id=entry_id, ..) if entry_id == target_id => {
        let _ = self.active_formatting.remove(i)
        return
      }
      _ => ()
    }
  }
}

///|
/// Check if a node is in the stack of open elements
fn TreeBuilder::is_in_open_elements(self : TreeBuilder, node_id : Int) -> Bool {
  for entry in self.open_elements {
    if entry.node_id == node_id {
      return true
    }
  }
  false
}

///|
/// Get the formatting element entry at an index
pub fn TreeBuilder::get_formatting_entry(
  self : TreeBuilder,
  idx : Int,
) -> FormattingEntry? {
  if idx >= 0 && idx < self.active_formatting.length() {
    Some(self.active_formatting[idx])
  } else {
    None
  }
}

///|
/// Find formatting element index in list
pub fn TreeBuilder::find_formatting_element_index(
  self : TreeBuilder,
  tag_name : String,
) -> Int {
  for i = self.active_formatting.length() - 1; i >= 0; i = i - 1 {
    match self.active_formatting[i] {
      Marker => return -1
      Element(tag_name=entry_tag, ..) => if entry_tag == tag_name { return i }
    }
  }
  -1
}

///|
/// Find the furthest block from the formatting element
pub fn TreeBuilder::find_furthest_block(
  self : TreeBuilder,
  formatting_idx : Int,
) -> Int {
  // Find the formatting element's position in the stack
  let formatting_entry = self.active_formatting[formatting_idx]
  let formatting_node_id = match formatting_entry {
    Element(node_id~, ..) => node_id
    Marker => return -1
  }
  // Find stack position
  let mut stack_idx = -1
  for i, entry in self.open_elements {
    if entry.node_id == formatting_node_id {
      stack_idx = i
      break
    }
  }
  if stack_idx == -1 {
    return -1
  }
  // Search for furthest block
  for i = stack_idx + 1; i < self.open_elements.length(); i = i + 1 {
    let entry = self.open_elements[i]
    // Check if element is "special" - namespace-aware per WHATWG spec
    let is_special = match entry.ns {
      HTML => is_special_element(entry.tag_name)
      SVG =>
        // Only foreignObject, desc, title are special in SVG namespace
        entry.tag_name == "foreignObject" ||
          entry.tag_name == "desc" ||
          entry.tag_name == "title"
      MathML =>
        // Only these are special in MathML namespace
        entry.tag_name == "mi" ||
          entry.tag_name == "mo" ||
          entry.tag_name == "mn" ||
          entry.tag_name == "ms" ||
          entry.tag_name == "mtext" ||
          entry.tag_name == "annotation-xml"
    }
    if is_special {
      return i
    }
  }
  -1
}
