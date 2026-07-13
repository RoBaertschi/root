package freetype

import "vendor:stb/image"
import "core:image/png"
import "core:fmt"
import "base:intrinsics"
import "core:os"
import "core:c"
foreign import lib "system:freetype"


Error :: enum c.int {
	// from /usr/include/freetype2/freetype/fterrdef.h

	/* generic errors */
	Ok = 0x00,

	Cannot_Open_Resource = 0x01,
	Unknown_File_Format = 0x02,
	Invalid_File_Format = 0x03,
	Invalid_Version = 0x04,
	Lower_Module_Version = 0x05,
	Invalid_Argument = 0x06,
	Unimplemented_Feature = 0x07,
	Invalid_Table = 0x08,
	Invalid_Offset = 0x09,
	Array_Too_Large = 0x0A,
	Missing_Module = 0x0B,
	Missing_Property = 0x0C,

	/* glyph/character errors */

	Invalid_Glyph_Index = 0x10,
	Invalid_Character_Code = 0x11,
	Invalid_Glyph_Format = 0x12,
	Cannot_Render_Glyph = 0x13,
	Invalid_Outline = 0x14,
	Invalid_Composite = 0x15,
	Too_Many_Hints = 0x16,
	Invalid_Pixel_Size = 0x17,
	Invalid_SVG_Document = 0x18,

	/* handle errors */

	Invalid_Handle = 0x20,
	Invalid_Library_Handle = 0x21,
	Invalid_Driver_Handle = 0x22,
	Invalid_Face_Handle = 0x23,
	Invalid_Size_Handle = 0x24,
	Invalid_Slot_Handle = 0x25,
	Invalid_CharMap_Handle = 0x26,
	Invalid_Cache_Handle = 0x27,
	Invalid_Stream_Handle = 0x28,

	/* driver errors */

	Too_Many_Drivers = 0x30,
	Too_Many_Extensions = 0x31,

	/* memory errors */

	Out_Of_Memory = 0x40,
	Unlisted_Object = 0x41,

	/* stream errors */

	Cannot_Open_Stream = 0x51,
	Invalid_Stream_Seek = 0x52,
	Invalid_Stream_Skip = 0x53,
	Invalid_Stream_Read = 0x54,
	Invalid_Stream_Operation = 0x55,
	Invalid_Frame_Operation = 0x56,
	Nested_Frame_Access = 0x57,
	Invalid_Frame_Read = 0x58,

	/* raster errors */

	Raster_Uninitialized = 0x60,
	Raster_Corrupted = 0x61,
	Raster_Overflow = 0x62,
	Raster_Negative_Height = 0x63,

	/* cache errors */

	Too_Many_Caches = 0x70,

	/* TrueType and SFNT errors */

	Invalid_Opcode = 0x80,
	Too_Few_Arguments = 0x81,
	Stack_Overflow = 0x82,
	Code_Overflow = 0x83,
	Bad_Argument = 0x84,
	Divide_By_Zero = 0x85,
	Invalid_Reference = 0x86,
	Debug_OpCode = 0x87,
	ENDF_In_Exec_Stream = 0x88,
	Nested_DEFS = 0x89,
	Invalid_CodeRange = 0x8A,
	Execution_Too_Long = 0x8B,
	Too_Many_Function_Defs = 0x8C,
	Too_Many_Instruction_Defs = 0x8D,
	Table_Missing = 0x8E,
	Horiz_Header_Missing = 0x8F,
	Locations_Missing = 0x90,
	Name_Table_Missing = 0x91,
	CMap_Table_Missing = 0x92,
	Hmtx_Table_Missing = 0x93,
	Post_Table_Missing = 0x94,
	Invalid_Horiz_Metrics = 0x95,
	Invalid_CharMap_Format = 0x96,
	Invalid_PPem = 0x97,
	Invalid_Vert_Metrics = 0x98,
	Could_Not_Find_Context = 0x99,
	Invalid_Post_Table_Format = 0x9A,
	Invalid_Post_Table = 0x9B,
	DEF_In_Glyf_Bytecode = 0x9C,
	Missing_Bitmap = 0x9D,
	Missing_SVG_Hooks = 0x9E,

	/* CFF, CID, and Type 1 errors */

	Syntax_Error = 0xA0,
	Stack_Underflow = 0xA1,
	Ignore = 0xA2,
	No_Unicode_Glyph_Name = 0xA3,
	Glyph_Too_Big = 0xA4,

	/* BDF errors */

	Missing_Startfont_Field = 0xB0,
	Missing_Font_Field = 0xB1,
	Missing_Size_Field = 0xB2,
	Missing_Fontboundingbox_Field = 0xB3,
	Missing_Chars_Field = 0xB4,
	Missing_Startchar_Field = 0xB5,
	Missing_Encoding_Field = 0xB6,
	Missing_Bbx_Field = 0xB7,
	Bbx_Too_Big = 0xB8,
	Corrupted_Font_Header = 0xB9,
	Corrupted_Font_Glyphs = 0xBA,

}

/**************************************************************************
 *
 * @type:
 *   FT_Library
 *
 * @description:
 *   A handle to a FreeType library instance.  Each 'library' is completely
 *   independent from the others; it is the 'root' of a set of objects like
 *   fonts, faces, sizes, etc.
 *
 *   It also embeds a memory manager (see @FT_Memory), as well as a
 *   scan-line converter object (see @FT_Raster).
 *
 *   [Since 2.5.6] In multi-threaded applications it is easiest to use one
 *   `FT_Library` object per thread.  In case this is too cumbersome, a
 *   single `FT_Library` object across threads is possible also, as long as
 *   a mutex lock is used around @FT_New_Face and @FT_Done_Face.
 *
 * @note:
 *   Library objects are normally created by @FT_Init_FreeType, and
 *   destroyed with @FT_Done_FreeType.  If you need reference-counting
 *   (cf. @FT_Reference_Library), use @FT_New_Library and @FT_Done_Library.
 */
Library :: struct {}

/**************************************************************************
 *
 * @enum:
 *   FT_FACE_FLAG_XXX
 *
 * @description:
 *   A list of bit flags used in the `face_flags` field of the @FT_FaceRec
 *   structure.  They inform client applications of properties of the
 *   corresponding face.
 *
 * @values:
 *   FT_FACE_FLAG_SCALABLE ::
 *     The face contains outline glyphs.  Note that a face can contain
 *     bitmap strikes also, i.e., a face can have both this flag and
 *     @FT_FACE_FLAG_FIXED_SIZES set.
 *
 *   FT_FACE_FLAG_FIXED_SIZES ::
 *     The face contains bitmap strikes.  See also the `num_fixed_sizes`
 *     and `available_sizes` fields of @FT_FaceRec.
 *
 *   FT_FACE_FLAG_FIXED_WIDTH ::
 *     The face contains fixed-width characters (like Courier, Lucida,
 *     MonoType, etc.).
 *
 *   FT_FACE_FLAG_SFNT ::
 *     The face uses the SFNT storage scheme.  For now, this means TrueType
 *     and OpenType.
 *
 *   FT_FACE_FLAG_HORIZONTAL ::
 *     The face contains horizontal glyph metrics.  This should be set for
 *     all common formats.
 *
 *   FT_FACE_FLAG_VERTICAL ::
 *     The face contains vertical glyph metrics.  This is only available in
 *     some formats, not all of them.
 *
 *   FT_FACE_FLAG_KERNING ::
 *     The face contains kerning information.  If set, the kerning distance
 *     can be retrieved using the function @FT_Get_Kerning.  Otherwise the
 *     function always returns the vector (0,0).
 *
 *     Note that for TrueType fonts only, FreeType supports both the 'kern'
 *     table and the basic, pair-wise kerning feature from the 'GPOS' table
 *     (with `TT_CONFIG_OPTION_GPOS_KERNING` enabled), though FreeType does
 *     not support the more advanced GPOS layout features; use a library
 *     like HarfBuzz for those instead.
 *
 *   FT_FACE_FLAG_FAST_GLYPHS ::
 *     THIS FLAG IS DEPRECATED.  DO NOT USE OR TEST IT.
 *
 *   FT_FACE_FLAG_MULTIPLE_MASTERS ::
 *     The face contains multiple masters and is capable of interpolating
 *     between them.  Supported formats are Adobe MM, TrueType GX, and
 *     OpenType Font Variations.
 *
 *     See section @multiple_masters for API details.
 *
 *   FT_FACE_FLAG_GLYPH_NAMES ::
 *     The face contains glyph names, which can be retrieved using
 *     @FT_Get_Glyph_Name.  Note that some TrueType fonts contain broken
 *     glyph name tables.  Use the function @FT_Has_PS_Glyph_Names when
 *     needed.
 *
 *   FT_FACE_FLAG_EXTERNAL_STREAM ::
 *     Used internally by FreeType to indicate that a face's stream was
 *     provided by the client application and should not be destroyed when
 *     @FT_Done_Face is called.  Don't read or test this flag.
 *
 *   FT_FACE_FLAG_HINTER ::
 *     The font driver has a hinting machine of its own.  For example, with
 *     TrueType fonts, it makes sense to use data from the SFNT 'gasp'
 *     table only if the native TrueType hinting engine (with the bytecode
 *     interpreter) is available and active.
 *
 *   FT_FACE_FLAG_CID_KEYED ::
 *     The face is CID-keyed.  In that case, the face is not accessed by
 *     glyph indices but by CID values.  For subsetted CID-keyed fonts this
 *     has the consequence that not all index values are a valid argument
 *     to @FT_Load_Glyph.  Only the CID values for which corresponding
 *     glyphs in the subsetted font exist make `FT_Load_Glyph` return
 *     successfully; in all other cases you get an
 *     `FT_Err_Invalid_Argument` error.
 *
 *     Note that CID-keyed fonts that are in an SFNT wrapper (that is, all
 *     OpenType/CFF fonts) don't have this flag set since the glyphs are
 *     accessed in the normal way (using contiguous indices); the
 *     'CID-ness' isn't visible to the application.
 *
 *   FT_FACE_FLAG_TRICKY ::
 *     The face is 'tricky', that is, it always needs the font format's
 *     native hinting engine to get a reasonable result.  A typical example
 *     is the old Chinese font `mingli.ttf` (but not `mingliu.ttc`) that
 *     uses TrueType bytecode instructions to move and scale all of its
 *     subglyphs.
 *
 *     It is not possible to auto-hint such fonts using
 *     @FT_LOAD_FORCE_AUTOHINT; it will also ignore @FT_LOAD_NO_HINTING.
 *     You have to set both @FT_LOAD_NO_HINTING and @FT_LOAD_NO_AUTOHINT to
 *     really disable hinting; however, you probably never want this except
 *     for demonstration purposes.
 *
 *     Currently, there are about a dozen TrueType fonts in the list of
 *     tricky fonts; they are hard-coded in file `ttobjs.c`.
 *
 *   FT_FACE_FLAG_COLOR ::
 *     [Since 2.5.1] The face has color glyph tables.  See @FT_LOAD_COLOR
 *     for more information.
 *
 *   FT_FACE_FLAG_VARIATION ::
 *     [Since 2.9] Set if the current face (or named instance) has been
 *     altered with @FT_Set_MM_Design_Coordinates,
 *     @FT_Set_Var_Design_Coordinates, @FT_Set_Var_Blend_Coordinates, or
 *     @FT_Set_MM_WeightVector to select a non-default instance.
 *
 *   FT_FACE_FLAG_SVG ::
 *     [Since 2.12] The face has an 'SVG~' OpenType table.
 *
 *   FT_FACE_FLAG_SBIX ::
 *     [Since 2.12] The face has an 'sbix' OpenType table *and* outlines.
 *     For such fonts, @FT_FACE_FLAG_SCALABLE is not set by default to
 *     retain backward compatibility.
 *
 *   FT_FACE_FLAG_SBIX_OVERLAY ::
 *     [Since 2.12] The face has an 'sbix' OpenType table where outlines
 *     should be drawn on top of bitmap strikes.
 *
 */
Face_Flag :: enum {
	SCALABLE,
	FIXED_SIZES,
	FIXED_WIDTH,
	SFNT,
	HORIZONTAL,
	VERTICAL,
	KERNING,
	FAST_GLYPHS,
	MULTIPLE_MASTERS,
	GLYPH_NAMES,
	EXTERNAL_STREAM ,
	HINTER,
	CID_KEYED,
	TRICKY,
	COLOR,
	VARIATION,
	SVG,
	SBIX,
	SBIX_OVERLAY,
}

Face_Flags :: bit_set[Face_Flag; c.long]

/**************************************************************************
 *
 * @enum:
 *   FT_STYLE_FLAG_XXX
 *
 * @description:
 *   A list of bit flags to indicate the style of a given face.  These are
 *   used in the `style_flags` field of @FT_FaceRec.
 *
 * @values:
 *   FT_STYLE_FLAG_ITALIC ::
 *     The face style is italic or oblique.
 *
 *   FT_STYLE_FLAG_BOLD ::
 *     The face is bold.
 *
 * @note:
 *   The style information as provided by FreeType is very basic.  More
 *   details are beyond the scope and should be done on a higher level (for
 *   example, by analyzing various fields of the 'OS/2' table in SFNT based
 *   fonts).
 */
Style_Flag :: enum {
	ITALIC,
	BOLD,
}

Style_Flags :: bit_set[Style_Flag; c.long]

/**************************************************************************
 *
 * @type:
 *   FT_Pos
 *
 * @description:
 *   The type FT_Pos is used to store vectorial coordinates.  Depending on
 *   the context, these can represent distances in integer font units, or
 *   16.16, or 26.6 fixed-point pixel coordinates.
 */
