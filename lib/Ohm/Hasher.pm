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
use utf8;
use feature qw( current_sub );
use File::Basename;
use File::Path;
use JSON::XS;
use Storable qw(dclone);
use Carp qw(croak carp);
use Cwd;
use Data::Dumper;
use lib ($ENV{HOME}.'/hmofa/hmofa/lib');
use Data::Walk;
use Hash::Flatten qw(:all);

sub new { my ($class, $args) = @_;
    # Convert '$args' into type 'HASH', if not already
    unless (UNIVERSAL::isa($args, 'HASH')) {
        $args = {input => $_[1],dspt  => $_[2],drsr  => $_[3],mask  => $_[4],prsv  => $_[5]};
        # Remove args with undefined values
        delete $args->{$_} for grep { !(defined $args->{$_}) } keys %$args}
    # Create Object
    my $self = {}; bless $self, $class;
    # init
    $self->__init( $args ); return $self}

sub gen_dspt { my ($self, $args) = @_;
    my $dspt = do {open my $fh,'<:utf8',$self->{paths}{dspt}; local $/; decode_json(<$fh>)};
    $dspt = $self->gen_config('dspt', $dspt ); $self->{dspt} = $dspt;
    for my $obj (keys %$dspt) { my $objDSPT = $dspt->{$obj};
        for my $key (keys %$objDSPT) {
            if ($key eq 're') {$objDSPT->{cre} = qr/$objDSPT->{re}/}
            if ($key eq 'attrs') { my $dspt_attr = $objDSPT->{attrs};
                for my $attr (keys %$dspt_attr) {
                    $dspt_attr->{$attr}{cre} = qr/$dspt_attr->{$attr}{re}/;
                    if (defined $dspt_attr->{$attr}{delims}) { my $delims = join '', $dspt_attr->{$attr}{delims}->@*;
                        $dspt_attr->{$attr}{cdelims} = ($delims ne '') ? qr{\s*[\Q$delims\E]\s*} : ''}}}}}
    # check for duplicates: order
    my @keys  = sort map { exists $dspt->{$_}{order} and $dspt->{$_}{order} } keys %{$dspt};
    my %dupes;
    for (@keys) { die "Cannot have duplicate reserved keys!" if $dupes{$_}++ }
    my @orders = grep { defined } map {$dspt->{$_}{order}} keys %$dspt;
    $self->{meta}{dspt}{ord_max} = ( sort { length $b <=> length $a || substr($b, -1) <=> substr($a, -1); } @orders)[0];
    my @pntstr = split /\./, $self->{meta}{dspt}{ord_max};
    $pntstr[$#pntstr]++;
    $self->{meta}{dspt}{ord_limit} = join '.', @pntstr;
    $self->{meta}{dspt}{ord_map}->%* = map  { $dspt->{$_}{order} => $_ } grep { exists $dspt->{$_}{order} } keys %$dspt;
    my @sorted_ords  = sort {
            ( $a eq 'lib' ?-1 :0 ) || ( $b eq 'lib' ?1 :0 ) ||
            scalar (split /\./, $dspt->{$a}{order}) <=> scalar (split /\./, $dspt->{$b}{order}) ||
            ($dspt->{$a}{order} =~ m/-*\d+$/g)[0] <=> ($dspt->{$b}{order} =~ m/-*\d+$/g)[0] } keys %$dspt;
    $self->{meta}{dspt}{ord_sort_map} = [@sorted_ords];
    my @sorted_ords2  = sort {
            ( $a eq 'lib' ?1 :0 ) || ( $b eq 'lib' ?-1 :0 ) ||
            scalar (split /\./, $dspt->{$b}{order}) <=> scalar (split /\./, $dspt->{$a}{order}) ||
            ($dspt->{$a}{order} =~ m/-*\d+$/g)[0] <=> ($dspt->{$b}{order} =~ m/-*\d+$/g)[0] } keys %$dspt;
    $self->{meta}{dspt}{ord_sort_map2} = [@sorted_ords2];
    $self->{drsr} = do { open my $fh, '<', $self->{paths}{drsr} or die; local $/; decode_json(<$fh>); };
    $self->{drsr} = $self->gen_config( 'drsr', $self->{drsr}  );
    $self->{mask} = do { open my $fh, '<:utf8', $self->{paths}{mask} or die; local $/; decode_json(<$fh>); };
    $self->{mask} = $self->gen_config( 'mask', $self->{mask}  );
    $self->{smask} = [];
    for my $smask_path ( $self->{paths}{smask}->@* ) {
        my $smask = do { open my $fh, '<:utf8', $smask_path->[0] or die; local $/; decode_json(<$fh>); };
        $smask = $self->gen_config( 'mask', $smask  );
        unless ( $smask_path->[1] ) { $smask_path->[1] = ''; }
        push $self->{smask}->@*, [$smask, $smask_path->[1]]; }
    $self->{sdrsr} = [];
    for my $sdrs_path ( $self->{paths}{sdrsr}->@* ) {
        my $sdrsr = do { open my $fh, '<', $sdrs_path or die; local $/; decode_json(<$fh>); };
        $sdrsr = $self->gen_config( 'mask', $sdrsr  );
        use File::Basename;
        my $file = basename($sdrs_path);
        $sdrsr->{lib}{name} = $file;
        push $self->{sdrsr}->@*, $sdrsr; }
    $self->{dspt} = $dspt; return $self}




sub get_sum { my ($self, $args) = @_; my $copy = dclone $self;
    delete $copy->{tmp};
    if ( exists $copy->{dspt} ) { my $dspt = $copy->{dspt};
        for my $obj (keys %$dspt) { my $str = '';
            # Creaated Value String for each key in dspt obj.
            for my $key (sort keys $dspt->{$obj}->%*) { my $value = $dspt->{$obj}{$key}; my $ref   = ref $value;
                if ($ref eq 'HASH') {$value = '['.(join ',', sort keys %$value).']'}
                $str .= ';'.$key.':'.($value // 'n/a').'; '} $dspt->{$obj} = $str} $copy->{dspt} = $dspt}
    $copy->{dspt} = exists $copy->{dspt} ?1 :0;
    # MATCHES
    if (exists $copy->{matches}) { my $matches = $copy->{matches}; my $total = 0;
        if (exists $matches->{miss}) {
            $matches->{miss} = scalar $matches->{miss}->@*;
            $total += $matches->{miss}}
        $matches->{obj_count} = scalar keys $matches->{objs}->%*;
        for (keys $matches->{objs}->%*) {
            $matches->{objs}{$_} = scalar $matches->{objs}{$_}->@*;
            $total += $matches->{objs}{$_}}
        $matches->{total} = $total;
        $copy->{matches} = $matches}
    if (exists $copy->{meta}) { my $meta = $copy->{meta};
        $meta->{dspt}{ord_map} = scalar keys $meta->{dspt}{ord_map}->%*;
        $copy->{meta} = $meta}
    if (exists $copy->{circ}) {$copy->{circ} = scalar $copy->{circ}->@*}
    if (exists $copy->{stdout}) {$copy->{stdout} = scalar $copy->{stdout}->@*}
    $copy->{hash} = exists $copy->{hash} ?1 :0;
    return $copy}

sub gen_config { my ($self,$bp_name,$init_hash) = @_;
    my $bp = dclone $self->__gen_bp( $bp_name ) // die;
    my $config = populate ($self,$bp,{},0,$bp_name,);
    if ($init_hash) { my $flat_mask  = flatten $init_hash; my $flat_config = flatten $config;
        $flat_config = $self->__mask($flat_config, $flat_mask);
        $config = unflatten $flat_config}
    return $config;
    sub populate {
        my ($self,$bp,$config,$OBJ,$bp_name) = @_;
        my $member  = delete $bp->{member}  // die "no member hash in boiler_plate $bp_name";
        my $fill    = delete $bp->{fill}    // die "no fill hash in boiler_plate $bp_name";
        my $general = delete $bp->{general} // die "no general hash in boiler_plate $bp_name";
        my @RemKeys = keys %$bp;
        $config = dclone $general if $general;
        if (%$member) { my @KEYS;
            if ($OBJ) {@KEYS = keys $self->{dspt}{$OBJ}{attrs}->%*; push @KEYS, $OBJ if $fill}
            else {@KEYS = keys $self->{dspt}->%*}
            for my $key (@KEYS) {
                $config->{$key} = populate ($self,dclone $member,$config->{$key},$key,$bp_name)}}
        for my $key ( @RemKeys ) {
            $config->{$key} = populate ($self,dclone $bp->{$key},$config->{$key},$OBJ,$bp_name)}
        if (ref $config eq 'HASH') {
            my $flat_mask  = flatten (dclone $general) if $general;
            my $flat_config = flatten $config;
            $flat_config = $self->__mask($flat_config, $flat_mask);
            return unflatten $flat_config}
        return $config}

    sub __mask { my ($self,$flat_config,$flat_mask) = @_;
        for my $key ( keys %$flat_mask ) {
            my $str = $key;
            my $pat;
            my $end;
            my @KEYS;
            my $delim = '';
            my @CLN = (0);
            while ( scalar @KEYS > 1 || scalar @CLN ) {
                if ( $str =~ s/((?:\\\:|\\\.|[_[:alnum:]])+)((?:\.|:)*)// ) {
                    $pat  .= $delim.$1;
                    $delim = $2 // '';
                    $end = $delim ? '' : '$'}
                @KEYS = grep {$_ =~ /^\Q$pat\E($|:|\.)/ } keys %$flat_config;
                @CLN  = grep {$_ !~ m/^\Q$pat$delim\E$end/ } @KEYS;
                delete $flat_config->{$_} for @CLN}
            $flat_config->{$key} = $flat_mask->{$key}}
        return $flat_config}}


sub __divy { my ($self, $args) = @_;
    $self->{hash} = $self->gen_config( 'objHash', { val => $self->{name}, obj => 'lib', } );
    $self->{m}{reffArray} = [$self->{hash}];
    $self->{m}{point}     = [1];
    $self->{m}{pointer}   = [];
    __leveler( $self );
    delete $self->{m};
    return $self;
    sub __leveler  { my ( $self ) = @_;
    # iterates in 2 dimensions the order of the dspt
        ## check existance of OBJ at current point
        my $obj = __getObj( $self );
        return unless $obj;
        ## Reverence Arrary for the current recursion
        my $recursionReffArray;
        while ( $obj ) {
            ## Checking existance of recursionReffArray
            unless ( defined $recursionReffArray ) {$recursionReffArray->@* = $self->{m}{reffArray}->@*}
            ## divy
            __divyMatches( $self );
            ## Check for CHILDREN
            __changePointLvl( $self->{m}{point}, 1 );
            __leveler( $self );
            __changePointLvl( $self->{m}{point });
            $self->{m}{reffArray}->@* = $recursionReffArray->@*;
            ## Check for SYBLINGS
            if (scalar $self->{m}{point}->@*) {$self->{m}{point}[-1]++}
            else {last}
            $obj = __getObj($self)}
        ## Preserves
        if (__getPointStr($self) eq $self->{meta}{dspt}{ord_limit}) {
            $self->{m}{point}->@* = (-1);
            __divyMatches( $self )}
        return $self}

    sub __divyMatches { my ($self) = @_; my $obj = __getObj( $self );
        return unless exists $self->{matches}{objs}{$obj};
        my @objMatches = $self->{matches}{objs}{$obj}->@*;
        ## --- REFARRAY LOOP
        my $refArray = $self->{m}{reffArray};
        my $ind = ( scalar @$refArray ) - 1;
        for my $ref ( reverse @$refArray ) { my $ref_LN = $ref->{meta}{LN} // 0; my $childObjs;
            ## --- MATCHES LOOP
            for my $match (reverse @objMatches) {
                if ($match->{meta}{LN} > $ref_LN) { my $match = pop @objMatches;
                    __genAttributes($self, $match);
                    push @$childObjs, $match}
                else {last}}
            ## --- MATCHES TO REF ARRAY
            if ($childObjs) {
                @$childObjs = reverse @$childObjs;
                $refArray->[$ind]{childs}{$obj} = $childObjs;
                #add matches to ref array
                splice( @$refArray,$ind,1,($refArray->[$ind],@$childObjs))}
            $ind--}}

    sub __genAttributes { my ($self, $match) = @_; my $obj = $self->__getObj;
        $match->{meta}{raw} = $match->{$obj};
        if (exists $self->{dspt}{$obj}{attrs}) { my $attrsDspt = $self->{dspt}{$obj}{attrs};
            my @ATTRS = sort {$attrsDspt->{$a}{order} cmp $attrsDspt->{$b}{order}} keys %$attrsDspt;
            for my $attr (@ATTRS) { my $success = $match->{val} =~ s/$attrsDspt->{$attr}{cre}//;
                if ($success) { $match->{attrs}{$attr} = $1;
                    if (defined $attrsDspt->{$attr}{delims}) {$self->__delimitAttr($attr, $match)}}}
            unless ($match->{val}) {
                $match->{val} = [];
                for my $attr(@ATTRS) {
                    if (exists $match->{attrs}{$attr}) {
                        push $match->{val}->@*, $match->{attrs}{$attr}->@*}}}}}
    sub __delimitAttr { my ($self,$attr,$match ) = @_; my $objKey   = __getObj($self);
        my $dspt_attr = $self->{dspt}{$objKey}{attrs};
        ## Regex for Attribute Delimiters
        my $delimsRegex = $dspt_attr->{$attr}{cdelims};
        ## Split and Grep Attribute Match-
        $match->{attrs}{$attr} = [grep {$_ ne ''} split(/$delimsRegex/,$match->{attrs}{$attr})]}
    sub __changePointLvl { my $point = shift @_; my $op    = shift @_;
        if ($op) {push $point->@*,1}
        else     {pop $point->@*,1}
        return $point}
    sub __getObj { my ($self) = @_;
        my $pntstr = join('.', $self->{m}{point}->@*) or  die "pointStr cannot be an empty string!";
        return $self->{meta}{dspt}{ord_map}{$pntstr} // 0}
    sub __getPointStr { my $self = shift @_; my $pointStr = join('.', $self->{m}{point}->@*);
        return ($pointStr ne '') ? $pointStr : 0}}

sub __sweep { my ($self, $subs) = @_;
    my $sub_list = {reffs => \&gen_reffs,matches => \&gen_matches,plhd => \&place_holder };
    $self->{m} = {};
    walk ({ wanted => sub {for my $name (@$subs) {$sub_list->{$name}->($self)}}},
        $self->{hash} // die " No hash has been loaded for object '$self->{name}'");
    delete $self->{m};
    return $self;
    sub gen_reffs { my ($self,$args) = @_;
        $self->{circ} = [] unless exists $self->{circ};
        if (UNIVERSAL::isa($_, 'HASH')) { my $objHash = $_; my $objArr  = $Data::Walk::container; my $obj = $objHash->{obj} // 'NULL';
            $objHash->{circ}{'.'}   = $objHash;
            $objHash->{circ}{'..'}  = $objArr // 'NULL';
            push $self->{circ}->@*, $objHash->{circ}}

        elsif (UNIVERSAL::isa($_, 'ARRAY')) { my $objArr = $_; my $ParentHash  = $Data::Walk::container;
            unshift @$objArr, {'.'  => $_,'..'  => $ParentHash // 'NULL'}; push $self->{circ}->@*, $objArr->[0]}}

    sub gen_matches { my ($self, $args) = @_;
        unless (exists $self->{matches}) {$self->{matches} = {objs => {},miss => [{a => 2}]}}
        if (UNIVERSAL::isa($_, 'HASH')) {my $objHash = $_;my $obj = $objHash->{obj};push $self->{matches}{objs}{ $obj }->@*,$objHash}}

    sub place_holder { my $self = shift @_;
        if (UNIVERSAL::isa($_,'HASH')) { my $objHash = $_; my $obj     = $objHash->{obj}; my $objMask = $self->{mask}{$obj} // return 1;
            if ($objMask->{place_holder}{enable}) {
                for my $child ($objMask->{place_holder}{childs}->@*) {
                    unless (exists $objHash->{childs}{$child->[0]}) { my $childHash = $objHash->{childs}{$child->[0]}[0] = {};
                        %$childHash = (obj => $child->[0],val => $child->[1],meta => undef);
                        # attributes
                        my $childDspt = $self->{dspt}{$child->[0]};
                        if (defined $childDspt->{attrs}) { for my $attr (keys $childDspt->{attrs}->%*) {
                                if (exists $childDspt->{attrs}{$attr}{delims}) {$childHash->{attrs}{$attr} = []}
                                else {$childHash->{attrs}{$attr} = ''}}}}}}}}}

sub __commit { my ($self, $args) = @_;
    if ($self->{state} ne 'ok') { print "Commit aborted, object state is not ok\n"; return}
    my $db = $self->{paths}{dir}."/db";
    unless (-d $self->{paths}{dir}) {mkdir($self->{paths}{dir})}
    unless (-d $db) {mkdir($db)}
    $self->{paths} = $self->gen_config('paths',{smask => $self->{paths}{smask}});
    $self->rm_reff;
    use Data::Structure::Util qw( unbless );
    my @KEYS = qw( hash dspt matches drsr mask);
    for my $key (@KEYS) { my $hash = dclone $self->{$key};
        if ($key eq 'matches') {
            for my $obj (keys $hash->{objs}->%*) {
                for my $match ($hash->{objs}{$obj}->@*) {delete $match->{childs}}}}
        my $json = JSON::XS->new->pretty->allow_nonref->allow_blessed(['true'])->encode( $hash );
        open my $fh, '>:utf8', $self->{paths}{cwd} . "$db/$key.json" or die;
            print $fh $json;
            truncate $fh, tell($fh) or die; seek $fh,0,0 or die; close $fh}
    delete $self->{drsr};
    delete $self->{mask};
    unless (-d $self->{paths}{cwd} . "$db/smask") {mkdir($self->{paths}{cwd} . "$db/smask")}
    $self->{paths}{smask} = [];
    for my $hash ($self->{smask}->@*) {
        push $self->{paths}{smask}->@*, [$self->{paths}{cwd} . "$db/smask/" . $hash->[0]{lib}{name}.".json", $hash->[1]];
        my $json = JSON::XS->new->pretty->allow_nonref->allow_blessed(['true'])->encode( $hash->[0] );
        open my $fh, '>:utf8', $self->{paths}{cwd} . "$db/smask/" . $hash->[0]{lib}{name}.".json" or die;
            print $fh $json;
            truncate $fh, tell($fh) or die; seek $fh,0,0 or die; close $fh}
    unless ( -d $self->{paths}{cwd} . "$db/sdrsr" ) {mkdir($self->{paths}{cwd} . "$db/sdrsr")}
    $self->{paths}{sdrsr} = [];
    for my $hash ( $self->{sdrsr}->@* ) { my $filename = ($self->{paths}{cwd}) . ("$db/sdrsr/") . ($hash->{lib}{name});
        push $self->{paths}{sdrsr}->@*, $filename}
    { my $hash = dclone $self;
        for my $key (@KEYS, 'stdout', 'tmp', 'circ', 'meta', 'cwd', 'smask', 'sdrsr', 'mmm') {delete $hash->{$key}}
        my $json = JSON::XS->new->pretty->allow_nonref->allow_blessed(['true'])->encode( unbless $hash );
        open my $fh, '>:utf8', $self->{paths}{cwd} . "$db/self.json" or die;
            print $fh $json;
            truncate $fh, tell($fh) or die; seek $fh,0,0 or die; close $fh}
    use File::Copy;
    my $oldfile = $self->{paths}{output} . $self->{paths}{dir} . '/tmp/' . $self->{name} . '.txt';
    my $newfile = $self->{paths}{cwd} . $db . '/output.txt';
    copy($oldfile, $newfile) or die "failed copy of $oldfile to $newfile: $!";
    $self->__sweep(['reffs']);
    $self->__genObjLists();
    return $self}




#####################################
############## GEN WRITE ############
#####################################

sub __genWrite { my ($self,$mask,$sdrsr) = @_;
    
    # Load Configs
    $self->{stdout}       = [];
    my $dspt              = $self->{dspt};
    
    # Set Runtime Variables
    $self->{m}{prevDepth} = '';
    $self->{m}{prevObj}   = 'NULL';
    $self->{mmm} = {
        'author' => 0,
        'series' => 0,
        'title' => 0,
        'section' => 0,
    };

    # Check if mask was supplied, else use config
    unless ($mask) {$mask = $self->{mask}}

    walk ({

        # wanted subroutine
        wanted => sub {

                # Current Element
                my $item = $_;
        
                # Container of Element
                my $container  = $Data::Walk::container;

                # non 'lib' hash objects
                if (ref $item eq 'HASH' && $item->{obj} ne 'lib') { my $obj = $item->{obj}; my $drsr = $self->{drsr};

                    # if no sdrs provided use config
                    if ($sdrsr) {$drsr = $sdrsr};
                    my $depth = $Data::Walk::depth;
                    my $str = '';

                    # If suppress all is True, skip node and return m vars to previous node
                    if ($mask->{$obj}{supress}) {
                        if ($mask->{$obj}{supress}{all}) {
                            $self->{m}{prevDepth} = $depth;
                            $self->{m}{prevObj} = $obj;
                            return}}

                    ## --- String: d0, d1
                    if (ref $item->{val} ne 'ARRAY') { my $vall = $item->{val};

                        # html file modifications
                        if ($mask->{lib}{name} eq 'newbin.html') {
                            $vall =~ s/&/&amp/g;
                            $vall =~ s/</&lt/g;
                            $vall =~ s/>/&gt/g;
                            $vall =~ s/'/&#39/g;
                            $vall =~ s/"/&quot/g;
                            if ($item->{val} =~ m/^(http[^ ]+)/) {
                                if (length($1) > 80) {
                                    $vall =~ s/(http[^ ]+)/                        <a href="$1">Link<\/a>/
                                }
                                else {
                                    $vall =~ s/(http[^ ]+)/                        <a href="$1">$1<\/a>/
                                }
                            }
                            elsif ($vall =~ /^\s*masterbin\s*$/)           {
                                $vall =~ s/\s*masterbin\s*//;
                            }
                            if ($obj eq 'prsv') {
                                $vall =~ s/\[(.+)\]\((http[^ ]+)\)/<a href="$2">$1<\/a>/;
                                $vall =~ s/^-&gt/<center>/;
                                $vall =~ s/&lt-$/<\/center>/;
                                if    ($vall =~ /rentry\.org\/hmofa\b/)          {$vall =~ s/^- (.+)/            <ul>\n                <li>$1<\/li>/}
                                elsif ($vall =~ /Program/)            {$vall =~ s/^- (.+)/                <li>$1<\/li>\n            <\/ul>\n        <\/div>/}
                                elsif ($vall =~ /== \*\*LINKS\*\*/)   {$vall =~ s/.*/        <div>\n            <br\/><br\/>LINKS<br\/>/}
                                elsif ($vall =~ /azuhmier/)           {
                                    $vall =~ s/^</        </;
                                    $vall =~ s/> />/;
                                    $vall =~ s/ <\//<\//;
                                }
                                elsif ($vall =~ /ETC/) {
                                    $vall =~ s/^</        </;
                                    $vall =~ s/> />/;
                                    $vall =~ s/ <\//<\//;
                                }
                                elsif ($vall =~ /TABLE OF CONTENTS/) { $vall =~ s/.*\n// }
                                elsif ($vall =~ /TOC2/) { $vall =~ s/.*\n// }
                                else                                  {$vall =~ s/^- (.+)/                <li>$1<\/li>/}}}
                                
                          


                        # initial dressing
                        $str .= $drsr->{$obj}{$obj}[0] .  $vall .  $drsr->{$obj}{$obj}[1]}

                    ## --- Attributes String: d0, d1, d2, d3, d4
                    my $attrStr = '';
                    my $attrDspt = $dspt->{$obj}{attrs};
                    if ($attrDspt) {
                        for my $attr (sort {$attrDspt->{$a}{order} cmp $attrDspt->{$b}{order}} keys %$attrDspt) {
                            if (exists $item->{attrs}{$attr}) { my $attrItem = $item->{attrs}{$attr} // '';

                                # if $attrItem is a ref, clone it
                                if (ref $attrItem) {$attrItem = dclone $item->{attrs}{$attr}}

                                ## Item Arrays
                                if (exists $attrDspt->{$attr}{delims}) { my @itemPartArray = ();
                                    for my $part (@$attrItem) {
                                        unless (defined $drsr->{$obj}{$attr}[2] || defined $drsr->{$obj}{$attr}[3]) {die " obj '$obj' does not have delims drsrs"}
                                        if (exists $mask->{$obj}{removeInTag}) { my $removeInTag = $mask->{$obj}{removeInTag};
                                            $part =~ s/\w+\Q$removeInTag\E//}

                                        #html file escapes
                                        if ($mask->{lib}{name} eq 'newbin.html') {
                                            $part =~ s/&/&amp/g;
                                            $part =~ s/</&lt/g;
                                            $part =~ s/>/&gt/g;
                                            $part =~ s/'/&#39/g;
                                            $part =~ s/"/&quot/g}


                                        $part = $drsr->{$obj}{$attr}[2] . $part . $drsr->{$obj}{$attr}[3]; push @itemPartArray, $part}
                                    $attrItem = join $drsr->{$obj}{$attr}[4], @itemPartArray}
                                $attrStr .= $drsr->{$obj}{$attr}[0] .  $attrItem .  $drsr->{$obj}{$attr}[1]}}}


                    ## --- Line Striping: d5,d6
                    my $F_empty;
                    if (exists $drsr->{$obj}{$obj} and exists $drsr->{$obj}{$obj}[5] and $self->{m}{prevDepth}) {
                        my $prevObj   = $self->{m}{prevObj};
                        my $prevDepth = $self->{m}{prevDepth};
                        my $ref       = ref $drsr->{$obj}{$obj}[5];
                        my $tgtObjs   = ($ref eq 'HASH') ?$drsr->{$obj}{$obj}[5] :0;

                        ## strip lines only after target object
                        if ($tgtObjs && exists $tgtObjs->{$prevObj}) { my $cnt = $tgtObjs->{$prevObj};

                            # descending lvl
                            if ($prevDepth < $depth) {$str =~ s/.*\n// for (1 .. $cnt); $F_empty = 1 if $str eq ''; }

                            # ascending lvl
                            elsif ($prevDepth > $depth) {$str =~ s/.*\n// for (1 .. $cnt)}

                            # maintaining lvl
                            elsif ($prevDepth == $depth) {

                                # Preserve
                                if ($obj eq 'prsv') {$str =~ s/.*\n// for (1 .. $cnt)}

                                # Post Preserve
                                elsif ($prevObj eq 'prsv') {$str =~ s/.*\n// for (1 .. $cnt)}}}

                        ## strip lines after all objects

                        # descending lvl
                        elsif (!$tgtObjs and $prevDepth < $depth) {my $cnt = $drsr->{$obj}{$obj}[5]; $str =~ s/.*\n// for (1 .. $cnt)}} #}}}

                    ## --- Line Chopping d7
                    if (ref $drsr->{$obj}{$obj}[6] eq 'HASH' and exists $drsr->{$obj}{$obj}[6]{chop}) {
                        my $last = $self->{matches}{objs}{$obj}->$#*;
                        my $cnt = -1;
                        for my $reff ($self->{matches}{objs}{$obj}->@*) { $cnt++;
                            if ($reff == $item) {last}}
                        if ($cnt == $last) {return}}

                    ## --- String Concatenation 
                    $str = ($str) ? $str . $attrStr : $attrStr;
                    chomp $str if $obj eq 'prsv';
                    unless ($F_empty) {
                        if ($obj eq 'prsv') {
                            push $self->{stdout}->@*, $str if $obj ne 'lib';
                            if ( exists $mask->{lib}{prsv_tail} && $item->{meta}{LN} == $mask->{lib}{prsv_tail}[0]) {
                                my $tail = $mask->{lib}{prsv_tail}[1];

                                # html
                                if ($mask->{lib}{name} eq 'newbin.html') {}

                                push $self->{stdout}->@*, $tail; }
                        }
                        else {

                            ## --- closing html tags
                            if ($mask->{lib}{name} eq 'newbin.html' and $obj ne 'prsv') {

                                if ($obj eq 'section') {
                                    if ($self->{mmm}{section} eq 1)  {
                                        $str = "        <\/div>\n".$str;
                                        $self->{mmm}{section} = 0;
                                        if ($self->{mmm}{author} eq 1)  {
                                            $str = "            <\/div>\n".$str;
                                            $self->{mmm}{author} = 0;
                                            if ($self->{mmm}{series} eq 1) {
                                                $str = "                <\/div>\n".$str;
                                                $self->{mmm}{series} = 0;
                                            }
                                            if ($self->{mmm}{title} eq 1)  {
                                                $str = "                <\/div>\n".$str;
                                                $self->{mmm}{title} = 0;
                                            }
                                        }
                                    }
                                }
                                #AUTHOR
                                elsif ($obj eq 'author') {
                                    if ($self->{mmm}{author} eq 1)  {
                                        $str = "            <\/div>\n".$str;
                                        $self->{mmm}{author} = 0;
                                        if ($self->{mmm}{series} eq 1) {
                                            $str = "                    <\/div>\n".$str;
                                            $self->{mmm}{series} = 0;
                                        }
                                        if ($self->{mmm}{title} eq 1)  {
                                            $str = "                    <\/div>\n".$str;
                                            $self->{mmm}{title} = 0;
                                        }
                                    }
                                }
                                #TITLE
                                elsif ($obj eq 'title'){
                                    if ($self->{mmm}{title} eq 1)  {
                                        $str = "                    <\/div>\n".$str;
                                        $self->{mmm}{title} = 0;
                                    }
                                }
                                #SERIES
                                elsif ($obj eq 'series') {
                                    if ($self->{mmm}{title} eq 1)  {
                                        $str = "                    <\/div>\n".$str;
                                        $self->{mmm}{title} = 0;
                                    }
                                    if ($self->{mmm}{series} eq 1) {
                                        $str = "                    <\/div>\n".$str;
                                        $self->{mmm}{series} = 0;
                                    }
                                }
                                if ($obj eq 'section' ||  $obj eq 'title' || $obj eq 'author' || $obj eq 'series') {$self->{mmm}{$obj} = 1}
                            }

                            push $self->{stdout}->@*, split/\n/, $str if $obj ne 'lib'
                        }
                    }
                    $self->{m}{prevDepth} = $depth;
                    $self->{m}{prevObj} = $obj}
                if (ref $item eq 'ARRAY' ) {}
            },

            # preprocess subroutine
            preprocess => sub {my $type = $Data::Walk::type; my @children = @_;
                # Alphabetically sort child object names
                if ($type eq 'HASH') {
                    # using bitwise operator '&' on 2-base versions of indexes to seperate even and odds.
                    #even nums: 0, 10, 100, 110, 1000, 1010
                    #odd  nums: 1, 11, 101, 111, 1001, 1011
                     
                    # get odd number idexes
                    my @values = map { $children[$_]           } grep { $_ & 1    } (0..$#children);

                    # get even number idexes
                    my @keys   = map { $children[$_]           } grep { !($_ & 1) } (0..$#children);

                    my @var    = map { [$keys[$_],$values[$_]] }                    (0..$#keys);

                    if ($mask->{lib}{name} eq 'newbin.html') {
                        my $first = $dspt->{url}{order};
                        $dspt->{url}{order} = $dspt->{description}{order};
                        $dspt->{description}{order} = $first;
                    }
                    @children = map {@$_} sort {
                            if (scalar (split /\./, $dspt->{$b->[0]}{order}) != scalar (split /\./,$dspt->{$a->[0]}{order})) {
                                  join '', $dspt->{$b->[0]}{order} cmp join '', $dspt->{$a->[0]}{order}}
                            else {join '', $dspt->{$a->[0]}{order} cmp join '', $dspt->{$b->[0]}{order}} } @var;
                    if ($mask->{lib}{name} eq 'newbin.html') {
                        my $first = $dspt->{url}{order};
                        $dspt->{url}{order} = $dspt->{description}{order};
                        $dspt->{description}{order} = $first;
                    }
                }

                # Alphabetically sort child object values
                elsif ($type eq 'ARRAY') { my $item = \@children; my $idx_0 = (exists  $item->[0]{obj}) ?0 :1; my $obj = $item->[$idx_0]{obj};
                    if ( scalar $mask->{$obj}{supress}{vals}->@* ) {
                        for my $idx ($mask->{$obj}{supress}{vals}->@*) {splice @$item, ($idx+$idx_0),1} }
                    if ( $mask->{$obj}{sort} != 0 ) {
                        @children = sort {lc $a->{val} cmp lc $b->{val}}@children}}return @children},},$self->{hash});
    delete $self->{m};
    return $self}





sub __get_matches { my ($self,$line,$FR_prsv,$tmp) = @_; my $tgt = $tmp ? $self->{tmp} : $self; my $dspt = $self->{dspt};
    my $match;
    for my $obj (keys %$dspt) { $tgt->{matches}{objs}{$obj} = [] unless exists $tgt->{matches}{objs}{$obj}; my $regex = $dspt->{$obj}{cre} // 0;
        if ($regex and $line =~ $regex) {
            last if _isPrsv($self,$obj,$1,$FR_prsv);
            $match = {obj => $obj, val => $1, meta => {raw => $line, LN  => $.}};
            $self->_checks($match);
            push $tgt->{matches}{objs}{$obj}->@*, $match}}
    if (!$match and _isPrsv( $self, 'NULL', '', $FR_prsv)) {
        $tgt->{matches}{objs}{prsv} = [] unless exists $tgt->{matches}{objs}{prsv};
        $match = {obj => 'prsv',val => $line, meta => {raw => $line,LN => $.}};
        $self->_checks($match,'prsv');
        push $tgt->{matches}{objs}{prsv}->@*, $match}
    elsif ( !$match ) {
        $tgt->{matches}{miss} = [] unless exists $tgt->{matches}{miss};
        $match = {obj => 'miss',val => $line,meta => {raw => $line,LN  => $.}};
        $self->_checks( $match,'miss' );
        push $tgt->{matches}{miss}->@*, $match}
    ## -- subroutnes
    sub _isPrsv { my ($self, $obj, $match, $FR_prsv) = @_; my $dspt = $self->{dspt};
        if (defined $self->{prsv} and $obj eq $self->{prsv}{till}[0]) {
            $FR_prsv->{F} = 0, if $FR_prsv->{cnt} eq $self->{prsv}{till}[1];
            $FR_prsv->{cnt}++}
        if (defined $self->{prsv}) {return $FR_prsv->{F}}
        else {return 0} }
    sub _checks { my ($self, $match, $type);
        if ($type and $type eq 'miss') {if ( $match->{line} =~ /\w/) {}}}
    return $FR_prsv}

sub __validate  { my ( $self ) = @_;
    # --------- Dummy File --------
    # TMP DIR
    my $tmpdir = $self->{paths}{output} . $self->{paths}{dir} . '/tmp/';
    mkdir($tmpdir) unless(-d $tmpdir);
    # tgt filepath
    my $dir = $self->{paths}{output} . $self->{paths}{dir} . '/tmp/';
    # create filepath
    mkdir($dir) unless(-d $dir);
    # write to filepath
    open my $fh_22, '>:utf8', $dir . $self->{name} . '.txt' or die $!;
        for ($self->{stdout}->@*) {print $fh_22 $_,"\n"}
        truncate $fh_22, tell($fh_22) or die; seek $fh_22,0,0 or die; close $fh_22;
    my $CHECKS;
    my $Diffdir = $tmpdir.'/diffs/';
    mkdir($Diffdir) unless(-d $Diffdir);
    my $tmpFile = $self->{paths}{output} . $self->{paths}{dir} . '/tmp/' . $self->{name} . '.txt';
    my $file = $self->{paths}{input};
    $CHECKS->{txtCmp}{fp}  = $Diffdir . 'diff.txt';
    $CHECKS->{txtCmp}{out} = [`diff $file $tmpFile`];
    $self->{meta}{tmp}{matches} = {};
    $self->get_matches(1);
    my @matches = map {[$_,$self->{matches}{objs}{$_},$self->{tmp}{matches}{objs}{$_},]} keys $self->{matches}{objs}->%*;
    my $miss_matches = ['miss',$self->{matches}{miss},$self->{tmp}{matches}{miss},];
    push @matches, $miss_matches;
    my @OUT;
    for my $part (@matches) { my ( $obj, $val, $val2 ) = @$part;
        $val = $val // [1];
        $val2 = $val2 // [1];
        if (scalar @$val != scalar @$val2) {
            push @OUT, $obj .  ':' .  (scalar @$val) .  ':' .  (scalar @$val2) .  "\n"}}
    $CHECKS->{matchCmp}{fp}  = $Diffdir.'cnt.txt';
    $CHECKS->{matchCmp}{out} = [@OUT];
    if ( $self->{paths}{input} eq $self->{cwd}.'/.ohm/db/output.txt' ) { my $oldHash = do
        { open my $fh, '<', $self->{cwd}.'/.ohm/db/hash.json';local $/;decode_json(<$fh>)};
        $self->rm_reff;
        my $newHash = dclone $self->{hash};
        my $newFlat = $self->__see($newHash,'lib',[]);
        my $oldFlat = $self->__see($oldHash,'lib',[]);
        my $newFlat2 = [];
        my $oldFlat2 = [];
        for my $aref ([$oldFlat, $oldFlat2], [$newFlat, $newFlat2]) {
            for my $part ($aref->[0]->@*) {
                if ( $part !~ /LN=/ && $part !~ /raw=/ && $part !~ /\.obj/ && $part !~ /\.tags:\[\d+\]\.attrs/) {
                    $part .= "\n";
                    $part =~ s/\.childs//g;
                    $part =~ s/\.val=.*$//g;
                    $part =~ s/(\.tags:)\[\d+\]\.val:\[\d+\]=(.*)/$1\[$2\]/g;
                    push $aref->[1]->@*, $part}}}
        my $oldPath = $Diffdir . 'oldHash';
        my $newPath = $Diffdir . 'newHash';
        my $fh;
        open $fh, ">:utf8", $oldPath;
        print $fh @$oldFlat2;
        truncate $fh, tell($fh) or die; seek $fh,0,0 or die; close $fh;
        open $fh, ">:utf8", $newPath;
        print $fh @$newFlat2;
        truncate $fh, tell($fh) or die; seek $fh,0,0 or die; close $fh;
        $CHECKS->{hashCmp}{fp}  = $Diffdir . 'hashDiff.txt';
        $CHECKS->{hashCmp}{out} = [`bash -c "diff <(sort $oldPath) <(sort $newPath)"`];
        if ($oldPath =~ /ohm/) {unlink $oldPath};
        if ($newPath =~ /ohm/) {unlink $newPath}}
    else {
        open my $fh, ">", $Diffdir . 'hashDiff.txt';
        print $fh '';
        truncate $fh, tell($fh) or die; seek $fh,0,0 or die; close $fh}
    for my $check (values %$CHECKS) { my $out = $check->{out}; my $fp  = $check->{fp};
        open my $fh, '>:utf8', $fp or die;
            print $fh @$out;
            truncate $fh, tell($fh) or die; seek $fh,0,0 or die; close $fh}
    # open non-empty check files in less
    my @files = glob $Diffdir."*";
    my $fileList;
    for my $file (@files) {unless (-z $file) {$fileList .= " $file"}}
    if ($fileList) {
        system "less " . $fileList;
        use ExtUtils::MakeMaker qw(prompt);
        my $ans = '';
        unless ($ans eq 'y' || $ans eq 'n') {$ans = prompt( "contiue?", "y/n" ); $self->{state} = $ans eq 'y' ? 'ok' : ''}}
    else {$self->{state} = 'ok'}}

sub __genObjLists { my $self = shift @_; my %objMatches = $self->{matches}{objs}->%*;
    for my $obj ( keys %objMatches ) { my $objLNs = []; my $hashof_attrLNs = {};
        for my $objHash ( $objMatches{$obj}->@* ) { my $LN = $objHash->{meta}{LN} // next;
            if (ref $objHash->{val} eq 'ARRAY') {
                for my $member ( $objHash->{val}->@* ) {push @$objLNs, [$member, $LN]}}
            else {push @$objLNs, [$objHash->{val}, $LN]}
            for my $attr (keys $objHash->{attrs}->%*) { my $attrLNs = []; my $attrItem = $objHash->{attrs}{$attr};
                if (ref $attrItem eq 'ARRAY') {for my $member (@$attrItem) {push @$attrLNs, [$member, $LN]}}
                else {push @$attrLNs, [$attrItem, $LN]}
                $hashof_attrLNs->{$attr} = $attrLNs}}
        my $sorted_objLNs = [sort {$a->[0] cmp $b->[0] || $a->[1] cmp $b->[1]} @$objLNs];
        my $sorted_hashof_attrLNs = {};
        for my $attr (keys %$hashof_attrLNs) {
            my $sorted_attrLNs = [sort {$a->[0] cmp $b->[0] || $a->[1] cmp $b->[1]} $hashof_attrLNs->{$attr}->@*];
            $sorted_hashof_attrLNs->{$attr} = $sorted_attrLNs}
        my $uniq_objs = [];
        my $uniq_hashof_attrs = {};
        if (ref $objMatches{$obj}->[0]{val} eq 'ARRAY') { my %seen;
            for my $member (@$sorted_objLNs) {$seen{$member->[0]}++}
            $uniq_objs = [ sort {lc $a cmp lc $b} keys %seen ];
            for my $attr (keys %$sorted_hashof_attrLNs) { my %seen = ();
                for my $member (@$sorted_hashof_attrLNs{$attr}) {$seen{$member->[0]}++}
                my $uniq_attrs = [ sort {lc $a cmp lc $b} keys %seen ];
                $uniq_hashof_attrs->{$attr} = $uniq_attrs}}
        my $tgtDir = $self->{cwd}.'/.ohm/output/paged_lists';
        File::Path::make_path($tgtDir) unless -e $tgtDir;
        File::Path::make_path($tgtDir.'/attrs/paged/') or die unless (-d $tgtDir.'/attrs/paged/');
        File::Path::make_path($tgtDir.'/attrs/plain/') or die unless (-d $tgtDir.'/attrs/plain/');
        File::Path::make_path($tgtDir.'/objs/paged/')  or die unless (-d $tgtDir.'/objs/paged/');
        File::Path::make_path($tgtDir.'/objs/plain/')  or die unless (-d $tgtDir.'/objs/plain/');
        open my $fh1, '>:utf8', $tgtDir.'/objs/plain/'.$obj.'.txt' or die "something happened $obj";
            if (@$uniq_objs) {for (@$uniq_objs) {print $fh1 "$_\n"}}
            else {for (@$sorted_objLNs) {print $fh1 "$_->[0]\n"}}
            truncate $fh1, tell($fh1) or die; seek $fh1,0,0 or die; close $fh1;
        open my $fh2, '>:utf8', $tgtDir.'/objs/paged/'.$obj.'.txt' or die "something happened $obj";
            for ( @$sorted_objLNs ) {print $fh2 "$_->[1] $_->[0]\n"}
            truncate $fh2, tell($fh2) or die; seek $fh2,0,0 or die; close $fh2;
        for my $attr (keys %$sorted_hashof_attrLNs) { my $sorted_attrLNs = $hashof_attrLNs->{$attr};
            open my $fh3, '>:utf8', $tgtDir.'/attrs/plain/'.$attr.'.txt' or die "something happened $attr";
                if ( keys %$uniq_hashof_attrs ) {for ($uniq_hashof_attrs->{$attr}->@*) {print $fh3 "$_\n"}}
                else {for ($sorted_hashof_attrLNs->{$attr}->@*) {print $fh3 "$_->[0]\n"}}
                truncate $fh3, tell($fh3) or die; seek $fh3,0,0 or die; close $fh3;
            open my $fh4, '>:utf8', $tgtDir.'/attrs/paged/'.$attr.'.txt' or die 'something happened';
                for ($sorted_hashof_attrLNs->{$attr}->@*) {print $fh4 "$_->[1] $_->[0]\n"}
                truncate $fh4, tell($fh4) or die; seek $fh4,0,0 or die; close $fh4}}}

sub __init { my ($self, $args) = @_; my $class = ref $self;
    $self->{state} = '';
    use Cwd 'abs_path';  $self->{cwd} = getcwd;
    my $isBase = $self->__checkDir();
    #%-------- RESUME --------#
    # get the 'self' hash from the db if it exits
    my $old_args = {};
    if (-e $self->{cwd}.'/.ohm/db/self.json') {
        $old_args = do {
            open my $fh, '<:utf8', $self->{cwd}.'/.ohm/db/self.json' ;
            local $/;
            decode_json(<$fh>)};
        delete $old_args->{paths}{cwd};
        delete $old_args->{state}}
    # reshape "old_args" to the form of "args"
    for my $key (keys $old_args->{paths}->%*) {$old_args->{$key} = $old_args->{paths}{$key}}
    delete $old_args->{paths}; # we no longer need it
    my $flat_config = flatten $old_args;
    $flat_config    = $self->__mask($flat_config, flatten $args);
    $args           = unflatten $flat_config;
    my $paths_input = delete $args->{input} || die "No path to input provided";
    __checkChgArgs( $paths_input, '' , 'string scalar' );
    if ($paths_input) { $self->{paths}{input} = abs_path $paths_input }
    my $paths_dspt = delete $args->{dspt} || die "No path to dspt provided";
    __checkChgArgs( $paths_dspt, '' , 'string scalar' );
    if ($paths_dspt) { $self->{paths}{dspt} = abs_path $paths_dspt }
    my $paths_output = delete $args->{output} // '';
    __checkChgArgs( $paths_output,'','string scalar' );
    if ($paths_output) { $self->{paths}{output} = abs_path $paths_output }
    my $paths_dir = delete $args->{dir} // '';
    __checkChgArgs( $paths_dir,'','string scalar' );
    if ($paths_dir) { $self->{paths}{dir} = $paths_dir }
    my $paths_drsr = delete $args->{drsr} // '';
    __checkChgArgs( $paths_drsr, '' , 'string scalar' );
    if ($paths_drsr) { $self->{paths}{drsr} = abs_path $paths_drsr }
    my $paths_mask = delete $args->{mask} // '';
    __checkChgArgs( $paths_mask, '' , 'string scalar' );
    if ($paths_mask) { $self->{paths}{mask} = abs_path $paths_mask }
    my $paths_SMASK = delete $args->{smask} // [];
    __checkChgArgs( $paths_SMASK, 'ARRAY' , 'ARRAY REF' );
    if ($paths_SMASK) {$self->{paths}{smask} = [map {[abs_path($_->[0]),$_->[1]]} @$paths_SMASK ]}
    my $paths_SDRSR = delete $args->{sdrsr} // [];
    __checkChgArgs($paths_SDRSR,'ARRAY','ARRAY REF');
    if ($paths_SDRSR) {$self->{paths}{sdrsr} = [map {abs_path$_;$_} @$paths_SDRSR ]}
    $self->{paths} = $self->gen_config('paths',$self->{paths});
    my $name = delete $args->{name};
    unless (defined $name) {my $fname = basename( $self->{paths}{input}); $name = $fname =~ s/\..*$//r}
    __checkChgArgs( $name,'','string scalar' );
    $self->{name} = $name;
    my $prsv = delete $args->{prsv};
    $self->{prsv} = $prsv;
    my $params = delete $args->{params};
    if (defined $params) {__checkChgArgs($params,'HASH','hash') }
    $self->{params} = $self->gen_config( 'params', $params  );
    if (my $remaining = join ', ',keys %$args) {croak("Unknown keys to $class\::new: $remaining")}
    return $self}

sub __see { my ($self,$item,$prefix,$flat) = @_;
    if (UNIVERSAL::isa($item,'HASH')) {
        for my $key (keys %$item) {my $flatkey = $prefix . '.' . $key; $flat = $self->__see($item->{$key}, $flatkey, $flat)}}
    elsif (UNIVERSAL::isa($item,'ARRAY')) {
        for my $idx (0 .. $item->$#*) { my $key;
            if (ref $item->[$idx] ne 'HASH' || ref $item->[$idx]{val} eq 'ARRAY') {$key = $idx}
            else {$key = $item->[$idx]{val}}
            my $flatkey = $prefix . ':' . "[".$key."]";
            $flat = $self->__see( $item->[$idx], $flatkey, $flat)}}
    else {my $flatkey = $prefix . '=' . ($item // 'NULL'); push @$flat, $flatkey}
    return $flat}


sub __gen_bp { my ($self,$bp_name) = @_;
    # general
    # fill
    # member
    # <subkey>
    # <key>
    my %bps = (
        objhash => {fill => 0,member => {},
            general => {obj => undef,val => undef,childs => {},attrs => {},meta  => {},circs => {'.' => undef,'..' => undef}}},
        meta => {fill => 0,member => {},
            general => {dspt => {ord_limit => undef,ord_map => undef,ord_max => undef,ord_sort_map => undef}}},
        params => {fill => 0,member => {},
            general => {attribs => 1,delims => 1,mes => 1,prsv => 1}},
        paths => {fill => 0,member => {},
            general => {drsr => $self->{cwd}.'/.ohm/db/drsr.json',dspt => $self->{cwd}.'/.ohm/db/dspt.json',input => $self->{cwd}.'/.ohm/db/output.txt',mask => $self->{cwd}.'/.ohm/db/mask.json',cwd => $self->{cwd},output => $self->{cwd},smask => [],dir => '/.ohm'}},
        prsv => {fill => 0,member => {},
            general => {till => [ 'section', 0]}},
        self => {fill => 0,member => {},
            general => {circs => [],dspt => {},hash => {},matches => {},meta => {},name => undef,stdout => [],params => {},paths => {},prsv => {}}},
        drsr => {fill => 0, general =>     {},
            member => {fill => 1,member => {fill => 0,member => {},general => ['','','','','',{}]},general => {}}},
        mask => {fill => 0,
            member => {fill => 0, member => {},
                general => {supress => {all => 0,vals => []},sort => 0,place_holder => {enable => 0,childs => []}}},
            general => {lib => {cmd => '',scripts => [],pwds => [],name => ''}}},
        matches => {fill => 0,member => {},
            general => {miss => [],objs => {}},
            objs => {fill => 0, general => {},
                member => {fill => 0, member => {},
                    general => []}}},
        dspt => {fill => 0,
            member  => {fill => 0,member => {},
                general => {re => undef,cre => undef,order => undef,attrs => {},drsr => {},mask => {}},
                attrs => {fill => 0, general => {},
                    member => {fill => 0,member => {},
                        general => {re => undef,cre => undef,order => undef,delims => [],cdelims => undef}}}},
            general => {lib => {order => 0,smask => []},prsv => {order => -1,mask => {},drsr => {}}}});
    return dclone $bps{lc $bp_name}}




sub launch { my ($self,$args) = @_;

    # Check State
    if ($self->{state} ne 'ok') {print "Launch aborted, object state is not ok\n"; return}

    # Load Configs
    my @SMASKS = @{$self->{smask}}; my $dspt = $self->{dspt};

    # Create output for every smask in config
    for my $smask (@SMASKS) { my $pwds_DirPaths = $smask->[0]{lib}{pwds}; my @pwds;

        # Get Passwords
        for my $path (@$pwds_DirPaths) { my ($CONFIG_DIR) = glob $path->[0]; my $pwd = 0;
            if ($CONFIG_DIR) { open my $fh, '<', $CONFIG_DIR or die 'something happened';
                while (my $line = <$fh>) {if ($line =~ qr/$path->[1]/) {$pwd = $1; last}}} push @pwds, $pwd}

        # Only use sdrsr if alt smask exists, else use drsr
        my $sdrsr = $self->{sdrsr}[0]; unless ($smask->[1]) {$sdrsr = $self->{drsr}}

        # Use alternative sdrsr for html files
        if ($smask->[1] eq 'newbin') {$sdrsr = $self->{sdrsr}[1]}

        # Generate Output
        $self->__genWrite($smask->[0], $sdrsr);

        # Write output to file       
        open my $fh2, '>:utf8', $self->{paths}{output}."/.ohm/output/".$smask->[0]{lib}{name} or die 'something happened';
            $self->{stdout}[0] = $smask->[0]{lib}{header} // $self->{stdout}[0]; my $count = 0;

            # Print Lines
            for my $line ($self->{stdout}->@*) {

                # Add breaks to html files for all but the first line (This is the header, breaks were already specified here)
                if ($smask->[0]{lib}{name} eq 'newbin.html') {
                    if ($count != 0) {
                        if ($count <= ($smask->[0]{lib}{prsv_tail}[0] + 4)) {
                            unless ($line =~ /^\s*$/) {print $fh2 $line, "\n"}
                        }
                        elsif ($line =~ /^\s*<br\/>\s*$/) {}
                        elsif ($line =~ /^\s*<br>\s*$/) {}
                        elsif ($line =~ /^\s*$/) {}
                        elsif ($line =~ /^\s*<\/div>\s*$/) {print $fh2 $line, "\n"}
                        else {
                            if ($line =~ /^\s*\[/) {$line =~ s/^\s*(\[.*)/                        $1/ }
                            print $fh2 $line, "<br/>\n"
                        }

                    }
                    else {print $fh2 $line, "\n"}}

                else {print $fh2 $line,"\n"} $count++}

            # Append ending tags to html
            if ($smask->[0]{lib}{name} eq 'newbin.html') {
                if ($self->{mmm}{series} eq 1) {
                    print $fh2 "                <\/div>\n                <\/div>\n            <\/div>\n        <\/div>\n<\/div>\n    </body>\n</html>", "\n"
                }
                else {
                    print $fh2 "                <\/div>\n            <\/div>\n        <\/div>\n<\/div>\n    </body>\n</html>", "\n"
                }
            }

            truncate $fh2, tell($fh2) or die; seek $fh2,0,0 or die; close $fh2;

        # Insert Passwords
        $smask->[0]{lib}{cmd} =~ s/\$\{PWD\}/$pwds[0]/g; print "launching ".$smask->[0]{lib}{name} ." ... ";

        # Run Smask Command 
        my $cmd = `$smask->[0]{lib}{cmd}`; print "ok\n"} return $self}




sub check_matches { my ( $self, $args ) = @_;
    # without the 'g' modifier and the array context the regex exp will return
    # a boolean instead of the first match
    my ($fext) = $self->{paths}{input} =~ m/\.([^.]*$)/g;
    $self->{matches} = {} unless exists $self->{matches};
    if ($fext eq 'txt') {
        delete $self->{matches};
        delete $self->{circ};
        delete $self->{stdout};
        # should be it's own object
        $self->get_matches;
        $self->__divy();
        $self->__sweep(['reffs']);
        $self->__genWrite();
        $self->__validate();
        $self->__commit()}
    else { die "$fext is not a valid file extesion, must either be 'txt' or 'json'" }
    return $self }

sub __checkChgArgs  { my ($arg, $cond, $type) = @_;
    unless (defined $arg)      {croak( (caller(1))[3] . " requires an input" )}
    elsif  (ref $arg ne $cond) {croak( (caller(1))[3] . " requires a $type"  )}}

sub get_matches { my ( $self, $tmp ) = @_; my $dspt = $self->{dspt}; my $FR_prsv = { cnt => 0, F   => 1, };
    if ($tmp) { $self->{tmp} = {}; $self->{tmp}{matches} = {};
        for my $line ($self->{stdout}->@*) { $FR_prsv = $self->__get_matches($line, $FR_prsv, $tmp); } }
    else {
        open my $fh, '<:utf8', $self->{paths}{input} or die $!;
        { while ( my $line = <$fh> ) { $FR_prsv = $self->__get_matches($line, $FR_prsv); } } close $fh } return $self}

sub rm_reff { my ($self, $args) = @_; my $CIRCS = $self->{circ} // return;
    for my $circ (@$CIRCS) { my $ref = $circ->{'.'};
        if    (UNIVERSAL::isa($ref,'HASH' )) {delete $ref->{circ}}
        elsif (UNIVERSAL::isa($ref,'ARRAY')) {shift @$ref        }
        else                                 {die                }}
    $self->{circ} = []}

sub __checkDir  {my ($self      ) = @_; return (-d          $self->{cwd} . '/.ohm') }

sub __flatten   {my ($self, $key) = @_; return flatten      $self->{$key}           }

sub __unflatten {my ($self, $key) = @_; return unflatten    $self->{$key}           }

sub see         {my ($self, $key) = @_; return $self->__see($self->{$key},'lib',[],)}
1;
