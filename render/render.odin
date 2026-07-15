package root_render

import "core:math/linalg"
import "base:runtime"
import "core:container/handle_map"
import "core:mem/virtual"

import gl "vendor:OpenGL"

State :: struct {
	arena: virtual.Arena,

	textures:    handle_map.Dynamic_Handle_Map(Texture, Texture_Handle),
	nil_texture: Texture_Handle,
}

@private
state: State

@private
state_allocator :: proc() -> runtime.Allocator {
	return virtual.arena_allocator(&state.arena)
}

init :: proc() {
	handle_map.dynamic_init(&state.textures, state_allocator())

	state.nil_texture = texture_from_data({ 1, 1 }, { 255, 255, 255, 255 })
}

Texture_Handle :: struct {
	idx: u32,
	gen: u32,
}

Texture :: struct {
	handle: Texture_Handle,
	id:     u32,
}

texture_from_data :: proc(size: [2]int, data: []byte) -> Texture_Handle {
	texture := Texture{}

	gl.GenTextures(1, &texture.id)
	gl.BindTexture(gl.TEXTURE_2D, texture.id)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, **linalg.array_cast(size, i32), 0, gl.RGBA, gl.UNSIGNED_BYTE, raw_data(data))

	handle, _ := handle_map.add(&state.textures, texture)
	return handle
}

texture_from_size :: proc(size: [2]int) -> Texture_Handle {
	return texture_from_data(size, nil)
}

texture_fill_part :: proc(handle: Texture_Handle, pos: [2]int, size: [2]int, data: []byte) {
	assert(len(data) >= size.x * size.y * 4)

	texture, ok := handle_map.get(&state.textures, handle)
	if !ok {
		return
	}

	gl.BindTexture(gl.TEXTURE_2D, texture.id)
	gl.TexSubImage2D(gl.TEXTURE_2D, 0, **linalg.array_cast(pos, i32), **linalg.array_cast(size, i32), gl.RGBA, gl.UNSIGNED_BYTE, raw_data(data))
}
