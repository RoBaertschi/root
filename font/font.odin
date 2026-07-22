package root_font

import "core:container/intrusive/list"
import "base:runtime"

import "core:c"
import "core:os"
import "core:log"
import "core:mem"
import "core:math"
import "core:hash"
import "core:slice"
import "core:strings"
import "core:math/bits"
import "core:mem/virtual"
import "core:math/linalg"
import "core:hash/xxhash"

import B "../base"
import R "../render"
import FT "../freetype"

import kbts "vendor:kb_text_shape"

ID :: distinct u128

// TODO(robin): consider special casing path="", face_index=0 to map top DEFAULT_ID

DEFAULT_ID :: ID(0)

Font_Flag :: enum {
	Bold,
	Italic,
}

Font_Flags :: bit_set[Font_Flag]

Font :: struct {
	hash_next: ^Font,
	hash:      u128,

	// error != nil indicates an invalid font
	error: union{FT.Error, os.Error, kbts.load_font_error},

	path:       string,
	face_index: int,

	data:         []u8 `fmt: "-"`,
	flags:        Font_Flags,
	ft_face:      ^FT.Face,
	kbts_font:    kbts.font,
	units_per_em: int,
}

Glyph_Key :: struct {
	font:      ID,
	font_size: u16,
	id:        u16,
}

Glyph :: struct {
	using key: Glyph_Key,

	hash_next: ^Glyph,
	hash:      u64,

	atlas:          ^Atlas,
	used_rect:      B.Rect(u16),
	allocated_rect: B.Rect(u16),
	bitmap_top:     int,
	bitmap_left:    int,
	bbox:           FT.BBox,
}

Render_Glyph :: struct {
	glyph:  ^Glyph,
	pos:    [2]f32,
	source: B.Range,
}

Glyph_Node :: struct {
	next:  ^Glyph_Node,
	glyph: Render_Glyph,
}

Glyph_List :: struct {
	first, last: ^Glyph_Node,
	len:         int,
}

Grapheme :: struct {
	range: B.Range,
	start: ^Glyph_Node,
	count: int,
}

Grapheme_Node :: struct {
	next:     ^Grapheme_Node,
	grapheme: Grapheme,
}

Grapheme_List :: struct {
	first, last: ^Grapheme_Node,
	len:         int,
}

Run_Key :: struct {
	s:         string,
	font:      ID,
	font_size: u16,
}

Run :: struct {
	// Map
	key:       Run_Key,
	hash:      u128,
	hash_next: ^Run,

	// Lru
	lru_node:              list.Node,
	lru_last_access_frame: int,

	// Data
	glyphs:    Glyph_List,
	graphemes: Grapheme_List,
	visible:   B.Rect(f32),
	layout:    [2]f32,
}

Atlas_Node :: struct {
	children:      [B.Corner]^Atlas_Node,
	used_rect_len: int, // used sub-rects in children
	rect:          B.Rect(u16),
	glyph:         ^Glyph, // nil if not used
}

Atlas :: struct {
	texture: R.Texture_Handle,
	root:    ^Atlas_Node,
	size:    [2]u16,
}

State :: struct {
	logger:     runtime.Logger,
	ft_library: ^FT.Library,
	kbts_ctx:   ^kbts.shape_context,
	_allocator: runtime.Allocator,

	arena:      virtual.Arena,
	font_map:   []^Font,

	glyph_map:     []^Glyph,
	glyph_atlases: [dynamic; 8]Atlas,

	glyph_node_free: ^Glyph_Node,
	grapheme_free:   ^Grapheme_Node,

	run_map:               []^Run,
	run_lru:               list.List,
	run_lru_len:           int,
	run_lru_current_frame: int,
	run_string_arenas:     [2]virtual.Arena,
}

@private
lru_clone_string :: proc(s: string) -> string {
	return strings.clone(
		s,
		allocator = virtual.arena_allocator(
			&state.run_string_arenas[state.run_lru_current_frame % 2],
		),
	)
}

arena :: proc() -> ^virtual.Arena {
	return &state.arena
}