Pos :: c.long

/**************************************************************************
 *
 * @struct:
 *   FT_Bitmap_Size
 *
 * @description:
 *   This structure models the metrics of a bitmap strike (i.e., a set of
 *   glyphs for a given point size and resolution) in a bitmap font.  It is
 *   used for the `available_sizes` field of @FT_Face.
 *
 * @fields:
 *   height ::
 *     The vertical distance, in pixels, between two consecutive baselines.
 *     It is always positive.
 *
 *   width ::
 *     The average width, in pixels, of all glyphs in the strike.
 *
 *   size ::
 *     The nominal size of the strike in 26.6 fractional points.  This
 *     field is not very useful.
 *
 *   x_ppem ::
 *     The horizontal ppem (nominal width) in 26.6 fractional pixels.
 *
 *   y_ppem ::
 *     The vertical ppem (nominal height) in 26.6 fractional pixels.
 *
 * @note:
 *   Windows FNT:
 *     The nominal size given in a FNT font is not reliable.  If the driver
 *     finds it incorrect, it sets `size` to some calculated values, and
 *     `x_ppem` and `y_ppem` to the pixel width and height given in the
 *     font, respectively.
 *
 *   TrueType embedded bitmaps:
 *     `size`, `width`, and `height` values are not contained in the bitmap
 *     strike itself.  They are computed from the global font parameters.
 */
Bitmap_Size :: struct {
	height: c.short,
	width:  c.short,

	size: Pos,

	x_ppem: Pos,
	y_ppem: Pos,
}

/**************************************************************************
 *
 * @enum:
 *   FT_Encoding
 *
 * @description:
 *   An enumeration to specify character sets supported by charmaps.  Used
 *   in the @FT_Select_Charmap API function.
 *
 * @note:
 *   Despite the name, this enumeration lists specific character
 *   repertoires (i.e., charsets), and not text encoding methods (e.g.,
 *   UTF-8, UTF-16, etc.).
 *
 *   Other encodings might be defined in the future.
 *
 * @values:
 *   FT_ENCODING_NONE ::
 *     The encoding value~0 is reserved for all formats except BDF, PCF,
 *     and Windows FNT; see below for more information.
 *
 *   FT_ENCODING_UNICODE ::
 *     The Unicode character set.  This value covers all versions of the
 *     Unicode repertoire, including ASCII and Latin-1.  Most fonts include
 *     a Unicode charmap, but not all of them.
 *
 *     For example, if you want to access Unicode value U+1F028 (and the
 *     font contains it), use value 0x1F028 as the input value for
 *     @FT_Get_Char_Index.
 *
 *   FT_ENCODING_MS_SYMBOL ::
 *     Microsoft Symbol encoding, used to encode mathematical symbols and
 *     wingdings.  For more information, see
 *     'https://learn.microsoft.com/typography/opentype/spec/recom#non-standard-symbol-fonts',
 *     'http://www.kostis.net/charsets/symbol.htm', and
 *     'http://www.kostis.net/charsets/wingding.htm'.
 *
 *     This encoding uses character codes from the PUA (Private Unicode
 *     Area) in the range U+F020-U+F0FF.
 *
 *   FT_ENCODING_SJIS ::
 *     Shift JIS encoding for Japanese.  More info at
 *     'https://en.wikipedia.org/wiki/Shift_JIS'.  See note on multi-byte
 *     encodings below.
 *
 *   FT_ENCODING_PRC ::
 *     Corresponds to encoding systems mainly for Simplified Chinese as
 *     used in People's Republic of China (PRC).  The encoding layout is
 *     based on GB~2312 and its supersets GBK and GB~18030.
 *
 *   FT_ENCODING_BIG5 ::
 *     Corresponds to an encoding system for Traditional Chinese as used in
 *     Taiwan and Hong Kong.
 *
 *   FT_ENCODING_WANSUNG ::
 *     Corresponds to the Korean encoding system known as Extended Wansung
 *     (MS Windows code page 949).  For more information see
 *     'https://www.unicode.org/Public/MAPPINGS/VENDORS/MICSFT/WindowsBestFit/bestfit949.txt'.
 *
 *   FT_ENCODING_JOHAB ::
 *     The Korean standard character set (KS~C 5601-1992), which
 *     corresponds to MS Windows code page 1361.  This character set
 *     includes all possible Hangul character combinations.
 *
 *   FT_ENCODING_ADOBE_LATIN_1 ::
 *     Corresponds to a Latin-1 encoding as defined in a Type~1 PostScript
 *     font.  It is limited to 256 character codes.
 *
 *   FT_ENCODING_ADOBE_STANDARD ::
 *     Adobe Standard encoding, as found in Type~1, CFF, and OpenType/CFF
 *     fonts.  It is limited to 256 character codes.
*
*   FT_ENCODING_ADOBE_EXPERT ::
*     Adobe Expert encoding, as found in Type~1, CFF, and OpenType/CFF
*     fonts.  It is limited to 256 character codes.
*
*   FT_ENCODING_ADOBE_CUSTOM ::
*     Corresponds to a custom encoding, as found in Type~1, CFF, and
*     OpenType/CFF fonts.  It is limited to 256 character codes.
*
*   FT_ENCODING_APPLE_ROMAN ::
*     Apple roman encoding.  Many TrueType and OpenType fonts contain a
*     charmap for this 8-bit encoding, since older versions of Mac OS are
*     able to use it.
*
*   FT_ENCODING_OLD_LATIN_2 ::
*     This value is deprecated and was neither used nor reported by
*     FreeType.  Don't use or test for it.
*
*   FT_ENCODING_MS_SJIS ::
*     Same as FT_ENCODING_SJIS.  Deprecated.
*
*   FT_ENCODING_MS_GB2312 ::
*     Same as FT_ENCODING_PRC.  Deprecated.
*
*   FT_ENCODING_MS_BIG5 ::
*     Same as FT_ENCODING_BIG5.  Deprecated.
*
*   FT_ENCODING_MS_WANSUNG ::
*     Same as FT_ENCODING_WANSUNG.  Deprecated.
*
*   FT_ENCODING_MS_JOHAB ::
*     Same as FT_ENCODING_JOHAB.  Deprecated.
*
* @note:
*   When loading a font, FreeType makes a Unicode charmap active if
*   possible (either if the font provides such a charmap, or if FreeType
	*   can synthesize one from PostScript glyph name dictionaries; in either
	*   case, the charmap is tagged with `FT_ENCODING_UNICODE`).  If such a
*   charmap is synthesized, it is placed at the first position of the
*   charmap array.
*
*   All other encodings are considered legacy and tagged only if
*   explicitly defined in the font file.  Otherwise, `FT_ENCODING_NONE` is
*   used.
*
*   `FT_ENCODING_NONE` is set by the BDF and PCF drivers if the charmap is
*   neither Unicode nor ISO-8859-1 (otherwise it is set to
	*   `FT_ENCODING_UNICODE`).  Use @FT_Get_BDF_Charset_ID to find out which
*   encoding is really present.  If, for example, the `cs_registry` field
*   is 'KOI8' and the `cs_encoding` field is 'R', the font is encoded in
*   KOI8-R.
*
*   `FT_ENCODING_NONE` is always set (with a single exception) by the
*   winfonts driver.  Use @FT_Get_WinFNT_Header and examine the `charset`
*   field of the @FT_WinFNT_HeaderRec structure to find out which encoding
*   is really present.  For example, @FT_WinFNT_ID_CP1251 (204) means
*   Windows code page 1251 (for Russian).
*
*   `FT_ENCODING_NONE` is set if `platform_id` is @TT_PLATFORM_MACINTOSH
*   and `encoding_id` is not `TT_MAC_ID_ROMAN` (otherwise it is set to
	*   `FT_ENCODING_APPLE_ROMAN`).
*
*   If `platform_id` is @TT_PLATFORM_MACINTOSH, use the function
*   @FT_Get_CMap_Language_ID to query the Mac language ID that may be
*   needed to be able to distinguish Apple encoding variants.  See
*
*     https://www.unicode.org/Public/MAPPINGS/VENDORS/APPLE/Readme.txt
*
*   to get an idea how to do that.  Basically, if the language ID is~0,
*   don't use it, otherwise subtract 1 from the language ID.  Then examine
*   `encoding_id`.  If, for example, `encoding_id` is `TT_MAC_ID_ROMAN`
*   and the language ID (minus~1) is `TT_MAC_LANGID_GREEK`, it is the
*   Greek encoding, not Roman.  `TT_MAC_ID_ARABIC` with
*   `TT_MAC_LANGID_FARSI` means the Farsi variant of the Arabic encoding.
*/
Encoding :: enum c.int {
	NONE = 0<<24 | 0<<16 | 0<<8 | 0,

	MS_SYMBOL = 's'<<24 | 'y'<<16 | 'm'<<8 | 'b',
	UNICODE   = 'u'<<24 | 'n'<<16 | 'i'<<8 | 'c',

	SJIS    = 's'<<24 | 'j'<<16 | 'i'<<8 | 's',
	PRC     = 'g'<<24 | 'b'<<16 | ' '<<8 | ' ',
	BIG5    = 'b'<<24 | 'i'<<16 | 'g'<<8 | '5',
	WANSUNG = 'w'<<24 | 'a'<<16 | 'n'<<8 | 's',
	JOHAB   = 'j'<<24 | 'o'<<16 | 'h'<<8 | 'a',

	GB2312     = PRC,
	MS_SJIS    = SJIS,
	MS_GB2312  = PRC,
	MS_BIG5    = BIG5,
	MS_WANSUNG = WANSUNG,
	MS_JOHAB   = JOHAB,

	ADOBE_STANDARD = 'A'<<24 | 'D'<<16 | 'O'<<8 | 'B',
	ADOBE_EXPERT   = 'A'<<24 | 'D'<<16 | 'B'<<8 | 'E',
	ADOBE_CUSTOM   = 'A'<<24 | 'D'<<16 | 'B'<<8 | 'C',
	ADOBE_LATIN_1  = 'l'<<24 | 'a'<<16 | 't'<<8 | '1',

	OLD_LATIN_2 = 'l'<<24 | 'a'<<16 | 't'<<8 | '2',

	APPLE_ROMAN = 'a'<<24 | 'r'<<16 | 'm'<<8 | 'n',
}

/**************************************************************************
 *
 * @struct:
 *   FT_CharMapRec
 *
 * @description:
 *   The base charmap structure.
 *
 * @fields:
 *   face ::
 *     A handle to the parent face object.
 *
 *   encoding ::
 *     An @FT_Encoding tag identifying the charmap.  Use this with
 *     @FT_Select_Charmap.
 *
 *   platform_id ::
 *     An ID number describing the platform for the following encoding ID.
 *     This comes directly from the TrueType specification and gets
 *     emulated for other formats.
 *
 *   encoding_id ::
 *     A platform-specific encoding number.  This also comes from the
 *     TrueType specification and gets emulated similarly.
 */
CharMap :: struct {
	face:        ^Face,
	encoding:    Encoding,
	platform_id: c.ushort,
	encoding_id: c.ushort,
}

/**************************************************************************
 *
 * @functype:
 *   FT_Generic_Finalizer
 *
 * @description:
 *   Describe a function used to destroy the 'client' data of any FreeType
 *   object.  See the description of the @FT_Generic type for details of
 *   usage.
 *
 * @input:
 *   The address of the FreeType object that is under finalization.  Its
 *   client data is accessed through its `generic` field.
 */
Generic_Finalizer :: #type proc "c"(object: rawptr)

/**************************************************************************
 *
 * @struct:
 *   FT_Generic
 *
 * @description:
 *   Client applications often need to associate their own data to a
 *   variety of FreeType core objects.  For example, a text layout API
 *   might want to associate a glyph cache to a given size object.
 *
 *   Some FreeType object contains a `generic` field, of type `FT_Generic`,
 *   which usage is left to client applications and font servers.
 *
 *   It can be used to store a pointer to client-specific data, as well as
 *   the address of a 'finalizer' function, which will be called by
 *   FreeType when the object is destroyed (for example, the previous
 *   client example would put the address of the glyph cache destructor in
 *   the `finalizer` field).
 *
 * @fields:
 *   data ::
 *     A typeless pointer to any client-specified data. This field is
 *     completely ignored by the FreeType library.
 *
 *   finalizer ::
 *     A pointer to a 'generic finalizer' function, which will be called
 *     when the object is destroyed.  If this field is set to `NULL`, no
 *     code will be called.
 */
Generic :: struct {
	data:      rawptr,
	finalizer: Generic_Finalizer,
}

/**************************************************************************
 *
 * @struct:
 *   FT_BBox
 *
 * @description:
 *   A structure used to hold an outline's bounding box, i.e., the
 *   coordinates of its extrema in the horizontal and vertical directions.
 *
 * @fields:
 *   xMin ::
 *     The horizontal minimum (left-most).
 *
 *   yMin ::
 *     The vertical minimum (bottom-most).
 *
 *   xMax ::
 *     The horizontal maximum (right-most).
 *
 *   yMax ::
 *     The vertical maximum (top-most).
 *
 * @note:
 *   The bounding box is specified with the coordinates of the lower left
 *   and the upper right corner.  In PostScript, those values are often
 *   called (llx,lly) and (urx,ury), respectively.
 *
 *   If `yMin` is negative, this value gives the glyph's descender.
 *   Otherwise, the glyph doesn't descend below the baseline.  Similarly,
 *   if `ymax` is positive, this value gives the glyph's ascender.
 *
 *   `xMin` gives the horizontal distance from the glyph's origin to the
 *   left edge of the glyph's bounding box.  If `xMin` is negative, the
 *   glyph extends to the left of the origin.
 */
