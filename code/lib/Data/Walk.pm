#! /bin/false

# Traverse Perl data structures.
# Copyright (C) 2005-2016 Guido Flohr <guido.flohr@cantanea.com>,
# all rights reserved.

# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU Library General Public License as published
# by the Free Software Foundation; either version 2, or (at your option)
# any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Library General Public License for more details.

# You should have received a copy of the GNU Library General Public
# License along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307,
# USA.

package Data::Walk;

use strict;
use 5.004;

use Scalar::Util;

require Exporter;

use vars qw ($VERSION @ISA @EXPORT);

$VERSION = '2.01';
@ISA     = qw (Exporter);
@EXPORT  = qw (walk walkdepth);

use vars qw (
    $address
    $container
    $depth
    $index
    $key
    $seen
    $type
);

# Forward declarations.
sub walk;
sub walkdepth;
sub __walk;
sub __recurse;

## WALK
sub walk {
    my ($options, @args) = @_;
    unless (UNIVERSAL::isa($options, 'HASH')) { $options = { wanted => $options } }
    __walk ($options, @args);
}

## WALKDEPTH
sub walkdepth {
    my ($options, @args) = @_;
    unless (UNIVERSAL::isa($options, 'HASH')) { $options = { wanted => $options } }
    $options->{bydepth} = 1;
    __walk ($options, @args);
}

sub __walk {
    local $index         = 0;
    my ($options, @args) = @_;
    $options->{seen}     = {};

    for my $item (@args) {
        local ($container, $type, $depth);
        if (ref $item) {
            if ( UNIVERSAL::isa ($item, 'HASH') ) {
                $container = $item;
                $type      = 'HASH';
            } elsif ( UNIVERSAL::isa ($item, 'ARRAY') ) {
                $container = $item;
                $type      = 'ARRAY';
            } else {
                $container = \@args;
                $type      = 'ARRAY';
            }
        } else {
            $container = \@args;
            $type      = 'ARRAY';
        }
        $depth = 0;
        __recurse $options, $item;
        ++$index;
    }

    return 1;
}

sub __recurse {
    local ($container, $type, $address, $seen) = ($container, $type, undef, 0);
    my ($options, $item)                       = @_;
    my $ref                                    = ref $item;
    my $data_type                              = '';
    my @children;

    ++$depth;

    if ($ref) {
        my $blessed = Scalar::Util::blessed($item);
        bless $item if $blessed; # Avoid fancy overloading stuff.
        $address = Scalar::Util::refaddr($item);
        $seen    = $options->{seen}->{$address}++;
        #print "    $address $options->{seen}->{$address}\n";


        if    ( UNIVERSAL::isa ($item, 'HASH')  ) { $data_type = 'HASH' }
        elsif ( UNIVERSAL::isa ($item, 'ARRAY') ) { $data_type = 'ARRAY'}
        else                                      { $data_type = ''     }


        ## PREPROCESS
        if ('ARRAY' eq $data_type || 'HASH' eq $data_type) {
            local ($index, $type, $container) = (-1, $data_type, $item);

            if ('ARRAY' eq $data_type) { @children = @{$item} }
            else                       { @children = %{$item} }
            #if ((grep {$_ eq "Storytime with Coyote"} @children)[0]) {
            #  print "[$address $options->{seen}->{$address}]";
            #  print "    Storytime with Coyote\n";
            #  print "    $item\n";

            #}
            #if ((grep {$_ eq "The Witch's Ball"} @children)[0]) {
            #  print "[$address $options->{seen}->{$address}]";
            #  print "    The Witch's Ball\n";
            #  print "    $item\n";

            #}
            if ('ARRAY' eq $data_type) {
                @children = $options->{preprocess}      (@{$item})  if $options->{preprocess};
            } else {
                local $container = \@children;
                @children = $options->{preprocess}      (@children) if $options->{preprocess};
            }

        } else { $data_type = '' }

        # Recover original object state.
        bless $item, $ref if $blessed;
    }

    ## WANTED and RECURSION
    unless ($options->{bydepth}) { local $_ = $item; $options->{wanted}->($item); }
    if (@children && ($options->{follow} || !$seen)) {
        local ($container, $type, $index);
        $type      = $data_type;
        $container = $item;
        $index     = 0;

        foreach my $child (@children) {
            if ($type eq 'HASH' && $index & 1) { $key = $children[$index - 1] }
            else                               { undef $key }
            __recurse $options, $child;
            ++$index;
        }
    }
    if ($options->{bydepth}) { local $_ = $item; $options->{wanted}->($item); }

    --$depth;
    # void
}


1;
