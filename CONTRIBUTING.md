# MoonBit HTML5 Parser - Product Requirements Document

## Overview

This project implements a **fully WHATWG-compliant HTML5 parser** in MoonBit. It achieves 100% conformance with the html5lib tree construction test suite (8251/8251 tests passing).

### Key Features

| Feature | Description |
|---------|-------------|
| Tokenizer States | 80 states as defined in WHATWG spec |
| Insertion Modes | 25 tree construction insertion modes |
| Parse Errors | 49 error types with graceful recovery |
| Named Entities | 2,231 character references from WHATWG |
| Conformance | 100% html5lib-tests tree construction |

## Project Structure

```
aaom-html/
├── moon.mod.json              # Module definition
├── moon.pkg.json              # Root package config
├── README.md -> README.mbt.md # Symlink to README
├── README.mbt.md              # Documentation with runnable examples
├── CONTRIBUTING.md            # This file
├── LICENSE                    # Apache 2.0
│
├── src/                       # Source code
│   ├── moon.pkg.json          # Package config
│   │
│   │── Core Types
│   ├── types.mbt              # Token, State, Attribute, ParseError enums
│   ├── dom.mbt                # Document, Node, Element structures
│   │
│   │── Tokenizer (80 states)
│   ├── tokenizer.mbt          # Main tokenizer with dispatch loop
│   ├── states_data.mbt        # Data, RCDATA, RAWTEXT, PLAINTEXT, CDATA
│   ├── states_attr.mbt        # 8 attribute states
│   ├── states_comment.mbt     # 11 comment states
│   ├── states_doctype.mbt     # 16 DOCTYPE states
│   ├── states_script.mbt      # 13 script data states
│   ├── states_charref.mbt     # 9 character reference states
│   │
│   │── Tree Construction
│   ├── tree_builder.mbt       # TreeBuilder struct, main loop
│   ├── insertion_modes.mbt    # 25 insertion mode handlers
│   ├── adoption.mbt           # Adoption agency algorithm
│   ├── formatting.mbt         # Active formatting elements list
│   │
│   │── Generated Files
│   ├── entities.mbt           # 2,231 named character references (generated)
│   │
│   │── Tests
│   ├── smoke_test.mbt         # Manual smoke tests
│   ├── tokenizer_test.mbt     # Tokenizer unit tests
│   │
│   └── conformance_tests/     # Generated conformance tests
│       ├── moon.pkg.json
│       ├── html5lib_tokenizer_*_test.mbt   # Tokenizer tests (14 files)
│       └── html5lib_tree_*_test.mbt        # Tree construction tests (4 files)
│
├── scripts/                   # Code generation scripts
│   ├── generate_entities.py           # Entity table generator
│   ├── generate_conformance_tests.py  # Test suite generator
│   └── html_reference.py              # Reference parser utility
│
└── html5lib-tests/            # Cloned test suite (git-ignored)
    ├── tokenizer/             # Tokenizer test files (.test JSON)
    └── tree-construction/     # Tree construction tests (.dat format)
```

## Building the Project

### Prerequisites

