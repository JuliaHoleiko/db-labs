This is an example of LAB3 implementation

You can use this sample as a skeleton project for your app

To develop the app you can run it natively using IDE, for example PyCharm

To deploy it to the teacher it should be runnable under Docker:
   - run compose.bat to build and run the container
   - now you can connect to the containers tty with the following comand:
        docker exec -it lab3-app /bin/bash (or simply use bash.bat)
     and try to run the py-script using:
        python cli.py
   - the list of awailable options will be displayed, try them all:
        python cli.py create-tables
        python cli.py fill-db
        python cli.py list-users -d 2
        python cli.py drop-tables

All python dependencies are listed in requirements.txt

============================================
phpPGAdmin 

The docker project also includes phpPGAdmin and you can use it to interact with the DB
Use root/password to login
