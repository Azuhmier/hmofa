#!/usr/bin/env perl

#============================================================
#
#         FILE: jsonCombine.pl
#        USAGE: ./genJson.pl
#  DESCRIPTION: ---
#       AUTHOR: Azuhmier (aka taganon), azuhmier@gmail.com
#      Created: Wed 06/23/21 12:03:43
#============================================================

use warnings;
use strict;
use JSON::PP;
use Data::Dumper;
use Storable qw(dclone);

#  Assumptions

# MAIN {{{1
#------------------------------------------------------
{
    my $data = init({
        fileNames => {
            fname  => [
                './json/catalog.json',
                './json/masterbin.json',
            ],
            output => './json/hmofa_lib.json',
            dspt   => './json/deimos.json',
            external => [
                './json/gitIO.json'
            ],
        },
        process => {
            write => 1,
        },
        sort    => 1,
        verbose => 0,
    });

    my $catalog = $data->{hash}->[0]->{SECTIONS}->[1];
        my $catalog_contents = dclone $catalog;
        $catalog             = {};
        $catalog->{contents} = $catalog_contents;
        $catalog->{reff}     = $catalog;
        $catalog->{contents}->{libName}  = 'catalog';
        delete $catalog->{contents}->{section};

    my $masterbin = $data->{hash}->[1]->{SECTIONS}->[1];
        my $masterbin_contents = dclone $masterbin;
        $masterbin             = {};
        $masterbin->{contents} = $masterbin_contents;
        $masterbin->{reff}     = $masterbin;
        $catalog->{contents}->{libName}  = 'masterbin';

    my $sub = genFilter({
        pattern => qr?\Qhttps://raw.githubusercontent.com/Azuhmier/hmofa/master/archive_7/\E(\w{8})?,
        dspt    => $data->{external}->{gitIO},
    });

    use Data::Walk;

        sub walker {
            my $type      = $Data::Walk::type;
            my $index     = $Data::Walk::index;
            my $container = $Data::Walk::container;
            if ($type eq 'HASH') {
                deleteKey( $_, 'LN',     $index, $Data::Walk::container);
                deleteKey( $_, 'raw',    $index, $Data::Walk::container);
                deleteKey( $_, 'test33', $index, $Data::Walk::container);
                deleteKey( $_, 'test3',  $index, $Data::Walk::container);
                deleteKey( $_, 'test',   $index, $Data::Walk::container);
                filter   ( $_, 'url',    $index, $Data::Walk::container, $sub);
            }
        }

        sub walker2 {
            my $type      = $Data::Walk::type;
            my $index     = $Data::Walk::index;
            my $container = $Data::Walk::container;
            if ($type eq 'HASH') {
                deleteKey ( $_, 'LN',                $index, $container);
                deleteKey ( $_, 'raw',               $index, $container);
                removeKey( $_, 'SERIES', 'STORIES', $index, $container);
                deleteKey ( $_, 'url_attribute',               $index, $container);
                #deleteKey ( $_, 'URLS',               $index, $container);
                #deleteKey ( $_, 'TAGS',               $index, $container);
                filter    ( $_, 'url',               $index, $container, $sub);
            }
        }

        walkdepth { wanted => \&walker} ,  $masterbin->{contents};
        walkdepth { wanted => \&walker2}, $catalog->{contents};
        sortHash($data,$catalog);
        sortHash($data,$masterbin);
        combine( $data, $masterbin, $catalog );
        #combine( $data, $catalog, $masterbin );
        #combine( $data, $catalog, $catalog );
        encodeResult($data, dclone($masterbin->{contents}));
}


# SUBROUTINES {{{1
#------------------------------------------------------

#===| init() {{{2
sub init {
    my $data = shift @_;
    $data->{hash} = [ map { getJson($_) } $data->{fileNames}->{fname}->@* ];
    $data->{dspt} = getJson($data->{fileNames}->{dspt});
    $data->{external} = {
        map {
          $_ =~ m/(\w+)\.json$/;
          $1 => getJson($_);
        } $data->{fileNames}->{external}->@*
    };
    validate_Dspt( $data );
    return $data;
}


