# How It Works
This article describes the principles behind the Gameboy Video Player. You should read this article before diving into the source code.

## General Gameboy Graphics
The Gameboy LCD controller does not provide direct pixel access to the user. Generally, with OAMs (Sprites) aside, it constructs a 160x144 pixels image using 5 parameters: (Gameboy developers; please excuse me for the simplification)

* A tileset – a set of several 8x8 bitmaps, each with a 2-bit color depth
* A tilemap – a two-dimensional table of indexes in the tileset, that basically places the tiles in a 2D space
* Palettes – a set of 8 palettes, each containing 4 16-bit colors
* An attribute map – a map that “connects” each tile position in the tile map to a palette (We'll ignore the other attributes here)
* Control registers – several flags and single values that affect the images, such as the scroll value that sets which position of the tilemap is to be displayed in the top-left corner

The LCD controller can be in several different states (Again, simplifying to omit irrelevant content):

* VBlank – the LCD controller is now “between” two frames. It is not currently rendering anything.
* HBlank – the LCD controller finished rendering a single row of pixels, and will soon start rendering the next row in the same frame.
* Rendering – a row in a tile (i.e. a line of 8 pixels) is currently being rendered by the controller.

The important thing to note is, that only the control registers may be freely modified at any time. During the time the LCD controller is in rendering mode, you *mostly* can't modify the other data, located in the VRAM.

If we want to play a video in real time and in a decent resolution (i.e. higher than a 8x8 pixelated image, 20x18) in a "traditional" fashion, we would have at the very least overwrite the entire tilemap every (video) frame. This is too much for a Gameboy CPU to handle in a decent FPS, so we must find a better solution.

## HBlank and sub-HBlank tricks
Since you can change control registers between rows while the controller is rendering, it allows you to "break" out of the 8x8 tile grid and create complex effects while hardly spending any processing power. A very common technique used in many Gameboy games is to change the X scrolling register or Y scrolling register in a sine-like manner to create two different styles of "wave" effects. However, since the HBlank period is *very* short, the code that changes these registers "live" must be very short and very fast.

A less known technique, however, is to modify the Y scrolling register (more on why Y and not X later) *during* the rendering process. This must be done **much** faster than we would do in a standard HBlank trick. How fast? By the time a Gameboy Color CPU at 8MHz finishes running these two instructions:

    ld a, [hli] ; Load a from memory pointed by hl, and increase hl (so we don't write the same value over over again)
    ld [c], a ; Store a to a register pointed by c
    
the LCD controller will already have rendered 8 pixels! With Gameboy CPU on a "classic" 4MHz mode, the LCD controller will manage to render **16 pixels**!

So now we can select a value for the Y-scroll register for each group of 8 pixels in a row, assuming we have these values stored one after another in the RAM or ROM.

## Render a 20x144 image

How can we use such trick to quickly render an image with a resolution somewhat better than 20x18 pixels, without writing a lot of data every frame? Let's assume we have a ability to “fill” a group of 8 pixels row with a solid color. This would allow us to render a 20x144 image, "stretched" to fill the 160x144 screen.

The way we "fill" these rows is as described; at start up, we set the tileset, tilemap and attribute map up so they construct an image of 32 horizontal lines. Each line will have a different color and be 4 pixel thick.

Now, every frame, we change the palette so it contains the 32 different colors used in that frame; and in our sub-HBlank trick, we change the Y-scroll value so the line in the color we want is positioned at the current (screen-)row we are rendering. This calculation of Y-scroll value can be done inside the encoder. (It *must* be done actually, we don't have enough CPU cycles to calculate it ourselves) 

This image demonstrates how it happens. The left image is what the screen actually looks like, with darkened parts not rendered yet. The right image shows what the screen would have looked like if it rendered immediately right now (I.e., what the LCD controller *attempts* to currently render). The red arrow is the currently rendered 8-pixel row.

<img src="doc_images/scroll_animation.gif?raw=true" style="image-rendering: pixelated; height:288px;" />

Remember that if the same color is two be rendered in two *different* rows on the screen in the same frame, each 8-pixel group would require a **different** Y-scroll value.

This method can be enhanced to improved image quality, such as allowing all 128 allowed two-color combinations in a single 8-pixel group, to make the resolution 40x144 pixels. This was not implemented in this simple demo (it might be in the future) because this would require a more complex encoder (Out of 32x32 (=1024) two-color combinations, only 128 are possible to create. We must carefully construct 8 different palettes!). Another option is to reduce the color quality to 4 colors only and have a 80x144 images without such limitations, or reduce the color even more to 2 colors and have a full resolution of 160x144.

## Improving color depth and resolution

Our current resolution isn't very impressive. This is when we use two more techniques to effectively double the horizontal resolution to 40, while effectively displaying up to 528 different colors per frame.

We actually take advantage of the fact that the Gameboy LCD itself has a very poor refresh rate. Effectively, every frame rendered on screen, is blended "50-50" with the previous frame. Careful encoding of two images and displaying them one after another can produce an image with up two 528 different colors. But how can we improve the horizontal resolution using this trick? We are blending two 20x144 pixel images directly on top of each other, this will obviously still produce a 20x144 image.

For this, we will need another trick. There comes a useful fact: when the LCD controller renders an 8-pixel group, it is always *aligned to an 8-pixel wide tile*. So what happens when we set the X-scroll to 4? In this case, the very first pixel is not aligned to a tile! Well, the LCD controller will first render a *4-pixel group of bytes*, then render pixels in groups of 8 again. Basically, this will *offset* our image by 4 pixels! This allows, using careful encoding, to enhance the resolution to 40x144 while reducing the FPS from the native 60 to the more reasonable 30. The downside of this technique, is that it introduces an horizontal blur to the image, but it's still better than the lower resolution image.

So let's see how this will preform on this sample image:

![Sample image](doc_images/sample.png?raw=true)

This is how it will look like with a standard 20x144 resolution:

![Sample image in 20x144](doc_images/sample_w20.png?raw=true)

These are the two images we'll blend together:

![Sample image in 'stereo'](doc_images/sample_stereo.png?raw=true)

And the final result:

![Sample image in 40x144](doc_images/sample_w40.png?raw=true)

Note the careful terminology: although this does *introduce blur* into the image, it does not "*blur*" the image. A similar improvement cannot be achieved without additional data; take for example the same sample image, with plain blur on the 20x144 version:

![Sample image with plain blur](doc_images/sample_blur.png?raw=true)

The result is hardly as good.

This same technique can also be applied to the suggested improvements from the last section: 

 * The 32-color 40x144 version will become 528-color 80x144
 * The 4-color 80x144 version will become 10-color 160x144
 * The 2-color 160x144 version will become 3-color or 4-color (with reduced contrast) 160x144, without introducing blur.
 
# The rest of it
 
The actual implementation is quite easy to understand once you know what it actually does. After reading this article it should be easy to understand the player code and the encoder. The file format for the video is quite irregular due to the unusual requirements of such video player, but since the encoder has a lot of comments, it should be easy enough to understand.