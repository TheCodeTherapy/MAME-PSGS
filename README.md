# MAME-PSGS ( MAME Platform-Switcher GLSL Shader)

[![Watch the video](https://mgz.me/publicfiles/images/mamepsgs.png)](https://youtu.be/u__lpFvR4kA)

## What?

Have you ever wondered how would be the looks of one of your Megadrive (Sega Genesis) games if you could play it on Commodore 64, or on MSX, or even on an AppleII? Now you don't have to wonder anymore.

As MAME is now capable of emulating ROMs from several different platforms (including home systems and home consoles) and not only Arcade games anymore, you can run everything (well, almost everything) through it.

## Why?

By doing some research I noticed that there's a huge demand for decent GLSL Shaders for MAME, as programmers used to focus on HLSL Shaders (which was not a bad mindset, as MAME used to be a software executed almost exclusively on PCs using Windows, thus, with Direct3D/DirectX 9.0 available as it's graphics motor/pipeline). However, now we have a HUGE community using MAME on Android based devices (like Raspberry Pi 3, Odroid XU4 and other single-board computers), and also on Linux systems, with no native access to DirectX (thus, no HLSL Shaders compatibility).

## How?

So I decided to write a decent GLSL Shader (with all the desired goodies like CRT-like distortion, scan-lines, etc.). Then I took the opportunity to include a dithering-based color approximation special method that I wrote to emulate some classic hardware platforms's color palettes, which in my experience can bring a great nostalgic look and feel for those who love old-school systems emulation. So now I can, for example, play Arcade's Street Fighter Alpha 2 "replacing" it's graphics chip for Commodore 64 one... or even play Megadrive's Sonic restricting it to AppleII's or MSX's color palettes. Cool heh?

![](http://mgz.me/mame-psgs/Image6.jpg)

## Tell me more...

The platforms I've enabled to emulate on my shader so far are:

- AppleII series 16-color composite video palette representation, based on YIQ color space used by NTSC;
- Commodore VIC-20 based on MOS Technology VIC chip (also a 16-color YpbPr composite video palette);
- Commodore 64 based on MOS Technology VIC-II chip (also a 16-color YpbPr composite video palette);
- MSX compatible computers using a Texas Instruments TMS9918 chip providing a proprietary 15-color YPbPr;
- IBM PC CGA Mode 4 palette #1 with both intensities (low and high)... The good old Cyan-magenta "7-color" IBM RGBi;
- 16-color RGBi IBM CGA as seen on registers from compatible monitors back then
- NESish 54 colors palette / YIQ color space was used to create a 64-color palette (with 54 usable colors);

... besides many other hand-crafted color palettes to make the experience richer :)

## Question...

Q: "But why didn't you include **THAT** system???"

A: Probably because I did not have the time to research about it's color palette yet, or because it's a system capable of showing a limited amount of colors at the same time, chosen dynamically as per scene basis (not a fixed unchangeable color palette, but a restricted palette picked dynamically among a much broader color availability).

Q: "Can I add more custom color palettes myself?"

A: Sure, like I did with the below one. Just research the system you want to emulate, and write it to the Shader.

```
// Commodore 64 based on MOS Technology VIC-II chip (also a 16-color YpbPr composite video palette)...
// This one evolved from VIC-20 and now counts with 3 shades of grey.
if (mode == 3.0) {
    tryColor(vec3(  0.0,   0.0,   0.0)); //  0 - black       (YPbPr = 0.0   ,  0.0   ,  0.0   )
    tryColor(vec3(255.0, 255.0, 255.0)); //  1 - white       (YPbPr = 1.0   ,  0.0   ,  0.0   )
    tryColor(vec3(161.0,  77.0,  67.0)); //  2 - red         (YPbPr = 0.313 , -0.383 ,  0.924 )
    tryColor(vec3(106.0, 193.0, 200.0)); //  3 - cyan        (YPbPr = 0.625 ,  0.383 , -0.924 )
    tryColor(vec3(162.0,  86.0, 165.0)); //  4 - purple      (YPbPr = 0.375 ,  0.707 ,  0.707 )
    tryColor(vec3( 92.0, 173.0,  95.0)); //  5 - green       (YPbPr = 0.5   , -0.707 , -0.707 )
    tryColor(vec3( 79.0,  68.0, 156.0)); //  6 - blue        (YPbPr = 0.25  ,  1.0   ,  0.0   )
    tryColor(vec3(203.0, 214.0, 137.0)); //  7 - yellow      (YPbPr = 0.75  , -1.0   ,  0.0   )
    tryColor(vec3(163.0, 104.0,  58.0)); //  8 - orange      (YPbPr = 0.375 , -0.707 ,  0.707 )
    tryColor(vec3(110.0,  83.0,  11.0)); //  9 - brown       (YPbPr = 0.25  , -0.924 ,  0.383 )
    tryColor(vec3(204.0, 127.0, 118.0)); // 10 - light red   (YPbPr = 0.5   , -0.383 ,  0.924 )
    tryColor(vec3( 99.0,  99.0,  99.0)); // 11 - dark grey   (YPbPr = 0.313 ,  0.0   ,  0.0   )
    tryColor(vec3(139.0, 139.0, 139.0)); // 12 - grey        (YPbPr = 0.469 ,  0.0   ,  0.0   )
    tryColor(vec3(155.0, 227.0, 157.0)); // 13 - light green (YPbPr = 0.75  , -0.707 , -0.707 )
    tryColor(vec3(138.0, 127.0, 205.0)); // 14 - light blue  (YPbPr = 0.469 ,  1.0   ,  0.0   )
    tryColor(vec3(175.0, 175.0, 175.0)); // 15 - light grey  (YPbPr = 0.625  , 0.0   ,  0.0   )
}
```

## How do I use it? I'm not a programmer :(

Just **copy the glsl folder inside your MAME directory**, and **edit your mame.ini** to enable GLSL shaders, and then point my custom shader like I did in the mame.ini quote below:

```
#
# OpenGL-SPECIFIC OPTIONS
#
gl_forcepow2texture       0
gl_notexturerect          0
gl_vbo                    1
gl_pbo                    1
gl_glsl                   1
gl_glsl_filter            1
glsl_shader_mame0         ".\glsl\mame-psgs"
```

The most important parameters above are:
**`gl_glsl 1`** to enable the GLSL shaders;
**`glsl_shader_mame0 ".\glsl\mame-psgs"`** to specify the path for the Vertex and Fragment shaders.

Please make sure that you're using `opengl` as your MAME video mode. You can change the video mode through the GUI, or editing your `mame.ini` file manually. Just search for the `# OSD VIDEO OPTIONS` section on `mame.ini`, and set the `video` parameter to `opengl` as shown in the quote below:

```
#
# OSD VIDEO OPTIONS
#
video                     opengl
numscreens                1
window                    0
maximize                  1
waitvsync                 0
syncrefresh               0
monitorprovider           auto
```

## How do I select the color palette emulation that I want to play with?

All the configuration settings for the shader are specified on the Vertex Shader (**`mame-psgs.vsh`**). You can edit the file and select the palette emulation you want on the **`palette_emulation = <value>;`** line. The modes are briefly described right above the configuration line, as per you can see on this part of the file:

```
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

palette_emulation = 13.0; // Color palette emulation (change this value)
```

## Will you create more custom color palettes?

Yes, you can follow this repo so you can keep updated once I include new ones **:) You can also Favorite / Star this repo so I can have an idea if this was useless for others than me (I loved playing with it), and if I should invest more time on refining the shader's results** (and maybe some optimization as I don't have the resources to test it on slower platforms as Raspberry Pi 3 to evaluate the shader's performance). Thanks in advance for your interest. Have fun playing some old-school games :)

## Will you write something similar to be used with DirectX 9.0?

Yes, it is on my plans to write the HLSL version of this same shader (maybe with some extra features) ASAP.

## That's great man! How can I support you to do more cool stuff like that?

Just say hi to me on Twitter, or Tweet me memes [@TheCodeTherapy](https://twitter.com/TheCodeTherapy)
