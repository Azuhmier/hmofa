#! /bin/false
#============================================================
#
#        FILE: Walk.pm
#
#       USAGE: ./Walk.pm
#
#  DESCRIPTION: ---
#
#       AUTHOR: Azuhmier (aka taganon), azuhmier@gmail.com
# ORGANIZATION: ---
#      VERSION: 1.0
#      Created: Mon 10/11/21 10:15:45
#============================================================

package Data::Walk;

use strict;
use 5.004;

use Scalar::Util;

require Exporter;

use vars qw ($VERSION @ISA @EXPORT);

$VERSION = '2.01';
@ISA = qw (Exporter);
@EXPORT = qw (walk walkdepth);

use vars qw ($container $type $seen $address $depth $index $key);

# Forward declarations.
sub walk;
sub walkdepth;
sub __walk;
sub __recurse;

sub walk {
    my ($options, @args) = @_;

    unless (UNIVERSAL::isa($options, 'HASH')) {
        $options = { wanted => $options };
    }

    __walk ($options, @args);
}

sub walkdepth {
    my ($options, @args) = @_;

    unless (UNIVERSAL::isa($options, 'HASH')) {
        $options = { wanted => $options };
    }

    $options->{bydepth} = 1;

    __walk ($options, @args);
}

sub __walk {
    my ($options, @args) = @_;

    $options->{seen} = {};

    local $index = 0;
    for my $item (@args) {
        local ($container, $type, $depth);
        if (ref $item) {
            if (UNIVERSAL::isa ($item, 'HASH')) {
                $container = $item;
                $type = 'HASH';
            } elsif (UNIVERSAL::isa ($item, 'ARRAY')) {
                $container = $item;
                $type = 'ARRAY';
            } else {
                $container = \@args;
                $type = 'ARRAY';
            }
        } else {
            $container = \@args;
            $type = 'ARRAY';
        }
        $depth = 0;
        __recurse $options, $item;
        ++$index;
    }

    return 1;
}

sub __recurse {
    my ($options, $item) = @_;

    ++$depth;

    my @children;
    my $data_type = '';

    local ($container, $type, $address, $seen) = ($container, $type, undef, 0);
    my $ref = ref $item;

    if ($ref) {
        my $blessed = Scalar::Util::blessed($item);

        # Avoid fancy overloading stuff.
        bless $item if $blessed;
        $address = Scalar::Util::refaddr($item);

        $seen = $options->{seen}->{$address}++;

        if (UNIVERSAL::isa ($item, 'HASH')) {
            $data_type = 'HASH';
        } elsif (UNIVERSAL::isa ($item, 'ARRAY')) {
            $data_type = 'ARRAY';
        } else {
            $data_type = '';
        }

        if ('ARRAY' eq $data_type || 'HASH' eq $data_type) {
            local $index = -1;
            local $type = $data_type;
            local $container = $item;

            if ('ARRAY' eq $data_type) {
                @children = $item->@[1..$item->$#*];
            } else {
                @children = $item->{childs}->%*;
            }

            if ('ARRAY' eq $data_type) {
                @children = $options->{preprocess} (@{$item})
                        if $options->{preprocess};
            } else {
                local $container = \@children;
                @children = $options->{preprocess} (@children)
                        if $options->{preprocess};
                @children = $options->{preprocess_hash} (@children)
                        if $options->{preprocess_hash};
            }
        } else {
            $data_type = '';
        }

        # Recover original object state.
        bless $item, $ref if $blessed;
    }

    unless ($options->{bydepth}) {
        local $_ = $item;
        $options->{wanted}->($item);
    }

    if (@children && ($options->{follow} || !$seen)) {
        local ($container, $type, $index);
        $type = $data_type;
        $container = $item;
        $index = 0;

        for my $child (@children) {
            if ($type eq 'HASH' && $index & 1) {
                $key = $children[$index - 1];
            } else {
                undef $key;
            }
            __recurse $options, $child;
            ++$index;
        }
    }

    if ($options->{bydepth}) {
        local $_ = $item;
        $options->{wanted}->($item);
    }

    if ($data_type) {
        local ($container, $type, $index) = ($item, $data_type, -1);
        $options->{postprocess}->() if $options->{postprocess};
    }

    --$depth;
    # void
}


1;
