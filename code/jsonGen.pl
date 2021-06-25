#!/usr/bin/env perl
#============================================================
#
#         FILE: jsonGen.pl
#        USAGE: ./jsonGen.pl
#   DESCRIPTION: ---
#        AUTHOR: Azuhmier (aka taganon), azuhmier@gmail.com
#       Created: sprig 2021
#===========================================================
use strict;
use warnings;
use utf8;
use Storable qw(dclone);
use JSON::PP;
use XML::Simple;
use YAML;
use lib ($ENV{HOME} . '/hmofa/hmofa/code/lib/');
    use Hmofa::Hash;

#  Assumptions
#    - all first level dspt keys and their group names are unique


# MAIN {{{1
#------------------------------------------------------
{
    my $opts = genOpts({ sort => 1, write => 0, divy => [1,1], attribs => [0], verbose =>1});

    # ===| tagCatalog {{{2
    delegate({
        name => 'catalog',
        opts => $opts,
        fileNames => {
            fname  => '../tagCatalog.txt',
            output => './json/catalog.json',
            dspt   => './json/deimos.json',
        },
    });


    # ===| masterbin {{{2
    delegate({
        name => 'masterbin',
        opts => $opts,
        fileNames => {
            fname  => '../masterbin.txt',
            output => './json/masterbin.json',
            dspt   => './json/deimos.json',
        },
    });
}


# PUBLIC {{{1
#------------------------------------------------------
#===| genOpts() {{{2
sub genOpts {
    my $ARGS = shift @_;
    my $defaults = {

        ## Processes
        divy     => 1,
        attribs  => 1,
        delims   => 1,
        write    => 1,

        ## STDOUT
        verbose  => 0,
        display  => 0,
        lineNums => 0,

        ## MISC
        sort     => 1,
    };
    $defaults->{$_} = $ARGS->{$_}  for keys %{$ARGS};
    return $defaults;
}


#===| getMatches() {{{2
sub getMatches {

    ##
    my $data = shift @_;
    my $fname = $data->{fileNames}->{fname};
    my $dspt  = $data->{dspt};
    my $output;

    ##
    open( my $fh, '<', $fname )
        or die $!;

    ##
    while (my $line = <$fh>) {

        ##
        my $flag;
        for my $objKey (keys %$dspt) {
            my $obj = $dspt->{$objKey};

            ##
            if ($obj->{re} and $line =~ /$obj->{re}/) {
                my $match = {
                    LN      => $.,
                    $objKey => $1,
                };
                push  $output->{$objKey}->@*, $match;
                $flag=1;
            }
        }
        unless ($flag) {
            my $match = {
                LN      => $.,
                miss => $line,
            };
            push  $output->{miss}->@*, $match;
        }
    }

    ##
    close( $fh );
    $data->{matches} = $output;
}


#===| leveler() {{{2
# iterates in 2 dimensions the order of the dspt
sub leveler {

    my $data = shift @_;
    my $sub  = shift @_;

    ## check existance of OBJ at current point
    my $objKey = getObj( $data );
    unless ($objKey) { return }
    mes("LEVELER ".getPointStr($data), $data, -1);

    ## Reverence Arrary for the current recursion
    my $recursionReffArray;
    while ($objKey) {
        mes("------------", $data);
        mes("OBJ: ${objKey}", $data);

        ## Checking existance of recursionReffArray
        unless (defined $recursionReffArray) { $recursionReffArray->@* = $data->{reffArray}->@* }

        ## checkMatches
        $sub->( $data );

        ## Check for CHILDREN
        changePointLvl($data->{point}, 1);
        leveler( $data, $sub);
        changePointLvl($data->{point});
        $data->{reffArray}->@* = $recursionReffArray->@*;

        ## Check for SYBLINGS
        if (scalar $data->{point}->@*) {
            $data->{point}->[-1]++;
        } else { last }

        $objKey = getObj( $data );
    }
    return $data->{result};
}


#===| checkMatches() {{{2
sub checkMatches {

    my $data    = shift @_;
    my $objKey = getObj( $data );

    if (exists $data->{matches}->{$objKey}) {
        divyMatches( $data );
    }
}


