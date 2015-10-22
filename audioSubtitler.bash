#!/bin/bash

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
        echo Empty
        return 1
    elif [ -z "$2" ]; then
        if [ -d "$1" ]; then
            echo a dir
            usage
            exit 1
        elif [ -r "$1" ]; then
            echo Not a dir
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
            echo is probably generated config
            exit 0
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
    echo "Sans 14" >> $1
    echo >> $1
    echo >> $1
    echo "# Example subtitling:" >> $1
    echo >> $1
    echo "# <color as hex> <height in pixels from bottom> <the text to display>" >> $1
    echo "FFFFFF 30 This is some white subtitled text." >> $1
    echo "00FF00 15 This is some green subtitled text." >> $1
    echo "000000 0 This is some black subtitled text." >> $1
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

main() {
    check_param "$@"

    if [ $? -eq 1 ]; then
        echo one
    else
        generate_config
    fi
}

main "$@"