BBox :: struct {
    xMin, yMin: Pos,
    xMax, yMax: Pos,
}

/**************************************************************************
 *
 * @struct:
 *   FT_Glyph_Metrics
 *
 * @description:
 *   A structure to model the metrics of a single glyph.  The values are
 *   expressed in 26.6 fractional pixel format; if the flag
 *   @FT_LOAD_NO_SCALE has been used while loading the glyph, values are
 *   expressed in font units instead.
 *
 * @fields:
 *   width ::
 *     The glyph's width.
 *
 *   height ::
 *     The glyph's height.
 *
 *   horiBearingX ::
 *     Left side bearing for horizontal layout.
 *
 *   horiBearingY ::
 *     Top side bearing for horizontal layout.
 *
 *   horiAdvance ::
 *     Advance width for horizontal layout.
 *
 *   vertBearingX ::
 *     Left side bearing for vertical layout.
 *
 *   vertBearingY ::
 *     Top side bearing for vertical layout.  Larger positive values mean
 *     further below the vertical glyph origin.
 *
 *   vertAdvance ::
 *     Advance height for vertical layout.  Positive values mean the glyph
 *     has a positive advance downward.
 *
 * @note:
 *   If not disabled with @FT_LOAD_NO_HINTING, the values represent
 *   dimensions of the hinted glyph (in case hinting is applicable).
 *
 *   Stroking a glyph with an outside border does not increase
 *   `horiAdvance` or `vertAdvance`; you have to manually adjust these
 *   values to account for the added width and height.
 *
 *   FreeType doesn't use the 'VORG' table data for CFF fonts because it
 *   doesn't have an interface to quickly retrieve the glyph height.  The
 *   y~coordinate of the vertical origin can be simply computed as
 *   `vertBearingY + height` after loading a glyph.
 */
Glyph_Metrics :: struct {
    width:  Pos,
    height: Pos,

    horiBearingX: Pos,
    horiBearingY: Pos,
    horiAdvance:  Pos,

    vertBearingX: Pos,
    vertBearingY: Pos,
    vertAdvance:  Pos,
}

/**************************************************************************
 *
 * @type:
 *   FT_Fixed
 *
 * @description:
 *   This type is used to store 16.16 fixed-point values, like scaling
 *   values or matrix coefficients.
 */
Fixed :: c.long

// NOTE: Original struct: struct { FT_Pos x; FT_Pos y; };

/**************************************************************************
 *
 * @struct:
 *   FT_Vector
 *
 * @description:
 *   A simple structure used to store a 2D vector; coordinates are of the
 *   FT_Pos type.
 *
 * @fields:
 *   x ::
 *     The horizontal coordinate.
 *   y ::
 *     The vertical coordinate.
 */
Vector :: [2]Pos

/**************************************************************************
 *
 * @enum:
 *   FT_Glyph_Format
 *
 * @description:
 *   An enumeration type used to describe the format of a given glyph
 *   image.  Note that this version of FreeType only supports two image
 *   formats, even though future font drivers will be able to register
 *   their own format.
 *
 * @values:
 *   FT_GLYPH_FORMAT_NONE ::
 *     The value~0 is reserved.
 *
 *   FT_GLYPH_FORMAT_COMPOSITE ::
 *     The glyph image is a composite of several other images.  This format
 *     is _only_ used with @FT_LOAD_NO_RECURSE, and is used to report
 *     compound glyphs (like accented characters).
 *
 *   FT_GLYPH_FORMAT_BITMAP ::
 *     The glyph image is a bitmap, and can be described as an @FT_Bitmap.
 *     You generally need to access the `bitmap` field of the
 *     @FT_GlyphSlotRec structure to read it.
 *
 *   FT_GLYPH_FORMAT_OUTLINE ::
 *     The glyph image is a vectorial outline made of line segments and
 *     Bezier arcs; it can be described as an @FT_Outline; you generally
 *     want to access the `outline` field of the @FT_GlyphSlotRec structure
 *     to read it.
 *
 *   FT_GLYPH_FORMAT_PLOTTER ::
 *     The glyph image is a vectorial path with no inside and outside
 *     contours.  Some Type~1 fonts, like those in the Hershey family,
 *     contain glyphs in this format.  These are described as @FT_Outline,
 *     but FreeType isn't currently capable of rendering them correctly.
 *
 *   FT_GLYPH_FORMAT_SVG ::
 *     [Since 2.12] The glyph is represented by an SVG document in the
 *     'SVG~' table.
 */
Glyph_Format :: enum c.int {
	NONE = 0<<24 | 0<<16 | 0<<8 | 0,

	COMPOSITE = 'c'<<24 | 'o'<<16 | 'm'<<8 | 'p',
	BITMAP    = 'b'<<24 | 'i'<<16 | 't'<<8 | 's',
	OUTLINE   = 'o'<<24 | 'u'<<16 | 't'<<8 | 'l',
	PLOTTER   = 'p'<<24 | 'l'<<16 | 'o'<<8 | 't',
	SVG       = 'S'<<24 | 'V'<<16 | 'G'<<8 | ' ',
}

/**************************************************************************
 *
 * @enum:
 *   FT_Pixel_Mode
 *
 * @description:
 *   An enumeration type used to describe the format of pixels in a given
 *   bitmap.  Note that additional formats may be added in the future.
 *
 * @values:
 *   FT_PIXEL_MODE_NONE ::
 *     Value~0 is reserved.
 *
 *   FT_PIXEL_MODE_MONO ::
 *     A monochrome bitmap, using 1~bit per pixel.  Note that pixels are
 *     stored in most-significant order (MSB), which means that the
 *     left-most pixel in a byte has value 128.
 *
 *   FT_PIXEL_MODE_GRAY ::
 *     An 8-bit bitmap, generally used to represent anti-aliased glyph
 *     images.  Each pixel is stored in one byte.  Note that the number of
 *     'gray' levels is stored in the `num_grays` field of the @FT_Bitmap
 *     structure (it generally is 256).
 *
 *   FT_PIXEL_MODE_GRAY2 ::
 *     A 2-bit per pixel bitmap, used to represent embedded anti-aliased
 *     bitmaps in font files according to the OpenType specification.  We
 *     haven't found a single font using this format, however.
 *
 *   FT_PIXEL_MODE_GRAY4 ::
 *     A 4-bit per pixel bitmap, representing embedded anti-aliased bitmaps
 *     in font files according to the OpenType specification.  We haven't
 *     found a single font using this format, however.
 *
 *   FT_PIXEL_MODE_LCD ::
 *     An 8-bit bitmap, representing RGB or BGR decimated glyph images used
 *     for display on LCD displays; the bitmap is three times wider than
 *     the original glyph image.  See also @FT_RENDER_MODE_LCD.
 *
 *   FT_PIXEL_MODE_LCD_V ::
 *     An 8-bit bitmap, representing RGB or BGR decimated glyph images used
 *     for display on rotated LCD displays; the bitmap is three times
 *     taller than the original glyph image.  See also
 *     @FT_RENDER_MODE_LCD_V.
 *
 *   FT_PIXEL_MODE_BGRA ::
 *     [Since 2.5] An image with four 8-bit channels per pixel,
 *     representing a color image (such as emoticons) with alpha channel.
 *     For each pixel, the format is BGRA, which means, the blue channel
 *     comes first in memory.  The color channels are pre-multiplied and in
 *     the sRGB colorspace.  For example, full red at half-translucent
 *     opacity will be represented as '00,00,80,80', not '00,00,FF,80'.
 *     See also @FT_LOAD_COLOR.
 */
Pixel_Mode :: enum c.uchar {
    NONE = 0,
    MONO,
    GRAY,
    GRAY2,
    GRAY4,
    LCD,
    LCD_V,
    BGRA,

    MAX      /* do not remove */ // NOTE: this comment is from the library itself
}

/**************************************************************************
 *
 * @struct:
 *   FT_Bitmap
 *
 * @description:
 *   A structure used to describe a bitmap or pixmap to the raster.  Note
 *   that we now manage pixmaps of various depths through the `pixel_mode`
 *   field.
 *
 * @fields:
 *   rows ::
 *     The number of bitmap rows.
 *
 *   width ::
 *     The number of pixels in bitmap row.
 *
 *   pitch ::
 *     The pitch's absolute value is the number of bytes taken by one
 *     bitmap row, including padding.  However, the pitch is positive when
 *     the bitmap has a 'down' flow, and negative when it has an 'up' flow.
 *     In all cases, the pitch is an offset to add to a bitmap pointer in
 *     order to go down one row.
 *
 *     Note that 'padding' means the alignment of a bitmap to a byte
 *     border, and FreeType functions normally align to the smallest
 *     possible integer value.
 *
 *     For the B/W rasterizer, `pitch` is always an even number.
 *
 *     To change the pitch of a bitmap (say, to make it a multiple of 4),
 *     use @FT_Bitmap_Convert.  Alternatively, you might use callback
 *     functions to directly render to the application's surface; see the
 *     file `example2.cpp` in the tutorial for a demonstration.
 *
 *   buffer ::
 *     A typeless pointer to the bitmap buffer.  This value should be
 *     aligned on 32-bit boundaries in most cases.
 *
 *   num_grays ::
 *     This field is only used with @FT_PIXEL_MODE_GRAY; it gives the
 *     number of gray levels used in the bitmap.
 *
 *   pixel_mode ::
 *     The pixel mode, i.e., how pixel bits are stored.  See @FT_Pixel_Mode
 *     for possible values.
 *
 *   palette_mode ::
 *     This field is intended for paletted pixel modes; it indicates how
 *     the palette is stored.  Not used currently.
 *
 *   palette ::
 *     A typeless pointer to the bitmap palette; this field is intended for
 *     paletted pixel modes.  Not used currently.
 *
 * @note:
 *   `width` and `rows` refer to the *physical* size of the bitmap, not the
 *   *logical* one.  For example, if @FT_Pixel_Mode is set to
 *   `FT_PIXEL_MODE_LCD`, the logical width is a just a third of the
 *   physical one.
 *
 *   An empty bitmap with a NULL `buffer` is valid, with `rows` and/or
 *   `pitch` also set to 0.  Such bitmaps might be produced while rendering
 *   empty or degenerate outlines.
 */
Bitmap :: struct {
	rows:         c.uint,
	width:        c.uint,
	pitch:        c.int,
	buffer:       [^]c.uchar,
	num_grays:    c.ushort,
	pixel_mode:   Pixel_Mode,
	palette_mode: c.uchar,
	palette:      rawptr,
}

/**************************************************************************
 *
 * @enum:
 *   FT_OUTLINE_XXX
 *
 * @description:
 *   A list of bit-field constants used for the flags in an outline's
 *   `flags` field.
 *
 * @values:
 *   FT_OUTLINE_NONE ::
 *     Value~0 is reserved.
 *
 *   FT_OUTLINE_OWNER ::
 *     If set, this flag indicates that the outline's field arrays (i.e.,
 *     `points`, `flags`, and `contours`) are 'owned' by the outline
 *     object, and should thus be freed when it is destroyed.
 *
 *   FT_OUTLINE_EVEN_ODD_FILL ::
 *     By default, outlines are filled using the non-zero winding rule.  If
 *     set to 1, the outline will be filled using the even-odd fill rule
 *     (only works with the smooth rasterizer).
 *
 *   FT_OUTLINE_REVERSE_FILL ::
 *     By default, outside contours of an outline are oriented in
 *     clock-wise direction, as defined in the TrueType specification.
 *     This flag is set if the outline uses the opposite direction
 *     (typically for Type~1 fonts).  This flag is ignored by the scan
 *     converter.
 *
 *   FT_OUTLINE_IGNORE_DROPOUTS ::
 *     By default, the scan converter will try to detect drop-outs in an
 *     outline and correct the glyph bitmap to ensure consistent shape
 *     continuity.  If set, this flag hints the scan-line converter to
 *     ignore such cases.  See below for more information.
 *
 *   FT_OUTLINE_SMART_DROPOUTS ::
 *     Select smart dropout control.  If unset, use simple dropout control.
 *     Ignored if @FT_OUTLINE_IGNORE_DROPOUTS is set.  See below for more
 *     information.
 *
 *   FT_OUTLINE_INCLUDE_STUBS ::
 *     If set, turn pixels on for 'stubs', otherwise exclude them.  Ignored
 *     if @FT_OUTLINE_IGNORE_DROPOUTS is set.  See below for more
 *     information.
 *
 *   FT_OUTLINE_OVERLAP ::
 *     [Since 2.10.3] This flag indicates that this outline contains
 *     overlapping contours and the anti-aliased renderer should perform
 *     oversampling to mitigate possible artifacts.  This flag should _not_
 *     be set for well designed glyphs without overlaps because it quadruples
 *     the rendering time.
 *
 *   FT_OUTLINE_HIGH_PRECISION ::
 *     This flag indicates that the scan-line converter should try to
 *     convert this outline to bitmaps with the highest possible quality.
 *     It is typically set for small character sizes.  Note that this is
 *     only a hint that might be completely ignored by a given
 *     scan-converter.
 *
 *   FT_OUTLINE_SINGLE_PASS ::
 *     This flag is set to force a given scan-converter to only use a
 *     single pass over the outline to render a bitmap glyph image.
 *     Normally, it is set for very large character sizes.  It is only a
 *     hint that might be completely ignored by a given scan-converter.
 *
 * @note:
 *   The flags @FT_OUTLINE_IGNORE_DROPOUTS, @FT_OUTLINE_SMART_DROPOUTS, and
 *   @FT_OUTLINE_INCLUDE_STUBS are ignored by the smooth rasterizer.
 *
 *   There exists a second mechanism to pass the drop-out mode to the B/W
 *   rasterizer; see the `tags` field in @FT_Outline.
 *
 *   Please refer to the description of the 'SCANTYPE' instruction in the
 *   [OpenType specification](https://learn.microsoft.com/typography/opentype/spec/tt_instructions#scantype)
 *   how simple drop-outs, smart drop-outs, and stubs are defined.
 */
