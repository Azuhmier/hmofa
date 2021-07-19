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
use JSON::PP;
use List::Util qw( uniq );
no warnings 'uninitialized';
use Scalar::Util;
use Storable qw(dclone);
my $erreno;
use lib ($ENV{HOME}.'/hmofa/hmofa/code/lib');
use Data::Walk;
use Data::Dumper;



# MAIN {{{1
#------------------------------------------------------
{
    my $opts2 = genOpts2({
        ## Processes
        combine  => [1,1,1,1,1],
        encode   => [1,0],
        write    => [1,0],
        delegate => [1,0],

        ## STDOUT
        verbose  => 1,

        ## MISC
        sort    => 1,
    });
     delegate2({
         opts => $opts2,
         name => 'hmofa_llib',
         fileNames => {
             fname    => ['./data/catalog/catalog.json', './data/masterbin/masterbin.json',],
             output   => './json/hmofa_lib.json',
             dspt     => './json/deimos.json',
             external => ['./json/gitIO.json'],
         },
     });


}


# SUBROUTINES {{{1
#------------------------------------------------------

#===| gendspt {{{2
sub genDspt {

    my $data = shift @_;
    my $dspt = do {
        open my $fh, '<', $data->{fileNames}->{dspt};
        local $/;
        decode_json(<$fh>);
    };

    $dspt->{libName} = { order =>'0', groupName =>'LIBS'};
    $dspt->{miss} = { order =>'-1', groupName =>'miss'};

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
       my $preserve = $data->{preserve};
        for my $obj (keys %$preserve) {
            my $preserve_obj          = dclone($preserve->{$obj});
            my $dspt_obj              = $dspt->{$obj};
            $dspt_obj->{preserve}->@* = @$preserve_obj;
        }
        delete $data->{preserve};
    }
    $data->{dspt} = dclone($dspt);
}
#===| validate_Dspt() {{{2
sub validate_Dspt {

    my $data = shift @_;
    my $dspt = $data->{dspt};
    my %hash = ();

    ## check for duplicates: order
    my @keys  = sort map { exists $dspt->{$_}->{order} and  $dspt->{$_}->{order} } keys %{$dspt};
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


#===| delegate2() {{{2
sub delegate2 {

    my $db = shift @_;

    ## checks
    init2($db);

    my $catalog = $db->{hash}->[0]->{SECTIONS}->[1];
        my $catalog_contents = dclone($catalog);
        $catalog             = {};
        $catalog->{contents} = $catalog_contents;
        $catalog->{reff}     = $catalog;
        delete $catalog->{contents}->{section};

    my $masterbin = $db->{hash}->[1]->{SECTIONS}->[1];
        my $masterbin_contents = dclone($masterbin);
        $masterbin             = {};
        $masterbin->{contents} = $masterbin_contents;
        $masterbin->{reff}     = $masterbin;
        delete $masterbin->{contents}->{section};

    my $sub = genFilter({
        pattern => qr?\Qhttps://raw.githubusercontent.com/Azuhmier/hmofa/master/archive_7/\E(\w{8})?,
        dspt    => $db->{external}->{gitIO},
    });

    ### Walkers {{{
    my $walker = sub {
        my $type      = $Data::Walk::type;
        my $index     = $Data::Walk::index;
        my $container = $Data::Walk::container;
        if ($type eq 'HASH') {
            deleteKey( $_, 'LN',     $index, $Data::Walk::container);
            deleteKey( $_, 'raw',    $index, $Data::Walk::container);
            removeKey( $_, 'SERIES', 'STORIES', $index, $container);
            deleteKey( $_, 'miss',   $index, $Data::Walk::container);
            deleteKey( $_, 'preserve',   $index, $Data::Walk::container);
            filter   ( $_, 'url',    $index, $Data::Walk::container, $sub);
        }
    };

    my $walker2 = sub {
        my $type      = $Data::Walk::type;
        my $index     = $Data::Walk::index;
        my $container = $Data::Walk::container;
        if ($type eq 'HASH') {
            deleteKey ( $_, 'LN',                $index, $container);
            deleteKey ( $_, 'raw',               $index, $container);
            removeKey ( $_, 'SERIES', 'STORIES', $index, $container);
            deleteKey ( $_, 'url_attribute',     $index, $container);
            deleteKey ( $_, 'miss',              $index, $Data::Walk::container);
            deleteKey ( $_, 'preserve',          $index, $Data::Walk::container);
            filter    ( $_, 'url',               $index, $container, $sub);
        }
    };
    # }}}

    walkdepth { wanted => $walker} ,  $masterbin->{contents};
    walkdepth { wanted => $walker2}, $catalog->{contents};
    sortHash($db, $catalog);
    sortHash($db, $masterbin);
    print "kkkkkkkkk\n";
    combine($db, $masterbin, $catalog );
    return $db;
}


#===| init2() {{{2
sub init2 {
    my $db = shift @_;
    unless (exists $db->{debug}) {$db->{debug} = []}
        else {warn "WARNING!: 'debug' is already defined by user!"}
    unless (exists $db->{meta}) {$db->{meta} = {}}
        else {warn "WARNING!: 'meta' is already defined by user!"}
    $db->{hash} = [ map { getJson($_) } $db->{fileNames}->{fname}->@* ];
    $db->{dspt} = getJson($db->{fileNames}->{dspt});
    $db->{external} = {
        map {
          $_ =~ m/(\w+)\.json$/;
          $1 => getJson($_);
        } $db->{fileNames}->{external}->@*
    };
    validate_Dspt( $db );
    return $db;
}


#===| combine() {{{2
sub combine {

    my ($db, $hhash_0, $hhash_1) = @_;
    $db->{reff_0}  = [ $hhash_0->{contents} ]; my $reff_0 = $db->{reff_0};
    $db->{reff_1}  = [ $hhash_1->{contents} ]; my $reff_1 = $db->{reff_1};
    $db->{pointer} = [0] unless (exists $db->{pointer});
    my $flappy = dclone($db->{reff_0});


    # ===|| preprocess->() {{{3
    my $preprocess = sub {

        my @children   = @_;
        my $cmbOpts    = $db->{opts}->{combine};
        my $lvl        = $Data::Walk::depth - 2;
        my $type       = $Data::Walk::type;
        my $pointer    = $db->{pointer};
        for my $ref (@children) {
            print "$ref ".__LINE__." " if "$ref" eq $db->{fucker3};
            print join('.', @$pointer)."\n" if "$ref" eq $db->{fucker3};
        }

        ## Pre HASH
        if ($type eq 'HASH') {

            $pointer->[$lvl]            = (exists $pointer->[$lvl]) ? ++$pointer->[$lvl] : 0;
            my $lvlPoint                = \$pointer->[$lvl];
            my ($lvlReff_0, $lvlReff_1) = ($reff_0->[$lvl], $reff_1->[$lvl]);
            for my $ref (@children) {
                print "$ref ".__LINE__." " if "$ref" eq $db->{fucker3};
                print join('.', @$pointer)."\n" if "$ref" eq $db->{fucker3};
            }

            ## Convert Array to Hash
            my ($hash_0, $cnt) = (undef, 0);
            for my $part (@children) {
                if ($cnt & 1) {$hash_0->{$children[$cnt-1]} = $part}
                $cnt++;
            }

            my $lvlObj_0  = getLvlObj($db, $hash_0);
            my $index = $$lvlPoint;

            ## Debug {{{
            mes("\nPRE ".$lvlObj_0."-".$type." ".$lvl." $index", $db,[-1]);
            mes(" PointStr: ".join('.', @$pointer), $db);
            # }}}

            my $hash_1 = $lvlReff_1; if (ref $lvlReff_1 eq 'ARRAY') {
                my $lvlObj_1 = (exists $lvlReff_1->[$index]->{$lvlObj_0}) ? $lvlObj_0 : ' ';
                $hash_1   = $lvlReff_1->[$index];
                $lvlReff_0->[$index] = $hash_0;

                ## Debug {{{
                mes("    obj_0: $lvlObj_0",            $db);
                mes("    obj_1: $lvlObj_1",            $db);
                mes("   item_0: $hash_0->{$lvlObj_0}", $db);
                mes("   item_1: $hash_1->{$lvlObj_0}", $db);
                # }}}

            }

            ## COMBINE KEYS
            my @keys_0 = sort {lc $a cmp lc $b} keys %$hash_0;
            my @keys_1 = sort {lc $a cmp lc $b} keys %$hash_1;
            while (scalar @keys_0 or scalar @keys_1) {
                my $key_0 = $keys_0[0];
                my $key_1 = $keys_1[0];
                my $bool  = lc $key_0 cmp lc $key_1;
                if ( (!$key_0 || ( $bool and $bool != -1)) and $key_1 ) {
                    unshift @keys_0, $key_1;
                    $hash_0->{$key_1} = $hash_1->{$key_1};
                } elsif ( (!$key_1 || ( $bool == -1)) and $key_0 ) {
                    unshift @keys_1, $key_0;
                    $hash_1->{$key_0} = $hash_0->{$key_0};
                } else {
                    shift @keys_0;
                    shift @keys_1;
                }
                ## Debug {{{
                mes("    ------------",              $db,[2],$cmbOpts->[1] == 2);
                mes("     key_0: $key_0",            $db,[2],$cmbOpts->[1] == 2);
                mes("     key_1: $key_1",            $db,[2],$cmbOpts->[1] == 2);
                mes("    item_0: $hash_0->{$key_0}", $db,[2],$cmbOpts->[1] == 2);
                mes("    item_1: $hash_1->{$key_1}", $db,[2],$cmbOpts->[1] == 2);
                # }}}
            }

            # convert hash back into array
            #print $db->{fucker5},"\n" if exists $db->{fucker5} and $db->{fucker5};
            #undef $db->{fucker5};
            for my $ref (@children) {
                print "$ref ".__LINE__."\n" if "$ref" eq $db->{fucker3};
            }
            undef @children;
            for my $ref (@children) {
                print "$ref ".__LINE__."\n" if "$ref" eq $db->{fucker3};
            }
            for my $key (sort keys %$hash_0) {
                push @children, ($key, $hash_0->{$key});
            }
            return @children;

        ## Pre ARRAY
        } elsif ($type eq 'ARRAY') {
            for my $ref (@children) {
                print "$ref ".__LINE__." " if "$ref" eq $db->{fucker3};
                print join('.', @$pointer)."\n" if "$ref" eq $db->{fucker3};
            }
            my $index = $pointer->[$lvl];
            my $flaggot;
            if ( (join '.', $db->{pointer}->@*) eq '0.176.0') {
              $flaggot = 1;
            }

            ##
            my $lvlReff_0 = $reff_0->[$lvl+1];
            my $lvlReff_1 = $reff_1->[$lvl+1];
            my $flag_1; unless ($lvlReff_1) {$flag_1 = 1}
            my $flag_0; unless ($lvlReff_0) {$flag_0 = 2}
            if ($flag_1 && $flag_0) {
                die $!;
            } elsif ($flag_1) {
                my $lvlObj_0                  = getLvlObj($db, $lvlReff_0->[0]);
                my $groupName                 = getGroupName($db,$lvlObj_0);
                $reff_1->[$lvl]->{$groupName} = dclone($lvlReff_0);
                $reff_1->[$lvl+1]             = $reff_1->[$lvl]->{$groupName};
                $lvlReff_1                    = $reff_1->[$lvl+1];
            } elsif ($flag_0) {
                my $lvlObj_1                  = getLvlObj($db, $lvlReff_1->[0]);
                my $groupName                 = getGroupName($db,$lvlObj_1);
                $reff_0->[$lvl]->{$groupName} = dclone($lvlReff_1);
                $reff_0->[$lvl+1]             = $reff_0->[$lvl]->{$groupName};
                $lvlReff_0                    = $reff_0->[$lvl+1];
            }

            my $obj = getLvlObj($db, $children[0]);

            ## Debug {{{
            mes("\nPRE ".getGroupName($db,$obj)."-".$type." ".( (scalar @$pointer) ? (scalar @$pointer)-1 : 0)." $index",$db,[-1]);
            mes(" PointStr: ".join('.', @$pointer),$db) if !$flaggot;
            # }}}

            ## objArray
            if ($obj) {

                mes(" PointStr: ".join('.', @$pointer),$db,[0],1,$flaggot) if $flaggot;
                print "    PRE ".getGroupName($db,$obj)."-"."$type $lvl  $index","\n" if $flaggot;
                my @objArray_0 =  sort {$a->{$obj} cmp $b->{$obj} } @{dclone(\@children)};
                my @objArray_1 =  sort {$a->{$obj} cmp $b->{$obj} } @{dclone(\@$lvlReff_1)};
                if ($flaggot) {
                    print "        PointStr: ".join('.', @$pointer)."\n";
                    print "        BALL\n";
                    for my $hash (@children) {
                      if ($hash->{title} =~ 'Ball') { print "        $hash ()()()\n"}
                    }
                    for my $hash (@objArray_0) {
                      if ($hash->{title} =~ 'Ball') { print "        $hash )()()(\n"}
                    }
                    print "        $db->{fucker3}\n";
                    print "        $db->{fucker4}\n";
                }
                @children      = ();
                @$lvlReff_1    = ();

                my $seen;
                while (scalar @objArray_0 or scalar @objArray_1) {
                    my $obj_0     = getLvlObj($db, $objArray_0[0]);
                    my $obj_1     = getLvlObj($db, $objArray_1[0]);
                    my $objHash_0 = $objArray_0[0];
                    my $objHash_1 = $objArray_1[0];
                    my $item_0    = ($obj_0 and $objHash_0) ? $objHash_0->{$obj_0} : undef;
                    my $item_1    = ($obj_1 and $objHash_1) ? $objHash_1->{$obj_1} : undef;
                    my $bool      = $item_0 cmp $item_1;

                    if ( (!$objHash_0 || ( $bool and $bool != -1)) and $objHash_1 ) {
                        unshift @objArray_0, $objHash_1;
                    } elsif ( (!$objHash_1 || ( $bool == -1)) and $objHash_0 ) {
                        unshift @objArray_1, $objHash_0;
                    } else {
                        push @children, (shift @objArray_0);
                        push @$lvlReff_1, (shift @objArray_1);
                        if (ref $children[0]->{$obj} eq 'ARRAY') {last}
                        if ($obj_0 eq 'author' and ${seen}->{$item_0}++) {
                            mes("DUPLICATE: $item_0",$db);
                            die;
                        }
                    }
                    mes("-----------",          $db,[2],$cmbOpts->[1] == 2);
                    mes("     item_0: $item_0", $db,[2],$cmbOpts->[1] == 2);
                    mes("     item_1: $item_1", $db,[2],$cmbOpts->[1] == 2);
                }

            ## Array
            } else {
                my @array_0 = sort {lc $a cmp lc $b} @{dclone(\@children)};
                my @array_1 = sort {lc $a cmp lc $b} @{dclone(\@{$lvlReff_1})};
                for my $ref (@children) {
                    print "$ref ".__LINE__." " if "$ref" eq $db->{fucker3};
                    print join('.', @$pointer)."\n" if "$ref" eq $db->{fucker3};
                }
                @children   = ();
                @$lvlReff_1 = ();
                for my $ref (@children) {
                    print "$ref ".__LINE__." " if "$ref" eq $db->{fucker3};
                    print join('.', @$pointer)."\n" if "$ref" eq $db->{fucker3};
                }

                while (scalar @array_0 or scalar @array_1) {
                    my $part_0 = $array_0[0];
                    my $part_1 = $array_1[0];
                    my $bool   = lc $part_0 cmp lc $part_1;
                    if ( (!$part_0 || ( $bool and $bool != -1)) and $part_1 ) {
                        unshift @array_0, $part_1;
                    } elsif ( (!$part_1 || ( $bool == -1)) and $part_0 ) {
                        unshift  @array_1, $part_0;
                    } else {
                        push @children, (shift @array_0);
                        push @$lvlReff_1, (shift @array_1);
                    }
                    mes("-----------",          $db,[2],$cmbOpts->[1] == 2);
                    mes("     part_0: $part_0", $db,[2],$cmbOpts->[1] == 2);
                    mes("     part_1: $part_1", $db,[2],$cmbOpts->[1] == 2);
                }
            }

            ## Debug {{{
            my $cnt = 0;
            for my $ref (@children) {
                print "$ref ".__LINE__." " if "$ref" eq $db->{fucker3};
                print join('.', @$pointer)."\n" if "$ref" eq $db->{fucker3};
            }
            for my $part (@children) {
                my $obj_0  = getLvlObj($db, $part);
                my $obj_1  = getLvlObj($db, $lvlReff_1->[$cnt]);
                my $item_0 = ($obj_0) ? $children[$cnt]->{ getLvlObj($db, $children[$cnt]) } : undef;
                my $item_1 = ($obj_1) ? $children[$cnt]->{ getLvlObj($db, $children[$cnt]) } : undef;

                mes("-----------",                     $db,[2],$cmbOpts->[1] == 2);
                mes("     item_0: $part",              $db,[2],$cmbOpts->[1] == 2);
                mes("     item_1: $lvlReff_1->[$cnt]", $db,[2],$cmbOpts->[1] == 2);
                mes("      obj_0: " .$obj_0,           $db,[2],$cmbOpts->[1] == 2);
                mes("      obj_1: " .$obj_1,           $db,[2],$cmbOpts->[1] == 2);
                mes("     item_0: $item_0",            $db,[2],$cmbOpts->[1] == 2);
                mes("     item_1: $item_1",            $db,[2],$cmbOpts->[1] == 2);

                $cnt++;
            }
            # }}}

            @$lvlReff_0 = @children;
            if ( (join '.', $db->{pointer}->@*) eq '0.175.0') {
                print "    PRE ".getGroupName($db,$obj)."-"."$type $lvl  $index","\n";
                print "        PointStr: ".join('.', @$pointer)."\n";;
                print "        COYOTE\n";
                for my $hash (@children) {
                  if ($hash->{title} =~ 'Coyote') {
                      my $var = $hhash_0->{contents}->{AUTHORS}->[175]->{STORIES}->[22];
                      print "        $hash\n";
                      print "        $var\n";
                      $db->{fucker3} = "$hash";
                      $db->{fucker4} = Scalar::Util::refaddr($hash);
                      $db->{fucker5} = $hash;
                  }
                }
            }
            for my $ref (@children) {
                print "$ref ".__LINE__." " if "$ref" eq $db->{fucker3};
                print join('.', @$pointer)."\n" if "$ref" eq $db->{fucker3};
            }
            return @children;
        } else { return @_ }
    };


    # ===|| wanted->() {{{3
    my $wanted = sub {

        my $item    = $_;
        my $type    = $Data::Walk::type;
        my $index   = $Data::Walk::index;
        my $lvl     = $Data::Walk::depth-2;
        my $cmbOpts = $db->{opts}->{combine};

        unless ($lvl == -1) {

            my $prior_lvl = ( scalar $db->{pointer}->@* ) - 1;
            my $pointer   = $db->{pointer};
            my $lvlReff_0 = $reff_0->[$lvl];
            my $lvlReff_1 = $reff_1->[$lvl];
            print "$item ".__LINE__." " if "$item" eq $db->{fucker3};
            print join('.', @$pointer)."\n" if "$item" eq $db->{fucker3};

            if ($prior_lvl > $lvl) {
                pop @$pointer for ( 0 .. ($prior_lvl - $lvl) );
            }

            ## HASH
            if ($type eq 'HASH') {
                unless ($index & 1) {

                    $pointer->[$lvl] = $index/2;
                    my $obj_0     = $item;
                    my $item_0    = $lvlReff_0->{$obj_0};
                    my $item_1    = $lvlReff_1->{$obj_0};
                    my $lvlObj_0  = getLvlObj($db, $lvlReff_0);
                    my $lvlObj_1  = getLvlObj($db, $lvlReff_1);
                    my $lvlItem_0 = $lvlReff_0->{$lvlObj_0};
                    my $lvlItem_1 = $lvlReff_1->{$lvlObj_1};

                    ## Debug {{{
                    mes("\nWANT $obj_0 in $lvlObj_0-$type $lvl ".$pointer->[$lvl],$db,[-1],$cmbOpts->[2]);
                    mes(" PointStr: ".join('.', @$pointer),$db,[0],$cmbOpts->[2]);
                    mes("    obj_0: $obj_0",     $db,[0],$cmbOpts->[2]);
                    mes("   item_0: $item_0",    $db,[0],$cmbOpts->[2]);
                    mes("   item_1: $item_1",    $db,[0],$cmbOpts->[2]);
                    # }}}

                    ## CONFIGURE REFFS
                    $reff_1->[$lvl+1] = $lvlReff_1->{$_};
                    $reff_0->[$lvl+1] = $lvlReff_0->{$_};
                }

            ## ARRAY
            } elsif ($type eq 'ARRAY') {
                print "$item ".__LINE__." " if "$item" eq $db->{fucker3};
                print join('.', @$pointer)."\n" if "$item" eq $db->{fucker3};

                $pointer->[$lvl] = $index;
                my $hash         = $item;
                my $lvlObj_0     = getLvlObj($db, $hash);
                my $lvlObj_1     = getLvlObj($db, $lvlReff_1->[$index]);
                my $lvlItem_0    = $lvlObj_0 ? $lvlReff_0->[$index]->{$lvlObj_0} : undef;
                my $lvlItem_1    = $lvlObj_1 ? $lvlReff_1->[$index]->{$lvlObj_1} : undef;

                ## Debug {{{
                mes("\nWANT $lvlObj_0 $index in " . getGroupName($db, $lvlObj_0) . "-" . "$type $lvl $index", $db,[-1],$cmbOpts->[2]);
                mes("  PointStr: ".join('.', @$pointer), $db,[0],$cmbOpts->[2]);
                mes(" lvlReff_0: ($lvl, $index) $lvlReff_0->[$index]",$db,[0],$cmbOpts->[2]);
                mes(" lvlReff_1: ($lvl, $index) $lvlReff_1->[$index]",$db,[0],$cmbOpts->[2]);
                mes("  Obj_0: $lvlObj_0",  $db,[0],$cmbOpts->[2]);
                mes("  Obj_1: $lvlObj_1",  $db,[0],$cmbOpts->[2]);
                mes(" item_0: $lvlItem_0", $db,[0],$cmbOpts->[2]);
                mes(" item_1: $lvlItem_1", $db,[0],$cmbOpts->[2]);
                # }}}

                ## CONFIGURE REFFS
                $reff_1->[$lvl+1] = $lvlReff_1->[$index];
                $reff_0->[$lvl+1] = $lvlReff_0->[$index];
                print "$item ".__LINE__." " if "$item" eq $db->{fucker3};
                print join('.', @$pointer)."\n" if "$item" eq $db->{fucker3};

            }
            print "$item ".__LINE__." " if "$item" eq $db->{fucker3};
            print join('.', @$pointer)."\n" if "$item" eq $db->{fucker3};
            print $db->{fucker5},"\n" if exists $db->{fucker5} and $db->{fucker5};
            undef $db->{fucker5};
        }
    };
    #}}}

    walk { wanted => $wanted, preprocess => $preprocess}, $hhash_0->{contents};

    {

        my $json_obj = JSON::PP->new->ascii->pretty->allow_nonref;
        $json_obj = $json_obj->allow_blessed(['true']);
        if ($db->{opts}->{sort}) {
            $json_obj->sort_by( sub { cmpKeys( $db, $JSON::PP::a, $JSON::PP::b, $_[0] ); } );
        }
        my $json  = $json_obj->encode($hhash_0->{contents});

        open my $fh, '>', $db->{fileNames}->{output} or die;
            print $fh $json;
            truncate $fh, tell( $fh ) or die;
        close $fh
    }
}

# UTILITIES {{{1
#------------------------------------------------------

#===| cmpKeys() {{{2
sub cmpKeys {
    my ($data, $key_a, $key_b, $hash, $opts) = @_;

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


#===| genOpts2() {{{2
sub genOpts2 {
    my $ARGS = shift @_;
    my $defaults = {

        ## Processes
        combine => [1,0,0,0,0],
        encode   => [1,0],
        write    => [1,0],

        ## STDOUT
        verbose  => [0],
        display  => [0],
        lineNums => [0],

        ## MISC
        sort     => [0],
    };
    $defaults->{$_} = $ARGS->{$_}  for keys %{$ARGS};
    return $defaults;
}


#===| getGroupName() {{{2
sub getGroupName {

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


#===| getPointStr() {{{2
sub getPointStr {
    # return CURRENT POINT
    # return '0' if poinStr is an empty string!

    my $data = shift @_;
    my $pointStr = join('.', $data->{point}->@*);
    return ($pointStr ne '') ? $pointStr
                             : 0;
}


#===| isReservedKey() {{{2
sub isReservedKey {
    my ($data, $key)  = @_;
    my $resvKeys      = $data->{reservedKeys};

    my @matches  = grep { $key eq $resvKeys->{$_}->[0] } keys %{$resvKeys};

    return $matches[0] ? 1 : 0;
}


#===| mes() {{{2
sub mes {
    my ($mes, $db, $opts, $bool, $flaggot) = @_;
    $bool = 1 unless scalar @_ >= 4;

    if ($db->{opts}->{verbose} and $bool) {
        my ($cnt, $NewLineDisable, $silent) = @$opts if $opts;
        my $indent = "    ";
        $mes = ( $cnt ? $indent x (1 + $cnt) : $indent )
             . $mes
             . ( !($NewLineDisable) ? "\n" : "" );

        unless ($flaggot) {
        }
        push $db->{debug}->@*, $mes unless $silent;
        return $mes;
    }
}



# OTHER {{{1
#------------------------------------------------------

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