@private
state_allocator :: proc() -> runtime.Allocator {
	return virtual.arena_allocator(arena())
}

state: ^State

@rodata
nil_atlas := Atlas {
	texture = R.NIL_TEXTURE,
}

nil_glyph := Glyph {
	atlas = &nil_atlas,
}

@(private="file")
default_font_data := #load("embed/JetBrainsMono-Regular.ttf")

init :: proc() -> (ok: bool) {
	B.perf_scoped()

	state, _ = virtual.arena_growing_bootstrap_new(State, "arena")

	state.logger   = log.create_console_logger(ident = "FONT", allocator = state_allocator())
	context.logger = state.logger

	if err := FT.Init_FreeType(&state.ft_library); err != nil {
		log.fatalf("Could not initalize FreeType: %v(%v)", FT.Error_String(err), err)
		return
	}
	defer if !ok {
		FT.Done_FreeType(state.ft_library)
		state.ft_library = nil
	}

	state._allocator = context.allocator

	state.kbts_ctx = kbts.CreateShapeContext(kbts.AllocatorFromOdinAllocator(&state._allocator))
	if state.kbts_ctx == nil {
		log.fatal("Could not initalize kbts, out of memory")
		return
	}
	defer if !ok {
		kbts.DestroyShapeContext(state.kbts_ctx)
		state.kbts_ctx = nil
	}

	INITIAL_FONT_MAP_SIZE :: 64
	state.font_map = B.arena_make(arena(), []^Font, INITIAL_FONT_MAP_SIZE)
	INITIAL_GLYPH_MAP_SIZE :: 1024
	state.glyph_map = B.arena_make(arena(), []^Glyph, INITIAL_GLYPH_MAP_SIZE)
	INITIAL_RUN_MAP_SIZE :: 256
	state.run_map = B.arena_make(arena(), []^Run, INITIAL_RUN_MAP_SIZE)

	BUCKET_INDEX :: u128(DEFAULT_ID) % u128(INITIAL_FONT_MAP_SIZE)

	font := B.arena_new(arena(), Font)

	font.data = default_font_data

	if err := FT.New_Memory_Face(state.ft_library, raw_data(font.data), c.long(len(font.data)), c.long(font.face_index), &font.ft_face); err != nil {
		log.fatalf("could not create FreeType face for internal default font: %v(%v)", FT.Error_String(err), err)
		return
	}

	font.kbts_font = kbts.FontFromMemory(font.data, c.int(font.face_index), kbts.AllocatorFromOdinAllocator(&state._allocator))
	if font.kbts_font.Error != .NONE {
		log.fatalf("could not create kbts font for internal default font: %v", font.kbts_font.Error)
		return
	}
	defer if !ok {
		kbts.FreeFont(&font.kbts_font)
	}
	

	info: kbts.font_info2_1
	info.Size = size_of(info)
	kbts.GetFontInfo2(&font.kbts_font, &info)
	font.units_per_em = int(info.UnitsPerEm)

	state.font_map[BUCKET_INDEX] = font

	ok = true
	return
}

frame :: proc() {
	state.run_lru_current_frame += 1
	virtual.arena_free_all(&state.run_string_arenas[state.run_lru_current_frame % 2])
}

// NOTE: internal, invalid with INVALID_ID
_from_id :: proc(id: ID) -> ^Font {
	B.perf_scoped()

	hash := u128(id)
	font := state.font_map[hash % u128(len(state.font_map))]
	for font != nil {
		if font.hash == hash {
			if font.error != nil {
				return _from_id(DEFAULT_ID)
			}

			return font
		}

		font = font.hash_next
	}

	return _from_id(DEFAULT_ID)
}

