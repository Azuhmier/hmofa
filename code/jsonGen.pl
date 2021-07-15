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
use Storable qw(dclone);
use JSON::PP;
use XML::Simple;
use YAML;
use Data::Walk;
use List::Util qw( uniq );
no warnings 'uninitialized';
my $erreno;

# MAIN {{{1
#------------------------------------------------------
{
    ## OPTS {{{
    my $opts = genOpts({
        ## Processes
        all      => [1,0],
        leveler  => [1,0],
        divy     => [1,0],
        attribs  => [1,0],
        delims   => [1,0],
        encode   => [1,0],
        write    => [1,0],
        delegate => [1,0],

        ## STDOUT
        verbose  => 1,
        display  => 0,
        lineNums => 0,

        ## MISC
        sort    => 1,
    });
    #}}}

    ## DELEGATES {{{
    ## masterbin
    delegate({
        opts => $opts,
        name => 'masterbin',
        preserve => {
            libName => [
                ['',[0]],
            ],
            section => [
                ['FOREWORD',[1]],
            ],
        },
        fileNames => {
            fname  => '../masterbin.txt',
            output => './json/masterbin2.json',
            dspt   => './json/deimos.json',
        },
    });

    ## tagCatalog
    delegate({
        opts => $opts,
        name => 'catalog',
        preserve => {
            libName => [
                ['',[0]],
            ],
            section => [
                ['Introduction/Key',[1,1,1]],
            ],
        },
        fileNames => {
            fname  => '../tagCatalog.txt',
            output => './json/catalog2.json',
            dspt   => './json/deimos.json',
        },
    });
    #}}}

    ## COMBINE {{{
    my $db = init2({
        fileNames => {
            fname => [
                './data/catalog/catalog.json',
                './data/masterbin/masterbin.json',
            ],
            external => [
                './json/gitIO.json'
            ],
            output => './json/hmofa_lib.json',
            dspt => './json/deimos.json',
        },
        process => {
            write => 1,
        },
        sort => 1,
        verbose => 0,
    });


    my $catalog = $db->{hash}->[0]->{SECTIONS}->[1];
        my $catalog_contents = dclone $catalog;
        $catalog             = {};
        $catalog->{contents} = $catalog_contents;
        $catalog->{reff}     = $catalog;
        $catalog->{contents}->{libName}  = 'catalog';
        delete $catalog->{contents}->{section};

    my $masterbin = $db->{hash}->[1]->{SECTIONS}->[1];
        my $masterbin_contents = dclone $masterbin;
        $masterbin             = {};
        $masterbin->{contents} = $masterbin_contents;
        $masterbin->{reff}     = $masterbin;
        $catalog->{contents}->{libName}  = 'masterbin';

    my $sub = genFilter({
        pattern => qr?\Qhttps://raw.githubusercontent.com/Azuhmier/hmofa/master/archive_7/\E(\w{8})?,
        dspt    => $db->{external}->{gitIO},
    });
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
            deleteKey( $_, 'miss',   $index, $Data::Walk::container);
            deleteKey( $_, 'preserve',   $index, $Data::Walk::container);
            deleteKey( $_, 'preserves',   $index, $Data::Walk::container);
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
            deleteKey( $_, 'miss',   $index, $Data::Walk::container);
            deleteKey( $_, 'preserve',   $index, $Data::Walk::container);
            deleteKey( $_, 'preserves',   $index, $Data::Walk::container);
            #deleteKey ( $_, 'URLS',               $index, $container);
            #deleteKey ( $_, 'TAGS',               $index, $container);
            filter    ( $_, 'url',               $index, $container, $sub);
        }
    }

    walkdepth { wanted => \&walker} ,  $masterbin->{contents};
    walkdepth { wanted => \&walker2}, $catalog->{contents};
    sortHash($db,$catalog);
    sortHash($db,$masterbin);
    combine( $db, $masterbin, $catalog );
        ##combine( $data, $catalog, $masterbin );
        ##combine( $data, $catalog, $catalog );
        #encodeResult($data, dclone($masterbin->{contents}));
    # }}}
}


# SUBROUTINES {{{1
#------------------------------------------------------

