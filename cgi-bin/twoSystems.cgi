#!/usr/bin/perl -wT
#
# twoSystems.cgi
#
# CGI-bin script.  
# Computes the two-systems statistics from a set of edge weights.
# Raphael Finkel 5/2016

use CGI::Simple::Standard qw(:standard -debug);
use CGI::Carp qw(fatalsToBrowser);
use Encode;
use URI::Escape;
use HTML::Template;
# use Encode;
use strict;
use utf8;

# constants
	my $HTMLtemplateFile = "twoSystems.tmpl"; # output template

# global variables
	my $HTML = HTML::Template->new(utf8 => 1, filename => $HTMLtemplateFile);
	my $computeProgram = "twoSystems.pl";

sub init {
	binmode STDIN, ":utf8";
	binmode STDOUT, ":utf8";
	binmode STDERR, ":utf8";
	$ENV{'PATH'} = '/bin:/usr/bin:/usr/local/bin:/usr/local/gnu/bin';
	$| = 1; # flush output
} # init

sub sayError {
	my ($msg) = @_;
	print "Content-Type: text/html; charset=utf-8\n
	<head><title>error</title></head><body>
	<span style='color:red;font-weight:bold'>$msg\n
		</span></html></body>\n";
	exit(0);
} # sayError

sub doIt {
	my $data = param('data');
	if (defined($data)) {
		my $full = param('full') // '';
		my $fileName = "/tmp/twoSystems$$.data";
		open DATAFILE, ">$fileName";
		print DATAFILE $data;
		close DATAFILE;
		print STDERR "About to invoke $computeProgram\n";
		my $result = `/usr/bin/perl -w $computeProgram $full < $fileName`;
		print STDERR "result is $result\n";
		unlink $fileName;
		# print "result is $result\n";
		$HTML->param('result' => $result);
	} else {
		$HTML->param('result' => 0);
	}
	print "Content-Type: text/html; charset=utf-8\n\n";
	print $HTML->output();
} # doIt;

print STDERR "starting up the CGI program\n";
init();
doIt();