#===| combine() {{{2
sub combine {
    no warnings 'uninitialized';
    my $data   = shift @_;
    my $hash_0 = shift @_;
    my $hash_1 = shift @_;
    #$Data::Dumper::Maxdepth = 2;
    $data->{reff2} = [ $hash_0->{contents} ];
    $data->{reff}  = [ $hash_1->{contents} ];

    # ===|| preprocess->() {{{3
    my $preprocess = sub {

        ##
        my @children = @_;
        my $lvl      = $Data::Walk::depth - 2;
        my $type     = $Data::Walk::type;

        ## Pre HASH
        if ($type eq 'HASH') {
            unless (exists $data->{pointer}) { $data->{pointer} = [0] }
            else {
                unless (exists $data->{pointer}->[$lvl]) { $data->{pointer}->[$lvl] = 0 }
                else                                     { $data->{pointer}->[$lvl]++ }
            }

            my $lvlReff  = $data->{reff}->[$lvl];
            my $lvlReff2 = $data->{reff2}->[$lvl];
            my $container; my $cnt = 0; for my $part (@children) {
                if ($cnt & 1) { $container->{ $children[$cnt - 1] } = $part }
                $cnt++;
            }

            my $obj = getLvlObj($data, $container);
            my $vaar = scalar @{$data->{pointer}} ? ( scalar @{$data->{pointer}} ) - 1 : 0;
            my $index   = $data->{pointer}->[$lvl];
            print "\nPRE ".$obj."-".$type." ".$vaar." $index\n";
            print "  PointStr: ".join('.', $data->{pointer}->@*),"\n";

            my $hash_1 = $container;
            my $hash_2 = $lvlReff; if (ref $lvlReff eq 'ARRAY') {
                my $key  = $obj;
                my $key2 = ( exists $lvlReff->[$index]->{$key} ) ? $key : ' ';
                print "  Key_1: $key\n";
                print "  Key_2: $key2\n";
                print "  Value_1: $container->{$key}\n";
                print "  Value_2: $lvlReff->[$index]->{$key}\n";
                $hash_2 = $lvlReff->[$index];
            }

            if (join('.', $data->{pointer}->@*) =~ '0.1.0') {print Dumper $hash_1}
            if (join('.', $data->{pointer}->@*) =~ '0.1.0') {print Dumper $hash_2}
            #COMBINE KEYS
            my @keys_1 = sort {lc $a cmp lc $b} keys %{$hash_1};
            my @keys_2 = sort {lc $a cmp lc $b} keys %{$hash_2};
            while (scalar @keys_1 or scalar @keys_2) {
                my $bool = lc $keys_1[0] cmp lc $keys_2[0];
                if (!$keys_1[0]) {
                    unshift @keys_1, $keys_2[0];
                    $hash_1->{$keys_2[0]} = $hash_2->{$keys_2[0]};
                } elsif (!$keys_2[0]) {
                    unshift @keys_2, $keys_1[0];
                    $hash_2->{$keys_1[0]} = $hash_1->{$keys_1[0]};
                } elsif ($bool and $bool != -1) {
                    unshift @keys_1, $keys_2[0];
                    $hash_1->{$keys_2[0]} = $hash_2->{$keys_2[0]};
                } elsif ($bool == -1) {
                    unshift @keys_2, $keys_1[0];
                    $hash_2->{$keys_1[0]} = $hash_1->{$keys_1[0]};
                } else {
                    shift @keys_1;
                    shift @keys_2;
                }
            }

            #if ($lvl != -1) {
            #    $lvlReff->[$index]->%* = $hash_2->%*;
            #    $lvlReff2->[$index]->%* = $hash_1->%*;
            #}

            undef @children;
            for my $key (sort keys %{$hash_1}) {
                push @children, ($key, $hash_1->{$key});
            }
            return @children;

        ## Pre ARRAY
        } elsif ($type eq 'ARRAY') {
            my $index      = $data->{pointer}->[$lvl];
            my $lvlReff    = $data->{reff}->[$lvl+1];
            my $lvlReff2   = $data->{reff2}->[$lvl+1];

            my $flag1; if (!$lvlReff)  {$flag1 = 1}
            my $flag2; if (!$lvlReff2) {$flag2 = 2}
            if ($flag1 && $flag2) {
                die $!;
            } elsif ($flag1) {
                my $obj = getLvlObj($data, $lvlReff2->[0]);
                $data->{reff}->[$lvl]->{ getGroupName($data,$obj) } = dclone($lvlReff2);
                $data->{reff}->[$lvl + 1] = $data->{reff}->[$lvl]->{ getGroupName($data,$obj) };
                $lvlReff = $data->{reff}->[$lvl + 1];
            } elsif ($flag2) {
                my $obj = getLvlObj($data, $lvlReff->[0]);
                $data->{reff2}->[$lvl]->{ getGroupName($data,$obj) } = dclone($lvlReff);
                $data->{reff2}->[$lvl + 1] = $data->{reff2}->[$lvl]->{ getGroupName($data,$obj) };
                $lvlReff2 = $data->{reff2}->[$lvl + 1];
            }

            my $container  = [ @children ];
            my $obj       = getLvlObj($data, $container->[0]);
            print "\nPRE ".getGroupName($data,$obj)."-".$type." ".( (scalar $data->{pointer}->@*) ? (scalar $data->{pointer}->@*)-1 : 0)." $index\n";
            print "  PointStr: ".join('.', $data->{pointer}->@*),"\n";

            my @array_1;
            my @array_2;
            if ( getLvlObj($data, $children[0]) ) {

                my $array_11     =  dclone(\@children);
                my $array_22     =  dclone(\@{$lvlReff});
                @array_1     =  $array_11->@*;
                @array_2     =  $array_22->@*;
                @children    = ();
                $lvlReff->@* = ();
                while (scalar @array_1 or scalar @array_2) {
                    my $obj_1 = getLvlObj($data, $array_1[0]);
                    my $obj_2 = getLvlObj($data, $array_2[0]);

                    my $thing1;
                    if ($obj_1 and $array_1[0]) { $thing1 = $array_1[0]->{$obj_1}; }
                    my $thing2;
                    if ($obj_2 and $array_2[0]) { $thing2 = $array_2[0]->{$obj_2}; }

                    my $bool = $thing1 cmp $thing2;
                    if (!$array_1[0]) {
                        unshift @array_1, $array_2[0];
                    } elsif (!$array_2[0]) {
                        unshift @array_2, $array_1[0];
                    } elsif ($bool == -1) {
                        unshift @array_2, $array_1[0];
                    } elsif ($bool and $bool != -1) {
                        unshift @array_1, $array_2[0];
                    } else {
                      push @children, (shift @array_1);
                      push $lvlReff->@*, (shift @array_2);
                      #if ($obj eq 'tags') {last}
                      if (ref $children[0]->{$obj} eq 'ARRAY') {last}
                    }
                }
            } else {
                my $array_11     =  dclone(\@children);
                my $array_22     =  dclone(\@{$lvlReff});
                @array_1         =  $array_11->@*;
                @array_2         =  $array_22->@*;
                @array_1         = sort {lc $a cmp lc $b} @array_1;
                @array_2         = sort {lc $a cmp lc $b} @array_2;
                @children        = ();
                @{$lvlReff}      = ();
                while (scalar @array_1 or scalar @array_2) {
                    my $bool = lc $array_1[0] cmp lc $array_2[0];
                    if ( !$array_1[0]) {
                       unshift @array_1, $array_2[0];
                    } elsif ( !$array_2[0]) {
                       unshift  @array_2, $array_1[0];
                    } elsif ($bool and $bool != -1) {
                       unshift @array_1, $array_2[0];
                    } elsif ($bool == -1) {
                       unshift  @array_2, $array_1[0];
                    } else {
                      push @children, (shift @array_1);
                      push $lvlReff->@*, (shift @array_2);
                    }
                }
            }
            my $cnt = 0;
            for my $part (@children) {
                my $obj_1 = getLvlObj($data, $part);
                my $obj_2 = getLvlObj($data, $lvlReff->[$cnt]);
                print "  Item1: $part\n";
                print "  Item2: $lvlReff->[$cnt]\n";
                print "  Obj1: " .$obj_1."\n";
                print "  Obj2: " .$obj_2."\n";

                my $thing1;
                if ($obj_1) {
                    $thing1 = $children[$cnt]->{ getLvlObj($data, $children[$cnt]) }
                } print "  thing1: $thing1\n";

                my $thing2;
                if ($obj_2) {
                    $thing2 = $lvlReff->[$cnt]->{ getLvlObj($data, $lvlReff->[$cnt]) }
                } print "  thing2: $thing2\n";

                $cnt++;
            }
            $lvlReff2->@* = @children;
            return @children;
        } else {
            return @_;
        }
    };


    # ===|| wanted->() {{{3
    my $wanted = sub {
        ##
        my $item      = $_;
        my $type      = $Data::Walk::type;
        my $index     = $Data::Walk::index;
        my $lvl       = $Data::Walk::depth-2;

        if ($lvl != -1) {

            my $prior_lvl = ( scalar @{$data->{pointer}} ) - 1;
            if ($lvl < $prior_lvl) {
                my $cnt = $prior_lvl - $lvl;
                pop @{$data->{pointer}} for (0..$cnt);
            }

            ## HASH
            if ($type eq 'HASH') {
                unless ($index & 1) {
                    $data->{pointer}->[$lvl] = $index/2;
                    my $lvlReff = $data->{reff}->[$lvl];
                    my $lvlReff2 = $data->{reff2}->[$lvl];
                    my $obj_1   = getLvlObj($data, $lvlReff2);
                    my $obj_2   = getLvlObj($data, $lvlReff);
                    my $thing_1 = $lvlReff2->{ getLvlObj($data, $lvlReff2) };
                    my $thing_2 = $lvlReff->{ getLvlObj($data, $lvlReff) };
                    print "\nWANT $item in $obj_1-$type $lvl ".$data->{pointer}->[$lvl]."\n";
                    print "  PointStr: ".join('.', @{$data->{pointer}}),"\n";
                    print "  Obj1: $obj_1\n";
                    print "  Obj2: $obj_2\n";
                    print "  thing1: $thing_1\n";
                    print "  thing2: $thing_2\n";
                    print "  thing11: $lvlReff2->{$item}\n";
                    print "  thing22: $lvlReff->{$item}\n";

                    if (ref $lvlReff2->{$item} ne 'ARRAY'
                    and ref $lvlReff2->{$item} ne 'HASH'
                    and ref $lvlReff->{$item} ne 'ARRAY'
                    and ref $lvlReff->{$item} ne 'HASH'
                    and $lvlReff->{$item} ne $lvlReff2->{$item} )
                    {
                        die $!
                    }

                    $data->{reff}->[$lvl + 1] = $lvlReff->{$_};
                    $data->{reff2}->[$lvl + 1] = $lvlReff2->{$_};
                }

            ## ARRAY
            } elsif ($type eq 'ARRAY') {
                $data->{pointer}->[$lvl] = $index;

                my $lvlReff  = $data->{reff}->[$lvl];
                my $lvlReff2 = $data->{reff2}->[$lvl];
                my $obj_1   = getLvlObj($data, $item);
                my $obj_2   = getLvlObj($data, $lvlReff->[$index]);

                print "\nWANT $obj_1 $index in " . getGroupName($data, $obj_1) . "-" . "$type $lvl $index\n";
                print "  PointStr: ".join('.', @{$data->{pointer}}),"\n";
                print "  Item: $item\n";
                print "  Obj1: $obj_1\n";
                print "  Obj1: $obj_2\n";

                my $thing1; if ($obj_1) {
                  $thing1 = $lvlReff2->[$index]->{$obj_1}
                } print "  thing1: $thing1\n";

                my $thing2; if ($obj_2) {
                    $thing2 = $lvlReff->[$index]->{$obj_2}
                } print "  thing2: $thing2\n";

                unless ($thing1 eq $thing2) {
                    die("Fuckie Wuckie! In ${0} at line: ".__LINE__)
                }

                $data->{reff}->[$lvl+1] = $lvlReff->[$index];
                $data->{reff2}->[$lvl+1] = $lvlReff2->[$index];

            } else {
                die("Hash contains a reff that is neither hash or array! In ${0} at line: ".__LINE__)
            }
        }
    };
    #}}}

    walk { wanted => $wanted, preprocess => $preprocess}, $hash_0->{contents};
}

