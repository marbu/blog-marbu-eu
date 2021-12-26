#!/bin/bash

show_help()
{
  echo -e "Usage: $(basename "$0") [options] site-name\n"
  echo """Options:
  -d      dry run
  -h      show this help message"""
}

find_files_to_gzip()
{
  find _site/posts  -type f -name '*.html'
  find _site/images -type f -name '*.svg'
  find _site/       -type f -name '*.xml'
}

run_rsync()
{
  $DEBUG rsync -avc --delete _site/ "${SITE_NAME}:/var/www/${SITE_NAME}/"
}

#
# main
#

if [[ $# = 0 || $1 = "-h" || $1 = "--help" ]]; then
  show_help
  exit
fi

# debug mode
if [[ $1 = "-d" ]]; then
  # shellcheck disable=SC2209
  DEBUG=echo
  shift
else
  unset DEBUG
fi

SITE_NAME=$1
shift

find_files_to_gzip | xargs $DEBUG gzip --keep --force --rsyncable
run_rsync
