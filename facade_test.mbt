///|
test "root package facade exposes parser API" {
  let doc = @html.parse("<p>ok</p>")
  assert_true(doc.get_text_content(doc.body_element) is "ok")
  let (tokens, errors) = @html.tokenize("<br>")
  assert_true(errors.is_empty())
  assert_true(tokens[0] is StartTag(name="br", attrs=[], self_closing=false))
}

///|
test "DOM insertion rejects self and ancestor cycles" {
  let doc = @html.parse("<div><span></span></div>")
  let div = doc.get_children(doc.body_element)[0]
  let span = doc.get_children(div)[0]
  let before = doc.to_html()
  doc.append_child(div, div)
  doc.append_child(span, div)
  doc.insert_before(span, div, span)
  assert_eq(doc.to_html(), before)
  assert_eq(doc.get_children(div), [span])
  assert_true(doc.get_children(span).is_empty())
}

///|
test "serializer preserves literal text element contents" {
  for tag in ["xmp", "iframe", "noembed", "noframes", "plaintext"] {
    let input = "<\{tag}>&amp;"
    let doc = @html.parse(input)
    assert_true(doc.to_html().contains("<\{tag}>&amp;</\{tag}>"))
  }
  let scripted = @html.parse_with_scripting("<body><noscript>&lt;b></noscript>")
  assert_true(scripted.to_html().contains("<noscript>&lt;b></noscript>"))
  let nonscripted = @html.parse("<body><noscript>&lt;b></noscript>")
  assert_true(nonscripted.to_html().contains("<noscript>&lt;b&gt;</noscript>"))
}

///|
test "DOM mutation preserves parent-child consistency" {
  let doc = @html.parse(
    "<div><span>text</span></div><section></section><template><i></i></template>",
  )
  let body_children = doc.get_children(doc.body_element)
  let div = body_children[0]
  let section = body_children[1]
  let template = body_children[2]
  let span = doc.get_children(div)[0]
  let text = doc.get_children(span)[0]
  assert_eq(doc.get_parent(text), span)
  doc.append_child(section, span)
  assert_true(doc.get_children(div).is_empty())
  assert_eq(doc.get_children(section), [span])
  assert_eq(doc.get_parent(span), section)
  doc.remove_child(div, span)
  assert_eq(doc.get_children(section), [span])
  assert_eq(doc.get_parent(span), section)
  let fragment = doc.get_template_content(template)
  let fragment_child = doc.get_children(fragment)[0]
  assert_eq(doc.get_parent(fragment_child), fragment)
  doc.remove_child(fragment, fragment_child)
  assert_true(doc.get_children(fragment).is_empty())
  assert_eq(doc.get_parent(fragment_child), @html.NO_NODE)
}

///|
test "processing instructions follow current WHATWG syntax" {
  let (tokens, errors) = @html.tokenize("<?foo bar?>")
  assert_true(errors.is_empty())
  assert_true(tokens is [ProcessingInstruction(target="foo", data="bar"), EOF])
  let doc = @html.parse("<!doctype html><?foo bar?>")
  assert_true(doc.dump().contains("<?foo bar?>"))
  assert_true(doc.to_html().contains("<?foo bar?>"))
  let (xml_tokens, xml_errors) = @html.tokenize("<?xml version='1.0'?>")
  assert_true(xml_tokens[0] is Comment("?xml version='1.0'?"))
  assert_true(xml_errors[0].code is DisallowedProcessingInstructionTarget)
  let (unfinished_tokens, unfinished_errors) = @html.tokenize("<?marker")
  assert_true(unfinished_tokens is [EOF])
  assert_true(unfinished_errors[0].code is EofInProcessingInstruction)
  let (invalid_tokens, invalid_errors) = @html.tokenize("<?#data>")
  assert_true(invalid_tokens is [Comment("?#data"), EOF])
  assert_true(
    invalid_errors[0].code is InvalidFirstCharacterOfProcessingInstructionTarget,
  )
}

///|
test "parse diagnostics preserve positions and error domains" {
  let (_, cr_errors) = @html.tokenize("&foo\r<")
  let cr_error = cr_errors[cr_errors.length() - 1]
  assert_true(cr_error.code is EofBeforeTagName)
  assert_eq(cr_error.position.line, 2)
  assert_eq(cr_error.position.column, 2)
  assert_eq(cr_error.position.offset, 6)
  let (_, crlf_errors) = @html.tokenize("&foo\r\n<")
  let crlf_error = crlf_errors[crlf_errors.length() - 1]
  assert_true(crlf_error.code is EofBeforeTagName)
  assert_eq(crlf_error.position.line, 2)
  assert_eq(crlf_error.position.column, 2)
  assert_eq(crlf_error.position.offset, 7)
  let (_, tree_errors) = @html.parse_with_errors("<p>ok</p>")
  assert_true(tree_errors[0].code is TreeConstruction)
  let (_, tokenizer_errors) = @html.tokenize("<p x=<>")
  assert_true(
    tokenizer_errors[0].code is UnexpectedCharacterInUnquotedAttributeValue,
  )
}
