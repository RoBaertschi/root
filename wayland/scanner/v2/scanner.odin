package wayland_scanner_v2

import "core:io"
import "core:container/intrusive/list"
import "core:strconv"
import "core:fmt"
import "core:encoding/xml"
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

	name:        string,
	copyright:   string, // child tag
	description: Description,

	enums:          map[string]^Enum,
	enum_size_info: map[string]Enum_Size_Info_Flags,

	interfaces: map[string]^Interface,
}

Interface :: struct {
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

	canonical_name: string,

	name:        string,
	since:       int,
	bitfield:    bool,
	description: Description,

	entries: list.List,

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
			fmt.panicf("no %v name", element_name(p, element))
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
				fmt.panicf("missing %s for %v", field, element_name(p, element))
			} else {
				return
			}
		}

		value, ok = strconv.parse_int(version_string)
		if !ok {
			fmt.panicf("invalid %s number for %v", field, element_name(p, element))
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
		return read_number(p, element, "deprecated_since", false)
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
			fmt.panicf("missing type on arg")
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
		}

		enum_ := xml.find_attribute_val_by_key(p.d, element, "enum") or_else ""
		interface := xml.find_attribute_val_by_key(p.d, element, "interface") or_else ""

		a.type.nullable  = (xml.find_attribute_val_by_key(p.d, element, "allow-null") or_else "") == "true"

		if enum_ != "" {
			if strings.index(enum_, ".") == -1 {
				enum_ = strings.concatenate({ interface_name, ".", enum_ }, allocator = p_allocator(p))
			}

			flags := Enum_Size_Info_Flags{}
			if a.type.kind == .Int {
				flags += { .I32 }
			} else if a.type.kind == .Uint {
				flags += { .U32 }
			}

			size_info, found := &p.enum_size_info[enum_]
			if !found {
				p.enum_size_info[enum_] = flags
			} else {
				size_info^ += flags
			}
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
			list.push_back(&i.enums, &enum_.node)
		}

		num_requests := 0
		for {
			request_element_id := xml.find_child_by_ident(p.d, element, "request", num_requests) or_break

			num_requests += 1

			request := read_message(p, i.name, request_element_id)
			list.push_back(&i.requests, &request.node)
		}

		num_events := 0
		for {
			event_element_id := xml.find_child_by_ident(p.d, element, "event", num_events) or_break

			num_events += 1

			event := read_message(p, i.name, event_element_id)
			list.push_back(&i.events, &event.node)
		}

		return
	}

	// #endregion

	// #region Parse Protocol File

	file_content_bytes, _ := os.read_entire_file(file, p_allocator(p))
	p.file_content         = string(file_content_bytes)
	p.file                 = strings.clone(file, p_allocator(p))

	xml_err: xml.Error
	p.d, xml_err = xml.parse_string(p.file_content, path = file, allocator = p_allocator(p))
	if xml_err != nil {
		fmt.panicf("%v", xml_err)
	}

	// #endregion

	p.enum_size_info = make(map[string]Enum_Size_Info_Flags, allocator = p_allocator(p))
	p.enums          = make(map[string]^Enum, allocator = p_allocator(p))

	element := p.d.elements[0]
	// element, ok := xml.find_child_by_ident(document, 0, "protocol")
	// if !ok do panic("no protocol")
	assert(element.ident == "protocol")
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
	}

	return
}

// #endregion

Protocol_Import :: struct {
	alias: string,
	path:  string,
}

Mapping :: struct {
	// Maps "xdg_shell" -> "xdg_"
	//      "wayland"   -> "wl_"
	protocol_to_prefix: map[string]string,

	// Maps "xdg_" -> "xdg_shell"
	prefix_to_protocol: map[string]string,

	// Maps "xdg_shell" -> "xdg"
	protocol_import_path: map[string]Protocol_Import,
}

Protocols :: struct {
	using mapping: Mapping,

	// Maps "xdg_shell" -> ^Protocol(name="xdg_shell")
	//      "wayland"   -> ^Protocol(name="wayland")
	protocols: map[string]^Protocol,

	interfaces: map[string]^Interface,
}

// #region Write Protocol