#===| delegate() {{{2
sub delegate {

    my $data = shift @_;
    my $delegate_opts = $data->{opts}->{delegate};
    if ($delegate_opts->[0]) {

        ## sigtrap
        $SIG{__DIE__} = sub {
            if ($data and exists $data->{debug}) {
                print $_ for $data->{debug}->@*;
                print $erreno;
            }
        };

        ## checks
        init($data);

        ## matches
        getMatches($data);
        validate_Matches($data);
        $data->{matches4}->%* =
            map { map { $_->{LN} => $_
                      } $data->{matches_clone}->{$_}->@*
                } keys $data->{matches_clone}->%*;
        ## convert
        leveler($data,\&checkMatches);

        ## encode
        encodeResult($data);

        ## write
        my $writeArray = genWriteArray($data);
        open my $fh, '>', './result/'.$data->{result}->{libName}.'.txt' or die $!;
        for (@$writeArray) {
            print $fh $_,"\n";
        }
        truncate $fh, tell($fh) or die;
        seek $fh,0,0 or die;
        close $fh;

        ## output {{{

        if ($delegate_opts->[1]) {
            ## Matches Meta
            my $matches_Meta = $data->{meta}->{matches};
            my $max = length longest(keys $matches_Meta->%*);

            ## Verbose
            print "\nSummary: $data->{name}\n";
            for my $obj (sort keys $matches_Meta->%*) {
                printf "%${max}s: %s\n", ($obj, $matches_Meta->{$obj}->{count});
            }

            ## Subs
            sub longest {
                my $max = -1;
                my $max_ref;
                for (@_) {
                    if (length > $max) {  # no temp variable, length() twice is faster
                        $max = length;
                        $max_ref = \$_;   # avoid any copying
                    }
                }
                $$max_ref
            }
        }
        print $_ for $data->{debug}->@*;
        if ($data->{opts}->{write}->[1] == 2) { print Dumper($data->{pointy})   }
        #}}}

        ## WRITE {{{
        my $headDir = './data';
        my $dirname = $headDir.'/'.$data->{result}->{libName};
        mkdir $headDir if (!-d './data');
        mkdir $dirname if (!-d $dirname);

        ## META
        {
            my $json_obj = JSON::PP->new->ascii->pretty->allow_nonref;
            $json_obj    = $json_obj->allow_blessed(['true']);
            my $json     = $json_obj->encode($data->{meta});
            my $fname    = $dirname.'/meta.json';
            open my $fh, '>', $fname or die "Error in opening file $fname\n";
                print $fh $json;
                truncate $fh, tell( $fh ) or die;
            close $fh;
        }
        ## RESULT
        {
            my $json_obj = JSON::PP->new->ascii->pretty->allow_nonref;
            $json_obj    = $json_obj->allow_blessed(['true']);
            my $json     = $json_obj->encode($data->{result});
            my $fname    = $dirname.'/'.$data->{result}->{libName}.'.json';
            open my $fh, '>', $fname or die "Error in opening file $fname\n";
                print $fh $json;
                truncate $fh, tell( $fh ) or die;
            close $fh;
        }
        ## MATCHES
        {
            my $json_obj = JSON::PP->new->ascii->pretty->allow_nonref;
            $json_obj    = $json_obj->allow_blessed(['true']);
            my $json     = $json_obj->encode($data->{matches});
            my $fname    = $dirname.'/matches.json';
            open my $fh, '>', $fname or die "Error in opening file $fname\n";
                print $fh $json;
                truncate $fh, tell( $fh ) or die;
            close $fh;
        }
        ## MATCHES4
        {
            my $json_obj = JSON::PP->new->ascii->pretty->allow_nonref;
            $json_obj    = $json_obj->allow_blessed(['true']);
            my $json     = $json_obj->encode($data->{matches4});
            my $fname    = $dirname.'/matches4.json';
            open my $fh, '>', $fname or die "Error in opening file $fname\n";
                print $fh $json;
                truncate $fh, tell( $fh ) or die;
            close $fh;
        }
        ## MATCHES_CLONE
        {
            my $json_obj = JSON::PP->new->ascii->pretty->allow_nonref;
            $json_obj    = $json_obj->allow_blessed(['true']);
            my $json     = $json_obj->encode($data->{matches_clone});
            my $fname    = $dirname.'/matches_clone.json';
            open my $fh, '>', $fname or die "Error in opening file $fname\n";
                print $fh $json;
                truncate $fh, tell( $fh ) or die;
            close $fh;
        }
        ## MATCHES_CLONE
        {
            my $json_obj = JSON::PP->new->ascii->pretty->allow_nonref;
            $json_obj    = $json_obj->allow_blessed(['true']);
            my $json     = $json_obj->encode($data->{dspt});
            my $fname    = $dirname.'/dspt.json';
            open my $fh, '>', $fname or die "Error in opening file $fname\n";
                print $fh $json;
                truncate $fh, tell( $fh ) or die;
            close $fh;
        }

        opendir my $dh, $headDir or die "Error in opening dir $headDir\n";
            while (readdir $dh) {}
        closedir $dh;
        # }}}


        return $data;
    }
}


#===| init() {{{2
sub init {

  my $data = shift @_;

  # ---|| properties |---{{{3
  unless (exists $data->{point})     {$data->{point}     = [1]}
      else {warn "WARNING!: 'point' is already defined by user!"}
  unless (exists $data->{result})    {$data->{result}    = {libName => $data->{name}}}
      else {warn "WARNING!: 'result' is already defined by user!"}
  unless (exists $data->{reffArray}) {$data->{reffArray} = [$data->{result}]}
      else {warn "WARNING!: 'reffArray' is already defined by user!"}
  unless (exists $data->{meta})      {$data->{meta}      = {}}
      else {warn "WARNING!: 'meta' is already defined by user!"}
  unless (exists $data->{debug})     {$data->{debug}     = []}
      else {warn "WARNING!: 'debug' is already defined by user!"}
  unless (exists $data->{index})     {$data->{index}     = []}
      else {warn "WARNING!: 'index' is already defined by user!"}
  genReservedKeys($data);

  # ---|| filenames |---{{{3
  unless ($data->{fileNames}->{dspt})   {die "User did not provide filename for 'dspt'!"}
      genDspt($data);
      validate_Dspt($data);
  unless ($data->{fileNames}->{fname})  {die "User did not provide filename for 'fname'!"}
  unless ($data->{fileNames}->{output}) {die "User did not provide filename for 'output'!"}
  #}}}
}
#===| genReservedKeys() {{{2
sub genReservedKeys {

    my $data = shift @_;
    my $ARGS = shift @_;
    my $defaults = {
        NULL      => [ 'NULL',      1 ],
        preserve  => [ 'preserve',  2 ],
        PRESERVES => [ 'PRESERVES', 3 ],
        raw       => [ 'raw',       4 ],
        trash     => [ 'trash',     5 ],
        LN        => [ 'LN',        6 ],
        point     => [ 'point',     7 ],
        miss      => [ 'miss',      8 ],
        MISS      => [ 'MISS',      9 ],
        libName   => [ 'libName',   10 ],
    };
    $defaults->{$_} = $ARGS->{$_}  for keys %{$ARGS};

    ## check for duplicates: keys
    my @keys  = sort map  {$defaults->{$_}->[0]} keys %{$defaults};
    my %DupesKeys;
    for (@keys) { die "Cannot have duplicate reserved keys!" if $DupesKeys{$_}++ }

    ## check for duplicates: order numbers
    my @order = sort map {$defaults->{$_}->[1]} keys %{$defaults};
    my %DupesOrderNum;
    for (@order) { die "Reserved keys cannot have identical orders!" if $DupesOrderNum{$_}++ }

    $data->{reservedKeys} = $defaults;
}

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


