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
// Adoption Agency Algorithm (WHATWG 13.2.6.4.7)
// ============================================================================

///|
/// Run the adoption agency algorithm for a formatting element
pub fn TreeBuilder::run_adoption_agency(
  self : TreeBuilder,
  tag_name : String,
) -> Unit {
  // Outer loop counter
  let mut outer_loop = 0
  while outer_loop < 8 {
    outer_loop += 1
    // 1. Find formatting element
    let formatting_idx = self.find_formatting_element_index(tag_name)
    if formatting_idx == -1 {
      // No formatting element, process as "any other end tag"
      self.process_any_other_end_tag(tag_name)
      return
    }
    let formatting_entry = match self.get_formatting_entry(formatting_idx) {
      Some(entry) => entry
      None => return
    }
    let formatting_node_id = match formatting_entry {
      Element(node_id~, ..) => node_id
      Marker => return
    }
    // 2. Check if formatting element is in stack
    if not(self.is_in_open_elements(formatting_node_id)) {
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      self.remove_from_active_formatting(formatting_node_id)
      return
    }
    // 3. Check if formatting element is in scope
    if not(self.in_default_scope(tag_name)) {
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
      return
    }
    // 4. Check if formatting element is current node
    if self.current_node().node_id != formatting_node_id {
      self.emit_error(UnexpectedCharacterInUnquotedAttributeValue)
    }
    // 5. Find furthest block
    let furthest_block_idx = self.find_furthest_block(formatting_idx)
    if furthest_block_idx == -1 {
      // No furthest block - pop elements until formatting element
      while self.open_elements.length() > 0 {
        let entry = self.pop_element()
        if entry.node_id == formatting_node_id {
          break
        }
      }
      self.remove_from_active_formatting(formatting_node_id)
      return
    }
    // Store furthest block node_id (index becomes stale after removals)
    let furthest_block_id = self.open_elements[furthest_block_idx].node_id
    // 6. Get common ancestor
    let common_ancestor_idx = self.find_stack_position(formatting_node_id)
    if common_ancestor_idx == -1 || common_ancestor_idx == 0 {
      return
    }
    let common_ancestor = self.open_elements[common_ancestor_idx - 1].node_id
    // 7. Bookmark is the position of formatting element in the formatting list
    let mut bookmark = formatting_idx
    // 8. Variables for inner loop
    let mut node_idx = furthest_block_idx
    let mut last_node_id = furthest_block_id
    // 9. Inner loop - counter limit of 3
    let mut inner_loop = 0
    while true {
      // Increment counter first
      inner_loop += 1
      // Check if > 3, break
      if inner_loop > 3 {
        break
      }
      // 9.1 Move back in stack
      node_idx -= 1
      if node_idx < 0 {
        break
      }
      let node = self.open_elements[node_idx]
      // 9.2 Check if node is formatting element
      if node.node_id == formatting_node_id {
        break
      }
      // 9.3 Check if node is in formatting list
      let node_formatting_idx = self.find_formatting_node_index(node.node_id)
      if node_formatting_idx == -1 {
        // Remove from stack
        let _ = self.open_elements.remove(node_idx)
        continue
      }
      // 9.4 Create replacement element
      let replacement_id = self.create_element_for_formatting(
        node_formatting_idx,
      )
      // 9.5 Replace in both lists
      self.open_elements[node_idx] = {
        node_id: replacement_id,
        tag_name: node.tag_name,
        ns: node.ns,
      }
      self.replace_formatting_node(node_formatting_idx, replacement_id)
      // 9.6 Check if last node is furthest block
      if last_node_id == furthest_block_id {
        bookmark = node_formatting_idx + 1
      }
      // 9.7 Move last node into replacement
      let parent = self.document.get_parent(last_node_id)
      if parent != NO_NODE {
        self.document.remove_child(parent, last_node_id)
      }
      self.document.append_child(replacement_id, last_node_id)
      // 9.8 Set last node to current node
      last_node_id = replacement_id
    }
    // 10. Insert last node into common ancestor
    let parent = self.document.get_parent(last_node_id)
    if parent != NO_NODE {
      self.document.remove_child(parent, last_node_id)
    }
    self.insert_after_appropriate_place(common_ancestor, last_node_id)
    // 11. Create element for formatting element
    let new_formatting_id = self.create_element_for_formatting(formatting_idx)
    // 12. Move all children of furthest block into new element
    let children = self.document.get_children(furthest_block_id)
    for child_id in children {
      self.document.remove_child(furthest_block_id, child_id)
      self.document.append_child(new_formatting_id, child_id)
    }
    // 13. Append new element to furthest block
    self.document.append_child(furthest_block_id, new_formatting_id)
    // 14. Remove old formatting element from list and insert new one
    // Adjust bookmark if it's after the removed element
    if formatting_idx < bookmark {
      bookmark -= 1
    }
    self.remove_from_active_formatting(formatting_node_id)
    self.insert_formatting_at(bookmark, new_formatting_id, tag_name)
    // 15. Remove old formatting element from stack and insert new one
    self.remove_from_stack(formatting_node_id)
    self.insert_in_stack_after(furthest_block_id, new_formatting_id, tag_name)
  }
}