Outline_Flag :: enum {
	OWNER           = intrinsics.constant_log2(0x1),
	EVEN_ODD_FILL   = intrinsics.constant_log2(0x2),
	REVERSE_FILL    = intrinsics.constant_log2(0x4),
	IGNORE_DROPOUTS = intrinsics.constant_log2(0x8),
	SMART_DROPOUTS  = intrinsics.constant_log2(0x10),
	INCLUDE_STUBS   = intrinsics.constant_log2(0x20),
	OVERLAP         = intrinsics.constant_log2(0x40),

	HIGH_PRECISION  = intrinsics.constant_log2(0x100),
	SINGLE_PASS     = intrinsics.constant_log2(0x200),
}

Outline_Flags :: bit_set[Outline_Flag; c.int]

/**************************************************************************
 *
 * @struct:
 *   FT_Outline
 *
 * @description:
 *   This structure is used to describe an outline to the scan-line
 *   converter.
 *
 * @fields:
 *   n_contours ::
 *     The number of contours in the outline.
 *
 *   n_points ::
 *     The number of points in the outline.
 *
 *   points ::
 *     A pointer to an array of `n_points` @FT_Vector elements, giving the
 *     outline's point coordinates.
 *
 *   tags ::
 *     A pointer to an array of `n_points` chars, giving each outline
 *     point's type.
 *
 *     If bit~0 is unset, the point is 'off' the curve, i.e., a Bezier
 *     control point, while it is 'on' if set.
 *
 *     Bit~1 is meaningful for 'off' points only.  If set, it indicates a
 *     third-order Bezier arc control point; and a second-order control
 *     point if unset.
 *
 *     If bit~2 is set, bits 5-7 contain the drop-out mode (as defined in
 *     the OpenType specification; the value is the same as the argument to
 *     the 'SCANTYPE' instruction).
 *
 *     Bits 3 and~4 are reserved for internal purposes.
 *
 *   contours ::
 *     An array of `n_contours` shorts, giving the end point of each
 *     contour within the outline.  For example, the first contour is
 *     defined by the points '0' to `contours[0]`, the second one is
 *     defined by the points `contours[0]+1` to `contours[1]`, etc.
 *
 *   flags ::
 *     A set of bit flags used to characterize the outline and give hints
 *     to the scan-converter and hinter on how to convert/grid-fit it.  See
 *     @FT_OUTLINE_XXX.
 *
 * @note:
 *   The B/W rasterizer only checks bit~2 in the `tags` array for the first
 *   point of each contour.  The drop-out mode as given with
 *   @FT_OUTLINE_IGNORE_DROPOUTS, @FT_OUTLINE_SMART_DROPOUTS, and
 *   @FT_OUTLINE_INCLUDE_STUBS in `flags` is then overridden.
 */
Outline :: struct {
	n_contours: c.ushort,
	n_points:   c.ushort,

	points:   [^]Vector,
	tags:     [^]c.uchar,
	contours: [^]c.ushort,

	flags: Outline_Flags,
}

/**************************************************************************
 *
 * @struct:
 *   FT_SubGlyph
 *
 * @description:
 *   The subglyph structure is an internal object used to describe
 *   subglyphs (for example, in the case of composites).
 *
 * @note:
 *   The subglyph implementation is not part of the high-level API, hence
 *   the forward structure declaration.
 *
 *   You can however retrieve subglyph information with
 *   @FT_Get_SubGlyph_Info.
 */
SubGlyph :: struct {}

/**************************************************************************
 *
 * @type:
 *   FT_Slot_Internal
 *
 * @description:
 *   An opaque handle to an `FT_Slot_InternalRec` structure, used to model
 *   private data of a given @FT_GlyphSlot object.
 */
Slot_Internal :: struct {}

/**************************************************************************
 *
 * @struct:
 *   FT_GlyphSlotRec
 *
 * @description:
 *   FreeType root glyph slot class structure.  A glyph slot is a container
 *   where individual glyphs can be loaded, be they in outline or bitmap
 *   format.
 *
 * @fields:
 *   library ::
 *     A handle to the FreeType library instance this slot belongs to.
 *
 *   face ::
 *     A handle to the parent face object.
 *
 *   next ::
 *     In some cases (like some font tools), several glyph slots per face
 *     object can be a good thing.  As this is rare, the glyph slots are
 *     listed through a direct, single-linked list using its `next` field.
 *
 *   glyph_index ::
 *     [Since 2.10] The glyph index passed as an argument to @FT_Load_Glyph
 *     while initializing the glyph slot.
 *
 *   generic ::
 *     A typeless pointer unused by the FreeType library or any of its
 *     drivers.  It can be used by client applications to link their own
 *     data to each glyph slot object.
 *
 *   metrics ::
 *     The metrics of the last loaded glyph in the slot.  The returned
 *     values depend on the last load flags (see the @FT_Load_Glyph API
 *     function) and can be expressed either in 26.6 fractional pixels or
 *     font units.
 *
 *     Note that even when the glyph image is transformed, the metrics are
 *     not.
 *
 *   linearHoriAdvance ::
 *     The advance width of the unhinted glyph.  Its value is expressed in
 *     16.16 fractional pixels, unless @FT_LOAD_LINEAR_DESIGN is set when
 *     loading the glyph.  This field can be important to perform correct
 *     WYSIWYG layout.  Only relevant for scalable glyphs.
 *
 *   linearVertAdvance ::
 *     The advance height of the unhinted glyph.  Its value is expressed in
 *     16.16 fractional pixels, unless @FT_LOAD_LINEAR_DESIGN is set when
 *     loading the glyph.  This field can be important to perform correct
 *     WYSIWYG layout.  Only relevant for scalable glyphs.
 *
 *   advance ::
 *     This shorthand is, depending on @FT_LOAD_IGNORE_TRANSFORM, the
 *     transformed (hinted) advance width for the glyph, in 26.6 fractional
 *     pixel format.  As specified with @FT_LOAD_VERTICAL_LAYOUT, it uses
 *     either the `horiAdvance` or the `vertAdvance` value of `metrics`
 *     field.
 *
 *   format ::
 *     This field indicates the format of the image contained in the glyph
 *     slot.  Typically @FT_GLYPH_FORMAT_BITMAP, @FT_GLYPH_FORMAT_OUTLINE,
 *     or @FT_GLYPH_FORMAT_COMPOSITE, but other values are possible.
 *
 *   bitmap ::
 *     This field is used as a bitmap descriptor.  Note that the address
 *     and content of the bitmap buffer can change between calls of
 *     @FT_Load_Glyph and a few other functions.
 *
 *   bitmap_left ::
 *     The bitmap's left bearing expressed in integer pixels.
*
	*   bitmap_top ::
		*     The bitmap's top bearing expressed in integer pixels.  This is the
		   *     distance from the baseline to the top-most glyph scanline, upwards
		   *     y~coordinates being **positive**.
		   *
		   *   outline ::
		   *     The outline descriptor for the current glyph image if its format is
		   *     @FT_GLYPH_FORMAT_OUTLINE.  Once a glyph is loaded, `outline` can be
		   *     transformed, distorted, emboldened, etc.  However, it must not be
		   *     freed.
		   *
		   *     [Since 2.10.1] If @FT_LOAD_NO_SCALE is set, outline coordinates of
	*     OpenType Font Variations for a selected instance are internally
		*     handled as 26.6 fractional font units but returned as (rounded)
		   *     integers, as expected.  To get unrounded font units, don't use
		   *     @FT_LOAD_NO_SCALE but load the glyph with @FT_LOAD_NO_HINTING and
		   *     scale it, using the font's `units_per_EM` value as the ppem.
		   *
		   *   num_subglyphs ::
		   *     The number of subglyphs in a composite glyph.  This field is only
		   *     valid for the composite glyph format that should normally only be
		   *     loaded with the @FT_LOAD_NO_RECURSE flag.
		   *
		   *   subglyphs ::
		   *     An array of subglyph descriptors for composite glyphs.  There are
		   *     `num_subglyphs` elements in there.  Currently internal to FreeType.
		   *
		   *   control_data ::
		   *     Certain font drivers can also return the control data for a given
		   *     glyph image (e.g.  TrueType bytecode, Type~1 charstrings, etc.).
		   *     This field is a pointer to such data; it is currently internal to
		   *     FreeType.
		   *
		   *   control_len ::
		   *     This is the length in bytes of the control data.  Currently internal
		   *     to FreeType.
		   *
		   *   other ::
		   *     Reserved.
		   *
		   *   lsb_delta ::
		   *     The difference between hinted and unhinted left side bearing while
		   *     auto-hinting is active.  Zero otherwise.
		   *
		   *   rsb_delta ::
		   *     The difference between hinted and unhinted right side bearing while
		   *     auto-hinting is active.  Zero otherwise.
		   *
		   * @note:
*   If @FT_Load_Glyph is called with default flags (see @FT_LOAD_DEFAULT)
	*   the glyph image is loaded in the glyph slot in its native format
	*   (e.g., an outline glyph for TrueType and Type~1 formats).  [Since 2.9]
	*   The prospective bitmap metrics are calculated according to
	*   @FT_LOAD_TARGET_XXX and other flags even for the outline glyph, even
	*   if @FT_LOAD_RENDER is not set.
	*
	*   This image can later be converted into a bitmap by calling
	*   @FT_Render_Glyph.  This function searches the current renderer for the
	*   native image's format, then invokes it.
	*
	*   The renderer is in charge of transforming the native image through the
	*   slot's face transformation fields, then converting it into a bitmap
	*   that is returned in `slot->bitmap`.
	*
	*   Note that `slot->bitmap_left` and `slot->bitmap_top` are also used to
	*   specify the position of the bitmap relative to the current pen
	*   position (e.g., coordinates (0,0) on the baseline).  Of course,
	*   `slot->format` is also changed to @FT_GLYPH_FORMAT_BITMAP.
	*
	*   Here is a small pseudo code fragment that shows how to use `lsb_delta`
	*   and `rsb_delta` to do fractional positioning of glyphs:
	*
	*   ```
	*     FT_GlyphSlot  slot     = face->glyph;
	*     FT_Pos        origin_x = 0;
	*
	*
	*     for all glyphs do
	*       <load glyph with `FT_Load_Glyph'>
	*
	*       FT_Outline_Translate( slot->outline, origin_x & 63, 0 );
	*
	*       <save glyph image, or render glyph, or ...>
	*
	*       <compute kern between current and next glyph
	*        and add it to `origin_x'>
	*
	*       origin_x += slot->advance.x;
	*       origin_x += slot->lsb_delta - slot->rsb_delta;
	*     endfor
	*   ```
	*
	*   Here is another small pseudo code fragment that shows how to use
	*   `lsb_delta` and `rsb_delta` to improve integer positioning of glyphs:
	*
	*   ```
	*     FT_GlyphSlot  slot           = face->glyph;
	*     FT_Pos        origin_x       = 0;
	*     FT_Pos        prev_rsb_delta = 0;
	*
	*
	*     for all glyphs do
	*       <compute kern between current and previous glyph
	*        and add it to `origin_x'>
	*
	*       <load glyph with `FT_Load_Glyph'>
	*
	*       if ( prev_rsb_delta - slot->lsb_delta >  32 )
	*         origin_x -= 64;
	*       else if ( prev_rsb_delta - slot->lsb_delta < -31 )
	*         origin_x += 64;
	*
	*       prev_rsb_delta = slot->rsb_delta;
	*
	*       <save glyph image, or render glyph, or ...>
	*
	*       origin_x += slot->advance.x;
	*     endfor
	*   ```
	*
	*   If you use strong auto-hinting, you **must** apply these delta values!
	*   Otherwise you will experience far too large inter-glyph spacing at
	*   small rendering sizes in most cases.  Note that it doesn't harm to use
	*   the above code for other hinting modes also, since the delta values
	*   are zero then.
	*/
GlyphSlot :: struct {
	library:     ^Library,
	face:        ^Face,
	next:        ^GlyphSlot,
	glyph_index: c.uint,
	generic:     Generic,

	metrics:           Glyph_Metrics,
	linearHoriAdvance: Fixed,
	linearVertAdvance: Fixed,
	advance:           Vector,

	format: Glyph_Format,

	bitmap:      Bitmap,
	bitmap_left: c.int,
	bitmap_top:  c.int,

	outline: Outline,
	
	num_subglyphs: c.uint,
	subglyphs:     ^SubGlyph,

	control_data: rawptr,
	control_len:  c.long,

	lsb_delta: Pos,
	rsb_delta: Pos,

	other: rawptr,

	internal: ^Slot_Internal,
}

