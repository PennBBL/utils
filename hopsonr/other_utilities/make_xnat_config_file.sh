echo "This script generates ~/.xnat.cfg needed to access xnat from the command line."
echo "Make sure you are using the login of the person for whom this config file is being created, or permissions will be incorrect."
echo "Please enter your xnat user name:"
read username
echo "Please enter your xnat password:"
read -s password
echo {\"password\": \"$password\", \"user\": \"$username\", \"cachedir\": \"/tmp/"$username"_xnat_temp\", \"server\": \"https://xnat.uphs.upenn.edu/xnat\"} > ~/.xnat.cfg
chmod 700 ~/.xnat.cfg


