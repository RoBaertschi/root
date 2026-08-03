# Wayland scanner v2: context and decisions

This document is the authoritative context for `wayland/scanner/v2`. It records
the intended behavior of the rewrite, the decisions made while designing and
reviewing it, rejected alternatives, current verification results, and known
remaining work.

If an older plan or generated example conflicts with this document, this
document takes precedence.

## Goal

The v2 scanner is a cleaner, client-only replacement for the original local
scanner. It reads a folder of Wayland protocol XML files plus a small JSON
configuration file, resolves all protocols together, and routes the generated
Odin files into configured packages and directories.

The generated source does not need to resemble v1. The exposed API should
remain familiar where doing so is useful, while fixing v1's enum sizes,
signedness, naming, and ABI mistakes.

The immediate completeness target is correct code for every protocol under
`wayland/scanner/protocols`. Those eight files cover the Wayland DTD features
that matter for this repository.

## Scope and non-goals

- Generate client-side protocol bindings only.
- Generate one Odin file per XML protocol, not one file per interface.
- Do not generate the handwritten/libwayland binding layer.
- Do not generate server-side code.
- Do not special-case `wayland.xml`, `wl_shell`, or any other interface.
- Do not update or add a generation script yet.
- Do not replace the active v1-generated files yet.
- Use `wayland/generated-v2` as the repository-local verification output.
- Do not expand the work into generalized XML/config validation.
- Do not add compatibility wrappers merely to make the generated source match
  v1.

## Command-line interface

The initial interface is:

```sh
odin run wayland/scanner/v2 -- \
    -input:wayland/scanner/protocols \
    -config:wayland/scanner/config.json
```

`-input` and `-config` are the only required options.

## Configuration contract

The config file has one top-level `bindings` entry and a `protocols` map:

```json
{
  "bindings": "..",
  "protocols": {
    "wayland": {
      "prefix": "wl_",
      "package": "wayland_protocol",
      "directory": "../generated-v2/wayland"
    },
    "xdg_shell": {
      "prefix": "xdg_",
      "package": "xdg",
      "directory": "../generated-v2/xdg"
    }
  }
}
```

The `protocols` key is the XML root `<protocol name>`. It is not the XML
filename.

Each protocol entry contains:

- `prefix`: the prefix shared by every interface in that XML protocol;
- `package`: the Odin package emitted in the generated file;
- `directory`: the output directory;
- `filename`: an optional output filename.

All configured paths are relative to the config file, not the current working
directory.

If `filename` is absent, replace the XML file's `.xml` extension with `.odin`
and otherwise preserve the basename exactly. In particular, preserve hyphens;
do not normalize them to underscores.

The `bindings` path names the existing package containing the libwayland
types and procedures. The scanner never produces those bindings.

The runtime import alias is fixed as `wl`; it is not configurable.

### Output groups

An output group is identified by both:

```text
(absolute output directory, Odin package name)
```

Protocols in the same output group may refer to one another without an import.
Protocols in different output groups use the configured package name and a
relative import.

The generated core Wayland protocol and the libwayland bindings may be placed
in the same directory/package. In that case:

- no `wl` import is emitted;
- binding types and procedures are unqualified;
- a distinct filename can be configured if necessary to avoid overwriting the
  binding source file.

The repository's separate verification package uses `wayland_protocol`
because importing the existing `wayland` package from another package also
named `wayland` is invalid in Odin.

## Discovery and output behavior

- Read only immediate `*.xml` children of the input directory.
- Do not recurse.
- Do not sort merely for aesthetics; preserve XML declaration order wherever
  order affects output or ABI.
- Match each discovered XML file by its root protocol name.
- A discovered protocol with no config entry is a hard error.
- A config entry with no corresponding discovered XML file is ignored.
- Require every interface in a protocol to use that protocol's configured
  prefix. Mixed interface prefixes in one protocol are rejected.
- Create configured output directories when needed.
- Write directly to the target files.
- Do not use temporary sibling files.
- Do not delete stale output files.

## Processing model

Generation is deliberately multi-phase:

1. Read the config and parse every discovered XML protocol.
2. Build global protocol, interface, and enum indexes.
3. Resolve every typed interface/enum reference and infer enum carriers
   globally.
4. Render every configured protocol into memory.
5. Create directories and write the rendered files.

`wayland.xml` is not mandatory. If another protocol references an interface
that was not supplied, global resolution fails normally. There is no special
"core protocol required" rule.

Failures should print useful file/protocol/interface/message context and call
`os.exit(1)`. Do not build an error-propagation framework, aggregate errors,
recover, or retain user-controlled `panic`/`assert`/`ensure` paths.

## Public generated API

### Interfaces and descriptors

