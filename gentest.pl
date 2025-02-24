#!/usr/bin/perl

# Copyright (c) 2008, 2012, Oracle and/or its affiliates. All rights
# reserved.
# Copyright (c) 2013, Monty Program Ab.
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

use lib 'lib';
use lib "$ENV{RQG_HOME}/lib";
use strict;
use Carp;
use Getopt::Long;

use GenTest;
use GenTest::Properties;
use GenTest::Constants;
use GenTest::App::GenTest;

my $logger;
eval
{
    require Log::Log4perl;
    Log::Log4perl->import();
    $logger = Log::Log4perl->get_logger('randgen.gentest');
};

my $DEFAULT_THREADS = 1;
my $DEFAULT_QUERIES = 1000;
my $DEFAULT_DURATION = 3600;
my $DEFAULT_DSN = 'dbi:mysql:host=127.0.0.1:port=3306:user=root:database=test';
my @debug_server;

my @ARGV_saved = @ARGV;

my $options = {};
my $opt_result = GetOptions($options,
                            'config=s',
                            'dsn=s@',
                            'dsn1=s',
                            'dsn2=s',
                            'dsn3=s',
                            'engine:s',
                            'engine1:s',
                            'engine2:s',
                            'engine3:s',
                            'generator=s',
                            'gendata:s',
                            'gendata-advanced',
                            'gendata_advanced',
                            'grammar=s',
                            'skip-recursive-rules',
                            'redefine=s@',
                            'testname=s',
                            'threads=i',
                            'queries=s',
                            'duration=s',
                            'help',
                            'debug',
                            'rpl_mode=s',
                            'validators:s@',
                            'reporters:s@',
                            'transformers:s@',
                            'report-xml-tt',
                            'report-xml-tt-type=s',
                            'report-xml-tt-dest=s',
                            'seed=s',
                            'mask=i',
                            'mask-level=i',
                            'rows=s',
                            'varchar-length=i',
                            'xml-output=s',
                            'sqltrace:s',
                            'no-err-filter',
                            'views:s',
                            'views1:s',
                            'views2:s',
                            'views3:s',
                            'start-dirty',
                            'filter=s',
                            'valgrind',
                            'valgrind-xml',
                            'notnull',
                            'short_column_names',
                            'strict_fields',
                            'freeze_time',
                            'debug',
                            'debug-server',
                            'logfile=s',
                            'logconf=s',
                            'report-tt-logdir=s',
                            'querytimeout=i',
                            'annotate-rules',
                            'annotate_rules',
                            'ps-protocol');
backwardCompatability($options);
my $config = GenTest::Properties->new(
    options => $options,
    defaults => {dsn=>[$DEFAULT_DSN],
                 seed => 1,
                 queries => $DEFAULT_QUERIES,
                 duration => $DEFAULT_DURATION,
                 threads => $DEFAULT_THREADS},
    legal => ['dsn',
              'engine',
              'gendata',
              'gendata-advanced',
              'generator',
              'grammar',
              'skip-recursive-rules',
              'redefine',
              'testname',
              'threads',
              'queries',
              'duration',
              'help',
              'debug',
              'rpl_mode',
              'validators',
              'reporters',
              'transformers',
              'report-xml-tt',
              'report-xml-tt-type',
              'report-xml-tt-dest',
              'seed',
              'mask',
              'mask-level',
              'rows',
              'varchar-length',
              'xml-output',
              'vcols',
              'views',
              'sqltrace',
              'no-err-filter',
              'start-dirty',
              'filter',
              'valgrind',
              'valgrind-xml',
              'sqltrace',
              'notnull',
              'short_column_names',
              'freeze_time',
              'strict_fields',
              'logfile',
              'logconf',
              'report-tt-logdir',
              'debug_server',
              'querytimeout',
              'servers',
              'multi-master',
              'annotate-rules',
              'ps-protocol',
              'restart-timeout'],
    help => \&help);

help() if !$opt_result || $config->help;

if (defined $config->logfile && defined $logger) {
    setLoggingToFile($config->logfile);
} else {
    if (defined $config->logconf && defined $logger) {
        setLogConf($config->logconf);
    }
}

say("Starting: $0 ".join(" ", @ARGV_saved));

system("rm -rf output/");

# Pass debug server.
$config->debug_server(\@debug_server) if @debug_server;
$ENV{RQG_DEBUG} = 1 if defined $config->debug;
$config->property('gendata-advanced',1) if defined $options->{'gendata_advanced'} || defined $options->{'gendata-advanced'};
my $gentest = GenTest::App::GenTest->new(config => $config);

my $status = $gentest->run();

# delete persistentProperties file
new GenTest()->ppUnlink();

safe_exit($status);