#===| encodeResult() {{{2
sub encodeResult {

    my $data  = shift @_;
    my $hash  = shift @_;
    #mes("Starting ENCODE_RESULT", $data, 0, 1, 1);

    if  ($data->{process}->{write}) {
        my $fname = $data->{fileNames}->{output};
        {
            my $json_obj = JSON::PP->new->ascii->pretty->allow_nonref;
            $json_obj = $json_obj->allow_blessed(['true']);
            if ($data->{sort}) {
              $json_obj->sort_by( sub { cmpKeys( $data, $JSON::PP::a, $JSON::PP::b, $_[0] ); } );
            }
            my $json  = $json_obj->encode($hash);
            open( my $fh, '>' ,$fname ) or die $!;
                print $fh $json;
                truncate $fh, tell( $fh ) or die;
            close( $fh );
        }
        #mes("..ok", $data, 0, 1, 1);
    }
    #else { mes("..disabled by user", $data, 0, 1, 1) }
}


# UTILITIES {{{1
#------------------------------------------------------

#===| sortHash(){{{2
sub sortHash {
    my ($data, $hash) = @_;


    #===| sortSub->(){{3
    my $sortSub = sub {
        my $key = shift @_;
        my $index = shift @_;
        my $container  = shift @_;
        if ( ($index % 2) == 0 and ref $container->{$key} eq 'ARRAY') {
            my $checkobj = getLvlObj($data, $container->{$key}->[0]);
            if ($checkobj) {
                $container->{$key} = [ sort {
                    my $obj_a = getLvlObj($data, $a);
                    my $obj_b = getLvlObj($data, $b);
                    if ($obj_a ne $obj_b) {
                        lc $data->{dspt}->{$obj_a}->{order} cmp lc $data->{dspt}->{$obj_b}->{order}
                    } else {
                        lc $a->{$obj_a} cmp lc $b->{$obj_b}
                    }
                } $container->{$key}->@* ];
            }
        }
    };

    my $sub = sub {
        my $type      = $Data::Walk::type;
        my $index     = $Data::Walk::index;
        my $container = $Data::Walk::container;
        if ($type eq 'HASH') {
            $sortSub->($_, $index, $container);
        }
    };

    walk { wanted => $sub}, $hash->{contents};
}


