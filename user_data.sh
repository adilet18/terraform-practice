#!/bin/bash
yum -y update
yum -y install httpd


cat <<EOF > /var/www/html/index.html
<html>
<body bgcolor="aqua">
<h2><font color="gold">Build by Power of Terraform <font color="red"> v1.4.6</font></h2><br><p>
<font color="magenta">
<b>Version 3.0</b>
</body>
</html>
EOF

sudo service httpd start
chkconfig httpd on