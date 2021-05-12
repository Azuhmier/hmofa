#!/usr/bin/env perl
#============================================================
#
#        FILE: tags.pl
#       USAGE: perl ./tags.pl
#  DESCRIPTION: ---
#       AUTHOR: Azuhmier (aka taganon), azuhmier@gmail.com
#      Created: Sun 12/20/20 16:47:38
#===========================================================

use strict;
use warnings;
use utf8;
use XML::Simple;
use JSON;
use Data::Dumper;
$Data::Dumper::Indent = 1;
use Storable qw(dclone);

#----- FILEPATHS -----{{{1
my $fname_IN = '../tagCatalog.txt';


#----- REGEX CONFIG -----{{{1
my $dspt = {
  section => {
    order => '1a',
    re => qr/^\s*%+\s*(.*?)\s*%+/,
    match => [],
  },
  author => {
    order => '2a',
    re => qr/^\s*[Bb]y\s+(.*)/,
    match => [],
  },
  series => {
    order => '3a',
    re => qr/^=+\/\s*(.*)\s*\/=+/,
    match => [],
  },
  title => {
    order => '4a',
    re => qr/^\s*>\s*(.*)/,
    match => [],
  },
  tags => {
    order => '5a',
    re => qr/^\s*(\[.*)/,
    match => [],
  },
  url => {
    order => '5b',
    re => qr/(https?:\/\/[^\s]+)\s+(.*)/,
    match => [],
  },
  description => {
    order => '5c',
    re => qr/^#(.*)/,
    match => [],
  },
};

my @a = grep {$dspt->{$_}->{order} } keys %$dspt;

print Dumper(\@a);
#----- Main -----{{{1
my $capture_hash = file2hash( $fname_IN );
#my $formated_hash = formatHash( $capture_hash, $dspt );

#----- Subroutines -----{{{1
sub file2hash {
  my $fname = shift @_;
  my $output;
  open( my $fh, '<', $fname )  #Open Masterbin for reading
    or die $!;

    while ( my $line = <$fh> ) {

      for my $obj_key ( keys %$dspt ) {
        my $obj = $dspt->{$obj_key};

        if ( $line =~ /$obj->{re}/ ) {
          my $match = {
            LN       => $.,
            $obj_key => $1, };
          push  $output->{$obj_key}->@*, $match;

        }
      }
    }

  close($fh);

  return $output;
}

sub formated_hash {
  my $capture_hash = shift @_;
  my $dspt = shift @_;
  my $reff = generate_reffHash($dspt);
  my $output = {};

  for my $obj_key ( keys %$dspt ) {
     my $obj = $dspt->{$obj_key};
     push  @$reff, [ $obj->{order}, $obj_key ];
  }

  @$reff = sort { @$a[0] cmp @$b[0] } @$reff;

  for my $author ( reverse $dspt->{author}->{match}->@* ) {
    my $lineA = ${$author}{LN};
    my $obj = $output->{ ${$author}{contents} };
    $output->{ ${$author}{contents} } = { LN => ${$author}{LN} };

    for my $b ( reverse $dspt->{title}->{match}->@*) {
      my $lineB = ${$b}{LN};

      if ( $lineA < $lineB ) {
        my $nameB = ${$b}{contents};
        $output->{ ${$author}{contents} }->{titles}->{$nameB}->{urls}= [];

        for my $c ( reverse $dspt->{url}->{match}->@*) {
          my $lineC = ${$c}{LN};

          if ( $lineB < $lineC ) {
            my $nameC = ${$c}{contents};
            push $output->{ ${$author}{contents} }->{titles}->{$nameB}->{urls}->@*, $nameC;
            pop $dspt->{url}->{match}->@*;
          }
          else {
            last;
          }
        }
        pop $dspt->{title}->{match}->@*;
      }
      else {
        last;
      }
    }
  }
}

sub generate_reffHash {
}
##----- BEAUTIFY -----{{{1
#  my $DP_output = dclone($output); # Deep Copy of $output
#  my $output2 = [];                # New Better Hash
#  for my $author (keys %$DP_output) {
#    my @titles;
#    for my $title (keys %{$DP_output->{$author}->{titles}}) {
#      my @urls = reverse @{$DP_output->{$author}->{titles}->{$title}->{urls}}; # descending order
#      my %title_hash = ( 
#        title => $title,
#        urls => \@urls,
#      );
#      push @titles, \%title_hash;
#    }
#    my %author_hash = ( 
#      author => $author,
#      stories => \@titles,
#      LineNumber => $DP_output->{$author}->{LN},
#    );
#
#    push @$output2, \%author_hash;
#  }
#  $output2 = {masterbin => $output2};
##print Dumper($output2);
##----- EXTERNAL DATASTRUCTS -----{{{1
#  #==|| XML
#  my $xml = XMLout($output);
#  my $xml2 = XMLout($output2,NoAttr => 1);
#  #==|| JSON
#  my $json_obj = JSON->new->allow_nonref;
#  my $json = $json_obj->pretty->encode($output);
#  my $json_obj2 = JSON->new->allow_nonref;
#  $json_obj2 = $json_obj2->canonical([1]);
#  my $json2 = $json_obj2->pretty->encode($output2);
#  #print $json2;
##----- WRITING TO FILES -----{{{1
#  open(my $fh_MasterBinXML, '>' , $fname) or die $!;
#    print $fh_MasterBinXML $xml2;
#  close($fh_MasterBinXML);
#  open(my $fh_MasterBinjson, '>' , $fname) or die $!;
#    print $fh_MasterBinjson $json2;
#  close($fh_MasterBinjson);
#
##----- META -----{{{1
#my $cmd = q{sed -n 's/^>\(.*\)/\1/p' ../masterbin.txt > ../story_list.txt};
#system($cmd);
#my $cmd2 = q{sed -n 's/^[Bb]y \(.*\)/\1/p' ../masterbin.txt > ../author_list.txt};
#system($cmd2);
#
##----- SUBROUTINES -----{{{1
#sub uniq {
#    my %seen;
#    grep !$seen{$_}++, @_;
#}
#sub argParser {
#}
