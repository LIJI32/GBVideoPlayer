# Player

This is a technical demo demonstrating how the Gameboy LCD controller can be hacked to make a Gameboy Color play a full motion video in color, together with music. It is inspired by [8088 Corruption](http://www.youtube.com/watch?v=H1p1im_2uf4) and [8088 Domination](http://www.youtube.com/watch?v=MWdG413nNkI).

## tl;dr
Here's a video of a [Gameboy Color playing the Pokémon TV Opening](http://www.youtube.com/watch?v=c5HfmaDCVsY). You can get the ROM at [the releases page](https://github.com/LIJI32/GBVideoPlayer/releases) and run it on your Gameboy Color with a flash cart or an emulator with good accuracy like BGB. You will need to turn on inter-frame blending in the emulator for accurate results.

## Technical Specifications
The player itself, due to the high optimization requirements and CPU cycle counting, is written in Z80 assembly. The video encoder has two stage, with the first once being a batch script run by Photoshop, and the other being a python script. The music is written in an OpenMPT-style textual format, which is later converted to a compact binary format which is easy to play.

The Gameboy Color uses a 8MHz Z80 8-bit processor, which effectively runs at 2MHz (Since the CPI of each instruction is a multiple of 4). To play the Pokémon theme in a good quality (I.e. not too many frame skips) it requires a 7.6MB ROM, which is huge in Gameboy terms. The LCD controller (OAMs are ignored by the player) is designed output, in 60 FPS, a 160x144 image, composed of a map of 32x32 tiles size 8x8, each can have a 4-color palette from a selection of user-defined 8 palette. It does not allow direct pixel access. Since the player uses less than 20 bytes of RAM (slight stack use and a very small state), memory is not an issue.

There's an article explaining [How It Works](How+It+Works.md).

The video format has the following properties:

 * Effective frame resolution of 40x144 pixels, resized to fill the 160x144 Gameboy screen
 * Effectively up to 528 different colors per frame
 * 30 Frames per second
 * Can repeat a single frame for up to 127 times, allowing the encoder to skip similar frames
 * The player and the encoder have a buggy (and disabled) support for what I call a row-back-reference compression. Any type of in-row compression simply can not work because there aren't enough free CPU cycles to decompress it.

## Hardware support
Any MBC5-capable cart that is big enough to store the ROM should be enough. It was tested only on an original Gameboy Color (And only one to be honest), but will probably work on a Gameboy Advance too.

## Emulator support
Due to exploiting hardware hacks and very precise timing, the player hardly works on any emulator. BGB is the only one capable of reasonably emulating the player, and it's still not perfect. There used to be another emulator (forgot its name, sorry!) that could run it; however, I had to make a choice between supporting it and supporting BGB, as a single opcode change would break it for one and fix it for the other, and the other emulator did not have any debugger. For best results, use an emulator that support inter-frame blending.

## Compilation
You will need [rgbds](https://github.com/bentley/rgbds/releases/). To compile a player playing the Pokémon TV Opening, run:

    make VIDEO_SRC_FOLDER=PokemonTheme

To convert your own video, split it into a sequence of PNGs, and batch run the included GBEncode Photoshop Action on all of them. The output images should be named 0.png, 1.png, ..., n.png and be placed on a folder of their own. Then run:

    make VIDEO_SRC_FOLDER=MyVideoFolder