/**************************************************************************
 *
 * @struct:
 *   FT_Size_Metrics
 *
 * @description:
 *   The size metrics structure gives the metrics of a size object.
 *
 * @fields:
 *   x_ppem ::
 *     The width of the scaled EM square in pixels, hence the term 'ppem'
 *     (pixels per EM).  It is also referred to as 'nominal width'.
 *
 *   y_ppem ::
 *     The height of the scaled EM square in pixels, hence the term 'ppem'
 *     (pixels per EM).  It is also referred to as 'nominal height'.
 *
 *   x_scale ::
 *     A 16.16 fractional scaling value to convert horizontal metrics from
 *     font units to 26.6 fractional pixels.  Only relevant for scalable
 *     font formats.
 *
 *   y_scale ::
 *     A 16.16 fractional scaling value to convert vertical metrics from
 *     font units to 26.6 fractional pixels.  Only relevant for scalable
 *     font formats.
 *
 *   ascender ::
 *     The ascender in 26.6 fractional pixels, rounded up to an integer
 *     value.  See @FT_FaceRec for the details.
 *
 *   descender ::
 *     The descender in 26.6 fractional pixels, rounded down to an integer
 *     value.  See @FT_FaceRec for the details.
 *
 *   height ::
 *     The height in 26.6 fractional pixels, rounded to an integer value.
 *     See @FT_FaceRec for the details.
 *
 *   max_advance ::
 *     The maximum advance width in 26.6 fractional pixels, rounded to an
 *     integer value.  See @FT_FaceRec for the details.
 *
 * @note:
 *   The scaling values, if relevant, are determined first during a size
 *   changing operation.  The remaining fields are then set by the driver.
 *   For scalable formats, they are usually set to scaled values of the
 *   corresponding fields in @FT_FaceRec.  Some values like ascender or
 *   descender are rounded for historical reasons; more precise values (for
 *   outline fonts) can be derived by scaling the corresponding @FT_FaceRec
 *   values manually, with code similar to the following.
 *
 *   ```
 *     scaled_ascender = FT_MulFix( face->ascender,
 *                                  size_metrics->y_scale );
 *   ```
 *
 *   Note that due to glyph hinting and the selected rendering mode these
 *   values are usually not exact; consequently, they must be treated as
 *   unreliable with an error margin of at least one pixel!
 *
 *   Indeed, the only way to get the exact metrics is to render _all_
 *   glyphs.  As this would be a definite performance hit, it is up to
 *   client applications to perform such computations.
 *
 *   The `FT_Size_Metrics` structure is valid for bitmap fonts also.
 *
 *
 *   **TrueType fonts with native bytecode hinting**
 *
 *   All applications that handle TrueType fonts with native hinting must
*   be aware that TTFs expect different rounding of vertical font
*   dimensions.  The application has to cater for this, especially if it
*   wants to rely on a TTF's vertical data (for example, to properly align
	*   box characters vertically).
*
*   Only the application knows _in advance_ that it is going to use native
*   hinting for TTFs!  FreeType, on the other hand, selects the hinting
*   mode not at the time of creating an @FT_Size object but much later,
*   namely while calling @FT_Load_Glyph.
*
*   Here is some pseudo code that illustrates a possible solution.
*
*   ```
*     font_format = FT_Get_Font_Format( face );
*
*     if ( !strcmp( font_format, "TrueType" ) &&
	*          do_native_bytecode_hinting         )
*     {
	*       ascender  = ROUND( FT_MulFix( face->ascender,
			*                                     size_metrics->y_scale ) );
	*       descender = ROUND( FT_MulFix( face->descender,
			*                                     size_metrics->y_scale ) );
	*     }
	*     else
	*     {
		*       ascender  = size_metrics->ascender;
		*       descender = size_metrics->descender;
		*     }
		*
		*     height      = size_metrics->height;
		*     max_advance = size_metrics->max_advance;
		*   ```
		*/
Size_Metrics :: struct {
	x_ppem:      c.ushort, /* horizontal pixels per EM               */
	y_ppem:      c.ushort, /* vertical pixels per EM                 */

	x_scale:     Fixed,    /* scaling values used to convert font    */
	y_scale:     Fixed,    /* units to 26.6 fractional pixels        */

	ascender:    Pos,      /* ascender in 26.6 frac. pixels          */
	descender:   Pos,      /* descender in 26.6 frac. pixels         */
	height:      Pos,      /* text height in 26.6 frac. pixels       */
	max_advance: Pos,      /* max horizontal advance, in 26.6 pixels */
}

/**************************************************************************
 *
 * @type:
 *   FT_Size_Internal
 *
 * @description:
 *   An opaque handle to an `FT_Size_InternalRec` structure, used to model
 *   private data of a given @FT_Size object.
 */
Size_Internal :: struct {}

/**************************************************************************
 *
 * @struct:
 *   FT_SizeRec
 *
 * @description:
 *   FreeType root size class structure.  A size object models a face
 *   object at a given size.
 *
 * @fields:
 *   face ::
 *     Handle to the parent face object.
 *
 *   generic ::
 *     A typeless pointer, unused by the FreeType library or any of its
 *     drivers.  It can be used by client applications to link their own
 *     data to each size object.
 *
 *   metrics ::
 *     Metrics for this size object.  This field is read-only.
 */
Size :: struct {
	face:     ^Face,
	generic:  Generic,
	metrics:  Size_Metrics,
	internal: ^Size_Internal,
}

/**************************************************************************
 *
 * @type:
 *   FT_Driver
 *
 * @description:
 *   A handle to a given FreeType font driver object.  A font driver is a
 *   module capable of creating faces from font files.
 */
Driver :: struct {}

/**************************************************************************
 *
 * @type:
 *   FT_Memory
 *
 * @description:
 *   A handle to a given memory manager object, defined with an
 *   @FT_MemoryRec structure.
 *
 */
Memory :: struct {}

/**************************************************************************
 *
 * @struct:
 *   FT_StreamDesc
 *
 * @description:
 *   A union type used to store either a long or a pointer.  This is used
 *   to store a file descriptor or a `FILE*` in an input stream.
 *
 */
StreamDesc :: struct #raw_union {
	value:   c.long,
	pointer: rawptr,
}

/**************************************************************************
 *
 * @functype:
 *   FT_Stream_IoFunc
 *
 * @description:
 *   A function used to seek and read data from a given input stream.
 *
 * @input:
 *   stream ::
 *     A handle to the source stream.
 *
 *   offset ::
 *     The offset from the start of the stream to seek to.
 *
 *   buffer ::
 *     The address of the read buffer.
 *
 *   count ::
 *     The number of bytes to read from the stream.
 *
 * @return:
 *   If count >~0, return the number of bytes effectively read by the
 *   stream (after seeking to `offset`).  If count ==~0, return the status
 *   of the seek operation (non-zero indicates an error).
 *
 */
Stream_IoFunc :: proc "c" (stream: ^Stream, offset: c.ulong, buffer: [^]c.uchar, count: c.ulong) -> c.ulong

/**************************************************************************
 *
 * @functype:
 *   FT_Stream_CloseFunc
 *
 * @description:
 *   A function used to close a given input stream.
 *
 * @input:
 *  stream ::
 *    A handle to the target stream.
 *
 */
Stream_CloseFunc :: proc "c" (stream: ^Stream)

/**************************************************************************
 *
 * @struct:
 *   FT_StreamRec
 *
 * @description:
 *   A structure used to describe an input stream.
 *
 * @input:
 *   base ::
 *     For memory-based streams, this is the address of the first stream
 *     byte in memory.  This field should always be set to `NULL` for
 *     disk-based streams.
 *
 *   size ::
 *     The stream size in bytes.
 *
 *     In case of compressed streams where the size is unknown before
 *     actually doing the decompression, the value is set to 0x7FFFFFFF.
 *     (Note that this size value can occur for normal streams also; it is
 *     thus just a hint.)
 *
 *   pos ::
 *     The current position within the stream.
 *
 *   descriptor ::
 *     This field is a union that can hold an integer or a pointer.  It is
 *     used by stream implementations to store file descriptors or `FILE*`
 *     pointers.
 *
 *   pathname ::
 *     This field is completely ignored by FreeType.  However, it is often
 *     useful during debugging to use it to store the stream's filename
 *     (where available).
 *
 *   read ::
 *     The stream's input function.
 *
 *   close ::
 *     The stream's close function.
 *
 *   memory ::
 *     The memory manager to use to preload frames.  This is set internally
 *     by FreeType and shouldn't be touched by stream implementations.
 *
 *   cursor ::
 *     This field is set and used internally by FreeType when parsing
 *     frames.  In particular, the `FT_GET_XXX` macros use this instead of
 *     the `pos` field.
 *
 *   limit ::
 *     This field is set and used internally by FreeType when parsing
 *     frames.
 *
 */
Stream :: struct {
	base:       [^]c.uchar,
	size:       c.ulong,
	pos:        c.ulong,

	descriptor: StreamDesc,
	pathname:   StreamDesc,
	read:       Stream_IoFunc,
	close:      Stream_CloseFunc,

	memory:     ^Memory,
	cursor:     ^c.uchar,
	limit:      ^c.uchar,
}

/**************************************************************************
 *
 * @struct:
 *   FT_ListNodeRec
 *
 * @description:
 *   A structure used to hold a single list element.
 *
 * @fields:
 *   prev ::
 *     The previous element in the list.  `NULL` if first.
 *
 *   next ::
 *     The next element in the list.  `NULL` if last.
 *
 *   data ::
 *     A typeless pointer to the listed object.
 */
ListNode :: struct {
	prev: ^ListNode,
	next: ^ListNode,
	data: rawptr,
}

/**************************************************************************
 *
 * @struct:
 *   FT_ListRec
 *
 * @description:
 *   A structure used to hold a simple doubly-linked list.  These are used
 *   in many parts of FreeType.
 *
 * @fields:
 *   head ::
 *     The head (first element) of doubly-linked list.
 *
 *   tail ::
 *     The tail (last element) of doubly-linked list.
 */
List :: struct {
	head: ^ListNode,
	tail: ^ListNode,
}

/**************************************************************************
 *
 * @type:
 *   FT_Face_Internal
 *
 * @description:
 *   An opaque handle to an `FT_Face_InternalRec` structure that models the
 *   private data of a given @FT_Face object.
 *
 *   This structure might change between releases of FreeType~2 and is not
 *   generally available to client applications.
 */
Face_Internal :: struct {}

/**************************************************************************
 *
 * @struct:
 *   FT_FaceRec
 *
 * @description:
 *   FreeType root face class structure.  A face object models a typeface
 *   in a font file.
 *
 * @fields:
 *   num_faces ::
 *     The number of faces in the font file.  Some font formats can have
 *     multiple faces in a single font file.
 *
 *   face_index ::
 *     This field holds two different values.  Bits 0-15 are the index of
 *     the face in the font file (starting with value~0).  They are set
 *     to~0 if there is only one face in the font file.
 *
 *     [Since 2.6.1] Bits 16-30 are relevant to TrueType GX and OpenType
 *     Font Variations only, holding the named instance index for the
 *     current face index (starting with value~1; value~0 indicates font
 *     access without a named instance).  For non-variation fonts, bits
 *     16-30 are ignored.  If we have the third named instance of face~4,
 *     say, `face_index` is set to 0x00030004.
 *
 *     Bit 31 is always zero (that is, `face_index` is always a positive
 *     value).
 *
 *     [Since 2.9] Changing the design coordinates with
 *     @FT_Set_Var_Design_Coordinates or @FT_Set_Var_Blend_Coordinates does
 *     not influence the named instance index value (only
 *     @FT_Set_Named_Instance does that).
 *
 *   face_flags ::
 *     A set of bit flags that give important information about the face;
 *     see @FT_FACE_FLAG_XXX for the details.
 *
 *   style_flags ::
 *     The lower 16~bits contain a set of bit flags indicating the style of
 *     the face; see @FT_STYLE_FLAG_XXX for the details.
 *
 *     [Since 2.6.1] Bits 16-30 hold the number of named instances
 *     available for the current face if we have a TrueType GX or OpenType
 *     Font Variation.  Bit 31 is always zero (that is, `style_flags` is
 *     always a positive value).  Note that a variation font has always at
 *     least one named instance, namely the default instance.
 *
 *   num_glyphs ::
 *     The number of glyphs in the face.  If the face is scalable and has
 *     sbits (see `num_fixed_sizes`), it is set to the number of outline
 *     glyphs.
 *
 *     For CID-keyed fonts (not in an SFNT wrapper) this value gives the
 *     highest CID used in the font.
 *
 *   family_name ::
 *     The face's family name.  This is an ASCII string, usually in
 *     English, that describes the typeface's family (like 'Times New
 *     Roman', 'Bodoni', 'Garamond', etc).  This is a least common
 *     denominator used to list fonts.  Some formats (TrueType & OpenType)
 *     provide localized and Unicode versions of this string.  Applications
 *     should use the format-specific interface to access them.  Can be
 *     `NULL` (e.g., in fonts embedded in a PDF file).
 *
 *     In case the font doesn't provide a specific family name entry,
	  *     FreeType tries to synthesize one, deriving it from other name
 *     entries.
 *
 *   style_name ::
 *     The face's style name.  This is an ASCII string, usually in English,
*     that describes the typeface's style (like 'Italic', 'Bold',
	*     'Condensed', etc).  Not all font formats provide a style name, so
*     this field is optional, and can be set to `NULL`.  As for
*     `family_name`, some formats provide localized and Unicode versions
*     of this string.  Applications should use the format-specific
*     interface to access them.
*
*   num_fixed_sizes ::
*     The number of bitmap strikes in the face.  Even if the face is
*     scalable, there might still be bitmap strikes, which are called
*     'sbits' in that case.
*
*   available_sizes ::
*     An array of @FT_Bitmap_Size for all bitmap strikes in the face.  It
*     is set to `NULL` if there is no bitmap strike.
*
*     Note that FreeType tries to sanitize the strike data since they are
*     sometimes sloppy or incorrect, but this can easily fail.
*
*   num_charmaps ::
*     The number of charmaps in the face.
*
*   charmaps ::
*     An array of the charmaps of the face.
*
*   generic ::
*     A field reserved for client uses.  See the @FT_Generic type
*     description.
*
*   bbox ::
*     The font bounding box.  Coordinates are expressed in font units (see
	*     `units_per_EM`).  The box is large enough to contain any glyph from
*     the font.  Thus, `bbox.yMax` can be seen as the 'maximum ascender',
*     and `bbox.yMin` as the 'minimum descender'.  Only relevant for
*     scalable formats.
*
*     Note that the bounding box might be off by (at least) one pixel for
*     hinted fonts.  See @FT_Size_Metrics for further discussion.
*
*     Note that the bounding box does not vary in OpenType Font Variations
*     and should only be used in relation to the default instance.
*
*   units_per_EM ::
*     The number of font units per EM square for this face.  This is
*     typically 2048 for TrueType fonts, and 1000 for Type~1 fonts.  Only
*     relevant for scalable formats.
*
*   ascender ::
*     The typographic ascender of the face, expressed in font units.  For
*     font formats not having this information, it is set to `bbox.yMax`.
*     Only relevant for scalable formats.
*
*   descender ::
*     The typographic descender of the face, expressed in font units.  For
*     font formats not having this information, it is set to `bbox.yMin`.
*     Note that this field is negative for values below the baseline.
*     Only relevant for scalable formats.
*
*   height ::
*     This value is the vertical distance between two consecutive
*     baselines, expressed in font units.  It is always positive.  Only
*     relevant for scalable formats.
*
*     If you want the global glyph height, use `ascender - descender`.
*
*   max_advance_width ::
*     The maximum advance width, in font units, for all glyphs in this
*     face.  This can be used to make word wrapping computations faster.
*     Only relevant for scalable formats.
*
*   max_advance_height ::
*     The maximum advance height, in font units, for all glyphs in this
*     face.  This is only relevant for vertical layouts, and is set to
*     `height` for fonts that do not provide vertical metrics.  Only
*     relevant for scalable formats.
*
*   underline_position ::
*     The position, in font units, of the underline line for this face.
*     It is the center of the underlining stem.  Only relevant for
*     scalable formats.
*
*   underline_thickness ::
*     The thickness, in font units, of the underline for this face.  Only
*     relevant for scalable formats.
*
*   glyph ::
*     The face's associated glyph slot(s).
*
*   size ::
*     The current active size for this face.
*
*   charmap ::
*     The current active charmap for this face.
*
* @note:
*   Fields may be changed after a call to @FT_Attach_File or
*   @FT_Attach_Stream.
*
*   For OpenType Font Variations, the values of the following fields can
*   change after a call to @FT_Set_Var_Design_Coordinates (and friends) if
*   the font contains an 'MVAR' table: `ascender`, `descender`, `height`,
*   `underline_position`, and `underline_thickness`.
*
*   Especially for TrueType fonts see also the documentation for
*   @FT_Size_Metrics.
*/
Face :: struct {
	num_faces:  c.long,
	face_index: c.long,

	face_flags:  Face_Flags,
	style_flags: Style_Flags,

	num_glyphs: c.long,

	family_name: cstring,
	style_name:  cstring,

	num_fixed_sizes: c.int,
	available_sizes: [^]Bitmap_Size,

	num_charmaps: c.int,
	charmaps:     [^]^CharMap,

	generic: Generic,

	/* The following member variables (down to `underline_thickness`) */
	/* are only relevant to scalable outlines; cf. @FT_Bitmap_Size    */
	/* for bitmap fonts.                                              */
	bbox: BBox,

	units_per_EM: c.ushort,
	ascender:     c.short,
	descender:    c.short,
	height:       c.short,

	max_advance_width:  c.short,
	max_advance_height: c.short,

	underline_position:  c.short,
	underline_thickness: c.short,

	glyph:   ^GlyphSlot,
	size:    Size,
	charmap: CharMap,

	/* private fields, internal to FreeType */
	driver: ^Driver,
	memory: ^Memory,
	stream: ^Stream,

	sizes_list: List,

	autohint:   Generic, /* face-specific auto-hinter data */
	extensions: rawptr,  /* unused                         */

	internal: ^Face_Internal,
}