#===| getMatches() {{{2
sub getMatches {

    my $data = shift @_;
    my $fname = $data->{fileNames}->{fname};
    my $dspt  = $data->{dspt};
    my $output;

    open( my $fh, '<', $fname )
        or die $!;

    while (my $line = <$fh>) {

        my $flag;
        for my $objKey (keys %$dspt) {
            my $obj = $dspt->{$objKey};

            if ($obj->{re} and $line =~ /$obj->{re}/) {
                my $match = {
                    LN      => $.,
                    $objKey => $1,
                    raw     => $line,
                };
                push  $output->{$objKey}->@*, $match;
                $flag=1;
            }
        }
        unless ($flag) {
            my $match = {
                LN      => $.,
                miss => $line,
            };
            push  $output->{miss}->@*, $match;
        }
    }

    close( $fh );
    $data->{matches} = $output;
}



#===| validate_Matches() {{{2
sub validate_Matches {

    my $data    = shift @_;
    my $dspt    = $data->{dspt};
    my $matches = $data->{matches};
    my $meta    = $data->{meta};
    $data->{matches_clone} = dclone($matches);

    ## MATCHES META
    $meta->{matches} = {};
    my $meta_matches = $meta->{matches};

    for my $obj (keys %$dspt, 'miss') {

        $meta_matches->{$obj}      = {};
        my $meta_matches_obj       = $meta_matches->{$obj};

        my $matches_obj            = $matches->{$obj};
        $meta_matches_obj->{count} = $matches_obj ? scalar @$matches_obj : 0;
    }
}



#===| leveler() {{{2
# iterates in 2 dimensions the order of the dspt
sub leveler {

    my $data = shift @_;
    my $sub  = shift @_;
    my $leveler_opts = $data->{opts}->{leveler};
    if ($leveler_opts->[0]) {

        ## check existance of OBJ at current point
        my $objKey = getObj( $data );
        unless ($objKey) { return }

        ## Debug {{{
        mes("LEVELER ".getPointStr($data), $data, [-1])
            if $leveler_opts->[1];
        #}}}

        ## Reverence Arrary for the current recursion
        my $recursionReffArray;
        while ($objKey) {

            ## Debug {{{
            if ($leveler_opts->[1]) {
                mes("------------", $data);
                mes("OBJ: ${objKey}", $data);
            }
            ## }}}

            ## Checking existance of recursionReffArray
            unless (defined $recursionReffArray) { $recursionReffArray->@* = $data->{reffArray}->@* }

            ## checkMatches
            $sub->( $data );

            ## Check for CHILDREN
            changePointLvl($data->{point}, 1);
            leveler( $data, $sub);
            changePointLvl($data->{point});
            $data->{reffArray}->@* = $recursionReffArray->@*;

            ## Check for SYBLINGS
            if (scalar $data->{point}->@*) {
                $data->{point}->[-1]++;
            } else { last }

            $objKey = getObj( $data );
        }
        return $data->{result};
    }
}


#===| checkMatches() {{{2
sub checkMatches {

    my $data = shift @_;
    my $obj  = getObj( $data );
    my $divier  = \&divyMatches;

    if (exists $data->{matches}->{$obj}) {
        $divier->( $data );
    }
}


