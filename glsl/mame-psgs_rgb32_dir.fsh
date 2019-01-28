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

#define LINEAR_PROCESSING					// Comment out to disable gamma lerp (increase performance)
#define CURVATURE							// Comment out to disable CRT curvature

// Choose one (and comment out the other of those profiles)
#define OVERSAMPLE
// #define USEGAUSSIAN						// Gaussian is better for low-end graphics cards

// Constants
#define FIX(c) max(abs(c), 1e-5);
#define PI 3.141592653589

#ifdef LINEAR_PROCESSING
#       define TEX2D(c) pow(texture2D(mpass_texture, (c)), vec4(CRTgamma))
#else
#       define TEX2D(c) texture2D(mpass_texture, (c))
#endif

uniform sampler2D mpass_texture;      // = rubyTexture
uniform vec2 color_texture_sz;        // = rubyInputSize
uniform vec2 color_texture_pow2_sz;   // = rubyTextureSize

varying vec2 texCoord;
varying vec2 one;

varying float CRTgamma;
varying float monitorgamma;

varying vec2 overscan;
varying vec2 aspect;

varying float d;
varying float R;

varying float cornersize;
varying float cornersmooth;
varying float filmicReinhard;
varying float palette_emulation;

varying float halation;
varying float saturation;

varying vec3 stretch;
varying vec2 sinangle;
varying vec2 cosangle;

const float rndc = 43758.5453123;
const float W = 1.2;
const float T = 7.5;
const vec3 gammaBoost = vec3(1.0/1.15, 1.0/1.15, 1.0/1.15);

#define BRIGHTNESS 1.0

