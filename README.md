# janssonr

Strict JSON for R, backed by the system [Jansson](https://github.com/akheron/jansson)
C library. Two functions, zero R package dependencies.

janssonr implements an **R-safe profile of RFC 8259**: RFC-conformant
parsing plus deliberate extra restrictions, so that what parses maps
predictably into R (integer literals are exact or refused; fraction and
exponent literals convert by correctly rounded double conversion) and
everything that encodes is faithfully representable in JSON. Where
common JSON packages guess
(collapse duplicate keys, truncate at NUL, round big integers, stringify
NA), janssonr refuses with a classed condition.

## API

```r
from_json('{"a": 1, "b": [true, null]}')
#> $a
#> [1] 1
#> $b
#> $b[[1]]
#> [1] TRUE
#> $b[[2]]
#> NULL

to_json(list(a = 1L, b = list(TRUE, NULL)))
#> [1] "{\"a\":1,\"b\":[true,null]}"
```

### Decoding (`from_json`)

| JSON | R |
|---|---|
| object | named list, key order preserved (`{}` keeps a `character(0)` names attribute) |
| array | unnamed list, never an atomic vector (`[]` has `NULL` names) |
| string | `character(1)`, always UTF-8 |
| integer in int range | `integer(1)` (`-2147483648`, R's NA sentinel, becomes double) |
| other number | `double(1)` |
| `true` / `false` | `logical(1)` |
| `null` | `NULL` |

Rejected, with a classed error: malformed or truncated input, trailing
content, duplicate object keys at any depth (including inside arrays of
objects), invalid UTF-8, lone surrogates, NUL escapes, reals overflowing
double (`1e999`), and integer literals whose magnitude exceeds 2^53 (no
silent precision loss). The exactness guarantee is for integer literals;
number literals with a fraction or exponent (`1.5`,
`9007199254740993.0`, `1e-999`) use ordinary correctly rounded double
conversion, so writing `.0` after a big integer opts into rounding.
Nesting is capped at 1024 containers by janssonr's own guard,
independent of the Jansson version underneath.

Errors carry `line`, `column`, `position` (byte offset) and a stable
`code` string (`"duplicate_key"`, `"invalid_utf8"`, ...). Every
integer-form refusal is `"integer_precision"`: detected post-parse
(beyond 2^53) it carries an RFC 6901 JSON Pointer in `path`; detected
by the lexer (beyond the parser's integer range) it carries source
coordinates instead. `"numeric_overflow"` is real-form overflow
(`1e999`).

### Encoding (`to_json`)

| R | JSON |
|---|---|
| list with names | object, insertion order (`""` is a valid key; duplicates refuse) |
| unnamed list | array (a length-1 list stays a 1-element array) |
| length-1 unnamed atomic | bare scalar |
| other atomic | array of scalars |
| integral double, magnitude <= 2^53 | integer spelling (`1`, not `1.0`) |
| `-0` | `-0.0` (the sign bit survives the round-trip) |
| other double | 17 significant digits: the exact value round-trips |
| `NULL` | `null` |

Output is compact UTF-8, one line, no trailing newline. Refused: `NA` of
any type, `NaN`, infinities, named atomic vectors, attributes other than
list names, classed objects, duplicate or `NA` keys, raw, complex,
functions, environments.

The double round-trip guarantee is value-level: `from_json(to_json(x))`
returns bit-identical doubles, but the lexical spelling of non-integral
reals may differ across Jansson versions.

### Conditions

```
janssonr_input_error   janssonr_parse_error   janssonr_encode_error
                \             |                   /
                 \____ janssonr_error ___________/
```

## Installation

janssonr needs R >= 4.4. On Unix it links against the system Jansson
library, version **2.11 or newer** (Ubuntu 20.04+, Debian bullseye+,
RHEL 8+, current Homebrew all qualify):

```sh
# Debian/Ubuntu          # Fedora/RHEL              # macOS
apt install libjansson-dev   dnf install jansson-devel   brew install jansson
```

On Windows nothing extra is needed: Rtools carries no jansson, so the
package compiles its bundled Jansson 2.15.1 sources (`src/jansson/`).

```r
remotes::install_github("cornball-ai/janssonr")
```

### From the apt repository (Ubuntu, binary)

Prebuilt `r-cornball-janssonr` packages are published to
<https://cornball-ai.github.io/janssonr/>, built per suite so a client
is never offered a build compiled against a different release. The
repository is unsigned, so clients opt in with `Trusted: yes`. Set
`Suites` to your release codename, `noble` for 24.04:

```bash
sudo tee /etc/apt/sources.list.d/janssonr.sources > /dev/null <<'EOF'
Types: deb
URIs: https://cornball-ai.github.io/janssonr
Suites: noble
Components: main
Trusted: yes
Enabled: yes
EOF

sudo apt update
sudo apt install r-cornball-janssonr
```

The binary needs only the Jansson runtime (`libjansson4`), never a
compiler or `libjansson-dev`. Debs are built by `tools/build-deb.sh`
and indexed by `tools/mkrepo.sh` (rapt's repository pattern).

## Design notes

- All Jansson interaction sits behind one internal C seam
  (`src/jr_jansson.h`); Unix links the system library, Windows compiles
  the bundled copy, and the package code cannot tell the difference.
  The real-number contract stays value-level partly because the two
  linkages may carry different Jansson versions.
- No memory is leaked when R errors mid-conversion: the Jansson tree is
  owned by an external pointer finalizer from the moment it exists.
- janssonr never touches Jansson's process-global state
  (`json_object_seed()`, `json_set_alloc_funcs()`), which is shared with
  any other in-process user of libjansson.
