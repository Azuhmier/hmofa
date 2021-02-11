#!/usr/bin/env perl
use warnings;
use strict;
#use LWP::Simple;
use LWP::UserAgent;
use utf8;

my $ua = LWP::UserAgent->new(timeout => 10);
$ua->agent('Mozilla/5.0'); 
my $start = time;

my $response = $ua->get('http://api2.sofurry.com/std/getUserProfile');
print $response->decoded_content;
