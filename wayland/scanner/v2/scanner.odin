package wayland_scanner_v2

import "core:io"
import "core:container/intrusive/list"
import "core:strconv"
import "core:fmt"
import "core:encoding/xml"
import "core:encoding/json"
import "core:path/filepath"
import "core:flags"
import tokenizer "core:odin/tokenizer"
import "core:strings"
import "base:runtime"
import "core:os"
import "core:mem/virtual"

Description :: struct {
	summary: string,
	content: string,
}

Enum_Size_Info_Flag :: enum {
	I32,
	U32,
}

Enum_Size_Info_Flags :: bit_set[Enum_Size_Info_Flag]

Protocol :: struct {
	arena: virtual.Arena `fmt:"-"`,
	node:  list.Node,

	file:         string,
	file_content: string `fmt:"-"`,

	d: ^xml.Document,

	name:             string,
	prefix:           string,
	package_name:     string,
	output_directory: string,
	output_filename:  string,
	output_path:      string,
	copyright:   string, // child tag
	description: Description,

	enums:           map[string]^Enum,
	interfaces:      map[string]^Interface,
	interface_order: list.List,
}

Interface :: struct {
	node:     list.Node,
	protocol: ^Protocol,

	name:        string,
	version:     int,
	description: Description,
	enums:       list.List,
	requests:    list.List,
	events:      list.List,
}

Enum :: struct {
	node: list.Node,

	interface:      ^Interface,
	canonical_name: string,

	name:        string,
	since:       int,
	bitfield:    bool,
	description: Description,

	entries: list.List,

	size_info:     Enum_Size_Info_Flags,
	postfix:       bool,
	postfix_names: [Enum_Size_Info_Flag]string,
}

Entry :: struct {
	node: list.Node,

	description:      Description,
	name:             string,
	value:            int,
	summary:          string,
	since:            int,
	deprecated_since: int,
}

Message :: struct {
	node: list.Node,

	interface:      ^Interface,
	canonical_name: string,

	description:      Description,
	name:             string,
	destructor:       bool,
	since:            int,
	deprecated_since: int,

	args: list.List,
}

Type_Kind :: enum {
	Int,
	Uint,
	Fixed,
	String,
	Object,
	New_Id,
	Array,
	Fd,
}

Type :: struct {
	kind:      Type_Kind,
	reference: string,
	nullable:  bool,
	is_enum:   bool,
}

Arg :: struct {
	node: list.Node,

	description: Description,
	name:        string,
	type:        Type,
	summary:     string,
}

p_allocator :: proc(p: ^Protocol) -> runtime.Allocator {
	return virtual.arena_allocator(&p.arena)
}

// #region Read Protocol

