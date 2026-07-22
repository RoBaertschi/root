package root_render

import "core:container/xar"
import B "../base"

Batch :: struct {
	start, end: int, // index into rects xar
	data:       Batch_Data,
}

Batch_Node :: struct {
	next:  ^Batch_Node,
	batch: Batch,
}

Batch_Data :: struct {
	texture: Texture_Handle,
	clip:    B.Rect(int),
}

Batch_List :: struct {
	first, last: ^Batch_Node,
}

batch_list_push :: proc(bl: ^Batch_List, batch: Batch) {
	node       := B.arena_new(frame_arena(), Batch_Node)
	node.batch  = batch
	B.sll_insert(&bl.first, &bl.last, node)
}

batch_list_clear :: proc(bl: ^Batch_List) {
	bl^ = {}
}

batch_push_rect :: proc(r: Rect, data: Batch_Data) -> ^Rect {
	ptr, _ := xar.push_back_elem_and_get_ptr(&state.rects, r)
	rects  := xar.len(state.rects)

	batches := &state.batches
	last    := batches.last

	if last != nil && last.batch.data == data {
		last.batch.end = rects
	} else {
		batch_list_push(
			batches,
			Batch {
				start = rects-1,
				end   = rects,
				data  = data,
			},
		)
	}

	return ptr
}
