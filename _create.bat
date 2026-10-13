
docker run ^
  --name=lab2 ^
  --rm ^
  --volume="%CD%/schema.sql:/docker-entrypoint-initdb.d/schema.sql" ^
  --volume="%CD%:/repo" ^
  --env=PSQLRC=/repo/.psqlrc ^
  --env=POSTGRES_PASSWORD=foo ^
  -p 5434:5432 ^
  postgres:14.0 -c log_statement=all