// Color Palette Replacement Method ===================================================================================
vec3 find_closest (vec3 ref, float mode) {
	vec3 old = vec3 (100.0 * 255.0);
	#define TRY_COLOR(new) old = mix (new, old, step (length (old-ref), length (new-ref)));

	// Part One - YPbPr 16-colorish composite video based systems =====================================================

	// AppleII series 16-color composite video palette representation, based on YIQ color space used by NTSC
	// practical 15 color palette as it count's  with 2 similar grey instances.
	if (mode == 1.0) {
		TRY_COLOR (vec3 (  0.0,   0.0,   0.0));		//  0 - black			(YPbPr = 0.0  ,  0.0 ,  0.0 )
		TRY_COLOR (vec3 (133.0,  59.0,  81.0));		//  1 - magenta			(YPbPr = 0.25 ,  0.0 ,  0.5 )
		TRY_COLOR (vec3 ( 80.0,  71.0, 137.0));		//  2 - dark blue		(YPbPr = 0.25 ,  0.5 ,  0.0 )
		TRY_COLOR (vec3 (233.0,  93.0, 240.0));		//  3 - purple			(YPbPr = 0.5  ,  1.0 ,  1.0 )
		TRY_COLOR (vec3 (  0.0, 104.0,  82.0));		//  4 - dark green		(YPbPr = 0.25 ,  0.0 , -0.5 )
		TRY_COLOR (vec3 (146.0, 146.0, 146.0));		//  5 - gray #1			(YPbPr = 0.5  ,  0.0 ,  0.0 )
		TRY_COLOR (vec3 (  0.0, 168.0, 241.0));		//  6 - medium blue		(YPbPr = 0.5  ,  1.0 , -1.0 )
		TRY_COLOR (vec3 (202.0, 195.0, 248.0));		//  7 - light blue		(YPbPr = 0.75 ,  0.5 ,  0.0 )
		TRY_COLOR (vec3 ( 81.0,  92.0,  15.0));		//  8 - brown			(YPbPr = 0.25 , -0.5 ,  0.0 )
		TRY_COLOR (vec3 (235.0, 127.0,  35.0));		//  9 - orange			(YPbPr = 0.5  , -1.0 ,  1.0 )
		//TRY_COLOR(vec3(146.0, 146.0, 146.0));		// 10 - gray #2			(YPbPr = 0.5  ,  0.0 ,  0.0 )
		TRY_COLOR (vec3 (241.0, 166.0, 191.0));		// 11 - pink			(YPbPr = 0.75 ,  0.0 ,  0.5 )
		TRY_COLOR (vec3 (  0.0, 201.0,  41.0));		// 12 - green			(YPbPr = 0.5  , -1.0 , -1.0 )
		TRY_COLOR (vec3 (203.0, 211.0, 155.0));		// 13 - yellow			(YPbPr = 0.75 , -0.5 ,  0.0 )
		TRY_COLOR (vec3 (154.0, 220.0, 203.0));		// 14 - aqua			(YPbPr = 0.75 ,  0.0 , -0.5 )
		TRY_COLOR (vec3 (255.0, 255.0, 255.0));		// 15 - white			(YPbPr = 1.0  ,  0.0 ,  0.0 )
	}

	// Commodore VIC-20 based on MOS Technology VIC chip (also a 16-color YpbPr composite video palette)
	// this one lacks any intermediate grey shade and counts with 5 levels of luminance.
	if (mode == 2.0) {
		TRY_COLOR (vec3 (  0.0,   0.0,   0.0));		//  0 - black			(YPbPr = 0.0  ,  0.0   ,  0.0   )
		TRY_COLOR (vec3 (255.0, 255.0, 255.0));		//  1 - white			(YPbPr = 1.0  ,  0.0   ,  0.0   )
		TRY_COLOR (vec3 (120.0,  41.0,  34.0));		//  2 - red				(YPbPr = 0.25 , -0.383 ,  0.924 )
		TRY_COLOR (vec3 (135.0, 214.0, 221.0));		//  3 - cyan			(YPbPr = 0.75 ,  0.383 , -0.924 )
		TRY_COLOR (vec3 (170.0,  95.0, 182.0));		//  4 - purple			(YPbPr = 0.5  ,  0.707 ,  0.707 )
		TRY_COLOR (vec3 ( 85.0, 160.0,  73.0));		//  5 - green			(YPbPr = 0.5  , -0.707 , -0.707 )
		TRY_COLOR (vec3 ( 64.0,  49.0, 141.0));		//  6 - blue			(YPbPr = 0.25 ,  1.0   ,  0.0   )
		TRY_COLOR (vec3 (191.0, 206.0, 114.0));		//  7 - yellow			(YPbPr = 0.75 , -1.0   ,  0.0   )
		TRY_COLOR (vec3 (170.0, 116.0,  73.0));		//  8 - orange			(YPbPr = 0.5  , -0.707 ,  0.707 )
		TRY_COLOR (vec3 (234.0, 180.0, 137.0));		//  9 - light orange	(YPbPr = 0.75 , -0.707 ,  0.707 )
		TRY_COLOR (vec3 (184.0, 105.0,  98.0));		// 10 - light red		(YPbPr = 0.5  , -0.383 ,  0.924 )
		TRY_COLOR (vec3 (199.0, 255.0, 255.0));		// 11 - light cyan		(YPbPr = 1.0  ,  0.383 , -0.924 )
		TRY_COLOR (vec3 (234.0, 159.0, 246.0));		// 12 - light purple	(YPbPr = 0.75 ,  0.707 ,  0.707 )
		TRY_COLOR (vec3 (148.0, 224.0, 137.0));		// 13 - light green		(YPbPr = 0.75 , -0.707 , -0.707 )
		TRY_COLOR (vec3 (128.0, 113.0, 204.0));		// 14 - light blue		(YPbPr = 0.5  ,  1.0   ,  0.0   )
		TRY_COLOR (vec3 (255.0, 255.0, 178.0));		// 15 - light yellow	(YPbPr = 1.0  , -1.0   ,  0.0   )
	}

	// Commodore 64 based on MOS Technology VIC-II chip (also a 16-color YpbPr composite video palette)
	// this one evolved from VIC-20 and now counts with 3 shades of grey
	if (mode == 3.0) {
		TRY_COLOR (vec3 (  0.0,   0.0,   0.0));		//  0 - black			(YPbPr = 0.0   ,  0.0   ,  0.0   )
		TRY_COLOR (vec3 (255.0, 255.0, 255.0));		//  1 - white			(YPbPr = 1.0   ,  0.0   ,  0.0   )
		TRY_COLOR (vec3 (161.0,  77.0,  67.0));		//  2 - red				(YPbPr = 0.313 , -0.383 ,  0.924 )
		TRY_COLOR (vec3 (106.0, 193.0, 200.0));		//  3 - cyan			(YPbPr = 0.625 ,  0.383 , -0.924 )
		TRY_COLOR (vec3 (162.0,  86.0, 165.0));		//  4 - purple			(YPbPr = 0.375 ,  0.707 ,  0.707 )
		TRY_COLOR (vec3 ( 92.0, 173.0,  95.0));		//  5 - green			(YPbPr = 0.5   , -0.707 , -0.707 )
		TRY_COLOR (vec3 ( 79.0,  68.0, 156.0));		//  6 - blue			(YPbPr = 0.25  ,  1.0   ,  0.0   )
		TRY_COLOR (vec3 (203.0, 214.0, 137.0));		//  7 - yellow			(YPbPr = 0.75  , -1.0   ,  0.0   )
		TRY_COLOR (vec3 (163.0, 104.0,  58.0));		//  8 - orange			(YPbPr = 0.375 , -0.707 ,  0.707 )
		TRY_COLOR (vec3 (110.0,  83.0,  11.0));		//  9 - brown			(YPbPr = 0.25  , -0.924 ,  0.383 )
		TRY_COLOR (vec3 (204.0, 127.0, 118.0));		// 10 - light red		(YPbPr = 0.5   , -0.383 ,  0.924 )
		TRY_COLOR (vec3 ( 99.0,  99.0,  99.0));		// 11 - dark grey		(YPbPr = 0.313 ,  0.0   ,  0.0   )
		TRY_COLOR (vec3 (139.0, 139.0, 139.0));		// 12 - grey			(YPbPr = 0.469 ,  0.0   ,  0.0   )
		TRY_COLOR (vec3 (155.0, 227.0, 157.0));		// 13 - light green		(YPbPr = 0.75  , -0.707 , -0.707 )
		TRY_COLOR (vec3 (138.0, 127.0, 205.0));		// 14 - light blue		(YPbPr = 0.469 ,  1.0   ,  0.0   )
		TRY_COLOR (vec3 (175.0, 175.0, 175.0));		// 15 - light grey		(YPbPr = 0.625  , 0.0   ,  0.0   )
	}

	// MSX compatible computers using a Texas Instruments TMS9918 chip providing a proprietary 15-color YPbPr
	// ... encoded palette with a plus transparent color intended to be used by hardware sprites overlay.
	// ... curiously, TI TMS9918 focuses on 3 shades of green, 3 shades of red, and just 1 shade of grey
	if (mode == 4.0) {
		//TRY_COLOR(vec3(  0.0,   0.0,   0.0));		//  0 - transparent		(YPbPr = 0.0  ,  0.0   ,  0.0   )
		TRY_COLOR (vec3 (  0.0,   0.0,   0.0));		//  1 - black			(YPbPr = 0.0  ,  0.0   ,  0.0   )
		TRY_COLOR (vec3 ( 62.0, 184.0,  73.0));		//  2 - medium green	(YPbPr = 0.53 , -0.509 , -0.755 )
		TRY_COLOR (vec3 (116.0, 208.0, 125.0));		//  3 - light green		(YPbPr = 0.67 , -0.377 , -0.566 )
		TRY_COLOR (vec3 ( 89.0,  85.0, 224.0));		//  4 - dark blue		(YPbPr = 0.40 ,  1.0   , -0.132 )
		TRY_COLOR (vec3 (128.0, 128.0, 241.0));		//  5 - light blue		(YPbPr = 0.53 ,  0.868 , -0.075 )
		TRY_COLOR (vec3 (185.0,  94.0,  81.0));		//  6 - dark red		(YPbPr = 0.47 , -0.321 ,  0.679 )
		TRY_COLOR (vec3 (101.0, 219.0, 239.0));		//  7 - cyan			(YPbPr = 0.73 ,  0.434 , -0.887 )
		TRY_COLOR (vec3 (219.0, 101.0,  89.0));		//  8 - medium red		(YPbPr = 0.53 , -0.377 ,  0.868 )
		TRY_COLOR (vec3 (255.0, 137.0, 125.0));		//  9 - light red		(YPbPr = 0.67 , -0.377 ,  0.868 )
		TRY_COLOR (vec3 (204.0, 195.0,  94.0));		// 10 - dark yellow		(YPbPr = 0.73 , -0.755 ,  0.189 )
		TRY_COLOR (vec3 (222.0, 208.0, 135.0));		// 11 - light yellow	(YPbPr = 0.80 , -0.566 ,  0.189 )
		TRY_COLOR (vec3 ( 58.0, 162.0,  65.0));		// 12 - dark green		(YPbPr = 0.47 , -0.453 , -0.642 )
		TRY_COLOR (vec3 (183.0, 102.0, 181.0));		// 13 - magenta			(YPbPr = 0.53 ,  0.377 ,  0.491 )
		TRY_COLOR (vec3 (204.0, 204.0, 204.0));		// 14 - grey			(YPbPr = 0.80 ,  0.0   ,  0.0   )
		TRY_COLOR (vec3 (255.0, 255.0, 255.0));		// 15 - white			(YPbPr = 1.0  ,  0.0   ,  0.0   )
	}

	// Part Two - IBM RGBi based palettes =============================================================================

	// CGA Mode 4 palette #1 with both intensities (low and high). The good old cyan-magenta "7-color" palette
	if (mode == 5.0) {
		TRY_COLOR (vec3 (  0.0,   0.0,   0.0));		//  0 - black
		TRY_COLOR (vec3 (  0.0, 170.0, 170.0));		//  1 - low intensity cyan
		TRY_COLOR (vec3 (170.0,   0.0, 170.0));		//  2 - low intensity magenta
		TRY_COLOR (vec3 (170.0, 170.0, 170.0));		//  3 - low intensity white / light grey
		TRY_COLOR (vec3 ( 85.0, 255.0, 255.0));		//  4 - high intensity cyan
		TRY_COLOR (vec3 (255.0,  85.0, 255.0));		//  5 - high intensity magenta
		TRY_COLOR (vec3 (255.0, 255.0, 255.0));		//  6 - high intensity grey / bright white
	}


	// 16-color RGBi IBM CGA as seen on registers from compatible monitors back then
	if (mode == 6.0) {
		TRY_COLOR (vec3 (  0.0,   0.0,   0.0));		//  0 - black
		TRY_COLOR (vec3 (  0.0,  25.0, 182.0));		//  1 - low blue
		TRY_COLOR (vec3 (  0.0, 180.0,  29.0));		//  2 - low green
		TRY_COLOR (vec3 (  0.0, 182.0, 184.0));		//  3 - low cyan
		TRY_COLOR (vec3 (196.0,  31.0,  12.0));		//  4 - low red
		TRY_COLOR (vec3 (193.0,  43.0, 182.0));		//  5 - low magenta
		TRY_COLOR (vec3 (193.0, 106.0,  21.0));		//  6 - brown
		TRY_COLOR (vec3 (184.0, 184.0, 184.0));		//  7 - light grey
		TRY_COLOR (vec3 (104.0, 104.0, 104.0));		//  8 - dark grey
		TRY_COLOR (vec3 ( 95.0, 110.0, 252.0));		//  9 - high blue
		TRY_COLOR (vec3 ( 57.0, 250.0, 111.0));		// 10 - high green
		TRY_COLOR (vec3 ( 36.0, 252.0, 254.0));		// 11 - high cyan
		TRY_COLOR (vec3 (255.0, 112.0, 106.0));		// 12 - high red
		TRY_COLOR (vec3 (255.0, 118.0, 253.0));		// 13 - high magenta
		TRY_COLOR (vec3 (255.0, 253.0, 113.0));		// 14 - yellow
		TRY_COLOR (vec3 (255.0, 255.0, 255.0));		// 15 - white
	}

	// Part three - my hand crafted palettes ==========================================================================

	if (mode == 7.0) {							// 54 COLORS NESish palette
		TRY_COLOR (vec3 (  0.0,   0.0,   0.0)); //vec3 (  0.0,   88.0,   0.0)
		TRY_COLOR (vec3 ( 80.0,  48.0,   0.0));
		TRY_COLOR (vec3 (  0.0, 104.0,   0.0));
		TRY_COLOR (vec3 (  0.0,  64.0,  88.0));
		TRY_COLOR (vec3 (  0.0, 120.0,   0.0));
		TRY_COLOR (vec3 (136.0,  20.0,   0.0));
		TRY_COLOR (vec3 (  0.0, 168.0,   0.0));
		TRY_COLOR (vec3 (168.0,  16.0,   0.0));
		TRY_COLOR (vec3 (168.0,   0.0,  32.0));
		TRY_COLOR (vec3 (  0.0, 168.0,  68.0));
		TRY_COLOR (vec3 (  0.0, 184.0,   0.0));
		TRY_COLOR (vec3 (  0.0,   0.0, 188.0));
		TRY_COLOR (vec3 (  0.0, 136.0, 136.0));
		TRY_COLOR (vec3 (148.0,   0.0, 132.0));
		TRY_COLOR (vec3 ( 68.0,  40.0, 188.0));
		TRY_COLOR (vec3 (120.0, 120.0, 120.0));
		TRY_COLOR (vec3 (172.0, 124.0,   0.0));
		TRY_COLOR (vec3 (124.0, 124.0, 124.0));
		TRY_COLOR (vec3 (228.0,   0.0,  88.0));
		TRY_COLOR (vec3 (228.0,  92.0,  16.0));
		TRY_COLOR (vec3 ( 88.0, 216.0,  84.0));
		TRY_COLOR (vec3 (  0.0,   0.0, 252.0));
		TRY_COLOR (vec3 (248.0,  56.0,   0.0));
		TRY_COLOR (vec3 (  0.0,  88.0, 248.0));
		TRY_COLOR (vec3 (  0.0, 120.0, 248.0));
		TRY_COLOR (vec3 (104.0,  68.0, 252.0));
		TRY_COLOR (vec3 (248.0, 120.0,  88.0));
		TRY_COLOR (vec3 (216.0,   0.0, 204.0));
		TRY_COLOR (vec3 ( 88.0, 248.0, 152.0));
		TRY_COLOR (vec3 (248.0,  88.0, 152.0));
		TRY_COLOR (vec3 (104.0, 136.0, 252.0));
		TRY_COLOR (vec3 (252.0, 160.0,  68.0));
		TRY_COLOR (vec3 (248.0, 184.0,   0.0));
		TRY_COLOR (vec3 (184.0, 248.0,  24.0));
		TRY_COLOR (vec3 (152.0, 120.0, 248.0));
		TRY_COLOR (vec3 (  0.0, 232.0, 216.0));
		TRY_COLOR (vec3 ( 60.0, 188.0, 252.0));
		TRY_COLOR (vec3 (188.0, 188.0, 188.0));
		TRY_COLOR (vec3 (216.0, 248.0, 120.0));
		TRY_COLOR (vec3 (248.0, 216.0, 120.0));
		TRY_COLOR (vec3 (248.0, 164.0, 192.0));
		TRY_COLOR (vec3 (  0.0, 252.0, 252.0));
		TRY_COLOR (vec3 (184.0, 184.0, 248.0));
		TRY_COLOR (vec3 (184.0, 248.0, 184.0));
		TRY_COLOR (vec3 (240.0, 208.0, 176.0));
		TRY_COLOR (vec3 (248.0, 120.0, 248.0));
		TRY_COLOR (vec3 (252.0, 224.0, 168.0));
		TRY_COLOR (vec3 (184.0, 248.0, 216.0));
		TRY_COLOR (vec3 (216.0, 184.0, 248.0));
		TRY_COLOR (vec3 (164.0, 228.0, 252.0));
		TRY_COLOR (vec3 (248.0, 184.0, 248.0));
		TRY_COLOR (vec3 (248.0, 216.0, 248.0));
		TRY_COLOR (vec3 (248.0, 248.0, 248.0));
		TRY_COLOR (vec3 (252.0, 252.0, 252.0));
	}

	else if (mode == 8.0) {						// 38 COLORS
		TRY_COLOR (vec3 (255.0, 153.0, 153.0)); // L80
		TRY_COLOR (vec3 (255.0, 181.0, 153.0)); // L80
		TRY_COLOR (vec3 (254.0, 255.0, 153.0)); // L80
		TRY_COLOR (vec3 (181.0, 255.0, 153.0)); // L80
		TRY_COLOR (vec3 (153.0, 214.0, 255.0)); // L80
		TRY_COLOR (vec3 (153.0, 163.0, 255.0)); // L80
		TRY_COLOR (vec3 (255.0,  50.0,  50.0)); // L60
		TRY_COLOR (vec3 (255.0, 108.0,  50.0)); // L60
		TRY_COLOR (vec3 (254.0, 255.0,  50.0)); // L60
		TRY_COLOR (vec3 (108.0, 255.0,  50.0)); // L60
		TRY_COLOR (vec3 ( 50.0, 173.0, 255.0)); // L60
		TRY_COLOR (vec3 ( 50.0,  71.0, 255.0)); // L60
		TRY_COLOR (vec3 (204.0,   0.0,   0.0)); // L40
		TRY_COLOR (vec3 (204.0,  57.0,   0.0)); // L40
		TRY_COLOR (vec3 (203.0, 204.0,   0.0)); // L40
		TRY_COLOR (vec3 ( 57.0, 204.0,   0.0)); // L40
		TRY_COLOR (vec3 (  0.0, 122.0, 204.0)); // L40
		TRY_COLOR (vec3 (  0.0,  20.0, 204.0)); // L40
		TRY_COLOR (vec3 (102.0,   0.0,   0.0)); // L20
		TRY_COLOR (vec3 (102.0,  28.0,   0.0)); // L20
		TRY_COLOR (vec3 (101.0, 102.0,   0.0)); // L20
		TRY_COLOR (vec3 ( 28.0, 102.0,   0.0)); // L20
		TRY_COLOR (vec3 (  0.0,  61.0, 102.0)); // L20
		TRY_COLOR (vec3 (  0.0,  10.0, 102.0)); // L20
		TRY_COLOR (vec3 (255.0, 255.0, 255.0)); // L100
		TRY_COLOR (vec3 (226.0, 226.0, 226.0)); // L90
		TRY_COLOR (vec3 (198.0, 198.0, 198.0)); // L80
		TRY_COLOR (vec3 (171.0, 171.0, 171.0)); // L70
		TRY_COLOR (vec3 (145.0, 145.0, 145.0)); // L60
		TRY_COLOR (vec3 (119.0, 119.0, 119.0)); // L50
		TRY_COLOR (vec3 ( 94.0,  94.0,  94.0)); // L40
		TRY_COLOR (vec3 ( 71.0,  71.0,  71.0)); // L30
		TRY_COLOR (vec3 ( 48.0,  48.0,  48.0)); // L20
		TRY_COLOR (vec3 ( 27.0,  27.0,  27.0)); // L10
		TRY_COLOR (vec3 (  0.0,   0.0,   0.0)); // L0
		TRY_COLOR (vec3 (  0.0,   0.0, 255.0)); // L30
		TRY_COLOR (vec3 (255.0,   0.0,   0.0)); // L54
		TRY_COLOR (vec3 (  0.0, 255.0,   0.0)); // L88
	}

	else if (mode == 9.0) {						// 16 COLORS
		TRY_COLOR (vec3 (  0.0,   0.0,   0.0));
		TRY_COLOR (vec3 (255.0, 255.0, 255.0));
		TRY_COLOR (vec3 (255.0,   0.0,   0.0));
		TRY_COLOR (vec3 (  0.0, 255.0,   0.0));
		TRY_COLOR (vec3 (  0.0,   0.0, 255.0));
		TRY_COLOR (vec3 (255.0, 255.0,   0.0));
		TRY_COLOR (vec3 (  0.0, 255.0, 255.0));
		TRY_COLOR (vec3 (255.0,   0.0, 255.0));
		TRY_COLOR (vec3 (128.0,   0.0,   0.0));
		TRY_COLOR (vec3 (  0.0, 128.0,   0.0));
		TRY_COLOR (vec3 (  0.0,   0.0, 128.0));
		TRY_COLOR (vec3 (128.0, 128.0,   0.0));
		TRY_COLOR (vec3 (  0.0, 128.0, 128.0));
		TRY_COLOR (vec3 (128.0,   0.0, 128.0));
		TRY_COLOR (vec3 (128.0, 128.0, 128.0));
		TRY_COLOR (vec3 (255.0, 128.0, 128.0));
	}

	else if (mode == 10.0) {					// 16 COLORS
		TRY_COLOR (vec3 (  0.0,   0.0,   0.0));
	    TRY_COLOR (vec3 (255.0, 255.0, 255.0));
	    TRY_COLOR (vec3 (116.0,  67.0,  53.0));
	    TRY_COLOR (vec3 (124.0, 172.0, 186.0));
	    TRY_COLOR (vec3 (123.0,  72.0, 144.0));
	    TRY_COLOR (vec3 (100.0, 151.0,  79.0));
	    TRY_COLOR (vec3 ( 64.0,  50.0, 133.0));
	    TRY_COLOR (vec3 (191.0, 205.0, 122.0));
	    TRY_COLOR (vec3 (123.0,  91.0,  47.0));
	    TRY_COLOR (vec3 ( 79.0,  69.0,   0.0));
	    TRY_COLOR (vec3 (163.0, 114.0, 101.0));
	    TRY_COLOR (vec3 ( 80.0,  80.0,  80.0));
	    TRY_COLOR (vec3 (120.0, 120.0, 120.0));
	    TRY_COLOR (vec3 (164.0, 215.0, 142.0));
	    TRY_COLOR (vec3 (120.0, 106.0, 189.0));
	    TRY_COLOR (vec3 (159.0, 159.0, 150.0));
	}

	else if (mode == 11.0) {					// 16 COLORS					
		TRY_COLOR (vec3 (  0.0,   0.0,   0.0));
		TRY_COLOR (vec3 (255.0, 255.0, 255.0));
		TRY_COLOR (vec3 (152.0,  75.0,  67.0));
		TRY_COLOR (vec3 (121.0, 193.0, 200.0));
		TRY_COLOR (vec3 (155.0,  81.0, 165.0));
		TRY_COLOR (vec3 (202.0, 160.0, 218.0));
		TRY_COLOR (vec3 (202.0, 160.0, 218.0));
		TRY_COLOR (vec3 (202.0, 160.0, 218.0));
		TRY_COLOR (vec3 (202.0, 160.0, 218.0));
		TRY_COLOR (vec3 (191.0, 148.0, 208.0));
		TRY_COLOR (vec3 (179.0, 119.0, 201.0));
		TRY_COLOR (vec3 (167.0, 106.0, 198.0));
		TRY_COLOR (vec3 (138.0, 138.0, 138.0));
		TRY_COLOR (vec3 (163.0, 229.0, 153.0));
		TRY_COLOR (vec3 (138.0, 123.0, 206.0));
		TRY_COLOR (vec3 (173.0, 173.0, 173.0));
	}

	else if (mode == 12.0) {					// 16 COLORS
		TRY_COLOR (vec3 (  0.0,   0.0,   0.0));
		TRY_COLOR (vec3 (255.0, 255.0, 255.0));
		TRY_COLOR (vec3 (255.0,   0.0,   0.0));
		TRY_COLOR (vec3 (  0.0, 255.0,   0.0));
		TRY_COLOR (vec3 (  0.0,   0.0, 255.0));
		TRY_COLOR (vec3 (255.0,   0.0, 255.0));
		TRY_COLOR (vec3 (255.0, 255.0,   0.0));
		TRY_COLOR (vec3 (  0.0, 255.0, 255.0));
		TRY_COLOR (vec3 (215.0,   0.0,   0.0));
		TRY_COLOR (vec3 (  0.0, 215.0,   0.0));
		TRY_COLOR (vec3 (  0.0,   0.0, 215.0));
		TRY_COLOR (vec3 (215.0,   0.0, 215.0));
		TRY_COLOR (vec3 (215.0, 215.0,   0.0));
		TRY_COLOR (vec3 (  0.0, 215.0, 215.0));
		TRY_COLOR (vec3 (215.0, 215.0, 215.0));
		TRY_COLOR (vec3 ( 40.0,  40.0,  40.0));
	}

	else if (mode == 13.0) {					// 13 COLORS
		TRY_COLOR (vec3 (  0.0,   0.0,   0.0));
		TRY_COLOR (vec3 (  1.0,   3.0,  31.0));
		TRY_COLOR (vec3 (  1.0,   3.0,  53.0));
		TRY_COLOR (vec3 ( 28.0,   2.0,  78.0));
		TRY_COLOR (vec3 ( 80.0,   2.0, 110.0));
		TRY_COLOR (vec3 (143.0,   3.0, 133.0));
		TRY_COLOR (vec3 (181.0,   3.0, 103.0));
		TRY_COLOR (vec3 (229.0,   3.0,  46.0));
		TRY_COLOR (vec3 (252.0,  73.0,  31.0));
		TRY_COLOR (vec3 (253.0, 173.0,  81.0));
		TRY_COLOR (vec3 (254.0, 244.0, 139.0));
		TRY_COLOR (vec3 (239.0, 254.0, 203.0));
		TRY_COLOR (vec3 (242.0, 255.0, 236.0));
	}

	else if (mode == 14.0) {					// 5 COLORS (GREENISH - GAMEBOY)
		TRY_COLOR (vec3 ( 41.0,  57.0,  65.0));
		TRY_COLOR (vec3 ( 72.0,  93.0,  72.0));
		TRY_COLOR (vec3 (133.0, 149.0,  80.0));
		TRY_COLOR (vec3 (186.0, 195.0, 117.0));
		TRY_COLOR (vec3 (242.0, 239.0, 231.0));
	}
	
	else if (mode == 15.0) {					// 5 COLORS (PURPLEISH)
		TRY_COLOR (vec3 ( 65.0,  49.0,  41.0));
		TRY_COLOR (vec3 ( 93.0,  72.0,  93.0));
		TRY_COLOR (vec3 ( 96.0,  80.0, 149.0));
		TRY_COLOR (vec3 (126.0, 117.0, 195.0));
		TRY_COLOR (vec3 (231.0, 234.0, 242.0));
	}

	else if (mode == 16.0) {					// 4 COLORS (GREENISH)
		TRY_COLOR (vec3 (156.0, 189.0,  15.0));
		TRY_COLOR (vec3 (140.0, 173.0,  15.0));
		TRY_COLOR (vec3 ( 48.0,  98.0,  48.0));
		TRY_COLOR (vec3 ( 15.0,  56.0,  15.0));
	}
	
	else if (mode == 17.0) {					// 11 COLORS (GRAYSCALE)
		TRY_COLOR (vec3 (255.0, 255.0, 255.0)); // L100
		TRY_COLOR (vec3 (226.0, 226.0, 226.0)); // L90
		TRY_COLOR (vec3 (198.0, 198.0, 198.0)); // L80
		TRY_COLOR (vec3 (171.0, 171.0, 171.0)); // L70
		TRY_COLOR (vec3 (145.0, 145.0, 145.0)); // L60
		TRY_COLOR (vec3 (119.0, 119.0, 119.0)); // L50
		TRY_COLOR (vec3 ( 94.0,  94.0,  94.0)); // L40
		TRY_COLOR (vec3 ( 71.0,  71.0,  71.0)); // L30
		TRY_COLOR (vec3 ( 48.0,  48.0,  48.0)); // L20
		TRY_COLOR (vec3 ( 27.0,  27.0,  27.0)); // L10
		TRY_COLOR (vec3 (  0.0,   0.0,   0.0)); // L0
	}
	
	else if (mode == 18.0) {					// 6 COLORS (GRAYSCALE)
		TRY_COLOR (vec3 (255.0, 255.0, 255.0)); // L100
		TRY_COLOR (vec3 (198.0, 198.0, 198.0)); // L80
		TRY_COLOR (vec3 (145.0, 145.0, 145.0)); // L60
		TRY_COLOR (vec3 ( 94.0,  94.0,  94.0)); // L40
		TRY_COLOR (vec3 ( 48.0,  48.0,  48.0)); // L20
		TRY_COLOR (vec3 (  0.0,   0.0,   0.0)); // L0
	}
	
	else if (mode == 19.0) {					// 3 COLORS (GRAYSCALE)
		TRY_COLOR (vec3 (255.0, 255.0, 255.0)); // L100
		TRY_COLOR (vec3 (145.0, 145.0, 145.0)); // L60
		TRY_COLOR (vec3 ( 48.0,  48.0,  48.0)); // L20
	}

	return old ;
}
//=====================================================================================================================

