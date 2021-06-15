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

# ===| init {{{2
my $data = init({
    dspt => [
        './json/deimos.json',
        './json/gitIO.json'
    ],
    hash => [
       './json/catalog.json',
       './json/masterbin.json',
    ],
});


# ===| simple listing {{{2
{
    my ($data, $diffs)  = genDiff(
        $data,
        [
            'series',
        ],
    );


    ## Output
    my $obj   = getObjFromGroupNameKey($data, $data->{objs}->[0]);
    my @LIST  = ();
    my @list0 = map { '0 ' . $_->{$obj} . " || " .  $_->{LN}} $diffs->[0]->@*;
    my @list1 = map { '1 ' . $_->{$obj} . " || " .  $_->{LN}} $diffs->[1]->@*;
    push( @LIST, @list0);
    push( @LIST, @list1);
    print "\n\n\n\n===============================\n";
    print $_, "\n" for sort { substr($a,2) cmp substr($b,2) } @LIST;
}


# ===| relative listing #1: Author and Stories {{{2
{
    my ($data, $diffs)  = genDiff(
        $data,
        [
            'author',
            'title',
        ],
    );

    ## Outputs
    my $obj2  = getObjFromGroupNameKey($data, $data->{objs}->[1]);
    my $obj   = getObjFromGroupNameKey($data, $data->{objs}->[0]);
    my @list  = ();
    my @list0 = map {  $_->{$obj} . ' || 0 ' . $_->{$obj2} . " || " .  $_->{LN} } $diffs->[0]->@*;
    my @list1 = map {  $_->{$obj} . ' || 1 ' . $_->{$obj2} . " || " .  $_->{LN} } $diffs->[1]->@*;
    push( @list, @list0);
    push( @list, @list1);
    print "\n\n\n\n===============================\n";
    print $_, "\n" for sort {
        my $aa  = $a;
        my $bb  = $b;
        my $aa2 = $a;
        my $bb2 = $b;
        $aa2 =~ s/^.*?\|\|\s//g;
        $bb2 =~ s/^.*?\|\|\s//g;
        $aa cmp $bb || substr($aa2,2) cmp substr($bb2,2);
    } @list;
}


# ===| List with External Data: gitIO.json {{{2
{
    my ($data, $diffs)  = genDiff(
        $data,
        [
            'url',
        ],
    );


    ## Output
    my $obj   = getObjFromGroupNameKey($data, $data->{objs}->[0]);
    my @LIST  = ();
    my @list0 = map { '0 ' . $_->{$obj} . " || " .  $_->{LN}} $diffs->[0]->@*;
    my @list1 = map { '1 ' . $_->{$obj} . " || " .  $_->{LN}} $diffs->[1]->@*;
    push( @LIST, @list0);
    push( @LIST, @list1);
    print "\n\n\n\n===============================\n";
    print $_, "\n" for sort { substr($a,2) cmp substr($b,2) } @LIST;
}


# ===| complex listing #2: attributes {{{2
{
    print "\n\n\n\n===============================\n";
}


# ===| complex listing #2: recursive listing {{{2
{
    print "\n\n\n\n===============================\n";
}




#------------------------------------------------------
# subroutines {{{1
#------------------------------------------------------

#===| getName() {{{2
sub getName {
    my $obj  = shift @_;
    my $dspt = shift @_;
    my $name = $dspt->{$obj}->{groupName};
    return ($name) ? $name
                   : $obj;
}


#===| genDiff() {{{2
sub genDiff {

    my $data         = shift @_;
    $data->{objs}    = shift @_;
    $data->{objs}    = [ map { getName( $_, $data->{dspt}->{deimos}) } $data->{objs}->@* ];
    my $solo = ($data->{objs}->[1]) ? 0 : 1;
    my @lists;

    ## LISTS
    for my $hash ($data->{hash}->@*) {
        my $list = getAllValuesForKey(
            $data,
            {
              hash        => dclone($hash),
              obj_0       => $data->{objs}->[0],
              obj_1       => $data->{objs}->[1],
              sliceEnable => $solo ? 1 : 0,
            },
        );
        unless ($solo) {
            $list = biFlat(
                $data,
                {
                    list  => $list,,
                    obj_0 => $data->{objs}->[0],
                    obj_1 => $data->{objs}->[1],
                }
            );
        }
        push @lists, $list;
    }

    ## DIFFS
    my $diffs = getDiffs(
        $data,
        {
            hashList => [ @lists ],
            obj_0    => $data->{objs}->[0],
            obj_1    => $data->{objs}->[1],
        }
    );


    return ( $data, $diffs );
}


#===| getAllValuesForKey() {{{2
sub getAllValuesForKey {
    my $data        = shift @_;
    my $ARGS        = shift @_;
    my $hash        = $ARGS->{hash};
    my $sliceEnable = $ARGS->{sliceEnable};
    my $obj_0       = $ARGS->{obj_0};
    my $obj_1       = $ARGS->{obj_1};
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
                            elsif ($key eq 'point')              { delete $part->{$key} }
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
                            elsif ($key eq 'point')              { delete $part->{$key} }
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
    my $obj_0 = $ARGS->{obj_0};
    my $obj_1 = $ARGS->{obj_1};;

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
    my $data = shift @_;
    my $ARGS = shift @_;
    my $hashList = $ARGS->{hashList};
    my $obj_0 = $ARGS->{obj_0};
    my $obj_1 = $ARGS->{obj_1};
        my $ind_0 = 0;
        for my $part_0 ( @{ dclone($hashList->[0]) } ) {
            my $ind_1 = 0;
            for my $part_1  (@{ dclone($hashList->[1]) } ) {
                my @match;
                if ($obj_1) {
                    my $parent = getObjFromGroupNameKey($data, $obj_0);
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


#===| getObjFromGroupNameKey() {{{2
sub getObjFromGroupNameKey {
    # return GROUP_NAME if it is an OBJECT_KEY
    # return OBJECT_KEY that contains GROUP_NAME
    # return '0' if no OBJECT_KEY contains a GROUP_NAME!
    # return '0' if no OBJECTY_KEY contains GROUP_NAME!

    my $data      = shift @_;
    my $dspt      = $data->{dspt}->{deimos};
    my $groupName = shift @_;

    my @keys  = grep { exists $dspt->{$_}->{groupName} } keys $dspt->%*;
    if (scalar @keys) {
        my @match = grep { $dspt->{$_}->{groupName} eq $groupName } @keys;
        if ($match[0]) { return $match[0] }
        else { return 0 }
    }
    else { return 0 }
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

#===| extConvert() {{{2
print extConvert('https://raw.githubusercontent.com/Azuhmier/hmofa/master/archive_7/RbHXR9Rq', $data->{dspt}->{gitIO}),"\n";
sub extConvert {
    my $raw = shift @_;
    my $dspt = shift @_;
    if ($raw =~ m?\Qhttps://raw.githubusercontent.com/Azuhmier/hmofa/master/archive_7/\E.*?) {
        $raw =~ m/(\w{8})$/;
        return $dspt->{$1};
    }
    else { return $raw }
}


#===| init() {{{2
sub init {
    my $data = shift @_;
    $data->{hash} = [ map { getJson($_) } $data->{hash}->@* ];
    $data->{dspt} = { 
        map {
          $_ =~ m/(\w+)\.json$/;
          my $key = $1;
          $key => getJson($_); } $data->{dspt}->@*
    };
    return $data;

}


