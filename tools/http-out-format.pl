#!/usr/bin/perl

use strict;
use warnings;

local $/;
my $input = <STDIN>;

my $code = $input =~ /^HTTP\/\S+ (\d+)/m ? $1 : '-';
my $date = $input =~ /^Date: (.+)/mi ? $1 : '-';
my $xcache = $input =~ /^X-Cache: (.+)/mi ? $1 : '-';
my $body = $input =~ /\r?\n\r?\n(.*)/s ? $1 : '-';

$date =~ s/\r//g;
$body =~ s/\n/ /g;
$body =~ s/\s+$//;

my $localtime = localtime();
print "$localtime | $code | $date | $body | $xcache\n";