#===| encodeResult() {{{2
sub encodeResult {

    my $data  = shift @_;
    if  ($data->{opts}->{write}) {
        my $fname = $data->{fileNames}->{output};
        {
            my $json_obj = JSON::PP->new->ascii->pretty->allow_nonref;
            $json_obj = $json_obj->allow_blessed(['true']);
            if ($data->{opts}->{sort}) {
              $json_obj->sort_by( sub { cmpKeys( $data, $JSON::PP::a, $JSON::PP::b, $_[0] ); } );
            }
            my $json  = $json_obj->encode($data->{result});
            open( my $fh, '>' ,$fname ) or die $!;
                print $fh $json;
                truncate $fh, tell( $fh ) or die;
            close( $fh );
        }
    }
}


# PRIVATE {{{1
#------------------------------------------------------
#===| init() {{{2
sub init {

  my $data = shift @_;

  # ---|| properties |---{{{3
  unless (exists $data->{point})     { $data->{point}     = [1] }
      else {warn "WARNING!: 'point' is already defined by user!"}
  unless (exists $data->{result})    { $data->{result}    = {libName => $data->{name}} }
      else {warn "WARNING!: 'result' is already defined by user!"}
  unless (exists $data->{reffArray}) { $data->{reffArray} = [$data->{result}] }
      else {warn "WARNING!: 'reffArray' is already defined by user!"}
  unless (exists $data->{meta})      { $data->{meta}      = {} }
      else {warn "WARNING!: 'meta' is already defined by user!"}
  genReservedKeys($data);

  # ---|| filenames |---{{{3
  unless ($data->{fileNames}->{dspt})   {die "User did not provide filename for 'dspt'!"}
      genDspt($data);
      validate_Dspt($data);
  unless ($data->{fileNames}->{fname})  {die "User did not provide filename for 'fname'!"}
  unless ($data->{fileNames}->{output}) {die "User did not provide filename for 'output'!"}
  #}}}
}
#===| divyMatches() {{{2
sub divyMatches {

    my $data = shift @_;
    my $obj_key = getObj( $data );

    if ($data->{opts}->{divy}->[0]) {
        my $pond      = dclone(${$data}{matches}->{$obj_key});
        my $groupName = getGroupName($data, $obj_key);

        my $ind = ( scalar ${$data}{reffArray}->@* ) - 1;
        for my $reff (reverse ${$data}{reffArray}->@*) {
            my $lvlObj  = getLvlObj($data,$reff);
            my $lvlItem = $reff->{getLvlObj($data,$reff)};

            ## Check existance of line# at reff
            my $reff_lineNum;
            if ($reff->{LN}) { $reff_lineNum = $reff->{LN} }
            else             { $reff_lineNum = 0 }

            ## Debug
            mes("IDX-$ind $obj_key -> $lvlObj", $data, 1)
                if $data->{opts}->{divy}->[1] and $data->{opts}->{divy}->[1] == 1;
            mes("[$reff_lineNum] <".$lvlObj."> ".$lvlItem, $data, 4)
                if $data->{opts}->{divy}->[1] and $data->{opts}->{divy}->[1] == 1;

            my $bucket;
            my $flag=0;
            for my $match (reverse $pond->@*) {
                if ($match->{LN} > $reff_lineNum) {
                    my $match = pop $pond->@*;

                    ## debug
                    unless ($data->{opts}->{divy}->[1]) {
                        mes("IDX-$ind $lvlObj -> $obj_key", $data, 1)
                            if !$flag;
                    }
                    unless ($data->{opts}->{divy}->[1]) {
                        mes("[$reff_lineNum] <".$lvlObj."> ".$lvlItem, $data, 4)
                            if !$flag
                    }
                    mes("($match->{LN}) <$obj_key> $match->{$obj_key}", $data, 4);

                    ## Attrbutes
                    genAttributes( $data, $match );
                    push $bucket->@*, $match;

                } else {
                    last;
                }
                $flag++;
            }

            ## Check if bucket is empty
            if ($bucket) {
                $bucket->@* = reverse $bucket->@*;
                ${$data}{reffArray}->[$ind]->{$groupName} = $bucket;
                my $ref = ${$data}{reffArray}->[$ind];
                splice( ${$data}{reffArray}->@*, $ind, 1, ($ref, $bucket->@*) );
            }
            $ind--;
        }
        return $groupName;
    }
}