- [MoonBit toolchain](https://www.moonbitlang.com/download/) (moon CLI)
- Python 3.8+ (for code generation scripts)

### Build Commands

```bash
# Type check
moon check

# Run all tests
moon test

# Run tests with verbose output
moon test --verbose

# Format code
moon fmt

# Regenerate .mbti interface files
moon info
```

### Running Specific Tests

```bash
# Run only smoke tests
moon test src

# Run only conformance tests
moon test src/conformance_tests

# Update snapshot tests
moon test --update
```

## Code Generation Scripts

### 1. Entity Table Generator (`scripts/generate_entities.py`)

Downloads the official WHATWG named character reference list and generates MoonBit lookup code.

**Source:** https://html.spec.whatwg.org/entities.json

**Usage:**
```bash
python3 scripts/generate_entities.py
```

**What it does:**
1. Downloads `entities.json` from WHATWG HTML spec
2. Parses all 2,231 named character references
3. Generates `src/entities.mbt` with:
   - Lazy-loaded `Map[String, Array[Int]]` for memory efficiency
   - `lookup_entity(name: String) -> Array[Int]?` function
4. Each entity maps to one or more Unicode codepoints

**Example entities:**
| Entity | Codepoints |
|--------|------------|
| `&amp;` | `[38]` (U+0026 AMPERSAND) |
| `&copy;` | `[169]` (U+00A9 COPYRIGHT SIGN) |
| `&NotNestedGreaterGreater;` | `[10914, 824]` (two codepoints) |

### 2. Conformance Test Generator (`scripts/generate_conformance_tests.py`)

Generates MoonBit test files from the html5lib-tests suite.

**Source:** https://github.com/html5lib/html5lib-tests

**Usage:**
```bash
python3 scripts/generate_conformance_tests.py
```

**What it does:**

1. **Clone test suite** (if not present):
   ```bash
   git clone --depth 1 https://github.com/html5lib/html5lib-tests.git
   ```

2. **Generate tokenizer tests** from `html5lib-tests/tokenizer/*.test`:
   - Parses JSON test format
   - Handles double-escaped input strings
   - Converts expected tokens to MoonBit `Token` enum format
   - Outputs to `src/conformance_tests/html5lib_tokenizer_*_test.mbt`

3. **Generate tree construction tests** from `html5lib-tests/tree-construction/*.dat`:
   - Parses `.dat` format (sections prefixed with `#data`, `#document`, etc.)
   - Normalizes expected tree output
   - Handles `#script-on` and `#script-off` variants
   - Outputs to `src/conformance_tests/html5lib_tree_*_test.mbt`

4. **Format generated files** with `moon fmt`

**Test file limits:**
- Max 500 tests per file to avoid OOM during compilation
- Tokenizer: ~14 files
- Tree construction: ~4 files

### 3. Reference Parser (`scripts/html_reference.py`)

Utility for comparing against the Python html5lib reference implementation.

**Prerequisites:**
```bash
pip install html5lib
```

**Usage:**
```bash
# Parse from file
python3 scripts/html_reference.py input.html

# Parse from stdin
echo "<div>Hello</div>" | python3 scripts/html_reference.py
```

## html5lib-tests Format

### Tokenizer Tests (`.test` JSON)

```json
{
  "tests": [
    {
      "description": "Correct Doctype lowercase",
      "input": "<!DOCTYPE html>",
      "output": [["DOCTYPE", "html", null, null, true]],
      "initialStates": ["Data state"]
    }
  ]
}
```

**Output token types:**
- `["DOCTYPE", name, publicId, systemId, correctness]`
- `["StartTag", name, {attrs}, selfClosing]`
- `["EndTag", name]`
- `["Comment", data]`
- `["Character", chars]` or raw string for characters

### Tree Construction Tests (`.dat` format)

```
#data
<!DOCTYPE html><html><head></head><body><p>Hello</p></body></html>
#document
| <!DOCTYPE html>
| <html>
|   <head>
|   <body>
|     <p>
|       "Hello"
```

**Sections:**
- `#data` - Input HTML
- `#document` - Expected tree (indented with `| `)
- `#document-fragment` - Fragment context element (if any)
- `#script-on` - Test requires scripting enabled
- `#script-off` - Test requires scripting disabled

## Public API

### Main Functions

```moonbit
// Parse HTML string
fn parse(String) -> Document

// Parse with error collection
fn parse_with_errors(String) -> (Document, Array[ParseError])

// Parse with scripting enabled (affects <noscript>)
fn parse_with_scripting(String) -> Document

// Tokenize without tree construction
fn tokenize(String) -> (Array[Token], Array[ParseError])
```

### Document Methods

```moonbit
fn dump(Self) -> String           // Pretty-print tree
fn to_html(Self) -> String        // Serialize to HTML
fn get_children(Self, Int) -> Array[Int]
fn get_parent(Self, Int) -> Int
fn get_tag_name(Self, Int) -> String?
fn get_attribute(Self, Int, String) -> String?
fn get_text_content(Self, Int) -> String
```

### Token Types

```moonbit
pub(all) enum Token {
  DOCTYPE(name~ : String?, public_id~ : String?, system_id~ : String?, force_quirks~ : Bool)
  StartTag(name~ : String, attrs~ : Array[Attribute], self_closing~ : Bool)
  EndTag(name~ : String)
  Character(Char)
  Comment(String)
  EOF
}
```

## Regenerating Everything

To regenerate all generated code from scratch:

```bash
# 1. Generate entity lookup table
python3 scripts/generate_entities.py

# 2. Generate conformance tests (clones html5lib-tests if needed)
python3 scripts/generate_conformance_tests.py

# 3. Regenerate .mbti interface files
moon info

# 4. Run all tests to verify
moon test
```

## Specification References

- [WHATWG HTML Living Standard - Parsing](https://html.spec.whatwg.org/multipage/parsing.html)
- [WHATWG HTML Living Standard - Tokenization](https://html.spec.whatwg.org/multipage/parsing.html#tokenization)
- [WHATWG HTML Living Standard - Tree Construction](https://html.spec.whatwg.org/multipage/parsing.html#tree-construction)
- [WHATWG Named Character References](https://html.spec.whatwg.org/entities.json)
- [html5lib-tests Repository](https://github.com/html5lib/html5lib-tests)

## License

Apache-2.0
