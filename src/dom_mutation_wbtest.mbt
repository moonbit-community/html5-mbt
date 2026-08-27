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
struct DomModel {
  parents : Array[Int]
  children : Array[Array[Int]]
  containers : Array[Bool]
}

///|
fn remove_model_child(children : Array[Int], child_id : Int) -> Unit {
  for i, id in children {
    if id == child_id {
      let _ = children.remove(i)
      return
    }
  }
}

///|
fn DomModel::would_create_cycle(
  self : DomModel,
  parent_id : Int,
  child_id : Int,
) -> Bool {
  if parent_id < 0 ||
    parent_id >= self.parents.length() ||
    child_id < 0 ||
    child_id >= self.parents.length() ||
    !self.containers[parent_id] {
    return true
  }
  let mut ancestor = parent_id
  while ancestor != NO_NODE {
    if ancestor == child_id {
      return true
    }
    ancestor = self.parents[ancestor]
  }
  false
}

///|
fn DomModel::detach(self : DomModel, child_id : Int) -> Unit {
  let old_parent = self.parents[child_id]
  if old_parent != NO_NODE {
    remove_model_child(self.children[old_parent], child_id)
  }
}

///|
fn DomModel::append_child(
  self : DomModel,
  parent_id : Int,
  child_id : Int,
) -> Unit {
  if self.would_create_cycle(parent_id, child_id) {
    return
  }
  self.detach(child_id)
  self.children[parent_id].push(child_id)
  self.parents[child_id] = parent_id
}

///|
fn DomModel::insert_before(
  self : DomModel,
  parent_id : Int,
  child_id : Int,
  reference_id : Int,
) -> Unit {
  if child_id == reference_id || self.would_create_cycle(parent_id, child_id) {
    return
  }
  self.detach(child_id)
  let mut index = self.children[parent_id].length()
  for i, id in self.children[parent_id] {
    if id == reference_id {
      index = i
      break
    }
  }
  self.children[parent_id].insert(index, child_id)
  self.parents[child_id] = parent_id
}

///|
fn DomModel::remove_child(
  self : DomModel,
  parent_id : Int,
  child_id : Int,
) -> Unit {
  if parent_id < 0 ||
    parent_id >= self.parents.length() ||
    child_id < 0 ||
    child_id >= self.parents.length() ||
    self.parents[child_id] != parent_id {
    return
  }
  remove_model_child(self.children[parent_id], child_id)
  self.parents[child_id] = NO_NODE
}

///|
fn assert_dom_matches_model(doc : Document, model : DomModel) -> Unit raise {
  @debug.assert_eq(doc.nodes.length(), model.parents.length())
  for id in 0..<doc.nodes.length() {
    @debug.assert_eq(doc.get_parent(id), model.parents[id])
    @debug.assert_eq(doc.get_children(id), model.children[id])
    match doc.nodes[id] {
      ElementNode(element) =>
        @debug.assert_eq(element.parent, model.parents[id])
      _ => ()
    }
    let seen = Array::make(doc.nodes.length(), false)
    for child_id in doc.get_children(id) {
      assert_true(child_id >= 0 && child_id < doc.nodes.length())
      assert_false(seen[child_id])
      seen[child_id] = true
      @debug.assert_eq(doc.get_parent(child_id), id)
    }
    let mut ancestor = doc.get_parent(id)
    let mut depth = 0
    while ancestor != NO_NODE {
      assert_true(ancestor >= 0 && ancestor < doc.nodes.length())
      assert_true(ancestor != id)
      depth += 1
      assert_true(depth < doc.nodes.length())
      ancestor = doc.get_parent(ancestor)
    }
  }
}

///|
test "DOM mutations preserve parent-child invariants" {
  let doc = Document::new()
  let _ = doc.add_node(ElementNode(Element::new("a", HTML, [])))
  let _ = doc.add_node(ElementNode(Element::new("b", HTML, [])))
  let _ = doc.add_node(ElementNode(Element::new("c", HTML, [])))
  let _ = doc.add_node(ElementNode(Element::new("d", HTML, [])))
  let _ = doc.add_node(TextNode("text"))
  let _ = doc.add_node(CommentNode("comment"))
  let _ = doc.add_node(DocumentFragmentNode(children=[]))
  let node_count = doc.nodes.length()
  let model = {
    parents: Array::make(node_count, NO_NODE),
    children: Array::makei(node_count, _ => []),
    containers: Array::makei(node_count, id => {
      id == 0 || (id >= 1 && id <= 4) || id == 7
    }),
  }
  let random = @splitmix.new(seed=20260827)
  for _ in 0..<2000 {
    let operation = random.next_positive_int() % 4
    let parent_id = random.next_positive_int() % node_count
    let child_id = 1 + random.next_positive_int() % (node_count - 1)
    let reference_id = 1 + random.next_positive_int() % (node_count - 1)
    match operation {
      0 => {
        doc.append_child(parent_id, child_id)
        model.append_child(parent_id, child_id)
      }
      1 => {
        doc.insert_before(parent_id, child_id, reference_id)
        model.insert_before(parent_id, child_id, reference_id)
      }
      _ => {
        doc.remove_child(parent_id, child_id)
        model.remove_child(parent_id, child_id)
      }
    }
    assert_dom_matches_model(doc, model)
  }

  doc.append_child(-1, 1)
  doc.append_child(node_count, 1)
  doc.insert_before(-1, 1, 2)
  doc.remove_child(node_count, 1)
  assert_dom_matches_model(doc, model)
}
