# ffmpeg-compare-script

ffmpeg-compare-script takes a single argument, the source file.  It then creates a composite video to use as a reference by splicing together the first 3s of every minute in the video to create a file ~ 5% of the original size.  This reference video is then run through a number of encoding processes using the list of settings below.  Each is compared against the reference using netflix's vmaf comparison and the 'vmaf_4k_v0.6.1.pkl' model.  I am targeting overall quality over reduced filesize so the resulting file may not save a ton of space compared to the source.  Future enhancement is to add a target size percentage.
> it takes a while, be patient

- preset: ultrafast, superfast, veryfast, faster, fast, medium, slow, slower, veryslow
- crf: 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24
- tune: grain, film, animation

## prereqs

- netflix's vmaf project [netflix/vmaf build](https://github.com/Netflix/vmaf/blob/master/resource/doc/libvmaf.md#use-libvmaf-with-ffmpeg)
  - copy vmaf's model directory into this project's root dir `cp -r <path-to-vmaf-root>/model .`
- ffmpeg built with libvmaf enabled [ffmpeg compile guide](https://trac.ffmpeg.org/wiki/CompilationGuide)

## usage

`./ffmpeg-compare.sh <input_file>`

## notes

I have been testing using a video I found licensed for creative commons use found here [birds-at-feeder](https://www.videvo.net/video/birds-at-feeder/380/).  To test this I place the downloaded file in a `test` directory and then run `./ffmpeg-compare.sh test/BirdsAndFeeder-H264\ 75.mov`
