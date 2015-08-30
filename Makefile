ifndef VIDEO_SRC_FOLDER
    $(error VIDEO_SRC_FOLDER is not defined; it should be a path to a video folder in a compatible format)
endif

video.gbc: video.o $(VIDEO_SRC_FOLDER)/video.gbv
	rgblink -o $@ -m video.map -n video.sym $<
	cat $(VIDEO_SRC_FOLDER)/video.gbv >> $@
	rgbfix -Cv -i GBVP -t "GBVideo" -m 25 $@
CLEAN += video.gbc video.sym video.map

video.o: video.asm music.gbm gbhw.asm
	rgbasm -o $@ $<
CLEAN += video.o

music.gbm: music.itt
	@# 3571 is the hardcoded length for the Pokémon Theme
	python itt.py $< 3571 > $@
CLEAN += music.gbm

$(VIDEO_SRC_FOLDER)/video.gbv: $(VIDEO_SRC_FOLDER)
	python convert.py $(VIDEO_SRC_FOLDER) `ls -1 $(VIDEO_SRC_FOLDER)/*.png | wc -l`

clean:
	rm $(CLEAN)