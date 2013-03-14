#!/usr/bin/env perl
#===============================================================================
#
#         FILE: knock.pl
#
#        USAGE: ./knock.pl
#
#  DESCRIPTION:
#
#      OPTIONS: ---
# REQUIREMENTS: Perl 5.010, Sys::Syslog, DBI, DBD::SQLite (SQLite)
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: SHIE, Li-Yi <lyshie@mx.nthu.edu.tw>
# ORGANIZATION:
#      VERSION: 1.0
#      CREATED: 2013/03/12 15:32:36
#     REVISION: ---
#===============================================================================

use 5.010;
use strict;
use warnings;

use FindBin qw($Bin);
use CGI qw(:standard);
use Sys::Syslog qw(:standard :macros);
use Net::POP3;
use DBI;

my $DB_FILE = "$Bin/databases/knock.sqlite";

my %_GET = ();

my %POP_HOSTS = (
    'mx.test.edu.tw' => 'pop.mx.test.edu.tw',
    'cc.test.edu.tw' => 'pop.cc.test.edu.tw',
);

my $TIME_GAP = 30;    # unit: seconds
my $MAX_TRY  = 3;

sub get_param {
    $_GET{'ip'}       = $ENV{'REMOTE_ADDR'}         // '';
    $_GET{'user'}     = param('user')               // '';
    $_GET{'host'}     = param('host')               // '';
    $_GET{'password'} = param('password')           // '';
    $_GET{'pop_host'} = $POP_HOSTS{ $_GET{'host'} } // '';
}

sub db_open {

    # check if database exists
    die("ERROR: $DB_FILE not found!\n") if ( !-f $DB_FILE );

    # database connection
    my $dbh =
      DBI->connect( "dbi:SQLite:dbname=$DB_FILE", "", "", { AutoCommit => 0 } );

    return $dbh;
}

sub db_close {
    my ($dbh) = @_;

    $dbh->disconnect();
}

sub _fetch {
    my ( $dbh, $ip, $user, $host ) = @_;

    my ( $lasttime, $count );
    my $sth;

    # select and fetch
    $sth = $dbh->prepare(
        qq{
        SELECT lasttime, count
          FROM knock
         WHERE (ip = ?) AND (username = ?) AND (host = ?);
        }
    );
    $sth->execute( $ip, $user, $host );

    my $row = $sth->fetchrow_hashref();
    $lasttime = $row->{'lasttime'} || 0;
    $count    = $row->{'count'}    || 0;

    # gracefully finalize
    $sth->finish();
    undef($sth);

    return ( $lasttime, $count );
}

sub _increment {
    my ( $dbh, $ip, $user, $host, $reset ) = @_;

    my ( $lasttime, $count );
    my $time = time();
    my $sth;

    # first, insert or ignore
    $sth = $dbh->prepare(
        qq{
        INSERT OR IGNORE INTO knock (lasttime, ip, username, host, count)
                       VALUES (?, ?, ?, ?, 0);
    }
    );
    $sth->execute( $time, $ip, $user, $host );

    # second, update
    $sth = $dbh->prepare(
        $reset
        ? qq{
        UPDATE knock SET lasttime = ?, count = 1 WHERE (ip = ?) AND (username = ?) AND (host = ?);    }
        : qq{
        UPDATE knock SET lasttime = ?, count = count + 1 WHERE (ip = ?) AND (username = ?) AND (host = ?);    }
    );
    $sth->execute( $time, $ip, $user, $host );

    # commit
    $dbh->commit();

    # gracefully finalize
    $sth->finish();
    undef($sth);
}

sub main {
    get_param();

    if ( ( $_GET{'user'} ne '' ) && ( $_GET{'password'} ne '' ) ) {
        my $pop = Net::POP3->new( Host => $_GET{'pop_host'}, Timeout => 10 );

        print header( -charset => 'utf-8', -type => 'text/plain' );
        if ( $pop->login( $_GET{'user'}, $_GET{'password'} ) > 0 )
        {    # POP login succeed

            my ( $lasttime, $count );

            my $dbh = db_open();

            ( $lasttime, $count ) =
              _fetch( $dbh, $_GET{'ip'}, $_GET{'user'}, $_GET{'host'} );

            my $gap = time() - $lasttime;
            if ( $gap > 30 ) {    # check time gap
                if ( $gap > 86400 )
                {                 # last try over 24 hours, and reset to 1 time
                    _increment( $dbh, $_GET{'ip'}, $_GET{'user'},
                        $_GET{'host'}, 1 );
                }
                else {
                    _increment( $dbh, $_GET{'ip'}, $_GET{'user'},
                        $_GET{'host'} );
                }

                ( $lasttime, $count ) =
                  _fetch( $dbh, $_GET{'ip'}, $_GET{'user'}, $_GET{'host'} );

                if ( $count > $MAX_TRY ) {    # check max times
                    print
qq{FAIL: Maximum times exceeded within 24 hours. (count = $count)\n};
                }
                else {
                    print qq{OK: $_GET{'ip'}, }, scalar( localtime($lasttime) ),
                      qq{ (count = $count)\n};

                    openlog( 'knock', "ndelay,pid", LOG_LOCAL7 );
                    syslog( LOG_INFO,
qq{ACTION=knock IP=$_GET{'ip'} USER=$_GET{'user'} HOST=$_GET{'host'} COUNT=$count}
                    );
                    closelog();
                }
            }
            else {
                print qq{FAIL: Time gap too close. (gap = $gap)\n};
            }

            db_close($dbh);
        }
        else {    # POP login failed
            print qq{FAIL: POP3 Authentication failed.\n};
        }
    }
    else {
        print header( -charset => 'utf-8' );
        print qq{
        <html>
        <head></head>
        <body>
        <a href="kms.bat">Download kms.bat</a>
        </br >
        </br >
        <form method="post">
            <label for="user">Username:</label><input id="user" type="text" name="user" value="" />@
            <select id="host" name="host">
                <option value="mx.test.edu.tw">mx.test.edu.tw</option>
                <option value="cc.test.edu.tw">cc.test.edu.tw</option>
            </select>
            <br />
            <label for="password">Password:</label><input id="password" type="password" name="password" value="" /><br />
            <input type="submit" />
        </form>
        </body>
        </html>
        }, "\n";
    }
}

main;
