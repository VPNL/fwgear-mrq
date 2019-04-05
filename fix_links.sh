#!/bin/bash

# Replace soft links with the actual file - preserving the link file name.
for link in $(find $1 -type l)
do
  cd "$(dirname "${link}")"
  echo "$(pwd)"
  target="$(readlink "$link")"
  unlink "$link"
  cp -v "${target}" "${link}"
done
