package root_render

import "core:log"
import "core:container/xar"
import "core:math/linalg"
import "base:runtime"
import "core:mem/virtual"

import gl "vendor:OpenGL"

import B "../base"

// TODO(robin): blending

Rect :: struct {
	dst_00:           [2]f32,
	dst_11:           [2]f32,
	src_00:           [2]f32,
	src_11:           [2]f32,
	color:            [B.Corner]Color,
	corner_radius:    f32,
	edge_softness:    f32,
	border_thickness: f32,
}

Color :: [4]f32

State :: struct {
	arena:       virtual.Arena,
	frame_arena: virtual.Arena,
	logger:      runtime.Logger,

	textures:    B.Handle_Map(Texture, Texture_Handle),

	window_size: [2]int,

	clips:             xar.Array(B.Rect(int), 4),
	rects:             xar.Array(Rect, 6),
	textures_per_rect: Texture_Handle,  // one per rect
	batches:           Batch_List,

	vao:         u32,
	vbo:         u32,
	buffer_size: int,

	shader_program: u32,
}

NIL_TEXTURE :: Texture_Handle {}

@rodata
nil_texture: Texture_Handle

@private
state: ^State

arena :: proc() -> ^virtual.Arena {
	return &state.arena
}

@private
frame_arena :: proc() -> ^virtual.Arena {
	return &state.frame_arena
}

@private
state_allocator :: proc() -> runtime.Allocator {
	return virtual.arena_allocator(arena())
}

VERT_SHADER_SOURCE :: #load("vertex.glsl", string)
FRAG_SHADER_SOURCE :: #load("fragment.glsl", string)

@(require_results)
init :: proc() -> (ok: bool) {
	state, _ = virtual.arena_growing_bootstrap_new(State, "arena")

	state.logger   = log.create_console_logger(ident = "RENDER", allocator = state_allocator())
	context.logger = state.logger

	B.hm_init(&state.textures, _texture_from_data({ 1, 1 }, { 255, 255, 255, 255 }), state_allocator())
	xar.init(&state.rects, state_allocator())
	xar.init(&state.clips, state_allocator())

	state.shader_program, ok = gl.load_shaders_source(VERT_SHADER_SOURCE, FRAG_SHADER_SOURCE)
	if !ok {
		msg, _, msg2, _ := gl.get_last_error_messages()
		log.fatalf("could not compile shader or program: %v\nlink: %v", msg, msg2)
		return
	}

	state.buffer_size = 64

	gl.GenVertexArrays(1, &state.vao)
	gl.GenBuffers(1, &state.vbo)

	gl.BindVertexArray(state.vao)
	gl.BindBuffer(gl.ARRAY_BUFFER, state.vbo)
	gl.BufferData(gl.ARRAY_BUFFER, state.buffer_size * size_of(Rect), nil, gl.DYNAMIC_DRAW)

	layout := [?]i32{
		2,
		2,
		2,
		2,

		// Colors
		4,
		4,
		4,
		4,

		1,
		1,
		1,
	}

	stride: i32
	for attr in layout {
		stride += attr
	}

	offset: uintptr
	for attr, i in layout {
		gl.VertexAttribPointer(u32(i), attr, gl.FLOAT, false, stride * size_of(f32), offset * size_of(f32))
		gl.EnableVertexAttribArray(u32(i))
		gl.VertexAttribDivisor(u32(i), 1)
		offset += uintptr(attr)
	}

	gl.BindBuffer(gl.ARRAY_BUFFER, 0)

	gl.Enable(gl.BLEND)
	gl.Enable(gl.SCISSOR_TEST)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

	ok = true
	return
}

begin_frame :: proc(window_size: [2]int) {
	state.window_size = window_size

	// Reset frame data
	xar.clear(&state.rects)
	xar.clear(&state.clips)
	_, _ = xar.push_back(&state.clips, B.Rect(int){ pos = {}, size = window_size })
	batch_list_clear(&state.batches)
	virtual.arena_free_all(&state.frame_arena)
}

