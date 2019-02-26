# ffmpeg-compare

ffmpeg-compare takes at least one but up to two arguments: the source file and an optional target file size multiplier.  It then creates a number of samples by slicing out 15 seconds from every 5 minutes of the video to create a set of files ~5% of the original size.  These reference videos are then run through a number of encoding processes using the list of settings below.  Each is compared against the reference using netflix's vmaf comparison and the 'vmaf_4k_v0.6.1.pkl' model.  I am targeting overall quality over reduced filesize so the resulting file may not save a ton of space compared to the source if you don't supply a target file size multiplier (in the form of a decimal .5 means you want a resulting file size no greater than 50% of the original).
> it takes a while, be patient

- preset: ultrafast, superfast, veryfast, faster, fast, medium, slow, slower, veryslow
- crf: 0-51
- tune: grain, film, animation

## prereqs

- netflix's vmaf project [netflix/vmaf build](https://github.com/Netflix/vmaf/blob/master/resource/doc/libvmaf.md#use-libvmaf-with-ffmpeg)
  - copy vmaf's model directory into this project's root dir `cp -r <path-to-vmaf-root>/model .`
- ffmpeg built with libvmaf enabled [ffmpeg compile guide](https://trac.ffmpeg.org/wiki/CompilationGuide)

## usage

`./ffmpeg-compare.sh <input_file>`
`./ffmpeg-compare.sh <input_file> <target_multiplier>`

## notes

I have been testing using a video I found licensed for creative commons use found here [birds-at-feeder](https://www.videvo.net/video/birds-at-feeder/380/).  To test this I place the downloaded file in a `test` directory and then run

`./ffmpeg-compare.sh test/BirdsAndFeeder-H264\ 75.mov`
`./ffmpeg-compare.sh test/BirdsAndFeeder-H264\ 75.mov .75`
`./ffmpeg-compare.sh test/BirdsAndFeeder-H264\ 75.mov .5`
`./ffmpeg-compare.sh test/BirdsAndFeeder-H264\ 75.mov .25`