sub help {

    print <<EOF
$0 - Testing via random query generation. Options:

        --dsn      : DBI resources to connect to (default $DEFAULT_DSN).
                      Supported databases are MySQL, Drizzle, PostgreSQL, JavaDB
                      first --dsn must be to MySQL or Drizzle
        --debug-server: Use mysqld-debug server
        --gendata   : Execute gendata-old.pl in order to populate tables with simple data (default NO)
        --gendata=s : Execute gendata.pl in order to populate tables with data 
                      using the argument as specification file to gendata.pl
        --engine    : Table engine to use when creating tables with gendata (default: no ENGINE for CREATE TABLE)
                      Different values can be provided to servers through --engine1 | --engine2 | --engine3
        --threads   : Number of threads to spawn (default $DEFAULT_THREADS)
        --queries   : Numer of queries to execute per thread (default $DEFAULT_QUERIES);
        --duration  : Duration of the test in seconds (default $DEFAULT_DURATION seconds);
        --grammar   : Grammar file to use for generating the queries (REQUIRED);
        --redefine  : Grammar file(s) to redefine and/or add rules to the given grammar
        --seed      : PRNG seed (default 1). If --seed=time, the current time will be used.
        --rpl_mode  : Replication mode
        --validator : Validator classes to be used. Defaults
                           ErrorMessageCorruption if one or two MySQL dsns
                           ResultsetComparator3 if 3 dsns
                           ResultsetComparartor if 2 dsns
        --reporter  : ErrorLog, Backtrace if one or two MySQL dsns
        --mask      : A seed to a random mask used to mask (reduce) the grammar.
        --mask-level: How many levels deep the mask is applied (default 1)
        --rows      : Number of rows to generate for each table in gendata.pl, unless specified in the ZZ file
        --varchar-length: maximum length of strings (deault 1) in gendata.pl
        --views     : Pass --views to gendata-old.pl or gendata.pl. Optionally specify view type (algorithm) as option value. 
                      Different values can be provided to servers through --views1 | --views2 | views3
        --filter    : ......
        --sqltrace  : Print all generated SQL statements. 
                      Optional: Specify --sqltrace=MarkErrors to mark invalid statements.
        --no-err-filter:  Do not suppress error messages.  Output all error messages encountered.
        --start-dirty: Do not generate data (use existing database(s))
        --xml-output: Name of a file to which an XML report will be written if this option is set.
        --report-xml-tt: Report test results in XML-format to the Test Tool (TT) reporting framework.
        --report-xml-tt-type: Type of TT XML transport to use (e.g. scp)
        --report-xml-tt-dest: Destination of TT XML report (e.g. user\@host:/path/to/location (for type scp))
        --testname  : Name of test, used for reporting purposes.
        --valgrind  : ......
        --filter    : ......
        --freeze_time: Freeze time for each query so that CURRENT_TIMESTAMP gives the same result for all transformers/validators
        --strict_fields: Disable all AI applied to columns defined in \$fields in the gendata file. Allows for very specific column definitions
        --short_column_names: use short column names in gendata (c<number>)
        --annotate-rules: Add to the resulting query a comment with the rule name before expanding each rule. 
                          Useful for debugging query generation, otherwise makes the query look ugly and barely readable.
        --help      : This help message
        --debug     : Provide debug output
EOF
	;
	safe_exit(1);
}

sub backwardCompatability {
    my ($options) = @_;
    if (defined $options->{dsn}) {
        croak ("Do not combine --dsn and --dsnX") 
            if defined $options->{dsn1} or
            defined $options->{dsn2} or
            defined $options->{dsn3};
        
    } else {
        my @dsns;
        foreach my $i (1..3) {
            if (defined $options->{'dsn'.$i}) {
                push @dsns, $options->{'dsn'.$i};
                delete $options->{'dsn'.$i};
            }
        }
        $options->{dsn} = \@dsns;
    }
    
    # debug server options array is constructed. 
    if (defined $options->{debug_server}) {
        push (@debug_server,1);
    } else {
        # hack to workaround, Getopt seems to undef not defined values.
        push (@debug_server,undef);
    }    
    
    if (grep (/,/,@{$options->{reporters}})) {
        my $newreporters = [];
        map {push(@$newreporters,split(/,/,$_))} @{$options->{reporters}};
        $options->{reporters}=$newreporters ;
    }

    if (grep (/,/,@{$options->{transformers}})) {
        my $newtransformers = [];
        map {push(@$newtransformers,split(/,/,$_))} @{$options->{transformers}};
        $options->{transformers}=$newtransformers ;
    }

    if (grep (/,/,@{$options->{validators}})) {
        my $newvalidators = [];
        map {push(@$newvalidators,split(/,/,$_))} @{$options->{validators}};
        $options->{validators}=$newvalidators ;
    }

    if (not defined $options->{generator}) {
        $options->{generator} = 'FromGrammar';
    }
    
    if (defined $options->{sqltrace}) {
        my $sqltrace = $options->{sqltrace};
        # --sqltrace may have a string value (optional).
        # To retain backwards compatibility we set value 1 when no value is given.
        # Allowed values for --sqltrace:
        my %sqltrace_legal_values = (
            'MarkErrors'    => 1  # Prefixes invalid SQL statements for easier post-processing
        );
        if (length($sqltrace) > 0) {
            # A value is given, check if it is legal.
            if (not exists $sqltrace_legal_values{$sqltrace}) {
                say("Invalid value for --sqltrace option: '".$sqltrace."'");
                say("Valid values are: ".join(', ', keys(%sqltrace_legal_values)));
                say("No value means that default/plain sqltrace will be used.\n");
                help();
            }
        } else {
            # If no value is given, GetOpt will assign the value '' (empty string).
            # We interpret this as plain tracing (no marking of errors, prefixing etc.).
            # Better to use 1 instead of empty string for comparisons later.
            $options->{sqltrace} = 1;
        }
    }

    # if --views[=<value>] is defined, it will be used for both servers.
    # --views1 and --views2 will only be used for the corresponding server
    #   and have higher priority than --views

    my @views = ( 
        defined $options->{views1} ? $options->{views1} : $options->{views}, 
        defined $options->{views2} ? $options->{views2} : $options->{views},
        defined $options->{views3} ? $options->{views3} : $options->{views}  
    );
    $options->{views} = \@views;
    delete $options->{views1};
    delete $options->{views2};
    delete $options->{views3};

    my @engine = ( 
        defined $options->{engine1} ? $options->{engine1} : $options->{engine}, 
        defined $options->{engine2} ? $options->{engine2} : $options->{engine},
        defined $options->{engine3} ? $options->{engine3} : $options->{engine}  
    );
    $options->{engine} = \@engine;
    delete $options->{engine1};
    delete $options->{engine2};
    delete $options->{engine3};

}

