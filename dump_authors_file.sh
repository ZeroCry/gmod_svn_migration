#!/usr/bin/env bash
authors=$(svn log -q file://$PWD/svn_backup | grep -e '^r' | awk 'BEGIN { FS = "|" } ; { print $2 }' | sort | uniq)
for author in ${authors}; do
  echo "${author} = NAME <USER@DOMAIN>";
done
