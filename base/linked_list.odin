package root_base

import "base:intrinsics"

sll_insert :: proc(first, last: ^^$T, value: ^T)
	where intrinsics.type_has_field(T, "next"), intrinsics.type_field_type(T, "next") == ^T
{
	if last^ == nil {
		first^ = value
		last^  = value
	} else {
		last^.next = value
		last^      = value
	}
}
