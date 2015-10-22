#Audio Subtitler

##Dependencies

Requires ffmpeg compiled with --enable-libfreetype and --enable-libfontconfig.
Also uses ffprobe, but that should be included with ffmpeg.

##Usage

Take any audio file supported by ffmpeg and run it through the script once to create a config file. Modify the config file with subtitles of your choosing and run the script with the config file to create the video. Modify the script if you require a different video size or other font or font size, etc.

```
./AudioSubtitler audiothing.mp3
./AudioSubtitler --config=generatedConfig.txt
```

To print usage just run the script without any parameters.

