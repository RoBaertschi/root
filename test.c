#include <ft2build.h>
#include FT_FREETYPE_H
#include FT_GLYPH_H
#include FT_BBOX_H

int main() {
  FT_Library library;
  FT_Face face;
  FT_Init_FreeType(&library);
  FT_New_Face(library, "/usr/share/fonts/noto/NotoSans-Regular.ttf", 0, &face);
  FT_Open_Face
  FT_List l;
  FT_Set_Char_Size(face, 0, 16 * 64, 300, 300);
  FT_Get_Char_Index(face, 'a');
  FT_Load_Glyph(face, 0, 0);
  int test = FT_LOAD_TARGET_LIGHT;

  FT_HAS_VERTICAL(face);

  FT_Render_Glyph(face->glyph, FT_RENDER_MODE_NORMAL);
  FT_Glyph glyph;
  FT_Get_Glyph(face->glyph, &glyph);
  FT_Glyph_Copy(glyph, &glyph);
  FT_Matrix m;
  FT_Glyph_Get_CBox(glyph, 0, 0);
  FT_Glyph_To_Bitmap(&glyph, 0, 0, 0);
  FT_BitmapGlyph g;
  FT_IS_SCALABLE(face);
  FT_Attach_File(face, "");
  FT_Open_Args args;
  FT_Stream stream;
  FT_Pointer p;
  FT_Get_Kerning(face, 0, 0, 0, 0);
  FT_Done_Glyph(glyph);
  FT_Done_Face(face);
  FT_Outline_Get_BBox(0, 0);
  FT_HAS_KERNING(face);
  FT_BitmapGlyph a;
  FT_Error_String
}