read_protocol :: proc(file: string) -> (p: ^Protocol) {
	p, _ = virtual.arena_growing_bootstrap_new(Protocol, "arena")

	// #region Helpers

	element_name :: proc(p: ^Protocol, element: xml.Element_ID) -> string {
		return p.d.elements[element].ident
	}

	read_name :: proc(p: ^Protocol, element: xml.Element_ID) -> string {
		name, ok := xml.find_attribute_val_by_key(p.d, element, "name")
		if !ok {
			fmt.eprintfln("%s: %s element has no name", p.file, element_name(p, element))
			os.exit(1)
		}
		return name
	}

	read_string_body :: proc(p: ^Protocol, element_id: xml.Element_ID) -> string {
		element := p.d.elements[element_id]

		b: strings.Builder
		strings.builder_init(&b, p_allocator(p))

		for value in element.value {
			switch v in value {
			case string:
				lines := v
				for line in strings.split_lines_iterator(&lines) {
					i := 0
					for r, j in line {
						if r != '\t' && r != ' ' {
							break
						}
						i = j+1
					}

					strings.write_string(&b, line[i:])
					strings.write_rune(&b, '\n')
				}
			case u32:
			}
		}

		return strings.to_string(b)
	}

	read_summary :: proc(p: ^Protocol, element: xml.Element_ID) -> string {
		summary, _ := xml.find_attribute_val_by_key(p.d, element, "summary")
		return summary
	}

	read_description :: proc(p: ^Protocol, element: xml.Element_ID) -> (d: Description) {
		element, ok := xml.find_child_by_ident(p.d, element, "description")
		if !ok {
			return {}
		}

		d.content = read_string_body(p, element)
		d.summary, ok = xml.find_attribute_val_by_key(p.d, element, "summary")
		if !ok {
			fmt.printfln("%v: missing \"summary\" key for description of %v(%v)", p.name, element_name(p, element), element)
		}

		return
	}

	read_number :: proc(p: ^Protocol, element: xml.Element_ID, field: string, $REQUIRED: bool) -> (value: int) {
		version_string, ok := xml.find_attribute_val_by_key(p.d, element, field)
		if !ok {
			when REQUIRED {
				fmt.eprintfln("%s: %s element is missing %s", p.file, element_name(p, element), field)
				os.exit(1)
			} else {
				return
			}
		}

		value, ok = strconv.parse_int(version_string)
		if !ok {
			fmt.eprintfln("%s: %s element has invalid %s value %s", p.file, element_name(p, element), field, version_string)
			os.exit(1)
		}
		return
	}

	read_version :: proc(p: ^Protocol, element: xml.Element_ID) -> (version: int) {
		return read_number(p, element, "version", true)
	}

	read_value :: proc(p: ^Protocol, element: xml.Element_ID) -> (value: int) {
		return read_number(p, element, "value", true)
	}

	// 0 means it was always there
	read_since :: proc(p: ^Protocol, element: xml.Element_ID) -> (version: int) {
		return read_number(p, element, "since", false)
	}

	read_deprecated_since :: proc(p: ^Protocol, element: xml.Element_ID) -> (version: int) {
		return read_number(p, element, "deprecated-since", false)
	}

	read_destructor :: proc(p: ^Protocol, element: xml.Element_ID) -> bool {
		type, ok := xml.find_attribute_val_by_key(p.d, element, "type")
		if !ok {
			return false
		}

		return type == "destructor"
	}

	// #endregion

	// #region Enum

	read_entry :: proc(p: ^Protocol, element: xml.Element_ID) -> (e: ^Entry) {
		e, _ = virtual.new(&p.arena, Entry)

		e.description      = read_description(p, element)
		e.name             = read_name(p, element)
		e.value            = read_value(p, element)
		e.since            = read_since(p, element)
		e.deprecated_since = read_deprecated_since(p, element)
		e.summary          = read_summary(p, element)

		return
	}

	read_enum :: proc(p: ^Protocol, interface_name: string, element: xml.Element_ID) -> (e: ^Enum) {
		e, _ = virtual.new(&p.arena, Enum)

		e.name           = read_name(p, element)
		e.canonical_name = strings.concatenate({interface_name, ".", e.name}, allocator = p_allocator(p))
		e.description    = read_description(p, element)
		e.since          = read_since(p, element)
		e.bitfield       = (xml.find_attribute_val_by_key(p.d, element, "bitfield") or_else "") == "true"

		num_entries := 0
		for {
			entry_element_id := xml.find_child_by_ident(p.d, element, "entry", num_entries) or_break

			num_entries += 1

			entry := read_entry(p, entry_element_id)
			list.push_back(&e.entries, &entry.node)
		}

		p.enums[e.canonical_name] = e

		return
	}

	// #endregion

	// #region Message

	read_arg :: proc(p: ^Protocol, interface_name: string, element: xml.Element_ID) -> (a: ^Arg) {
		a, _ = virtual.new(&p.arena, Arg)

		a.description = read_description(p, element)
		a.name = read_name(p, element)
		a.summary = read_summary(p, element)

		type, type_found := xml.find_attribute_val_by_key(p.d, element, "type")
		if !type_found {
			fmt.eprintfln("%s: argument %s is missing type", p.file, a.name)
			os.exit(1)
		}

		switch type {
		case "int":    a.type.kind = .Int
		case "uint":   a.type.kind = .Uint
		case "fixed":  a.type.kind = .Fixed
		case "string": a.type.kind = .String
		case "object": a.type.kind = .Object
		case "new_id": a.type.kind = .New_Id
		case "array":  a.type.kind = .Array
		case "fd":     a.type.kind = .Fd
		case:
			fmt.eprintfln("%s: arg %s: unknown type %s", p.file, a.name, type)
			os.exit(1)
		}

		enum_ := xml.find_attribute_val_by_key(p.d, element, "enum") or_else ""
		interface := xml.find_attribute_val_by_key(p.d, element, "interface") or_else ""

		a.type.nullable  = (xml.find_attribute_val_by_key(p.d, element, "allow-null") or_else "") == "true"

		if enum_ != "" {
			if strings.index(enum_, ".") == -1 {
				enum_ = strings.concatenate({ interface_name, ".", enum_ }, allocator = p_allocator(p))
			}
			a.type.is_enum = true
		}

		a.type.reference = enum_ if enum_ != "" else interface

		return
	}

	read_message :: proc(p: ^Protocol, interface_name: string, element: xml.Element_ID) -> (m: ^Message) {
		m, _ = virtual.new(&p.arena, Message)

		m.description      = read_description(p, element)
		m.name             = read_name(p, element)
		m.canonical_name   = strings.concatenate({ interface_name, ".", m.name }, allocator = p_allocator(p))
		m.destructor       = read_destructor(p, element)
		m.since            = read_since(p, element)
		m.deprecated_since = read_deprecated_since(p, element)

		num_args := 0
		for {
			arg_element_id := xml.find_child_by_ident(p.d, element, "arg", num_args) or_break

			num_args += 1

			arg := read_arg(p, interface_name, arg_element_id)
			list.push_back(&m.args, &arg.node)
		}

		return
	}

	// #endregion

	// #region Interface

	read_interface :: proc(p: ^Protocol, element: xml.Element_ID) -> (i: ^Interface) {
		i, _ = virtual.new(&p.arena, Interface)

		i.description = read_description(p, element)
		i.name        = read_name(p, element)
		i.version     = read_version(p, element)

		num_enums := 0
		for {
			enum_element_id := xml.find_child_by_ident(p.d, element, "enum", num_enums) or_break

			num_enums += 1

			enum_ := read_enum(p, i.name, enum_element_id)
			enum_.interface = i
			list.push_back(&i.enums, &enum_.node)
		}

		num_requests := 0
		for {
			request_element_id := xml.find_child_by_ident(p.d, element, "request", num_requests) or_break

			num_requests += 1

			request := read_message(p, i.name, request_element_id)
			request.interface = i
			list.push_back(&i.requests, &request.node)
		}

		num_events := 0
		for {
			event_element_id := xml.find_child_by_ident(p.d, element, "event", num_events) or_break

			num_events += 1

			event := read_message(p, i.name, event_element_id)
			event.interface = i
			list.push_back(&i.events, &event.node)
		}

		return
	}

	// #endregion

	// #region Parse Protocol File

	file_content_bytes, err := os.read_entire_file(file, p_allocator(p))
	if err != os.General_Error.None {
		fmt.eprintfln("%s: cannot read XML: %s", file, os.error_string(err)); os.exit(1)
	}
	p.file_content         = string(file_content_bytes)
	p.file                 = strings.clone(file, p_allocator(p))

	xml_err: xml.Error
	p.d, xml_err = xml.parse_string(p.file_content, path = file, allocator = p_allocator(p))
	if xml_err != nil {
		fmt.eprintfln("%s: invalid XML: %v", file, xml_err)
		os.exit(1)
	}

	// #endregion

	p.enums      = make(map[string]^Enum, allocator = p_allocator(p))
	p.interfaces = make(map[string]^Interface, allocator = p_allocator(p))

	element := p.d.elements[0]
	if element.ident != "protocol" {
		fmt.eprintfln("%s: root element is %s, expected protocol", file, element.ident)
		os.exit(1)
	}
	ok: bool
	p.name = read_name(p, 0)

	p.description = read_description(p, 0)
	copyright_element, copyright_found := xml.find_child_by_ident(p.d, 0, "copyright")
	if copyright_found {
		p.copyright = read_string_body(p, copyright_element)
	}

	num_interfaces := 0
	for {
		interface_element_id := xml.find_child_by_ident(p.d, 0, "interface", num_interfaces) or_break

		num_interfaces += 1

		interface          := read_interface(p, interface_element_id)
		interface.protocol  = p
		p.interfaces[interface.name] = interface
		list.push_back(&p.interface_order, &interface.node)
	}

	return
}

// #endregion

Protocols :: struct {
	bindings_directory: string,
	protocols: map[string]^Protocol,
	interfaces: map[string]^Interface,
	enums:      map[string]^Enum,
}

Protocol_Config :: struct {
	prefix: string,
	pkg: string `json:"package"`,
	directory: string,
	filename: string,
}

