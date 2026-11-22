This is an example of LAB4 implementation

You can use this sample as a skeleton project for your app

To deploy it to the teacher it should be runnable under Docker:
   - run compose.bat to build and run the container
   - than run docker ps and find the SHA for the container with your postgres_db
   - now you can connect to the containers tty with the following comand:
        docker exec -it 589c3ec6cb6c /bin/bash
   - run psql
        \l # displays the list of available databases
        \c car_portal  # selects this database as current
        \i pg/1.sql  # this command will add key:value pair 1:'hello' to memcached
                       and after this step you can try open in your browser the url
                       like 'localhost:8088/1' and it displays 'hello'; this means
                       that all is going well
        \i pg/2.sql ... pg/2.sql  # these commands is for demonstration only (read .docx file for comments)
        \i pg/5.sql will add to memcached all accounts from the corresponding table and 
                    after this step you can try open in your browser the url like '127.0.0.1:8088/2'
                    and it displays smth like {"account_id":3,"first_name":"Art","last_name":"Venere","email":"art@venere.org"}
                    this means that all is going well!
                       and now you can add some AJAX-JS into the nginx/index.html page to use this stuff

============================================
phpPGAdmin 

The docker project also includes phpPGAdmin and you can use it to interact with the DB
Use root/password to login