// NOTE: This was written with the idea of immediate mode and to not report duplicate errors
_push_font :: proc(bucket: ^^Font, hash: u128, font_path: string, face_index: int) -> (id: ID) {
	font: ^Font
	if bucket^ != nil {
		font = bucket^
	} else {
		font = B.arena_new(arena(), Font)
	}
	bucket^         = font
	font.hash       = hash
	font.face_index = face_index
	if font.path != font_path {
		font.path = strings.clone(font_path, allocator = state_allocator())
	}

	font_error_equal :: proc(err: $T, font: ^Font) -> bool {
		if err2, ok := font.error.(T); ok {
			return err2 == err
		}

		return false
	}

	if font.data == nil {
		err: os.Error
		font.data, err = os.read_entire_file(font_path, state_allocator())
		if err != nil {
			if font.error != err {
				log.errorf("could not read font file %q: %v", font_path, err)
			}
			font.error = err
			return DEFAULT_ID
		}
	}

	if ft_err := FT.New_Memory_Face(state.ft_library, raw_data(font.data), c.long(len(font.data)), c.long(font.face_index), &font.ft_face); ft_err != nil {
		if font.error != ft_err {
			log.errorf("could not create FreeType face for font %q: %v(%v)", font_path, FT.Error_String(ft_err), ft_err)
		}
		font.error = ft_err
		return DEFAULT_ID
	}

	font.kbts_font = kbts.FontFromMemory(font.data, c.int(font.face_index), kbts.AllocatorFromOdinAllocator(&state._allocator))
	if font.kbts_font.Error != .NONE {
		if font.error != font.kbts_font.Error {
			log.errorf("could not create kbts font for %q: %v", font_path, font.kbts_font.Error)
		}
		font.error = font.kbts_font.Error
		return DEFAULT_ID
	}

	info: kbts.font_info2_1
	info.Size = size_of(info)
	kbts.GetFontInfo2(&font.kbts_font, &info)
	font.units_per_em = int(info.UnitsPerEm)

	font.error = nil
	return ID(hash)
}

from_path :: proc(path: string, face_index: int) -> ID {
	face_index := face_index

	context.logger = state.logger

	B.perf_scoped()

	context.logger = state.logger

	temp := B.TEMP_ALLOCATOR_GUARD()

	// NOTE(robin): Perf this is measured to be around 2 microseconds
	//              If we find ourself calling `from_path` 100-1000's of times per frame
	//              We might consider removing this and accepting the potentially higher
	//              Memory usage due to duplication of font
	//              This makes the hotpath go from ~300-400ns -> ~3.5µs
	when true {
		font_path, err := os.get_absolute_path(path, temp)
		if err != nil {
			log.errorf("could not get absolute path for font path %q: %v", path, err)
			return DEFAULT_ID
		}
	} else {
		font_path := path
	}

	hash_state: xxhash.XXH3_state
	xxhash.XXH3_128_reset(&hash_state)
	xxhash.XXH3_128_update(&hash_state, transmute([]u8)font_path)
	xxhash.XXH3_128_update(&hash_state, mem.ptr_to_bytes(&face_index))

	hash := xxhash.XXH3_128_digest(&hash_state)
	if hash == 0 {
		// ID's of value 0 are not valid and should never correspond to an actual Font
		hash = 1
	}

	bucket := &state.font_map[hash % u128(len(state.font_map))]
	for {
		if bucket^ == nil {
			return _push_font(bucket, hash, font_path, face_index)
		}

		if bucket^.hash == hash {
			if bucket^.path != font_path || bucket^.face_index != bucket^.face_index {
				log.warnf("hash collison detected: path %q != %q, face_index %d != %d, hash %v == %v", font_path, bucket^.path, face_index, bucket^.face_index, hash, bucket^.hash)
			}

			if bucket^.error != nil {
				return _push_font(bucket, hash, font_path, face_index)
			}

			return ID(bucket^.hash)
		}

		bucket = &bucket^.hash_next
	}
}

