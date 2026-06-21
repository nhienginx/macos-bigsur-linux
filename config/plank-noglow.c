/* Plank macOS tweaks via LD_PRELOAD (no system files modified):
 *  1) draw_active_glow  -> no-op   (remove ugly active background, keep dot)
 *  2) create_indicator  -> force black running dot (macOS-style), still
 *     calls the real renderer so the dot is drawn normally, just black.
 *
 * Drawing.Color in Plank = { double red, green, blue, alpha }.
 * create_indicator C sig (verified by disasm):
 *   Surface* plank_dock_theme_create_indicator(
 *       PlankDockTheme* self, int size, Color* color, Surface* model)
 */
#define _GNU_SOURCE
#include <dlfcn.h>

typedef struct { double red, green, blue, alpha; } PColor;

void plank_dock_theme_draw_active_glow(void) { }

void *plank_dock_theme_create_indicator(void *self, int size,
                                        PColor *color, void *model)
{
    static void *(*real)(void *, int, PColor *, void *);
    if (!real)
        real = dlsym(RTLD_NEXT, "plank_dock_theme_create_indicator");
    PColor black = { 0.0, 0.0, 0.0, 1.0 };
    return real(self, size, &black, model);
}
