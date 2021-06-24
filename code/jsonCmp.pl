#!/usr/bin/env perl

#============================================================
#
#         FILE: jsonCmp.pl
#        USAGE: ./jsonCmp.pl
#  DESCRIPTION: ---
#       AUTHOR: Azuhmier (aka taganon), azuhmier@gmail.com
#      Created: Sat 06/12/21 17:34:34
#============================================================

my $start = time;
use warnings;
use strict;
use JSON::PP;
use Data::Dumper;
use Storable qw(dclone);
my $duration1 = time - $start;
use Time::HiRes qw(time);
#use List::MoreUtils qw(uniq);
#use List::Util;
#use Array::Utils;
#use Data::Compare;
#use Data::Structure::Util;
## NOT WORKING
#use Data::Diff;
#use Data::Match;


#  Assumptions
#    - all jsons were generated with dspts with identical objs, orders, and attributes

# MAIN {{{1
#------------------------------------------------------
{
    my $data = init({
        dspt => './json/deimos.json',
        external => [
            './json/gitIO.json'
        ],
        hash => [
            './json/catalog.json',
            './json/masterbin.json',
        ],
    });


    # ===| simple listing {{{2
    delegate(
        $data,
        {
            objs => ['series'],
            process => {
                disableDiffs => 1,
            },
        },
    );


    # ===| relative listing {{{2
    delegate(
        $data,
        {
            objs => ['author', 'title'],
            process => {
                disableDiffs => 1,
            },
        },
    );


    # ===| using external data: gitIO.json {{{2
    delegate(
        $data,
        {
            objs  => ['url'],
            sub_0 => genFilter({
                        pattern => qr?\Qhttps://raw.githubusercontent.com/Azuhmier/hmofa/master/archive_7/\E(\w{8})?,
                        dspt    => $data->{external}->{gitIO},
            }),
            process => {
                disableDiffs => 1,
            },
        },
    );

    delegate(
        $data,
        {
            objs  => ['title', 'url'],
            sub_0 => genFilter({
                        pattern => qr?\Qhttps://raw.githubusercontent.com/Azuhmier/hmofa/master/archive_7/\E(\w{8})?,
                        dspt    => $data->{external}->{gitIO},
            }),
            process => {
                disableDiffs => 1,
            },
        },
    );

    # ===| output{{{2
}


# SUBROUTINES {{{1
#------------------------------------------------------

#===| init() {{{2
sub init {
    my $data = shift @_;
    $data->{hash} = [ map { getJson($_) } $data->{hash}->@* ];
    $data->{dspt} = getJson($data->{dspt});
    $data->{external} = {
        map {
          $_ =~ m/(\w+)\.json$/;
          $1 => getJson($_);
        } $data->{external}->@*
    };
    validate_Dspt( $data );
    return $data;

}


#===| delegate() {{{2
sub delegate {

    my $data         = shift @_;
    my $ARGS         = shift @_;
    my $solo = ($ARGS->{objs}->[1]) ? 0 : 1;
    my @lists;

    my $sub_0 = 0;
    if (exists $ARGS->{sub_0}) {$sub_0 = $ARGS->{sub_0}}
    ## LISTS
    for my $hash ($data->{hash}->@*) {
        my $list = getAllValuesForKey(
            $data,
            {
              hash        => dclone($hash),
              obj_0       => $ARGS->{objs}->[0],
              obj_1       => $ARGS->{objs}->[1],
              sliceEnable => $solo ? 1 : 0,
            },
        );
        unless ($solo) {
            $list = biFlat(
                $data,
                {
                    list  => $list,
                    obj_0 => $ARGS->{objs}->[0],
                    obj_1 => $ARGS->{objs}->[1],
                }
            );
        }
        push @lists, $list;
    }
    unless ($ARGS->{process}->{disableDiffs}) {
        ## DIFFS
        my $diffs = getDiffs(
            $data,
            {
                hashList => [ @lists ],
                obj_0    => $ARGS->{objs}->[0],
                obj_1    => $ARGS->{objs}->[1],
                sub_0    => $sub_0,
            }
        );

        ## Outputs
        formatToSTDOUT(
            $data,
            {
                objs  => [$ARGS->{objs}->[0], $ARGS->{objs}->[1]],
                diffs => $diffs,
                sub_0 => $sub_0,
            }
        );
    }
}


