#!/usr/bin/env bash

SOURCE_FILE=$1
SIZE_MULTIPLIER=${2:-1}
echo Input file: "$SOURCE_FILE"
echo Target output size: "$SIZE_MULTIPLIER"

PRESETS=( ultrafast veryslow )
CRFS=( 0 16 24)
TUNES=( grain film )

PREV_VMAF=0

BASE_FILENAME=$(basename "$SOURCE_FILE" | cut -f 1 -d '.')
BASE_FILENAME=${BASE_FILENAME// /_}
BASE_DIR="$BASE_FILENAME"-tests
REF_DIR="$BASE_DIR"/reference
ENC_DIR="$BASE_DIR"/encoded
mkdir -p "$REF_DIR" "$ENC_DIR"

grabSnippet() {
    START_OFFSET=${1:-0}
    OFFSET_ARRAY=" $OFFSET_ARRAY $START_OFFSET "
    if [ "$((START_OFFSET + 15))" -lt "$ORIGINAL_DURATION" ]
    then
        grabSnippet "$((START_OFFSET + 300))"
    fi
}
updateBest() {
    PREV_FILESIZE="$THIS_FILESIZE"
    PREV_VMAF="$THIS_VMAF"
    BEST_PRESET="$PRESET"
    BEST_TUNE="$TUNE"
    BEST_CRF="$CRF"
    echo New best preset="$BEST_PRESET", tune="$BEST_TUNE", crf="$BEST_CRF" with vmaf="$THIS_VMAF"
}
bytesToHuman () {
    numfmt --to=iec-i --format='%.5f' "$1"
}
floatLessThanPercent() {
    awk -v n1="$1" -v n2="$2" -v n3="$3" 'BEGIN {if (n1+0<((n2+0)*(n3+0))) exit 0; exit 1}'
}
floatLessThan() {
    awk -v n1="$1" -v n2="$2" 'BEGIN {if (n1+0<n2+0) exit 0; exit 1}'
}
floatEquals() {
    awk -v n1="$1" -v n2="$2" 'BEGIN {if (n1+0==n2+0) exit 0; exit 1}'
}
runEncode() {
    BASE_FILENAME="$1"
    TEMP_NAME=${BASE_FILENAME//reference/encoded}
    ffmpeg -loglevel panic -i "$BASE_FILENAME" -c:v libx264 -crf "$CRF" -preset "$PRESET" -tune "$TUNE" -sn -an "$TEMP_NAME"
}
runVmaf() {
    BASE_FILENAME="$1"
    TEMP_NAME=${BASE_FILENAME//reference/encoded}
    TEMP_VMAF=$(ffmpeg -i "$TEMP_NAME" -i "$BASE_FILENAME" -lavfi libvmaf="pool=perc5:log_fmt=json:model_path=model/vmaf_4k_v0.6.1.pkl" -f null - 2>&1 | grep "\[libvmaf" | grep "VMAF score" | grep -Poh "([0-9]{1,3}\.[0-9]{1,15})")
    VMAF=" $VMAF $TEMP_VMAF "
}

ORIGINAL_DURATION=$(ffprobe -v panic -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$SOURCE_FILE" | grep -Poh -m 1 "([0-9]{1,9})" | head -1)

grabSnippet
OFFSET_ARRAY=( $OFFSET_ARRAY )

for i in "${!OFFSET_ARRAY[@]}"
do
    REF_FILE="$BASE_FILENAME"_reference_"$i".mkv
    ffmpeg -loglevel panic -ss "${OFFSET_ARRAY[$i]}" -i "$SOURCE_FILE" -t "00:00:15" -c:v copy -avoid_negative_ts 1 -sn -an "$REF_DIR"/"$REF_FILE"
done


REF_FILESIZE=$(du "$REF_DIR" | grep -Poh -m 1 "([0-9]{1,999})(?=\s)")
PREV_FILESIZE="$REF_FILESIZE"
echo Created sample set of videos with total filesize of "$(bytesToHuman "$REF_FILESIZE")"

BEST_PRESET=""
BEST_TUNE=""
BEST_CRF=""

for PRESET in "${PRESETS[@]}"
do
    for TUNE in "${TUNES[@]}"
    do
        for CRF in "${CRFS[@]}"
        do
            echo Running preset="$PRESET", crf="$CRF", and tune="$TUNE"
            for REF_FILE in $REF_DIR/*
            do
                runEncode "$REF_FILE"
            done
            THIS_FILESIZE=$(du "$ENC_DIR" | grep -Poh -m 1 "([0-9]{1,999})(?=\s)")
            if floatLessThanPercent "$THIS_FILESIZE" "$REF_FILESIZE" "$SIZE_MULTIPLIER"
            then
                echo Continuing with VMAF: 0"$(bc <<< "scale=5; $THIS_FILESIZE / $REF_FILESIZE")"X file size
                for REF_FILE in $REF_DIR/*
                do
                    runVmaf "$REF_FILE"
                done
                VMAF=( $VMAF )
                VMAF_SUM=$( IFS="+"; bc <<< "${VMAF[*]}" )
                THIS_VMAF=$(bc <<< "scale=15; $VMAF_SUM / ${#VMAF[@]}")
                echo "$THIS_VMAF"
                if floatLessThan "$PREV_VMAF" "$THIS_VMAF"
                then
                    updateBest
                elif floatEquals "$PREV_VMAF" "$THIS_VMAF"
                then
                    if [ "$THIS_FILESIZE" -lt "$PREV_FILESIZE" ]
                    then
                        echo Same quality result: vmaf="$THIS_VMAF" but smaller file size.
                        updateBest
                    else
                        echo Same quality result: vmaf="$THIS_VMAF" but larger or same file size.  Retaining previous best preset="$BEST_PRESET", tune="$BEST_TUNE", crf="$BEST_CRF"
                    fi
                else
                    echo Lower quality result: vmaf="$THIS_VMAF" \< "$PREV_VMAF".  Retaining previous best preset="$BEST_PRESET", tune="$BEST_TUNE", crf="$BEST_CRF"
                    rm "$ENC_DIR"/*
                    break
                fi
            else
                echo Too big: "$(bc <<< "scale=2; $THIS_FILESIZE / $REF_FILESIZE")"X file size
            fi
            rm "$ENC_DIR"/*
        done
    done
done
rm -rf "$BASE_DIR"
echo best preset="$BEST_PRESET", best tune="$BEST_TUNE", best crf="$BEST_CRF"
echo Use command:   ffmpeg -loglevel panic -i "$SOURCE_FILE" -c:v libx264 -crf "$BEST_CRF" -preset "$BEST_PRESET" -tune "$BEST_TUNE" -sn -an out/"$(basename "$SOURCE_FILE")"

exit 0
