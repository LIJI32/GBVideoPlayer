import sys

music = open(sys.argv[1]).read().splitlines()
ticks = int(sys.argv[2])
ticks_per_line = float(ticks) / len(music)

MIDDLE_A = 440.0
SEMITONE = 2.0 ** (1/12.0)
MIDDLE_C = MIDDLE_A * SEMITONE ** 3
SLIDE_MAGIC = SEMITONE ** (1/8.0)

DRUMS = {
    "C-503": "201F2177228B2380".decode("hex"),
    "C-504": "203F218122312380".decode("hex"),
    "C-505": "203F219222102380".decode("hex"),
    "C-506": "203F217122002380".decode("hex"),
    "C-507": "203F217122512380".decode("hex"),
    "A-407": "203F217122412380".decode("hex"),
    "C-508": "203F21F1226B2380".decode("hex"),
}
#203F2188226B2380 # Bass
#203F217122002380 # Close hat
#203F218122312380 # Snare
#203F219222102380 # Open hat

def note_to_frequency(note):
    index = ["C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-"].index(note[:2])
    octave = int(note[2]) - 5
    return MIDDLE_C * (SEMITONE ** index) * (2.0 ** octave)


pending_delay = 0
previous_frequencies = [None] * 3

for line in music:
    instruments = line[1:].split("|")

    # Instruments 1 & 2
    for index, instrument in enumerate(instruments[0:2]):
        note = instrument[0:3]
        volume = instrument[6:8]
        command = instrument[8]
        command_value = instrument[9:11]

        if note == "===":
            volume = "00"
            command = "."
            note = "..."
        elif note != "...":
            if volume == "..":
                volume = "64"

        if volume != "..":
            if pending_delay >= 1:
                sys.stdout.write("\x90")
                sys.stdout.write(chr(int(pending_delay)))
                pending_delay %= 1

            volume = int(volume)
            volume = int(round(volume / 64.0 * 0xF))
            sys.stdout.write("\x12" if index == 0 else "\x17")
            sys.stdout.write(chr(volume * 0x10))

        if note != "...":
            if pending_delay >= 1:
                sys.stdout.write("\x90")
                sys.stdout.write(chr(int(pending_delay)))
                pending_delay %= 1

            frequency = note_to_frequency(note)
            previous_frequencies[index] = frequency
            gb_frequency = int(round(2048 - 131072/frequency))
            assert gb_frequency < 2048
            sys.stdout.write("\x13" if index == 0 else "\x18")
            sys.stdout.write(chr(gb_frequency & 0xFF))
            sys.stdout.write("\x14" if index == 0 else "\x19")
            sys.stdout.write(chr((gb_frequency / 0x100) | 0x80)) # 80 = Init sound

        if command == "F":
            if pending_delay >= 1:
                sys.stdout.write("\x90")
                sys.stdout.write(chr(int(pending_delay)))
                pending_delay %= 1
            previous_frequencies[index] *= SLIDE_MAGIC ** int(command_value)
            frequency = previous_frequencies[index]
            gb_frequency = int(round(2048 - 131072/frequency))
            assert gb_frequency < 2048
            sys.stdout.write("\x13" if index == 0 else "\x18")
            sys.stdout.write(chr(gb_frequency & 0xFF))
            sys.stdout.write("\x14" if index == 0 else "\x19")
            sys.stdout.write(chr((gb_frequency / 0x100)))

        if command == "E":
            if pending_delay >= 1:
                sys.stdout.write("\x90")
                sys.stdout.write(chr(int(pending_delay)))
                pending_delay %= 1
            previous_frequencies[index] /= SLIDE_MAGIC ** int(command_value)
            frequency = previous_frequencies[index]
            gb_frequency = int(round(2048 - 131072/frequency))
            assert gb_frequency < 2048
            sys.stdout.write("\x13" if index == 0 else "\x18")
            sys.stdout.write(chr(gb_frequency & 0xFF))
            sys.stdout.write("\x14" if index == 0 else "\x19")
            sys.stdout.write(chr((gb_frequency / 0x100)))

    # Instrument 3
    note = instruments[2][0:3]
    command = instruments[2][8]
    command_value = instruments[2][9:11]

    if note != "...":
        if pending_delay >= 1:
            sys.stdout.write("\x90")
            sys.stdout.write(chr(int(pending_delay)))
            pending_delay %= 1

        if note == "===":
            sys.stdout.write("\x1A\x00") # Channel Off
        else:
            frequency = note_to_frequency(note)
            previous_frequencies[2] = frequency
            gb_frequency = int(round(2048 - 131072/frequency))
            assert gb_frequency < 2048
            try:
                sys.stdout.write("\x1A\x80") # Channel On
                sys.stdout.write("\x1D")
                sys.stdout.write(chr(gb_frequency & 0xFF))
                sys.stdout.write("\x1E")
                sys.stdout.write(chr((gb_frequency / 0x100) | 0x80)) # 80 = Init sound
            except:
                sys.stderr.write(line+"\n")

    if command == "F":
        if pending_delay >= 1:
            sys.stdout.write("\x90")
            sys.stdout.write(chr(int(pending_delay)))
            pending_delay %= 1
        previous_frequencies[2] *= SLIDE_MAGIC ** int(command_value)
        frequency = previous_frequencies[2]
        gb_frequency = int(round(2048 - 131072/frequency))
        assert gb_frequency < 2048
        sys.stdout.write("\x1D")
        sys.stdout.write(chr(gb_frequency & 0xFF))
        sys.stdout.write("\x1E")
        sys.stdout.write(chr((gb_frequency / 0x100)))

    if command == "E":
        if pending_delay >= 1:
            sys.stdout.write("\x90")
            sys.stdout.write(chr(int(pending_delay)))
            pending_delay %= 1
        previous_frequencies[2] /= SLIDE_MAGIC ** int(command_value)
        frequency = previous_frequencies[2]
        gb_frequency = int(round(2048 - 131072/frequency))
        assert gb_frequency < 2048
        sys.stdout.write("\x1D")
        sys.stdout.write(chr(gb_frequency & 0xFF))
        sys.stdout.write("\x1E")
        sys.stdout.write(chr((gb_frequency / 0x100)))

    pending_delay += ticks_per_line

    # Instrument 4
    sample = instruments[3][:5]
    if sample in DRUMS:
        if pending_delay >= 1:
            sys.stdout.write("\x90")
            sys.stdout.write(chr(int(pending_delay)))
            pending_delay %= 1
        sys.stdout.write(DRUMS[sample])
    elif sample != ".....":
        sys.stderr.write("Missing drum definition for %s. \n"  % (sample,))

if pending_delay >= 1:
    sys.stdout.write("\x90")
    sys.stdout.write(chr(int(pending_delay)))
    pending_delay %= 1