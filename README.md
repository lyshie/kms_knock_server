KMS (Key-Management-Service) Knock Server
=========================================
The KMS (Key-Management-Service) knock server provides an easy way to temporarily open TCP
1688 port by knocking the server. You can use various way to authenticate a user, like POP3,
Radius, LDAP, etc. It is suitable for those that dose not have VPN (Virtual Private Network).

Architecture
------------
     (kms-server)          (kms-knock-server)
    +------------+          +--------------+          +----------------+
    | KMS Server | <------> | Knock Server | <------> | Windows Client |
    +------------+          +--------------+          +----------------+
                    socat       fail2ban     iptables
                    rinetd

    +----------+         +---------+         +------------+         +----------+
    | knock.pl | ------> | rsyslog | ------> | local7.log | ------> | fail2ban |
    +----------+         +---------+         +------------+         +----+-----+
                                                                         |
                                                                    +----+-----+
                                                                    | iptables |
                                                                    +----+-----+
																	     |
																	+----+-----+
																	|  socat   |
																	|  rinetd  |
																	+----------+

Dependencies
------------
  * **iptables/fail2ban/rsyslog**: open/close tcp port 1688
  * **socat/rinetd**: tcp port redirection
  * **httpd/lighttpd**
  * **Perl 5.10 or newer** (Sys::Syslog, DBI, DBD::SQLite)
  * **SQLite**

Usage
-----
  * Configure fail2ban and rsyslog

        # cd /etc/fail2ban
        # sudo cp [KNOCK_SRC]/fail2ban/action.d/knock.conf action.d/
        # sudo cp [KNOCK_SRC]/fail2ban/filter.d/knock.conf filter.d/
        # sudo cat [KNOCK_SRC]/fail2ban/jail.conf >> jail.conf
        # sudo systemctl restart fail2ban.service

        # sudo vim /etc/rsyslog.conf
        local7.*        -/var/log/local7.log

  * Create sqlite database

        # sqlite3 cgi-bin/databases/knock.sqlite < cgi-bin/_knock.sql

  * Configure CGI application

        # cd /var/www/cgi-bin
        # sudo cp [KNOCK_SRC]/cgi-bin/knock.pl .
        # sudo cp -r [KNOCK_SRC]/cgi-bin/databases .
        # sudo chown -R apache:apache knock.pl databases/
        # sudo chmod 755 knock.pl databases/

Sample output log
-----------------
    Mar 13 22:12:35 r309-1 knock[25356]: ACTION=knock IP=127.0.0.1 USER=lyshie HOST=test.edu.tw COUNT=1
    Mar 13 22:13:20 r309-1 knock[26836]: ACTION=knock IP=127.0.0.1 USER=lyshie HOST=test.edu.tw COUNT=2

Author
------
    SHIE, Li-Yi <lyshie@mx.nthu.edu.tw>

License
-------
    GNU General Public License (GPL)
