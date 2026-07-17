package root_render

import "core:fmt"
import "base:intrinsics"
import "core:log"
import "core:container/xar"
import "core:math/linalg"
import "base:runtime"
import "core:mem/virtual"

import gl "vendor:OpenGL"

import B "../base"

// TODO(robin): blending

Rect :: struct {
	pos_00: [2]f32,
	pos_11: [2]f32,
	color:  Color,
}

Color :: [4]f32

State :: struct {
	arena:    virtual.Arena,
	logger:   runtime.Logger,
	textures: B.Handle_Map(Texture, Texture_Handle),
	rects:    xar.Array(Rect, 8),

	vao:         u32,
	vbo:         u32,
	ebo:         u32,
	buffer_size: int,

	shader_program: u32,
}

NIL_TEXTURE :: Texture_Handle {}

@rodata
nil_texture: Texture_Handle

@private
state: State

@private
state_allocator :: proc() -> runtime.Allocator {
	return virtual.arena_allocator(&state.arena)
}

VERT_SHADER_SOURCE :: #load("vertex.glsl", string)
FRAG_SHADER_SOURCE :: #load("fragment.glsl", string)

@(require_results)
init :: proc() -> (ok: bool) {
	state.logger   = log.create_console_logger(ident = "RENDER", allocator = state_allocator())
	context.logger = state.logger

	B.hm_init(&state.textures, _texture_from_data({ 1, 1 }, { 255, 255, 255, 255 }), state_allocator())
	xar.init(&state.rects, state_allocator())

	state.shader_program, ok = gl.load_shaders_source(VERT_SHADER_SOURCE, FRAG_SHADER_SOURCE)
	if !ok {
		msg, _ := gl.get_last_error_message()
		log.fatalf("could not compile shader or program: %v", msg)
		return
	}

	state.buffer_size = 64

	gl.GenVertexArrays(1, &state.vao)
	gl.GenBuffers(1, &state.vbo)
	gl.GenBuffers(1, &state.ebo)

	gl.BindVertexArray(state.vao)
	gl.BindBuffer(gl.ARRAY_BUFFER, state.vbo)
	gl.BufferData(gl.ARRAY_BUFFER, state.buffer_size * size_of(Rect), nil, gl.DYNAMIC_DRAW)
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, state.ebo)
	gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, state.buffer_size * 6 * size_of(u16), nil, gl.DYNAMIC_DRAW)

	gl.VertexAttribPointer(0, 2, gl.FLOAT, false, 8 * size_of(f32), 0)
	gl.VertexAttribPointer(1, 2, gl.FLOAT, false, 8 * size_of(f32), 2 * size_of(f32))
	gl.VertexAttribPointer(2, 4, gl.FLOAT, false, 8 * size_of(f32), 4 * size_of(f32))

	gl.EnableVertexAttribArray(0)
	gl.EnableVertexAttribArray(1)
	gl.EnableVertexAttribArray(2)

	gl.VertexAttribDivisor(0, 1)
	gl.VertexAttribDivisor(1, 1)
	gl.VertexAttribDivisor(2, 1)

	gl.BindBuffer(gl.ARRAY_BUFFER, 0)

	ok = true
	return
}

frame :: proc(window_size: [2]int) {
	gl.Viewport(0, 0, **linalg.array_cast(window_size, i32))

	for state.rects.len > state.buffer_size {
		state.buffer_size *= 2
	}
	gl.BindVertexArray(state.vao)
	gl.BindBuffer(gl.ARRAY_BUFFER, state.vbo) // the upload needs the buffer bound
	gl.BufferData(gl.ARRAY_BUFFER, state.buffer_size * size_of(Rect), nil, gl.DYNAMIC_DRAW)

	rects := state.rects

	temp := B.TEMP_ALLOCATOR_GUARD()
	temp_data := make([]u16, rects.len * 6, allocator = temp)

	for i in 0..<rects.len {
		copy(temp_data[i*6:], []u16{ 0, 1, 2, 1, 2, 3 })
	}
	gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, state.buffer_size * 6 * size_of(u16), nil, gl.DYNAMIC_DRAW)
	gl.BufferSubData(gl.ELEMENT_ARRAY_BUFFER, 0, rects.len * 6 * size_of(u16), raw_data(temp_data))

	copied := 0
	for chunk in rects.chunks {
		if chunk != nil {
			chunk_cap := uint(1) << 8
			index_shift := copied >> 8
			if index_shift > 0 {
				N :: 8*size_of(uint)-1
				CLZ :: intrinsics.count_leading_zeros
				chunk_idx := uint(N-CLZ(index_shift))
				chunk_cap = 1 << (chunk_idx + 8)
			}

			to_copy := min(int(chunk_cap), rects.len - copied)

			gl.BufferSubData(gl.ARRAY_BUFFER, copied * size_of(Rect), to_copy * size_of(Rect), chunk)

			copied += to_copy
		}
	}

	gl.BindBuffer(gl.ARRAY_BUFFER, 0)

	gl.ClearColor(1, 1, 1, 1)
	gl.Clear(gl.COLOR_BUFFER_BIT)

	gl.UseProgram(state.shader_program)
	gl.Uniform2f(1, **linalg.array_cast(window_size, f32))
	gl.DrawElementsInstanced(gl.TRIANGLES, 6, gl.UNSIGNED_SHORT, nil, i32(rects.len))
	gl.BindVertexArray(0)

	xar.clear(&state.rects)
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

	gl.BindTexture(gl.TEXTURE_2D, texture.id)
	gl.TexSubImage2D(gl.TEXTURE_2D, 0, **linalg.array_cast(pos, i32), **linalg.array_cast(size, i32), gl.BGRA, gl.UNSIGNED_BYTE, raw_data(data))
}

// ptr valid for the whole frame, this is for immediate mode
rect_empty :: proc() -> ^Rect {
	return rect_from_b_rect_with_color({}, { 0, 0, 0, 1 })
}

rect_from_b_rect :: proc(r: B.Rect(f32)) -> ^Rect {
	return rect_from_b_rect_with_color(r, { 0, 0, 0, 1 })
}

rect_from_b_rect_with_color :: proc(r: B.Rect(f32), color: Color) -> ^Rect {
	ptr, _ := xar.push_back_elem_and_get_ptr(
		&state.rects,
		Rect {
			pos_00 = r.pos,
			pos_11 = r.pos + r.size,
			color  = color,
		},
	)
	return ptr
}

rect :: proc{
	rect_empty,
	rect_from_b_rect,
	rect_from_b_rect_with_color,
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