///|
/// Find position of a node in the stack
fn TreeBuilder::find_stack_position(self : TreeBuilder, node_id : Int) -> Int {
  for i, entry in self.open_elements {
    if entry.node_id == node_id {
      return i
    }
  }
  -1
}

///|
/// Find formatting node index by node id
fn TreeBuilder::find_formatting_node_index(
  self : TreeBuilder,
  node_id : Int,
) -> Int {
  for i = self.active_formatting.length() - 1; i >= 0; i = i - 1 {
    match self.active_formatting[i] {
      Marker => ()
      Element(node_id=entry_id, ..) => if entry_id == node_id { return i }
    }
  }
  -1
}

///|
/// Create element for a formatting entry (without inserting it)
fn TreeBuilder::create_element_for_formatting(
  self : TreeBuilder,
  formatting_idx : Int,
) -> Int {
  let entry = self.active_formatting[formatting_idx]
  match entry {
    Element(tag_name~, attributes~, ..) =>
      self.create_element_for_token(tag_name, attributes, HTML)
    Marker => NO_NODE
  }
}

///|
/// Replace node in formatting list
fn TreeBuilder::replace_formatting_node(
  self : TreeBuilder,
  idx : Int,
  new_node_id : Int,
) -> Unit {
  match self.active_formatting[idx] {
    Element(tag_name~, attributes~, ..) =>
      self.active_formatting[idx] = Element(
        node_id=new_node_id,
        tag_name~,
        attributes~,
      )
    Marker => ()
  }
}

///|
/// Insert into active formatting at specific position
fn TreeBuilder::insert_formatting_at(
  self : TreeBuilder,
  idx : Int,
  node_id : Int,
  tag_name : String,
) -> Unit {
  let attrs = self.document
    .get_element(node_id)
    .map(fn(elem) { elem.attributes })
    .unwrap_or([])
  self.active_formatting.insert(
    idx,
    Element(node_id~, tag_name~, attributes=attrs),
  )
}

///|
/// Insert in stack after a specific node
fn TreeBuilder::insert_in_stack_after(
  self : TreeBuilder,
  after_node : Int,
  node_id : Int,
  tag_name : String,
) -> Unit {
  let mut insert_idx = self.open_elements.length()
  for i, entry in self.open_elements {
    if entry.node_id == after_node {
      insert_idx = i + 1
      break
    }
  }
  self.open_elements.insert(insert_idx, { node_id, tag_name, ns: HTML })
}

///|
/// Insert after the appropriate place in the DOM
/// The parent_id is the override target - we check if IT is table-related
fn TreeBuilder::insert_after_appropriate_place(
  self : TreeBuilder,
  parent_id : Int,
  node_id : Int,
) -> Unit {
  // Check if the target (parent_id) is a table-related element
  if self.foster_parenting && self.is_table_element(parent_id) {
    self.insert_node_foster_parenting(node_id)
  } else {
    // If parent is a template, insert into template content
    let actual_parent = match self.document.get_tag_name(parent_id) {
      Some("template") => {
        let content = self.document.get_template_content(parent_id)
        if content != NO_NODE { content } else { parent_id }
      }
      _ => parent_id
    }
    self.document.append_child(actual_parent, node_id)
  }
}

///|
/// Check if a node is a table-related element that requires foster parenting
fn TreeBuilder::is_table_element(self : TreeBuilder, node_id : Int) -> Bool {
  match self.document.get_tag_name(node_id) {
    Some(tag) =>
      tag == "table" ||
      tag == "tbody" ||
      tag == "tfoot" ||
      tag == "thead" ||
      tag == "tr"
    None => false
  }
}