// Dither Matrix ======================================================================================================
float dither_matrix (float x, float y) {
	return mix(mix(mix(mix(mix(mix(0.0,32.0,step(1.0,y)),mix(8.0,40.0,step(3.0,y)),step(2.0,y)),mix(mix(2.0,34.0,step(5.0,y)),mix(10.0,42.0,step(7.0,y)),step(6.0,y)),step(4.0,y)),mix(mix(mix(48.0,16.0,step(1.0,y)),mix(56.0,24.0,step(3.0,y)),step(2.0,y)),mix(mix(50.0,18.0,step(5.0,y)),mix(58.0,26.0,step(7.0,y)),step(6.0,y)),step(4.0,y)),step(1.0,x)),mix(mix(mix(mix(12.0,44.0,step(1.0,y)),mix(4.0,36.0,step(3.0,y)),step(2.0,y)),mix(mix(14.0,46.0,step(5.0,y)),mix(6.0,38.0,step(7.0,y)),step(6.0,y)),step(4.0,y)),mix(mix(mix(60.0,28.0,step(1.0,y)),mix(52.0,20.0,step(3.0,y)),step(2.0,y)),mix(mix(62.0,30.0,step(5.0,y)),mix(54.0,22.0,step(7.0,y)),step(6.0,y)),step(4.0,y)),step(3.0,x)),step(2.0,x)),mix(mix(mix(mix(mix(3.0,35.0,step(1.0,y)),mix(11.0,43.0,step(3.0,y)),step(2.0,y)),mix(mix(1.0,33.0,step(5.0,y)),mix(9.0,41.0,step(7.0,y)),step(6.0,y)),step(4.0,y)),mix(mix(mix(51.0,19.0,step(1.0,y)),mix(59.0,27.0,step(3.0,y)),step(2.0,y)),mix(mix(49.0,17.0,step(5.0,y)),mix(57.0,25.0,step(7.0,y)),step(6.0,y)),step(4.0,y)),step(5.0,x)),mix(mix(mix(mix(15.0,47.0,step(1.0,y)),mix(7.0,39.0,step(3.0,y)),step(2.0,y)),mix(mix(13.0,45.0,step(5.0,y)),mix(5.0,37.0,step(7.0,y)),step(6.0,y)),step(4.0,y)),mix(mix(mix(63.0,31.0,step(1.0,y)),mix(55.0,23.0,step(3.0,y)),step(2.0,y)),mix(mix(61.0,29.0,step(5.0,y)),mix(53.0,21.0,step(7.0,y)),step(6.0,y)),step(4.0,y)),step(7.0,x)),step(6.0,x)),step(4.0,x));
}
//=====================================================================================================================

