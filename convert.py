import sys
import png

BANK_SIZE = 0x4000
COLOR_SIZE = 2
PALETTE_COLORS = 32
PALETTE_SIZE = PALETTE_COLORS * COLOR_SIZE
# It is not allowed to switch banks during a frame header or a data row. This
# defines the size of the zone at the bank's end where new data can't start.
RED_ZONE = PALETTE_SIZE + 1
# Frame with a difference lower than this will be considered identical, and only
# the first will be encoded.
SKIP_THRESHOLD = 96

def rgb2gb(r, g, b):
    r = int(round(r / 255.0 * 31))
    g = int(round(g / 255.0 * 31))
    b = int(round(b / 255.0 * 31))
    color1 = (r + (g % 8) * 32)
    color2 = g/8 + b * 4
    return chr(color2) + chr(color1)

def fill_bank(out):
    # Fill the bank if we're in the red zone already.
    if out.tell() % BANK_SIZE >= (BANK_SIZE - RED_ZONE):
        out.write("\xFF" * (BANK_SIZE - out.tell() % BANK_SIZE))

def color_diff(a, b):
    a = int(a.encode("hex"), 16)
    b = int(b.encode("hex"), 16)
    r1 = a % 32
    r2 = b % 32
    g1 = a / 32 % 32
    g2 = b / 32 % 32
    b1 = a /32 / 32 % 32
    b2 = a /32 / 32 % 32

    return (abs(r1-r2) + abs(g1-g2) + abs(b1-b2)) / 31.0

def frame_diff(a, b, max):
    diff = 0
    for i in xrange(0, len(a)):
        diff += color_diff(a[i], b[i])
        if diff > max:
            break
    return diff




def convert(folder, n_frames):
    palette = ["\xFF\xFF"] * 32
    frames = []
    out = open("%s/video.gbv" % (folder,) , "w")
    skipped = 0
    current_skip = 0
    rows = {}
    for i in xrange(0, n_frames):
        print "\r %d/%d (%d skipped)" % (i + 1, n_frames, skipped),
        sys.stdout.flush()

        image = png.Reader("%s/%d.png" % (folder, i)).asRGB8()[2]
        offset = 0
        colors = []
        frame = []

        location = out.tell()

        # Create palette, attempt to keep previous colors to improve row-back-
        # referencing compression rate.
        for y, line in enumerate(image):
            for x in xrange(len(line) / 3):
                pixel = rgb2gb(*line[x*3: x*3+3])
                if pixel not in colors:
                    colors += [pixel]

        palette = [(color if color in colors else "\xFF\xFF") for color in palette]
        for color in colors:
            if color not in palette:
                palette[palette.index("\xFF\xFF")] = color

        binary_palette = (''.join(palette))[::-1]
        assert len(palette) == PALETTE_COLORS

        ## Write the frame header

        # Write the repeat count, it will be increased later if needed
        out.write("\x01")
        # Write the palette
        out.write(binary_palette)

        # Fill the bank if we're in the red zone after the header
        fill_bank(out)

        # Write the data
        image = png.Reader("%s/%d.png" % (folder, i)).asRGB8()[2]
        diff = 0xffffffff

        for y, line in enumerate(image):
            row = ""
            # Write a single row
            for x in xrange(len(line) / 3):
                rgb = line[x*3: x*3+3]

                pixel = rgb2gb(*rgb)
                frame += [pixel]
                # This byte is the Y scroll value required to display request
                # color in this specific row. This value must be odd - it is
                # required to support row-back-referencing. This calculation
                # can be improved to enhance RBR compression rate.
                offset = chr(((palette.index(pixel) * 4 - (y%144) + 256 + 1) | 1) % 256)
                row += offset

            if True: # row not in rows or i == 0: # Row compression has some
                     # unfixed bugs, so it's disabled for now; the compression
                     # rate isn't that great anyway. I probably something silly
                     # I did broke it, but I can't remember if it ever worked.
                rows[row] = out.tell()
                out.write(row)
            else:
                row_location = rows[row]
                bank = row_location / BANK_SIZE + 1
                address = row_location % BANK_SIZE + 0x4000
                out.write(chr(bank / 256 * 2))
                out.write(chr(bank % 256))
                out.write(chr(address % 256))
                out.write(chr(address / 256))

            # Fill the bank if we're in the red zone after a row
            fill_bank(out)

        if len(frames):
            # Calculate diff between this and the previous frame
            diff = frame_diff(frame, frames[-1][1], 256)

        frames += [(location, frame)]

        if (diff < SKIP_THRESHOLD and current_skip < 127):
            # Update the repeat count in the previous frame
            current_skip += 1
            out.seek(frames[-2][0])
            out.write(chr(current_skip * 2 + 1))

            # Delete the frame we just wrote
            out.seek(frames[-1][0])
            out.truncate()

            # Delete rows used in this frame from the rows dict
            bad_keys = []
            for key, value in rows.iteritems():
                if value > frames[-1][0]:
                    bad_keys += [key]

            for key in bad_keys:
                rows.pop(key)

            # Remove this frame from the frame list
            frames = frames[:-1]

            # For statistics
            skipped += 1
        else:
            # Reset the skip - we actually wrote our frame
            current_skip = 0

    # Useful for debugging
    # for offset, frame in frames:
    #     print hex(offset)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print "Usage: %s folder frame_count" % (sys.argv[0],)
        exit(1)
    convert(sys.argv[1], int(sys.argv[2]))