get_run :: proc(font_id: ID, font_size: u16, text: string) -> ^Run {
	font_id   := font_id
	font_size := font_size

	// Hash
	hash_state: xxhash.XXH3_state
	xxhash.XXH3_128_reset(&hash_state)
	xxhash.XXH3_128_update(&hash_state, mem.ptr_to_bytes(&font_id))
	xxhash.XXH3_128_update(&hash_state, mem.ptr_to_bytes(&font_size))
	xxhash.XXH3_128_update(&hash_state, transmute([]u8)text)
	hash := xxhash.XXH3_128_digest(&hash_state)

	key := Run_Key{
		font      = font_id,
		font_size = font_size,
		s         = text,
	}

	// Map Lookup
	bucket := &state.run_map[hash % u128(len(state.font_map))]
	for {
		if bucket^ == nil {
			// TODO(robin): add

			key.s = lru_clone_string(text)
			glyphs, graphemes, visible, layout := shape_text(font_id, font_size, text)

			MAX_LRU_ENTRIES :: 1024

			run: ^Run
			last := container_of(state.run_lru.tail, Run, "lru_node")

			if state.run_lru_len < MAX_LRU_ENTRIES || last.lru_last_access_frame == state.run_lru_current_frame {
				run                = B.arena_new(arena(), Run)
				state.run_lru_len += 1
			} else {
				run = last
				glyph_list_free(last.glyphs)
			}

			list.push_front(&state.run_lru, &run.lru_node)

			run.lru_last_access_frame = state.run_lru_current_frame
			run.key       = key
			run.glyphs    = glyphs
			run.visible   = visible
			run.layout    = layout
			run.graphemes = graphemes
			run.hash      = hash

			bucket^ = run

			return run
		}

		if bucket^.hash == hash && bucket^.key == key {
			if bucket^.lru_last_access_frame != state.run_lru_current_frame {
				// Update outdated bucket
				bucket^.lru_last_access_frame = state.run_lru_current_frame

				// Clone the old string into the new arena
				bucket^.key.s = lru_clone_string(bucket^.key.s)

				list.remove(&state.run_lru, &bucket^.lru_node)
				list.push_front(&state.run_lru, &bucket^.lru_node)
			}

			return bucket^
		}

		bucket = &bucket^.hash_next
	}
}

shape_text :: proc(font_id: ID, font_size: u16, text: string) -> (gl: Glyph_List, grl: Grapheme_List, visible: B.Rect(f32), layout: [2]f32) {
	font := _from_id(font_id)

	if text == "" {
		// NOTE: kbts.ShapeUtf8 seems to crash on an empty string, I don't know why but it does.
		return
	}

	context.logger = state.logger

	_ = kbts.ShapePushFont(state.kbts_ctx, &font.kbts_font)
	defer _ = kbts.ShapePopFont(state.kbts_ctx)

	{
		kbts.ShapeBegin(state.kbts_ctx, .DONT_KNOW, .DONT_KNOW)
		defer kbts.ShapeEnd(state.kbts_ctx)

		kbts.ShapePushFeature(state.kbts_ctx, .kern, 0)
		defer _ = kbts.ShapePopFeature(state.kbts_ctx, .kern)

		kbts.ShapeUtf8(state.kbts_ctx, text, .SOURCE_INDEX)
	}

	FT.Set_Pixel_Sizes(font.ft_face, 0, u32(font_size))

	ascender    := f32(font.ft_face.size.metrics.ascender) / 64
	cursor      := [2]f32{ 0, ascender }
	scale       := f32(font_size) / f32(font.units_per_em)
	line_height := f32(font.ft_face.size.metrics.height) / 64

	line := 1
	max_width: f32

	P00_INIT :: [2]f32{ +math.INF_F32, +math.INF_F32 }
	P11_INIT :: [2]f32{ -math.INF_F32, -math.INF_F32 }

	p00 := P00_INIT
	p11 := P11_INIT

	current_grapheme: Grapheme

	for {
		run := kbts.ShapeRun(state.kbts_ctx) or_break

		if .LINE_HARD in run.Flags {
			max_width = max(max_width, cursor.x)
			cursor.y  = ascender + line_height * f32(line)
			cursor.x  = 0
			line     += 1
		}

		for glyph in kbts.GlyphIteratorNext(&run.Glyphs) {
			origin := [2]f32{
				cursor.x + f32(glyph.OffsetX) * scale,
				cursor.y - f32(glyph.OffsetY) * scale,
			}

			source: kbts.shape_codepoint
			_ = kbts.ShapeGetShapeCodepoint(state.kbts_ctx, glyph.UserIdOrCodepointIndex, &source)

			if gl.last != nil {
				gl.last.glyph.source.end = int(source.UserId)
			}

			g := glyph_map_get({ font = font_id, font_size = font_size, id = glyph.Id })
			glyph_node := glyph_list_push(
				&gl,
				{
					glyph = g,
					pos   = {
						origin.x + f32(g.bitmap_left),
						origin.y - f32(g.bitmap_top),
					},
					source = {
						start = int(source.UserId),
					},
				},
			)

			if .GRAPHEME in source.BreakFlags {
				current_grapheme.range.end = int(source.UserId)

				grapheme_list_push(&grl, current_grapheme)

				current_grapheme.range.start = current_grapheme.range.end
				current_grapheme.start = glyph_node
				current_grapheme.count = 0
			}

			current_grapheme.count += 1

			p00.x = min(p00.x, origin.x + f32(g.bbox.xMin) / 64)
			p11.x = max(p11.x, origin.x + f32(g.bbox.xMax) / 64)

			p00.y = min(p00.y, origin.y - f32(g.bbox.yMax) / 64)
			p11.y = max(p11.y, origin.y - f32(g.bbox.yMin) / 64)

			cursor.y -= f32(glyph.AdvanceY) * scale
			cursor.x += f32(glyph.AdvanceX) * scale
		}
	}

	max_width = max(max_width, cursor.x)

	if gl.last != nil {
		gl.last.glyph.source.end = len(text)
	}

	current_grapheme.range.end = len(text)
	grapheme_list_push(&grl, current_grapheme)

	if p00 == P00_INIT {
		p00 = {}
	}

	if p11 == P11_INIT {
		p11 = {}
	}

	visible = {
		pos  = p00,
		size = p11 - p00,
	}
	layout = {
		max_width,
		f32(line) * line_height,
	}
	return
}

