#!/usr/bin/perl -w
#
# systems.pl < DATA
#
# Computes the distance between a set of 2-system data and a canonical 2-system
# data set.
#
# DATA should be a set of lines, each of which is of the form
#
# class1 class2 number
#
# Here, class1 is a value of the first system (like masc, fem, neut), and
# class2 is a value of the second system (like long, heavy, animate).  Number
# is the token frequency of nouns that belong to the combination of class1 and
# class2.  
#
# Say that there are two systems, A and B (such as gender and classifier).
# They have possible values A1, A2, ... (such as male, female, inanimate, ...)
# and B1, B2, ... (such as long, round, ...).
#
# We first need to describe the token frequency of each these values.
# Represent frequencies as a fraction of the whole:  A1f, A2f, and so forth,
# where the sum of all Anf is 1.0.  So if most nouns are male, some are female,
# and only one is inanimate, we might have A1f = 0.60, A2f = 0.39, A3F = 0.01.
# Do the same for the B series.
#
# In a canonical language, we might expect that A1f = A2f = A3f = ..., but
# let's not do so. We'll allow a canonical language to have any distribution of
# the frequencies, because languages represent the real world, which does not
# have a uniform distribution of, for instance, differently shaped objects.
# But we *do* expect a canonical language to have edge frequencies (in the
# bipartite graph) to respect these token frequencies.  So the edge A1B1 ought
# to have frequency A1f * B1f.  (I use * to mean "multiplied by".) In
# particular, we expect every possible edge to be populated (although
# discretization error might reduce a very small probability to zero).
#
# Let's say that the observed frequencies of the edges are A1B1f, A2B1f, ... .
#
# The total discrepancy TD between those observed frequencies and the canonical
# frequencies is
#
#         TD = sum over all edges i-j (abs(AiBjf - Aif*BiF))
#
# where "abs" means "absolute value", so negative discrepancy is treated as
# positively discrepant.
#
# Now a language with lots of edges gets penalized for each edge.  I think we
# should normalize TD by dividing by the number of edges (including those that
# are not actually evidenced by the language) to get the normalized total
# discrepancy NTD:
#
#         NTD = TD / (size of A * size of B)

use strict;

# global variables
my %cellData; # cellData{class class ...} = count
my %members; # members{class} = count
my %weight; # $weight{"class1 class2"} = count
my $totalCount; # total count of elements
my $columns; # number of columns in the data
my %inColumn; # inColumn{class} = column
my $full; # whether to show extra information

sub init {
	binmode STDIN, ":utf8";
	binmode STDOUT, ":utf8";
	binmode STDERR, ":utf8";
	$full = defined $ARGV[0];
} # init

sub sayError {
	my ($msg) = @_;
	print "<span style='color:red;font-weight:bold'>$msg\n</span>";
} # sayError

sub readData {
	while (my $line = <STDIN>) {
		chomp $line;
		$line =~ s/%.*//; # comments
		next unless $line =~ /\w/; # blank lines
		my @parts = split(/\s+|,/, $line);
		shift @parts if $parts[0] eq '';
		my $count = pop @parts;
		$totalCount += $count;
		$cellData{join(' ', @parts)} += $count;
		if (defined($columns)) {
			sayError("Wrong number of columns (" . scalar(@parts) .
					", not $columns): $line")
				unless scalar @parts == $columns;
		} else {
			$columns = scalar(@parts);
		}
		for my $index1 (0 .. $#parts) {
			my $part1 = $parts[$index1];
			sayError("$part1 is in systems $inColumn{$part1} and $index1")
				if (defined($inColumn{$part1})
					and $inColumn{$part1} != $index1);
			$members{$part1} += $count;
			$inColumn{$part1} = $index1;
			for my $index2 (0 .. $#parts) {
				next if $index1 == $index2;
				my $part2 = $parts[$index2];
				$weight{"$part1 $part2"} += $count;
			} # each index2
		} # each index1
	} # each line
} # readData

