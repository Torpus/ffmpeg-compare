# ffmpeg-compare

ffmpeg-compare takes at least one but up to three arguments: the source file, an optional target file size multiplier, and an optional pool setting for vmaf.  It then creates up to 10 samples by slicing out 10 seconds from every 10 minutes of the video to create a set of reference videos from the original.  These reference videos are then run through a number of encoding processes using the list of settings below.  Each set of encoded files are compared against the references using netflix's vmaf comparison and the 'vmaf_4k_v0.6.1.pkl' model.  I am targeting overall quality over reduced filesize so the resulting file may not save a ton of space compared to the source if you don't supply a target file size multiplier (in the form of a decimal, .5 meaning you want a resulting file size no greater than 50% of the original).
> it takes a while, be patient

- preset: ultrafast, superfast, veryfast, faster, fast, medium, slow, slower, veryslow
- crf: 0-51
- tune: grain, film, animation

optional pool values: harmonic_mean(default), mean, median, min, perc5, perc10 and perc20

## prereqs

- netflix's vmaf project [netflix/vmaf build](https://github.com/Netflix/vmaf/blob/master/resource/doc/libvmaf.md#use-libvmaf-with-ffmpeg)
  - copy vmaf's model directory into this project's root dir `cp -r <path-to-vmaf-root>/model .`
- ffmpeg built with libvmaf enabled [ffmpeg compile guide](https://trac.ffmpeg.org/wiki/CompilationGuide)

## usage

`./ffmpeg-compare.sh <input_file>`

`./ffmpeg-compare.sh <input_file> <target_multiplier>`

`./ffmpeg-compare.sh <input_file> <target_multiplier> <pool_name>`

## notes

I have been testing using a video I found licensed for creative commons use found here [Lake_and_Clouds_CCBY_NatureClip.mp4](https://www.videvo.net/download_new.php?hash=fd238e00faab809400c90241887dc093&test_new_server=1).  To test this I run

`./ffmpeg-compare.sh test/Lake_and_Clouds_CCBY_NatureClip.mp4`

`./ffmpeg-compare.sh test/Lake_and_Clouds_CCBY_NatureClip.mp4 .25`

`./ffmpeg-compare.sh test/Lake_and_Clouds_CCBY_NatureClip.mp4 .25 perc5`
