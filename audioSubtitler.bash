#!/bin/bash

OUTPUT_VIDEO_WIDTH=1280
OUTPUT_VIDEO_HEIGHT=720
OUTPUT_VIDEO_FORMAT="mkv"

check_for_error() {
    error_value=$?
    if [ $error_value -ne 0 ]; then
        echo
        echo Error: $1
        exit $error_value
    fi
}

usage() {
    echo
    echo "====  USAGE  ===="
    echo "./AudioSubtitler <audio-file>"
    echo "  - generates a config file for that audio"
    echo "./AudioSubtitler --config=<config-file>"
    echo "  - creates the subtitled video using the config file"
}

check_param() {
    if [ -z "$1" ]; then
        usage
        return 1
    elif [ -z "$2" ]; then
        if [ -d "$1" ]; then
            echo Is a directory
            usage
            exit 1
        elif [ -r "$1" ]; then
            paramResult=$(realpath "$1")
            return 0
        elif [ "$(echo "$1" | cut -f1 -d=)" = "--config" ]; then
            configFile=$(echo "$1" | cut -f2 -d=)
            if [[ -z "$configFile" || "$configFile" = "--config" ]]; then
                usage
                exit 1
            elif [ ! -r "$configFile" ]; then
                echo Config file not found
                usage
                exit 1
            fi
#            echo is probably generated config
            return 0
        fi
    fi
    usage
    exit 1
}

write_config() {
    echo creating config ${1} ...
    echo "# Lines starting with # are comments" >> $1
    echo "# The first line in the config file must be the audio file." >> $1
    echo "# An absolute path is preferred." >> $1
    echo $paramResult >> $1
    echo "# The second line must be font information like so:" >> $1
    echo "Sans 36" >> $1
    echo >> $1
    echo "# Example subtitling:" >> $1
    echo >> $1
    echo "# <color as hex> <height in pixels from bottom> <start time in seconds> <end time in seconds> <the text to display>" >> $1
    echo "0xFFFFFF 80 0.2 2 This is some white subtitled text." >> $1
    echo "0x00FF00 40 2 3.5 This is some green subtitled text." >> $1
    echo "0x808080 0 3 4 This is some gray subtitled text." >> $1
    echo created config $1
}

generate_config() {
    local configFilename="generatedConfig"
    local suffix=".txt"
    local number=1

    if [ ! -e "${configFilename}${suffix}" ]; then
        write_config "${configFilename}${suffix}"
        exit 0
    fi

    until [ ! -e "${configFilename}$(printf "%04d" $number)${suffix}" ]; do
        number=$((number + 1))
    done

    write_config "${configFilename}$(printf "%04d" $number)${suffix}"
    exit 0
}

generate_blank_video() {
    local tempLogFilename="tempReport"
    local rnumber=0
    while [ -e "${tempLogFilename}${rnumber}.txt" ]; do
        rnumber=$((rnumber + 1))
    done

    FFREPORT=file=${tempLogFilename}${rnumber}.txt ffprobe $1
    local duration=$(cat ${tempLogFilename}${rnumber}.txt | grep Duration | awk '{ print $2}' | cut -f1 -d, | awk '{ gsub(/:/, "\\\\:"); print }')
    rm ${tempLogFilename}${rnumber}.txt

    tempVideoFilename="tempVideo"
    vnumber=0
    while [ -e "${tempVideoFilename}${vnumber}.mkv" ]; do
        vnumber=$((vnumber + 1))
    done

    ffmpeg -i $1 -f lavfi -i color=c=black:s=1280x720:r=30:d=$duration ${tempVideoFilename}${vnumber}.mkv
    check_for_error "Perhaps the audio file in the config is incorrect?"
}

create_video() {
    echo Create video
# ffmpeg -i out.mkv -vf "drawtext=text=Testing...:x=main_w/2-text_w/2:y=main_h-text_h:enable=between(t\,0.5\,4):fontcolor=white" out2.mkv

    local inputAudioFilename=$(cat $configFile | awk '$1 !~ /^#/' | awk '$1 !~ /^$/' | awk 'NR == 1')
    generate_blank_video $inputAudioFilename
# ffmpeg -i tempVideo0.mkv -vf "drawtext=text=Testing...:x=main_w/2-text_w/2:y=main_h-text_h:enable=between(t\,0.5\,4):fontcolor=white, drawtext=text=derpadoo...:x=main_w/2-text_w/2:y=main_h-text_h-30:enable=between(t\,0.2\,3.5):fontcolor=white" out2.mkv

    local fontName=$(cat $configFile | awk '$1 !~ /^#/' | awk '$1 !~ /^$/' | awk 'NR == 2 {print $1}')
    check_for_error "Perhaps the font setting in the config is incorrect?"
    local fontSize=$(cat $configFile | awk '$1 !~ /^#/' | awk '$1 !~ /^$/' | awk 'NR == 2 {print $2}')
    check_for_error "Perhaps the font setting in the config is incorrect?"

    if [ -z "$fontName" ]; then
        echo "Error: Font was not specified in the config!"
        exit 1
    elif [ -z "$fontSize" ]; then
        echo "Error: Font size was not specified in the config!"
        exit 1
    fi

    local configLineIndex=3
    local drawtextFilter=""
    while [ ! -z "$(cat $configFile | awk '$1 !~ /^#/' | awk '$1 !~ /^$/' | awk -v configLineIndex=$configLineIndex 'NR == configLineIndex')" ]; do
        local configLine=$(cat $configFile | awk '$1 !~ /^#/' | awk '$1 !~ /^$/' | awk -v configLineIndex=$configLineIndex 'NR == configLineIndex')

        local lineColor=$(echo $configLine | awk '{print $1}')
        local lineYPos=$(echo $configLine | awk '{print $2}')
        local startSeconds=$(echo $configLine | awk '{print $3}')
        local endSeconds=$(echo $configLine | awk '{print $4}')
        local lineText=$(echo $configLine | awk '{print substr($0, index($0, $5))}')

        if [ -z "$drawtextFilter" ]; then
            drawtextFilter="drawtext=text=$lineText:x=main_w/2-text_w/2:y=main_h-text_h-$lineYPos:enable=between(t\\,$startSeconds\\,$endSeconds):fontcolor=$lineColor:font=$fontName:fontsize=$fontSize"
        else
            drawtextFilter="$drawtextFilter, drawtext=text=$lineText:x=main_w/2-text_w/2:y=main_h-text_h-$lineYPos:enable=between(t\\,$startSeconds\\,$endSeconds):fontcolor=$lineColor:font=$fontName:fontsize=$fontSize"
        fi

        configLineIndex=$((configLineIndex + 1))
    done

    local finalOutputName="out"
    local finalOutputNumber=0
    until [ ! -e "${finalOutputName}${finalOutputNumber}.${OUTPUT_VIDEO_FORMAT}" ]; do
        finalOutputNumber=$((finalOutputNumber + 1))
    done

    ffmpeg -i "${tempVideoFilename}${vnumber}.mkv" -vf "$drawtextFilter" ${finalOutputName}${finalOutputNumber}.${OUTPUT_VIDEO_FORMAT}
    check_for_error "Config file may be invalid in the subtitles section"
    rm ${tempVideoFilename}${vnumber}.mkv
}

main() {
    check_param "$@"

    if [ $? -eq 1 ]; then
        exit 1
    elif [ ! -z "$paramResult" ]; then
        generate_config
    elif [ ! -z "$configFile" ]; then
        create_video
    else
        usage
        exit 1
    fi

    echo
    echo Finished.
}

main "$@"

