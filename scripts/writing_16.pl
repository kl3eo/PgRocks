#!/usr/bin/perl
use strict;

my $num_args = $#ARGV + 1;
if ($num_args != 2) {
    #print "\nUsage: '$0 <table> <number of ROWS> <(re)create clone = 1/ use old clone = 0>'\n";
    print "\nUsage: '$0 <table> <number of ROWS>'\n";
    exit;
}

system("echo ==== >> log && date >> log && echo 'Starting script' >> log && echo ==== && date && echo 'Starting script'");

my $tab = $ARGV[0];
my $nrows =$ARGV[1];
my $flag =$ARGV[2];

my $N = 16; #how many parallel streams, must be even number
my $sum = 0;
my $lim = 0;

#coeffs taken from measuring input of 102821244 rows with LIMIT 6500000, OFFSET  = LIMIT*n, i.e. equidistant
#in order to get ~ equal numbers of rows in shards, we need these weights --ash

#my @coeff = (151,147,135,126,118,112,108,106,102,102,102,102,101,101,101,101);

#my @coeff = (100,81,67,58,51,46,42,39); # hard
my @coeff = (100,97,90,84,78,74,72,70); # soft
#my @coeff = (100,97,94,91,88,85,82,79); # softer
my $scoeff = 0;


foreach my $w (@coeff ){$scoeff += $w;}

#recreate v3_dna for parent tab
my $c = `/usr/local/pgsql/bin/psql -c "\\timing" -c "select _i_v3_dna('$tab',1)" people > .err0.log 2>&1`;

#recreate child tab if flag

#if ($flag) {
system("echo ==== >> log && date >> log && echo '(Re)creating clone $tab\_new' >> log && echo ==== && date && echo '(Re)creating clone $tab\_new'");
$c = `/usr/local/pgsql/bin/psql -c "\\timing" -c "drop table if exists $tab\_new" people >> .err0.log 2>&1`;
$c = `/usr/local/pgsql/bin/psql -c "\\timing" -c "create unlogged table $tab\_new as select * from $tab limit 0" people >> .err0.log 2>&1`;
$c = `/usr/local/pgsql/bin/psql -c "\\timing" -c "alter table $tab\_new add column my_$tab\_new_id bigserial" people >> .err0.log 2>&1`;
system("echo ==== >> log && date >> log && echo 'Copying clone $tab\_new from parent $tab' >> log && echo ==== && date && echo 'Copying clone $tab\_new from parent $tab'");
$c = `/usr/local/pgsql/bin/psql -c "\\timing" -c "insert into $tab\_new select * from $tab" people >> .err0.log 2>&1`;
system("echo ==== >> log && date >> log && echo 'Indexing clone $tab\_new' >> log && echo ==== && date && echo 'Indexing clone $tab\_new'");
$c = `/usr/local/pgsql/bin/psql -c "\\timing" -c "alter table $tab\_new add primary key (my_$tab\_new_id)" people >> .err0.log 2>&1`;
#}

my $nru = ($N/2) - 1;  

system("echo ==== >> log && date >> log && echo 'Creating RocksDB $N stores' >> log && echo ==== && date && echo 'Creating RocksDB $N stores'");

for (my $i = 0; $i <$nru; $i++) {

	$lim = int( 0.5 * $nrows * ($coeff[$i]/$scoeff));
	
	my $j = $i + 1;
	my $k = $N - $i;

	my $c = `/usr/local/pgsql/bin/psql -c "\\timing" -c "explain analyze select _e_v3_dna('$tab',$j, $lim,$sum,'asc')" people > .err$j.log 2>&1 &`;
print "Here store is $j, rows is $lim, offset is $sum, order is asc!\n";	
	$c = `/usr/local/pgsql/bin/psql -c "\\timing" -c "explain analyze select _e_v3_dna('$tab',$k, $lim,$sum,'desc')" people > .err_bis_$j.log 2>&1 &`;
print "Here store is $k, rows is $lim, offset is $sum, order is desc!\n";	


	$sum += $lim;

}


#start the last two runners

my $k = $N - $nru;
my $j = $N/2;

$lim = int( 0.5 * $nrows * ($coeff[$j-1]/$scoeff));

my $c = `/usr/local/pgsql/bin/psql -c "\\timing" -c "explain analyze select _e_v3_dna('$tab',$k,$lim,$sum,'desc')" people > .err_bis_$j.log 2>&1 &`;
print "Here store is $k, rows is $lim, offset is $sum, order is desc!\n";

$lim = $nrows - 2*$sum - $lim;

print "Here store is $j, rows is $lim, offset is $sum, order is asc!\n";
$c = `/usr/local/pgsql/bin/psql -c "\\timing" -c "explain analyze select _e_v3_dna('$tab',$j,$lim,$sum,'asc')" people > .err$j.log 2>&1`;


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


system("echo ==== >> log && date >> log && echo 'Dropping clone $tab\_new' >> log && echo ==== && date && echo 'Dropping clone $tab\_new'");
$c = `/usr/local/pgsql/bin/psql -c "\\timing" -c "drop table if exists $tab\_new" people >> .err0.log 2>&1`;

system("echo ==== >> log && date >> log && echo 'Finished' >> log && echo ==== && date && echo 'Finished'");

exit;
