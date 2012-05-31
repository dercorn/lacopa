#!/usr/bin/perl -w

use strict;
use warnings;
use Text::CSV;

my $sysfile = "systemlist.csv";
my $cfile   = "connectionlist.csv";
my $noc = 0;	# total Number Of Connections
my @sources;
my @targets;
my %slabels;
my %tlabels;
my %outHash;	# actually actively used outputs
my @outArray;	# same as above; for sorting
my %connections;# hash with source-ID->@(list, of, target indices)

# read HSLDs from $sysfile
my $csv = Text::CSV->new();
open (CSV, "<", $sysfile) or die $!;
while (<CSV>) {
	if ( /B0R/ ) { 	# match for Input
		if ($csv->parse($_)) {
			my @columns = $csv->fields();
			push @sources, $columns[10];
			$slabels{$columns[10]} = join('|',$columns[9],$columns[11],$columns[12],$columns[13]);

		} else {
			my $err = $csv->error_input;
			print "Failed to parse line: $err";
		}
	}
	if ( /B0S/ ) {	# match for Output
		if ($csv->parse($_)) {
			my @columns = $csv->fields();
			push @targets, $columns[10];
			$tlabels{$columns[10]} = join('|',$columns[9],$columns[11],$columns[12],$columns[13]);

		} else {
			my $err = $csv->error_input;
			print "Failed to parse line: $err";
		}
	}
}
close CSV;


# get Connections from cfile
open (CSV, "<", $cfile) or die $!;
while (<CSV>) {
	next if ($. == 1);					# omit first line (category names)
	if ($csv->parse($_)) {
		my @columns = $csv->fields();
		my $index = getIndex($columns[3]);		# get index number of current target
		push @{$connections{$columns[0]}}, $index;	# add index of target to value list of source
		$outHash{$index} = 1;				# to get a "list" unique target indices
		$noc++;
	} else {
		my $err = $csv->error_input;
		print "Failed to parse line: $err";
	}
}
close CSV;


## print %connections
#while ( (my $k, my $v) = each %connections ) {
#    print "$k => @{$v}\n";
#}


# created an array of sorted indices from %outHash
foreach my $key (sort {$a<=>$b} keys %outHash) {
	push @outArray, $key;
}

# getindex of target ID
sub getIndex { 
	my $want = $_[0];
	for (my $i=0; $i<=@targets; $i++) {
		if($targets[$i]){
			if($want eq $targets[$i]) {
				return $i;
			} else {
				next;
			}
		} else {
			print "Failed to access \$targets[$i]\n";
		}
	}
}	

# write only active connections of the matrix as csv formatted file
# begin with targets as first line (x-axis)
open (FH, ">", "matrix_active.csv") or die "$!";
print FH '""';						# insert first empty (pivot) cell
for (my $i=0; $i<$noc; $i++) {
	print FH  ",\"$tlabels{$targets[$i]}\""; #",\"$targets[$i]\"";
}
print FH "\n";						# end first line

# for every source (y-axis): create new line and mark targets with an "1"
foreach my $src (@sources) {
	if (!exists($connections{$src})) {		# src w/o target
		# do nothing
	} else {
		print FH  "\"$slabels{$src}\""; #"\"$src\"";
		foreach my $v (@outArray) {
			if ( grep { $_ eq $v } @{$connections{$src}} ) {
				#print "HIT\n";
				print FH ",\"1\"";
			} else {
				print FH ",\"\"";
			}
		}
		print FH "\n";
	}
}
close(FH);

# write complete matrix as csv formatted file
# begin with targets as first line (x-axis)
open (FH, ">", "matrix_full.csv") or die "$!";
print FH '""';						# insert first empty (pivot) cell
foreach my $t (@targets) {				# insert all targets into first line
	print FH ",\"$tlabels{$t}\"";
}
print FH "\n";						# end first line

# for every source (y-axis): create new line and mark targets with an "x"
foreach my $src (@sources) {
	if (!exists($connections{$src})) {		# src w/o target
		print FH "\"$src\"";
		for (my $i=0; $i<=511; $i++) {
			print FH ",\"\"";
		}
		print FH "\n";
	} else {
		print FH "\"$slabels{$src}\"";
		for (my $i=0; $i<=511; $i++) {
			if ( grep { $_ eq $i} @{$connections{$src}} ) {
				#print "HIT\n";
				print FH ",\"1\"";
			} else {
				print FH ",\"\"";
			}
		}
		print FH "\n";
	}
}
close(FH);

exit;
