#!/usr/bin/env perl
#============================================================
#
#        FILE: tags3.pl
#       USAGE: perl ./tags3.pl
#  DESCRIPTION: ---
#       AUTHOR: Azuhmier (aka taganon), azuhmier@gmail.com
#===========================================================
use strict;
use warnings;
use utf8;
use JSON;
use Storable qw(dclone);
use Data::Dumper;

##Assumptions
# no backslashes in dspt key names
# all dspt key names are unique

#----- FILEPATHS -----{{{1
my $fname_IN = '../tagCatalog.txt';

#----- REGEX CONFIG -----{{{1
my $dspt = {
  section => {
    order => '1',
    re => qr/^\s*%+\s*(.*?)\s*%+/,
    match => [],
  },
  author => {
    order => '1.1',
    re => qr/^\s*[Bb]y\s+(.*)/,
    partion => {
      author_attribute => qr/\((.*)\)/,
    },
    match => [],
  },
  series => {
    order => '1.1.1',
    re => qr/^\s*=+\/\s*(.*)\s*\/=+/,
    match => [],
  },
  title => {
    order => '1.1.1.1',
    re => qr/^\s*>\s*(.*)/,
    partion => {
      title_attribute => qr/\((.*)\)/,
    },
    match => [],
  },
  tags => {
    order => '1.1.1.1.1',
    re => qr/^\s*(\[.*)/,
    partion => {
      anthro  => qr/(?x) ^\[  ([^\[\]])\+ \]\[/,
      general => qr/(?x) \]\[ ([^\[\]])\+ \]/,
      ops     => qr/(?x) \]   ([^\[\]])\+ $/,
      all     => [ qw( anthro general ) ],
    },
    match => [],
  },
  url => {
    order => '1.1.1.1.2',
    re => qr/^\s*(https?:\/\/[^\s]+)\s+\((.*)\)/,
    partion => {
      label => [ qw( \2 ) ],,
    },
    match => [],
  },
  description => {
    order => '1.1.1.1.3',
    re => qr/^\s*#(.*)/,
    match => [],
  },
  test => {
    order => '2',
    match => [],
  },
  test2 => {
    order => '2.1',
    match => [],
  },
  test3 => {
    order => '2.1.1',
    match => [],
  },
  test4 => {
    order => '2.1.1.1',
    match => [],
  },
  test5 => {
    order => '2.1.1.2',
    match => [],
  },
  test6 => {
    order => '2.1.1.2.1',
    match => [],
  },
};


#----- Main -----{{{1
my $capture_hash  = file2hash( $fname_IN );
my $formated_hash = hash_delegate( { capture_hash => $capture_hash, dspt => $dspt } );


#----- Subroutines -----{{{1
sub hash_delegate {
  my $args = shift @_;
  my $capture_hash = $args->{capture_hash};
  my $dspt         = $args->{dspt};

  my $output = leveler ({
    capture_hash => $capture_hash,
    dspt         => $dspt,
  });
}


sub getPoint {
  my $dspt  = shift @_;
  my $point = shift @_;
  my $point_str = join '.', $point->@*;
  my @match = grep { $dspt->{$_}->{order} =~ /^$point_str$/ } keys $dspt->%*;

  if ( !$match[0] ) {
    return 0;
  }
  elsif ( scalar @match > 1 ) {
    die("more than one objects have the point: \'${point_str}\', for ${0} at line: ".__LINE__);
  }
  else {
    return $match[0];
  }
}


sub leveler {
  my $args = shift @_;
  my $capture_hash = $args->{capture_hash};
  my $dspt         = $args->{dspt};
  my $point        =  exists $args->{point} ? $args->{point} : [1];

  my $obj;
  #----- Exists? -----
  if ( getPoint($dspt, $point) ) {
    $obj = getPoint($dspt, $point);
    print "object \'${obj}\' exists\n";
  }
  else {
    my $point_str = join '.', $point->@*;
    die("Point \'${point_str}\' does not exist, for ${0} at line: ".__LINE__) 
  }

  #----- Child? -----
  push $point->@*, 1;
  if ( getPoint($dspt, $point) ) {
    my $child = getPoint($dspt, $point);
    print "object \'${obj}\' has child \'${child}\'\n";
    #my $output = leveler ({
    #  capture_hash => $capture_hash,
    #  dspt         => $dspt,
    #  point        => $point,
    #});
  }
  else { pop $point->@*, 1 }

  #----- Sybling? -----
  $point->[-1]++;
  if ( getPoint($dspt, $point) ) {
    my $sybling = getPoint($dspt, $point);
    print "object \'${obj}\' has sybling \'${sybling}\'\n";
  }
  else { $point->[-1]-- }





  #my $output = leveler ( {
  #  capture_hash => $capture_hash,
  #  dspt         => $dspt,
  #  pointer      => $pointer,
  #});

  #my @level_keys  = grep { scalar $reff->{$_}->@* == $dial->[0] } keys %$reff;
  #my @point_keys = grep { scalar $reff->{$_}->@* == [1,1] } keys %$reff;
  #my $dial    =  exists $args->{dial} ? $args->{dial} : [4,1];
  #my %level = $reff->%{@level_keys};
  #my %point = $reff->%{@point_keys};
  #print Dumper(\%level);
  #print Dumper(\%point);
}

sub file2hash {
  my $fname = shift @_;
  my $output;

  open( my $fh, '<', $fname )  #Open Masterbin for reading
    or die $!;

  while ( my $line = <$fh> ) {

    for my $obj_key ( keys %$dspt ) {
      my $obj = $dspt->{$obj_key};

      if ($obj->{re} && $line =~ /$obj->{re}/ ) {
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