Scanner_Config :: struct {
	bindings: string,
	protocols: map[string]Protocol_Config,
}

keyword_lut: tokenizer.Keyword_LUT

odin_identifier :: proc(name: string, allocator := context.allocator) -> string {
	result := name
	if len(result) > 0 && result[0] >= '0' && result[0] <= '9' {
		result = strings.concatenate({"_", result}, allocator = allocator)
	}
	if 1 < len(result) && len(result) < 16 {
		entry := &keyword_lut[tokenizer.keyword_hash(result) & tokenizer.KEYWORD_LUT_MASK]
		if entry.kind != .Invalid && entry.name == result {
			result = strings.concatenate({result, "_"}, allocator = allocator)
		}
	}
	return result
}

same_output_group :: proc(a, b: ^Protocol) -> bool {
	return a.output_directory == b.output_directory && a.package_name == b.package_name
}

interface_public_name :: proc(i: ^Interface, allocator := context.allocator) -> string {
	return odin_identifier(strings.trim_prefix(i.name, i.protocol.prefix), allocator)
}

enum_base_name :: proc(e: ^Enum, allocator := context.allocator) -> string {
	return strings.concatenate(
		{interface_public_name(e.interface, allocator), "_", odin_identifier(e.name, allocator)},
		allocator = allocator,
	)
}

enum_variant_name :: proc(e: ^Enum, flag: Enum_Size_Info_Flag, allocator := context.allocator) -> string {
	name := enum_base_name(e, allocator)
	if .I32 in e.size_info && .U32 in e.size_info {
		suffix := "_i32" if flag == .I32 else "_u32"
		name = strings.concatenate({name, suffix}, allocator = allocator)
	}
	return name
}

entry_public_name :: proc(entry: ^Entry, allocator := context.allocator) -> string {
	return odin_identifier(entry.name, allocator)
}

interface_descriptor_name :: proc(i: ^Interface, allocator := context.allocator) -> string {
	return strings.concatenate({interface_public_name(i, allocator), "_interface"}, allocator = allocator)
}

request_public_name :: proc(ps: ^Protocols, r: ^Message, allocator := context.allocator) -> string {
	name := strings.concatenate(
		{interface_public_name(r.interface, allocator), "_", odin_identifier(r.name, allocator)},
		allocator = allocator,
	)
	for _, p in ps.protocols {
		if !same_output_group(p, r.interface.protocol) { continue }
		for it := list.iterator_head(p.interface_order, Interface, "node"); i in list.iterate_next(&it) {
			if name == interface_public_name(i, allocator) {
				return strings.concatenate(
					{interface_public_name(r.interface, allocator), "_get_", odin_identifier(r.name, allocator)},
					allocator = allocator,
				)
			}
			for eit := list.iterator_head(i.enums, Enum, "node"); e in list.iterate_next(&eit) {
				for flag in e.size_info {
					if name == enum_variant_name(e, flag, allocator) {
						return strings.concatenate(
							{interface_public_name(r.interface, allocator), "_get_", odin_identifier(r.name, allocator)},
							allocator = allocator,
						)
					}
				}
			}
		}
	}
	return name
}

resolve_protocols :: proc(ps: ^Protocols) {
	resolve_message :: proc(ps: ^Protocols, m: ^Message) {
		for it := list.iterator_head(m.args, Arg, "node"); a in list.iterate_next(&it) {
			if a.type.is_enum {
				e, found := ps.enums[a.type.reference]
				if !found {
					fmt.eprintfln(
						"%s: protocol %s, interface %s, message %s, argument %s: unknown enum %s",
						m.interface.protocol.file,
						m.interface.protocol.name,
						m.interface.name,
						m.name,
						a.name,
						a.type.reference,
					)
					os.exit(1)
				}
				#partial switch a.type.kind {
				case .Int:
					e.size_info += {.I32}
				case .Uint:
					e.size_info += {.U32}
				case:
					fmt.eprintfln(
						"%s: protocol %s, interface %s, message %s, argument %s: enum %s uses unsupported carrier",
						m.interface.protocol.file,
						m.interface.protocol.name,
						m.interface.name,
						m.name,
						a.name,
						a.type.reference,
					)
					os.exit(1)
				}
			} else if a.type.reference != "" && (a.type.kind == .Object || a.type.kind == .New_Id) {
				if _, found := ps.interfaces[a.type.reference]; !found {
					fmt.eprintfln(
						"%s: protocol %s, interface %s, message %s, argument %s: unknown interface %s",
						m.interface.protocol.file,
						m.interface.protocol.name,
						m.interface.name,
						m.name,
						a.name,
						a.type.reference,
					)
					os.exit(1)
				}
			}
		}
	}

	for _, p in ps.protocols {
		for it := list.iterator_head(p.interface_order, Interface, "node"); i in list.iterate_next(&it) {
			for mit := list.iterator_head(i.requests, Message, "node"); m in list.iterate_next(&mit) {
				resolve_message(ps, m)
			}
			for mit := list.iterator_head(i.events, Message, "node"); m in list.iterate_next(&mit) {
				resolve_message(ps, m)
			}
		}
	}
	for _, e in ps.enums {
		if card(e.size_info) == 0 {
			e.size_info = {.U32}
		}
		for flag in e.size_info {
			e.postfix_names[flag] = enum_variant_name(e, flag, p_allocator(e.interface.protocol))
		}
	}
}

// #region Write Protocol

