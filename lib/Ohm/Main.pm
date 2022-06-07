package Ohm::Main;

use warnings;
use strict;
use Carp qw(croak);
use Cwd qw (getcwd abs_path);
use Storable qw(dclone);
use feature 'say';
use Data::Dumper;
#use File::Spec;
#use File::Basename;
#use File::Find;
#use Data::Recursive qw/clone lclone merge hash_merge array_merge compare/;
use JSON::XS;
use Params::Check qw[check allow last_error];
    $Params::Check::SANITY_CHECK_TEMPLATE = 0;
    $Params::Check::PRESERVE_CASE = 1;
    $Params::Check::WARNINGS_FATAL = 1;
    $Params::Check::STRICT_TYPE = 1;
    #$Params::Check::VERBOSE =1;
    #$Params::Check::CALLER_DEPTH = 5;

require Exporter;
our (@ISA, %EXPORT_TAGS, @EXPORT_OK, @EXPORT, $VERSION);
BEGIN {
    @ISA = qw(Exporter);
    #@EXPORT = qw(FALSE TRUE BASE);
    @EXPORT_OK = qw(FALSE TRUE BASE);
    %EXPORT_TAGS = (
        constants => [qw(FALSE TRUE BASE)],
        all => \@EXPORT_OK,
    );
}


use constant FALSE => 0;
use constant TRUE  => not FALSE;
use constant BASE  => '.ohmi';

#############################################################
#  PUBLIC
#############################################################
sub get #{{{1
{
    my ( $self, $tableName, $flag ) = @_;

    croak "Error: No arguments were supplied"
            if !$tableName && !$flag;
    die "Error: No tableName was supplied"
            if !$tableName;
    croak "Error: No argument for key in table '$tableName' was supplied"
            if !$flag;

    my $isValidType = !( ref $tableName ) && !( ref $flag );
    croak 'Error: Argument must be a tableName-key SCALAR pair' unless $isValidType;

    croak "Error: Table '$tableName' is undefined"
            unless exists $self->{$tableName};

    if ( exists $self->{$tableName}{$flag} )
    {
        return $self->{$tableName}{$flag};
    }

    elsif ( grep {$_ =~ /$flag/} keys $self->{$tableName}->%* )
    {
       my @keys =  grep {/$flag/} keys $self->{$tableName}->%*;
       my @status = map {"$_ = $self->{$tableName}{$_}"} @keys;

       return @status;
    }

    else
    {
        croak "Error: '$flag' is not a key in '$tableName'";
    }

}




sub set_flags #{{{1
{
    my ( $self, @args ) = @_;

    $self->{'flags'} = $self->__gen_config('flags')
            unless exists $self->{'flags'};

    $self->__set('flags',@args);

    return $self;
}




sub init_ohmi #{{{1
{
    my ($self, $baseDir) = @_;

    croak "ERROR: '.ohmi' directory has not been selected\n"
        unless ( $self->get('status','base') );

    $baseDir = $baseDir // $self->{cwd};
    my $basePath = $baseDir . '/' . BASE;

    mkdir $basePath;
    my $fname =  $basePath.'/ohminfo';

    $self->__write($fname,["lol\n", "go away\n"]);

    return $self;

}



sub select_ohmi #{{{1
{
    my ($self, $path, $NONE) = @_;

    die "ERROR: ohmi path not specified\n"
            unless $path;

    unless ($NONE)
    {
        $self->{paths}{baseDir} = $path;
        $self->__set_status('base',TRUE);
    }

    else
    {
        $self->{paths}{baseDir} = undef;
        $self->__set_status('base',FALSE);
    }

    return $self;
}

sub seek_ohmi #{{{1
{
    my ( $self, $path, $mode ) = @_;

    my $baseDirs = $self->__find_ohmi();
    my @basePaths = map { $_.'/'.BASE } @$baseDirs;

    return  \@basePaths;

    # Find .ohm in current dir or upwards
    sub __find_ohmi #{{{
    {
        my $self = shift @_;
        my $dir = $self->{cwd};
        my $baseDirs = [];

        if (-d BASE)
        {
            push @$baseDirs, $dir;
        }
        else
        {

            while ( $dir )
            {
                my $hit_top = $dir eq dirname($dir);
                $dir = dirname($dir);

                my $found  = basename($dir) eq BASE;

                if ($found or $hit_top)
                {
                    push @$baseDirs, $dir if $found;
                }
            }
        }

        return $baseDirs;

    } #}}}

}




