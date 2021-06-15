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
use List::MoreUtils qw(uniq);
use Array::Diff;
use List::Util;
use Array::Utils;
use Data::Compare;
use Data::Structure::Util;
## NOT WORKING
#use Data::Diff;
#use Data::Match;


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
delegate(
    $data,
    {
        objs => ['series'],
        process => {
            disableDiffs => 1,
        },
    },
);


# ===| relative listing #1: Author and Stories {{{2
delegate(
    $data,
    {
        objs => ['author', 'title'],
        process => {
            disableDiffs => 1,
        },
    },
);


# ===| relative listing #2: Only show obj_1 additions {{{2


# ===| List with External Data: gitIO.json {{{2
delegate(
    $data,
    {
        objs  => ['url'],
        sub_0 => genFilter({
                    pattern => qr?\Qhttps://raw.githubusercontent.com/Azuhmier/hmofa/master/archive_7/\E(\w{8})?,
                    dspt    => $data->{dspt}->{gitIO},
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
                    dspt    => $data->{dspt}->{gitIO},
        }),
        process => {
            disableDiffs => 1,
        },
    },
);


# ===| Exstended listing #1: Excluding object instances based on user specified pattern  {{{2


# ===| Exstended listing #2: Custom Sort  {{{2


# ===| Complex listing #1: attributes  {{{2


# ===| TEST {{{2

my $catalog   = $data->{hash}->[0]->{SECTIONS}->[1]->{ getName('author', $data->{dspt}->{deimos} ) };
my $masterbin = $data->{hash}->[1]->{AUTHORS};
my $sub = genFilter({
            pattern => qr?\Qhttps://raw.githubusercontent.com/Azuhmier/hmofa/master/archive_7/\E(\w{8})?,
            dspt    => $data->{dspt}->{gitIO},
});

use Data::Walk;
    my $max_depth = 20;
    sub not_too_deep {
        if ($Data::Walk::depth > $max_depth) {
        return ();
        } else {
        return @_;
        }
    }
    my @array;
    sub do_something {
        #NOTE: $Data::Walk::index is even then $_ is a hash key. If it is odd, then $_ is a hash value.
        #print "---------------\n";
        if ($Data::Walk::type eq 'HASH') {
            if ( ($Data::Walk::index % 2 == 0) and $_ eq 'SERIES') {
                 my $hash = $Data::Walk::container;
                 my @stories;
                 for my $part ($hash->{SERIES}->@*) {
                     push @stories, $part->{STORIES}->@*;
                 }
                 unless (exists $hash->{STORIES}) {$hash->{STORIES} = []}
                 push $hash->{STORIES}->@*, @stories;
                 delete $hash->{SERIES};
            }
            if ( ($Data::Walk::index % 2 == 0) and $_ eq 'TAGS') {
                 my $hash = $Data::Walk::container;
                 delete $hash->{TAGS};
            }
            if ( ($Data::Walk::index % 2 == 0) and $_ eq 'DESCRIPTIONS') {
                 my $hash = $Data::Walk::container;
                 delete $hash->{DESCRIPTIONS};
            }
            if ( ($Data::Walk::index % 2 == 0) and $_ eq 'LN') {
                 my $hash = $Data::Walk::container;
                 delete $hash->{LN};
            }
            if ( ($Data::Walk::index % 2 == 0) and $_ eq 'raw') {
                 my $hash = $Data::Walk::container;
                 delete $hash->{raw};
            }
            if ( ($Data::Walk::index % 2 == 0) and $_ eq 'url') {
                 my $hash = $Data::Walk::container;
                 $hash->{url} = $sub->($hash->{url});
            }
            if ( ($Data::Walk::index % 2 == 0) and $_ eq 'point') {
                 my $hash = $Data::Walk::container;
                 push @array, $hash->{point};
                 delete $hash->{point};
            }
        }
    }
    walkdepth { wanted => \&do_something, preprocess => \&not_too_deep }, $masterbin;
    print $_,"\n" for sort {$a cmp $b} uniq(@array);
    @array = ();
    walkdepth { wanted => \&do_something, preprocess => \&not_too_deep }, $catalog;
    print $_,"\n" for sort {$a cmp $b} uniq(@array);

use Deep::Hash::Utils;
    {
      local $\ = "\n";
      while (my @list = Deep::Hash::Utils::reach($masterbin)) {
          print "@list";
      }
    }

use Hash::Diff;
    #my %c = %{ Hash::Diff::diff( $data->{hash}->[0], $data->{hash}->[1] ) };
    #print Dumper \%c;

use Data::Search;
    #$Data::Dumper::Useqq=1;
    #$Data::Dumper::Terse=1;
    #for my $wanted ( qw( point ) ) {
    #    my @results = Data::Search::datasearch(
    #        data   => $data->{hash}->[0],
    #        search => 'keys',
    #        find   => qr{ \A $wanted \z }msx,
    #        return => 'container',
    #    );
    #
    #    #print "Found key '$wanted' in these hashrefs: ", Dumper @results;
    #}

use Data::Find;

# subroutines {{{1
#------------------------------------------------------

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


#------------------------------------------------------
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
    my $obj_0       = getName($ARGS->{obj_0}, $data->{dspt}->{deimos});
    my $obj_1       = getName($ARGS->{obj_1}, $data->{dspt}->{deimos});
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
    my $obj_0       = getName($ARGS->{obj_0}, $data->{dspt}->{deimos});
    my $obj_1       = getName($ARGS->{obj_1}, $data->{dspt}->{deimos});

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
    my $obj_0    = getName($ARGS->{obj_0}, $data->{dspt}->{deimos});
    my $obj_1    = getName($ARGS->{obj_1}, $data->{dspt}->{deimos});
    my $sub_0    = $ARGS->{sub_0};

    my $ind_0 = 0;
    my @parts_0 = @{ dclone($hashList->[0]) };
    my @parts_1 = @{ dclone($hashList->[1]) };

    my $child;
    if ($obj_1) { $child  = getObjFromGroupNameKey($data, $obj_1); }
    else        { $child  = getObjFromGroupNameKey($data, $obj_0); }

    @parts_0 = sort { $a->{$child} cmp $b->{$child} } @parts_0;
    @parts_1 = sort { $a->{$child} cmp $b->{$child} } @parts_1;
    for my $part_0 (@parts_0) {

        my $ind_1 = 0;
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


#===| getName() {{{2
sub getName {
    my $obj  = shift @_;
    if ($obj) {
        my $dspt = shift @_;
        my $name = $dspt->{$obj}->{groupName};
        return ($name) ? $name
                       : $obj;
    }
    else { return 0 }
}



