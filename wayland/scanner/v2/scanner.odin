package wayland_scanner_v2

import "core:strconv"
import "core:container/xar"
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

Protocol :: struct {
	arena: virtual.Arena `fmt:"-"`,

	file:         string,
	file_content: string `fmt:"-"`,

	d: ^xml.Document,

	name:        string,
	copyright:   string, // child tag
	description: Description,

	interfaces: xar.Array(Interface, 4),
}

Interface :: struct {
	name:    string,
	version: int,
}

p_allocator :: proc(p: ^Protocol) -> runtime.Allocator {
	return virtual.arena_allocator(&p.arena)
}

read_protocol :: proc(file: string) -> (p: ^Protocol) {
	p, _ = virtual.arena_growing_bootstrap_new(Protocol, "arena")

	file_content_bytes, _ := os.read_entire_file(file, p_allocator(p))
	p.file_content         = string(file_content_bytes)
	p.file                 = strings.clone(file, p_allocator(p))

	xml_err: xml.Error
	p.d, xml_err = xml.parse_string(p.file_content, path = file, allocator = p_allocator(p))
	if xml_err != nil {
		fmt.panicf("%v", xml_err)
	}

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

	element := p.d.elements[0]
	// element, ok := xml.find_child_by_ident(document, 0, "protocol")
	// if !ok do panic("no protocol")
	assert(element.ident == "protocol")
	ok: bool
	p.name = read_name(p, 0)

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

	p.description = read_description(p, 0)
	copyright_element, copyright_found := xml.find_child_by_ident(p.d, 0, "copyright")
	if copyright_found {
		p.copyright = read_string_body(p, copyright_element)
	}

	read_version :: proc(p: ^Protocol, element: xml.Element_ID) -> (version: int) {
		version_string, ok := xml.find_attribute_val_by_key(p.d, element, "version")
		if !ok {
			fmt.panicf("missing version for %v", element_name(p, element))
		}

		version, ok = strconv.parse_int(version_string)
		if !ok {
			fmt.panicf("invalid number for %v", element_name(p, element))
		}
		return
	}

	read_interface :: proc(p: ^Protocol, element: xml.Element_ID) -> (i: Interface) {
		i.name    = read_name(p, element)
		i.version = read_version(p, element)

		return
	}

	return
}

main :: proc() {
	args := os.args[1:]

	fmt.println(read_protocol(args[0]))
}
