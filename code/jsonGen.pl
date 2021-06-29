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
use Data::Walk;

#  Assumptions
#    - all first level dspt keys and their group names are unique
# -


# MAIN {{{1
#------------------------------------------------------
{
    my $opts = genOpts({
        sort    => 1,
        write   => 1,
        divy    => [1,1],
        attribs => [1,1],
        verbose => 1,
        display => 0,
    });

    ## tagCatalog
    my $data1 = delegate({
        opts => $opts,
        name => 'catalog',
        preserve => { section => ['Introduction/Key'] },
        fileNames => {
            fname  => '../tagCatalog.txt',
            output => './json/catalog.json',
            dspt   => './json/deimos.json',
        },
    });


    ## masterbin
    my $data2 = delegate({
        opts => $opts,
        name => 'masterbin',
        fileNames => {
            fname  => '../masterbin.txt',
            output => './json/masterbin.json',
            dspt   => './json/deimos.json',
        },
    });
    genWriteArray($data1);
}


# PUBLIC {{{1
#------------------------------------------------------

#===| genWriteArray(){{{2
sub genWriteArray {
    my $data   = shift;
    my $result = dclone($data->{result});
    my $dspt   = $data->{dspt};
    $data->{seen} = {};

    # %dresser {{{
    my %dresser = (
        title   => {
            title           => ["\n>"],
            title_attribute => [' (',')'],
        },
        author  => {
          author           => ["\n------------------------------------------------------------------------------------------------------------------------------\nBy "],
          author_attribute => [' (',')'],
        },
        series  => {
            series => ["\n=====", '====='],
        },
        section => {
            section => [
                "\n------------------------------------------------------------------------------------------------------------------------------\n---------------------------------------------------%",
                "%--------------------------------------------------\n------------------------------------------------------------------------------------------------------------------------------",
            ],
        },
        tags => {
            anthro  => ['[', ']', ';', ';', ' '],
            general => ['[', ']', ';', ';', ' '],
            ops => [],
        },
        url => {
            url           => [],
            url_attribute => [' (',')'],
        },
        description => {
            description => ['#'],
        },
    ); #}}}
    ## APPEND DSPT {{{
    for my $obj (keys %$dspt) {
        my $objReff   = $dspt->{$obj};
        my $dressReff = $dresser{$obj};
        $objReff->{dress} = $dressReff;
    }
    #}}}
    # $preprocess {{{
    my $preprocess = sub {
        my @children = @_;
        my $type     = $Data::Walk::type;

        if ($type eq 'HASH') {
            my $container; my $cnt = 0; for my $part (@children) {
                if ($cnt & 1) { $container->{ $children[$cnt - 1] } = $part }
                $cnt++;
            }
            undef @children;
            for my $key ( sort {cmpKeys($data, $a, $b, $container) } keys %{$container}) {
                push @children, ($key, $container->{$key});
            }
            return @children;
        } else {
            return @children;
        }

    }; #}}}
    # $wanted {{{
    my $wanted = sub {
        my $type      = $Data::Walk::type;
        my $index     = $Data::Walk::index;
        my $container = $Data::Walk::container;
        if ($type eq 'HASH') {
            my $obj    = getLvlObj($data,$container);
            my $dspt   = $data->{dspt};
            my $objRef = $dspt->{$obj};
            my $item   = $container->{$obj};
            my $dressRef = $objRef->{dress};
            my $arrayFlag;
            unless ($data->{seen}->{$item}++) {
                #mes("$obj $item",$data);
                if (ref $item ne 'ARRAY') {
                    $item  =  $dressRef->{$obj}->[0].$item if $dressRef->{$obj}->[0];
                    $item .=  $dressRef->{$obj}->[1]       if $dressRef->{$obj}->[1];
                } else { $arrayFlag = 1 }
                my $attrRefs = getAttrReffs($data, $obj);
                my $attrArray;
                if ($attrRefs) {
                    my $attrType = ($objRef->{partion}) ? 'partion' : 'append';
                    #mes("    Attrs: ".$attrRefs,$data);
                    #mes(" AttrType: ".$attrType,$data);
                    for my $key (sort {$attrRefs->{$a}->[1] cmp $attrRefs->{$b}->[1]} keys %$attrRefs) {
                        my $attrItem = $container->{$key};
                        if ($attrItem) {
                            if ($arrayFlag) {
                                my @array;
                                for my $part (@$attrItem) {
                                    $part  =  $dressRef->{$key}->[2].$part if $dressRef->{$key}->[2];
                                    $part .=  $dressRef->{$key}->[3] if $dressRef->{$key}->[3];
                                    push @array, $part;
                                }
                                if ($dressRef->{$key}->[4]) {
                                    $attrItem = join $dressRef->{$key}->[4], @array;
                                } else {
                                    $attrItem = join '', @array;
                                }
                            }
                            $attrItem  =  $dressRef->{$key}->[0].$attrItem if $dressRef->{$key}->[0];
                            $attrItem .=  $dressRef->{$key}->[1] if $dressRef->{$key}->[1];
                            #mes("$key $attrItem",$data);
                            push @$attrArray, $attrItem;

                        }
                    }
                }
                my $str = $arrayFlag ? join '', @$attrArray
                                     : $attrArray ? $item . join '', @$attrArray
                                                  : $item;
                #mes("   STRING: ".$str ,$data);
                mes($str ,$data,-1);
            }
        }
    }; #}}}

    walkdepth { wanted => $wanted, preprocess => $preprocess},  $result;
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

    ## ===|| output {{{
    if ($data->{opts}->{display}) { print decho($data->{result}, 0) };
    {
        ## Matches Meta
        my $matches_Meta = $data->{meta}->{matches};
        my $max = length longest(keys $matches_Meta->%*);

        ## Verbose
        print "\nSummary: $data->{name}\n";
        for my $obj (sort keys $matches_Meta->%*) {
            printf "%${max}s: %s\n", ($obj, $matches_Meta->{$obj}->{count});
        }

        ## Subs
        sub longest {
            my $max = -1;
            my $max_ref;
            for (@_) {
                if (length > $max) {  # no temp variable, length() twice is faster
                    $max = length;
                    $max_ref = \$_;   # avoid any copying
                }
            }
            $$max_ref
        }
    }
    #}}}

    return $data;
}


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


