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
use List::Util;
use Storable qw(dclone);

##Assumptions
# - no backslashes in dspt key names
# - all dspt key names are unique
# - partions patterns are independent of order
# - each child type only belongs to only one object type
# - Cannot have key named "TOP" 
# - all prior levels must have lne numbers after the lowest line number of the
#   first level.

#----- REGEX CONFIG -----{{{1
my $dspt = {
  section => {
    name    => 'SECTIONS',
    order   => '1',
    re      => qr/^\s*%+\s*(.*?)\s*%+/,
    exclude => ['Introduction/Key', 'Stories from outside /hmofa/'],
  },
  author => {
    name    => 'AUTHORS',
    order   => '1.1',
    re      => qr/^\s*[Bb]y\s+(.*)/,
    partion => {
      author_attribute => [ qr/\s+\((.*)\)/ ],
    },
  },
  series => {
    name  => 'SERIES',
    order => '1.1.1',
    re    => qr/^\s*=+\/\s*(.*)\s*\/=+/,
  },
  title => {
    name    => 'STORIES',
    order   => '1.1.1.1',
    re      => qr/^\s*>\s*(.*)/,
    partion => {
      title_attribute => [ qr/\s+\((.*)\)/ ],
    },
  },
  tags => {
    name    => 'TAGS',
    order   => '1.1.1.1.1',
    re      => qr/^\s*(\[.*)/,
    scalar  => 1,
    partion => {
      anthro  => [ qr/(?x) ^\[  ([^\[\]]*)/     , 1, [';',','] ],
      general => [ qr/(?x) \]\[ ([^\[\]]*) \]/  , 2, [';',','] ],
      ops     => [ qr/(?x) ([^\[\]]*) $/        , 3],
    },
  },
  url => {
    name    => 'URLS',
    order   => '1.1.1.1.2',
    re      => qr/^\s*(http.*)/,
    partion => {
      url_attribute => [ qr/\s*\((.*)\)/ ],
    },
  },
  description => {
    name   => 'DESCRIPTIONS',
    order  => '1.1.1.1.3',
    re     =>  qr/^\s*#(.*)/,
    scalar => 1,
  },
  test => {
    order => '2',
  },
  test2 => {
    order => '2.1',
  },
  test3 => {
    order => '2.1.1',
  },
  test4 => {
    order => '2.1.1.1',
  },
  test5 => {
    order => '2.1.1.2',
  },
  test6 => {
    order => '2.1.1.2.1',
  },
  test33 => {
    order => '2.1.2',
  },
  test333 => {
    order => '2.1.2.1',
  },
};


#----- Main -----{{{1
my $fname_IN = '../tagCatalog.txt';
#my $fname_IN = '../masterbin.txt';
my $capture_hash  = file2hash( $fname_IN );

#----- TESTS -----{{{2
my $num = 2;
$capture_hash->{test} = [
  {
    'LN' => 76,
    'test' => 'MINNIE: HIGH VELOCITY COURTING '
  },
  {
    'LN' => 76,
    'test' => 'MINNIE: HIGH VELOCITY COURTING '
  },
];
$capture_hash->{test33} = [
  {
    'LN' => 76,
    'test33' => 'MINNIE: HIGH VELOCITY COURTING '
  },
  {
    'LN' => 76,
    'test33' => 'MINNIE: HIGH VELOCITY COURTING '
  },
];
$capture_hash->{test3} = [
  {
    'LN' => 76,
    'test3' => 'MINNIE: HIGH VELOCITY COURTING '
  },
  {
    'LN' => 76,
    'test3' => 'MINNIE: HIGH VELOCITY COURTING '
  },
];
#for my $key ( keys $capture_hash->%* ) {
#  if ( exists $capture_hash->{$key}->[$num] ) {
#    $capture_hash->{$key}->@* = $capture_hash->{$key}->@[0..$num];
#    #$capture_hash->{$key}->@* = map { delete $_->{LN} } $capture_hash->{$key}->@*;
#  }
#  else {
#    my @array = $capture_hash->{$key}->@*;
#    $capture_hash->{$key}->@* = $capture_hash->{$key}->@[0..$#array];
#    #$capture_hash->{$key}->@* = map { delete $_->{LN} } $capture_hash->{$key}->@*;
#  }
#}
#----- Output -----{{{2
my $data = { 
  capture_hash  => $capture_hash, 
  dspt          => $dspt,
  result        => {},
  verbose       => 1,
  lineNums      => 1,
};
my $formated_hash = delegate($data);
#print Dumper($formated_hash);


#----- Subroutines -----{{{1
#-----| file2hash() -----{{{2
sub file2hash {
  my $fname = shift @_;
  my $output;

  open( my $fh, '<', $fname )  #Open Masterbin for reading
    or die $!;

  while ( my $line = <$fh> ) {

    for my $obj_key ( keys %$dspt ) {
      my $obj = $dspt->{$obj_key};

      if ( $obj->{re} && $line =~ /$obj->{re}/ ) {
        my $match = {
          LN       => $.,
          $obj_key => $1,
        };
        push  $output->{$obj_key}->@*, $match;
      }
    }
  }
  close($fh);
  return $output;
}


#-----| hash_delegate() -----{{{2
sub delegate {
  print "start DELEGATE\n";
  my $data = shift @_;
  checkCapture($data->{capture_hash});
  checkDspt($data->{dspt});

  return leveler ($data);
}


#-----| leveler() -----{{{2
sub leveler {
  my $data = shift @_;
  unless ( exists $data->{point}  ) { $data->{point}  = [] }
  unless ( exists $data->{stack}  ) { $data->{stack}  = [] }
  unless ( exists $data->{result} ) { $data->{result} = {} }
  unless ( exists $data->{reff}   ) { $data->{reff}   = [ $data->{result} ] }
  message("Start LEVELER at (" . getPointStr($data).")", $data, __LINE__, 0, 1, 1);

  #----- Checking existance of OBJ at point -----
  message( "Checking for OBJ", $data, __LINE__, 0, 0, 1 );
  my $obj = getObj( $data->@{'dspt', 'point'} );
  if ( !$obj ) {
    message( "..does not exist: OBJ", $data, __LINE__, 0, 0, 1 );
    message( "Exiting LEVLER instance", $data, __LINE__, 0, 0, 1 );
    return;
  }
  message( "..exists OBJ: \'${obj}\'", $data, __LINE__, 0, 0, 1 );

  #----- Sweep Obj -----
  my $lvl_reff;
  while ( $obj ) {
    message( "Selecting OBJ: \'${obj}\'", $data, __LINE__, 0, 0, 1 );

    #----- Checking status of lvl_reff -----
    message( "Checking for LVL_REFF", $data, __LINE__, 0, 0, 1 );
    unless ( defined $lvl_reff ) {
      message("..not defined: 'lvl_reff'", $data, __LINE__, 0, 0, 1 );
      $lvl_reff->@* = get_Lvl_reff($data);
      message("..setting 'lvl_reff' to 'Data->{reff}'", $data, __LINE__, 0, 0, 1 );
    }
    else {
      message( "..defined: 'lvl_reff'", $data, __LINE__, 0, 0, 1 );
    }

    #----- Populate -----
    populate( $data, $obj );

    #----- Check for Children? -----
    message( "Checking for CHILDREN", $data, __LINE__, 0, 0, 1 );
    message( "..Descend point (" . getPointStr($data) . ") by 1 level", $data, __LINE__, 0, 0, 1 );
    push $data->{point}->@*, 1;
    message( "..new point: (" . getPointStr($data) . ")", $data, __LINE__, 0, 0, 1, 1 );
    leveler( $data );
    message( "..Ascend point (" . getPointStr($data) . ") by 1 level", $data, __LINE__, 0, 0, 1, 1 );
    pop $data->{point}->@*, 1;
    message( "..new point: (" . getPointStr($data) . ")", $data, __LINE__, 1, 0, 1, 1);
    message( "..Returning data_reff at to lvl_reff", $data, __LINE__, 0, 0, 1 );
    $data->{reff}->@* = $lvl_reff->@*;

    #----- Check for SYBLINGS? -----
    message( "Checking for SYBLINGS", $data, __LINE__, 0, 0, 1 );
    if ( scalar $data->{point}->@* ) {
      message( "..increase point (". getPointStr($data) .") by 1", $data, __LINE__, 0, 0, 1 );
      $data->{point}->[-1]++;
      message( "..new point:  (" . getPointStr($data) . ")", $data, __LINE__, 0, 0, 1 );
    }
    else {
      message( "..can not increase point (" . getPointStr($data), $data, __LINE__, 0, 0, 1 );
      message( "Exiting LEVLER", $data, __LINE__, 0, 0, 1 );
      last;
    }
    $obj = getObj( $data->@{'dspt', 'point'} ); # set 'obj' to new 'obj' (next SYBLINGO)
    unless ($obj) {
      message("..does not exist: SYBLING", $data, __LINE__, 0, 0, 1);
      message("Exiting LEVLER", $data, __LINE__, 0, 0, 1);
    }
    else {
      message("..exists SYBLING: \'${obj}\'", $data, __LINE__, 0, 0, 1);
    }
  }
  return $data->{result};
}

#-----| populate() -----{{{2
sub populate {
  my $data = shift @_;
  my $obj  = shift @_;
  message("start POPULATE for '${obj}'", $data, __LINE__, 0, 0, 1 );
  if ( $obj ne 'TOP' && exists $data->{capture_hash}->{$obj} ) {
    divyMatches( $data, $obj );
  }
  else {
    message("..cannot populate for '${obj}'", $data, __LINE__, 1, 0, 1 );
    message("Exiting POPULATE", $data, __LINE__, 1, 0, 1 );
  }
}


#-----| divyMatches() -----{{{2
sub divyMatches {
    my $data = shift @_;
    my $obj  = shift @_;
    my $name = getname( $data->{dspt}, $obj );
    my $pond = dclone( ${$data}{capture_hash}->{$obj} );
    message( "start DIVY_MATCHES for '${obj}'", $data, __LINE__, 1, 0, 1 );

    #----- DIVY MATCHES -----
    my $ind = ( scalar ${$data}{reff}->@* ) - 1;
    for my $reff ( reverse ${$data}{reff}->@*) {
      #----- Check for reff line numbers -----
      message("Checking for reff line number", $data, __LINE__, 2, 0, 1 );
      my $line_reff;
      if ($reff->{LN}) {
        $line_reff = $reff->{LN};
        message("..exists reff line number at '${line_reff}'", $data, __LINE__, 2, 0, 1 );
      }
      else {
        $line_reff = 0;
        message("..does not exists: reff line number", $data, __LINE__, 2, 0, 1 );
        message("..setting reff line number to '${line_reff}'", $data, __LINE__, 2, 0, 1 );
      }
      my $line_reff = $reff->{LN} ?  $reff->{LN} : 0;
      message("Selecting reff index (${ind}) at line " . $line_reff, $data, __LINE__, 2, 0, 1 );
      my $bucket;
      for my $match ( reverse $pond->@* ) {
        message("Selecting match  at line '" . $match->{LN} . "'", $data, __LINE__, 3, 0, 1 );
        if ( $match->{LN} > $line_reff ) {
          message( "..found: line_match '" . $match->{LN} . "' > line_reff '${line_reff}'", $data, __LINE__, 3, 0, 1 );
          my $catch = pop $pond->@*;
          addPartion( $data, $obj, $catch );
          push $bucket->@*, $catch;
        }
        else {
          message( "..not found: line_match '" . $match->{LN} . "' > line_reff '${line_reff}'", $data, __LINE__, 3, 0, 1 );

          last;
        }
      }
      if ( $bucket ) {
        $bucket->@* = reverse $bucket->@*;

        ${$data}{reff}->[$ind]->{$name} = $bucket;
        splice( ${$data}{reff}->@*, $ind, 1, $bucket->@* );

      }
      message("Deincrementing reff index (${ind}) by 1", $data, __LINE__, 2, 0, 1 );
      $ind--;
      message("..new index at (${ind})", $data, __LINE__, 2, 0, 1 );
    }
    message("Iteration through reff indices is complete", $data, __LINE__, 2, 0, 1 );
    message("Exiting DIVY_MATCHES", $data, __LINE__, 2, 0, 1 );
    return $name;
}


#-----| addPartion() -----{{{2
sub addPartion {
  my $data  = shift @_;
  my $obj   = shift @_;
  my $catch = shift @_;
  my $raw = $catch->{$obj};
  my $flag;
  message( "start ADD_PARTION for '${obj}'", $data, __LINE__, 3, 0, 1 );
  message( "Checking for PARTION"          , $data, __LINE__, 4, 0, 1 );
  if ( exists $data->{dspt}->{$obj}->{partion} ) {
    message( "..exists: PARTION" , $data, __LINE__, 4, 0, 1 );
    for my $attrib (keys $data->{dspt}->{$obj}->{partion}->%*) {
      message( "Selecting ATTRIB '${attrib}'", $data, __LINE__, 5, 0, 1 );
      message( "Searching for ATTRIB match"  , $data, __LINE__, 5, 0, 1 );
      $catch->{$obj} =~ s/$data->{dspt}->{$obj}->{partion}->{$attrib}->[0]//g;
      if ($1 && $1 ne '') {
        $flag = 1;
        $catch->{$attrib} = $1;
        message( "..Found: '".$catch->{$attrib}."'"  , $data, __LINE__, 5, 0, 1 );
        message( "Checking for Additianol Partioning", $data, __LINE__, 5, 0, 1 );
        if (scalar $data->{dspt}->{$obj}->{partion}->{$attrib}->@* == 3) {
          message( "..Found: Additional partioning"  , $data, __LINE__, 5, 0, 1 );
          genTags($data,$obj,$catch,$attrib);
        }
        else {
          message( "..not Found: Additional partioning", $data, __LINE__, 5, 0, 1 );
        }
      }
      else {
        message( "..not Found: ATTRIB", $data, __LINE__, 5, 0, 1);
      }
    }
    if ($flag) {
      $catch->{raw} = $raw;
    }
    unless ($catch->{$obj}) { delete $catch->{$obj} }
  }
  else {
    message( "..does not exists: PARTION", $data, __LINE__, 4, 0, 1 );
  }
  message("Exiting ADD_PARTION", $data, __LINE__, 4, 0, 1 );
  return 1;

}


#-----| genTags() -----{{{2
sub genTags {
  my $data   = shift @_;
  my $obj    = shift @_;
  my $catch  = shift @_;
  my $attrib = shift @_;
  my @delims = $data->{dspt}->{$obj}->{partion}->{$attrib}->[2][0];
  message( "Start GEN_TAGS", $data, __LINE__, 5, 0, 1 );
  for my $delim (@delims[1 .. $#delims]) { $catch->{$attrib} =~ s/$delim/$delims[0]/g;}

  $catch->{$attrib} =~ s/$delims[0](\w+)/$1/g;
  $catch->{$attrib} = [ split /\s*$delims[0]\s*/, $catch->{$attrib} ];
  message("Exiting GEN_TAGS", $data, __LINE__, 6, 0, 1 );
}


#----- Utilities -----{{{1
#-----| getPointStr() -----{{{2
sub getPointStr {
  my $data = shift @_;
  return $data->{point}->[0] ? join '.', $data->{point}->@* : 0;
}
#-----| getname() ----{{{2
sub getname {
  my $dspt = shift @_;
  my $obj  = shift @_;
  my $name = exists $dspt->{$obj}->{name} ? $dspt->{$obj}->{name} : $obj;
  return $name;
}


#-----| getObjFromName() ----{{{2
sub getObjFromName {
  my $dspt = shift @_;
  my $name = shift @_;
  if ( exists $dspt->{$name} ) { return $name }
  else {
    my @keys  = grep { exists $dspt->{$_}->{name} } keys $dspt->%*;
    if (scalar @keys) {
      my @match = grep { $dspt->{$_}->{name} eq $name } @keys;
      return $match[0];
    }
    else {
      return 0;
    }
  }
}


#-----| getOrder() ----{{{2
sub getOrder {
  my $dspt = shift @_;
  my $arg  = shift @_;
  my $obj  = getObjFromName( $dspt, $arg );
  return $obj ? $dspt->{$obj}->{order} : 'z';
}


#-----| get_Lvl_reff() -----{{{2
sub get_Lvl_reff {
  my $data = shift @_;
  return $data->{reff}->@*;
}


#-----| getObj() -----{{{2
sub getObj {
  my $dspt  = shift @_;
  my $point = shift @_;
  my $point_str = join '.', $point->@*;

  if ($point_str eq '') { return 'TOP' }

  else {
    my @match = grep { $dspt->{$_}->{order} =~ /^$point_str$/ } keys $dspt->%*;

    if    ( !$match[0] )        { return 0 }
    elsif ( scalar @match > 1 ) { die( "more than one objects have the point: \'${point_str}\', for ${0} at line: ".__LINE__ ) }
    else                        { return $match[0] }
  }
}


#-----| decho() -----{{{2
sub decho {
  my $var = shift @_;

  #----- Data::Dumper  -----{{{3
  use Data::Dumper;

  $Data::Dumper::Sortkeys = sub {
    my ( $hash ) = @_;
    return [
      sort {
        my $order_a = getOrder( $dspt, $a );
        my $order_b = getOrder( $dspt, $b );
        if ( $a eq 'LN' && $b eq 'raw' ) {
          1;
        }
        elsif ( $a eq 'raw' && $b eq 'LN' ) {
          0;
        }
        elsif ( $b eq 'raw' || $b eq 'LN' ) {
          0;
        }
        elsif ( $a eq 'raw' || $a eq 'LN' ) {
          1;
        }
        else {
          $order_a cmp $order_b;
        }
      } keys %$hash
    ];
  };

  $Data::Dumper::Indent = 2; #}}}

  my $output = Data::Dumper->Dump( [$var], ['reff'] );
  $output =~ s/\s*[\}][,;]*\s*(\n)/$1/g;
  $output =~ s/\s*[\]][,;]*\s*(\n)/$1/g;
  #$output =~ s/\s*[\]][,;]*\s*(\n)/$1/g;
  return $output;
}


#-----| message() -----{{{2
sub message {
  my $mes   = shift @_;
  my $data  = shift @_;
  my $line  = shift @_;
  my $cnt   = shift @_;

  my $start = shift @_;
  $start = $start ? 0 : 1;


  my $disable_LN = shift @_;
  my $line_mes = "";
  unless ( $disable_LN ) { $line_mes = " at line ${line}." }

  my $offset = shift @_;
  $offset = $offset ? $offset : 0;

  my $indent = "  ";
  my $lvl = scalar $data->{point}->@* ?  scalar $data->{point}->@* : 0;
  $indent = $indent x ( $cnt + $start + $lvl - $offset );
  print $indent . $mes . $line_mes . "\n";
}


#----- Checks -----{{{1
#-----| checkCapture() -----{{{2
sub checkCapture {
  print "checking CAPTURE\n";
  print "...ok\n";
}


#-----| checkDspt() -----{{{2
sub checkDspt {
  print "checking DSPT\n";
  print "...ok\n";
}


