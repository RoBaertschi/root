package tools

import "base:runtime"
import "core:io"
import "core:os"
import "core:fmt"

Stack :: struct {
	name: string,
	type: string,
	nil_: string,
}

STACKS :: [?]Stack{
	// Sizes
	{"semantic_width",  "Size", "pixels(800, 1)"},
	{"semantic_height", "Size", "pixels(600, 1)"},

	// Layout
	{"child_layout_axis", "Axis", "Axis.X"},
	{"fixed_x",           "f32", "0"},
	{"fixed_y",           "f32", "0"},

	// Styles
	{"text_color",       "Color", "Color{0, 0, 0, 1}"},
	{"border_color",     "Color", "Color{1, 1, 1, 1}"},
	{"background_color", "Color", "Color{1, 1, 1, 1}"},
	{"border_thickness", "f32",   "1"},
	{"corner_radius",    "f32",   "0"},
	{"font_size",        "u16",   "16"},
	{"font",             "F.ID",  "F.DEFAULT_ID"},
}

main :: proc() {
	f, err := os.create("stacks.odin")
	if err != nil {
		fmt.println("could not create stacks.odin: %v", err)
		os.exit(1)
	}

	w := os.to_writer(f)

	io.write_string(w, "package oui\n\nimport \"base:runtime\"\nimport F \"../font\"\n\n")

	// Stacks struct
	io.write_string(w, "Stacks :: struct {\n")

	for stack in STACKS {
		fmt.wprintf(w, "\t%s: Stack(%s),\n", stack.name, stack.type)
	}

	io.write_string(w, "}\n\n")

	// auto_pop_stacks
	io.write_string(w, "auto_pop_stacks :: proc() {\n")

	for stack in STACKS {
		fmt.wprintf(w, "\tstack_auto_pop(&state.stacks.%s)\n", stack.name)
	}

	io.write_string(w, "}\n\n")

	// init_stacks

	io.write_string(w, "init_stacks :: proc() {\n")

	for stack in STACKS {
		fmt.wprintf(w, "\tstack_init(&state.stacks.%s, %s)\n", stack.name, stack.nil_)
	}

	io.write_string(w, "}\n\n")

	// stack procedures
	for stack in STACKS {
		fmt.wprintf(w, "//+%v\n", stack.name)

		// set_next
		fmt.wprintf(w, "%[0]s_set_next :: proc(v: %[1]s) {{ stack_set_next(&state.stacks.%[0]s, v) }}\n", stack.name, stack.type)

		// push
		fmt.wprintf(w, "%[0]s_push :: proc(v: %[1]s) {{ stack_push(&state.stacks.%[0]s, v) }}\n", stack.name, stack.type)

		// pop
		fmt.wprintf(w, "%[0]s_pop :: proc() -> %[1]s {{ return stack_pop(&state.stacks.%[0]s) }}\n", stack.name, stack.type)

		// top
		fmt.wprintf(w, "%[0]s_top :: proc() -> %[1]s {{ return stack_top(&state.stacks.%[0]s) }}\n", stack.name, stack.type)

		// guard
		fmt.wprintf(w, "@(deferred_in=_%[0]s_guard_end)\n%[0]s_guard :: proc(v: %[1]s, loc := #caller_location) {{ stack_push(&state.stacks.%[0]s, v) }}\n", stack.name, stack.type)
		fmt.wprintf(w, "_%[0]s_guard_end :: proc(v: %[1]s, loc: runtime.Source_Code_Location) {{\n\told := %[0]s_pop()\n\tassert(old == v, loc = loc)\n}}\n", stack.name, stack.type)

		fmt.wprintf(w, "//-%v\n\n", stack.name)
	}
}
