package xkbcommon

import "core:c"

MOD_NAME_SHIFT :: "Shift"
MOD_NAME_CAPS  :: "Lock"
MOD_NAME_CTRL  :: "Control"
MOD_NAME_MOD1  :: "Mod1"
MOD_NAME_MOD2  :: "Mod2"
MOD_NAME_MOD3  :: "Mod3"
MOD_NAME_MOD4  :: "Mod4"
MOD_NAME_MOD5  :: "Mod5"

/**
 * @defgroup virtual-modifier-names Virtual modifiers names
 *
 * Common [*virtual* modifiers][virtual modifiers], encoded in [xkeyboard-config]
 * in the [compat] and [symbols] files. They have been stable since the beginning
 * of the project and are unlikely to ever change.
 *
 * [virtual modifiers]: @ref virtual-modifier-def
 * [xkeyboard-config]: https://gitlab.freedesktop.org/xkeyboard-config/xkeyboard-config
 * [compat]: @ref the-xkb_compat-section
 * [symbols]: @ref the-xkb_symbols-section
 *
 * @{
 */
/** @since 1.8.0 */
VMOD_NAME_ALT    :: "Alt"
/** @since 1.8.0 */
VMOD_NAME_HYPER  :: "Hyper"
/** @since 1.8.0 */
VMOD_NAME_LEVEL3 :: "LevelThree"
/** @since 1.8.0 */
VMOD_NAME_LEVEL5 :: "LevelFive"
/** @since 1.8.0 */
VMOD_NAME_META   :: "Meta"
/** @since 1.8.0 */
VMOD_NAME_NUM    :: "NumLock"
/** @since 1.8.0 */
VMOD_NAME_SCROLL :: "ScrollLock"
/** @since 1.8.0 */
VMOD_NAME_SUPER  :: "Super"
/** @} */

context_       :: struct {}
keymap         :: struct {}
state          :: struct {}
keysym_t       :: distinct u32
keycode_t      :: distinct u32
mod_mask_t     :: distinct u32
level_index_t  :: distinct u32
layout_index_t :: distinct u32

/** Flags for context creation. */
context_flag :: enum c.int {
    /** Do not apply any context flags. */
    NO_FLAGS,
    /**
     * Create this context with an empty include path.
     *
     * This may be useful e.g.:
     * - to have full control over the included paths;
     * - for clients that do not need to access the XKB directories, e.g.
     *   if only retrieving keymap from the Wayland or X server. It avoids
     *   potential issues with directory access permissions.
     */
    NO_DEFAULT_INCLUDES,
    /**
     * Don’t take RMLVO names from the environment.
     *
     * @since 0.3.0
     */
    NO_ENVIRONMENT_NAMES,
    /**
     * Disable the use of secure_getenv for this context, so that privileged
     * processes can use environment variables. Client uses at their own risk.
     *
     * @since 1.5.0
     */
    NO_SECURE_GETENV,
}

context_flags :: bit_set[context_flag; c.int]

keymap_compile_flag :: enum c.int {
    NO_FLAGS,
}

keymap_compile_flags :: bit_set[keymap_compile_flag; c.int]

keymap_format :: enum c.int {
    TEXT_V1 = 1,
    TEXT_V2 = 2,
}

/**
 * Modifier and layout types for state objects.  This enum is bitmaskable,
 * e.g. (`::XKB_STATE_MODS_DEPRESSED` | `::XKB_STATE_MODS_LATCHED`) is valid to
 * exclude locked modifiers.
 *
 * In XKB, the `DEPRESSED` components are also known as *base*.
 */
state_component :: enum c.int {
    /** Depressed modifiers, i.e. a key is physically holding them. */
    MODS_DEPRESSED,
    /** Latched modifiers, i.e. will be unset after the next non-modifier
     *  key press. */
    MODS_LATCHED,
    /** Locked modifiers, i.e. will be unset after the key provoking the
     *  lock has been pressed again. */
    MODS_LOCKED,
    /** Effective modifiers, i.e. currently active and affect key
     *  processing (derived from the other state components).
     *  Use this unless you explicitly care how the state came about. */
    MODS_EFFECTIVE,
    /** Depressed layout, i.e. a key is physically holding it. */
    LAYOUT_DEPRESSED,
    /** Latched layout, i.e. will be unset after the next non-modifier
     *  key press. */
    LAYOUT_LATCHED,
    /** Locked layout, i.e. will be unset after the key provoking the lock
     *  has been pressed again. */
    LAYOUT_LOCKED,
    /** Locked layout, i.e. will be unset after the key provoking the lock
     *  has been pressed again. */
    LAYOUT_EFFECTIVE,
    /** LEDs (derived from the other state components). */
    LEDS,
}
state_components :: bit_set[state_component; c.int]