glyph_map_get :: proc(key: Glyph_Key) -> ^Glyph {
	context.logger = state.logger

	h := hash.fnv64a(slice.to_bytes([]Glyph_Key{ key }))
	bucket := &state.glyph_map[uint(h) % len(state.font_map)]
	for  {
		if bucket^ == nil {
			font := _from_id(key.font)

			FT.Set_Pixel_Sizes(font.ft_face, 0, u32(key.font_size))
			if err := FT.Load_Glyph(font.ft_face, u32(key.id), FT.load_flags({ .RENDER, .NO_HINTING })); err != nil {
				log.warnf("could not load and render glyph id %v: %v(%v)", key.id, FT.Error_String(err), err)

				if key.id == 0 {
					return &nil_glyph
				}

				return glyph_map_get({ font = key.font, font_size = key.font_size, id = 0 })
			}

			if font.ft_face.glyph.bitmap.width > bits.U16_MAX || font.ft_face.glyph.bitmap.rows > bits.U16_MAX {
				if key.id == 0 {
					return &nil_glyph
				}

				return glyph_map_get({ font = key.font, font_size = key.font_size, id = 0 })
			}

			glyph := B.arena_new(arena(), Glyph)

			glyph.key         = key
			glyph.hash        = h
			glyph.bitmap_left = int(font.ft_face.glyph.bitmap_left)
			glyph.bitmap_top  = int(font.ft_face.glyph.bitmap_top)

			FT.Outline_Get_BBox(&font.ft_face.glyph.outline, &glyph.bbox)

			glyph_size := [2]u16{ u16(font.ft_face.glyph.bitmap.width), u16(font.ft_face.glyph.bitmap.rows) }

			atlas: ^Atlas
			node:  ^Atlas_Node

			for &a in state.glyph_atlases {
				node = atlas_find_and_take_fitting_node_for_size(a.root, glyph_size)
				if node != nil {
					atlas = &a
					break
				}
			}

			if atlas == nil {
				idx := len(state.glyph_atlases)

				if append(&state.glyph_atlases, Atlas{}) <= 0 {
					return &nil_glyph
				}
				atlas = &state.glyph_atlases[len(state.glyph_atlases)-1]

				ATLAS_SIZE :: 1024

				atlas.size      = { ATLAS_SIZE, ATLAS_SIZE }
				atlas.texture   = R.texture_from_size(linalg.array_cast(atlas.size, int))
				atlas.root      = B.arena_new(arena(), Atlas_Node)

				atlas.root.rect.size = atlas.size

				node = atlas_find_and_take_fitting_node_for_size(atlas.root, glyph_size)
				if node == nil {
					// helpless and probably a bug
					log.errorf("could not allocate a well sized glyph in a new buffer")

					return &nil_glyph
				}
			}

			node.glyph           = glyph
			glyph.allocated_rect = node.rect
			glyph.used_rect      = { node.rect.pos, glyph_size }
			glyph.atlas          = atlas

			atlas_upload_glyph(atlas^, glyph, font.ft_face.glyph)

			bucket^ = glyph
			return glyph
		}

		if bucket^.hash == h && bucket^.key == key {
			return bucket^
		}

		bucket = &bucket^.hash_next
	}
}

