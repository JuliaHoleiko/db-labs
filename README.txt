
      *** Sample project for LAB_2 ***


this sample project is based on this tutorial:
   https://www.tangramvision.com/blog/hands-on-with-postgresql-authorization-part-1-roles-and-grants

=============================================

## Usage

This project uses Docker to run the PostgreSQL database, to avoid installing
a bunch of packages on your machine and potentially running into different
platform and environment issues.

To run the database with the example schema use:
   ./_create.sh

To open a psql prompt in that container, run the following in another terminal:
   ./_psql.sh

To select current database use:
   \c <database_name>  (as an example: \c lab2)
   HINT: \l displays list of databases created

On that stage the database have already been created and you can check that all is going well using the following command:
   \dt  (will list all created tables)
   \i /repo/sample_query_1.sql
       will execute SQL query from the corresponding file that shows the content of artist table;
       te table will be empty as no data were added yet;
 
To run SQL statements located in .sql files in psql use:
   \i /repo/sample_query_1.sql

=============================================

Other psql commands that can be usefull for you:

Listing databases:    \l
Switching Databases:  \c database
Listing Tables:       \dt
List of Relations:    \d
Quit:                 \q
Execute query:        \i /repo/sample_query_1.sql
List of roles:        \du
Show current user:    :whoami   (this is a short alias to get current user defined in .psqlrc)

   NOTE: you can also connect to postgresql that working in container from the host machine
         using port 5434 (instead the default 5432); password for user 'postgres' is set to 'foo'
         (all that parameters are configured in _create.sh script, so you can change it if you need)
         For example you can use PgAdmin GUI client, installed on the host
           or you can use some embedded DBMS client, for example in IntelJ or PyCharm

=============================================

SQL sample commands to insert test data into the database:

INSERT INTO artists (name) VALUES ('DJ Okawari'), ('Steely Dan'), ('Missy Elliott');

INSERT INTO albums (artist_id, title, released) VALUES (3, 'Under Construction', '2002-11-12');

SET ROLE testuser; -- change current user to testuser

   NOTE: don't forget to set ; at the end of each SQL statement while typing in psql shell

=============================================

