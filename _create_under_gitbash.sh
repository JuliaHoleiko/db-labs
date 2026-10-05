#!/bin/bash

# the main problem with execution of this script under git-bash on windows
# is that git-bash uses paths styled like /d/path/to/file but docker
# expects windows-style paths like d:/path/to/file; the back slashes
# are not nessesary but the drive letter should be the first and followed by : (not /)
 
function convert_path {
  local path=$1
  local win_path=$(echo "$path" | sed 's|^/\([a-zA-Z]\)/|\1:/|')
  echo "$win_path"
}

schema=$(convert_path "$(pwd)/schema.sql")
pwd=$(convert_path "$(pwd)")

echo "-- schema.sql path: $schema"
echo "-- current path: $pwd"

docker run \
   --name=lab2 \
   --rm \
   --volume="$schema:/docker-entrypoint-initdb.d/schema.sql" \
   --volume="$pwd:/repo" \
   --env=PSQLRC=/repo/.psqlrc \
   --env=POSTGRES_PASSWORD=foo \
   -p 5434:5432 \
   postgres:14.0 -c log_statement=all
