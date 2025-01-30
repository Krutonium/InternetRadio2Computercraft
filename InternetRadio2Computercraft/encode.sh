#!/usr/bin/env bash
# This script will take a URL and output audio on stdout
# yt-dlp will handle fetching
# ffmpeg will handle decoding

# Check for dependencies
if ! command -v yt-dlp &> /dev/null; then
    echo "yt-dlp not found. Please install it."
    exit 1
fi
if ! command -v ffmpeg &> /dev/null; then
    echo "ffmpeg not found. Please install it."
    exit 1
fi

# Check for arguments
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <URL>"
    exit 1
fi

# Fetch the URL
yt-dlp -x -o - "$1" | ffmpeg -i pipe:0 -f dfpwm -ar 48000 -ac 1 -vn pipe:1
 