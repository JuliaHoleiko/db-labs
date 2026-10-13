#!/bin/bash
docker run \
  --name=lab2 \
  --rm \
  --volume=$(pwd)/schema.sql:/docker-entrypoint-initdb.d/schema.sql \
  --volume=$(pwd):/repo \
  --env=PSQLRC=/repo/.psqlrc \
  --env=POSTGRES_PASSWORD=foo \
  -p 5434:5432 \
  postgres:14.0 -c log_statement=all
