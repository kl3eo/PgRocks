#!/usr/bin/perl
use strict;

my $num_args = $#ARGV + 1;
if ($num_args != 2 && $num_args != 3) {
    print "\nUsage: '$0 <table> <new cache: 1 / old cache : 0> [option: <initial RocksDB store number>]'\n";
    exit;
}

system("echo ==== >> log && date >> log && echo 'Starting script' >> log && echo ==== && date && echo 'Starting script'");

my $tab = $ARGV[0];
my $flag = $ARGV[1];
my $ini = defined($ARGV[2]) && int($ARGV[2]) > 0 ? int($ARGV[2])-1 : 0;

my $N = 8; # how many parallel readers, must be an even number; increase temp_buffers in postgresql.conf

if ($flag) {
system("echo ==== >> log && date >> log && echo 'Dropping old c0 cache (if exists) $tab\_c0' >> log && echo ==== && date && echo 'Dropping old c0 cache (if exists) $tab\_c0'");

my $c = `/usr/local/pgsql/bin/psql -p 9873 -c "\\timing" -c "drop table if exists $tab\_c0" people > .err0.log 2>&1`;

system("echo ==== >> log && date >> log && echo 'Creating empty $tab\_c0' >> log && echo ==== && date && echo 'Creating empty $tab\_c0'");

my $c = `/usr/local/pgsql/bin/psql -p 9873 -c "\\timing" -c "select _e_checkout_c0('$tab',0)" people >> .err0.log 2>&1`;

$c = `/usr/local/pgsql/bin/psql -p 9873 -c "\\timing" -c "alter table $tab\_c0 set (parallel_workers=20)" people >> .err0.log 2>&1`;
} else {
my $c = `/usr/local/pgsql/bin/psql -p 9873 -c "\\timing" -c "DROP TRIGGER IF EXISTS $tab\_c0_biud_v3 ON $tab\_c0" people >> .err0.log 2>&1`;
}

system("echo ==== >> log && date >> log && echo 'Starting parallel readers from $N RocksDB stores into $tab\_c0' >> log && echo ==== && date && echo 'Starting parallel readers from $N RocksDB stores into $tab\_c0'");

my $U = $ini + $N;

for (my $i = $ini; $i <$U-1; $i++) {
	my $j = $i + 1;
	my $c = `/usr/local/pgsql/bin/psql -p 9873 -c "\\timing" -c "select _e_checkout_c0('$tab',$j)" people > .err$j.log 2>&1 &`	

}


#start the last runner

my $c = `/usr/local/pgsql/bin/psql -p 9873 -c "\\timing" -c "select _e_checkout_c0('$tab',$U)" people > .err$U.log 2>&1`;


while (1) {
sleep(3);
my $str = `ps aux | grep psql | grep -v grep`;
if (length($str)) {
	print ".. waiting to finish\n"
} else {
	print "Finished all runners\n";
	last;
}
}
#$c = `/usr/local/pgsql/bin/psql -p 9873 -c "\\timing" -c "select rocks_close()" people >> .err0.log 2>&1`;
#NB: should not create trigger unless finished import rows from RocksDB

system("echo ==== >> log && date >> log && echo 'Creating trigger $tab\_c0_biud_v3' >> log && echo ==== && date && echo 'Creating trigger $tab\_c0_biud_v3'");

my $k = int(rand(15)) + 1;
$c = `/usr/local/pgsql/bin/psql -p 9873 -c "\\timing" -c "DROP TRIGGER IF EXISTS $tab\_c0_biud_v3 ON $tab\_c0" people >> .err0.log 2>&1`;
$c = `/usr/local/pgsql/bin/psql -p 9873 -c "\\timing" -c "CREATE TRIGGER $tab\_c0_biud_v3 BEFORE INSERT OR UPDATE OR DELETE  ON $tab\_c0 FOR EACH ROW EXECUTE PROCEDURE _ew_new_row('$tab',$k)" people >> .err0.log 2>&1`;

system("echo ==== >> log && date >> log && echo 'Finished' >> log && echo ==== && date && echo 'Finished'");

exit;
