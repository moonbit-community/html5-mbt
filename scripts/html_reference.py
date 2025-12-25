#!/usr/bin/env python3
"""
HTML5 Reference Parser using html5lib (WHATWG-compliant).

Outputs tokenizer events and tree structure in formats matching our parser.
"""

import html5lib
from html5lib import HTMLParser, getTreeBuilder, getTreeWalker
from html5lib.constants import tokenTypes
import json
from typing import List, Tuple, Optional


def escape_for_moonbit(s: str) -> str:
    """Escape string for MoonBit string literal."""
    result = []
    for c in s:
        code = ord(c)
        if c == '\\':
            result.append('\\\\')
        elif c == '"':
            result.append('\\"')
        elif c == '\n':
            result.append('\\n')
        elif c == '\t':
            result.append('\\t')
        elif c == '\r':
            result.append('\\r')
        elif code < 0x20:
            result.append(f'\\u{{{code:02x}}}')
        elif code == 0x7F:
            result.append('\\u{7f}')
        elif 0x80 <= code <= 0x9F:
            result.append(f'\\u{{{code:02x}}}')
        else:
            result.append(c)
    return ''.join(result)


def tokenize_html(html_content: str) -> Tuple[bool, List[dict]]:
    """
    Tokenize HTML and return tokens in a structured format.
    Returns (success, tokens_list).
    """
    from html5lib import HTMLParser, getTreeBuilder
    from html5lib._tokenizer import HTMLTokenizer

    try:
        tokenizer = HTMLTokenizer(html_content)
        tokens = []
        for token in tokenizer:
            tokens.append(token)
        return True, tokens
    except Exception as e:
        return False, str(e)


def parse_html_to_tree(html_content: str) -> Tuple[bool, str]:
    """
    Parse HTML and return tree structure.
    Returns (success, tree_string).
    """
    try:
        TreeBuilder = getTreeBuilder("etree")
        parser = HTMLParser(tree=TreeBuilder, namespaceHTMLElements=False)
        doc = parser.parse(html_content)

        # Convert to simple tree representation
        def element_to_str(elem, indent=0):
            lines = []
            prefix = "| " * indent

            tag = elem.tag if isinstance(elem.tag, str) else str(elem.tag)
            # Handle namespace prefixes
            if '}' in tag:
                tag = tag.split('}')[1]

            lines.append(f"{prefix}<{tag}>")

            # Attributes
            if elem.attrib:
                for key, value in sorted(elem.attrib.items()):
                    lines.append(f"{prefix}  {key}=\"{value}\"")

            # Text content
            if elem.text:
                text = elem.text
                lines.append(f"{prefix}  \"{text}\"")

            # Children
            for child in elem:
                lines.extend(element_to_str(child, indent + 1))
                if child.tail:
                    lines.append(f"{prefix}  \"{child.tail}\"")

            return lines

        result = element_to_str(doc)
        return True, '\n'.join(result)
    except Exception as e:
        return False, str(e)


def format_token_for_moonbit(token: dict) -> str:
    """Convert an html5lib token to MoonBit Token format string."""
    token_type = token.get('type')

    if token_type == 'StartTag':
        name = escape_for_moonbit(token.get('name', ''))
        attrs = token.get('data', {})
        self_closing = token.get('selfClosing', False)
        attrs_str = ', '.join(
            f'{{name: "{escape_for_moonbit(k)}", value: "{escape_for_moonbit(v)}"}}'
            for k, v in attrs.items()
        )
        return f'StartTag(name="{name}", attrs=[{attrs_str}], self_closing={str(self_closing).lower()})'

    elif token_type == 'EndTag':
        name = escape_for_moonbit(token.get('name', ''))
        return f'EndTag(name="{name}")'

    elif token_type == 'Characters' or token_type == 'SpaceCharacters':
        data = escape_for_moonbit(token.get('data', ''))
        # Emit individual characters
        chars = [f"Character('{escape_for_moonbit(c)}')" for c in token.get('data', '')]
        return ', '.join(chars)

    elif token_type == 'Comment':
        data = escape_for_moonbit(token.get('data', ''))
        return f'Comment("{data}")'

    elif token_type == 'Doctype':
        name = token.get('name')
        public_id = token.get('publicId')
        system_id = token.get('systemId')
        name_str = f'Some("{escape_for_moonbit(name)}")' if name else 'None'
        pub_str = f'Some("{escape_for_moonbit(public_id)}")' if public_id else 'None'
        sys_str = f'Some("{escape_for_moonbit(system_id)}")' if system_id else 'None'
        return f'DOCTYPE(name={name_str}, public_id={pub_str}, system_id={sys_str}, force_quirks=false)'

    elif token_type == 'ParseError':
        return None  # Skip parse errors in token output

    return None


def main():
    """Command-line interface."""
    import sys

    if len(sys.argv) > 1:
        with open(sys.argv[1], 'r', encoding='utf-8') as f:
            content = f.read()
        success, result = parse_html_to_tree(content)
        print(result)
        sys.exit(0 if success else 1)
    else:
        # Read HTML from stdin
        content = sys.stdin.read()
        success, result = parse_html_to_tree(content)
        print(result)
        sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
