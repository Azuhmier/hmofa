#!/usr/bin/env perl
#============================================================
#
#         FILE: tags3.pl
#        USAGE: perl ./tags3.pl
#   DESCRIPTION: ---
#        AUTHOR: Azuhmier (aka taganon), azuhmier@gmail.com
#===========================================================
use strict;
use warnings;
use utf8;
#use JSON;
use JSON::PP;
use List::Util;
use Storable qw(dclone);
use Hash::Ordered;
#use Tie::Hash::MultiValueOrdered;
#use JSON::MultiValueOrdered;

#  Assumptions
#    - no backslashes in dspt key names
#    - all dspt key names are unique
#    - attribute patterns are independent of order
#    - each child type only belongs to only one object type
#    - Cannot have key named "TOP"
#    - all prior levels must have line numbers after the lowest line number of the
#      first level.




# DSPT Configuration {{{1
#------------------------------------------------------
my $dspt = {
    section => {
        name    => 'SECTIONS',
        order   => '1',
        re      => qr/^\s*%+\s*(.*?)\s*%+/,
        exclude => [ 'Introduction/Key', 'Stories from outside /hmofa/' ],
    },
    author => {
        name    => 'AUTHORS',
        order   => '1.1',
        re      => qr/^\s*[Bb]y\s+(.*)/,
        attributes => {
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
        attributes => {
            title_attribute => [ qr/\s+\((.*)\)/ ],
        },
    },
    tags => {
        name    => 'TAGS',
        order   => '1.1.1.1.1',
        re      => qr/^\s*(\[.*)/,
        scalar  => 1,
        attributes => {
            anthro  => [ qr/(?x) ^\[  ([^\[\]]*)/     , 1, [';',','] ],
            general => [ qr/(?x) \]\[ ([^\[\]]*) \]/  , 2, [';',','] ],
            ops     => [ qr/(?x) ([^\[\]]*) $/        , 3],
        },
    },
    url => {
        name    => 'URLS',
        order   => '1.1.1.1.2',
        re      => qr/^\s*(http.*)/,
        attributes => {
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




#------------------------------------------------------
# Main {{{1
#------------------------------------------------------
## filepaths
my $fnameIN  = '../tagCatalog.txt';
#my $fnameIN  = '../masterbin.txt';

## get matches from txt file
my $matches = file2hash($fnameIN);
test($matches);

## turn matches into data hash
my $data = {
    matches  => $matches,
    dspt     => $dspt,
    result   => {},
    verbose  => 1,
    lineNums => 1,
};
my $dataHash = delegate($data);
#print decho($data, $dataHash);

##  encode jsons
my $json_obj = JSON::PP->new->ascii->pretty->allow_nonref;
my $enable = $json_obj->get_convert_blessed;
$json_obj = $json_obj->allow_blessed(['true']);
#$json_obj = $json_obj->canonical(['true']);

$json_obj->sort_by( sub { 
    $JSON::PP::order_a = getOrder( $data, $JSON::PP::a);
    $JSON::PP::order_b = getOrder( $data, $JSON::PP::b);
    $JSON::PP::order_a cmp $JSON::PP::order_b;
  });
my $json  = $json_obj->encode($data->{result});

##  write jsons to file
my $filename = './jsons/hmofa.json';
open( my $fh_hmofaJson, '>' ,$filename ) or die $!;
    print $fh_hmofaJson $json;
    truncate $fh_hmofaJson, tell( $fh_hmofaJson ) or die;
close( $fh_hmofaJson );


#------------------------------------------------------
# Subroutines {{{1
#------------------------------------------------------
#===| file2hash() {{{2
sub file2hash {
    #
    my $fname = shift @_;
    my $output;

    #
    open( my $fh, '<', $fname )
        or die $!;

    #
    while (my $line = <$fh>) {

        #
        for my $objKey (keys %$dspt) {
            my $obj = $dspt->{$objKey};

            #
            if ($obj->{ re } and $line =~ /$obj->{re}/) {
                my $match = {
                    LN       => $.,
                    $objKey => $1,
                };
                push  $output->{$objKey}->@*, $match;
            }
        }
    }

    #
    close( $fh );
    return $output;
}


#===| delegate() {{{2
sub delegate {
    ## Args
    my $data = shift @_;
    mes("DELEGATE", $data, 0, 1, 1);

    ## checks
    init($data);

    ## convert
    my $DataHash = leveler( $data );
    mes("Returning DELEGATE", $data, 0, 1, 1);
    return $DataHash;
}


#===| leveler() {{{2
sub leveler {
    ## Args
    my $data = shift @_; 
    mes("LEVELER at (".getPointStr($data).")", $data, 0, 1, 1);

    ## check existance of OBJ at point 
    my $objKey = getObjKey( $data );
    mes("Checking for OBJ", $data, 0, 0, 1);
    unless ($objKey) {
        mes("..does not exist: OBJ", $data, 0, 0, 1);
        mes("Returning LEVLER", $data, 0, 0, 1);
        return;
    }
    mes("..exists OBJ: \'${objKey}\'", $data, 0, 0, 1);

    #
    my $levelReffArray;
    while ($objKey) {
        mes("==Selecting OBJ== \'${objKey}\'", $data, 0, 0, 1);

        ## Checking existance of levelReffArray
        mes("Checking for levelReffArray", $data, 0, 0, 1);
        unless (defined $levelReffArray) {
            mes("..not defined: 'levelReffArray'", $data, 0, 0, 1);
            $levelReffArray->@* = getLvlReffArray( $data );
            mes("..setting 'levelReffArray' to 'Data->{reffArray}'", $data, 0, 0, 1);
        }
        else { mes("..defined: 'levelReffArray'", $data, 0, 0, 1); }

        ## Populate
        populate( $data );

        ## Check for CHILDREN
        mes("Checking for CHILDREN", $data, 0, 0, 1);
        mes("..Descend point (".getPointStr($data).") by 1 level", $data, 0, 0, 1);
        changePointStrLvl($data->{point}, 1);
        mes("..new point: (".getPointStr($data).")", $data, 0, 0, 1, 1);
        leveler( $data );
        mes("..Ascend point (".getPointStr($data).") by 1 level", $data, 0, 0, 1, 1);
        changePointStrLvl($data->{point}, 0);
        mes("..new point: (".getPointStr($data).")", $data, 1, 0, 1, 1);
        mes("..Returning data_reffArray at to levelReffArray", $data, 0, 0, 1);
        $data->{reffArray}->@* = $levelReffArray->@*;

        ## Check for SYBLINGS
        mes("Checking for SYBLINGS", $data, 0, 0, 1);
        if (scalar $data->{point}->@*) {
            mes("..increase point (".getPointStr($data) .") by 1", $data, 0, 0, 1);
            $data->{point}->[-1]++;
            mes("..new point: (".getPointStr($data).")", $data, 0, 0, 1);
        }
        else {
            mes("..can not increase point (".getPointStr($data).")", $data, 0, 0, 1);
            mes("Returning LEVLER", $data, 0, 0, 1);
            last;
        }

        #
        $objKey = getObjKey( $data );
        unless ($objKey) {
            mes("..does not exist: SYBLING", $data, 0, 0, 1);
            mes("Returning LEVLER", $data, 0, 0, 1);
        }
        else { mes("..exists SYBLING: \'${objKey}\'", $data, 0, 0, 1); }
    }
    return $data->{result};
}

#===| populate() {{{2
sub populate {
    my $data    = shift @_;
    my $objKey = getObjKey( $data );
    mes("POPULATE for '${objKey}'", $data, 0, 0, 1);
    if ($objKey ne 'TOP' and exists $data->{matches}->{$objKey}) {
        divyMatches( $data );
    }
    else {
        mes("..cannot populate for '${objKey}'", $data, 1, 0, 1);
        mes("Returning POPULATE", $data, 1, 0, 1);
    }
}


#===| divyMatches() {{{2
sub divyMatches {

        #
        my $data    = shift @_;
        my $obj_key = getObjKey( $data );
        my $name    = getname( $data );
        my $pond    = dclone( ${$data}{matches}->{$obj_key} );
        mes("DIVY_MATCHES for '${obj_key}'", $data, 1, 0, 1);

        #
        my $ind = ( scalar ${$data}{reffArray}->@* ) - 1;
        mes("Begin reverse iteration through reffArray", $data, 2, 0, 1);
        for my $reff (reverse ${$data}{reffArray}->@*) {
            mes("==Selecting reffArray element== at index (${ind})", $data, 2, 0, 1);

            ## Check existance of line# at reff
            mes("Checking for line# at reff array element", $data, 3, 0, 1);
            my $reff_lineNum;
            if ($reff->{LN}) {
                $reff_lineNum = $reff->{LN};
                mes("..exists", $data, 3, 0, 1);
            }
            else {
                $reff_lineNum = 0;
                mes("..does not exists", $data, 3, 0, 1 );
                mes("..setting reff_lineNum to '${reff_lineNum}'", $data, 3, 0, 1 );
            }
            #
            my $bucket;
            mes("Begin reverse iteration through Capture_Array", $data, 3, 0, 1);
            for my $match (reverse $pond->@*) {
                mes("==Selecting capture_array element== at line# '".$match->{LN}."'", $data, 3, 0, 1);
                mes("checking if match_lineNum > reff_lineNum", $data, 4, 0, 1);
                if ($match->{LN} > $reff_lineNum) {
                    mes("..True", $data, 4, 0, 1 );
                    mes("..Will add capture_array element to bucket", $data, 4, 0, 1 );
                    my $match = pop $pond->@*;
                    $match->{point} = join '.', $data->{point}->@*; #for sorting
                    genAttributes( $data, $match );
                    mes("Adding capture_array element to bucket", $data, 4, 0, 1 );
                    push $bucket->@*, $match;
                }
                else {
                    mes("..False", $data, 4, 0, 1);
                    last;
                }
            }

            ## Check if bucket i
            mes("Finished iteration through Capture_Array", $data, 2, 0, 1);
            mes("Checking if bucket is empty",  $data, 2, 0, 1);
            if ($bucket) {
                $bucket->@* = reverse $bucket->@*;

                #
                ${$data}{reffArray}->[$ind]->{$name} = $bucket;
                mes("Replacing reffArray element with Capture_array slice", $data, 2, 0, 1);
                splice( ${$data}{reffArray}->@*, $ind, 1, $bucket->@* );

            }
            else { mes("Deincrementing reffArray index (${ind}) by 1", $data, 2, 0, 1) }
            mes("Deincrementing reffArray index (${ind}) by 1", $data, 2, 0, 1 );
            $ind--;
            mes("..new index at (${ind})", $data, 2, 0, 1 );
        }
        mes("Iteration through reffArray indices is complete", $data, 2, 0, 1);
        mes("Returning DIVY_MATCHES", $data, 2, 0, 1);
        return $name;
}


#===| genAttributes() {{{2
sub genAttributes {

    ## Object Reff
    my $data    = shift @_;
    my $objKey  = getObjKey( $data );
    my $objReff = $data->{dspt}->{$objKey};

    #Save UnAttributed Match
    my $match = shift @_;
    my $raw   = $match->{$objKey};

    #
    my $flag;
    mes("ADD_ATTRIBUTES", $data, 4, 0, 1);
    mes("==Using Match_Str== '$match->{$objKey}'", $data,  5, 0, 1);
    mes("Checking for attributes key", $data, 5, 0, 1);
    if (exists $objReff->{attributes}) {
        my $attributesDSPT = $objReff->{attributes};
        mes("..exists", $data, 5, 0, 1);
        mes("Begin attributes_hash iteration", $data, 5, 0, 1);

        ## Iterate through attributeDSPT
        my @attributesOrderArray = sort {
            ## essentially 'undef cmp undef' with some elements
            $attributesDSPT->{$a}->[1] cmp $attributesDSPT->{$b}->[1];
            } keys $attributesDSPT->%*;
        for my $attrib (@attributesOrderArray) {
        #for my $attrib (keys $attributesDSPT->%*) {
            mes("==Selecting ATTRIBUTE== '${attrib}'", $data, 6, 0, 1);
            mes("Searching for ATTRIBUTE match in '".$match->{ $objKey }."'", $data, 7, 0, 1);
            $match->{ $objKey } =~ s/$attributesDSPT->{ $attrib }->[ 0 ]//g;

            #
            if ($1 && $1 ne '') {
                $match->{$attrib} = $1;
                $flag = 1;
                mes("..Found: '" . $match->{$attrib} . "'", $data, 7, 0, 1);
                mes("Set 'STR_MODIFIED' flag", $data, 7, 0, 1 );
                mes("Removing ATTRIBUTE match from string", $data, 7, 0, 1);
                mes("..New Match_Str: '" . $match->{$objKey} . "'", $data, 7, 0, 1);
                mes("Checking for Additianol Partioning", $data, 7, 0, 1);

                #
                if (scalar $attributesDSPT->{ $attrib }->@* == 3) {
                    mes("..Found!", $data, 7, 0, 1);
                    delimitAttribute($data, $attrib, $match);
                }
                else { mes("..not Found!", $data, 7, 0, 1) }
            }
            else { mes("..not Found!", $data, 7, 0, 1) }
        }
        mes( "Check for 'STR_MODIFIED' flag", $data, 7, 0, 1);

        #
        if ( $flag ) {
                mes("..Exists", $data, 7, 0, 1);
                mes("Adding original str to RAW key of current reff_hash", $data, 7, 0, 1);
            $match->{raw} = $raw;
        }
        else { mes("..does not Exists", $data, 7, 0, 1); }

        #
        unless ($match->{ $objKey }) {
            mes("Deleting Empty Match_Str", $data, 6, 0, 1);
            delete $match->{ $objKey }
        }
    }
    else { mes("..does not exists", $data, 5, 0, 1); }
    mes("Returning ADD_attributes", $data, 5, 0, 1);
}


#===| delimitAttribute() {{{2
sub delimitAttribute {

    ## Attributes
    my $data           = shift @_;
    my $objKey         = getObjKey($data);
    my $attributesDSPT = $data->{dspt}->{$objKey}->{attributes};

    ## Regex for Attribute Delimiters
    my $attributeKey = shift @_;
    my $delims       = join '', $attributesDSPT->{$attributeKey}->[2][0];
    my $delimsRegex  = qr{\s*[\Q$delims\E]\s*};

    ## Split and Grep Attribute Match-
    mes("DELIMIT_ATTRIBUTE for attribute '${attributeKey}'", $data, 7, 0, 1);
    my $match = shift @_;
    $match->{$attributeKey} = [
        grep { $_ ne '' }
        split( /$delimsRegex/, $match->{$attributeKey} )
    ];
    mes("Returning GEN_TAGS", $data, 8, 0, 1);
}




#------------------------------------------------------
# Utilities {{{1
#------------------------------------------------------
#===| sortKeys() #{{{2
sub sortKeys {
  my $hash = shift @_;
  $data->{point} = [ split /\./, $hash->{point} ];
  return [ sort {
          my $order_a = getOrder( $data, $a);
          my $order_b = getOrder( $data, $b);
          $order_a cmp $order_b;
      } keys %$hash ];
}
#===| getPointStr() {{{2
sub getPointStr {
    my $data = shift @_;
    return ($data->{point}->[0]) ? join '.', $data->{point}->@*
                                 : 0;
}
#===| getname() {{{2
sub getname {
    my $data    = shift @_;
    my $dspt    = $data->{dspt};;
    my $obj_key = getObjKey( $data );
    my $name    = exists ($dspt->{$obj_key}->{name}) ? $dspt->{$obj_key}->{name}
                                                     : $obj_key;
    return $name;
}


#===| getObjKeyFromName() {{{2
sub getObjKeyFromName {
    my $data = shift @_;
    my $dspt = $data->{dspt};
    my $name = shift @_;
    if (exists $dspt->{$name}) { return $name }
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


#===| getOrder() {{{2
sub getOrder {
    ## pointStr
    my $data       = shift @_;
    my $keyName    = shift @_;
    my $objKey     = getObjKeyFromName( $data, $keyName );
    my $pointStr   = getPointStr( $data );
    my $parentKey  = getObjKey( $data );
    my $parentReff = $data->{dspt}->{$parentKey};
    ## Parent and Children

    if ($objKey) {
        my $objReff = $data->{dspt}->{$objKey};
        $pointStr   = $objReff->{order};
    }

    ## Attributes
    elsif (exists $parentReff->{attributes}->{$keyName}) {
        my $attributeReff = $parentReff->{attributes}->{$keyName};
        my $cnt;
        if (exists $attributeReff->[1]) {
            $cnt = $attributeReff->[1];
        }
        else {
            $cnt = 1;
        }
        for (my $i = 1; $i <= $cnt; $i++) { 
            $pointStr = changePointStrInd( $pointStr, 1 );
        }
    }
    else {
        if ($keyName eq 'raw')   {$pointStr = '5.1.1.1.1.1.1.1.1.1.1'}
        if ($keyName eq 'LN')    {$pointStr = '5.1.1.1.1.1.1.1.1.1.2'}
        if ($keyName eq 'point') {$pointStr = '5.1.1.1.1.1.1.1.1.1.3'}
    }
    return $pointStr;
}


#===| getLvlReffArray() {{{2
sub getLvlReffArray {
    my $data = shift @_;
    return $data->{reffArray}->@*;
}


#===| changePointStrLvl() {{{2
sub changePointStrLvl {
    my $point = shift @_;
    my $op    = shift @_;
    if ($op) { push $point->@*, 1 }
    else     { pop $point->@*, 1 }
    return $point;

}
#===| changePointStrInd() {{{2
sub changePointStrInd {
    my $pointStr = shift @_;
    my @point    = split /\./, $pointStr;
    my $op       = shift @_;
    if ($op) { $point[-1]++ }
    else     { $point[-1]-- }
    $pointStr = join '.', @point;
    return $pointStr;
}


#===| getObjKey() {{{2
sub getObjKey {
    my $data      = shift @_;
    my $dspt      = $data->{dspt};
    my $point     = $data->{point};
    my $point_str = join( '.', $point->@* );

    if ($point_str eq '') { return 'TOP' }

    else {
        my @match = grep { $dspt->{$_}->{order} =~ /^$point_str$/ } keys $dspt->%*;

        unless ($match[0])         { return 0 }
        elsif  (scalar @match > 1) { die("more than one objects have the point: \'${point_str}\', for ${0} at line: ".__LINE__) }
        else                       { return $match[0] }
    }
}


#===| decho() {{{2
sub decho {
    my $data = shift @_;
    my $var = shift @_;

    ## Data::Dumper
    use Data::Dumper;
    $Data::Dumper::Sortkeys = \&sortKeys;
    $Data::Dumper::Indent = 2;
    my $output = Data::Dumper->Dump( [$var], ['reffArray'] );
    return $output;
}


#===| mes() {{{2
sub mes {
    ##
    my $mes   = shift @_;
    my $data  = shift @_;
    my $cnt   = shift @_;

    ##
    my $start = shift @_;
    $start = $start ? 0 : 1;

    ##
    my $disable_LN = shift @_;

    ##
    my $offset = shift @_;
    $offset = $offset ? $offset : 0;

    ##
    my $indent = "  ";
    my $lvl = 0;
    if (exists $data->{point}) { 
        $lvl = (scalar $data->{point}->@*) ? scalar $data->{point}->@*
                                           : 0;
    }
    $indent = $indent x ($cnt + $start + $lvl - $offset);
    print $indent . $mes . "\n";
}




#------------------------------------------------------
# Checks {{{1
#------------------------------------------------------
#===| init() {{{2
sub init {
  my $data = shift @_;

  ## Argument Checks
  unless ($data->{matches}) { die("User did not provide 'matches' argument at ${0} at line: ".__LINE__) }
  checkMatches( $data );
  unless ($data->{dspt}) { die("User did not provide 'dspt' argument  at ${0} at line: ".__LINE__)}
  checkDspt( $data );

  ## Initiate variables
  unless (exists $data->{point}    ) { $data->{point}     = []                  }
      else {warn "WARNING!: 'point' is already defined by user at ${0} at line: ".__LINE__}
  unless (exists $data->{result}   ) { $data->{result}    = {}                  }
      else {warn "WARNING!: 'result' is already defined by user at ${0} at line: ".__LINE__}
  unless (exists $data->{reffArray}) { $data->{reffArray} = [ $data->{result} ] }
      else {warn "WARNING!: 'reffArray' is already defined by user at ${0} at line: ".__LINE__}
  unless (exists $data->{meta}     ) { $data->{meta}      = {}                  }
      else {warn "WARNING!: 'meta' is already defined by user at ${0} at line: ".__LINE__}

  ## options
  unless ($data->{verbose}) {}
  unless ($data->{lineNums}) {}

}
#===| checkMatches() {{{2
sub checkMatches {
    my $data = shift @_;
    my $matches = $data->{matches};
    mes("Starting CHECK_MATCHES", $data, 0, 1, 1);
    mes("...ok", $data, 0, 0, 1);
}


#===| checkDspt() {{{2
sub checkDspt {
    my $data = shift @_;
    my $dspt = $data->{dspt};
    my %hash = (
    );
    mes("Starting CHECK_DSPT", $data, 0, 1, 1);
    mes("...ok", $data, 0, 0, 1);
}


#===| test() {{{2
sub test {
    my $num = 2;
    my $matches = shift @_;
    $matches->{test} = [
        {
            LN => 76,
            test => 'MINNIE: HIGH VELOCITY COURTING '
        },
        {
            LN => 76,
            test => 'MINNIE: HIGH VELOCITY COURTING '
        },
    ];
    $matches->{test33} = [
        {
            LN => 76,
            test33 => 'MINNIE: HIGH VELOCITY COURTING '
        },
        {
            LN => 76,
            test33 => 'MINNIE: HIGH VELOCITY COURTING '
        },
    ];
    $matches->{test3} = [
        {
            LN => 76,
            test3 => 'MINNIE: HIGH VELOCITY COURTING '
        },
        {
            LN => 76,
            test3 => 'MINNIE: HIGH VELOCITY COURTING '
        },
    ];
    #for my $key ( keys $matches->%* ) {
    ##  if (exists $matches->{$key}->[$num] ) {
    ##    $matches->{$key}->@* = $matches->{$key}->@[0..$num];
    ##    #$matches->{$key}->@* = map { delete $_->{LN} } $matches->{$key}->@*;
    ##  }
    ##  else {
    ##    my @array = $matches->{$key}->@*;
    ##    $matches->{$key}->@* = $matches->{$key}->@[0..$#array];
    ##    #$matches->{$key}->@* = map { delete $_->{LN} } $matches->{$key}->@*;
    ##  }
    #}
    }