// Dither Method ======================================================================================================
vec3 dither (vec3 col, vec2 uv, float mode) {	
	col *= 255.0 * BRIGHTNESS;	
	col += dither_matrix (mod (uv.x, 8.0), mod (uv.y, 8.0)) ;
	col = find_closest (clamp (col, 0.0, 255.0), mode);
	return col / 255.0;
}
//=====================================================================================================================

float filmicReinhardCurve (float x) {
	float q = (T * T + 1.0) * x * x;
	return q / (q + x + T * T);
}

vec3 fReinhard (vec3 x) {
	float w = filmicReinhardCurve(W);
	return vec3(
		filmicReinhardCurve(x.r),
		filmicReinhardCurve(x.g),
		filmicReinhardCurve(x.b)) / w;
}

vec3 sat(vec3 rgb, float adjustment) {
	const vec3 W = vec3(0.2125, 0.7154, 0.0721);
	vec3 intensity = vec3(dot(rgb, W));
	return mix(intensity, rgb, adjustment);
}

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

vec2 transform(vec2 coord) {
	coord *= color_texture_pow2_sz / color_texture_sz;
	coord = (coord - vec2(0.5)) * aspect * stretch.z + stretch.xy;
	return (bkwtrans(coord) / overscan / aspect + vec2(0.5)) * color_texture_sz / color_texture_pow2_sz;
}

