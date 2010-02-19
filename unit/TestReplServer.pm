# Copyright (C) 2010 Sun Microsystems, Inc. All rights reserved.  Use
# is subject to license terms.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301
# USA

package TestReplServer;

use base qw(Test::Unit::TestCase);
use lib 'lib';
use Cwd;
use GenTest;
use GenTest::Server::ReplMySQLd;
use GenTest::Executor;

use Data::Dumper;

sub new {
    my $self = shift()->SUPER::new(@_);
    # your state for fixture here
    return $self;
}

sub set_up {
}

@pids;

sub tear_down {
    if (windows) {
        ## Need to ,kill leftover processes if there are some
        foreach my $p (@pids) {
            Win32::Process::KillProcess($p,-1);
        }
        system("rmdir /s /q unit\\tmp1");
        system("rmdir /s /q unit\\tmp2");
    } else {
        ## Need to ,kill leftover processes if there are some
        kill 9 => @pids;
        system("rm -rf unit/tmp1");
        system("rm -rf unit/tmp2");
    }
}

sub test_create_server {
    my $self = shift;
    
    my $master_vardir= cwd()."/unit/tmp1";
    my $slave_vardir= cwd()."/unit/tmp2";
    
    $self->assert(defined $ENV{RQG_MYSQL_BASE},"RQG_MYSQL_BASE not defined");
    
    my $server = GenTest::Server::ReplMySQLd->new(basedir => $ENV{RQG_MYSQL_BASE},
                                                  master_vardir => $master_vardir,
                                                  slave_vardir => $slave_vardir,
                                                  mode => 'statement',
                                                  master_port => 22120);
    $self->assert_not_null($server);
    
    $self->assert(-f $master_vardir."/data/mysql/db.MYD","No ".$master_vardir."/data/mysql/db.MYD");
    
    $server->startServer;
    push @pids,$server->master->serverpid;
    push @pids,$server->slave->serverpid;


    $server->master->dbh->do("CREATE TABLE test.t (i integer)");
    $server->master->dbh->do("INSERT INTO test.t VALUES(42)");

    $server->waitForSlaveSync();
    
    my $result = $server->slave->dbh->selectrow_array("SELECT * FROM test.t");
    
    $self->assert_num_equals(42, $result);
    
    $server->stopServer;
    
    sayFile($server->master->logfile);
    sayFile($server->slave->logfile);
}

1;