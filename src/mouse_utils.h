#pragma once

#include <optional>

#include "point.h"
#include "cursesdef.h"
#if defined(TILES)
#include "sdltiles.h"
#endif

/// Convert a raw mouse position to absolute terminal cell coordinates.
/// In tiles builds the raw mouse position is in window pixels,
/// in curses builds it is already in terminal cells.
/// Returns nullopt if the position is invalid.
inline auto mouse_pos_to_screen_cell( const point &mouse_pos ) -> std::optional<point>
{
#if defined(TILES)
    // The game is rendered scaled into the window and the standard font size
    // accounts for that scaling, i.e. it is the window pixels per cell.
    const auto dim = get_window_dimensions( catacurses::stdscr );
    if( dim.scaled_font_size.x <= 0 || dim.scaled_font_size.y <= 0 ||
        mouse_pos.x < 0 || mouse_pos.y < 0 ) {
        return std::nullopt;
    }
    return point( mouse_pos.x / dim.scaled_font_size.x,
                  mouse_pos.y / dim.scaled_font_size.y );
#else
    return mouse_pos;
#endif
}