#===| getAllValuesForKey() {{{2
sub getAllValuesForKey {
    my $data        = shift @_;
    my $ARGS        = shift @_;
    my $hash        = $ARGS->{hash};
    my $sliceEnable = $ARGS->{sliceEnable};
    my $obj_0       = getGroupName($data, $ARGS->{obj_0});
    my $obj_1       = getGroupName($data, $ARGS->{obj_1});
    my $matches;

    ##  HASH?
    if (ref $hash eq 'HASH') {
        for my $key (keys $hash->%*) {
            if ($key eq $obj_0) {
                my @catch = $hash->{$key}->@*;

                ## SLICE
                if ($sliceEnable) {
                    for my $part (@catch) {
                        for my $key (keys $part->%*) {
                            if    (ref $part->{$key} eq 'ARRAY') { delete $part->{$key} }
                        }
                    }
                }

                ## Relative
                if ($obj_1) {
                    for my $part (@catch) {
                        my $childs = getAllValuesForKey(
                           $data,
                           {
                             hash        => $part,
                             obj_0       => $obj_1,
                             sliceEnable => 1,
                           },
                        );
                        for my $key (keys $part->%*) {
                            if    (ref $part->{$key} eq 'ARRAY') { delete $part->{$key} }
                        }
                        $part->{$obj_1} = $childs;
                    }
                }

                push $matches->@*, @catch;
            }
            else {
                my $catch = getAllValuesForKey(
                    $data,
                    {
                      hash        => $hash->{$key},
                      obj_0       => $obj_0,
                      obj_1       => $obj_1,
                      sliceEnable => $sliceEnable,
                    },
                );
                if ($catch) {
                    push $matches->@*, $catch->@*;
                }
            }
        }
    }

    ##  ARRAY?
    elsif (ref $hash eq 'ARRAY') {
        for my $part ($hash->@*) {
            my $catch = getAllValuesForKey(
                $data,
                {
                  hash        => $part,
                  obj_0       => $obj_0,
                  obj_1       => $obj_1,
                  sliceEnable => $sliceEnable,
                },
            );
            if ($catch) {
                push $matches->@*, $catch->@*;
            }
        }
    }


    ##  OTHER
    else {
        my $type = ref $hash;
        if ($type) {print $type, "\n"}
    }
    return $matches;
}


#===| biFlat() {{{2
sub biFlat {
    my $data  = shift @_;
    my $ARGS  = shift @_;
    my $hash  = $ARGS->{list};
    my $obj_0       = getGroupName($data, $ARGS->{obj_0});
    my $obj_1       = getGroupName($data, $ARGS->{obj_1});

    my $flatHash = [];
    my $parentObj = getObjFromGroupNameKey($data, $obj_0);
    for my $parent ($hash->@*) {
        my $parentName = $parent->{$parentObj};
        for my $child ($parent->{$obj_1}->@*) {
            $child->{$parentObj} = $parentName;
            push $flatHash->@*, $child;
        }
    }
    return $flatHash;
}


#===| getDiffs() {{{2
sub getDiffs {
    my $data     = shift @_;
    my $ARGS     = shift @_;
    my $hashList = $ARGS->{hashList};
    my $obj_0    = getGroupName($data, $ARGS->{obj_0});
    my $obj_1    = getGroupName($data, $ARGS->{obj_1});
    my $sub_0    = $ARGS->{sub_0};


    my $child;
    if ($obj_1) { $child  = getObjFromGroupNameKey($data, $obj_1); }
    else        { $child  = getObjFromGroupNameKey($data, $obj_0); }

    my $ind_0 = 0;
    my @parts_0 = @{ dclone($hashList->[0]) };
    #@parts_0 = sort { $a->{$child} cmp $b->{$child} } @parts_0;
    for my $part_0 (@parts_0) {

        my $ind_1 = 0;
        my @parts_1 = @{ dclone($hashList->[1]) };
        #@parts_1 = sort { $a->{$child} cmp $b->{$child} } @parts_1;
        for my $part_1  (@parts_1) {
            my @match;
            if ($obj_1) {
                my $parent = getObjFromGroupNameKey($data, $obj_0);
                @match = grep { $_ ne $parent and $_ ne 'LN' and  $_ !~ /attrib/ and $_ !~ /raw/} keys $part_1->%*;
            }
            else {
                @match = grep { $_ ne 'LN' and  $_ !~ /attrib/ and $_ !~ /raw/} keys $part_1->%*;
            }
            if ($sub_0) {
                $part_0->{$match[0]} = $sub_0->($part_0->{$match[0]});
                $part_1->{$match[0]} = $sub_0->($part_1->{$match[0]});
            }
            if (lc $part_0->{$match[0]} eq lc $part_1->{$match[0]}) {
                splice $hashList->[0]->@*, $ind_0, 1;
                splice $hashList->[1]->@*, $ind_1, 1;
                $ind_0 -= 1;
                $ind_1 -= 1;
                last;
            }
            $ind_1++;
        }
        $ind_0++;
    }

    return [ $hashList->[0] , $hashList->[1] ];
}