write_protocol :: proc(ps: ^Protocols, p: ^Protocol, w: io.Writer) {
	prefix := ps.protocol_to_prefix[p.name]
	ensure(prefix != "")

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

	c_add_import :: proc(c: Context, imp: Protocol_Import) {}

	// #region Write Enum

	write_enum :: proc(c: Context, e: ^Enum) {
		size_info := c.p.enum_size_info[e.canonical_name]

		postfix := false

		if .I32 in size_info && .U32 in size_info {
			postfix = true
		}

		@static
		LUT := [Enum_Size_Info_Flag]string{
			.I32 = "i32",
			.U32 = "u32",
		}

		if postfix {
			for flag in Enum_Size_Info_Flag {
				e.postfix_names[flag] = c_strip_prefix(c, e.name)

				e.postfix_names[flag] = strings.concatenate({ e.postfix_names[flag], LUT[flag] }, allocator = p_allocator(c.p))
			}
		} else {
			for flag in Enum_Size_Info_Flag {
				e.postfix_names[flag] = c_strip_prefix(c, e.name)
			}
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

				if e.bitfield && entry.value == 0 {
					c_write_string(c, "\t/* ")
				} else {
					c_write_string(c, "\t")
				}

				c_write_string(c, entry.name)
				c_write_string(c, " = ")
				if e.bitfield {
					c_write_string(c, "intrinsics.constant_log2(")
				}
				c_write_int(c, entry.value)
				if e.bitfield {
					c_write_string(c, ")")
				}

				c_write_string(c, ",")
				if entry.summary != "" {
					c_write_string(c, " // ")
					c_write_string(c, entry.summary)
				}

				if e.bitfield && entry.value == 0 {
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
				c_write_string(c, "; ")
				c_write_string(c, LUT[flag])
				c_write_string(c, "]\n\n")
			}
		}
	}
	// #endregion

	type_get_object :: proc(c: Context, t: Type, allocator: runtime.Allocator) -> string {
		i, ok := c.ps.interfaces[t.reference]
		ensure(ok)
		imp := c.ps.protocol_import_path[i.protocol.name]
		c_add_import(c, imp)
		prefix := c.ps.protocol_to_prefix[i.protocol.name]

		name: string

		if c.prefix == prefix {
			name = strings.trim_prefix(t.reference, prefix)
		} else {
			name = strings.concatenate({ imp.alias, ".", strings.trim_prefix(t.reference, prefix) }, allocator = allocator)
		}

		return strings.concatenate({ "^", name }, allocator = allocator)
	}

	type_get_odin_type :: proc(c: Context, t: Type, allocator: runtime.Allocator) -> string {
		switch t.kind {
		case .Int:
			if t.reference != "" {
				// enum
				e := c.p.enums[t.reference]
				return e.postfix_names[.I32]
			}
			return "i32"
		case .Uint:
			if t.reference != "" {
				// enum
				e := c.p.enums[t.reference]
				return e.postfix_names[.U32]
			}
			return "u32"
		case .Fixed:  return "wl.fixed"
		case .String: return "cstring"
		case .Object: return type_get_object(c, t, allocator)
		case .New_Id: panic("type_get_odin_type does not support new_id")
		case .Array:  return "wl.array"
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
		Types :: map[string]struct{}
		types := make(Types, allocator = context.temp_allocator)

		types[c_strip_prefix(c, i.name)] = {}

		for it := list.iterator_head(m.args, Arg, "node"); a in list.iterate_next(&it) {
			if a.type.kind == .New_Id {
				types["wl.interface"] = {}
				types["u32"] = {}

				if a.type.reference == "" {
					types["wl.proxy"] = {}
				} else {
					types[type_get_object(c, a.type, context.temp_allocator)] = {}
				}
			} else {
				types[type_get_odin_type(c, a.type, context.temp_allocator)] = {}
			}
		}

		info.args.allocator = context.temp_allocator

		get_name :: proc(name: string, types: Types) -> string {
			if _, ok := types[name]; ok {
				return strings.concatenate({ name, "_" }, allocator = context.temp_allocator)
			}
			return name
		}

		first_comma_placed: bool

		info.interface_name_var = get_name(c_strip_prefix(c, i.name), types)
		c_write_comma_sep(c, { info.interface_name_var, ": ^", c_strip_prefix(c, i.name) }, &first_comma_placed)

		for it := list.iterator_head(m.args, Arg, "node"); a in list.iterate_next(&it) {
			name := get_name(a.name, types)

			if a.type.kind == .New_Id {
				// do other thing
				info.ret_name_var = name
				info.ret_type = a.type

				if a.type.reference == "" {
					info.kind = .New_Id_Unknown
					info.interface_var = get_name("interface", types)
					info.version_var = get_name("version", types)

					c_write_comma_sep(
						c,
						{
							info.interface_var,
							": ^wl.interface, ",
							info.version_var,
							": u32",
						},
						&first_comma_placed,
					)

					append(&info.args, strings.concatenate({info.interface_var, ".name"}, allocator = context.temp_allocator))
					append(&info.args, info.version_var)

					info.ret_type_var = "^wl.proxy"
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
		defer free_all(context.temp_allocator)
		opcode_string := strings.to_upper_snake_case(c_canonical_to_global(c, r.canonical_name, context.temp_allocator), context.temp_allocator)
		c_write_strings(c, opcode_string, " :: ")
		c_write_string(c, " :: ")
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
			c_write_string(c, ")\n")
		}

		c_write_string(c, c_canonical_to_global(c, r.canonical_name, context.temp_allocator))
		c_write_string(c, " :: proc \"contextless\" (")

		info := write_message_signature(c, i, r)

		c_write_string(c, " {\n\t")
		if info.kind != .Normal {
			c_write_string(c, info.ret_name_var)
			c_write_string(c, " = cast(")
			c_write_string(c, info.ret_type_var)
			c_write_string(c, ")")
		}
	
		c_write_strings(c, "wl.proxy_marshal_flags(cast(^wl.proxy)", info.interface_name_var, ", ", opcode_string, ", ")

		switch info.kind {
		case .Normal:
			c_write_string(c, "nil")
		case .New_Id:
			i, ok := c.ps.interfaces[info.ret_type.reference]
			ensure(ok)
			imp: Protocol_Import
			imp, ok = c.ps.protocol_import_path[i.protocol.name]
			ensure(ok)
			c_write_strings(c, "&", imp.alias, ".", strings.trim_prefix(i.name, c.ps.protocol_to_prefix[i.protocol.name]), "_interface")
		case .New_Id_Unknown:
			c_write_string(c, info.interface_var)
		}

		c_write_string(c, ", ")

		if info.kind == .New_Id_Unknown {
			c_write_string(c, info.version_var)
		} else {
			c_write_strings(c,"wl.proxy_get_version(cast(^wl.proxy)", info.interface_name_var, ")")
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

	write_interface :: proc(c: Context, i: ^Interface) {
		c_write_comment(
			c,
			{
				description = i.description,
				version     = i.version,
			},
		)
		c_write_string(c, c_strip_prefix(c, i.name))
		c_write_string(c, " :: distinct wl.proxy\n\n")

		opcode := 0
		for it := list.iterator_head(i.requests, Message, "node"); r in list.iterate_next(&it) {
			write_request(c, i, r, opcode)
			opcode += 1
		}

		for it := list.iterator_head(i.enums, Enum, "node"); e in list.iterate_next(&it) {
			write_enum(c, e)
		}
	}

	c_write_strings(c, "package ", c.prefix, "\n\n")
	c_write_string(c, "@require import \"base:intrinsics\"\n@require import wl \"..\"\n\n")

	c_write_string(c, "/*\nGenerated with love by robaertschi/root/wayland/scanner/v2\n\nCopyright:\n")
	c_write_string(c, p.copyright)
	c_write_string(c, "*/\n\n")
	c_write_comment(c, { description = p.description })
	c_write_string(c, "\n")

	for _, i in p.interfaces {
		write_interface(c, i)
	}
}

// #endregion

main :: proc() {
	args := os.args[1:]

	p := read_protocol(args[0])

	// for it := list.iterator_head(p.interfaces, Interface, "node"); i in list.iterate_next(&it) {
	// 	fmt.println(i)
	// }

	ps: Protocols
	ps.protocol_to_prefix["wayland"] = "wl_"
	ps.prefix_to_protocol["wl_"] = "wayland"
	ps.protocol_import_path["wayland"] = {
		alias = "wl",
		path  = "..",
	}
	ps.protocols["wayland"] = p
	
	for k, v in p.interfaces {
		ps.interfaces[k] = v
	}

	write_protocol(&ps, p, os.to_stream(os.stdout))

	// fmt.printfln("%#v", p.enum_size_info)
}
