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




#------------------------------------------------------
# MAIN {{{1
#------------------------------------------------------
my $masterbin = getJson('./json/masterbin2.json');
my $catalog   = getJson('./json/hmofa2.json');

my $PATTERN = 'STORIES';
#my $PATTERN = 'point';
my $list = getAllValuesForKey($PATTERN, $catalog, 1);
my $list2 = getAllValuesForKey($PATTERN, $masterbin, 1);
my $diffs = getDiffs([$list, $list2]);
print Dumper($diffs);



#------------------------------------------------------
# subroutines {{{1
#------------------------------------------------------

#===| getDiffs() {{{2
sub getDiffs {
    my $hashList = shift @_;
        my $ind_0 = 0;
        for my $part_0 ( @{ dclone($hashList->[0]) } ) {
            my $ind_1 = 0;
            for my $part_1  (@{ dclone($hashList->[1]) } ) {
                my @match = grep { $_ ne 'LN' and  $_ !~ /attrib/ and $_ !~ /raw/} keys $part_1->%*;
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
    my $PATTERN     = shift @_;
    my $var         = shift @_;
    my $sliceEnable = shift @_;
    my $matches;

    ##  HASH?
    if (ref $var eq 'HASH') {
        for my $key (keys $var->%*) {
            if ($key eq $PATTERN) {
                my @catch = $var->{$key}->@*;
                if ($sliceEnable) {
                    for my $part (@catch) {
                        for my $key (keys $part->%*) {
                            if    (ref $part->{$key} eq 'ARRAY') { delete $part->{$key} }
                            elsif ($key eq 'point')              { delete $part->{$key} }
                        }
                    }
                }
                push $matches->@*, @catch;
            }
            else {
                my $catch = getAllValuesForKey($PATTERN, $var->{$key}, $sliceEnable);
                if ($catch) {
                    push $matches->@*, $catch->@*;
                }
            }
        }
    }

    ##  ARRAY?
    elsif (ref $var eq 'ARRAY') {
        for my $part ($var->@*) {
            my $catch = getAllValuesForKey($PATTERN, $part, $sliceEnable);
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
