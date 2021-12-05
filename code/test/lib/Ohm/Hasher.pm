#============================================================
#
#        FILE: Hasher.pm
#
#       USAGE: ./Hasher.pm
#
#  DESCRIPTION: ---
#
#       AUTHOR: Azuhmier (aka taganon), azuhmier@gmail.com
# ORGANIZATION: ---
#      VERSION: 1.0
#      Created: Thu 10/28/21 10:15:17
#============================================================
package Ohm::Hasher;
use strict;
use warnings;
use File::Basename;
use Storable qw(dclone);
use Cwd;
use Carp qw(croak carp);
use JSON::XS;
use lib ($ENV{HOME}.'/hmofa/hmofa/code/test/lib');
use Data::Walk;
my $erreno;

sub new { #{{{1
    my ( $class, @args ) = @_;
    my $self = bless {}, $class;
    $self->__init( \@args );
    $self->__gen_dspt();
    $self->__check_matches();
    return $self;
}

sub get_sum { #{{{1
    my ( $self, $args ) = @_;
    #__checkChgArgs($prsv,'HASH','hash');
    #dspt, drsr, matches, circs, hash, stdout

    my $copy = dclone $self;

    # DSPT
    if ($copy->{dspt}) {
        my $dspt = $copy->{dspt};
        for my $obj (keys %$dspt) {
            my $str = '';
            for my $key (sort keys $dspt->{$obj}->%*) {
                my $value = $dspt->{$obj}{$key};
                my $ref   = ref $value;
                if ($ref eq 'ARRAY') {
                } elsif ($ref eq 'HASH') {
                    $value = '['.(join ',', sort keys %$value).']';
                }

                $str .= ';'.$key.':'.($value // 'n/a').'; ';
            }
            $dspt->{$obj} = $str;
        }
        $copy->{dspt} = $dspt;
    }

    # MATCHES
    if ($copy->{matches}) {
        my $matches = $copy->{matches};
        $matches->{miss}      = scalar $matches->{miss}->@*;
        $matches->{obj_count} = scalar keys $matches->{objs}->%*;
        $matches->{objs}{$_}  = scalar $matches->{objs}{$_}->@* for keys $matches->{objs}->%*;
        $copy->{matches}      = $matches;
    }

    # META
    # MATCHES
    if ($copy->{meta}) {
        my $meta = $copy->{meta};
        $meta->{dspt}{ord_map} = scalar keys $meta->{dspt}{ord_map}->%*;
        $copy->{meta} = $meta;
    }



    return $copy;
}

sub chg_dspt { #{{{1
    my ( $self, $paths_dspt ) = @_;
    __checkChgArgs($paths_dspt,'','string scalar');
    $self->{paths}{dspt} = $paths_dspt;
    return $self;
}

sub chg_drsr { #{{{1
    my ( $self, $paths_drsr ) = @_;
    __checkChgArgs($paths_drsr,'','string scalar');
    $self->{paths}{drsr} = $paths_drsr;
    return $self;
}

sub chg_name { #{{{1
    my ( $self, $name ) = @_;
    __checkChgArgs($name,'','string scalar');
    $self->{name} = $name;
    return $self;
}

sub chg_output { #{{{1
    my ( $self, $paths_output ) = @_;
    __checkChgArgs($paths_output,'','string scalar');
    $self->{paths}{output} = $paths_output;
    return $self;
}

sub chg_prsv { #{{{1
    my ( $self, $prsv ) = @_;
    __checkChgArgs($prsv,'HASH','hash');
    $self->{prsv} = $prsv;
    return $self;
}

sub __init { #{{{1
    my ( $self, $args ) = @_;
    my $class = ref $self;
    unless (UNIVERSAL::isa($args->[0], 'HASH')) {
        $args->[0] = {
            input => $args->[0],
            dspt => $args->[1],
            drsr => $args->[2],
            prsv => $args->[3],
        };
    }
    my %args  = $args->[0]->%*; # make a shallow copy

    #%--------PATHS--------#% {{{2
    # CHECK INPUT
    my $input = delete $args{input};
    __checkChgArgs($input,'','string scalar');
    $self->{paths}{input} = $input;

    # CHECK DSPT
    my $paths_dspt = delete $args{dspt};
    __checkChgArgs($paths_dspt,'','string scalar');
    $self->{paths}{dspt} = $paths_dspt;

    # CHECK OUTPUT
    my $output = delete $args{output};
    unless ( defined $output ) {
        $output = getcwd;
    } $self->{paths}{output} = $output;

    # CHECK DRSR
    my $paths_drsr = delete $args{drsr};
    $self->{paths}{drsr} = $paths_drsr;

    #%--------OTHER ARGS--------#% {{{2
    # CHECK NAME
    my $name = delete $args{name};
    unless ( defined $name ) {
        my $fname = basename($self->{paths}{input});
        $name = $fname =~ s/\..*$//r;
    } $self->{name} = $name;

    # CHECK PRSV
    my $prsv = delete $args{prsv};
    $self->{prsv} = $prsv;

    # CHECK PARAMS
    my $params = delete $args{params};
    my $defaults = {
        attribs  => '01',
        delims   => '01',
        prsv     => '01',
        mes      => '01',
    };
    $defaults->{$_} = $params->{$_} for keys %$params;
    $self->{params} = $defaults;

    #%--------NON ARGS--------#% {{{2
    # CHECK KEYS
    if ( my $remaining = join ', ', keys %args ) {
        croak("Unknown keys to $class\::new: $remaining");
    }

    # SET PROPERTIES
    $self->{debug} = [];
    $SIG{__DIE__} = sub {
        print $_ for $self->{debug}->@*;
        print $erreno if $erreno;
    }; #}}}

}

sub __check_matches { #{{{1
    # have option presverses be 2nd option
    my ( $self, $args ) = @_;

    # without the 'g' modifier and the array context the regex exp will return
    # a boolean instead of the first match
    my ($fext) = $self->{paths}{input} =~ m/\.([^.]*$)/g;

    $self->{matches} = {} unless exists $self->{matches};
    if ($fext eq 'txt') {
        $self->__get_matches;
    } elsif ($fext eq 'json') {
        $self->__gen_matches;
    } else { die "$fext is not a valid file extesion, must either be 'txt' or 'json'" }

    return $self;
}

sub __gen_dspt { #{{{1

    my ( $self, $args ) = @_;

    my $dspt = do {
        open my $fh, '<', $self->{paths}{dspt};
        local $/;
        decode_json(<$fh>);
    };

    $dspt->{lib} = { order =>'0'};
    $dspt->{prsv} = { order =>'-1'};

    ## --- Generate Regexs
    for my $obj (keys %$dspt) {

        my $objDSPT = $dspt->{$obj};
        for my $key (keys %$objDSPT) {
            if ($key eq 're') { $objDSPT->{re} = qr/$objDSPT->{re}/ }
            if ($key eq 'attr') {

                my $dspt_attr = $objDSPT->{attr};
                for my $attr (keys %$dspt_attr) {
                    $dspt_attr->{$attr}[0] = qr/$dspt_attr->{$attr}[0]/;
                    if (scalar $dspt_attr->{$attr}->@* >= 3) {
                        my $delims = join '', $dspt_attr->{$attr}[2][0];
                        $dspt_attr->{$attr}[3] = ($delims ne '') ? qr{\s*[\Q$delims\E]\s*}
                                              : '';
                    }
                }
            }
        }
    }

    ## --- VALIDATE
    # check for duplicates: order
    my @keys  =
        sort
        map {
            exists $dspt->{$_}{order}
                and
            $dspt->{$_}{order}
        } keys %{$dspt};
    my %dupes;
    for (@keys) { die "Cannot have duplicate reserved keys!" if $dupes{$_}++ }

    ## --- META
    # max
    my @orders = grep { defined } map {$dspt->{$_}{order}} keys %$dspt;
    $self->{meta}{dspt}{ord_max} = (
        sort {
            length $b <=> length $a
                ||
            substr($b, -1) <=> substr($a, -1);
        } @orders
    )[0];

    # limit
    my @pntstr = split /\./, $self->{meta}{dspt}{ord_max};
    $pntstr[$#pntstr]++;
    $self->{meta}{dspt}{ord_limit} = join '.', @pntstr;

    # ordMap
    $self->{meta}{dspt}{ord_map}->%* =
        map  {$dspt->{$_}{order} => $_}
        grep {exists $dspt->{$_}{order} }
        keys %$dspt;

    # drsr
    my $drsr = do {
        open my $fh, '<', $self->{paths}{drsr}
            or die;
        local $/;
        decode_json(<$fh>);
    };
    for my $obj (keys %$drsr) {
        $dspt->{$obj} // die;
        $dspt->{$obj}{drsr} = $drsr->{$obj};
        for my $attr (grep {$_ ne $obj} keys $drsr->{$obj}->%*) {
            $dspt->{$obj}{attr}{$attr} // die "$attr for $self->{name}" ;

        }
    }

    $self->{dspt} = $dspt;

    return $self;
}


sub __sweep { #{{{1

    my ( $self, $subs ) = @_;

    $self->{m} = exists $self->{m} ?die " key 'm' is already defined "
                                   :{};

    walk (
        {
            wanted => sub {
                for my $sub (@$subs) {
                    $sub->();
                }
            },
            preprocess => sub {
                my @children = @_;
                my $type = $Data::Walk::type;
                if ($type eq 'HASH') {
                } elsif ($type eq 'ARRAY') {
                }
                return @children;
            },
        }, $self->{hash} // die " No hash has been loaded for object '$self->{name}'"
    );

    delete $self->{m};
    return $self;
}

sub __genReff { #{{{1

    my ( $self, $args ) = @_;

    $self->{m}{genReff} = exists $self->{genReff} ?die " key 'genReff' is already defined "
                                                  :{};
    $self->{m}{genReff}{seen} = {} unless exists $self->{m}{genReff}{seen};
    my $seen = $self->{m}{genReff}{seen};

    my $item      = $_;
    my $container = $Data::Walk::container;

    if (ref $item eq 'HASH') {
        my $obj = $item->{obj} // 'NULL'; # need to have NULL be
                                          # error or something
        my $type      = $Data::Walk::type;
        my $index     = $Data::Walk::index;

        $seen->{$obj}++;
        $item->{circ}{'.'}   = $item;
        $item->{circ}{'..'}  = $container // 'NULL';

    } elsif (ref $_ eq 'ARRAY'){
        unshift @$_, {
            '.'   => $_,
            '..'  => $container // 'NULL',
        };
    }
}

sub __gen_reffs { #{{{1
    my ( $self, $args ) = @_;
    return $self;
}

sub __gen_matches { #{{{1

    my ( $self, $args ) = @_;

    $self->{m}{genMatches} = exists $self->{genMatches} ?die " key 'genMatches' is already defined "
                                                        :{};
    $self->{m}{genMatches}{seen} = {} unless exists $self->{m}{genReff}{seen};
}

sub __genWrite { #{{{1
    my ( $self, $args ) = @_;

    my $dspt = $self->{dspt};
    $self->{m}{prevDepth} = '';
    $self->{m}{prevObj} = 'NULL';

    walk(
        {
            wanted => sub {
                my $item       = $_;
                my $container  = $Data::Walk::container;
                if (ref $item eq 'HASH' && $item->{obj} ne 'lib') {
                    my $obj = $item->{obj};

                    my $drsr       = $self->{dspt}{$obj}{drsr};
                    my $depth      = $Data::Walk::depth;
                    my $str        = '';

                    ## --- String: d0, d1 #{{{3
                    if (ref $item->{val} ne 'ARRAY') {
                        $str .= $drsr->{$obj}[0]
                             .  $item->{val}
                             .  $drsr->{$obj}[1];
                    }

                    ## --- Attributes String: d0, d1, d2, d3, d4{{{3
                    my $attrStr = '';
                    # this should be solved in sweep
                    my $attrDspt = $dspt->{$obj}{attr};
                    if ($attrDspt) {
                        for my $attr (
                            sort {
                                $attrDspt->{$a}[1]
                                    cmp
                                $attrDspt->{$b}[1]
                            } keys %$attrDspt
                        ) {

                            ## Check existence of attributes
                            if (exists $item->{attr}{$attr}) {
                                my $attrItem = $item->{attr}{$attr} // '';

                                ## Item Arrays
                                if (exists $attrDspt->{$attr}[2]) {
                                    my @itemPartArray = ();
                                    for my $part (@$attrItem) {
                                        $part = $drsr->{$attr}[2]
                                              . $part
                                              . $drsr->{$attr}[3];
                                        push @itemPartArray, $part;
                                    }
                                    $attrItem = join $drsr->{$attr}[4], @itemPartArray;
                                }

                                $attrStr .= $drsr->{$attr}[0]
                                         .  $attrItem
                                         .  $drsr->{$attr}[1];

                            }
                        }
                    }

                    ## --- Line Striping: d5,d6 #{{{3
                    my $F_empty;
                    if (exists $drsr->{$obj}[5] and $self->{m}{prevDepth}) {

                        my $prevObj   = $self->{m}{prevObj};
                        my $prevDepth = $self->{m}{prevDepth};

                        my $ref = ref $drsr->{$obj}[5];
                        my $tgtObjs = ($ref eq 'HASH') ?$drsr->{$obj}[5]
                                                       :0;

                        ## strip lines only after target object
                        if ($tgtObjs && exists $tgtObjs->{$prevObj}) {
                            my $cnt = $tgtObjs->{$prevObj};

                            # descending lvl
                            if ($prevDepth < $depth) {
                                $str =~ s/.*\n// for (1 .. $cnt);
                                $F_empty = 1 if $str eq '';
                            }

                            # ascending lvl
                            elsif ($prevDepth > $depth) {
                                $str =~ s/.*\n// for (1 .. $cnt);
                            }

                            # maintaining lvl
                            elsif ($prevDepth == $depth) {

                                # Preserve
                                if ($obj eq 'prsv') {
                                    $str =~ s/.*\n// for (1 .. $cnt);
                                }

                                # Post Preserve
                                elsif ($prevObj eq 'prsv') {
                                    $str =~ s/.*\n// for (1 .. $cnt);
                                }
                            }
                        }

                        ## strip lines after all objects
                        # descending lvl
                        elsif (!$tgtObjs and $prevDepth < $depth) {
                            my $cnt = $drsr->{$obj}[5];
                            $str =~ s/.*\n// for (1 .. $cnt);
                        }

                    }

                    ## --- String Concatenation {{{3
                    $str = ($str) ?$str . $attrStr
                                  :$attrStr;
                    chomp $str if $obj eq 'prsv';

                    #}}}
                    unless ($F_empty) { push $self->{stdout}->@*, $str if $obj ne 'lib'}
                    $self->{m}{prevDepth} = $depth;
                    $self->{m}{prevObj}   = $obj;
                }
            },
            preprocess => sub {
                my $type = $Data::Walk::type;
                my @children = @_;

                if ($type eq 'HASH') {
                    my @values   = map {$children[$_]} grep {$_ & 1} (0..$#children);
                    my @keys = map {$children[$_]} grep {!($_ & 1)} (0..$#children);
                    my @var    = map {[$keys[$_],$values[$_]]} (0..$#keys);
                    @children =
                        map {@$_}
                        sort {
                            if (scalar (split /\./, $dspt->{$b->[0]}{order}) != scalar (split /\./,$dspt->{$a->[0]}{order})) {
                                join '', $dspt->{$b->[0]}{order} cmp join '', $dspt->{$a->[0]}{order}
                            } else {
                                join '', $dspt->{$a->[0]}{order} cmp join '', $dspt->{$b->[0]}{order}
                            }
                        }
                        @var;
                }
                return @children;
            },
        },
        $self->{result}
    );
    return $self;
}
sub __get_matches { #{{{1
    my ( $self, $args ) = @_;
    my $dspt = $self->{dspt};

    ## --- open tgt file for regex parsing
    open my $fh, '<', $self->{paths}{input}
        or die $!;
    {
        my $FR_prsv = {
            cnt => 0,
            F   => 1,
        };

        while (my $line = <$fh>) {

            ## --- OBJS
            my $match;
            for my $obj (keys %$dspt) {
                $self->{matches}{objs}{$obj} = [] unless exists $self->{matches}{objs}{$obj};

                my $regex = $dspt->{$obj}{re} // 0;
                if ($regex and $line =~ $regex) {

                    last if _isPrsv($self,$obj,$1,$FR_prsv);

                    $match = {
                        obj => $obj,
                        val => $1,
                        meta => {
                            raw => $line,
                            LN  => $.,
                        },
                    }; push $self->{matches}{objs}{$obj}->@*, $match;
                }
            }
            ## --- PRESERVES
            if (!$match and _isPrsv($self,'NULL','',$FR_prsv)) {
                $self->{matches}{objs}{prsv} = [] unless exists $self->{matches}{objs}{prsv};
                $match = {
                    obj => 'prsv',
                    val => $line,
                    meta => {
                        LN  => $.,
                    },
                }; push $self->{matches}{objs}{prsv}->@*, $match;

            ## --- MISS
            } elsif (!$match) {
                $self->{matches}{miss} = [] unless exists $self->{matches}{miss};
                $match = {
                    obj => 'miss',
                    val => $line,
                    meta => {
                        LN  => $.,
                    },
                }; push $self->{matches}{miss}->@*, $match;
            }
        }
    } close $fh ;

    ## -- subroutnes
    sub _isPrsv { #{{{
        my ($self, $obj, $match, $FR_prsv) = @_;
        my $dspt = $self->{dspt};

        if ( $self->{prsv} and $obj eq $self->{prsv}{till}[0] ) {
            $FR_prsv->{F} = 0, if $FR_prsv->{cnt} eq $self->{prsv}{till}[1];
            $FR_prsv->{cnt}++
        }

        return $FR_prsv->{F};
    } #}}}
    return $self;
}

sub __checkChgArgs { #{{{1
    my ($arg, $cond, $type) = @_;
    unless ( defined $arg ) {
        croak( (caller(1))[3] . " requires an input" );
    } elsif (ref $arg ne $cond) {
        croak( (caller(1))[3] . " requires a $type" );
    }
} #}}}

1;