#===| removeKey(){{{2
sub removeKey {
    my $arg   = shift @_;
    my $key   = shift @_;
    my $key2   = shift @_;
    my $index = shift @_;
    my $hash  = shift @_;
    if ( ($index % 2 == 0) and $arg eq $key) {
         my $hash = $Data::Walk::container;
         my @stories;
         for my $part ($hash->{$key}->@*) {
             push @stories, $part->{$key2}->@*;
         }
         unless (exists $hash->{$key2}) {$hash->{$key2} = []}
         push $hash->{$key2}->@*, @stories;
         delete $hash->{$key};
    }
}


#===| deleteKey(){{{2
sub deleteKey {
    my $arg   = shift @_;
    my $key   = shift @_;
    my $index = shift @_;
    my $hash  = shift @_;
    if ( ($index % 2 == 0) and $arg eq $key) {
         delete $hash->{$arg};
    }
}


#===| waltzer() {{{2
sub waltzer {
    my $type      = $Data::Walk::type;
    my $index     = $Data::Walk::index;
    my $container = $Data::Walk::container;
    if ($type eq 'HASH') {
        #deleteKey( $_, 'LN',     $index, $Data::Walk::container);
        #deleteKey( $_, 'raw',    $index, $Data::Walk::container);
        #deleteKey( $_, 'test33', $index, $Data::Walk::container);
        #deleteKey( $_, 'test3',  $index, $Data::Walk::container);
        #deleteKey( $_, 'test',   $index, $Data::Walk::container);
        #filter   ( $_, 'url',    $index, $Data::Walk::container, $sub);
    }
}
# HASH {{{1
#------------------------------------------------------

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


#===| genfilter() {{{2
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

    #===|| getObjFromUniqeKey() {{{3
    sub getObjFromUniqeKey {
        my $data = shift @_;
        my $key  = shift @_;

        if    (exists $data->{dspt}->{$key})        { return $data->{dspt}->{$key}->{order} }
        elsif (getObjFromGroupName($data, $key))    { return $data->{dspt}->{getObjFromGroupName($data, $key)}->{order} }
        else                                        { return 0 }
        #===| getObjFromGroupName() {{{4
        sub getObjFromGroupName {
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
    #===|| genPointStrForRedundantKey() {{{3
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
}


# INHERITED {{{1
#------------------------------------------------------

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

    my $mes   = shift @_;
    my $data  = shift @_;

    if ($data->{opts}->{verbose}) {
        my $cnt             = shift @_;
        my $NewLineDisable  = shift @_;
        my $silent  = shift @_;
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