sub new #{{{1
{
    my ($class, $args, $old_args) = @_;

    ## Construct HASH
    my $self =
    {
        cwd => getcwd,
        args => $old_args // {},
    };

    bless $self, $class;

    ## Check for DSPT
    $self->__checkDspt($args);

    ## Construct OBJ
    my $attrs =  $self->__gen_config('init');
    my $parsed_args = $self->__gen_config('args', $args);
    $self->%* =  ( %$self, %$attrs );
    $self->{args} = $parsed_args;


    ## Initiate
    $self->__init;

    return $self;
}#}}}



#############################################################
# PRIVATE
#############################################################
sub __init #{{{1
{
    my $self = shift @_;
    $self->__private(caller);
    croak "Error: Method '__init' must be defined in a subclass of Ohm::Main";
}




sub __gen_config #{{{1
{
    my ( $self, $bp_name, $input) = @_;
    #$self->__private(caller);

    # populate config
    $input = $self->__populate
    (
        $input // {},
        undef, # obj_flag
        $bp_name,
        $self->__gen_bp( $bp_name ) // die # boiler plate
    );

    return $input;

}




sub __checkDspt #{{{1
{
    my ($self, $args) = @_;
    my $dspt = {};
    my $existDspt = FALSE;

    if (exists $args->{dspt})
    {
        $dspt = $args->{dspt};
    }

    elsif (exists $self->{args}{dspt})
    {
        $dspt = $self->{args}{dspt};
    }

    croak "Error: dspt must be a hashref"
        unless UNIVERSAL::isa($dspt,'HASH');

    if ( keys %$dspt )
    {
        my @objs = keys %$dspt;

        for my $obj (@objs)
        {
            croak "Error: obj '$obj'  must be a hashref"
                unless UNIVERSAL::isa($dspt->{$obj},'HASH');

            my $attrs = exists $dspt->{$obj}{attr}
                ? $dspt->{$obj}{attr}
                : undef;

            if ($attrs)
            {
                croak "Error: attr hash of obj '$obj'  must be a hashref"
                    unless Universal::isa($attrs,'HASH');
            }
        }
        $dspt->{prsv} = {}
            unless exists $dspt->{prsv};
        $dspt->{root} = {}
            unless exists $dspt->{root};
        $dspt->{miss} = {}
            unless exists $dspt->{miss};


        $self->{dspt} = $dspt;
        $existDspt = TRUE;
    }

    return $existDspt;
}




