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
my $dspt;
$Data::Dumper::Sortkeys = sub {
  my ($hash) = @_;
  return [
    sort {
      my $order_a = getOrder($dspt,$a);
      my $order_b = getOrder($dspt,$b);
      if ($a eq 'LN' && $b eq 'raw') {
        1;
      }
      elsif ($a eq 'raw' && $b eq 'LN') {
        0;
      }
      elsif ($b eq 'raw' || $b eq 'LN') {
        0;
      }
      elsif ($a eq 'raw' || $a eq 'LN') {
        1;
      }
      else {
        $order_a cmp $order_b;
      }
    } keys %$hash
  ];
};
$Data::Dumper::Indent = 2;

##Assumptions
# no backslashes in dspt key names
# all dspt key names are unique
# partions patterns are independent of order
# each child type only belongs to only one object type
# Cannot have key named "TOP" 

#----- FILEPATHS -----{{{1
my $fname_IN = '../tagCatalog.txt';
#my $fname_IN = '../masterbin.txt';

#----- REGEX CONFIG -----{{{1
$dspt = {
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
my $data = { capture_hash => $capture_hash, dspt => $dspt} ;
my $formated_hash = delegate($data);
#print Dumper($formated_hash);


#----- Subroutines -----{{{1
#-----| hash_delegate -----{{{2
sub delegate {
  print "start DELEGATE\n";
  my $data = shift @_;
  checkCapture($data->{capture_hash});
  checkDspt($data->{dspt});

  return leveler ($data);
}


#-----| getIndent -----{{{2
sub getIndent {
  my $data = shift @_;
  my $line = shift @_;
  my $log  = shift @_;
  my $cnt  = shift @_;
  $cnt = $cnt ? $cnt : 0;
  $log = $log ? 0 : 1;
  my $lvl = scalar $data->{point}->@*;
  if ($lvl) {return "    " x ($lvl+$log+$cnt)}
  else {return $log ? "    "."    "x$cnt: "". "    "x$cnt}
}


#-----| leveler -----{{{2
sub leveler {
  my $data = shift @_;
  unless ( exists $data->{point}  ) { $data->{point}  = [] }
  unless ( exists $data->{stack}  ) { $data->{stack}  = [] }
  unless ( exists $data->{result} ) { $data->{result} = {} }
  unless ( exists $data->{reff}   ) { $data->{reff}   = [ $data->{result} ] }
  #print getIndent($data, __LINE__, 1)."----------------------------------\n";
  print getIndent($data, __LINE__, 1)."start LEVELER at point: ".getPointStr($data)."\n";

  #----- Exists? -----
  my $obj = getObj( $data->@{'dspt', 'point'} );
  print getIndent($data, __LINE__)."checking for existance of obj at the given point\n";
  if ( !$obj ) {
    print getIndent($data, __LINE__)."...does not exists.\n";
    print getIndent($data, __LINE__)."Exiting LEVLER instance.\n";
    return;
  }
  print getIndent($data, __LINE__)."...exists: \'${obj}\'\n";

  #----- Sweep Obj -----
  my $lvl_reff;
  while ( $obj ) {
    print getIndent($data, __LINE__)."selecting Obj: \'${obj}\'\n";

    #----- lvl_reff? -----
    print getIndent($data, __LINE__)."checking status of lvl_reff\n";
    unless ( defined $lvl_reff ) {
      print getIndent($data, __LINE__)."...not defined!\n";
      $lvl_reff->@* = get_Lvl_reff($data);
      print getIndent($data, __LINE__)."seting lvl_reff to ".$lvl_reff."\n";
    }
    else {
      print getIndent($data, __LINE__)."...defined\n";
      print getIndent($data, __LINE__)."keeping lvl_reff as ".$lvl_reff."\n";
    }

    #----- Populate -----
    populate($data, $obj);

    #----- CHILDS? -----
    print getIndent($data, __LINE__)."Check for CHILDREN\n";
    print getIndent($data, __LINE__)."Descend current point: ". getPointStr($data) ." by 1 level\n";
    push $data->{point}->@*, 1;
    print getIndent($data, __LINE__, 1)."...new point at ". getPointStr($data) ."\n";
    leveler($data);
    print getIndent($data, __LINE__, 1)."Ascend current point: ". getPointStr($data) ." by 1 level\n";
    pop $data->{point}->@*, 1;
    print getIndent($data, __LINE__)."...new point at ". getPointStr($data) ."\n";
    print getIndent($data, __LINE__)."returing data_reff at ".$data->{reff}." to lvl_reff\n";
    $data->{reff}->@* = $lvl_reff->@*;
    print getIndent($data, __LINE__)."...data_reff is now ".$data->{reff}."\n";

    #----- SYBLINGS? -----
    print getIndent($data, __LINE__)."Check for SYBLINGS\n";
    if ( scalar $data->{point}->@* ) {
      print getIndent($data, __LINE__)."increase current point: ". getPointStr($data) ." by 1\n";
      $data->{point}->[-1]++;
      print getIndent($data, __LINE__)."...new point at ". getPointStr($data). "\n";
    }
    else {
      print getIndent($data, __LINE__)."can not increase current point " . getPointStr($data) . "\n";
      print getIndent($data, __LINE__)."Exiting LEVLER instance.\n";
      last;
    }
    $obj = getObj( $data->@{'dspt', 'point'} ); # set 'obj' to new 'obj' (next SYBLINGO)
    unless ($obj) {
      print getIndent($data, __LINE__)."no syblings exists at point found\n";
      print getIndent($data, __LINE__)."Exiting LEVLER instance.\n";
    }
    else {
      print getIndent($data, __LINE__)."sybling found\n";
    }
  }
  return $data->{result};
}

#-----| getPointStr -----{{{2
sub getPointStr {
  my $data = shift @_;
  return $data->{point}->[0] ? join '.', $data->{point}->@* : 0;
}
#-----| getname ----{{{2
sub getname {
  my $dspt = shift @_;
  my $obj  = shift @_;
  my $name = exists $dspt->{$obj}->{name} ? $dspt->{$obj}->{name} : $obj;
  return $name;
}


#-----| getObjFromName ----{{{2
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


#-----| getOrder ----{{{2
sub getOrder {
  my $dspt = shift @_;
  my $arg  = shift @_;
  my $obj  = getObjFromName( $dspt, $arg );
  return $obj ? $dspt->{$obj}->{order} : 'z';
}


#-----| get_Lvl_reff -----{{{2
sub get_Lvl_reff {
  my $data = shift @_;
  return $data->{reff}->@*;
}


#-----| addPartion() -----{{{2
sub addPartion {
  my $data  = shift @_;
  my $obj   = shift @_;
  my $catch = shift @_;
  my $raw = $catch->{$obj};
  my $flag;
  for my $attrib (keys $data->{dspt}->{$obj}->{partion}->%*) {
    $catch->{$obj} =~ s/$data->{dspt}->{$obj}->{partion}->{$attrib}->[0]//g;
    if ($1 && $1 ne '') {
      $flag = 1;
      $catch->{$attrib} = $1;
      if (scalar $data->{dspt}->{$obj}->{partion}->{$attrib}->@* == 3) {
        genTags($data,$obj,$catch,$attrib);
      }
    }
  }
  if ($flag) {
    $catch->{raw} = $raw;
  }
  unless ($catch->{$obj}) { delete $catch->{$obj} }
  return 1;

}


#-----| genTags() -----{{{2
sub genTags {
  my $data   = shift @_;
  my $obj    = shift @_;
  my $catch  = shift @_;
  my $attrib = shift @_;
  my @delims = $data->{dspt}->{$obj}->{partion}->{$attrib}->[2][0];
  for my $delim (@delims[1 .. $#delims]) { $catch->{$attrib} =~ s/$delim/$delims[0]/g;}

  $catch->{$attrib} =~ s/$delims[0](\w+)/$1/g;
  $catch->{$attrib} = [ split /\s*$delims[0]\s*/, $catch->{$attrib} ];
}


#-----| decho -----{{{2
sub decho {
  my $var = shift @_;
  my $output = Data::Dumper->Dump([$var], ['reff']);
  $output =~ s/\s*[\}][,;]*\s*(\n)/$1/g;
  $output =~ s/\s*[\]][,;]*\s*(\n)/$1/g;
  #$output =~ s/\s*[\]][,;]*\s*(\n)/$1/g;
  return $output;
}


#-----| divyMatches -----{{{2
sub divyMatches {
    my $data = shift @_;
    my $obj  = shift @_;
    my $name = getname( $data->{dspt}, $obj );
    my $pond = dclone( ${$data}{capture_hash}->{$obj} );

    #----- DIVY MATCHES -----
    if (1) {
    #if ( scalar ${$data}{point}->@* != 1 ) {
      my $ind = ( scalar ${$data}{reff}->@* ) - 1;
      for my $reff ( reverse ${$data}{reff}->@*) {
        my $bucket;
        for my $match ( reverse $pond->@* ) {
          if ( $match->{LN} > ( $reff->{LN} ?  $reff->{LN} : 0 ) ) {
            my $catch = pop $pond->@*;
            addPartion( $data, $obj, $catch );
            push $bucket->@*, $catch;
          }
          else {
            last;
          }
        }
        if ( $bucket ) {
          $bucket->@* = reverse $bucket->@*;

          ${$data}{reff}->[$ind]->{$name} = $bucket;
          splice( ${$data}{reff}->@*, $ind, 1, $bucket->@* );

        }
        $ind--;
      }
    }
    else {
      ${$data}{reff}->[0]->{$name} = $pond;
      splice( ${$data}{reff}->@*, 0, 1, $pond->@* );
    }
    return $name;
}


#-----| populate -----{{{2
sub populate {
  my $data = shift @_;
  my $obj  = shift @_;
  print getIndent($data, __LINE__)."start POPULATE\n";
  if ( $obj ne 'TOP' && exists $data->{capture_hash}->{$obj} ) {
    print getIndent($data,__LINE__,undef,1)."start DIVY_MATCHES\n";
    divyMatches( $data, $obj );
  }
  else {
    print getIndent($data,__LINE__,undef,1)."cannot populate for point ".getPointStr($data)."\n";
    print getIndent($data,__LINE__,undef,1)."Exiting POPULATE\n";
  }
}


#-----| getObj -----{{{2
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

#-----| file2hash -----{{{2
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


#----- checkCapture -----{{{2
sub checkCapture {
  print "checking CAPTURE\n";
  print "...ok\n";
}


#-----| checkDspt -----{{{2
sub checkDspt {
  print "checking DSPT\n";
  print "...ok\n";
}


