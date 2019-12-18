#/bin/sh

#sudo mysql
#GRANT ALL PRIVILEGES ON *.* TO 'adminuser'@'localhost' IDENTIFIED BY 'adminpassword';

SAKILA_TEST_DB_FILE=http://downloads.mysql.com/docs/sakila-db.tar.gz

PATH=`pwd`/bin:$PATH
if [ -f demo_env.sh ]; then
    . ./demo_env.sh
fi

. env.sh

# Create .my-admin.cnf --- for database administrator
cat <<EOF > /tmp/.my-admin.cnf
[client]
host=${DB_HOSTNAME}
port=${DB_PORT}
user=${DB_USERNAME}
password="${DB_PASSWORD}"
EOF

# Download and install sakila test database
curl -sL -o /tmp/sakila-db.tgz ${SAKILA_TEST_DB_FILE}
tar -zxf /tmp/sakila-db.tgz -C /tmp/
sudo mysql --defaults-file=/tmp/.my-admin.cnf < /tmp/sakila-db/sakila-schema.sql
sudo mysql --defaults-file=/tmp/.my-admin.cnf < /tmp/sakila-db/sakila-data.sql
# rm -rf /tmp/sakila-db
# rm -f /tmp/sakila-db.tgz
sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'mysql';FLUSH PRIVILEGES;"

cyan "# Data loaded"