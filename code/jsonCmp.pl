#!/usr/bin/env perl
#============================================================
#
#         FILE: jsonCmp.pl
#  DESCRIPTION:
#       AUTHOR: Azuhmier (aka taganon), azuhmier@gmail.com
#      Created: Sat 06/12/21 17:34:34
#============================================================
use warnings;
use strict;
use JSON;
use Data::Dumper;
use Storable qw(dclone);

#  Assumptions
#    - all jsons were generated with dspts with identical objs, orders, and attributes




# MAIN {{{1
#------------------------------------------------------

my $data;
$data->{dspt}    = getJson('./json/deimos.json');
my $gitIo        = getJson('./json/gitIO.json');
my $masterbin    = getJson('./json/masterbin2.json');
my $catalog      = getJson('./json/hmofa2.json');

## simple listing
{
    my $PATTERN  = 'SERIES';
    my $list0  = getAllValuesForKey($data, $PATTERN, dclone($catalog), 1);
    my $list1 = getAllValuesForKey($data, $PATTERN, dclone($masterbin), 1);
    my $diffs = getDiffs($data, [$list0, $list1]);
    my $obj = getObjFromGroupNameKey($data, $PATTERN);
    my @list = ();
    my @list0 = map { '0 ' . $_->{$obj} . " || " .  $_->{LN}} $diffs->[0]->@*;
    my @list1 = map { '1 ' . $_->{$obj} . " || " .  $_->{LN}} $diffs->[1]->@*;
    push( @list, @list0);
    push( @list, @list1);
    print $_, "\n" for sort { substr($a,2) cmp substr($b,2) } @list;
}

## relative listing
{
    print "\n===================\n";
    my $PATTERN  = 'AUTHORS';
    my $PATTERN2 = 'STORIES';
    my $list0  = getAllValuesForKey($data, $PATTERN, dclone($catalog), 0, $PATTERN2, 1);
    my $list1  = getAllValuesForKey($data, $PATTERN, dclone($masterbin), 0, $PATTERN2, 1);
    my $list0_flat = biFlat($data, $list0, $PATTERN, $PATTERN2);
    my $list1_flat = biFlat($data, $list1, $PATTERN, $PATTERN2);
    my $diffs = getDiffs($data, [$list0_flat, $list1_flat], $PATTERN);
    my $obj2 = getObjFromGroupNameKey($data, $PATTERN2);
    my $obj = getObjFromGroupNameKey($data, $PATTERN);
    my @list = ();
    my @list0 = map {  $_->{$obj} . ' || 0 ' . $_->{$obj2} . " || " .  $_->{LN} } $diffs->[0]->@*;
    my @list1 = map {  $_->{$obj} . ' || 1 ' . $_->{$obj2} . " || " .  $_->{LN} } $diffs->[1]->@*;
    push( @list, @list0);
    push( @list, @list1);
    print $_, "\n" for @list;
    print $_, "\n" for sort {
        my $aa = $a;
        my $bb = $b;
        my $aa2 = $a;
        my $bb2 = $b;
        $aa2 =~ s/^.*?\|\|\s//g;
        $bb2 =~ s/^.*?\|\|\s//g;
        $aa cmp $bb || substr($aa2,2) cmp substr($bb2,2);
    } @list;
}


## List with External Data: gitIO.json
{
    print "\n===================\n";
}


## complex listing #2: attributes
{
    print "\n===================\n";
}


## complex listing #2: recursive listing
{
    print "\n===================\n";
}




#------------------------------------------------------
# subroutines {{{1
#------------------------------------------------------

#===| biFlat() {{{2
sub biFlat {
    my $data = shift @_;
    my $hash = shift @_;
    my $PATTERN = shift @_;
    my $PATTERN2 = shift @_;
    my $flatHash = [];
    my $parentObj = getObjFromGroupNameKey($data, $PATTERN);
    for my $parent ($hash->@*) {
        my $parentName = $parent->{$parentObj};
        for my $child ($parent->{$PATTERN2}->@*) {
            $child->{$parentObj} = $parentName;
            push $flatHash->@*, $child;
        }
    }
    return $flatHash;
}


#===| getDiffs() {{{2
sub getDiffs {
    my $data = shift @_;
    my $hashList = shift @_;
    my $PATTERN = shift @_;
        my $ind_0 = 0;
        for my $part_0 ( @{ dclone($hashList->[0]) } ) {
            my $ind_1 = 0;
            for my $part_1  (@{ dclone($hashList->[1]) } ) {
                my @match;
                if ($PATTERN) {
                    my $parent = getObjFromGroupNameKey($data, $PATTERN);
                    @match = grep { $_ ne $parent and $_ ne 'LN' and  $_ !~ /attrib/ and $_ !~ /raw/} keys $part_1->%*;
                }
                else {
                    @match = grep { $_ ne 'LN' and  $_ !~ /attrib/ and $_ !~ /raw/} keys $part_1->%*;
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

    return [ [grep {$_} $hashList->[0]->@*] , [grep {$_} $hashList->[1]->@*] ];
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


#===| getAllValuesForKey() {{{2
sub getAllValuesForKey {
    my $data        = shift @_;
    my $PATTERN     = shift @_;
    my $var         = shift @_;
    my $sliceEnable = shift @_;
    my $PATTERN2    = shift @_;
    my $relEnable   = shift @_;
    my $matches;

    ##  HASH?
    if (ref $var eq 'HASH') {
        for my $key (keys $var->%*) {
            if ($key eq $PATTERN) {
                my @catch = $var->{$key}->@*;

                ## SLICE
                if ($sliceEnable) {
                    for my $part (@catch) {
                        for my $key (keys $part->%*) {
                            if    (ref $part->{$key} eq 'ARRAY') { delete $part->{$key} }
                            elsif ($key eq 'point')              { delete $part->{$key} }
                        }
                    }
                }

                ## Relative
                if ($relEnable and not $sliceEnable) {
                    for my $part (@catch) {
                      #print $part, "\n";
                       my $childs = getAllValuesForKey($data, $PATTERN2, $part, 1);
                        for my $key (keys $part->%*) {
                            if    (ref $part->{$key} eq 'ARRAY') { delete $part->{$key} }
                            elsif ($key eq 'point')              { delete $part->{$key} }
                        }
                        $part->{$PATTERN2} = $childs;
                    }
                }

                push $matches->@*, @catch;
            }
            else {
                my $catch = getAllValuesForKey($data, $PATTERN, $var->{$key}, $sliceEnable, $PATTERN2, $relEnable);
                if ($catch) {
                    push $matches->@*, $catch->@*;
                }
            }
        }
    }

    ##  ARRAY?
    elsif (ref $var eq 'ARRAY') {
        for my $part ($var->@*) {
            my $catch = getAllValuesForKey($data, $PATTERN, $part, $sliceEnable, $PATTERN2, $relEnable);
            if ($catch) {
                push $matches->@*, $catch->@*;
            }
        }
    }


    ##  OTHER
    else {
        my $type = ref $var;
        if ($type) {print $type, "\n"}
    }

    return $matches;
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