atlas_upload_glyph :: proc(atlas: Atlas, glyph: ^Glyph, glyph_slot: ^FT.GlyphSlot) {
	context.logger = state.logger

	bitmap := &glyph_slot.bitmap

	Feature_Flag :: enum {
		BGRA,
		Swizzle,
	}

	Feature_Flags :: bit_set[Feature_Flag]

	@(static)
	LUT_FEATURE_FLAGS := #partial [FT.Pixel_Mode]Feature_Flags{
		.GRAY = {.Swizzle},
		.BGRA = {.BGRA},
	}

	flags := LUT_FEATURE_FLAGS[bitmap.pixel_mode]

	width_bytes := int(bitmap.width) * 4
	buffer_size := int(bitmap.rows) * width_bytes

	if LUT_FEATURE_FLAGS[bitmap.pixel_mode] == {} {
		log.warnf("unsupported pixel mode %q for glyph %v encountered", bitmap.pixel_mode, glyph.id)
		return
	}

	temp := B.TEMP_ALLOCATOR_GUARD()
	buffer := B.arena_make(temp.arena, []u8, buffer_size)
	pos := 0

	if .Swizzle in flags {
		for i in 0..<int(bitmap.rows) {
			for alpha, j in bitmap.buffer[pos:pos+int(bitmap.width)] {
				copy(buffer[i*width_bytes + j*4:], []u8{ 255, 255, 255, alpha })
			}

			pos += int(bitmap.pitch)
		}
	} else {
		for i in 0..<int(bitmap.rows) {
			copy(buffer[i*width_bytes:], bitmap.buffer[pos:pos+width_bytes])

			pos += int(bitmap.pitch)
		}
	}

	used_rect := B.rect_cast(glyph.used_rect, int)

	if .BGRA in flags {
		R.texture_fill_part_bgra(atlas.texture, used_rect.pos, used_rect.size, buffer)
	} else {
		R.texture_fill_part     (atlas.texture, used_rect.pos, used_rect.size, buffer)
	}
}

atlas_find_and_take_fitting_node_for_size :: proc(node: ^Atlas_Node, glyph_size: [2]u16) -> ^Atlas_Node {
	context.logger = state.logger

	if node.rect.size.x < glyph_size.x || node.rect.size.y < glyph_size.y {
		return nil
	}

	if node.glyph != nil {
		return nil
	}

	if node.rect.size.x / 2 < glyph_size.x || node.rect.size.y / 2 < glyph_size.y {
		if node.used_rect_len > 0 {
			return nil
		}

		return node
	}

	if node.rect.size.x > 8 && node.rect.size.y > 8 {
		for &child, corner in node.children {
			if child == nil {
				child = B.arena_new(arena(), Atlas_Node)

				child.rect = {
					pos  = node.rect.pos + (B.corner_vec(corner, u16) * (node.rect.size / 2)),
					size = node.rect.size / 2,
				}
			}

			new_node := atlas_find_and_take_fitting_node_for_size(child, glyph_size)
			if new_node != nil {
				node.used_rect_len += 1
				return new_node
			}
		}
	}

	if node.used_rect_len <= 0 {
		return node
	}

	return nil
}