#===| formatToSTDOUT() {{{2
sub formatToSTDOUT {
    my $data  = shift @_;
    my $ARGS  = shift @_;
    my $obj_0 = $ARGS->{objs}->[0];
    my $obj_1 = $ARGS->{objs}->[1];
    my $diffs = $ARGS->{diffs};
    my $sub_0 = $ARGS->{sub_0};
    my @LIST  = ();

    if ($obj_1) {
        my @list0;
        my @list1;
        if ($sub_0) {
            @list0 = map {  '0 ' . $_->{$obj_0} . ' || ' . $sub_0->($_->{$obj_1}) . " || " .  $_->{LN} } $diffs->[0]->@*;
            @list1 = map {  '1 ' . $_->{$obj_0} . ' || ' . $sub_0->($_->{$obj_1}) . " || " .  $_->{LN} } $diffs->[1]->@*;
        }
        else {
            @list0 = map {  '0 ' . $_->{$obj_0} . ' || ' . $_->{$obj_1} . " || " .  $_->{LN} } $diffs->[0]->@*;
            @list1 = map {  '1 ' . $_->{$obj_0} . ' || ' . $_->{$obj_1} . " || " .  $_->{LN} } $diffs->[1]->@*;
        }
        push( @LIST, @list0);
        push( @LIST, @list1);
        print "\n\n\n\n===============================\n";
        print $_, "\n" for sort {

            my $aa  = $a;
            my $bb  = $b;

            ## num
            $aa =~ s/^(\d)\s+//;
            my $num_a = $1;
            $bb =~ s/^(\d)\s+//;
            my $num_b = $1;

            ## obj_0
            $aa =~ s/^(.*?)\s\|\|\s//;
            my $obj0_a = $1;
            $bb =~ s/^(.*?)\s\|\|\s//;
            my $obj0_b = $1;

            ## obj_1
            $aa =~ s/^(.*?)\s\|\|\s//;
            my $obj1_a = $1;
            $bb =~ s/^(.*?)\s\|\|\s//;
            my $obj1_b = $1;

            $obj0_a cmp $obj0_b || $num_a cmp $num_b || $obj1_a cmp $obj1_b;
        } @LIST;
    }
    else {
        my @list0;
        my @list1;
        if ($sub_0) {
            @list0 = map { '0 ' . $sub_0->($_->{$obj_0}) . " || " .  $_->{LN}} $diffs->[0]->@*;
            @list1 = map { '1 ' . $sub_0->($_->{$obj_0}) . " || " .  $_->{LN}} $diffs->[1]->@*;
        }
        else {
            @list0 = map { '0 ' . $_->{$obj_0} . " || " .  $_->{LN}} $diffs->[0]->@*;
            @list1 = map { '1 ' . $_->{$obj_0} . " || " .  $_->{LN}} $diffs->[1]->@*;
        }
        push( @LIST, @list0);
        push( @LIST, @list1);
        print "\n\n\n\n===============================\n";
        print $_, "\n" for sort {
            my $aa  = $a;
            my $bb  = $b;

            ## num
            $aa =~ s/^(\d)\s+//;
            my $num_a = $1;
            $bb =~ s/^(\d)\s+//;
            my $num_b = $1;

            ## obj_0
            $aa =~ s/^(.*?)\s\|\|\s//;
            my $obj0_a = $1;
            $bb =~ s/^(.*?)\s\|\|\s//;
            my $obj0_b = $1;

            $num_a cmp $num_b || $obj0_a cmp $obj0_b;
        } @LIST;
    }
}


# UTILITIES {{{1
#------------------------------------------------------

# NOTES {{{1
#------------------------------------------------------
#{
#  obj => '',
#  groupName => [...],
#  groupName1 => [...],
#  groupName2 => [...],
#  meta => '',
#}
#  keys $a == keys $b
#  $a->{$obj} == $b->{$obj}
#  $a->{meta} == $b->{meta}
#
#
#[
#  {$obj},
#  'scalar',
#]
#  @a == @b
#  $a->[$ind]->$obj == $b->[$ind]->$obj
#  $a->[$ind]->{$key} == $b->[$ind]->{$key}
#
#meta
#  keys $a == keys $b
#  values $a == values $b
#    if scalar
#        $meta_a->{$a} == keys $meta_b->{$b}
#    if ref 'ARRAY'
#        @a == @b
#    if ref 'HASH'
#        $meta_a->{$a} == keys $meta_b->{$b}
#
#ERRORS
#- $a != $b
#- $a = $b->{$key}
#- $a = $c->[0]->{$key} && $a == $b
# Shared {{{1
#------------------------------------------------------

#===| setReservedKeys() {{{2
sub setReservedKeys {
  my $data = shift @_;
  my $reservedKeys = {
        raw   => [ 'raw', 1 ],
        trash => [ 'trash', 2 ],
        LN    => [ 'LN', 3 ],
        miss  => [ 'miss', 4 ],
        miss  => [ 'LIBS', 5 ],
        miss  => [ 'libName', 6 ],
  };
  $data->{reservedKeys} = $reservedKeys;
}


#===| isReservedKey() {{{2
sub isReservedKey {

    my %reservedKeys = (
        LN    => 'LN',
        raw   => 'raw',
        trash => 'trash',
        miss  => 'miss',
    );

    my $data = shift @_;
    my $key  = shift @_;
    my @matches = grep { $_ eq $reservedKeys{$_} } keys %reservedKeys;
    if ($matches[0])    {return 1}
    else                {return 0}
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


#===| validate_Dspt() {{{2
sub validate_Dspt {

    my $data = shift @_;
    my $dspt = $data->{dspt};
    my %hash = (
    );
    $data->{dspt}->{libName} = {
        order => 0,
        groupName => 'LIBS',
    };
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

    ##
    my $mes   = shift @_;
    my $data  = shift @_;

    ##
    if ($data->{verbose}) {
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
}


