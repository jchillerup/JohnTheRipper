#!/usr/bin/perl -w
#
# John the Ripper benchmark output comparison tool, revision 3
# Copyright (c) 2011 Solar Designer
# Redistribution and use in source and binary forms, with or without
# modification, are permitted.  (This is a heavily cut-down "BSD license".)

sub parse
{
	chomp;
	if (/^$/) {
		undef $id;
		undef $name;
		undef $kind; undef $real; undef $virtual;
		return;
	}
	my $ok = 0;
	if (defined($name)) {
		($kind, $real, $reals, $virtual, $virtuals) =
		    /^([\w ]+):\s+([\d.]+)([KM]?) c\/s real, ([\d.]+)([KM]?) c\/s virtual$/;
		undef $id;
		if ($name && $kind && $real && $virtual) {
			$id = $name . ':' . $kind;
			$real *= 1000 if ($reals eq 'K');
			$real *= 1000000 if ($reals eq 'M');
			$virtual *= 1000 if ($virtuals eq 'K');
			$virtual *= 1000000 if ($virtuals eq 'M');
			return;
		} else {
			($kind, $real, $reals) =
				/^([\w ]+):\s+([\d.]+)([KM]?) c\/s$/;
			if ($name && $kind && $real) {
				$id = $name . ':' . $kind;
				$real *= 1000 if ($reals eq 'K');
				$real *= 1000000 if ($reals eq 'M');
				$virtual = $real;
				return;
			}
		}
	} else {
		($name) = /^Benchmarking: (.+) \[.*\].* DONE$/;
		$ok = defined($name);
	}
	print STDERR "Could not parse: $_\n" if (!$ok);
}

die "Usage: $0 BENCHMARK-FILE-1 BENCHMARK-FILE-2\n" if ($#ARGV != 1);

open(B1, '<' . $ARGV[0]) || die "Could not open file: $ARGV[0] ($!)";
open(B2, '<' . $ARGV[1]) || die "Could not open file: $ARGV[1] ($!)";

$_ = '';
parse();
while (<B1>) {
	parse();
	next unless (defined($id));
	$b1r{$id} = $real;
	$b1v{$id} = $virtual;
}
close(B1);

$_ = '';
parse();
while (<B2>) {
	parse();
	next unless (defined($id));
	$b2r{$id} = $real;
	$b2v{$id} = $virtual;
}
close(B2);

foreach $id (keys %b1r) {
	if (!defined($b2r{$id})) {
		print "Only in file 1: $id\n";
		next;
	}
}

$minr = $maxr = $minv = $maxv = -1.0;
$mr = $mv = 1.0;
$n = 0;
foreach $id (keys %b2r) {
	if (!defined($b1r{$id})) {
		print "Only in file 2: $id\n";
		next;
	}
	my $kr = $b2r{$id} / $b1r{$id};
	my $kv = $b2v{$id} / $b1v{$id};
	$minr = $kr if ($kr < $minr || $minr < 0.0);
	$maxr = $kr if ($kr > $maxr);
	$minv = $kv if ($kv < $minv || $minv < 0.0);
	$maxv = $kv if ($kv > $maxv);
	$akr[$n] = $kr;
	$akv[$n] = $kv;
	$mr *= $kr;
	$mv *= $kv;
	$n++;
}

print "Number of benchmarks:\t\t$n\n";
exit unless ($n);

printf "Minimum:\t\t\t%.5f real, %.5f virtual\n", $minr, $minv;
printf "Maximum:\t\t\t%.5f real, %.5f virtual\n", $maxr, $maxv;

@akr = sort @akr;
@akv = sort @akv;
if ($n & 1) {
	$medr = $akr[($n - 1) / 2];
	$medv = $akv[($n - 1) / 2];
} else {
	$medr = ($akr[$n / 2 - 1] * $akr[$n / 2]) ** 0.5;
	$medv = ($akv[$n / 2 - 1] * $akv[$n / 2]) ** 0.5;
}
printf "Median:\t\t\t\t%.5f real, %.5f virtual\n", $medr, $medv;

$mr **= 1.0 / $n;
$mv **= 1.0 / $n;
$dr = $dv = 0.0;
for ($i = 0; $i < $n; $i++) {
	$adr[$i] = abs($akr[$i] - $medr);
	$adv[$i] = abs($akv[$i] - $medv);
	$dr += log($akr[$i] / $mr) ** 2;
	$dv += log($akv[$i] / $mv) ** 2;
}
$dr = exp(($dr / $n) ** 0.5);
$dv = exp(($dv / $n) ** 0.5);

@adr = sort @adr;
@adv = sort @adv;
if ($n & 1) {
	$madr = $adr[($n - 1) / 2];
	$madv = $adv[($n - 1) / 2];
} else {
	$madr = ($adr[$n / 2 - 1] * $adr[$n / 2]) ** 0.5;
	$madv = ($adv[$n / 2 - 1] * $adv[$n / 2]) ** 0.5;
}
printf "Median absolute deviation:\t%.5f real, %.5f virtual\n", $madr, $madv;

printf "Geometric mean:\t\t\t%.5f real, %.5f virtual\n", $mr, $mv;
printf "Geometric standard deviation:\t%.5f real, %.5f virtual\n", $dr, $dv;