#===| genAttributes() {{{2
sub genAttributes {

    ## Object Reff
    my $data    = shift @_;
    my $objKey  = getObj( $data );
    my $objReff = $data->{dspt}->{$objKey};
    if ($data->{opts}->{attribs}->[0]) {

        #Save UnAttributed Match
        my $match = shift @_;
        my $raw   = $match->{$objKey};

        #
        my $flag;
        mes("ADD_ATTRIBUTES", $data);
        mes("==Using Match_Str== '$match->{$objKey}'", $data);
        mes("Checking for attributes key", $data);
        if (exists $objReff->{attributes}) {
            my $attributesDSPT = $objReff->{attributes};
            mes("..exists", $data);
            mes("Begin attributes_hash iteration", $data);

            ## Iterate through attributeDSPT
            my @attributesOrderArray = sort {
                ## essentially 'undef cmp undef' with some elements
                $attributesDSPT->{$a}->[1] cmp $attributesDSPT->{$b}->[1];
                } keys $attributesDSPT->%*;
            for my $attrib (@attributesOrderArray) {
                mes("==Selecting ATTRIBUTE== '${attrib}'", $data);
                mes("Searching for ATTRIBUTE match in '".$match->{$objKey}."'", $data);
                $match->{ $objKey } =~ s/$attributesDSPT->{$attrib}->[0]//;

                #
                if ($1 && $1 ne '') {
                    $match->{$attrib} = $1;
                    $flag = 1;
                    mes("..Found: '" . $match->{$attrib} . "'", $data);
                    mes("Set 'STR_MODIFIED' flag", $data);
                    mes("Removing ATTRIBUTE match from string", $data);
                    mes("..New Match_Str: '" . $match->{$objKey} . "'", $data);
                    mes("Checking for Additianol Partioning", $data);

                    #
                    if (scalar $attributesDSPT->{ $attrib }->@* == 3) {
                        mes("..Found!", $data);
                        delimitAttribute($data, $attrib, $match);
                    }
                    else { mes("..not Found!", $data) }
                }
                else { mes("..not Found!", $data) }
            }
            mes( "Check for 'STR_MODIFIED' flag", $data);

            #
            if ( $flag ) {
                    mes("..Exists", $data);
                    mes("Adding original str to RAW key of current reff_hash", $data);
                $match->{raw} = $raw;
            }
            else { mes("..does not Exists", $data); }

            #
            unless ($match->{$objKey}) {
              #mes("Deleting Empty Match_Str", $data, 6, 0, 1);
              #delete $match->{ $objKey }
              mes("populating Empty Match_Str", $data);
              $match->{$objKey} = [];
              for my $attrib (@attributesOrderArray) {
                  if (exists $match->{$attrib}) {
                      push $match->{$objKey}->@*, $match->{$attrib}->@*;
                  }
              }
            }
        }
        else { mes("..does not exists", $data); }
        mes("Returning ADD_attributes", $data);
    }
}


#===| delimitAttribute() {{{2
sub delimitAttribute {

    ## Attributes
    my $data           = shift @_;
    my $objKey         = getObj($data);
    my $attributesDSPT = $data->{dspt}->{$objKey}->{attributes};

    ## Regex for Attribute Delimiters
    my $attributeKey = shift @_;
    my $delims       = join '', $attributesDSPT->{$attributeKey}->[2][0];
    my $delimsRegex  = ($delims ne '') ? qr{\s*[\Q$delims\E]\s*}
                                       : '';

    ## Split and Grep Attribute Match-
    mes("DELIMIT_ATTRIBUTE for attribute '${attributeKey}'", $data);
    my $match = shift @_;
    $match->{$attributeKey} = [
        grep { $_ ne '' }
        split( /$delimsRegex/, $match->{$attributeKey} )
    ];
    mes("Returning GEN_TAGS", $data);
}


#===| validate_Matches() {{{2
sub validate_Matches {

    my $data = shift @_;
    my $matches = $data->{matches};
    #unless ($data->{matches}) { die("User did not provide 'matches' argument at ${0} at line: ".__LINE__) }
}