Each XML interface produces:

```odin
surface :: distinct wl.proxy
surface_interface: wl.interface
```

When colocated with the bindings, `proxy` and `interface` are unqualified.

The configured protocol prefix is stripped from the public interface name.
Every interface present in the XML is generated. `wl_shell`, for example,
remains an ordinary interface inside the single file generated from
`wayland.xml`.

### Requests

Each request produces:

- a public request opcode constant;
- a contextless request procedure;
- the XML description and `Since` documentation;
- a compiler deprecation annotation when applicable.

Public request names normally use:

```text
<interface>_<request>
```

If that name collides with an interface or enum/bitfield type in the same
output group, insert `get_`. This is required by local cases such as
`presentation_feedback` and `shell_surface_resize`.

Only request opcode constants are public. Do not generate public event opcode
constants.

### Familiar helpers

Keep the familiar helpers:

```text
<interface>_set_user_data
<interface>_get_user_data
<interface>_add_listener
<interface>_destroy
```

Generate the synthetic destroy helper when there is no protocol request named
`destroy`, following v1 behavior. Keep the v1 exception for `wl_display`.

### Listeners

An interface with events gets one listener struct and one add-listener helper.
Listener callbacks:

- use `proc "c"`;
- begin with `data: rawptr`;
- then receive the emitting interface pointer;
- preserve XML event and argument order;
- use the ABI mappings below.

Listener fields are not declarations that should receive compiler
`deprecated` annotations. Event `deprecated-since` therefore does not produce
an annotation on a listener field.

## ABI type mapping

Use fixed-width types at all C/Wayland ABI boundaries:

```text
XML int                       -> i32
XML uint                      -> u32
XML fixed                     -> wl.fixed_t / fixed_t
XML string                    -> cstring
typed object                  -> ^specific_interface
untyped object                -> rawptr
XML array                     -> ^wl.array / ^array
XML fd                        -> i32
typed new_id                  -> ^specific_interface result
untyped new_id                -> ^wl.proxy / ^proxy result
```

Do not use Odin `int` or `uint` for XML `int`/`uint`.

Do not wrap nullable arguments in `Maybe`. `allow-null` affects the private
Wayland wire signature only. Strings, object pointers, arrays, and other
pointer-shaped arguments retain their ordinary public type.

Arrays are pointers in both request procedures and listener callbacks.

An untyped object is `rawptr`, matching upstream's `void *` and avoiding a
forced proxy cast.

An untyped `new_id`, such as `wl_registry.bind`, exposes an interface
descriptor and version, returns `^wl.proxy`, and marshals the expanded
`interface.name`, `version`, and `nil` arguments required by the `sun`
expansion.

## Enums

Enum type names are qualified by their stripped interface name:

```text
wl_output.transform -> output_transform
xdg_toplevel.state  -> toplevel_state
```

Infer each enum's ABI carrier by resolving all references across all scanned
protocols:

```text
referenced only by int  -> enum i32
referenced only by uint -> enum u32
referenced by both      -> separate _i32 and _u32 declarations
not referenced          -> enum u32
```

Only add `_i32`/`_u32` when both representations are required. Do not add a
suffix merely for consistency.

Unreferenced error enums use `u32`; there is no special error-enum logic.

## Bitfields

Wayland XML bitfield entry values are masks, while Odin `bit_set` enum values
are bit positions. Emit power-of-two XML entries as positions:

```odin
output_mode_flag :: enum u32 {
    current   = intrinsics.constant_log2(1),
    preferred = intrinsics.constant_log2(2),
}

output_mode :: bit_set[output_mode_flag; u32]
```

The explicit backing type is mandatory. The earlier example
`bit_set[output_mode_flag]` was a planning mistake and must not be copied.
Use the inferred `i32` or `u32` carrier so the bit-set value remains ABI-sized
at four bytes.

Zero and composite mask entries are intentionally not exported as Odin
identifiers. For example, the `wl_shell_surface.resize` entries with values
`0`, `5`, `6`, `9`, and `10` are not public flag members.

Do not generate separate constants for composite masks. Users can combine
exported atomic flags when needed, but the scanner does not create named
composite values.

## Identifier rules

Identifier handling is intentionally narrow:

- prepend `_` when an identifier begins with a digit;
- append `_` when an identifier is an Odin keyword;
- otherwise preserve the identifier.

Do not replace other characters. The protocol inputs are expected to contain
valid identifiers. Do not add generalized duplicate-name handling; duplicates
are not expected.

### Minimal shadow suffixing

Suffix a parameter/receiver/result only when its name would hide an
unqualified type used later in the signature or generated procedure body.

