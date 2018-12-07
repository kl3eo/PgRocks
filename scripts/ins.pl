#!/usr/bin/perl

use DBI;
  use Time::HiRes qw( usleep ualarm gettimeofday tv_interval nanosleep
		      clock_gettime clock_getres clock_nanosleep clock
                      stat);

my $port = defined($ARGV[0]) && $ARGV[0] > 0 ? $ARGV[0] : 5432;
		      
my $server	= "localhost";
my $dbase  	= "tpcc";
my $user	= "postgres"; 
my $passwd	= "tpcc";

my $dbconn=DBI->connect("dbi:Pg:dbname=$dbase;port=$port;host=$server",$user, $passwd);
$dbconn->{LongReadLen} = 16384;

my $table = "orders";

&runCycles;

$dbconn->disconnect;
exit;
   
sub runCycles {
	
	for (my $i = 0; $i < 10000; $i++) {
			
		
		my $j = $i+1;
		#usleep(10000);
									
		$cmd = "insert into $table (key,mark,o_id, o_w_id, o_d_id, o_c_id, o_carrier_id, o_ol_cnt, o_all_local, o_entry_d) values 
		 ((select cast( rocks_get_node_number()*10000000000000000+ EXTRACT(EPOCH FROM current_timestamp)*1000000 as bigint)),
		 (SELECT floor(random()*16 + 1)::int),$j,$j,$j,$j,$j,$j,$j,now())";

		$result=$dbconn->prepare($cmd);
		$result->execute;
			&dBaseError($dbconn, $cmd) if (!defined($result));

	}
}

sub dBaseError {

    my ($check, $message) = @_;
    my $str = $check->errstr;    
    die("Action failed on command:$message  Error_was:$DBI::errstr");
}