/**************************************************************************
 *
 * @type:
 *   FT_F26Dot6
 *
 * @description:
 *   A signed 26.6 fixed-point type used for vectorial pixel coordinates.
 */
F26Dot6 :: c.long

/**************************************************************************
 *
 * @enum:
 *   FT_Render_Mode
 *
 * @description:
 *   Render modes supported by FreeType~2.  Each mode corresponds to a
 *   specific type of scanline conversion performed on the outline.
 *
 *   For bitmap fonts and embedded bitmaps the `bitmap->pixel_mode` field
 *   in the @FT_GlyphSlotRec structure gives the format of the returned
 *   bitmap.
 *
 *   All modes except @FT_RENDER_MODE_MONO use 256 levels of opacity,
 *   indicating pixel coverage.  Use linear alpha blending and gamma
 *   correction to correctly render non-monochrome glyph bitmaps onto a
 *   surface; see @FT_Render_Glyph.
 *
 *   The @FT_RENDER_MODE_SDF is a special render mode that uses up to 256
 *   distance values, indicating the signed distance from the grid position
 *   to the nearest outline.
 *
 * @values:
 *   FT_RENDER_MODE_NORMAL ::
 *     Default render mode; it corresponds to 8-bit anti-aliased bitmaps.
 *
 *   FT_RENDER_MODE_LIGHT ::
 *     This is equivalent to @FT_RENDER_MODE_NORMAL.  It is only defined as
 *     a separate value because render modes are also used indirectly to
 *     define hinting algorithm selectors.  See @FT_LOAD_TARGET_XXX for
 *     details.
 *
 *   FT_RENDER_MODE_MONO ::
 *     This mode corresponds to 1-bit bitmaps (with 2~levels of opacity).
 *
 *   FT_RENDER_MODE_LCD ::
 *     This mode corresponds to horizontal RGB and BGR subpixel displays
 *     like LCD screens.  It produces 8-bit bitmaps that are 3~times the
 *     width of the original glyph outline in pixels, and which use the
 *     @FT_PIXEL_MODE_LCD mode.
 *
 *   FT_RENDER_MODE_LCD_V ::
 *     This mode corresponds to vertical RGB and BGR subpixel displays
 *     (like PDA screens, rotated LCD displays, etc.).  It produces 8-bit
 *     bitmaps that are 3~times the height of the original glyph outline in
 *     pixels and use the @FT_PIXEL_MODE_LCD_V mode.
 *
 *   FT_RENDER_MODE_SDF ::
 *     The positive (unsigned) 8-bit bitmap values can be converted to the
 *     single-channel signed distance field (SDF) by subtracting 128, with
 *     the positive and negative results corresponding to the inside and
 *     the outside of a glyph contour, respectively.  The distance units are
 *     arbitrarily determined by an adjustable @spread property.
 *
 * @note:
 *   The selected render mode only affects scalable vector glyphs of a font.
 *   Embedded bitmaps often have a different pixel mode like
 *   @FT_PIXEL_MODE_MONO.  You can use @FT_Bitmap_Convert to transform them
 *   into 8-bit pixmaps.
 *
 */
Render_Mode :: enum c.int {
	NORMAL = 0,
	LIGHT,
	MONO,
	LCD,
	LCD_V,
	SDF,

	MAX
}

/**************************************************************************
 *
 * @enum:
 *   FT_LOAD_XXX
 *
 * @description:
 *   A list of bit field constants for @FT_Load_Glyph to indicate what kind
 *   of operations to perform during glyph loading.
 *
 * @values:
 *   FT_LOAD_DEFAULT ::
 *     Corresponding to~0, this value is used as the default glyph load
 *     operation.  In this case, the following happens:
	 *
 *     1. FreeType looks for a bitmap for the glyph corresponding to the
 *     face's current size.  If one is found, the function returns.  The
 *     bitmap data can be accessed from the glyph slot (see note below).
 *
 *     2. If no embedded bitmap is searched for or found, FreeType looks
 *     for a scalable outline.  If one is found, it is loaded from the font
 *     file, scaled to device pixels, then 'hinted' to the pixel grid in
 *     order to optimize it.  The outline data can be accessed from the
 *     glyph slot (see note below).
 *
 *     Note that by default the glyph loader doesn't render outlines into
 *     bitmaps.  The following flags are used to modify this default
 *     behaviour to more specific and useful cases.
 *
 *   FT_LOAD_NO_SCALE ::
 *     Don't scale the loaded outline glyph but keep it in font units.
 *     This flag is also assumed if @FT_Size owned by the face was not
 *     properly initialized.
 *
 *     This flag implies @FT_LOAD_NO_HINTING and @FT_LOAD_NO_BITMAP, and
 *     unsets @FT_LOAD_RENDER.
 *
 *     If the font is 'tricky' (see @FT_FACE_FLAG_TRICKY for more), using
 *     `FT_LOAD_NO_SCALE` usually yields meaningless outlines because the
 *     subglyphs must be scaled and positioned with hinting instructions.
 *     This can be solved by loading the font without `FT_LOAD_NO_SCALE`
 *     and setting the character size to `font->units_per_EM`.
 *
 *   FT_LOAD_NO_HINTING ::
 *     Disable hinting.  This generally generates 'blurrier' bitmap glyphs
 *     when the glyphs are rendered in any of the anti-aliased modes.  See
 *     also the note below.
 *
 *     This flag is implied by @FT_LOAD_NO_SCALE.
 *
 *   FT_LOAD_RENDER ::
 *     Call @FT_Render_Glyph after the glyph is loaded.  By default, the
 *     glyph is rendered in @FT_RENDER_MODE_NORMAL mode.  This can be
 *     overridden by @FT_LOAD_TARGET_XXX or @FT_LOAD_MONOCHROME.
 *
 *     This flag is unset by @FT_LOAD_NO_SCALE.
 *
 *   FT_LOAD_NO_BITMAP ::
 *     Ignore bitmap strikes when loading.  Bitmap-only fonts ignore this
 *     flag.
 *
 *     @FT_LOAD_NO_SCALE always sets this flag.
 *
 *   FT_LOAD_SBITS_ONLY ::
 *     [Since 2.12] This is the opposite of @FT_LOAD_NO_BITMAP, more or
 *     less: @FT_Load_Glyph returns `FT_Err_Invalid_Argument` if the face
 *     contains a bitmap strike for the given size (or the strike selected
 *     by @FT_Select_Size) but there is no glyph in the strike.
 *
 *     Note that this load flag was part of FreeType since version 2.0.6
 *     but previously tagged as internal.
 *
*   FT_LOAD_VERTICAL_LAYOUT ::
*     Load the glyph for vertical text layout.  In particular, the
*     `advance` value in the @FT_GlyphSlotRec structure is set to the
*     `vertAdvance` value of the `metrics` field.
*
*     In case @FT_HAS_VERTICAL doesn't return true, you shouldn't use this
*     flag currently.  Reason is that in this case vertical metrics get
*     synthesized, and those values are not always consistent across
*     various font formats.
*
*   FT_LOAD_FORCE_AUTOHINT ::
*     Prefer the auto-hinter over the font's native hinter.  See also the
*     note below.
*
*   FT_LOAD_PEDANTIC ::
*     Make the font driver perform pedantic verifications during glyph
*     loading and hinting.  This is mostly used to detect broken glyphs in
*     fonts.  By default, FreeType tries to handle broken fonts also.
*
*     In particular, errors from the TrueType bytecode engine are not
*     passed to the application if this flag is not set; this might result
*     in partially hinted or distorted glyphs in case a glyph's bytecode
*     is buggy.
*
*   FT_LOAD_NO_RECURSE ::
*     Don't load composite glyphs recursively.  Instead, the font driver
*     fills the `num_subglyph` and `subglyphs` values of the glyph slot;
*     it also sets `glyph->format` to @FT_GLYPH_FORMAT_COMPOSITE.  The
*     description of subglyphs can then be accessed with
*     @FT_Get_SubGlyph_Info.
*
*     Don't use this flag for retrieving metrics information since some
*     font drivers only return rudimentary data.
*
*     This flag implies @FT_LOAD_NO_SCALE and @FT_LOAD_IGNORE_TRANSFORM.
*
*   FT_LOAD_IGNORE_TRANSFORM ::
*     Ignore the transform matrix set by @FT_Set_Transform.
*
*   FT_LOAD_MONOCHROME ::
*     This flag is used with @FT_LOAD_RENDER to indicate that you want to
*     render an outline glyph to a 1-bit monochrome bitmap glyph, with
*     8~pixels packed into each byte of the bitmap data.
*
*     Note that this has no effect on the hinting algorithm used.  You
*     should rather use @FT_LOAD_TARGET_MONO so that the
*     monochrome-optimized hinting algorithm is used.
*
*   FT_LOAD_LINEAR_DESIGN ::
*     Keep `linearHoriAdvance` and `linearVertAdvance` fields of
*     @FT_GlyphSlotRec in font units.  See @FT_GlyphSlotRec for details.
*
*   FT_LOAD_NO_AUTOHINT ::
*     Disable the auto-hinter.  See also the note below.
*
*   FT_LOAD_COLOR ::
*     Load colored glyphs.  FreeType searches in the following order;
*     there are slight differences depending on the font format.
*
*     [Since 2.5] Load embedded color bitmap images (provided
	*     @FT_LOAD_NO_BITMAP is not set).  The resulting color bitmaps, if
*     available, have the @FT_PIXEL_MODE_BGRA format, with pre-multiplied
*     color channels.  If the flag is not set and color bitmaps are found,
*     they are converted to 256-level gray bitmaps, using the
*     @FT_PIXEL_MODE_GRAY format.
*
*     [Since 2.12] If the glyph index maps to an entry in the face's
*     'SVG~' table, load the associated SVG document from this table and
*     set the `format` field of @FT_GlyphSlotRec to @FT_GLYPH_FORMAT_SVG
*     ([since 2.13.1] provided @FT_LOAD_NO_SVG is not set).  Note that
*     FreeType itself can't render SVG documents; however, the library
*     provides hooks to seamlessly integrate an external renderer.  See
*     sections @ot_svg_driver and @svg_fonts for more.
*
*     [Since 2.10, experimental] If the glyph index maps to an entry in
*     the face's 'COLR' table with a 'CPAL' palette table (as defined in
	*     the OpenType specification), make @FT_Render_Glyph provide a default
*     blending of the color glyph layers associated with the glyph index,
*     using the same bitmap format as embedded color bitmap images.  This
*     is mainly for convenience and works only for glyphs in 'COLR' v0
*     tables.  **There is no rendering support for 'COLR' v1** (with the
	*     exception of v1 tables that exclusively use v0 features)!  You need
*     a graphics library like Skia or Cairo to interpret the graphics
*     commands stored in v1 tables.  For full control of color layers use
*     @FT_Get_Color_Glyph_Layer and FreeType's color functions like
*     @FT_Palette_Select instead of setting @FT_LOAD_COLOR for rendering
*     so that the client application can handle blending by itself.
*
*   FT_LOAD_NO_SVG ::
*     [Since 2.13.1] Ignore SVG glyph data when loading.
*
*   FT_LOAD_COMPUTE_METRICS ::
*     [Since 2.6.1] Compute glyph metrics from the glyph data, without the
*     use of bundled metrics tables (for example, the 'hdmx' table in
	*     TrueType fonts).  This flag is mainly used by font validating or
*     font editing applications, which need to ignore, verify, or edit
*     those tables.
*
*     Currently, this flag is only implemented for TrueType fonts.
*
*   FT_LOAD_BITMAP_METRICS_ONLY ::
*     [Since 2.7.1] Request loading of the metrics and bitmap image
*     information of a (possibly embedded) bitmap glyph without allocating
*     or copying the bitmap image data itself.  No effect if the target
*     glyph is not a bitmap image.
*
*     This flag unsets @FT_LOAD_RENDER.
*
*   FT_LOAD_CROP_BITMAP ::
*     Ignored.  Deprecated.
*
*   FT_LOAD_IGNORE_GLOBAL_ADVANCE_WIDTH ::
*     Ignored.  Deprecated.
*
* @note:
*   By default, hinting is enabled and the font's native hinter (see
	*   @FT_FACE_FLAG_HINTER) is preferred over the auto-hinter.  You can
*   disable hinting by setting @FT_LOAD_NO_HINTING or change the
*   precedence by setting @FT_LOAD_FORCE_AUTOHINT.  You can also set
*   @FT_LOAD_NO_AUTOHINT in case you don't want the auto-hinter to be used
*   at all.
*
*   See the description of @FT_FACE_FLAG_TRICKY for a special exception
*   (affecting only a handful of Asian fonts).
*
*   Besides deciding which hinter to use, you can also decide which
*   hinting algorithm to use.  See @FT_LOAD_TARGET_XXX for details.
*
*   Note that the auto-hinter needs a valid Unicode cmap (either a native
	*   one or synthesized by FreeType) for producing correct results.  If a
*   font provides an incorrect mapping (for example, assigning the
	*   character code U+005A, LATIN CAPITAL LETTER~Z, to a glyph depicting a
	*   mathematical integral sign), the auto-hinter might produce useless
*   results.
*
*/
Load_Flag :: enum {
	NO_SCALE,
	NO_HINTING,
	RENDER,
	NO_BITMAP,
	VERTICAL_LAYOUT,
	FORCE_AUTOHINT,
	CROP_BITMAP,
	PEDANTIC,
	IGNORE_GLOBAL_ADVANCE_WIDTH = 9,
	NO_RECURSE,
	IGNORE_TRANSFORM,
	MONOCHROME,
	LINEAR_DESIGN,
	SBITS_ONLY,
	NO_AUTOHINT,

	COLOR = 20,
	COMPUTE_METRICS,
	BITMAP_METRICS_ONLY,
	NO_SVG,

	/* used internally only by certain font drivers */
	ADVANCE_ONLY = 8,
	SVG_ONLY     = 23,

	// NOTE: TARGET_* are exposed trough the `load_flags()` procedure

	// TARGET_NORMAL = intrinsics.constant_log2(int((i32(Render_Mode.NORMAL) & 15) << 16)),
	// TARGET_LIGHT  = intrinsics.constant_log2(((3 & 15) << 16)),
	// TARGET_MONO   = intrinsics.constant_log2(int((i32(Render_Mode.MONO) & 15) << 16)),
	// TARGET_LCD    = intrinsics.constant_log2(int((i32(Render_Mode.LCD) & 15) << 16)),
	// TARGET_LCD_V  = intrinsics.constant_log2(int((i32(Render_Mode.LCD_V) & 15) << 16)),
}