end_frame :: proc() {
	// Apply window size
	gl.Viewport(0, 0, **linalg.array_cast(state.window_size, i32))

	// Resize buffer
	for state.rects.len > state.buffer_size {
		state.buffer_size *= 2
	}
	gl.BindVertexArray(state.vao)
	gl.BindBuffer(gl.ARRAY_BUFFER, state.vbo) // the upload needs the buffer bound
	gl.BufferData(gl.ARRAY_BUFFER, state.buffer_size * size_of(Rect), nil, gl.DYNAMIC_DRAW)


	// Copy all rects into buffer
	rects := state.rects

	copied := 0
	for chunk in rects.chunks {
		if chunk != nil {
			chunk_cap := B.xar_chunk_cap(&state.rects, uint(copied))

			to_copy := min(int(chunk_cap), rects.len - copied)

			gl.BufferSubData(gl.ARRAY_BUFFER, copied * size_of(Rect), to_copy * size_of(Rect), chunk)

			copied += to_copy
		}
	}

	// General prep
	gl.BindBuffer(gl.ARRAY_BUFFER, 0)

	gl.ClearColor(1, 1, 1, 1)
	gl.Clear(gl.COLOR_BUFFER_BIT)

	// Setup shared batch state
	gl.UseProgram(state.shader_program)
	gl.Uniform2f(1, **linalg.array_cast(state.window_size, f32))

	// Draw batches
	for batch_node := state.batches.first; batch_node != nil; batch_node = batch_node.next {
		batch := batch_node.batch
		count := batch.end - batch.start

		clip := batch.data.clip
		gl.Scissor(**linalg.array_cast(clip.pos, i32), **linalg.array_cast(clip.size, i32))

		texture := B.hm_get(&state.textures, batch.data.texture) or_else B.hm_get(&state.textures, NIL_TEXTURE)

		gl.BindTexture(gl.TEXTURE_2D, texture.id)

		gl.DrawArraysInstancedBaseInstance(gl.TRIANGLE_STRIP, 0, 4, i32(count), u32(batch.start))
	}

	gl.BindVertexArray(0)
}

Texture_Handle :: struct {
	idx: u32,
	gen: u32,
}

Texture :: struct {
	handle: Texture_Handle,
	id:     u32,
}

_texture_from_data :: proc(size: [2]int, data: []byte) -> (texture: Texture) {
	gl.GenTextures(1, &texture.id)
	gl.BindTexture(gl.TEXTURE_2D, texture.id)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA8, **linalg.array_cast(size, i32), 0, gl.RGBA, gl.UNSIGNED_BYTE, raw_data(data))

	return texture
}


texture_from_data :: proc(size: [2]int, data: []byte) -> Texture_Handle {
	texture   := _texture_from_data(size, data)
	handle, _ := B.hm_add(&state.textures, texture)
	return handle
}

texture_from_size :: proc(size: [2]int) -> Texture_Handle {
	return texture_from_data(size, nil)
}

texture_fill_part :: proc(handle: Texture_Handle, pos: [2]int, size: [2]int, data: []byte) {
	assert(len(data) >= size.x * size.y * 4)

	texture, ok := B.hm_get(&state.textures, handle)
	if !ok {
		return
	}

	gl.BindTexture(gl.TEXTURE_2D, texture.id)
	gl.TexSubImage2D(gl.TEXTURE_2D, 0, **linalg.array_cast(pos, i32), **linalg.array_cast(size, i32), gl.RGBA, gl.UNSIGNED_BYTE, raw_data(data))
}

texture_fill_part_bgra :: proc(handle: Texture_Handle, pos: [2]int, size: [2]int, data: []byte) {
	assert(len(data) >= size.x * size.y * 4)

	texture, ok := B.hm_get(&state.textures, handle)
	if !ok {
		return
	}

	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D, texture.id)
	gl.TexSubImage2D(gl.TEXTURE_2D, 0, **linalg.array_cast(pos, i32), **linalg.array_cast(size, i32), gl.BGRA, gl.UNSIGNED_BYTE, raw_data(data))
}

// ptr valid for the whole frame, this is for immediate mode
rect :: proc(r: B.Rect(f32) = {}, color: Color = {}, texture := NIL_TEXTURE, tex_r: B.Rect(f32) = {}) -> ^Rect {
	rect := Rect {
		dst_00 = r.pos,
		dst_11 = r.pos + r.size,
		src_00 = tex_r.pos,
		src_11 = tex_r.pos + tex_r.size,
		color  = { ._00 = color, ._10 = color, ._01 = color, ._11 = color },
	}

	return batch_push_rect(
		rect,
		{
			texture = texture,
			clip    = top_clip(),
		},
	)
}

top_clip :: proc() -> B.Rect(int) {
	return xar.get(&state.clips, xar.len(state.clips)-1)
}

push_clip :: proc(r: B.Rect(int)) {
	xar.push_back(&state.clips, B.rect_intersection(r, top_clip()))
}

pop_clip :: proc() -> B.Rect(int) {
	assert(xar.len(state.clips) > 1)

	return xar.pop(&state.clips)
}

// texture_fill_part_alpha_only :: proc(handle: Texture_Handle, pos: [2]int, size: [2]int, data: []byte) {
// 	assert(len(data) >= size.x * size.y)
//
// 	texture, ok := B.hm_get(&state.textures, handle)
// 	if !ok {
// 		return
// 	}
//
// 	gl.BindTexture(gl.TEXTURE_2D, texture.id)
//
// 	alpha_only_swizzles := [4]i32{
// 		gl.ONE, gl.ONE, gl.ONE, gl.RED,
// 	}
// 	default_swizzles := [4]i32{
// 		gl.RED, gl.GREEN, gl.BLUE, gl.ALPHA,
// 	}
// 	gl.TexSubImage2D(gl.TEXTURE_2D, 0, **linalg.array_cast(pos, i32), **linalg.array_cast(size, i32), gl.RED, gl.UNSIGNED_BYTE, raw_data(data))
// }
