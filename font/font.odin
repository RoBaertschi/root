package root_font

import "core:mem"
import "core:strings"
import "core:c"
import "base:runtime"

import "core:os"
import "core:log"
import "core:mem/virtual"
import "core:hash/xxhash"

import "../base"
import ft "../freetype/"

import kbts "vendor:kb_text_shape"

ID :: distinct u128

INVALID_ID :: ID(0)

Font_Flag :: enum {
	Bold,
	Italic,
}

Font_Flags :: bit_set[Font_Flag]

Font :: struct {
	hash_next: ^Font,
	hash:      u128,

	// error != nil indicates invalid font
	error: union{ft.Error, os.Error, kbts.load_font_error},

	path:       string,
	face_index: int,

	data:      []u8 `fmt: "-"`,
	flags:     Font_Flags,
	ft_face:   ^ft.Face,
	kbts_font: kbts.font,
}

State :: struct {
	logger:     runtime.Logger,
	ft_library: ^ft.Library,
	kbts_ctx:   ^kbts.shape_context,
	_allocator: runtime.Allocator,

	arena:      virtual.Arena,
	buckets:    []^Font,
}

@private
state_allocator :: proc() -> runtime.Allocator {
	return virtual.arena_allocator(&state.arena)
}

state: State

init :: proc() -> (ok: bool) {
	state = {}

	state.logger = log.create_console_logger(ident = "FONT", allocator = state_allocator())

	if err := ft.Init_FreeType(&state.ft_library); err != nil {
		log.fatalf("Could not initalize FreeType: %v(%v)", ft.Error_String(err), err)
		return
	}
	defer if !ok {
		ft.Done_FreeType(state.ft_library)
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

	state.buckets = make([]^Font, 64)

	ok = true
	return
}

// NOTE: internal, invalid with INVALID_ID
_from_id :: proc(id: ID) -> ^Font {
	base.perf_scoped()

	hash := u128(id)
	font := state.buckets[hash % u128(len(state.buckets))]
	for font != nil {
		if font.hash == hash {
			if font.error != nil {
				return nil
			}

			return font
		}

		font = font.hash_next
	}

	return nil
}

// NOTE: This was written with the idea of immediate mode and to not report duplicate errors
_push_font :: proc(bucket: ^^Font, hash: u128, font_path: string, face_index: int) -> (id: ID) {
	font: ^Font
	if bucket^ != nil {
		font = bucket^
	} else {
		font = new(Font, state_allocator())
	}
	bucket^   = font
	font.hash = hash
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
			return INVALID_ID
		}
	}

	if ft_err := ft.New_Memory_Face(state.ft_library, raw_data(font.data), c.long(len(font.data)), c.long(face_index), &font.ft_face); ft_err != nil {
		if font.error != ft_err {
			log.errorf("could not create FreeType face for font %q: %v(%v)", font_path, ft.Error_String(ft_err), ft_err)
		}
		font.error = ft_err
		return INVALID_ID
	}

	font.kbts_font = kbts.FontFromMemory(font.data, c.int(face_index), kbts.AllocatorFromOdinAllocator(&state._allocator))
	if font.kbts_font.Error != .NONE {
		if font.error != font.kbts_font.Error {
			log.errorf("could not create kbts font for %q: %v", font_path, font.kbts_font.Error)
		}
		font.error = font.kbts_font.Error
		return INVALID_ID
	}

	font.error = nil
	return ID(hash)
}

from_path :: proc(path: string, face_index: int) -> ID {
	face_index := face_index

	base.perf_scoped()

	context.logger = state.logger

	temp := base.TEMP_ALLOCATOR_GUARD()

	// NOTE(robin): Perf this is meassured to be around 2 micro seconds
	//              If we find ourself calling `from_path` 100-1000's of times per frame
	//              We might consider removing this and accepting the potentially higher
	//              Memory usage due to duplication of font
	//              This makes the hotpath go from ~300-400ns -> ~3.5µs
	when true {
		font_path, err := os.get_absolute_path(path, temp)
		if err != nil {
			log.errorf("could not get absolute path for font path %q: %v", path, err)
			return INVALID_ID
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

	bucket := &state.buckets[hash % u128(len(state.buckets))]
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
