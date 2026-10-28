// An ordered 4x4 screen door for a character that overlaps another on the same plane
// (decision 0051): it leaves out a fixed pattern of pixels so the one behind shows through,
// with no blending to sort. [dither] is the share left out; zero draws everything.

uniform float dither : hint_range(0.0, 1.0) = 0.0;

bool dithered_out(vec2 fragment_coordinate) {
	if (dither <= 0.0) {
		return false;
	}
	const float BAYER[16] = {
		0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0
	};
	int x = int(mod(fragment_coordinate.x, 4.0));
	int y = int(mod(fragment_coordinate.y, 4.0));
	return (BAYER[y * 4 + x] + 0.5) / 16.0 < dither;
}