write_protocol :: proc(ps: ^Protocols, p: ^Protocol, w: io.Writer) {
	prefix := p.prefix

	Context :: struct {
		prefix: string,
		p:      ^Protocol,
		ps:     ^Protocols,
		w:      io.Writer,
	}

	c := Context {
		prefix,
		p,
		ps,
		w,
	}

	c_write_string :: proc(c: Context, s: string) {
		io.write_string(c.w, s)
	}

	c_write_strings :: proc(c: Context, strs: ..string) {
		for str in strs {
			c_write_string(c, str)
		}
	}

	c_write_int :: proc(c: Context, i: int) {
		io.write_int(c.w, i)
	}

	runtime_name :: proc(c: Context, name: string, allocator: runtime.Allocator) -> string {
		if c.p.output_directory == c.ps.bindings_directory {
			return name
		}
		return strings.concatenate({"wl.", name}, allocator = allocator)
	}

	c_strip_prefix :: proc(c: Context, s: string) -> string {
		return strings.trim_prefix(s, c.prefix)
	}

	c_canonical_to_global :: proc(c: Context, s: string, allocator: runtime.Allocator) -> string {
		stripped := c_strip_prefix(c, s)
		replaced, _ := strings.replace_all(stripped, ".", "_", allocator)
		return replaced
	}

	Comment :: struct {
		description: Description,
		since:       int,
		version:     int,
	}

	c_write_comment :: proc(c: Context, co: Comment, depth: int = 0) {
		pad :: proc(c: Context, depth: int) {
			for i in 0..<depth {
				io.write_rune(c.w, '\t')
			}
		}

		d := co.description

		if d.summary == "" && d.content == "" && co.since == 0 && co.version == 0 {
			return
		}

		pad(c, depth); c_write_string(c, "/*\n")
		if d.summary != "" {
			pad(c, depth); c_write_string(c, "Summary: "); c_write_string(c, d.summary); c_write_string(c, "\n\n")
		}
		if d.content != "" {
			content := d.content
			for line in strings.split_lines_iterator(&content) {
				pad(c, depth); c_write_string(c, line); c_write_string(c, "\n")
			}
		}
		if co.since != 0 {
			pad(c, depth); c_write_string(c, "Since: "); c_write_int(c, co.since); c_write_string(c, "\n")
		}
		if co.version != 0 {
			pad(c, depth); c_write_string(c, "Version: "); c_write_int(c, co.version); c_write_string(c, "\n")
		}
		pad(c, depth); c_write_string(c, "*/\n")
	}

	c_write_comma_sep :: proc(c: Context, strs: []string, first_placed: ^bool) {
		if first_placed^ == true {
			c_write_string(c, ", ")
		} else {
			first_placed^ = true
		}

		for str in strs {
			c_write_string(c, str)
		}
	}

	// #region Write Enum

	write_enum :: proc(c: Context, e: ^Enum) {
		size_info := e.size_info

		@static
		LUT := [Enum_Size_Info_Flag]string{
			.I32 = "i32",
			.U32 = "u32",
		}

		comment := Comment {
			since       = e.since,
			description = e.description,
		}
		for flag in size_info {
			if !e.bitfield {
				c_write_comment(
					c,
					comment,
				)
			}
			c_write_string(c, e.postfix_names[flag])
			if e.bitfield {
				c_write_string(c, "_flag")
			}
			c_write_string(c, " :: enum ")
			c_write_string(c, LUT[flag])
			c_write_string(c, " {\n")

			for it := list.iterator_head(e.entries, Entry, "node"); entry in list.iterate_next(&it) {
				c_write_comment(
					c,
					Comment {
						description = entry.description,
						since       = entry.since,
					},
					1,
				)

				is_bit_position := entry.value > 0 && (entry.value & (entry.value-1)) == 0
				if e.bitfield && !is_bit_position {
					c_write_string(c, "\t/* ")
				} else {
					c_write_string(c, "\t")
				}

				c_write_string(c, entry_public_name(entry, p_allocator(c.p)))
				c_write_string(c, " = ")
				if e.bitfield && is_bit_position {
					c_write_string(c, "intrinsics.constant_log2(")
				}
				c_write_int(c, entry.value)
				if e.bitfield && is_bit_position {
					c_write_string(c, ")")
				}

				c_write_string(c, ",")
				if entry.summary != "" {
					c_write_string(c, " // ")
					c_write_string(c, entry.summary)
				}

				if e.bitfield && !is_bit_position {
					c_write_string(c, " */\n")
				} else {
					c_write_string(c, "\n")
				}
			}

			c_write_string(c, "}\n\n")
		}

		if e.bitfield {
			for flag in size_info {
				c_write_comment(c, comment)
				c_write_string(c, e.postfix_names[flag])
				c_write_string(c, " :: bit_set[")
				c_write_string(c, e.postfix_names[flag])
				c_write_string(c, "_flag; ")
				c_write_string(c, LUT[flag])
				c_write_string(c, "]\n\n")
			}
		}
	}
	// #endregion

	qualified_interface_name :: proc(c: Context, i: ^Interface, allocator: runtime.Allocator) -> string {
		name := interface_public_name(i, allocator)
		if !same_output_group(i.protocol, c.p) {
			name = strings.concatenate({i.protocol.package_name, ".", name}, allocator = allocator)
		}
		return name
	}

	qualified_interface_descriptor :: proc(c: Context, i: ^Interface, allocator: runtime.Allocator) -> string {
		name := interface_descriptor_name(i, allocator)
		if !same_output_group(i.protocol, c.p) {
			name = strings.concatenate({i.protocol.package_name, ".", name}, allocator = allocator)
		}
		return name
	}

	qualified_enum_type :: proc(c: Context, e: ^Enum, flag: Enum_Size_Info_Flag, allocator: runtime.Allocator) -> string {
		name := enum_variant_name(e, flag, allocator)
		if !same_output_group(e.interface.protocol, c.p) {
			name = strings.concatenate({e.interface.protocol.package_name, ".", name}, allocator = allocator)
		}
		return name
	}

	type_get_object :: proc(c: Context, t: Type, allocator: runtime.Allocator) -> string {
		if t.reference == "" { return "rawptr" }
		i, ok := c.ps.interfaces[t.reference]
		if !ok {
			fmt.eprintfln("%s: unresolved interface %s during rendering", c.p.name, t.reference)
			os.exit(1)
		}
		return strings.concatenate({"^", qualified_interface_name(c, i, allocator)}, allocator = allocator)
	}

	type_get_odin_type :: proc(c: Context, t: Type, allocator: runtime.Allocator) -> string {
		switch t.kind {
		case .Int:
			if t.reference != "" {
				e, found := c.ps.enums[t.reference]
				if !found { fmt.eprintfln("%s: unresolved enum %s during rendering", c.p.name, t.reference); os.exit(1) }
				return qualified_enum_type(c, e, .I32, allocator)
			}
			return "i32"
		case .Uint:
			if t.reference != "" {
				e, found := c.ps.enums[t.reference]
				if !found { fmt.eprintfln("%s: unresolved enum %s during rendering", c.p.name, t.reference); os.exit(1) }
				return qualified_enum_type(c, e, .U32, allocator)
			}
			return "u32"
		case .Fixed:  return runtime_name(c, "fixed_t", allocator)
		case .String: return "cstring"
		case .Object: return type_get_object(c, t, allocator)
		case .New_Id:
			fmt.eprintfln("%s: internal error: new_id requested as an ordinary type", c.p.name)
			os.exit(1)
		case .Array:
			return strings.concatenate({"^", runtime_name(c, "array", allocator)}, allocator = allocator)
		case .Fd:     return "i32"
		}

		unreachable()
	}

	Message_Info_Kind :: enum {
		Normal,
		New_Id,
		New_Id_Unknown,
	}

	Message_Info :: struct {
		kind:      Message_Info_Kind,
		args:      [dynamic]string,

		// written var strings
		ret_name_var:  string,
		ret_type_var:  string,
		version_var:   string,
		interface_var: string,

		interface_name_var: string,

		ret_type: Type,
	}

	write_message_signature :: proc(c: Context, i: ^Interface, m: ^Message) -> (info: Message_Info) {
		info.args.allocator = context.temp_allocator

		unqualified_identifier :: proc(type_name: string) -> string {
			name := strings.trim_prefix(type_name, "^")
			if strings.index(name, ".") >= 0 { return "" }
			return name
		}

		shadows_later_type :: proc(c: Context, m: ^Message, current: ^Arg, name: string) -> bool {
			after_current := current == nil
			for it := list.iterator_head(m.args, Arg, "node"); a in list.iterate_next(&it) {
				if !after_current {
					if a == current { after_current = true }
					continue
				}
				if a == current { continue }
				type_name := ""
				if a.type.kind == .New_Id {
					if a.type.reference != "" {
						type_name = type_get_object(c, a.type, context.temp_allocator)
					}
				} else {
					type_name = type_get_odin_type(c, a.type, context.temp_allocator)
				}
				if name == unqualified_identifier(type_name) { return true }
			}
			for it := list.iterator_head(m.args, Arg, "node"); a in list.iterate_next(&it) {
				if a.type.kind == .New_Id && a.type.reference != "" {
					if name == unqualified_identifier(type_get_object(c, a.type, context.temp_allocator)) {
						return true
					}
				}
			}
			return false
		}

		get_name :: proc(c: Context, m: ^Message, current: ^Arg, raw_name: string) -> string {
			name := odin_identifier(raw_name, context.temp_allocator)
			if shadows_later_type(c, m, current, name) {
				return strings.concatenate({name, "_"}, allocator = context.temp_allocator)
			}
			return name
		}

		first_comma_placed: bool

		info.interface_name_var = get_name(c, m, nil, interface_public_name(i, context.temp_allocator))
		c_write_comma_sep(c, {info.interface_name_var, ": ^", interface_public_name(i, context.temp_allocator)}, &first_comma_placed)

		for it := list.iterator_head(m.args, Arg, "node"); a in list.iterate_next(&it) {
			name := get_name(c, m, a, a.name)

			if a.type.kind == .New_Id {
				// do other thing
				info.ret_name_var = name
				info.ret_type = a.type

				if a.type.reference == "" {
					info.kind = .New_Id_Unknown
					info.interface_var = odin_identifier("interface", context.temp_allocator)
					info.version_var = odin_identifier("version", context.temp_allocator)

					c_write_comma_sep(
						c,
						{
							info.interface_var,
							": ^",
							runtime_name(c, "interface", context.temp_allocator),
							", ",
							info.version_var,
							": u32",
						},
						&first_comma_placed,
					)

					append(&info.args, strings.concatenate({info.interface_var, ".name"}, allocator = context.temp_allocator))
					append(&info.args, info.version_var)
					append(&info.args, "nil")

					info.ret_type_var = strings.concatenate(
						{"^", runtime_name(c, "proxy", context.temp_allocator)},
						allocator = context.temp_allocator,
					)
				} else {
					info.kind = .New_Id
					append(&info.args, "nil") // new_id turns into a nil argument

					info.ret_type_var = type_get_object(c, a.type, context.temp_allocator)
				}
			} else {
				append(&info.args, name)
				c_write_comma_sep(
					c,
					{
						name,
						": ",
						type_get_odin_type(c, a.type, context.temp_allocator),
					},
					&first_comma_placed,
				)
			}
		}

		c_write_string(c, ")")
		if info.ret_type_var != "" {
			c_write_strings(c, " -> (", info.ret_name_var, ": ", info.ret_type_var, ")")
		}

		return
	}

	write_request :: proc(c: Context, i: ^Interface, r: ^Message, opcode: int) {
		public_name := request_public_name(c.ps, r, context.temp_allocator)
		opcode_string := strings.to_upper_snake_case(public_name, context.temp_allocator)
		c_write_strings(c, opcode_string, " :: ")
		c_write_int(c, opcode)
		c_write_string(c, "\n")

		c_write_comment(
			c,
			{
				description = r.description,
				since = r.since,
			},
		)

		if r.deprecated_since != 0 {
			c_write_string(c, "@(deprecated = \"deprecated since ")
			c_write_int(c, r.deprecated_since)
			c_write_string(c, "\")\n")
		}

		c_write_string(c, public_name)
		c_write_string(c, " :: proc \"contextless\" (")

		info := write_message_signature(c, i, r)

		c_write_string(c, " {\n\t")
		if info.kind != .Normal {
			c_write_string(c, info.ret_name_var)
			c_write_string(c, " = cast(")
			c_write_string(c, info.ret_type_var)
			c_write_string(c, ")")
		}

		c_write_strings(
			c,
			runtime_name(c, "proxy_marshal_flags", context.temp_allocator),
			"(cast(^",
			runtime_name(c, "proxy", context.temp_allocator),
			")",
			info.interface_name_var,
			", ",
			opcode_string,
			", ",
		)

		switch info.kind {
		case .Normal:
			c_write_string(c, "nil")
		case .New_Id:
			i, ok := c.ps.interfaces[info.ret_type.reference]
			if !ok { fmt.eprintfln("%s: unresolved constructor interface %s", c.p.name, info.ret_type.reference); os.exit(1) }
			c_write_string(c, "&")
			c_write_string(c, qualified_interface_descriptor(c, i, context.temp_allocator))
		case .New_Id_Unknown:
			c_write_string(c, info.interface_var)
		}

		c_write_string(c, ", ")

		if info.kind == .New_Id_Unknown {
			c_write_string(c, info.version_var)
		} else {
			c_write_strings(
				c,
				runtime_name(c, "proxy_get_version", context.temp_allocator),
				"(cast(^",
				runtime_name(c, "proxy", context.temp_allocator),
				")",
				info.interface_name_var,
				")",
			)
		}

		c_write_string(c, ", ")

		if r.destructor {
			c_write_string(c, "1 /* DESTROY */")
		} else {
			c_write_string(c, "0")
		}

		first_comma_placed := true

		for arg in info.args {
			c_write_comma_sep(c, {arg}, &first_comma_placed)
		}
		c_write_string(c, ")\n\treturn\n}\n\n")
	}

	write_user_data_helpers :: proc(c: Context, i: ^Interface) {
		name := interface_public_name(i, context.temp_allocator)
		proxy := runtime_name(c, "proxy", context.temp_allocator)
		c_write_strings(c, name, "_set_user_data :: proc \"contextless\" (", name, ": ^", name, ", user_data: rawptr) {\n")
		c_write_strings(c, "\t", runtime_name(c, "proxy_set_user_data", context.temp_allocator), "(cast(^", proxy, ")", name, ", user_data)\n}\n\n")
		c_write_strings(c, name, "_get_user_data :: proc \"contextless\" (", name, ": ^", name, ") -> rawptr {\n")
		c_write_strings(c, "\treturn ", runtime_name(c, "proxy_get_user_data", context.temp_allocator), "(cast(^", proxy, ")", name, ")\n}\n\n")
	}

	message_count :: proc(messages: list.List) -> int {
		count := 0
		for it := list.iterator_head(messages, Message, "node"); _ in list.iterate_next(&it) {
			count += 1
		}
		return count
	}

	write_listener :: proc(c: Context, i: ^Interface) {
		if message_count(i.events) == 0 { return }
		name := interface_public_name(i, context.temp_allocator)
		c_write_strings(c, name, "_listener :: struct {\n")
		for it := list.iterator_head(i.events, Message, "node"); event in list.iterate_next(&it) {
			c_write_comment(c, {description = event.description, since = event.since}, 1)
			receiver_name := name
			for ait := list.iterator_head(event.args, Arg, "node"); a in list.iterate_next(&ait) {
				type_name := type_get_object(c, a.type, context.temp_allocator) if a.type.kind == .New_Id && a.type.reference != "" else
					type_get_odin_type(c, a.type, context.temp_allocator) if a.type.kind != .New_Id else
					strings.concatenate({"^", runtime_name(c, "proxy", context.temp_allocator)}, allocator = context.temp_allocator)
				if strings.index(type_name, ".") < 0 && strings.trim_prefix(type_name, "^") == receiver_name {
					receiver_name = strings.concatenate({receiver_name, "_"}, allocator = context.temp_allocator)
					break
				}
			}
			c_write_strings(c, "\t", odin_identifier(event.name, context.temp_allocator), ": proc \"c\" (data: rawptr, ", receiver_name, ": ^", name)
			for ait := list.iterator_head(event.args, Arg, "node"); a in list.iterate_next(&ait) {
				c_write_strings(c, ", ", odin_identifier(a.name, context.temp_allocator), ": ")
				if a.type.kind == .New_Id {
					if a.type.reference == "" {
						c_write_strings(c, "^", runtime_name(c, "proxy", context.temp_allocator))
					} else {
						c_write_string(c, type_get_object(c, a.type, context.temp_allocator))
					}
				} else {
					c_write_string(c, type_get_odin_type(c, a.type, context.temp_allocator))
				}
			}
			c_write_string(c, "),\n")
		}
		c_write_string(c, "}\n\n")
		c_write_strings(c, name, "_add_listener :: proc \"contextless\" (", name, ": ^", name, ", listener: ^", name, "_listener, data: rawptr) {\n")
		c_write_strings(
			c,
			"\t",
			runtime_name(c, "proxy_add_listener", context.temp_allocator),
			"(cast(^",
			runtime_name(c, "proxy", context.temp_allocator),
			")",
			name,
			", cast(^",
			runtime_name(c, "generic_c_call", context.temp_allocator),
			")listener, data)\n}\n\n",
		)
	}

	write_interface :: proc(c: Context, i: ^Interface) {
		c_write_comment(
			c,
			{
				description = i.description,
				version     = i.version,
			},
		)
		c_write_string(c, interface_public_name(i, context.temp_allocator))
		c_write_strings(c, " :: distinct ", runtime_name(c, "proxy", context.temp_allocator), "\n\n")
		c_write_string(c, interface_descriptor_name(i, context.temp_allocator))
		c_write_strings(c, " : ", runtime_name(c, "interface", context.temp_allocator), "\n\n")

		for it := list.iterator_head(i.enums, Enum, "node"); e in list.iterate_next(&it) {
			write_enum(c, e)
		}
		write_user_data_helpers(c, i)
		has_destroy := false
		opcode := 0
		for it := list.iterator_head(i.requests, Message, "node"); r in list.iterate_next(&it) {
			write_request(c, i, r, opcode)
			if r.name == "destroy" { has_destroy = true }
			opcode += 1
		}
		name := interface_public_name(i, context.temp_allocator)
		if !has_destroy && name != "display" {
			c_write_strings(c, name, "_destroy :: proc \"contextless\" (", name, ": ^", name, ") {\n")
			c_write_strings(c, "\t", runtime_name(c, "proxy_destroy", context.temp_allocator), "(cast(^", runtime_name(c, "proxy", context.temp_allocator), ")", name, ")\n}\n\n")
		}
		write_listener(c, i)
	}

	message_signature :: proc(m: ^Message, allocator: runtime.Allocator) -> string {
		b: strings.Builder
		strings.builder_init(&b, allocator)
		if m.since != 0 { fmt.sbprint(&b, m.since) }
		for it := list.iterator_head(m.args, Arg, "node"); a in list.iterate_next(&it) {
			if a.type.nullable && (a.type.kind == .String || a.type.kind == .Object) {
				strings.write_rune(&b, '?')
			}
			if a.type.kind == .New_Id && a.type.reference == "" {
				strings.write_string(&b, "su")
			}
			switch a.type.kind {
			case .Int:    strings.write_rune(&b, 'i')
			case .Uint:   strings.write_rune(&b, 'u')
			case .Fixed:  strings.write_rune(&b, 'f')
			case .String: strings.write_rune(&b, 's')
			case .Object: strings.write_rune(&b, 'o')
			case .New_Id: strings.write_rune(&b, 'n')
			case .Array:  strings.write_rune(&b, 'a')
			case .Fd:     strings.write_rune(&b, 'h')
			}
		}
		return strings.to_string(b)
	}

	Type_Metadata :: struct {
		values:  [dynamic]string,
		offsets: map[^Message]int,
	}

	build_type_metadata :: proc(c: Context) -> Type_Metadata {
		md: Type_Metadata
		md.values.allocator = context.temp_allocator
		md.offsets = make(map[^Message]int, allocator = context.temp_allocator)
		max_null_run := 0
		scan_max :: proc(messages: list.List, max_null_run: ^int) {
			for it := list.iterator_head(messages, Message, "node"); m in list.iterate_next(&it) {
				count := 0
				all_null := true
				for ait := list.iterator_head(m.args, Arg, "node"); a in list.iterate_next(&ait) {
					count += 1
					if a.type.reference != "" && (a.type.kind == .Object || a.type.kind == .New_Id) {
						all_null = false
					}
				}
				if all_null && count > max_null_run^ { max_null_run^ = count }
			}
		}
		for it := list.iterator_head(c.p.interface_order, Interface, "node"); i in list.iterate_next(&it) {
			scan_max(i.requests, &max_null_run)
			scan_max(i.events, &max_null_run)
		}
		if max_null_run == 0 { max_null_run = 1 }
		for _ in 0..<max_null_run { append(&md.values, "nil") }

		add_messages :: proc(c: Context, messages: list.List, md: ^Type_Metadata, max_null_run: int) {
			for it := list.iterator_head(messages, Message, "node"); m in list.iterate_next(&it) {
				all_null := true
				for ait := list.iterator_head(m.args, Arg, "node"); a in list.iterate_next(&ait) {
					if a.type.reference != "" && (a.type.kind == .Object || a.type.kind == .New_Id) {
						all_null = false
						break
					}
				}
				if all_null {
					md.offsets[m] = 0
					continue
				}
				md.offsets[m] = len(md.values)
				for ait := list.iterator_head(m.args, Arg, "node"); a in list.iterate_next(&ait) {
					if a.type.reference != "" && (a.type.kind == .Object || a.type.kind == .New_Id) {
						referenced, ok := c.ps.interfaces[a.type.reference]
						if !ok {
							fmt.eprintfln("%s: interface %s, message %s: unresolved metadata interface %s", c.p.file, m.interface.name, m.name, a.type.reference)
							os.exit(1)
						}
						append(&md.values, strings.concatenate({"&", qualified_interface_descriptor(c, referenced, context.temp_allocator)}, allocator = context.temp_allocator))
					} else {
						append(&md.values, "nil")
					}
				}
			}
		}
		for it := list.iterator_head(c.p.interface_order, Interface, "node"); i in list.iterate_next(&it) {
			add_messages(c, i.requests, &md, max_null_run)
			add_messages(c, i.events, &md, max_null_run)
		}
		return md
	}

	write_message_array :: proc(c: Context, i: ^Interface, messages: list.List, suffix: string, md: Type_Metadata) {
		if message_count(messages) == 0 { return }
		name := interface_public_name(i, context.temp_allocator)
		c_write_string(c, "@(private)\n")
		c_write_strings(c, name, suffix, " := []", runtime_name(c, "message", context.temp_allocator), " {\n")
		for it := list.iterator_head(messages, Message, "node"); m in list.iterate_next(&it) {
			c_write_strings(c, "\t{\"", m.name, "\", \"", message_signature(m, context.temp_allocator), "\", raw_data(", c.p.name, "_types)[")
			c_write_int(c, md.offsets[m])
			c_write_string(c, ":]},\n")
		}
		c_write_string(c, "}\n\n")
	}

	write_interface_init :: proc(c: Context) {
		init_name := odin_identifier(strings.replace_all(c.p.name, "-", "_", context.temp_allocator) or_else c.p.name, context.temp_allocator)
		c_write_string(c, "@(private)\n@(init)\n")
		c_write_strings(c, "init_interfaces_", init_name, " :: proc \"contextless\" () {\n")
		for it := list.iterator_head(c.p.interface_order, Interface, "node"); i in list.iterate_next(&it) {
			name := interface_descriptor_name(i, context.temp_allocator)
			c_write_strings(c, "\t", name, ".name = \"", i.name, "\"\n")
			c_write_strings(c, "\t", name, ".version = "); c_write_int(c, i.version); c_write_string(c, "\n")
			request_count := message_count(i.requests)
			event_count := message_count(i.events)
			c_write_strings(c, "\t", name, ".method_count = "); c_write_int(c, request_count); c_write_string(c, "\n")
			c_write_strings(c, "\t", name, ".event_count = "); c_write_int(c, event_count); c_write_string(c, "\n")
			public := interface_public_name(i, context.temp_allocator)
			if request_count > 0 { c_write_strings(c, "\t", name, ".methods = raw_data(", public, "_requests)\n") }
			if event_count > 0 { c_write_strings(c, "\t", name, ".events = raw_data(", public, "_events)\n") }
		}
		c_write_string(c, "}\n")
	}

	c_write_strings(c, "#+build linux\npackage ", c.p.package_name, "\n\n")
	c_write_string(c, "@require import \"base:intrinsics\"\n")

	runtime_path, runtime_path_err := filepath.rel(c.p.output_directory, c.ps.bindings_directory, context.temp_allocator)
	if runtime_path_err != .None {
		fmt.eprintfln("%s: cannot compute binding import from %s to %s", c.p.name, c.p.output_directory, c.ps.bindings_directory)
		os.exit(1)
	}
	if c.p.output_directory != c.ps.bindings_directory {
		c_write_strings(c, "@require import wl \"", runtime_path, "\"\n")
	}

	imported_packages := make(map[string]bool, allocator = context.temp_allocator)
	add_protocol_import :: proc(c: Context, owner: ^Protocol, imported_packages: ^map[string]bool) {
		if same_output_group(owner, c.p) || imported_packages^[owner.package_name] { return }
		path, err := filepath.rel(c.p.output_directory, owner.output_directory, context.temp_allocator)
		if err != .None {
			fmt.eprintfln("%s: cannot compute protocol import from %s to %s", c.p.name, c.p.output_directory, owner.output_directory)
			os.exit(1)
		}
		c_write_strings(c, "@require import ", owner.package_name, " \"", path, "\"\n")
		imported_packages^[owner.package_name] = true
	}
	for it := list.iterator_head(c.p.interface_order, Interface, "node"); i in list.iterate_next(&it) {
		scan_messages :: proc(c: Context, messages: list.List, imported_packages: ^map[string]bool) {
			for mit := list.iterator_head(messages, Message, "node"); m in list.iterate_next(&mit) {
				for ait := list.iterator_head(m.args, Arg, "node"); a in list.iterate_next(&ait) {
					if a.type.is_enum {
						if e, ok := c.ps.enums[a.type.reference]; ok {
							add_protocol_import(c, e.interface.protocol, imported_packages)
						}
					} else if a.type.reference != "" && (a.type.kind == .Object || a.type.kind == .New_Id) {
						if referenced, ok := c.ps.interfaces[a.type.reference]; ok {
							add_protocol_import(c, referenced.protocol, imported_packages)
						}
					}
				}
			}
		}
		scan_messages(c, i.requests, &imported_packages)
		scan_messages(c, i.events, &imported_packages)
	}
	c_write_string(c, "\n")

	c_write_string(c, "/*\nGenerated with love by robaertschi/root/wayland/scanner/v2\n\nCopyright:\n")
	c_write_string(c, p.copyright)
	c_write_string(c, "*/\n\n")
	c_write_comment(c, { description = p.description })
	c_write_string(c, "\n")

	md := build_type_metadata(c)
	c_write_string(c, "@(private)\n")
	c_write_strings(c, c.p.name, "_types := []^", runtime_name(c, "interface", context.temp_allocator), " {\n")
	for value in md.values { c_write_strings(c, "\t", value, ",\n") }
	c_write_string(c, "}\n\n")

	for it := list.iterator_head(p.interface_order, Interface, "node"); i in list.iterate_next(&it) {
		write_interface(c, i)
	}
	for it := list.iterator_head(p.interface_order, Interface, "node"); i in list.iterate_next(&it) {
		write_message_array(c, i, i.requests, "_requests", md)
		write_message_array(c, i, i.events, "_events", md)
	}
	write_interface_init(c)
}