float corner(vec2 coord) {
	coord *= color_texture_pow2_sz / color_texture_sz;
	coord = (coord - vec2(0.5)) * overscan + vec2(0.5);
	coord = min(coord, vec2(1.0) - coord) * aspect;
	vec2 cdist = vec2(cornersize);
	coord = (cdist - min(coord, cdist));
	float dist = sqrt(dot(coord, coord));
	return clamp((cdist.x - dist) * cornersmooth, 0.0, 1.0);
}

vec4 scanlineWeights(float distance, vec4 color) {  
#ifdef USEGAUSSIAN
	vec4 wid = 0.3 + 0.1 * pow(color, vec4(3.0));
	vec4 weights = vec4(distance / wid);
	return 0.4 * exp(-weights * weights) / wid;
#else
	vec4 wid = 2.0 + 2.0 * pow(color, vec4(4.0));
	vec4 weights = vec4(distance / 0.3);
	return 1.4 * exp(-pow(weights * inversesqrt(0.5 * wid), wid)) / (0.6 + 0.2 * wid);
#endif
}

vec4 vignette(vec2 xy, vec4 col) {
	xy *= 1.0 - xy.yx;
	float vig = xy.x * xy.y * 15.0;
	vig = pow(vig, 0.25);
	return col *= vec4(vig);
}

