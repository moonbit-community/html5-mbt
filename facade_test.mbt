///|
test "root package facade exposes parser API" {
  let doc = @html.parse("<p>ok</p>")
  assert_true(doc.get_text_content(doc.body_element) is "ok")
  let (tokens, errors) = @html.tokenize("<br>")
  assert_true(errors.is_empty())
  assert_true(tokens[0] is StartTag(name="br", attrs=[], self_closing=false))
}
