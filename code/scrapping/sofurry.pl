#!/usr/bin/env perl
use warnings;
use strict;
use DBD::DBM;
no warnings 'utf8';

use LWP::UserAgent;
use HTML::SimpleLinkExtor;
use XML::LibXML;

# Create a new instance of the class "UserAgent" called "ua" with a timout of 10
my $ua = LWP::UserAgent->new(timeout => 10);

# set the agent to Mozzilla ver. 5.0 so we don't look like we are up to no good.
$ua->agent('Mozilla/5.0'); 

# set the get url to the /hmofa/ thread search address
my $count = 0;
my $xpath;

#my $response = $ua->get('https://www.sofurry.com/view/1624674');
my $response = $ua->get('https://webbook.nist.gov/cgi/cbook.cgi?Name=butylbenzene&Units=SI&cIR=on&cMS=on&cUV=on');
#my $response = $ua->get('https://www.sofurry.com/view/1663701');
#my $response = $ua->get('https://www.sofurry.com/view/1663140');
unless ( $response->is_success ) {
  die $response->status_line;
}

my $html = $response->decoded_content;
open my $fh, '>', glob('./test.html');
  print $fh $html;
close $fh;

my $dom = XML::LibXML->load_html(
    location        => 'test.html',
    recover         => 1,
    suppress_errors => 1,
);

#$xpath = '/html/body/div[2]/div/div[3]/div[3]/div[1]/div[1]/div[2]/div[2]/span';
#$xpath = '/html/body/div[2]/div[1]/div[3]/div[3]/div[1]/div[1]/div[2]/p';
$xpath = '/html/body/main/ul[1]/li[5]';

for my $sections ( $dom->findnodes($xpath) ) {
  print $sections->to_literal();
}
#print $dom->toStringHTML();