Load_Flags :: bit_set[Load_Flag; i32]

/**************************************************************************
 *
 * @enum:
 *   FT_LOAD_TARGET_XXX
 *
 * @description:
 *   A list of values to select a specific hinting algorithm for the
 *   hinter.  You should OR one of these values to your `load_flags` when
 *   calling @FT_Load_Glyph.
 *
 *   Note that a font's native hinters may ignore the hinting algorithm you
 *   have specified (e.g., the TrueType bytecode interpreter).  You can set
 *   @FT_LOAD_FORCE_AUTOHINT to ensure that the auto-hinter is used.
 *
 * @values:
 *   FT_LOAD_TARGET_NORMAL ::
 *     The default hinting algorithm, optimized for standard gray-level
 *     rendering.  For monochrome output, use @FT_LOAD_TARGET_MONO instead.
 *
 *   FT_LOAD_TARGET_LIGHT ::
 *     A lighter hinting algorithm for gray-level modes.  Many generated
 *     glyphs are fuzzier but better resemble their original shape.  This
 *     is achieved by snapping glyphs to the pixel grid only vertically
 *     (Y-axis), as is done by FreeType's new CFF engine or Microsoft's
 *     ClearType font renderer.  This preserves inter-glyph spacing in
 *     horizontal text.  The snapping is done either by the native font
 *     driver, if the driver itself and the font support it, or by the
 *     auto-hinter.
 *
 *     Advance widths are rounded to integer values; however, using the
 *     `lsb_delta` and `rsb_delta` fields of @FT_GlyphSlotRec, it is
 *     possible to get fractional advance widths for subpixel positioning
 *     (which is recommended to use).
 *
 *     If configuration option `AF_CONFIG_OPTION_TT_SIZE_METRICS` is
 *     active, TrueType-like metrics are used to make this mode behave
 *     similarly as in unpatched FreeType versions between 2.4.6 and 2.7.1
 *     (inclusive).
 *
 *   FT_LOAD_TARGET_MONO ::
 *     Strong hinting algorithm that should only be used for monochrome
 *     output.  The result is probably unpleasant if the glyph is rendered
 *     in non-monochrome modes.
 *
 *     Note that for outline fonts only the TrueType font driver has proper
 *     monochrome hinting support, provided the TTFs contain hints for B/W
 *     rendering (which most fonts no longer provide).  If these conditions
 *     are not met it is very likely that you get ugly results at smaller
 *     sizes.
 *
 *   FT_LOAD_TARGET_LCD ::
 *     A variant of @FT_LOAD_TARGET_LIGHT optimized for horizontally
 *     decimated LCD displays.
 *
 *   FT_LOAD_TARGET_LCD_V ::
 *     A variant of @FT_LOAD_TARGET_NORMAL optimized for vertically
 *     decimated LCD displays.
 *
 * @note:
 *   You should use only _one_ of the `FT_LOAD_TARGET_XXX` values in your
 *   `load_flags`.  They can't be ORed.
 *
 *   If @FT_LOAD_RENDER is also set, the glyph is rendered in the
 *   corresponding mode (i.e., the mode that matches the used algorithm
 *   best).  An exception is `FT_LOAD_TARGET_MONO` since it implies
 *   @FT_LOAD_MONOCHROME.
 *
 *   You can use a hinting algorithm that doesn't correspond to the same
 *   rendering mode.  As an example, it is possible to use the 'light'
 *   hinting algorithm and have the results rendered in horizontal LCD
 *   pixel mode, with code like
*
*   ```
*     FT_Load_Glyph( face, glyph_index,
	*                    load_flags | FT_LOAD_TARGET_LIGHT );
*
*     FT_Render_Glyph( face->glyph, FT_RENDER_MODE_LCD );
*   ```
*
*   In general, you should stick with one rendering mode.  For example,
*   switching between @FT_LOAD_TARGET_NORMAL and @FT_LOAD_TARGET_MONO
*   enforces a lot of recomputation for TrueType fonts, which is slow.
*   Another reason is caching: Selecting a different mode usually causes
*   changes in both the outlines and the rasterized bitmaps; it is thus
*   necessary to empty the cache after a mode switch to avoid false hits.
*
*/
load_flags :: #force_inline proc(flags: Load_Flags, mode := Render_Mode.NORMAL) -> i32 {
	f := transmute(i32)flags
	f |= (i32(mode) & 15) << 16
	return f
}


