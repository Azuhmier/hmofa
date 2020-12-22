#!/usr/bin/perl;
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

my $response = $ua->get('https://pastebin.com/wsb88mUj');
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


$xpath = '/html/body/div[1]/div[2]/div[1]/div/div[1]/div[3]/div[2]/div[1]/a';
for my $sections ( $dom->findnodes($xpath) ) {
  print "===================" . "\n";
  print  "  " . $sections->to_literal(), "\n";
  my $href = $sections->findvalue('./@href');
  print "  " . $href, "\n";
  #->to_literal_list) {
}

$xpath = '/html/body/div[1]/div[2]/div[1]/div/div[1]/div[3]/div[1]/h1';
for my $sections ( $dom->findnodes($xpath) ) {
  print "===================" . "\n";
  print "  " . $sections->to_literal(), "\n";
}

$xpath = '/html/body/div[1]/div[2]/div[1]/div/div[1]/div[3]/div[2]/div[2]/span[1]';
for my $sections ( $dom->findnodes($xpath) ) {
  print "===================" . "\n";
  print "  " . $sections->to_literal(), "\n";
  my $title = $sections->findvalue('./@title');
  print "  " . $title, "\n";
}

$xpath = '/html/body/div[1]/div[2]/div[1]/div/div[1]/div[3]/div[2]/div[2]/span[2]';
for my $sections ( $dom->findnodes($xpath) ) {
  print "===================" . "\n";
  print "  " . $sections->to_literal(), "\n";
  my $title = $sections->findvalue('./@title');
  print "  " . $title, "\n";
}

$xpath = '/html/body/div[1]/div[2]/div[1]/div/div[1]/div[3]/div[2]/div[3]';
for my $sections ( $dom->findnodes($xpath) ) {
  print "===================" . "\n";
  print "  " . $sections->to_literal(), "\n";
  my $class = $sections->findvalue('./@class');
  my $title = $sections->findvalue('./@title');
  print "  " . $class . "\n";
  print "  " . $title . "\n";
}

