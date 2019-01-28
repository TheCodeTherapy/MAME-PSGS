/*  CRT shader
 *
 *  Copyright (C) 2019 Marco Gomez ( @marcogomez_ | http://mgz.me | http://github.com/mgzme )
 *
 *  This is a GLSL CRT simulation shader that I wrote to use with MAME emulator with a special
 *  method to simulate a variety of old-school computer hardware custom color palettes, through
 *  a special dithering matrix / color approximation method.
 *
 *  It was tested with several games on MAME 0.191, but as per MAME's documentation it should work
 *  fine with any recent version of MAME using OpenGL. I wrote it as GLSL (OpenGL) concerning the
 *  number of systems (including Linux, Raspberry Pi and Odroid XU4 - Android based ones) that
 *  can't run MAME with DirectX 9.0, but it is on my plans to write the HLSL version ASAP.
 *
 */

varying float CRTgamma;
varying float monitorgamma;
varying vec2 overscan;
varying vec2 aspect;
varying float d;
varying float R;
varying float cornersize;
varying float cornersmooth;
varying float halation;

varying float filmicReinhard;
varying float saturation;
varying float palette_emulation;

varying vec3 stretch;
varying vec2 sinangle;
varying vec2 cosangle;

uniform vec2 color_texture_sz;      // = rubyInputSize
uniform vec2 rubyOutputSize;
uniform vec2 color_texture_pow2_sz; // = rubyTextureSize

varying vec2 texCoord;
varying vec2 one;

#define FIX(c) max(abs(c), 1e-5);

float intersect(vec2 xy) {
	float A = dot(xy, xy) + d * d;
	float B = 2.0 * (R * (dot(xy, sinangle) - d * cosangle.x * cosangle.y) - d * d);
	float C = d * d + 2.0 * R * d * cosangle.x * cosangle.y;
	return (-B - sqrt(B * B - 4.0 * A * C)) / (2.0 * A);
}

vec2 bkwtrans(vec2 xy) {
	float c = intersect(xy);
	vec2 point = vec2(c) * xy;
	point -= vec2(-R) * sinangle;
	point /= vec2(R);
	vec2 tang = sinangle / cosangle;
	vec2 poc = point / cosangle;
	float A = dot(tang, tang) + 1.0;
	float B = -2.0 * dot(poc, tang);
	float C = dot(poc, poc) - 1.0;
	float a = (-B + sqrt(B * B - 4.0 * A * C)) / (2.0 * A);
	vec2 uv = (point - a * sinangle) / cosangle;
	float r = R * acos(a);
	return uv * r / sin(r / R);
}

vec2 fwtrans(vec2 uv) {
	float r = FIX(sqrt(dot(uv, uv)));
	uv *= sin(r / R) / r;
	float x = 1.0 - cos(r / R);
	float D = d / R + x * cosangle.x * cosangle.y + dot(uv, sinangle);
	return d * (uv * cosangle-x * sinangle) / D;
}

vec3 maxscale() {
	vec2 c = bkwtrans(-R * sinangle / (1.0 + R / d * cosangle.x * cosangle.y));
	vec2 a = vec2(0.5, 0.5) * aspect;
	vec2 lo = vec2(fwtrans(vec2(-a.x, c.y)).x, fwtrans(vec2(c.x, -a.y)).y) / aspect;
	vec2 hi = vec2(fwtrans(vec2(+a.x, c.y)).x, fwtrans(vec2(c.x, +a.y)).y) / aspect;
	return vec3((hi + lo) * aspect * 0.5, max(hi.x - lo.x, hi.y - lo.y));
}


void main() {

	// ============ START of parameters
	CRTgamma = 2.4;							// gamma of simulated CRT
	monitorgamma = 2.2;						// gamma of display monitor (typically 2.2 is correct)
	overscan = vec2(1.0, 1.0);				// overscan (e.g. 1.02 for 2% overscan)
	aspect = vec2(1.0, 0.75);				// aspect ratio
	d = 2.0;								// width of the monitor / simulated distance from viewer to monitor
	R = 1.75;								// radius of curvature
	const vec2 angle = vec2(0.0, -0.01);	// tilt angle in radians (behavior might be a bit wrong if both components are nonzero)
	cornersize = 0.021;						// size of curved corners
	cornersmooth = 25.0;					// border smoothness parameter (decrease if borders are too aliased)
	halation = 0.3;							// Bloom (0.3 is subtle and fine)
	
	filmicReinhard = 1.0;					// 0.0 disables it, 1.0 is full effect
	saturation = 0.7;						// Saturation (0.0 is Black&White, 2.0 is double saturation)
	
	// Palette Emulation parameters:
	//  0.0 = no palette emulation
	//  1.0 = AppleII series 16-color composite video palette based on YIQ color space used by NTSC
	//  2.0 = Commodore VIC-20/MOS Technology VIC chip (also 16-color YpbPr composite video palette)
	//  3.0 = Commodore 64 based on MOS Technology VIC-II chip (also a 16-color YpbPr composite one)
	//  4.0 = MSX computers (Texas Instruments TMS9918 chip) providing a proprietary 15-color YPbPr
	//  5.0 = CGA Mode 4 palette #1 with low and high intensities. Cyan-magenta "7-color" IBM RGBi
	//  6.0 = 16-color RGBi IBM CGA as seen on registers from compatible monitors back then
	//  7.0 = NES-ish color palette (YIQ color space for a 64-color palette (with 54 usable colors)
	//  8.0 = Hand crafted 38-color palette based on luminance levels
	//  9.0 = Hand crafted 16-color palette based on RGB values avg
	// 10.0 = Hand crafted 16-color palette based on tones temperature
	// 11.0 = Hand crafted 16-color palette to emulate SAM Coupé 16-color mode
	// 12.0 = Hand crafted 16-color oversaturated palette
	// 13.0 = Hand crafted 13-color palette to emulate Thermal Scanners (Purple-Orangeish spectrum)
	// 14.0 = 5-color palette to emulate Gameboy greenish colors
	// 15.0 = Purpleish 5-color palette replacement for Gameboy palette
	// 16.0 = 4-color green palette
	// 17.0 = 11 colors (grayscale)
	// 18.0 = 6 colors (grayscale)
	// 19.0 = 3 colors (grayscale)

	palette_emulation = 13.0;				// Color palette emulation	
	
	// ============ END of parameters

	gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;		// Do the standard vertex processing
	sinangle = sin(angle);										// Precalculate values we'll need in the fragment shader
	cosangle = cos(angle);
	stretch = maxscale();
	texCoord = gl_MultiTexCoord0.xy;							// Texture coords
	one = 1.0 / color_texture_pow2_sz;							// The size of one texel, in texture-coordinates
}