- A declaration's own type annotation does not count by itself.
- A later use of that type in the body does count.
- A receiver is not suffixed merely because it has the same name as its own
  type.
- A qualified type such as `wayland_protocol.surface` is not hidden by a local
  parameter named `surface`.
- Keep a suffix that is independently required because the original name is
  an Odin keyword.

Example:

```odin
pointer_set_cursor :: proc(pointer: ^pointer, serial: u32, surface: ^surface)
```

But a receiver named `surface` becomes `surface_` when a later parameter or
result still needs the unqualified type `surface`.

Typed `new_id` results whose names match their result types require a suffix
because the generated body uses the type again in its cast:

```odin
display_sync :: proc(...) -> (callback_: ^callback) {
    callback_ = cast(^callback) ...
    return
}
```

Using `callback` as the result name would hide the `callback` type before the
cast. The same reasoning applies to results such as `registry_`.

## Documentation and version metadata

- Preserve protocol/interface/message/enum/entry descriptions and summaries.
- Preserve copyright text and the v2 generated header.
- Emit `Since: N` in public comments.
- Encode `since` in private Wayland message signatures.
- Read the XML attribute as `deprecated-since`.
- Emit compiler deprecation annotations only on applicable declarations:
  request procedures and applicable enum declarations/entries.
- Do not annotate listener fields/events.
- Do not emit public `*_SINCE_VERSION` constants.
- Do not emit runtime version guards.

## Private libwayland metadata

The following implementation details remain private:

- flattened protocol-local interface type tables;
- request and event `wl.message` arrays;
- descriptor initialization procedures.

Wire signatures use:

```text
int=i, uint=u, fixed=f, string=s, object=o,
new_id=n, array=a, fd=h
```

Nullable strings/objects receive `?`, `since` is prepended when nonzero, and an
untyped `new_id` expands to `sun`.

Every public interface descriptor is initialized with the exact XML name,
version, method count, event count, and message-array pointers.

## Repository routing

The current repository config routes:

```text
wayland.xml                         -> generated-v2/wayland (wayland_protocol)
xdg-shell.xml                       -> generated-v2/xdg     (xdg)
xdg-decoration-unstable-v1.xml      -> generated-v2/xdg     (xdg)
presentation-time.xml               -> generated-v2/wp      (wp)
linux-dmabuf-v1.xml                 -> generated-v2/wp      (wp)
tablet-v2.xml                       -> generated-v2/wp      (wp)
viewporter.xml                      -> generated-v2/wp      (wp)
cursor-shape-v1.xml                 -> generated-v2/wp      (wp)
```

The generated filenames retain the XML basenames, including hyphens.

## Verification status

The following was verified on 2026-07-31 using Odin
`dev-2026-07:cbb10d8ee` and `wayland-scanner 1.25.0`:

- `odin check wayland/scanner/v2` passes.
- All eight repository-local XML files generate in one invocation.
- The generated `wayland`, `xdg`, and `wp` packages pass `odin check
  -no-entry-point`.
- A temporary layout with generated core protocol code and libwayland
  bindings in the same directory/package also compiles.
- All 48 interfaces, 145 requests, 139 events, 56 XML enums, and 362 enum
  entries were structurally checked.
- All upstream message names, wire signatures, type-table entries/offsets,
  descriptor references, interface versions, and method/event counts match
  `wayland-scanner private-code`.
- All 145 request wrappers have matching ABI parameter/result shapes, opcodes,
  constructor descriptors, destructor flags, and vararg arity.
- All 139 listener callbacks have matching ABI parameter shapes.
- All nine emitted bit-set types have explicit four-byte backing.
- All 33 listener structs have the expected C function-pointer layout.

The active v1 output and generation script were not changed by this work.

## Explicitly rejected alternatives

- Recursive XML discovery.
- Sorting input/output solely for presentation.
- Matching config entries by filename.
- Normalizing hyphens in default output filenames.
- Guessing protocol ownership from interface prefixes.
- Requiring or specially handling `wayland.xml`.
- Generating `wl_shell` separately.
- Generating the libwayland binding layer.
- Server-side generation.
- `Maybe` wrappers for nullable arguments.
- `int`/`uint` at ABI boundaries.
- Treating untyped objects as `^wl.proxy`.
- Emitting bit-sets without an explicit backing type.
- Emitting zero/composite masks as flag positions.
- Emitting separate constants for composite bitfield masks.
- Annotating listener fields with `deprecated`.
- Public since-version constants or runtime version guards.
- Broad identifier sanitization or duplicate detection.
- Temporary sibling output files.
- Error aggregation or returning errors through the generation pipeline.
- Generalized validation work beyond failures needed to generate correctly.
- Updating or adding generation scripts during this phase.