key_direction :: enum c.int {
    UP,
    DOWN,
}

foreign import lib "system:xkbcommon"

@(link_prefix="xkb_")
@(default_calling_convention="c")
foreign lib {
    context_new   :: proc(flags: context_flags) -> ^context_ ---
    context_ref   :: proc(ctx: ^context_) -> ^context_ ---
    context_unref :: proc(ctx: ^context_) ---

    keymap_new_from_string :: proc(ctx: ^context_, s: cstring, format: keymap_format, flags: keymap_compile_flags) -> ^keymap ---
    keymap_ref             :: proc(km: ^keymap) -> ^keymap ---
    keymap_unref           :: proc(km: ^keymap) ---

    state_new   :: proc(km: ^keymap) -> ^state ---
    state_ref   :: proc(s: ^state) -> ^state ---
    state_unref :: proc(s: ^state) ---

    /**
     * Get the single keysym obtained from pressing a particular key in a
     * given keyboard state.
     *
     * This function is similar to `xkb_state_key_get_syms()`, but intended
     * for users which cannot or do not want to handle the case where
     * multiple keysyms are returned (in which case this function is
     * preferred).
     *
     * @returns The keysym.  If the key does not have exactly one keysym,
     * returns `XKB_KEY_NoSymbol`.
     *
     * This function performs Capitalization @ref keysym-transformations.
     *
     * @sa xkb_state_key_get_syms()
     * @memberof xkb_state
     */
    state_key_get_one_sym  :: proc(s: ^state, code: keycode_t) -> keysym_t ---
    /**
     * Get the Unicode/UTF-8 string obtained from pressing a particular key
     * in a given keyboard state.
     *
     * @param[in]  state  The keyboard state object.
     * @param[in]  key    The keycode of the key.
     * @param[out] buffer A buffer to write the string into.
     * @param[in]  size   Size of the buffer.
     *
     * @warning If the buffer passed is too small, the string is truncated
     * (though still `NULL`-terminated).
     *
     * @returns The number of bytes required for the string, excluding the
     * `NULL` byte.  If there is nothing to write, returns 0.
     *
     * You may check if truncation has occurred by comparing the return value
     * with the size of @p buffer, similarly to the `snprintf(3)` function.
     * You may safely pass `NULL` and 0 to @p buffer and @p size to find the
     * required size (without the `NULL`-byte).
     *
     * This function performs Capitalization and Control @ref
     * keysym-transformations.
     *
     * @memberof xkb_state
     * @since 0.4.1
     */
    state_key_get_utf8 :: proc(s: ^state, key: keycode_t, buffer: [^]c.char, size: c.size_t) -> c.int ---

    /**
     * Update a keyboard state from a set of explicit masks.
     *
     * This entry point is intended for *client* applications; see @ref
     * server-client-state for details. *Server* applications should use
     * `xkb_state_update_key()` instead.
     *
     * All parameters must always be passed, or the resulting state may be
     * incoherent.
     *
     * @warning The serialization is lossy and will not survive round trips; it must
     * only be used to feed client state objects, and must not be used to update the
     * server state.
     *
     * @returns A mask of state components that have changed as a result of
     * the update.  If nothing in the state has changed, returns 0.
     *
     * @memberof xkb_state
     *
     * @sa `xkb_state_component`
     * @sa `xkb_state_update_key()`
     */
    state_update_mask :: proc(s: ^state, depressed_mods, latched_mods, locked_mods: mod_mask_t, depressed_layout, latched_layout, locked_layout: layout_index_t) -> state_components ---
    /**
     * Update the keyboard state to reflect a given key being pressed or
     * released.
     *
     * This entry point is intended for *server* applications and should not be used
     * by *client* applications; see @ref server-client-state for details.
     *
     * A series of calls to this function should be consistent; that is, a call
     * with `::XKB_KEY_DOWN` for a key should be matched by an `::XKB_KEY_UP`; if a
     * key is pressed twice, it should be released twice; etc. Otherwise (e.g. due
     * to missed input events), situations like “stuck modifiers” may occur.
     *
     * This function is often used in conjunction with the function
     * `xkb_state_key_get_syms()` (or `xkb_state_key_get_one_sym()`), for example,
     * when handling a key event.  In this case, you should prefer to get the
     * keysyms *before* updating the key, such that the keysyms reported for
     * the key event are not affected by the event itself.  This is the
     * conventional behavior.
     *
     * @returns A mask of state components that have changed as a result of
     * the update.  If nothing in the state has changed, returns 0.
     *
     * @memberof xkb_state
     *
     * @sa `xkb_state_update_mask()`
     */
    state_update_key :: proc(s: ^state, key: keycode_t, direction: key_direction) -> state_components ---

    /**
    * Test whether a modifier is active in a given keyboard state by name.
    *
    * @warning For [virtual modifiers], this function may *overmatch* in case
    * there are virtual modifiers with overlapping mappings to [real modifiers].
    *
    * @returns 1 if the modifier is active, 0 if it is not.  If the modifier
    * name does not exist in the keymap, returns -1.
    *
    * @memberof xkb_state
    *
    * @since 0.1.0: Works only with *real* modifiers
    * @since 1.8.0: Works also with *virtual* modifiers
    *
    * [virtual modifiers]: @ref virtual-modifier-def
    * [real modifiers]: @ref real-modifier-def
    */
    state_mod_name_is_active :: proc(s: ^state, name: cstring, type: state_component) -> c.int ---

    /**
     * Get the Unicode/UTF-32 representation of a keysym.
     *
     * @returns The Unicode/UTF-32 representation of keysym, which is also
     * compatible with UCS-4.  If the keysym does not have a Unicode
     * representation, returns 0.
     *
     * This function does not perform any @ref keysym-transformations.
     * Therefore, prefer to use xkb_state_key_get_utf32() if possible.
     *
     * @sa `xkb_state::xkb_state_key_get_utf32()`
     */
    keysym_to_utf32 :: proc(ks: keysym_t) -> rune ---

	/**
	 * Get the keysyms obtained from pressing a key in a given layout and
	 * shift level.
	 *
	 * This function is like `xkb_state::xkb_state_key_get_syms()`, only the layout
	 * and shift level are not derived from the keyboard state but are instead
	 * specified explicitly.
	 *
	 * @param[in] keymap    The keymap.
	 * @param[in] key       The keycode of the key.
	 * @param[in] layout    The layout for which to get the keysyms.
	 * @param[in] level     The shift level in the layout for which to get the
	 * keysyms. This should be smaller than:
	 * @code xkb_keymap_num_levels_for_key(keymap, key) @endcode
	 * @param[out] syms_out An immutable array of keysyms corresponding to the
	 * key in the given layout and shift level.
	 *
	 * If @c layout is out of range for this key (that is, larger or equal to
	 * the value returned by `xkb_keymap_num_layouts_for_key()`), it is brought
	 * back into range in a manner consistent with
	 * `xkb_state::xkb_state_key_get_layout()`.
	 *
	 * @returns The number of keysyms in the syms_out array.  If no keysyms
	 * are produced by the key in the given layout and shift level, returns 0
	 * and sets @p syms_out to `NULL`.
	 *
	 * @sa `xkb_state::xkb_state_key_get_syms()`
	 * @memberof xkb_keymap
	 */
	keymap_key_get_syms_by_level :: proc(keymap: ^keymap, key: keycode_t, layout: layout_index_t, level: level_index_t, syms_out: ^[^]keysym_t) -> c.int ---

    /**
     * Determine whether a key should repeat or not.
     *
     * A keymap may specify different repeat behaviors for different keys.
     * Most keys should generally exhibit repeat behavior; for example, holding
     * the `a` key down in a text editor should normally insert a single ‘a’
     * character every few milliseconds, until the key is released.  However,
     * there are keys which should not or do not need to be repeated.  For
     * example, repeating modifier keys such as Left/Right Shift or Caps Lock
     * is not generally useful or desired.
     *
     * @returns 1 if the key should repeat, 0 otherwise.
     *
     * @memberof xkb_keymap
     */
    keymap_key_repeats :: proc(keymap: ^keymap, key: keycode_t) -> b32 ---
}
