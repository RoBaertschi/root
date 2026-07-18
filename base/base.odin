package root_base

import "core:container/xar"
import "core:fmt"

Corner :: enum {
	Left_Top,
	Left_Bottom,
	Right_Top,
	Right_Bottom,

	_00 = Left_Top,
	_01 = Left_Bottom,
	_10 = Right_Top,
	_11 = Right_Bottom,
}

corner_vec :: proc(corner: Corner, $T: typeid) -> [2]T {
	switch corner {
	case ._00: return { 0, 0 }
	case ._10: return { 1, 0 }
	case ._01: return { 0, 1 }
	case ._11: return { 1, 1 }
	case:
		fmt.panicf("unhandled corner: %v", corner)
	}
}

xar_chunk_cap :: #force_inline proc(array: ^xar.Array($T, $SHIFT), index_in_chunk: uint) -> uint {
	_, _, chunk_cap := xar._meta_get(SHIFT, index_in_chunk)
	return chunk_cap
}