@(default_calling_convention="c", link_prefix="FT_")
foreign lib {
	/**************************************************************************
	 *
	 * @function:
	 *   FT_Init_FreeType
	 *
	 * @description:
	 *   Initialize a new FreeType library object.  The set of modules that are
	 *   registered by this function is determined at build time.
	 *
	 * @output:
	 *   alibrary ::
	 *     A handle to a new library object.
	 *
	 * @return:
	 *   FreeType error code.  0~means success.
	 *
	 * @note:
	 *   In case you want to provide your own memory allocating routines, use
	 *   @FT_New_Library instead, followed by a call to @FT_Add_Default_Modules
	 *   (or a series of calls to @FT_Add_Module) and
	 *   @FT_Set_Default_Properties.
	 *
	 *   See the documentation of @FT_Library and @FT_Face for multi-threading
	 *   issues.
	 *
	 *   If you need reference-counting (cf. @FT_Reference_Library), use
	 *   @FT_New_Library and @FT_Done_Library.
	 *
	 *   If compilation option `FT_CONFIG_OPTION_ENVIRONMENT_PROPERTIES` is
	 *   set, this function reads the `FREETYPE_PROPERTIES` environment
	 *   variable to control driver properties.  See section @properties for
	 *   more.
	 */
	Init_FreeType :: proc(alibrary: ^^Library) -> Error ---
	/**************************************************************************
	 *
	 * @function:
	 *   FT_Done_FreeType
	 *
	 * @description:
	 *   Destroy a given FreeType library object and all of its children,
	 *   including resources, drivers, faces, sizes, etc.
	 *
	 * @input:
	 *   library ::
	 *     A handle to the target library object.
	 *
	 * @return:
	 *   FreeType error code.  0~means success.
	 */
	Done_FreeType :: proc(library: ^Library) -> Error ---
	/**************************************************************************
	 *
	 * @function:
	 *   FT_New_Face
	 *
	 * @description:
	 *   Call @FT_Open_Face to open a font by its pathname.
	 *
	 * @inout:
	 *   library ::
	 *     A handle to the library resource.
	 *
	 * @input:
	 *   pathname ::
	 *     A path to the font file.
	 *
	 *   face_index ::
	 *     See @FT_Open_Face for a detailed description of this parameter.
	 *
	 * @output:
	 *   aface ::
	 *     A handle to a new face object.  If `face_index` is greater than or
	 *     equal to zero, it must be non-`NULL`.
	 *
	 * @return:
	 *   FreeType error code.  0~means success.
	 *
	 * @note:
	 *   The `pathname` string should be recognizable as such by a standard
	 *   `fopen` call on your system; in particular, this means that `pathname`
	 *   must not contain null bytes.  If that is not sufficient to address all
	 *   file name possibilities (for example, to handle wide character file
	 *   names on Windows in UTF-16 encoding) you might use @FT_Open_Face to
	 *   pass a memory array or a stream object instead.
	 *
	 *   Use @FT_Done_Face to destroy the created @FT_Face object (along with
	 *   its slot and sizes).
	 */
	New_Face :: proc(library: ^Library, filepathname: cstring, face_index: c.long, aface: ^^Face) -> Error ---
	/**************************************************************************
	 *
	 * @function:
	 *   FT_Done_Face
	 *
	 * @description:
	 *   Discard a given face object, as well as all of its child slots and
	 *   sizes.
	 *
	 * @input:
	 *   face ::
	 *     A handle to a target face object.
	 *
	 * @return:
	 *   FreeType error code.  0~means success.
	 *
	 * @note:
	 *   See the discussion of reference counters in the description of
	 *   @FT_Reference_Face.
	 */
	Done_Face :: proc(face: ^Face) -> Error ---
	/**************************************************************************
	 *
	 * @function:
	 *   FT_New_Memory_Face
	 *
	 * @description:
	 *   Call @FT_Open_Face to open a font that has been loaded into memory.
	 *
	 * @inout:
	 *   library ::
	 *     A handle to the library resource.
	 *
	 * @input:
	 *   file_base ::
	 *     A pointer to the beginning of the font data.
	 *
	 *   file_size ::
	 *     The size of the memory chunk used by the font data.
	 *
	 *   face_index ::
	 *     See @FT_Open_Face for a detailed description of this parameter.
	 *
	 * @output:
	 *   aface ::
	 *     A handle to a new face object.  If `face_index` is greater than or
	 *     equal to zero, it must be non-`NULL`.
	 *
	 * @return:
	 *   FreeType error code.  0~means success.
	 *
	 * @note:
	 *   You must not deallocate the memory before calling @FT_Done_Face.
	 */
	New_Memory_Face :: proc(library: ^Library, file_base: [^]byte, file_size: c.long, face_index: c.long, aface: ^^Face) -> Error ---
	/**************************************************************************
	 *
	 * @function:
	 *   FT_Set_Char_Size
	 *
	 * @description:
	 *   Call @FT_Request_Size to request the nominal size (in points).
	 *
	 * @inout:
	 *   face ::
	 *     A handle to a target face object.
	 *
	 * @input:
	 *   char_width ::
	 *     The nominal width, in 26.6 fractional points.
	 *
	 *   char_height ::
	 *     The nominal height, in 26.6 fractional points.
	 *
	 *   horz_resolution ::
	 *     The horizontal resolution in dpi.
	 *
	 *   vert_resolution ::
	 *     The vertical resolution in dpi.
	 *
	 * @return:
	 *   FreeType error code.  0~means success.
	 *
	 * @note:
	 *   While this function allows fractional points as input values, the
	 *   resulting ppem value for the given resolution is always rounded to the
	 *   nearest integer.
	 *
	 *   If either the character width or height is zero, it is set equal to
	 *   the other value.
	 *
	 *   If either the horizontal or vertical resolution is zero, it is set
	 *   equal to the other value.
	 *
	 *   A character width or height smaller than 1pt is set to 1pt; if both
	 *   resolution values are zero, they are set to 72dpi.
	 *
	 *   Don't use this function if you are using the FreeType cache API.
	 */
	Set_Char_Size :: proc(face: ^Face, char_width, char_height: F26Dot6, horz_resolution, vert_resolution: c.uint) -> Error ---
	/**************************************************************************
	 *
	 * @function:
	 *   FT_Set_Pixel_Sizes
	 *
	 * @description:
	 *   Call @FT_Request_Size to request the nominal size (in pixels).
	 *
	 * @inout:
	 *   face ::
	 *     A handle to the target face object.
	 *
	 * @input:
	 *   pixel_width ::
	 *     The nominal width, in pixels.
	 *
	 *   pixel_height ::
	 *     The nominal height, in pixels.
	 *
	 * @return:
	 *   FreeType error code.  0~means success.
	 *
	 * @note:
	 *   You should not rely on the resulting glyphs matching or being
	 *   constrained to this pixel size.  Refer to @FT_Request_Size to
	 *   understand how requested sizes relate to actual sizes.
	 *
	 *   Don't use this function if you are using the FreeType cache API.
	 */
	Set_Pixel_Sizes :: proc(face: ^Face, pixel_width, pixel_height: c.uint) -> Error ---
	/**************************************************************************
	 *
	 * @function:
	 *   FT_Get_Char_Index
	 *
	 * @description:
	 *   Return the glyph index of a given character code.  This function uses
	 *   the currently selected charmap to do the mapping.
	 *
	 * @input:
	 *   face ::
	 *     A handle to the source face object.
	 *
	 *   charcode ::
	 *     The character code.
	 *
	 * @return: *   The glyph index.  0~means 'undefined character code'. *
	 * @note:
	 *   If you use FreeType to manipulate the contents of font files directly,
	 *   be aware that the glyph index returned by this function doesn't always
	 *   correspond to the internal indices used within the file.  This is done
	 *   to ensure that value~0 always corresponds to the 'missing glyph'.  If
	 *   the first glyph is not named '.notdef', then for Type~1 and Type~42
	 *   fonts, '.notdef' will be moved into the glyph ID~0 position, and
	 *   whatever was there will be moved to the position '.notdef' had.  For
	 *   Type~1 fonts, if there is no '.notdef' glyph at all, then one will be
	 *   created at index~0 and whatever was there will be moved to the last
	 *   index -- Type~42 fonts are considered invalid under this condition.
	 */
	Get_Char_Index :: proc(face: ^Face, charcode: c.ulong) -> c.uint ---
	/**************************************************************************
	 * BINDING NOTE: use `load_flags()` for setting the flags
	 *
	 * @function:
	 *   FT_Load_Glyph
	 *
	 * @description:
	 *   Load a glyph into the glyph slot of a face object.
	 *
	 * @inout:
	 *   face ::
	 *     A handle to the target face object where the glyph is loaded.
	 *
	 * @input:
	 *   glyph_index ::
	 *     The index of the glyph in the font file.  For CID-keyed fonts
	 *     (either in PS or in CFF format) this argument specifies the CID
	 *     value.
	 *
	 *   load_flags ::
	 *     A flag indicating what to load for this glyph.  The @FT_LOAD_XXX
	 *     flags can be used to control the glyph loading process (e.g.,
	 *     whether the outline should be scaled, whether to load bitmaps or
	 *     not, whether to hint the outline, etc).
	 *
	 * @return:
	 *   FreeType error code.  0~means success.
	 *
	 * @note:
	 *   For proper scaling and hinting, the active @FT_Size object owned by
	 *   the face has to be meaningfully initialized by calling
	 *   @FT_Set_Char_Size before this function, for example.  The loaded
	 *   glyph may be transformed.  See @FT_Set_Transform for the details.
	 *
	 *   For subsetted CID-keyed fonts, `FT_Err_Invalid_Argument` is returned
	 *   for invalid CID values (that is, for CID values that don't have a
	 *   corresponding glyph in the font).  See the discussion of the
	 *   @FT_FACE_FLAG_CID_KEYED flag for more details.
	 *
	 *   If you receive `FT_Err_Glyph_Too_Big`, try getting the glyph outline
	 *   at EM size, then scale it manually and fill it as a graphics
	 *   operation.
	 */
	Load_Glyph :: proc(face: ^Face, glyph_index: c.uint, load_flags: i32) -> Error ---
	/**************************************************************************
	 * BINDING NOTE: use `load_flags()` for setting the flags
	 *
	 * @function:
	 *   FT_Load_Char
	 *
	 * @description:
	 *   Load a glyph into the glyph slot of a face object, accessed by its
	 *   character code.
	 *
	 * @inout:
	 *   face ::
	 *     A handle to a target face object where the glyph is loaded.
	 *
	 * @input:
	 *   char_code ::
	 *     The glyph's character code, according to the current charmap used in
	 *     the face.
	 *
	 *   load_flags ::
	 *     A flag indicating what to load for this glyph.  The @FT_LOAD_XXX
	 *     constants can be used to control the glyph loading process (e.g.,
	 *     whether the outline should be scaled, whether to load bitmaps or
	 *     not, whether to hint the outline, etc).
	 *
	 * @return:
	 *   FreeType error code.  0~means success.
	 *
	 * @note:
	 *   This function simply calls @FT_Get_Char_Index and @FT_Load_Glyph.
	 *
	 *   Many fonts contain glyphs that can't be loaded by this function since
	 *   its glyph indices are not listed in any of the font's charmaps.
	 *
	 *   If no active cmap is set up (i.e., `face->charmap` is zero), the call
	 *   to @FT_Get_Char_Index is omitted, and the function behaves identically
	 *   to @FT_Load_Glyph.
	 */
	Load_Char :: proc(face: ^Face, char_code: c.ulong, load_flags: i32) -> Error ---
	/**************************************************************************
	 *
	 * @function:
	 *   FT_Render_Glyph
	 *
	 * @description:
	 *   Convert a given glyph image to a bitmap.  It does so by inspecting the
	 *   glyph image format, finding the relevant renderer, and invoking it.
	 *
	 * @inout:
	 *   slot ::
	 *     A handle to the glyph slot containing the image to convert.
	 *
	 * @input:
	 *   render_mode ::
	 *     The render mode used to render the glyph image into a bitmap.  See
	 *     @FT_Render_Mode for a list of possible values.
	 *
	 *     If @FT_RENDER_MODE_NORMAL is used, a previous call of @FT_Load_Glyph
	 *     with flag @FT_LOAD_COLOR makes `FT_Render_Glyph` provide a default
	 *     blending of colored glyph layers associated with the current glyph
	 *     slot (provided the font contains such layers) instead of rendering
	 *     the glyph slot's outline.  This is an experimental feature; see
	 *     @FT_LOAD_COLOR for more information.
	 *
	 * @return:
	 *   FreeType error code.  0~means success.
	 *
	 * @note:
	 *   When FreeType outputs a bitmap of a glyph, it really outputs an alpha
	 *   coverage map.  If a pixel is completely covered by a filled-in
	 *   outline, the bitmap contains 0xFF at that pixel, meaning that
	 *   0xFF/0xFF fraction of that pixel is covered, meaning the pixel is 100%
	 *   black (or 0% bright).  If a pixel is only 50% covered (value 0x80),
	 *   the pixel is made 50% black (50% bright or a middle shade of grey).
	 *   0% covered means 0% black (100% bright or white).
	 *
	 *   On high-DPI screens like on smartphones and tablets, the pixels are so
	 *   small that their chance of being completely covered and therefore
	 *   completely black are fairly good.  On the low-DPI screens, however,
	 *   the situation is different.  The pixels are too large for most of the
	 *   details of a glyph and shades of gray are the norm rather than the
	 *   exception.
	 *
	 *   This is relevant because all our screens have a second problem: they
	 *   are not linear.  1~+~1 is not~2.  Twice the value does not result in
	 *   twice the brightness.  When a pixel is only 50% covered, the coverage
	 *   map says 50% black, and this translates to a pixel value of 128 when
	 *   you use 8~bits per channel (0-255).  However, this does not translate
	 *   to 50% brightness for that pixel on our sRGB and gamma~2.2 screens.
	 *   Due to their non-linearity, they dwell longer in the darks and only a
	 *   pixel value of about 186 results in 50% brightness -- 128 ends up too
	 *   dark on both bright and dark backgrounds.  The net result is that dark
	 *   text looks burnt-out, pixely and blotchy on bright background, bright
	 *   text too frail on dark backgrounds, and colored text on colored
	 *   background (for example, red on green) seems to have dark halos or
	 *   'dirt' around it.  The situation is especially ugly for diagonal stems
	 *   like in 'w' glyph shapes where the quality of FreeType's anti-aliasing
	 *   depends on the correct display of grays.  On high-DPI screens where
	 *   smaller, fully black pixels reign supreme, this doesn't matter, but on
	 *   our low-DPI screens with all the gray shades, it does.  0% and 100%
	 *   brightness are the same things in linear and non-linear space, just
	 *   all the shades in-between aren't.
	 *
	 *   The blending function for placing text over a background is
	 *
	 *   ```
	 *     dst = alpha * src + (1 - alpha) * dst    ,
	 *   ```
	 *
	 *   which is known as the OVER operator.
	*
	*   To correctly composite an anti-aliased pixel of a glyph onto a
	*   surface,
	*
	*   1. take the foreground and background colors (e.g., in sRGB space)
	*      and apply gamma to get them in a linear space,
	*
	*   2. use OVER to blend the two linear colors using the glyph pixel
	*      as the alpha value (remember, the glyph bitmap is an alpha coverage
		*      bitmap), and
	*
	*   3. apply inverse gamma to the blended pixel and write it back to
	*      the image.
	*
	*   Internal testing at Adobe found that a target inverse gamma of~1.8 for
	*   step~3 gives good results across a wide range of displays with an sRGB
	*   gamma curve or a similar one.
	*
	*   This process can cost performance.  There is an approximation that
	*   does not need to know about the background color; see
	*   https://web.archive.org/web/20211019204945/https://bel.fi/alankila/lcd/
	*   and
	*   https://web.archive.org/web/20210211002939/https://bel.fi/alankila/lcd/alpcor.html
	*   for details.
	*
	*   **ATTENTION**: Linear blending is even more important when dealing
	*   with subpixel-rendered glyphs to prevent color-fringing!  A
	*   subpixel-rendered glyph must first be filtered with a filter that
	*   gives equal weight to the three color primaries and does not exceed a
	*   sum of 0x100, see section @lcd_rendering.  Then the only difference to
	*   gray linear blending is that subpixel-rendered linear blending is done
	*   3~times per pixel: red foreground subpixel to red background subpixel
	*   and so on for green and blue.
	*/
	Render_Glyph :: proc(slot: ^GlyphSlot, render_mode: Render_Mode) -> Error ---
}

main :: proc() {
	library: ^Library

	if err := Init_FreeType(&library); err != .Ok {
		os.exit(1)
	}
	defer Done_FreeType(library)

	face: ^Face
	if err := New_Face(library, "/usr/share/fonts/noto/NotoSans-Regular.ttf", 0, &face); err != .Ok {
		os.exit(1)
	}
	defer Done_Face(face)

	if err := Set_Char_Size(face, 0, 16*64, 300, 300); err != nil {
		os.exit(1)
	}

	// if err := Set_Pixel_Sizes(face, 16, 16); err != nil {
	// 	os.exit(1)
	// }

	// fmt.println(Get_Char_Index(face, 'a'))
	//
	// face.glyph.format = .BITMAP
	//
	// if err := Load_Glyph(face, 0, load_flags({})); err != nil {
	// 	os.exit(1)
	// }
	//
	// if err := Render_Glyph(face.glyph, .NORMAL); err != nil {
	// 	os.exit(1)
	// }

	pen_x := i64(300)
	pen_y := i64(200)

	for r, i in "Hello World!" {
		Load_Char(face, c.ulong(r), load_flags({.RENDER})) or_continue
		// Render_Glyph(face.glyph, .NORMAL) or_continue

		image.write_png(fmt.ctprintf("test_%v.png", i), c.int(face.glyph.bitmap.width), c.int(face.glyph.bitmap.rows), 1, face.glyph.bitmap.buffer, face.glyph.bitmap.pitch)

		pen_x += face.glyph.advance.x >> 6
		// pen_y += face.glyph.advance.y >> 6
	}
}
