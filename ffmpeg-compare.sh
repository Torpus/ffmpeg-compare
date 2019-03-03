#!/usr/bin/env bash

SOURCE_FILE=$1
SIZE_MULTIPLIER=${2:-1}
POOL=${3:-"harmonic_mean"}

echo Input file: "$SOURCE_FILE"
echo Target output size: "$SIZE_MULTIPLIER"
echo Pool: "$POOL"

PRESETS=( ultrafast superfast veryfast faster fast medium slow slower veryslow )
MIN_CRF=0
MAX_CRF=51
TUNES=( grain film animation )
PREV_VMAF=0
GREEN='\033[0;32m'
NC='\033[0m'
BASE_FILENAME=$(basename "$SOURCE_FILE" | cut -f 1 -d '.')
BASE_FILENAME=${BASE_FILENAME// /_}
BASE_DIR="$BASE_FILENAME"-tests
REF_DIR="$BASE_DIR"/reference
ENC_DIR="$BASE_DIR"/encoded
CROP_W=0
CROP_H=0
CROP_W_OFFSET=0
CROP_H_OFFSET=0

buildCrfArray() {
    i="$1"
    MAX="$2"
    CRFS=( )
    while [ "$i" -le "$MAX" ]
    do
        CRFS+=( $i )
        i=$((i + 1))
    done
}
grabSnippet() {
    START_OFFSET=${1:-0}
    if [ "$((START_OFFSET + 10))" -lt "$ORIGINAL_DURATION" ]
    then
        OFFSET_ARRAY=" $OFFSET_ARRAY $START_OFFSET "
        grabSnippet "$((START_OFFSET + 600))"
    fi
}
updateBest() {
    PREV_FILESIZE="$THIS_FILESIZE"
    PREV_VMAF="$THIS_VMAF"
    BEST_PRESET="$PRESET"
    BEST_TUNE="$TUNE"
    BEST_CRF="$CRF"
    echo -e "$GREEN"New best preset="$BEST_PRESET", tune="$BEST_TUNE", crf="$BEST_CRF" with vmaf="$THIS_VMAF""$NC"
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
    FILENAME="$1"
    TEMP_NAME=${FILENAME//reference/encoded}
    ffmpeg -loglevel panic -i "$FILENAME" -c:v libx264 -crf "$CRF" -preset "$PRESET" -tune "$TUNE" -sn -an "$TEMP_NAME"
}
runVmaf() {
    FILENAME="$1"
    TEMP_NAME=${FILENAME//reference/encoded}
    TEMP_VMAF=$(ffmpeg -i "$TEMP_NAME" -i "$FILENAME" -lavfi libvmaf="pool=$POOL:log_fmt=json:model_path=model/vmaf_4k_v0.6.1.pkl" -f null - 2>&1 | grep "\[libvmaf" | grep "VMAF score" | grep -Poh "([0-9]{1,3}\.[0-9]{1,15})")
    VMAF=" $VMAF $TEMP_VMAF "
}
getCrop() {
    CROP=$(ffmpeg -ss $((ORIGINAL_DURATION / 2)) -i "$SOURCE_FILE" -vframes 2 -vf cropdetect -f null - 2>&1 | grep -Poh "([0-9]{1,5}:[0-9]{1,5}:[0-9]{1,5}:[0-9]{1,5})")
    IFS=':' read -r -a array <<< "$CROP"
    if [ "${array[0]}" -gt $CROP_W ]
    then
        CROP_W="${array[0]}"
    fi
    if [ "${array[0]}" -gt $CROP_H ]
    then
        CROP_H="${array[1]}"
    fi
    if [ "${array[0]}" -gt $CROP_W_OFFSET ]
    then
        CROP_W_OFFSET="${array[2]}"
    fi
    if [ "${array[0]}" -gt $CROP_H_OFFSET ]
    then
        CROP_H_OFFSET="${array[3]}"
    fi
}

mkdir -p "$REF_DIR" "$ENC_DIR"

ORIGINAL_DURATION=$(ffprobe -v panic -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$SOURCE_FILE" | grep -Poh -m 1 "([0-9]{1,9})" | head -1)

grabSnippet && OFFSET_ARRAY=( $OFFSET_ARRAY )

for i in "${!OFFSET_ARRAY[@]}"
do
    if [ "$i" -lt 10 ]
    then
        REF_FILE="$BASE_FILENAME"_reference_"$i".mkv
        ffmpeg -loglevel panic -ss "${OFFSET_ARRAY[$i]}" -i "$SOURCE_FILE" -t "00:00:10" -c:v copy -avoid_negative_ts 1 -sn -an "$REF_DIR"/"$REF_FILE"
    else
        break
    fi
done
echo "Calculating crop..."
for REF_FILE in $REF_DIR/*
do
    getCrop "$REF_FILE"
done
WIDTH_ARRAY=( $WIDTH_ARRAY ) && HEIGHT_ARRAY=( $HEIGHT_ARRAY ) && W_OFFSET_ARRAY=( $W_OFFSET_ARRAY ) && H_OFFSET_ARRAY=( $H_OFFSET_ARRAY )

echo "Finalized Crop: Width=$CROP_W, Height=$CROP_H, Width Offset=$CROP_W_OFFSET, Height Offset=$CROP_H_OFFSET"

REF_FILESIZE=$(du -s -B1 "$REF_DIR" | grep -Poh -m 1 "([0-9]{1,999})(?=\s)")
PREV_FILESIZE="$REF_FILESIZE"
echo Created sample set of videos with total filesize of "$(bytesToHuman "$REF_FILESIZE")"

BEST_PRESET=""
BEST_TUNE=""
BEST_CRF=""

for PRESET in "${PRESETS[@]}"
do
    for TUNE in "${TUNES[@]}"
    do
        buildCrfArray $MIN_CRF $MAX_CRF
        for CRF in "${CRFS[@]}"
        do
            echo Running preset="$PRESET", tune="$TUNE", crf="$CRF"
            for REF_FILE in $REF_DIR/*
            do
                runEncode "$REF_FILE"
            done
            THIS_FILESIZE=$(du -s -B1 "$ENC_DIR" | grep -Poh -m 1 "([0-9]{1,999})(?=\s)")
            if floatLessThanPercent "$THIS_FILESIZE" "$REF_FILESIZE" "$SIZE_MULTIPLIER"
            then
                echo Continuing with VMAF: 0"$(bc <<< "scale=5; $THIS_FILESIZE / $REF_FILESIZE")"X file size
                for REF_FILE in $REF_DIR/*
                do
                    runVmaf "$REF_FILE"
                done
                VMAF=( $VMAF )
                VMAF_SUM=$( IFS="+"; bc <<< "${VMAF[*]}" )
                THIS_VMAF=$(bc <<< "scale=7; $VMAF_SUM / ${#VMAF[@]}")
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
                echo Too big: "$(bc <<< "scale=5; $THIS_FILESIZE / $REF_FILESIZE")"X file size
            fi
            rm "$ENC_DIR"/*
        done
        MIN_CRF=$(bc <<< "scale=2; ($CRF*0.75)")
        MIN_CRF=$(bc <<< "($MIN_CRF+0.5)/1")
        echo Adjusting minumum CRF to "$MIN_CRF"
    done
done
rm -rf "$BASE_DIR"
echo best preset="$BEST_PRESET", best tune="$BEST_TUNE", best crf="$BEST_CRF"
echo Use command:   ffmpeg -loglevel panic -i \""$SOURCE_FILE"\" -c:v libx264 -crf "$BEST_CRF" -preset "$BEST_PRESET" -tune "$BEST_TUNE" -vf crop="$CROP_W":"$CROP_H":"$CROP_W_OFFSET":"$CROP_H_OFFSET" -c:a copy "$BASE_FILENAME".mp4

exit 0