# UTILITIES {{{1
#------------------------------------------------------

#===| cmpKeys() {{{2
sub cmpKeys {
    my ($data, $key_a, $key_b, $hash) = @_;

    my $pointStr_a = getPointStr_FromUniqeKey($data, $key_a) ? getPointStr_FromUniqeKey($data, $key_a)
                                                             : genPointStr_ForRedundantKey($data, $key_a, $hash);
    my $pointStr_b = getPointStr_FromUniqeKey($data, $key_b) ? getPointStr_FromUniqeKey($data, $key_b)
                                                             : genPointStr_ForRedundantKey($data, $key_b, $hash);
    return $pointStr_a cmp $pointStr_b;

    #===|| getPointStr_FromUniqeKey() {{{3
    sub getPointStr_FromUniqeKey {
        my ($data, $key)  = @_;

        if    (exists $data->{dspt}->{$key})        { return $data->{dspt}->{$key}->{order} }
        elsif (getObj_FromGroupName($data, $key))   { return $data->{dspt}->{getObj_FromGroupName($data, $key)}->{order} }
        else                                        { return 0 }
        #===| getObj_FromGroupName() {{{4
        sub getObj_FromGroupName {
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


    }
    #===|| genPointStr_ForRedundantKey() {{{3
    sub genPointStr_ForRedundantKey {
        # return 'pointStr' if 'key' is an 'objKey'
        # die if 'pointStr' is '0' or doesn't exist!
        # return '0' if 'objKey' doesn't exist!

        my ($data, $key, $hash)  = @_;

        ## Set 'data->{point}'
        my $lvlObj     =  getLvlObj($data, $hash);
        $data->{point} = [split /\./, $data->{dspt}->{$lvlObj}->{order}];

        ## Query 'data->{point}'
        my $pointStr      = getPointStr($data);
        my $hash_ObjKey   = getObj($data);
        my $hash_DsptReff = $data->{dspt}->{$hash_ObjKey};

        ## ATTRIBUTES
        #if (exists $hash_DsptReff->{attributes}->{$key}) {
        if ((exists $hash_DsptReff->{attributes}) and (exists $hash_DsptReff->{attributes}->{$key})) {

            my $attr_DsptReff = $hash_DsptReff->{attributes}->{$key};
            my $cnt;

            $cnt = exists $attr_DsptReff->[1] ? $attr_DsptReff->[1]
                                              : 1;

            for (my $i = 1; $i <= $cnt; $i++) { $pointStr = changePointStrInd($pointStr, 1) }

            if ($pointStr) { return $pointStr }
            else           { die "pointStr $pointStr doesn't exist or is equal to '0'!" }
        }

        ## RESERVED KEYS
        elsif (isReservedKey($data, $key)) {
            my $first     = join '.', $data->{point}->@[0 .. $data->{point}->$#* -1];
            my $pointEnd  = $data->{point}->[-1];
            my $order     = $data->{reservedKeys}->{$key}->[1];
            my $attrs_DsptReff = exists $hash_DsptReff->{attributes} ? $hash_DsptReff->{attributes}
                                                                     : 0;
            if ($attrs_DsptReff and $attrs_DsptReff->{$key}) {
                my @orders = map {$attrs_DsptReff->{$_}->[1]} keys $attrs_DsptReff->%*;
                my $attr   = ( sort { $b cmp $a } @orders)[0];
                my $end    = $order + $attr + $pointEnd;
                $pointStr  = $first . $end;
            } else {
                my $end    = $order . $pointEnd;
                $pointStr  = $first . $end;
            }

            return $pointStr;
        }

        ## INVALID KEY
        else {die "Invalid Key: $key."}
    }
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


#===| getAttrReffs(){{{2
sub getAttrReffs {
    my ($data, $obj) = @_;
    my $objReff = $data->{dspt}->{$obj};
    my $attrReff = (exists $objReff->{attributes}) ? $objReff->{attributes}
                                                   : 0;
    return $attrReff;
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


#===| isAttr(){{{2
sub isAttr {
    my ($data, $lvlObj, $key) = @_;
    my $attrRef = getAttrReffs($data,$lvlObj);
    if ($attrRef) {
        my $attr = (grep {$_ eq $key} keys %$attrRef)[0];
        return ($attr) ? $attrRef->{$attr}
                       : 0;
    }
    else {
        return 0;
    }
}


#===| isReservedKey() {{{2
sub isReservedKey {
    my ($data, $key)  = @_;
    my $resvKeys      = $data->{reservedKeys};

    my @matches  = grep { $key eq $resvKeys->{$_}->[0] } keys %{$resvKeys};

    return $matches[0] ? 1 : 0;
}


# PRIVATE {{{1
#------------------------------------------------------

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

    ## preserve
    if (exists $data->{preserve}) {
        for my $obj (keys $data->{preserve}->%*) {
            $dspt->{$obj}->{preserve}->@* = $data->{preserve}->{$obj}->@*;
        }
        delete $data->{preserve};
    }
    $data->{dspt} = dclone($dspt);
}


#===| genReservedKeys() {{{2
sub genReservedKeys {

    my $data = shift @_;
    my $ARGS = shift @_;
    my $defaults = {
        preserve => [ 'preserve', 1 ],
        raw      => [ 'raw',      2 ],
        trash    => [ 'trash',    3 ],
        LN       => [ 'LN',       4 ],
        point    => [ 'point',    5 ],
        miss     => [ 'miss',     6 ],
        libName  => [ 'libName',  7 ],
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

    ## META
    $data->{meta}->{dspt} = {};
    my $dspt_meta = $data->{meta}->{dspt};


    my @orders = map {$dspt->{$_}->{order}} keys %$dspt;
    $dspt_meta->{max} = (
        sort {
            length $b <=> length $a
            ||
            substr($b, -1) <=> substr($a, -1)
        } @orders
    )[0];
}


#===| validate_Matches() {{{2
sub validate_Matches {

    my $data         = shift @_;
    my $dspt         = $data->{dspt};
    my $matches      = $data->{matches};

    ## META
    $data->{meta}->{matches} = {};
    my $matches_meta = $data->{meta}->{matches};
    for my $obj (keys $dspt->%*, 'miss') {
        my $obj_matches = $matches->{$obj};
        $matches_meta->{$obj} = {};
        my $obj_meta    = $matches_meta->{$obj};
        if ($obj_matches) {
            $obj_meta->{count} = scalar $obj_matches->@*;
        } else {
            $obj_meta->{count} = 0;
        }
    }

    ## Preserve
    $data->{preserve} = [];
    for my $obj (keys %$dspt) {
        my $obj_Preserve = $dspt->{$obj}->{preserve};
        if ($obj_Preserve) {
            for my $item (@$obj_Preserve) {
                my $obj_matches = $data->{matches}->{$obj};
                my $HASH = (grep {$_->{$obj} eq $item} @$obj_matches)[0];
                my $LN = $HASH->{LN};


                {
                    my @objs = grep {
                        length $$dspt{$_}->{order} == length $$dspt{$obj}->{order}
                        and
                        $$dspt{$_}->{order} ne '0'
                    } keys %$dspt;
                    push @$obj_matches, $matches->@{@objs}->@*;

                }

                my $HASH2 = (grep {$_->{LN} > $LN} @$obj_matches)[0];
                my $LN2 = $HASH2 ? $HASH2->{LN}
                                 : 0;

                push $data->{preserve}->@*,[$LN,$LN2];
            }
        }
    }

    #unless ($data->{matches}) { die("User did not provide 'matches' argument at ${0} at line: ".__LINE__) }
}


# EXTERNAL {{{1
#------------------------------------------------------

#===| checkMatches() {{{2
sub checkMatches {

    my $data    = shift @_;
    my $objKey = getObj( $data );

    if (exists $data->{matches}->{$objKey}) {
        divyMatches( $data );
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
    my $match = shift @_;
    $match->{$attributeKey} = [
        grep { $_ ne '' }
        split( /$delimsRegex/, $match->{$attributeKey} )
    ];
}


#===| divyMatches() {{{2
sub divyMatches {

    my $data = shift @_;
    my $reffArray = $data->{reffArray};
    my $matches   = $data->{matches};
    my $opts      = $data->{opts};

    if ($opts->{divy}->[0]) {
        my $obj       = getObj( $data );
        my $pond      = dclone($matches->{$obj});
        my $groupName = getGroupName($data, $obj);

        my $ind = ( scalar $reffArray->@* ) - 1;
        for my $reff (reverse $reffArray->@*) {
            my $lvlObj      = getLvlObj($data, $reff);
            my $lvlItem     = $reff->{$lvlObj};
            my $reff_lineNum = ($reff->{LN}) ? $reff->{LN}
                                             : 0;

            ## Debug {{{
            mes( "IDX-$ind $obj -> $lvlObj", $data, 1)
                if $opts->{divy}->[1] and $opts->{divy}->[1] == 1;
            mes( "[$reff_lineNum] <".$lvlObj."> ".$lvlItem, $data, 4)
                if $opts->{divy}->[1] and $opts->{divy}->[1] == 1;
            #}}}


            my $bucket;
            my $flag=0;
            my $prev_match_lineNum;
            for my $match (reverse $pond->@*) {

                ## Preserve
                my $presFlag=0;
                for my $part ($data->{preserve}->@*) {
                    my $LN = $part->[0];
                    my $LN2 = $part->[1];
                    if ($LN2) {
                        $presFlag=1 if $match->{LN} >= $LN and $match->{LN} < $LN2;
                    } else {
                        $presFlag=1 if $match->{LN} >= $LN;
                    }
                }

                if ($match->{LN} > $reff_lineNum and !$presFlag) {
                    my $match     = pop $pond->@*;
                    my $attrDebug = genAttributes( $data, $match );
                    push $bucket->@*, $match;

                    ## Debug {{{
                    unless ($flag++) {
                        mes( "IDX-$ind $obj -> $lvlObj", $data, 1)
                            unless ($opts->{divy}->[1]);
                        mes( "[$reff_lineNum] <".$lvlObj."> ".$lvlItem, $data, 4)
                            unless ($opts->{divy}->[1]);
                    }

                    mes( "($match->{LN}) <$obj> $match->{$obj}", $data, 4)
                        if $data->{dspt}->{$obj}->{partion};
                    mes( "($match->{LN}) <$obj> $match->{$obj}", $data, 4)
                        unless $data->{dspt}->{$obj}->{partion};

                    if (scalar $attrDebug->@* and $opts->{attribs}->[1]) {mes("$_",$data,-1,1) for $attrDebug->@*}
                    #}}}

                } else { last }
                $prev_match_lineNum = $match->{LN};
            }

            ## Check if bucket is empty
            if ($bucket) {
                $bucket->@* = reverse $bucket->@*;
                $reffArray->[$ind]->{$groupName} = $bucket;
                splice( $reffArray->@*, $ind, 1, ($reffArray->[$ind], $bucket->@*) );
            }
            $ind--;
        }
        return $groupName;
    }
}

#===| genAttributes() {{{2
sub genAttributes {

    my $data    = shift @_;
    my $opts    = $data->{opts};
    my $debug   = [];

    if ($opts->{attribs}->[0]) {

        my $obj     = getObj($data);
        my $objReff = $data->{dspt}->{$obj};
        my $match = shift @_;
        $match->{raw} = $match->{$obj};

        if (exists $objReff->{attributes}) {
            my $attrDSPT = $objReff->{attributes};
            my @attrOrderArray = sort {
                $attrDSPT->{$a}->[1] cmp $attrDSPT->{$b}->[1];
                } keys $attrDSPT->%*;

            for my $attrib (@attrOrderArray) {
                my $attrReff = $attrDSPT->{$attrib};
                my $sucess = $match->{ $obj } =~ s/$attrReff->[0]//;
                my $fish = {};
                $fish->{caught} = $1 if $1;
                if ($sucess and !$1) {$fish->{caught} = '' }
                #if ($fish->{caught} && $fish->{caught} ne '') {
                if ($fish->{caught} || exists $fish->{caught}) {
                    $match->{$attrib} = $fish->{caught};

                    ## Debug {{{
                    push $debug->@*, mes("|${attrib}|", $data, 6, 1, 1);
                    push $debug->@*, mes(" '".$match->{$attrib}."'", $data, -1, 0, 1);
                    #}}}

                    if (scalar $attrReff->@* == 3) {
                        delimitAttribute($data, $attrib, $match);
                    }
                }
            }


            unless ($match->{$obj}) {
                $match->{$obj} = [];
                for my $attrib (@attrOrderArray) {
                    if (exists $match->{$attrib}) {
                        push $match->{$obj}->@*, $match->{$attrib}->@*;
                    }
                }
            }
        }
    }
    return $debug;
}


#===| getMatches() {{{2
sub getMatches {

    my $data = shift @_;
    my $fname = $data->{fileNames}->{fname};
    my $dspt  = $data->{dspt};
    my $output;

    open( my $fh, '<', $fname )
        or die $!;

    while (my $line = <$fh>) {

        my $flag;
        for my $objKey (keys %$dspt) {
            my $obj = $dspt->{$objKey};

            if ($obj->{re} and $line =~ /$obj->{re}/) {
                my $match = {
                    LN      => $.,
                    $objKey => $1,
                    raw     => $line,
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

    close( $fh );
    $data->{matches} = $output;
}


# INHERITED {{{1
#------------------------------------------------------

#===| decho() {{{2
sub decho {

    my $var    = shift @_;
    my $depth  = shift @_;
    my $data   = shift @_;

    use Data::Dumper;
    $Data::Dumper::Indent = 2;
    $Data::Dumper::Maxdepth = $depth if $depth;
    if ($data) {
        $Data::Dumper::Sortkeys = ( sub {
        });
    }

    my $output = Data::Dumper->Dump( [$var], ['reffArray']);
    return $output;
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


#===| filter(){{{2
sub filter {
    my $arg   = shift @_;
    my $key   = shift @_;
    my $index = shift @_;
    my $hash  = shift @_;
    my $sub0   = shift @_;
    if ( ($index % 2 == 0) and $arg eq $key) {
         $hash->{$arg} = $sub0->($hash->{$arg});
    }
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


#===| mes() {{{2
sub mes {

    my ($mes,$data,$cnt,$NewLineDisable,$silent,$indent) = @_;
    if ($data->{opts}->{verbose}) {
        my $indent          = "    ";
        my $newline         = !($NewLineDisable) ? "\n" : "";
        if ($cnt) { $indent = $indent x (1 + $cnt) }
        unless ($silent) {
            print $indent . $mes . $newline;
        } else {
            return $indent . $mes . $newline;
        }
    }
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

#$ perl -d:NYTProf ./jsonGen.pl
#$  nytprofhtml --open