#===| gendspt {{{2
sub genDspt {

    my $data = shift @_;
    my $dspt = do {
        open my $fh, '<', $data->{fileNames}->{dspt};
        local $/;
        decode_json(<$fh>);
    };

    ## Generate Regex's
    for my $obj (keys $dspt->%*) {

        my %objHash = %{ $dspt->{$obj} };
        for my $key (keys %objHash) {
            if ($key eq 're') { $objHash{re} = qr/$objHash{re}/ }
            if ($key eq 'attributes') {

                my %attribHash = %{ $objHash{attributes} };
                for my $attrib (keys %attribHash) {
                    $attribHash{$attrib}->[0] = qr/$attribHash{$attrib}->[0]/;
                }
            }
        }
    }
    $data->{dspt} = $dspt;
}


#===| delegate() {{{2
sub delegate {

    my $data = shift @_;

    ## checks
    init($data);

    ## matches
    getMatches($data);
    validate_Matches($data);

    ## convert
    leveler($data,\&checkMatches);

    ## encode
    encodeResult($data);
    if ($data->{opts}->{display}) { print decho($data, $data->{result}) };
    return $data;
}


# NOTES {{{1
#------------------------------------------------------
# OBJ: Hash
# PROPERTIES:
#    UID
#    dspt
#    contents
#    point
#    reff
# PUBLIC:
#    init()
#    decode()
#    encode()
# PRIVATE:
#    genUID()
# INHERITANCE: Controller

# OBJ: Json Generation Agent
# PROPERTIES:
#    HASH
# PUBLIC:
#    init()
#    delegate()
#    getMatches()
#    leveler()
# PRIVATE:
#    divy()
#    genAttribs()
# INHERITANCE: Controller

