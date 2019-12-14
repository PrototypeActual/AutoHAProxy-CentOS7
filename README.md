# AutoHAProxy-CentOS7
Bash script to deploy HAProxy 2.1.1 with SSL on a fresh CentOS 7 machine with very little setting up. There are messages displayed during the installation of this script to keep you aware of certain things as well as comments in the script to explain what the commands in the script do.

What you will still need to do

During the script it will open up the vi text editor so you can edit the last line

The last line needs to have the server ip where it says ENTERIPOFHTTPDSERVER Ex. server Apache1 192.168.1.10:80 check cookie s1

If you need to add more servers you can enter a new line with the same format as that last line.

If you add more servers make sure to change the name, and IP.
-You may need to change the the number after the s to the number that server is in the list

You will also need to update the login for the stats page or comment out
-stats auth admin:haproxy
-This line is located in the haproxy config file under the frontend section