void main() {  

	#ifdef CURVATURE
		vec2 xy = transform(texCoord);
	#else
		vec2 xy = texCoord;
	#endif

	float cval = corner(xy);

	vec2 ratio_scale = xy * color_texture_pow2_sz - vec2(0.5);

	#ifdef OVERSAMPLE
		float filter = fwidth(ratio_scale.y);
	#endif

	vec2 uv_ratio = fract(ratio_scale);
	xy = (floor(ratio_scale) + vec2(0.5)) / color_texture_pow2_sz;

	vec4 coeffs = PI * vec4(1.0 + uv_ratio.x, uv_ratio.x, 1.0 - uv_ratio.x, 2.0 - uv_ratio.x);
	coeffs = FIX(coeffs);
	coeffs = 2.0 * sin(coeffs) * sin(coeffs / 2.0) / (coeffs * coeffs);
	coeffs /= dot(coeffs, vec4(1.0));

	vec4 col  = clamp(mat4(
		TEX2D(xy + vec2(-one.x, 0.0)),
		TEX2D(xy),
		TEX2D(xy + vec2(one.x, 0.0)),
		TEX2D(xy + vec2(2.0 * one.x, 0.0))) * coeffs,
		0.0, 1.0);

	vec4 col2 = clamp(mat4(
		TEX2D(xy + vec2(-one.x, one.y)),
		TEX2D(xy + vec2(0.0, one.y)),
		TEX2D(xy + one),
		TEX2D(xy + vec2(2.0 * one.x, one.y))) * coeffs,
		0.0, 1.0);

	#ifndef LINEAR_PROCESSING
		col  = pow(col , vec4(CRTgamma));
		col2 = pow(col2, vec4(CRTgamma));
	#endif

	vec4 weights  = scanlineWeights(uv_ratio.y, col);
	vec4 weights2 = scanlineWeights(1.0 - uv_ratio.y, col2);

	#ifdef OVERSAMPLE
		uv_ratio.y = uv_ratio.y + 1.0 / 3.0 * filter;
		weights = (weights + scanlineWeights(uv_ratio.y, col)) / 3.0;
		weights2 = (weights2 + scanlineWeights(abs(1.0 - uv_ratio.y), col2)) / 3.0;
		uv_ratio.y = uv_ratio.y - 2.0 / 3.0 * filter;
		weights = weights + scanlineWeights(abs(uv_ratio.y), col) / 3.0;
		weights2 = weights2 + scanlineWeights(abs(1.0 - uv_ratio.y), col2) / 3.0;
	#endif

	vec3 mul_res  = (col * weights + col2 * weights2).rgb * vec3(cval);

	#define TEX2DH(x) texture2D(mpass_texture,x)
	vec3 blur = mix(mix(TEX2DH(xy),TEX2DH(xy+vec2(one.x,0.0)),uv_ratio.x),mix(TEX2DH(xy+vec2(0.0,one.y)),TEX2DH(xy+one),uv_ratio.x),uv_ratio.y).xyz;

	mul_res = mix(mul_res, pow(blur, vec3(CRTgamma)), halation);

	mul_res *= vec3(cval);

	vec3 dotMaskWeights = mix(
		vec3(1.0, 0.7, 1.0),
		vec3(0.7, 1.0, 0.7),
		floor(mod(gl_FragCoord.x, 2.0))
    );

	mul_res *= dotMaskWeights * 1.05;
	mul_res = clamp(pow(mul_res, vec3(1.00 / monitorgamma)) * 2.0, 0.0, 1.0);
	
	//mul_res = pow(filmicReinhard(mul_res), gammaBoost * 0.75);
	
	if (filmicReinhard > 0.0) {
		mul_res = mix(mul_res, fReinhard(mul_res), filmicReinhard);
	}

	mul_res = sat(mul_res, saturation);
	mul_res = pow(mul_res, gammaBoost * 0.8);

	if (palette_emulation > 0.0) { mul_res = dither(mul_res, xy, palette_emulation); }
	if ( xy.x < 0.0 || xy.x > 1.0 || xy.y < 0.0 || xy.y > 1.0 ) { mul_res = vec3(0); }

	gl_FragColor = vec4(mul_res, 1.0);
}