# OBJ: Controller
# PROPERTIES:
#    HASH
#    meta
#    options
#    -   processes
# PUBLIC:
#    init()
#    delegate()
#    getOptions()
#    getMeta()
# PRIVATE:
#    genMeta()
#    setOptions()
# UTILITIES {{{1
#------------------------------------------------------
# SHARED {{{1
#------------------------------------------------------
#===| getParent() {{{2
sub getParent {
    my $data = shift @_;
    my $dspt = $data->{dspt};
    my $PointStr = join '.', $data->{point}->@[0 .. $data->{point}->$#* - 1 ];
    my @matches  = grep {$dspt->{$_}->{order} eq $PointStr } keys %{$dspt};
    return $matches[0];
}

#===| genReservedKeys() {{{2
sub genReservedKeys {

    my $data = shift @_;
    my $ARGS = shift @_;
    my $defaults = {
        raw      => [ 'raw',     1 ],
        trash    => [ 'trash',   2 ],
        LN       => [ 'LN',      3 ],
        miss     => [ 'miss',    4 ],
        libName  => [ 'libName', 5 ],
    };
    $defaults->{$_} = $ARGS->{$_}  for keys %{$ARGS};

    ## check for duplicates: keys
    my @keys  = sort map  {$defaults->{$_}->[0]} keys %{$defaults};
    my %DupesKeys;
    for (@keys) { die "Cannot have duplicate reserved keys!" if $DupesKeys{$_}++ }

    ## check for duplicates: order numbers
    my @order = sort map {$defaults->{$_}->[1]} keys %{$defaults};
    my %DupesOrderNum;
    for (@order) { die "Reserved keys cannot have identical orders!" if $DupesOrderNum{$_}++ }

    $data->{reservedKeys} = $defaults;
}


#===| isReservedKey() {{{2
sub isReservedKey {
    my ($data, $key)  = @_;
    my $resvKeys      = $data->{reservedKeys};

    my @matches  = grep { $key eq $resvKeys->{$_}->[0] } keys %{$resvKeys};

    return $matches[0] ? 1 : 0;
}


#===| validate_Dspt() {{{2
sub validate_Dspt {

    my $data = shift @_;
    my $dspt = $data->{dspt};
    my %hash = (
    );

    $dspt->{libName} = {
        order => 0,
        groupName => 'LIBS',
    };

    ## check for duplicates: order
    my @keys  = sort map { $dspt->{$_}->{order} } keys %{$dspt};
    my %DupesKeys;
    for (@keys) { die "Cannot have duplicate reserved keys!" if $DupesKeys{$_}++ }

    ## check for use of gaps

}


#===| getJson() {{{2
sub getJson {
    my $fname = shift @_;
    my $hash = do {
        open my $fh, '<', $fname;
        local $/;
        decode_json(<$fh>);
    };
    return $hash
}


#===| filter() {{{2
sub genFilter {
    my $ARGS    = shift @_;
    my $dspt    = $ARGS->{dspt};
    my $obj     = $ARGS->{obj};
    my $pattern = $ARGS->{pattern};

    return sub {
        my $raw = shift @_;
        if ($raw =~ $pattern) {
            return ($dspt->{$1}) ? $dspt->{$1} : $raw;
        }
        else { return $raw }
    };
}


#===| getObj() {{{2
sub getObj {
    # return OBJECT_KEY at current point
    # return '0' if CURRENT_POINT doesn't exist!
    # return '0' if OBJECT_KEY doesn't exist for CURRENT_POINT!

    my $data      = shift @_;
    my $dspt      = $data->{dspt};
    my $point     = $data->{point};
    my $pointStr  = join( '.', $point->@* );

    if ($pointStr eq '') { die("pointStr cannot be an empty string! In ${0} at line: ".__LINE__) }
    else {
        my @match = grep { $dspt->{$_}->{order} =~ /^$pointStr$/ } keys $dspt->%*;

        unless ($match[0])         { return 0 }
        elsif  (scalar @match > 1) { die("more than one objects have the point: \'${pointStr}\'! In ${0} at line: ".__LINE__) }
        else                       { return $match[0] }
    }

}


#===| getObjFromUniqeKey() {{{2
sub getObjFromUniqeKey {
  my $data = shift @_;
  my $key  = shift @_;

  if    (exists $data->{dspt}->{$key})        { return $data->{dspt}->{$key}->{order} }
  elsif (getObjFromGroupNameKey($data, $key)) { return $data->{dspt}->{getObjFromGroupNameKey($data, $key)}->{order} }
  else                                        { return 0 }
}


#===| getObjFromGroupNameKey() {{{2
sub getObjFromGroupNameKey {
    # return GROUP_NAME if it is an OBJECT_KEY
    # return OBJECT_KEY that contains GROUP_NAME
    # return '0' if no OBJECT_KEY contains a GROUP_NAME!
    # return '0' if no OBJECTY_KEY contains GROUP_NAME!

    my $data      = shift @_;
    my $dspt      = $data->{dspt};
    my $groupName = shift @_;

    my @keys  = grep { exists $dspt->{$_}->{groupName} } keys $dspt->%*;
    if (scalar @keys) {
        my @match = grep { $dspt->{$_}->{groupName} eq $groupName } @keys;
        if ($match[0]) { return $match[0] }
        else { return 0 }
    }
    else { return 0 }
}


#===| getLvlObj {{{2
sub getLvlObj {
    my $data = shift @_;
    my $hash = shift @_;
    if (ref $hash eq 'HASH') {
        for (keys $hash->%*) {
             if ( exists $data->{dspt}->{$_} ) {return $_}
        }
    }
}


#===| getGroupName() {{{2
sub getGroupName {
    # return GROUP_NAME at current point.
    # return 'getObj()' if GROUP_NAME doesn't exist!

    my $data      = shift @_;
    my $obj      = shift @_;
    my $dspt      = $data->{dspt};
    if ($obj) {
        my $groupName = exists ($dspt->{$obj}->{groupName}) ? $dspt->{$obj}->{groupName}
                                                            : $obj;
        unless ($groupName) { die("groupName was returned empty or '0'! In ${0} at line: ".__LINE__) }
        return $groupName;
    }
    else { return 0 }

}


#===| getPointStr() {{{2
sub getPointStr {
    # return CURRENT POINT
    # return '0' if poinStr is an empty string!

    my $data = shift @_;
    my $pointStr = join('.', $data->{point}->@*);
    return ($pointStr ne '') ? $pointStr
                             : 0;
}


#===| genPointStrForRedundantKey() {{{2
sub genPointStrForRedundantKey {
    # return 'pointStr' if 'key' is an 'objKey'
    # die if 'pointStr' is '0' or doesn't exist!
    # return '0' if 'objKey' doesn't exist!

    my $data   = shift @_;
    my $key    = shift @_;
    my $hash   = shift @_; # single level hash, only needed for Attributes
                           # and Reserved Keys

    ## Set 'data->{point}'
    my $lvlObj =  getLvlObj($data, $hash);
    $data->{point} = [split /\./, $data->{dspt}->{$lvlObj}->{order}];

    my $pointStr     = getPointStr($data);
    my $hashObjKey   = getObj($data);
    my $hashDsptReff = $data->{dspt}->{$hashObjKey};

    ## ATTRIBUTES
    if (exists $hashDsptReff->{attributes}->{$key}) {

        my $attributeDsptReff = $hashDsptReff->{attributes}->{$key};
        my $cnt;

        if (exists $attributeDsptReff->[1]) { $cnt = $attributeDsptReff->[1] }
        else                                { $cnt = 1 }

        for (my $i = 1; $i <= $cnt; $i++)   { $pointStr = changePointStrInd($pointStr, 1) }

        unless ($pointStr) { die("pointStr (${pointStr}) doesn't exisst or is equal to '0'! In ${0} at line: ".__LINE__) }
        return $pointStr;
    }

    ## RESERVED KEYS
    #elsif (isReservedKey($key)) {
    elsif (1) {
        if ($key eq 'raw')   { $pointStr = '5.1.1.1.1.1.1.1.1.1.1' }
        if ($key eq 'LN')    { $pointStr = '5.1.1.1.1.1.1.1.1.1.2' }
        if ($key eq 'point') { $pointStr = '5.1.1.1.1.1.1.1.1.1.3' }
        if ($key eq 'libName')   { $pointStr = '5.1.1.1.1.1.1.1.1.1.4' }
        unless ($pointStr)   { die("pointStr (${pointStr}) doesn't exisst or is equal to '0'! In ${0} at line: ".__LINE__) }
        return $pointStr;
    }

    ## INVALID KEY
    else {}
}


#===| changePointLvl() {{{2
sub changePointLvl {

    my $point = shift @_;
    my $op    = shift @_;

    if ($op) { push $point->@*, 1 }
    else     { pop $point->@*, 1 }

    return $point;

}


#===| changePointStrInd() {{{2
sub changePointStrInd {

    my $pointStr = ($_[0] ne '') ? $_[0]
                                 : { die("pointStr cannot be an empty str! In ${0} at line: ".__LINE__) };
    my @point    = split /\./, $pointStr;
    my $op       = $_[1];

    if ($op) { $point[-1]++ }
    else     { $point[-1]-- }

    $pointStr = join '.', @point;
    return $pointStr;
}


#===| cmpKeys() {{{2
sub cmpKeys {
  my $data  = shift @_;
  my $key_a = shift @_;
  my $key_b = shift @_;
  my $hash  = shift @_;

  my $pointStr_a = getObjFromUniqeKey($data, $key_a);
  my $pointStr_b = getObjFromUniqeKey($data, $key_b);

  unless ($pointStr_a) { $pointStr_a = genPointStrForRedundantKey( $data, $key_a, $hash) }
  unless ($pointStr_b) { $pointStr_b = genPointStrForRedundantKey( $data, $key_b, $hash) }

  return $pointStr_a cmp $pointStr_b;
}


#===| decho() {{{2
sub decho {

    my $data = shift @_;
    my $var = shift @_;

    ## Data::Dumper
    use Data::Dumper;
    $Data::Dumper::Indent = 2;
    $Data::Dumper::Sortkeys = ( sub {
        my $hash = shift @_;
        return [ sort {
                my $order_a = genPointStrForRedundantKey( $data, $a, $_[0]);
                my $order_b = genPointStrForRedundantKey( $data, $b, $_[0]);
                $order_a cmp $order_b;
            } keys %$hash ];
        });

    ##
    my $output = Data::Dumper->Dump( [$var], ['reffArray'] );
    return $output;
}


#===| mes() {{{2
sub mes {

    my $mes   = shift @_;
    my $data  = shift @_;

    if ($data->{opts}->{verbose}) {
        my $cnt  = shift @_;
        my $indent = "    ";
        if ($cnt) { $indent = $indent x (1 + $cnt) }
        print $indent . $mes . "\n";
    }
}


