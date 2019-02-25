#!/usr/bin/env bash

SOURCE_FILE=$1
PREV_FILE=""
PREV_VMAF=0
PRESETS=( ultrafast superfast veryfast faster fast medium slow slower veryslow )
CRFS=( 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 )
TUNES=( grain film animation )
TEMP_FILE_LIST=temp_file_list.txt
BASE_FILENAME=$(basename "$SOURCE_FILE" | cut -f 1 -d '.')
BASE_FILENAME=${BASE_FILENAME// /_}
BASE_DIR="$BASE_FILENAME"-tests
TEMP_DIR="$BASE_DIR"/source_temp
mkdir -p "$TEMP_DIR"

grabSnippet() {
    START_OFFSET=${1:-0}
    OFFSET_ARRAY=" $OFFSET_ARRAY $START_OFFSET "
    if [ "$(($START_OFFSET + 3))" -lt "$ORIGINAL_DURATION" ]
    then
        grabSnippet "$(($START_OFFSET + 60))"
    fi
}

updateBest() {
    PREV_FILE="$BASE_DIR"/"$THIS_FILE"
    PREV_FILESIZE=$THIS_FILESIZE
    PREV_VMAF=$VMAF
    BEST_PRESET=$PRESET
    BEST_TUNE=$TUNE
    BEST_CRF=$CRF
}

bytesToHuman () {
    numfmt --to=iec-i --format='%.5f' "$1"
}

flessthan() {
    awk -v n1="$1" -v n2="$2" 'BEGIN {if (n1+0<n2+0) exit 0; exit 1}'
}

fequal() {
    awk -v n1="$1" -v n2="$2" 'BEGIN {if (n1+0==n2+0) exit 0; exit 1}'
}

echo Starting processing "$SOURCE_FILE"
ORIGINAL_DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$SOURCE_FILE" | grep -Poh -m 1 "([0-9]{1,9})" | head -1)

grabSnippet
OFFSET_ARRAY=( $OFFSET_ARRAY )

for i in "${!OFFSET_ARRAY[@]}"
do
    TEMP_FILE="$BASE_FILENAME"_source_"$i".mkv
    echo "file '$TEMP_FILE'" >> "$TEMP_DIR"/"$TEMP_FILE_LIST"
    ffmpeg -loglevel panic -ss "${OFFSET_ARRAY[$i]}" -i "$SOURCE_FILE" -t "00:00:03" -c:v copy -avoid_negative_ts 1 -sn -an "$TEMP_DIR"/"$TEMP_FILE"
done
REF_FILE="$BASE_DIR"/"$BASE_FILENAME"_source.mkv
ffmpeg -loglevel panic -f concat -i "$TEMP_DIR"/"$TEMP_FILE_LIST" -c:v copy -an -sn "$REF_FILE"
rm -rf "$TEMP_DIR"
REF_FILESIZE=$(stat -c%s "$REF_FILE")
PREV_FILESIZE="$REF_FILESIZE"
echo Created composite video with filesize "$(bytesToHuman "$REF_FILESIZE")"

BEST_PRESET=""
BEST_TUNE=""
BEST_CRF=""

for PRESET in "${PRESETS[@]}"
do
    for TUNE in "${TUNES[@]}"
    do
        for CRF in "${CRFS[@]}"
        do
            echo Running with preset="$PRESET", crf="$CRF", and tune="$TUNE"
            THIS_FILE="$BASE_FILENAME"_"$PRESET"_crf"$CRF"_"$TUNE"
            ffmpeg -loglevel panic -i "$REF_FILE" -c:v libx264 -crf "$CRF" -preset "$PRESET" -tune "$TUNE" -sn -an "$BASE_DIR"/"$THIS_FILE".mkv
            THIS_FILESIZE=$(stat -c%s "$BASE_DIR"/"$THIS_FILE".mkv)
            if [ "$THIS_FILESIZE" -lt "$REF_FILESIZE" ]
            then
                echo Continuing with VMAF: 0"$(bc <<< "scale=5; $THIS_FILESIZE / $REF_FILESIZE")"X file size
                VMAF=$(ffmpeg -i "$BASE_DIR"/"$THIS_FILE".mkv -i "$REF_FILE" -lavfi libvmaf="pool=perc5:log_fmt=json:model_path=model/vmaf_4k_v0.6.1.pkl" -f null - 2>&1 | grep "\[libvmaf" | grep "VMAF score" | grep -Poh "([0-9]{1,3}\.[0-9]{1,15})")
                if flessthan "$PREV_VMAF" "$VMAF"
                then
                    echo New best with vmaf="$VMAF" and "$(bc <<< "scale=5; $THIS_FILESIZE / $PREV_FILESIZE")"X file size
                    updateBest
                    if [ "$PREV_FILE" != "" ]
                    then
                        rm "$PREV_FILE".*
                    fi
                elif fequal "$PREV_VMAF" "$VMAF"
                then
                    if [ "$THIS_FILESIZE" -lt "$PREV_FILESIZE" ]
                    then
                        echo Same quality result: vmaf="$VMAF" but smaller file size.  New best with vmaf="$VMAF" and "$(bc <<< "scale=5; $THIS_FILESIZE / $PREV_FILESIZE")"X file size
                        updateBest
                    else
                        echo Same quality result: vmaf="$VMAF" but larger or same file size.  Retaining previous best preset="$BEST_PRESET", best tune="$BEST_TUNE", best crf="$BEST_CRF"
                    fi
                else
                    echo Lower quality result: vmaf="$VMAF" \< "$PREV_VMAF".  Retaining previous best preset="$BEST_PRESET", best tune="$BEST_TUNE", best crf="$BEST_CRF"
                    rm "$BASE_DIR"/"$THIS_FILE".*
                    break
                fi
            else
                echo Too big: "$(bc <<< "scale=2; $THIS_FILESIZE / $REF_FILESIZE")"X file size
                rm "$BASE_DIR"/"$THIS_FILE".mkv
            fi
        done
    done
done

echo best preset="$BEST_PRESET", best tune="$BEST_TUNE", best crf="$BEST_CRF"