#===| divyMatches() {{{2
sub divyMatches {

    my $data               = shift @_;
    my $dspt          = $data->{dspt};
    my $refArray      = $data->{reffArray};
    my $matches       = $data->{matches_clone};
    my $opts_divy     = $data->{opts}->{divy};

    if ($opts_divy->[0]) {
        my $obj          = getObj($data);
        my $dspt_obj     = $dspt->{$obj};
        my $matches_obj  = $matches->{$obj};
        my $matches_ALL  = $data->{matches4};
        $matches_ALL  = [ map { $matches_ALL->{$_} } sort {$a <=> $b } keys %$matches_ALL ];
        @$matches_ALL = grep {exists $_->{LN}} @$matches_ALL;
        my $objGroupName = getGroupName($data, $obj);


        ## refArray LOOP
        my $ind = (scalar @$refArray) - 1;
        for my $ref (reverse @$refArray) {
            #last if !(scalar $matches_obj);
            my @MATCHES;
            my $lvlObj      = getLvlObj($data, $ref);
            my $dspt_lvlObj = $dspt->{$lvlObj};
            my $lvlItem     = $ref->{$lvlObj};
            my $ref_LN      = ($ref->{LN}) ? $ref->{LN} : 0;
            my $match_ARRAY;
            @$match_ARRAY = @$matches_obj;
            @$match_ARRAY = grep {exists $_->{LN}} @$match_ARRAY;
            push @MATCHES, $match_ARRAY;

            ## Preserve {{{
            my $preserve_obj;
            my $presFlag = 0;
            if (exists $dspt_lvlObj->{preserve}) {
                $preserve_obj = $dspt_lvlObj->{preserve};
                if ( (grep {$_->[0] eq $lvlItem} @$preserve_obj)[0] ) {
                    $presFlag = 1;
                    my $size = scalar (split /\./, $dspt_lvlObj->{order});
                    my @elegible_obj = grep { exists $dspt->{$_}->{order} and scalar (split /\./, $dspt->{$_}->{order}) == $size and $dspt->{$_}->{order} ne '0'} keys %$dspt;
                    my $LN = $ref_LN;
                    for my $obj (@elegible_obj) {
                        for my $item ($data->{matches}->{$obj}->@*) {
                            if ($item->{LN} > $LN) {
                                $LN = $item->{LN};
                                last;
                            }
                        }
                    }
                    @$match_ARRAY = grep {exists $_->{LN} and $_->{LN} < $LN} @$matches_ALL;
                    $MATCHES[0] = $match_ARRAY;
                } elsif ($preserve_obj->[0]->[0] eq '' and scalar @$preserve_obj == 1) {
                    my $LN;
                    my $size = $lvlObj eq 'libName' ? 0 : scalar split /\./, $dspt_lvlObj->{order};
                    $size++;
                    my @elegible_obj = grep { exists $dspt->{$_}->{order} and scalar (split /\./, $dspt->{$_}->{order}) == $size and $dspt->{$_}->{order} ne '0'} keys %$dspt;
                    $LN = $ref_LN;
                    for my $obj (@elegible_obj) {
                        for my $item ($data->{matches}->{$obj}->@*) {
                            if ($item->{LN} > $LN) {
                                $LN = $item->{LN};
                                last;
                            }
                        }
                    }
                    my $pres_ARRAY = [ grep {exists $_->{LN} and $_->{LN} < $LN and  $_->{LN} > $ref_LN} @$matches_ALL];
                    push @MATCHES, $pres_ARRAY;
                }
            }
            #}}}

            ## Debug {{{
            mes( "IDX-$ind $obj -> $lvlObj", $data, [1])
                if $opts_divy->[1] == 2;
            mes( "[$ref_LN] <".$lvlObj."> ".$lvlItem, $data, [4])
                if $opts_divy->[1] == 2;
            #}}}

            ## matches_obj LOOP
            my $cnt;
            for my $array (@MATCHES) {
                $cnt++;
                my $partial_flag;
                $partial_flag = 1 if $cnt > 1;
                $obj = 'miss' if $cnt > 1;
                @$match_ARRAY = @$array;

                my $childObjs;
                my $flag = 0;
                for my $match (reverse @$match_ARRAY) {
                    next unless $match;
                    #print Dumper($match) if (scalar (split /\./, $dspt_lvlObj->{order}) == 1);

                    if ($match->{LN} > $ref_LN) {
                        my $match;
                        if ($presFlag) {
                           $match = pop @$match_ARRAY;
                        } elsif ($partial_flag) {
                           $match = pop @$match_ARRAY;
                        } else {
                           $match = pop @$matches_obj;
                        }
                        my $attrDebug = genAttributes( $data, $match, [$partial_flag, $presFlag]);
                        if ($presFlag || $partial_flag) {
                            my $obj = getLvlObj($data,$match);
                            unless (exists $match->{miss}) {
                                delete $match->{$obj};
                                $match->{miss} = $match->{raw};
                                delete $match->{raw};
                            }
                        }
                        push @$childObjs, $match;

                        ## Debug {{{
                        unless ($flag++) {
                            mes( "IDX-$ind $obj -> $lvlObj", $data, [1])
                                if ($opts_divy->[1] == 1);
                            mes( "[$ref_LN] <".$lvlObj."> ".$lvlItem, $data, [4])
                                if ($opts_divy->[1] == 1);
                        }

                        if ($opts_divy->[1]) {
                            mes( "($match->{LN}) <$obj> $match->{$obj}", $data, [4])
                                if $data->{dspt}->{$obj}->{partion};
                            mes( "($match->{LN}) <$obj> $match->{$obj}", $data, [4])
                                unless $data->{dspt}->{$obj}->{partion};
                        }

                        if (scalar $attrDebug->@* and $data->{opts}->{attribs}->[1]) { mes("$_",$data,[-1, 1]) for $attrDebug->@* }
                        #}}}

                    } else { last }
                }

                ## Check if childObjs is empty
                if ($childObjs) {
                    my $childObjs_Clone = dclone($childObjs);
                    if ($presFlag) {
                        @$childObjs_Clone = reverse @$childObjs_Clone;
                        unless (exists $refArray->[$ind]->{preserve}) { $refArray->[$ind]->{preserve} = [] }
                        @$childObjs_Clone = map {$data->{matches4}->{$_->{LN}} } @$childObjs_Clone;
                        my $ref = dclone($childObjs_Clone);
                        push $refArray->[$ind]->{preserve}->@*, @$ref;
                          #push $refArray->[$ind]->{preserve}->@*, @$childObjs_Clone;
                    } elsif ($partial_flag) {
                        @$childObjs_Clone = reverse @$childObjs_Clone;
                        $refArray->[$ind]->{preserve} = $childObjs_Clone;
                        splice( @$refArray, $ind, 1, ($refArray->[$ind], @$childObjs_Clone) );
                    } else {
                        @$childObjs_Clone = reverse @$childObjs_Clone;
                        $refArray->[$ind]->{$objGroupName} = $childObjs_Clone;
                        splice( @$refArray, $ind, 1, ($refArray->[$ind], @$childObjs_Clone) );
                    }
                    for my $hashRef (@$childObjs) { %$hashRef = () }
                }
            }
            $ind--;
        }
        return $objGroupName;
    }
}