sub compute {
	print "Number of lexemes: $totalCount\n";	
	# compute %prob, $classes, $size
	my (%prob); # $prob{class} = value in [0 .. 1]
	my %classes; # $classes{$index} = [class1, ...]
	my @size; # $size[$index] = number of classes in this column
	for my $class (keys %members) {
		$prob{$class} = (0.0 + $members{$class}) / $totalCount;
		my $index = $inColumn{$class};
		$size[$index] += 1;
		$classes{$index} = [] unless exists($classes{$index});
		push @{$classes{$index}}, $class;
		# print "Probability of $class (in column $inColumn{$class}, " .
		# 	"$members{$class} elements): $prob{$class}\n" if $full;
	}
	# compute $cells and $maxSize
	my $cells = 1;
	my $maxSize = 0; # largest size
	for my $index (0 .. $#size) {
		my $theSize = $size[$index];
		$cells *= $theSize;
		$maxSize = $theSize if $theSize > $maxSize;
	};
	# compute $edgeDiscrepancy, $edges, $cellsFilled, $minSize
	my $edgeDiscrepancy = 0.0; # total edge discrepancy
	my $cellsFilled;
	my $edges;
	my $minSize; # prime the pump
	for my $col1 (0 .. $columns-1) {
		for my $col2 ($col1+1 .. $columns-1) {
			my $size = scalar @{$classes{$col1}};
			$minSize = $size if !defined($minSize) or $minSize > $size;
			for my $class1 (@{$classes{$col1}}) {
				for my $class2 (@{$classes{$col2}}) {
					$edges += 1;
					my $cross = "$class1 $class2";
					if (defined($weight{$cross}) and $weight{$cross}>0) {
						$cellsFilled +=1;
					} else {
						$weight{$cross} = 0;
					}
					my $crossProb = (0.0 + $weight{$cross}) / $totalCount;
					my $expectedProb = $prob{$class1} * $prob{$class2};
					my $difference = $crossProb - $expectedProb;
					printf "edge %s, expect %3.2f; see %3.2f; difference %4.2f\n",
						$cross, $expectedProb, $crossProb, $difference
						if ($full and $difference > 0);
					$edgeDiscrepancy += $difference if $difference > 0;
				} # each class2
			} # each class1
		} # each col2
	} # each col1
	# compute per-cell discrepancy
	my $cellDiscrepancy = 0.0;
	for my $cell (keys %cellData) {
		my $expected = 1.0;
		for my $class (split /\s/, $cell) {
			$expected *= (0.0 + $members{$class}) / $totalCount;
		}
		my $difference = 0.0 + ($cellData{$cell} / $totalCount) - $expected;
		next if $difference < 0.0;
		printf "Cell %s, expect %4.2f, see %4.2f, difference %4.2f\n",
			$cell, $expected, ((0.0 + $cellData{$cell}) / $totalCount),
			$difference if ($full and $difference > 0);
		$cellDiscrepancy += $difference;
	}
	my $denominator = 1.0; # for max cell discrepancy
	for my $index (2 .. $columns) {
		$denominator *= $minSize;
	}
	my $maxCellDiscrepancy = 1.0 - (1.0 / $denominator);
	# print statistics
	printf "total edge discrepancy %4.2f%%\n", 100*$edgeDiscrepancy;
	# printf "average edge discrepancy per edge %4.2f%%\n",
	# 	100 * $edgeDiscrepancy / $edges;
	if ($columns > 1) {
	printf "normalized total edge discrepancy %4.2f%%\n",
		100.0 * $edgeDiscrepancy * 2 / ($columns * ($columns -1) * (1.0 - 1.0 / $minSize));
	}
	printf "total cell discrepancy %4.2f%%\n", 100*$cellDiscrepancy;
	printf "normalized total cell discrepancy %4.2f%%\n", 100*$cellDiscrepancy/$maxCellDiscrepancy;
	printf "cells filled %d, possible cells %d, minimum %d\n",
		$cellsFilled, $cells, $maxSize;
	my $orthogonality = 100*(0.0 + $cellsFilled - $maxSize) /
		($cells - $maxSize);
	printf "orthogonality %4.2f%%; anti-orthogonality %4.2f%%\n",
		$orthogonality, 100-$orthogonality;
} # compute

init();
readData();
compute();