// #endregion

main :: proc() {
	tokenizer.keyword_lut_init(&keyword_lut)

	options := struct { input: string, config: string }{}
	flags.parse_or_exit(&options, os.args, .Odin)
	if options.input == "" || options.config == "" {
		fmt.eprintln("usage: wayland-scanner-v2 -input:<directory> -config:<file>"); os.exit(1)
	}
	config_path := filepath.abs(options.config, context.temp_allocator) or_else options.config
	config_bytes, config_err := os.read_entire_file(config_path, context.temp_allocator)
	if config_err != os.General_Error.None { fmt.eprintfln("%s: %s", options.config, os.error_string(config_err)); os.exit(1) }
	config: Scanner_Config
	if json_err := json.unmarshal(config_bytes, &config); json_err != nil {
		fmt.eprintfln("%s: invalid JSON: %v", options.config, json_err); os.exit(1)
	}
	if config.protocols == nil { fmt.eprintfln("%s: missing protocols", options.config); os.exit(1) }

	input_dir := filepath.abs(options.input, context.temp_allocator) or_else options.input
	if filepath.ext(input_dir) == ".xml" {
		input_dir = filepath.dir(input_dir)
	}
	dir, open_err := os.open(input_dir)
	if open_err != os.General_Error.None { fmt.eprintfln("%s: cannot open input directory", input_dir); os.exit(1) }
	defer os.close(dir)
	files, dir_err := os.read_directory(dir, 0, context.temp_allocator)
	if dir_err != os.General_Error.None { fmt.eprintfln("%s: %s", input_dir, os.error_string(dir_err)); os.exit(1) }

	ps: Protocols
	config_dir := filepath.dir(config_path)
	ps.bindings_directory = filepath.abs(
		filepath.join({config_dir, config.bindings}) or_else config.bindings,
		context.temp_allocator,
	) or_else config.bindings
	ps.protocols = make(map[string]^Protocol)
	ps.interfaces = make(map[string]^Interface)
	ps.enums = make(map[string]^Enum)
	for fi in files {
		if !strings.has_suffix(fi.name, ".xml") { continue }
		path := filepath.join({input_dir, fi.name}) or_else fi.fullpath
		p := read_protocol(path)
		cfg, found := config.protocols[p.name]
		if !found { fmt.eprintfln("%s: protocol %s has no configuration entry", path, p.name); os.exit(1) }
		if cfg.prefix == "" || cfg.pkg == "" || cfg.directory == "" { fmt.eprintfln("%s: protocol %s has incomplete configuration", options.config, p.name); os.exit(1) }
		for name in p.interfaces {
			if !strings.has_prefix(name, cfg.prefix) { fmt.eprintfln("%s: interface %s does not use prefix %s", path, name, cfg.prefix); os.exit(1) }
		}
		output_directory := filepath.join({config_dir, cfg.directory}) or_else cfg.directory
		output_directory = filepath.abs(output_directory, context.temp_allocator) or_else output_directory
		output_filename := cfg.filename
		if output_filename == "" {
			output_filename = strings.concatenate(
				{strings.trim_suffix(filepath.base(p.file), ".xml"), ".odin"},
				allocator = context.temp_allocator,
			)
		}
		output_path := filepath.join({output_directory, output_filename}) or_else output_filename
		p.prefix = cfg.prefix
		p.package_name = cfg.pkg
		p.output_directory = output_directory
		p.output_filename = output_filename
		p.output_path = output_path
		ps.protocols[p.name] = p
		for k, v in p.interfaces { ps.interfaces[k] = v }
		for k, v in p.enums { ps.enums[k] = v }
	}
	if len(ps.protocols) == 0 { fmt.eprintfln("%s: no XML protocols found", input_dir); os.exit(1) }

	resolve_protocols(&ps)

	rendered := make(map[string]string)
	for _, p in ps.protocols {
		builder: strings.Builder
		if _, err := strings.builder_init(&builder, context.allocator); err != nil {
			fmt.eprintfln("%s: cannot allocate render buffer: %v", p.name, err)
			os.exit(1)
		}
		write_protocol(&ps, p, strings.to_stream(&builder))
		rendered[p.name] = strings.to_string(builder)
	}

	for name, p in ps.protocols {
		if err := os.make_directory_all(p.output_directory); err != os.General_Error.None && !os.is_directory(p.output_directory) {
			fmt.eprintfln("%s: %s", p.output_directory, os.error_string(err)); os.exit(1)
		}
		if out_err := os.write_entire_file(p.output_path, transmute([]u8)rendered[name]); out_err != os.General_Error.None {
			fmt.eprintfln("%s: %s", p.output_path, os.error_string(out_err))
			os.exit(1)
		}
		fmt.printfln("wrote %s", p.output_path)
	}
}