#===| genAttributes() {{{2
sub genAttributes {

    my $data  = shift @_;
    my $match = shift @_;
    my $flags = shift @_;
    my $attr_opts = $data->{opts}->{attribs};

    ## Debug {{{
    my $debug     = [];
    #}}}

    if ($attr_opts->[0] and !$flags->[0] and !$flags->[1]) {

        my $obj     = getObj($data);
        my $objReff = $data->{dspt}->{$obj};
        $match->{raw} = $match->{$obj};

        if (exists $objReff->{attributes}) {
            my $attrDSPT = $objReff->{attributes};
            my @attrOrderArray = sort {
                $attrDSPT->{$a}->[1] cmp $attrDSPT->{$b}->[1];
                } keys $attrDSPT->%*;

            for my $attrib (@attrOrderArray) {
                my $attrReff = $attrDSPT->{$attrib};
                my $sucess = $match->{ $obj } =~ s/$attrReff->[0]//;
                my $fish = {};
                $fish->{caught} = $1 if $1;
                if ($sucess and !$1) {$fish->{caught} = '' }
                #if ($fish->{caught} && $fish->{caught} ne '') {
                if ($fish->{caught} || exists $fish->{caught}) {
                    $match->{$attrib} = $fish->{caught};

                    ## Debug {{{
                    if ($attr_opts->[1] == 1) {
                        push $debug->@*, mes("|${attrib}|", $data, [6, 1, 1]);
                        push $debug->@*, mes(" '".$match->{$attrib}."'", $data, [-1, 0, 1]);
                    }
                    #}}}

                    if (scalar $attrReff->@* == 3) {
                        delimitAttribute($data, $attrib, $match);
                    }
                }
            }


            unless ($match->{$obj}) {
                $match->{$obj} = [];
                for my $attrib (@attrOrderArray) {
                    if (exists $match->{$attrib}) {
                        push $match->{$obj}->@*, $match->{$attrib}->@*;
                    }
                }
            }
        }
    }
    return $debug;
}


#===| delimitAttribute() {{{2
sub delimitAttribute {

    ## Attributes
    my $data           = shift @_;
    my $objKey         = getObj($data);
    my $attributesDSPT = $data->{dspt}->{$objKey}->{attributes};

    ## Regex for Attribute Delimiters
    my $attributeKey = shift @_;
    my $delims       = join '', $attributesDSPT->{$attributeKey}->[2][0];
    my $delimsRegex  = ($delims ne '') ? qr{\s*[\Q$delims\E]\s*}
                                       : '';

    ## Split and Grep Attribute Match-
    my $match = shift @_;
    $match->{$attributeKey} = [
        grep { $_ ne '' }
        split( /$delimsRegex/, $match->{$attributeKey} )
    ];
}


#===| encodeResult() {{{2
sub encodeResult {

    my $data  = shift @_;
    if  ($data->{opts}->{encode}->[0]) {
        my $fname = $data->{fileNames}->{output};
        {
            my $json_obj = JSON::PP->new->ascii->pretty->allow_nonref;
            $json_obj = $json_obj->allow_blessed(['true']);
            if ($data->{opts}->{sort}) {
              $json_obj->sort_by( sub { cmpKeys( $data, $JSON::PP::a, $JSON::PP::b, $_[0] ); } );
            }
            my $json  = $json_obj->encode($data->{result});
            open( my $fh, '>' ,$fname ) or die $!;
                print $fh $json;
                truncate $fh, tell( $fh ) or die;
            close( $fh );
        }
    }
}


