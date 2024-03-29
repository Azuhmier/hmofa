#!/usr/bin/env perl
#============================================================
#
#         FILE: gitio.pl
#        USAGE: ./gitio.pl url
#  DESCRIPTION:
#       AUTHOR: Azuhmier (aka taganon), azuhmier@gmail.com
#============================================================
use warnings;
use strict;
use Data::Dumper;




#------------------------------------------------------
# MAIN {{{1
#------------------------------------------------------

## parse cmdline arguments and output 'args' hash
my $args = ParseArgs(\@ARGV);

## construct system command
my $CMD = constructCMD($args);

## execute sys cmd
my $output = qx($CMD);
unless ($args->{'silent'}) { print "${output}\n" }




#------------------------------------------------------
# subroutines {{{1
#------------------------------------------------------

sub ParseArgs { #{{{2

    my @args = @{shift @_};

    ## Parameters
    my %valid_urls = (
        io => 'https://git.io/',
        raw => 'https://raw.githubusercontent.com/',
    );
    my %valid_opts = (
        clipboard => '-cb',
        slient => '-s',
    );

    ## Option Check
    my %opts;
    for my $arg (@args[0..$#args-1]) {
        my @match = grep { $arg =~ /\Q$valid_opts{$_}\E/ } keys %valid_opts;
        if (exists $opts{$match[0]}) {
            die( "'$arg' can only be stated once! In ${0} line ", __LINE__, "\n" )
        }
        $opts{$match[0]} = (scalar @match == 1) ? $valid_opts{ $match[0] }
                                                : die( "'$arg' is not a valid option!
                                                  In ${0} line ", __LINE__, "\n" );
    }

    ## URL must be valid and last
    my @match = grep { $args[-1] =~ /^\Q$valid_urls{$_}\E/  } keys %valid_urls;
    my $url   = scalar @match == 1 ? $args[-1]
                                   : die( "URL is invalid or not the last argument!
                                     In ${0} line ", __LINE__, "\n" );
    my $type  = $match[0];

    ## Return Hash
    return {
        URL  => $url,
        type => $type,
        %opts,
    }
}


sub constructCMD { #{{{2

    my %args = %{shift @_};
    my $CMD;

    ##
    if ($args->{'type'} =~ 'raw') {
        $CMD = q{curl -s -i https://git.io -F "url=} . $args->{'URL'}.q{" };
    }
    else { $CMD = q{curl -s -i } . $args->{'URL'} }

    ##
    my $cmd2 = q{ | grep Location          \\
        | sed -n 's/Location: \(.*\)/\1/p' \\
        | tr -d '\n'                       \\
        | tee /dev/tty                     \\
        | tr -d '\r\n' };
    my $cmd3 = !$args->{'clipboard'} ? ''
                                     : '| pbcopy';

    ##
    $CMD = $CMD . $cmd2 . $cmd3;

    ##
    return $CMD;
}