sub __populate #{{{1
{
    my
    (
        $self,
        $input,   # output being built within recursion
        $OBJ,     # Boolean for 1st lvl recursion
        $bp_name, # Name of boilerplate
        $bp,      # boiler plate
    ) = @_;

    $bp = { $bp->() };
    my %hash = exists $bp->{start}
        ? $bp->{start}->%*
        : die "no start hash in boiler_plate '$bp_name' in ". (ref $self);
    my %member = exists $bp->{member}
        ? $bp->{member}->%*
        : die "no member hash in boiler_plate '$bp_name' in ". (ref $self);
    my @fill  = exists $bp->{fill}
        ? $bp->{fill}->@*
        : die "no fill hash in boiler_plate '$bp_name' in ". (ref $self);

    if ( %member )
    {
        croak "Error: dspt must be defined in order to parse member hashes"
            unless keys $self->{dspt}->%*;

        my @KEYS;

        my %exclude = $fill[1]
            ? map { $_ => 1 } @fill[1 .. $#fill]
            : ();

        if ($OBJ)
        {
            @KEYS = grep { !(exists $exclude{$_}) } keys $self->{dspt}{$OBJ}{attrs}->%*;
            push @KEYS, $OBJ if $fill[0];
        }

        else
        {
            @KEYS = grep { !(exists $exclude{$_}) } keys $self->{dspt}->%*;
            $OBJ =1;
        }

        for my $key ( @KEYS )
        {
            unless (exists $hash{$key})
            {
                $hash{$key} = \%member;
            }
            else
            {
                my %newMember = %member;
                $newMember{params} = {$hash{$key}->{params}->%*, $member{params}->%*};
                $hash{$key} = {%newMember};
            }
        }

    }

    my %template;
    for my $key (grep {$_ ne 'params'} keys %hash)
    {
        #$template{$key}->%* = %{ dclone $hash{$key} };
        my %newHash = $hash{$key}->%{ grep {$_ ne 'allow'} keys $hash{$key}->%* };
        $template{$key}->%* = %{ dclone \%newHash };
        $template{$key}->{allow} = $hash{$key}->{allow} if exists $hash{$key}->{allow};
    }
    $self->merge($input, \%template);
    %$input = %{ dclone Params::Check::check(\%template, $input) };

    for my $key (keys %$input)
    {

        if (exists $hash{$key}->{params} )
        {

            if (ref $hash{$key}->{params} eq '')
            {
                if (ref $input->{$key} eq 'HASH')
                {
                    $OBJ = $key if $OBJ;
                    $self->__populate
                    (
                        $input->{$key},
                        $OBJ,
                        $hash{$key}->{params},
                        $self->__gen_bp( $hash{$key}->{params} ),
                    );

                }

                elsif (ref $input->{$key} eq 'ARRAY')
                {

                    for my $idx (0 .. $input->{$key}->$#*)
                    {
                        $OBJ = $key if $OBJ;
                        $self->__populate
                        (
                            $input->{$key}[$idx],
                            $OBJ,
                            $hash{$key}->{params},
                            $self->__gen_bp( $hash{$key}->{params} ),
                        );
                    }
                }
            }

            else
            {
               my %template;
               for my $key2 (keys $hash{$key}->{params}->%*)
               {
                    $template{$key2}->%* = %{ dclone $hash{$key}->{params}{$key2} };
               }
               $self->merge($input, \%template);
               #$self->merge(\%template, $input->{key});
               $input->{$key}->%* = %{ dclone Params::Check::check( \%template , $input->{$key}) };
            }

        }

    }

    return $input;
}




sub merge #{{{1
{
    my ($self, $input, $template) = @_;

    for (keys %$template)
    {

        my $is_valid =
            ref $template->{$_}{default} eq 'ARRAY'
                &&
            exists $input->{$_}
                &&
            ref $input->{$_} eq 'ARRAY';

        if ($is_valid)
        {
            my $arr_a = $input->{$_};
            my $arr_b = $template->{$_}{default};

            for (0.. $arr_b->$#*)
            {
                if (not exists $arr_a->[$_])
                {
                    $arr_a->[$_] = $arr_b->[$_] ;
                }
                else
                {
                    #print "lol\n" if ref $arr_a->[$_] ne $arr_b->[$_];
                }
            }
        }
    }
    return $self;
}




sub __set #{{{1
{
    my ( $self, $tableName, @args ) = @_;
    $self->__private(caller);

    croak 'Error: No argument was supplied'
            if !$tableName && !@args;
    die 'Error: No tableName was supplied'
            if !$tableName;
    croak "Error: Key-Value pair not supplied for table '$tableName'"
            if !@args;

    my @typeConditons =
    (
            UNIVERSAL::isa($args[0], 'HASH'),
            !(ref $args[0]) && !(ref $args[1]),
            !(ref $tableName),
    );

    my $isValidArgumentsType = 0;
    $isValidArgumentsType |= $_ for @typeConditons[0,1];
    croak 'Error: Argument must be a HASH or key-value SCALAR pair'
            unless $isValidArgumentsType;

    my $isValidTableType = $typeConditons[2];
    die 'Error: First argument must be a SCALAR'
            unless $isValidTableType;

    croak "Error: Table '$tableName' is undefined"
            unless exists( $self->{$tableName} );


    if ( UNIVERSAL::isa($args[0], 'HASH') )
    {
        my $hash = $args[0];

        for my $key ( keys %$hash )
        {
            croak "Error: '$key' is not a key in '$tableName'"
                    if !exists( $self->{$tableName}{$key} );

            $self->{$tableName}{$key} = $hash->{$key};
        }
    }

    else
    {
        my ( $key, $value ) = @args;

        croak 'Error: Key-Value pair was not supplied'
                if !$key && !$value;
        croak "Error: key was not supplied"
                unless $key;
        croak "Error: Value for '$key' was not supplied"
               unless $key;
        croak "Error: '$key' is not a key in '$tableName'"
                if !exists( $self->{$tableName}{ $key } );

        $self->{$tableName}{$key} = $value;
    }


    return $self;

}




sub __set_status #{{{1
{
    my ( $self, @args ) = @_;
    $self->__private(caller);

    $self->{'status'} = $self->__gen_config('status')
            unless exists $self->{'status'};

    $self->__set('status', @args);

    return $self;

}




sub __gen_bp #{{{1
{
    my ( $self, $bp_name) = @_;
    #$self->__private(caller);

    my $bps = $self->__bps;

    return exists $bps->{lc $bp_name}
        ? $bps->{lc $bp_name}
        : croak "$bp_name is not a key in bps";
}




sub __use_args #{{{1
{
    my $self = shift @_;
    $self->__private(caller);
    croak "Error: Method '__use_args' must be defined in a subclass of Ohm::Main";
}




sub __bps #{{{1
{
    my $self = shift @_;
    $self->__private(caller);
    croak "Error: Method '__bps' must be defined in a subclass of Ohm::Main";

}#}}}



#############################################################
#  UTILITIES
#############################################################
sub importTxt #{{{1
{
    my ($self, $path) = @_;

    open my $fh, '<:utf8', $path
        or die $!;
    chomp(my @lines = <$fh>);
    return \@lines;
}




sub importJson #{{{1
{
    my ($self, $path) = @_;

    my $jsonHash = do
    {
        open my $fh, '<', $path
            or croak "ERROR: Could not open $path, $!";
        local $/;
        decode_json(<$fh>);
    };

    return $jsonHash;
}




sub __write #{{{1
{
    my ($self, $fname, $lines) = @_;
    $self->__private(caller);
    open my $fh, '>:utf8', $fname
        or die "cannot open $fname";
        print $fh @$lines;
        truncate $fh, tell($fh) or die;
        seek $fh,0,0 or die;
    return $self;
}




sub __writeJson #{{{1
{
    my ($self, $path, $hash) = @_;
    $self->__private(caller);
    my $encoder = JSON::XS->new;
    $encoder->pretty->allow_nonref->allow_blessed(['true']);
    my $json = $encoder->encode( $hash );
    $self->__write($json,$path);
}




sub __fileExist #{{{
{
    my ($self, $path) = @_;
    $self->__private(caller);

    return 0 unless $path;

    my @cwd   = File::Spec->splitdir( $self->{cwd} );
    my @path  = File::Spec->splitdir( $path );

    no warnings 'uninitialized';
    my @isect  = intersect(@path, @cwd);
    use warnings 'uninitialized';

    my $dir = File::Spec->catdir(@isect);
    my $idx = scalar @isect;


    for ( $idx .. $#path )
    {
        chdir $dir;
        unless (-e $path[$_])
        {
            chdir $self->{cwd} or die;
            return 0;
        }
        no warnings 'uninitialized';
        $dir = File::Spec->catdir(@path[0 .. $_]);
        use warnings 'uninitialized';
    }
    chdir $self->{cwd};
    return 1;
}







1 ;
sub __private #{{{1
{
      my ($self, $caller) = @_;

      croak "Error: Private method called"
          unless (caller)[0]->UNIVERSAL::isa( ref($self) )
              || caller eq __PACKAGE__;

      croak "Error: Private method called".caller
          unless ($caller)[0]->UNIVERSAL::isa( ref($self) )
              || $caller eq __PACKAGE__;
} #}}}



1;