#===| genWriteArray(){{{2
sub genWriteArray {
    my $data       = shift;
    my $result     = dclone($data->{result});
    my $dspt       = $data->{dspt};
    my $write_opts = $data->{opts}->{write};
    my $writeArray = [];
    if ($write_opts->[0]) {

        $data->{seen}    = {};
        $data->{pointy}  = [];
        $data->{pointy2} = [];
        $data->{childs}  = {};
        $data->{hook}    = [];

        ## debug {{{
        mes("{{"."{", $data, [-1])
            if $write_opts->[1];
        # }}}

        # %dresser {{{
        my %dresser = (
            miss => {
                miss => [
                    '',
                    '',
                    '',
                    '',
                    '',
                    1,
                    1,
                    'section'
                ],
            },
            libName => {
                libName => [
                    '',
                    '',
                ],
            },
            title => {
                title => [
                    ">",
                    '',
                    '',
                    '',
                    '',
                ],
                title_attribute => [
                    ' (',
                    ')',
                ],
            },
            author => {
              author => [
                  "--------------------------------------------------------------------------------------------------------------\nBy ",
                  '',
                  '',
                  '',
                  '',
                  1,
                  3,
              ],
              author_attribute => [
                  ' (',
                  ')',
              ],
            },
            series  => {
                series => [
                    "===== "
                    , ' ====='
                ],
            },
            section => {
                section => [
                    "\n------------------------------------------------------------------------------------------------------------------------------\n-----------------------------------------------------% ",
                    " %-------------------------------------------------\n------------------------------------------------------------------------------------------------------------------------------",
                    '',
                    '',
                    '',
                    1,
                    2,
                    'miss'
                ],
            },
            tags => {
                anthro  => [
                    '[',
                    ']',
                    ';',
                    ';',
                    ' ',
                ],
                general => [
                    '[',
                    ']',
                    ';',
                    ';',
                    ' ',
                ],
                ops     => [
                    '',
                    '',
                    '',
                    '',
                    '',
                ],
            },
            url => {
                url           => [
                    '',
                    '',
                ],
                url_attribute => [
                    ' (',
                    ')',
                ],
            },
            description => {
                description => [
                    '#',
                    '',
                ],
            },
        ); #}}}
        # %dresser2 {{{
        my %dresser2 = (
            miss => {
                miss => [
                    '',
                    '',
                    '',
                    '',
                    '',
                    1,
                    1,
                    'section'
                ],
            },
            libName => {
                libName => [
                    '',
                    '',
                ],
            },
            title => {
                title => [
                    "\n>",
                    '',
                    '',
                    '',
                    '',
                    1,
                    1,
                    'series',
                ],
                title_attribute => [
                    ' (',
                    ')',
                ],
            },
            author => {
              author => [
                  "\n-----------------------------------------------------------------------------------------------------------------------------\n-----------------------------------------------------------------------------------------------------------------------------\nby ",
                  '',
                  '',
                  '',
                  '',
                  1,
                  3,
              ],
              author_attribute => [
                  ' (',
                  ')',
              ],
            },
            series  => {
                series => [
                    "\n=============/ ",
                    " /=============",
                ],
            },
            section => {
                section => [
                    "\n——————————————————————————————————————————————————————————————————————————————————\n%%%%% ",
                    " %%%%%\n——————————————————————————————————————————————————————————————————————————————————",
                    '',
                    '',
                    '',
                    1,
                    2,
                    'miss'
                ],
            },
            tags => {
                anthro  => [
                    '[',
                    ']',
                    ';',
                    ';',
                    ' ',
                ],
                general => ['[',
                    ']',
                    ';',
                    ';',
                    ' ',
                ],
                ops     => ['',
                    '',
                    '',
                    '',
                    '',
                ],
            },
            url => {
                url           => [
                    '',
                    '',
                ],
                url_attribute => [
                    ' (',
                    ')',
                ],
            },
            description => {
                description => [
                    '#',
                    ''
                ],
            },
        ); #}}}
        ## append DSPT {{{
        if ($data->{result}->{libName} eq 'catalog') {%dresser = %dresser2}
        for my $obj (keys %$dspt) {
            my $objDspt       = $dspt->{$obj};
            my $dressRef      = $dresser{$obj};
            $objDspt->{dresser} = $dressRef;
        }
        #}}}
        # $preprocess {{{
        my $preprocess = sub {

            my @children = @_;
            my $type     = $Data::Walk::type;
            my $index    = $Data::Walk::index;
            my $depth    = $Data::Walk::depth;
            my $lvl      = $depth - 2;

            if ($type eq 'HASH') {

                ## Tranform array to hash
                my $objHash = {};
                my $cnt = 0;
                for (@children) {
                    $objHash->{$children[$cnt - 1]} = $_ if ($cnt & 1);
                    $cnt++;
                }

                ## Tranform hash to array whilst sorting keys
                @children = ();
                for (sort {
                            if    ($a eq 'preserve' and $b ne 'libName' and $b ne 'section') {-1}
                            elsif ($b eq 'preserve' and $a ne 'libName' and $a ne 'section') {1}
                            elsif    ($a eq 'libName') {-1}
                            elsif ($b eq 'libName') {1}
                            elsif ($a eq 'SERIES' and $b eq 'STORIES') {1}
                            elsif ($b eq 'SERIES' and $a eq 'STORIES') {-1}
                            else { cmpKeys( $data, $a, $b, $objHash, [1]) }
                          } keys %{$objHash}) {
                    push @children, ($_, $objHash->{$_});
                }

            }
            return @children;

        }; #}}}
        # $wanted {{{
        my $wanted = sub {
            my $type  = $Data::Walk::type;
            my $index = $Data::Walk::index;
            my $depth = $Data::Walk::depth;
            my $lvl   = $depth - 2;


            ## HASH
            if ($type eq 'HASH' and $lvl >= 0) {
                my $objHash = $Data::Walk::container;
                my $obj     = getLvlObj($data, $objHash);
                my $item    = $objHash->{$obj};

                if ($_ eq $obj) {
                    my $objDspt  = $data->{dspt}->{$obj};
                    my $dresser  = dclone($objDspt->{dresser});

                    my $prior_lvl = (scalar $data->{index}->@*) - 1;
                    my $cnt = 0;
                    if ($lvl/2 < $prior_lvl) {
                        $cnt = $prior_lvl - $lvl/2;
                        if (scalar $data->{index}->@* != 1) {
                            pop @{$data->{index}} for (0..$cnt);
                        }
                    }

                    ## debug {{{
                    my $debug = [];
                    $data->{childs}->{$obj}++;
                    my $segmentRef = \$data->{childs}->{$obj};
                    my $point      = split /\./, $data->{dspt}->{$obj}->{order};
                    my $ind        = ($point eq '0') ? 0 : scalar $point;

                    unless (exists $data->{hook}->[$ind]) { $data->{hook}->[$ind] = {} }
                    $data->{hook}->[$ind]->{$obj} = $segmentRef;

                    if ( (scalar $data->{hook}->@*) > ($ind + 1) ) {
                        $data->{hook}->@[ ( $ind + 1 ) .. $data->{hook}->$#* ] =
                        map { my $hash = $data->{hook}->[$_];
                              my $hash2 = {map {
                                                 my $reff = $hash->{$_};
                                                 $reff->$* = 0; $_ => $reff;
                                               } keys %$hash};
                              $hash2;
                            } (($ind + 1 ) .. $data->{hook}->$#*);
                    }
                    $data->{index}->[$lvl/2] = [getGroupName($data,$obj), $segmentRef];
                    $data->{index}->@* = grep { defined $_->[0]; } $data->{index}->@*;
                    my @indArray = map {$_->[0] . "[".$_->[1]->$*."]" } $data->{index}->@*;
                    push $data->{pointy}->@*, join('.', @indArray);
                    push $data->{pointy2}->@*, [scalar @indArray, $obj];
                    if ($write_opts->[1] == 3) {
                        push @$debug, mes("PointStr: ".join('.', @indArray), $data, [1,0,1]);
                        push @$debug, mes("<$obj> $item", $data, [1,0,1]);
                        push @$debug, mes("ind: $ind", $data, [1,0,1]);
                        push @$debug, mes("lvl/2: ".$lvl/2, $data, [1,0,1]);
                    }
                    ## }}}

                    ## String
                    my $string = '';
                    if (ref $item ne 'ARRAY') {
                        $string = $dresser->{$obj}->[0]
                                . $item
                                . $dresser->{$obj}->[1];
                    }

                    ## Attributes String
                    my $attributes_String = '';
                    my $attrDspt = getAttrDspt($data, $obj);
                    if ($attrDspt) {

                        ## debug {{{
                        if ($write_opts->[1] == 3) {
                            my $mes = join ', ', sort { cmpKeys( $data, $a, $b, $objHash)
                                                 } keys %$attrDspt;
                            push @$debug, mes("|Attrs| ".$mes, $data, [1,0,1]);
                        }
                        #}}}

                        for my $attr (sort { $attrDspt->{$a}->[1]
                                             cmp
                                             $attrDspt->{$b}->[1] } keys %$attrDspt) {

                            ## Check existance of attributes
                            if (exists $objHash->{$attr}) {
                                my $attrItem = $objHash->{$attr};

                                ## Item Arrays
                                if (exists $attrDspt->{$attr}->[2]) {

                                    my @itemPartArray = ();
                                    for my $part (@$attrItem) {
                                        $part = $dresser->{$attr}->[2]
                                              . $part
                                              . $dresser->{$attr}->[3];
                                        push @itemPartArray, $part;
                                    }
                                    $attrItem = join $dresser->{$attr}->[4], @itemPartArray;
                                }

                                $attributes_String .= $dresser->{$attr}->[0]
                                                    . $attrItem
                                                    . $dresser->{$attr}->[1];

                                ## debug {{{
                                push @$debug, mes("|$attr| $attrItem", $data, [1,0,1])
                                    if $write_opts->[1] == 3;
                                #}}}

                            }
                        }
                    }

                    ## String Concatenation
                    $string = ($string) ? $string . $attributes_String
                                        : $attributes_String;

                    my $emptyFlag;
                    if (exists $data->{pointy2}->[-2] and exists $dresser->{$obj}->[5]) {
                        my $previousObj      = $data->{pointy2}->[-2]->[1];
                        my $previousObjOrder = $data->{pointy2}->[-2]->[0];
                        my $cnt              = $dresser->{$obj}->[6];
                        my $objOrder         = $data->{pointy2}->[-1]->[0];
                        if ($previousObjOrder < $objOrder) {
                          #print $obj if $obj eq 'miss';
                          #print $string if $obj eq 'miss';
                            if ($dresser->{$obj}->[7] and $previousObj eq $dresser->{$obj}->[7]) {
                                $string =~ s/.*\n// for (1 .. $cnt);
                                #print "(($string))" if $string eq '';
                                $emptyFlag = 1 if $string eq '';
                            } elsif (!$dresser->{$obj}->[7]) {
                                $string =~ s/.*\n// for (1 .. $cnt);
                            }
                        }
                        elsif ($previousObjOrder > $objOrder) {
                            if ($dresser->{$obj}->[7] and $previousObj eq $dresser->{$obj}->[7]) {
                                $string =~ s/.*\n// for (1 .. $cnt);
                            }
                        }
                        elsif ($previousObjOrder == $objOrder and $previousObj eq 'miss') {
                            if ($dresser->{$obj}->[7] and $previousObj eq $dresser->{$obj}->[7]) {
                                $string =~ s/.*\n// for (1 .. $cnt);
                            }
                        }
                        elsif ($previousObjOrder == $objOrder and $obj eq 'miss') {
                            if ($dresser->{$obj}->[7] and $previousObj eq $dresser->{$obj}->[7]) {
                                $string =~ s/.*\n// for (1 .. $cnt);
                            }
                        }
                    }

                    chomp $string if $obj eq 'miss';
                    #print "MISS {$string}\n" if $obj eq 'miss';
                    #print "SECTION {$string}\n" if $obj eq 'section';
                    unless ($emptyFlag) { push @$writeArray, $string if $obj ne 'libName'}

                    ## debug {{{
                    mes($string ,$data, [-1])
                        if $write_opts->[1] and $lvl != 0;

                    if ($write_opts->[1] == 3) { mes($_, $data, [-1,1]) for @$debug };

                    if ($data->{dspt}->{$obj}->{scalar} and $data->{pointy2}->[-2]->[1] eq $obj) {
                        $erreno = "ERROR: Scalar obj '$obj' was repeated!";
                        die;
                    }
                    #}}}

                }
            }

        }; #}}}

        walkdepth { wanted => $wanted, preprocess => $preprocess},  $result;
        mes("}}"."}", $data, [-1])
            if $write_opts->[1];
   }
   return $writeArray ? $writeArray : 0;
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


#===| genOpts() {{{2
sub genOpts {
    my $ARGS = shift @_;
    my $defaults = {

        ## Processes
        delegate => [1,0],
        leveler  => [1,0],
        divy     => [1,0],
        attribs  => [1,0],
        delims   => [1,0],
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


#===| getAttrDspt(){{{2
sub getAttrDspt {
    my ($data, $obj) = @_;
    my $objDspt = $data->{dspt}->{$obj};
    my $attrDspt = (exists $objDspt->{attributes}) ? $objDspt->{attributes}
                                                   : 0;
    return $attrDspt;
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


#===| isAttr(){{{2
sub isAttr {
    my ($data, $lvlObj, $key) = @_;
    my $attrDspt = getAttrDspt($data,$lvlObj);
    if ($attrDspt) {
        my $attr = (grep {$_ eq $key} keys %$attrDspt)[0];
        return ($attr) ? $attrDspt->{$attr}
                       : 0;
    }
    else {
        return 0;
    }
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
    my ($mes, $data, $opts, $bool) = @_;
    unless ($bool) {$bool = 1}

    if ($data->{opts}->{verbose} and $bool) {
        my ($cnt, $NewLineDisable, $silent) = @$opts if $opts;
        my $indent = "    ";

        $mes = ( $cnt ? $indent x (1 + $cnt) : $indent )
             . $mes
             . ( !($NewLineDisable) ? "\n" : "" );

        push $data->{debug}->@*, $mes unless $silent;
        return $mes;
    }
}



# OTHER {{{1
#------------------------------------------------------

#===| init2() {{{2
sub init2 {
    my $db = shift @_;
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
    no warnings 'uninitialized';
    use Data::Dumper;
    my $data   = shift @_;
    my $hash_0 = shift @_;
    my $hash_1 = shift @_;
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
            print " PointStr: ".join('.', $data->{pointer}->@*),"\n";

            my $hash_1 = $container;
            my $hash_2 = $lvlReff; if (ref $lvlReff eq 'ARRAY') {
                my $key  = $obj;
                my $key2 = ( exists $lvlReff->[$index]->{$key} ) ? $key : ' ';
                print "    Key_1: $key\n";
                print "    Key_2: $key2\n";
                print "  Value_1: $container->{$key}\n";
                print "  Value_2: $lvlReff->[$index]->{$key}\n";
                $hash_2 = $lvlReff->[$index];
            }

            if (join('.', $data->{pointer}->@*) =~ '0.1.0') {print Dumper($hash_1)}
            if (join('.', $data->{pointer}->@*) =~ '0.1.0') {print Dumper($hash_2)}
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
            print " PointStr: ".join('.', $data->{pointer}->@*),"\n";

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
                print "     Item1: $part\n";
                print "     Item2: $lvlReff->[$cnt]\n";
                print "      Obj1: " .$obj_1."\n";
                print "      Obj2: " .$obj_2."\n";

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
                    my $lvlReff  = $data->{reff}->[$lvl];
                    my $lvlReff2 = $data->{reff2}->[$lvl];
                    my $obj_1    = getLvlObj($data, $lvlReff2);
                    my $obj_2    = getLvlObj($data, $lvlReff);
                    my $thing_1  = $lvlReff2->{ getLvlObj($data, $lvlReff2) };
                    my $thing_2  = $lvlReff->{ getLvlObj($data, $lvlReff) };
                    print "\nWANT $item in $obj_1-$type $lvl ".$data->{pointer}->[$lvl]."\n";
                    print " PointStr: ".join('.', @{$data->{pointer}}),"\n";
                    print "  obj1: $obj_1\n";
                    print "  obj2: $obj_2\n";
                    print " item1: $thing_1\n";
                    print " item2: $thing_2\n";
                    print " item1: $lvlReff2->{$item}\n";
                    print " item2: $lvlReff->{$item}\n";

                    if (ref $lvlReff2->{$item} ne 'ARRAY'
                    and ref $lvlReff2->{$item} ne 'HASH'
                    and ref $lvlReff->{$item}  ne 'ARRAY'
                    and ref $lvlReff->{$item}  ne 'HASH'
                    and $lvlReff->{$item}      ne $lvlReff2->{$item} )
                    {
                        print $lvlReff->{$item} ." ne ". $lvlReff2->{$item}."\n";
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
                print "      Item: $item\n";
                print "      Obj1: $obj_1\n";
                print "      Obj2: $obj_2\n";

                my $thing1; if ($obj_1) {
                  $thing1 = $lvlReff2->[$index]->{$obj_1}
                } print "    thing1: $thing1\n";

                my $thing2; if ($obj_2) {
                    $thing2 = $lvlReff->[$index]->{$obj_2}
                } print "    thing2: $thing2\n";

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
