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
