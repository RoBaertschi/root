#include <ft2build.h>
#include FT_FREETYPE_H

int main() {
  FT_Library library;
  FT_Face face;
  FT_Init_FreeType(&library);
  FT_New_Face(library, "/usr/share/fonts/noto/NotoSans-Regular.ttf", 0, &face);
  FT_List l;
  FT_Set_Char_Size(face, 0, 16 * 64, 300, 300);
  FT_Get_Char_Index(face, 'a');
  FT_Load_Glyph(face, 0, 0);
  int test = FT_LOAD_TARGET_LIGHT;

  FT_Render_Glyph(face->glyph, FT_RENDER_MODE_NORMAL);
}
