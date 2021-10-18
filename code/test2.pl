#!/usr/bin/env perl


#!/usr/bin/env perl
#============================================================
#
#         FILE: hasher.pl
#        USAGE: ./hasher.pl
#   DESCRIPTION: ---
#        AUTHOR: Azuhmier (aka taganon), azuhmier@gmail.com
#       Created: Fri 10/08/21 07:55:11
#===========================================================
use strict;
use warnings;
use feature 'say';

doit(); sub doit {{use vars qw( $x )}}
# 'use vars' declares a non-lexical pacakge scoped alias to a package variable
# works by setting flags in $^H. $^H exposes some internal interpreter state
# bits, but you're not supposed to touch it in normal code

#$main::x = 'main::package';
# package variable

$x       = 'use';
# alias

# local $x = 'local';
# For our purposes local is not a declaration and does not create local
# variables; local temporarily changes the value of an existing variable. Local
# actually will save the given global variable's value away, so it will later
# automatically be restored to the global variable. Call context.

#our $x = 'our';
# Our declares a lexical alias to a package variable. This means that it's scoped
# just like my. The difference is that it's backed by a package variable, so the
# variable doesn't go away when you exit the scope. Only the alias goes away.

#my $x = 'my';
# lexically (i.e. locally) declared variables; File-scoped lexicals.

{
    package foo;
    say '[foo]';
    $foo::x = 'foo::package';
    #say '$x           ' . $x;
    say '$main::x     ' . $main::x;
    say '$foo::x      ' . $foo::x;
    say 'main::test() ' . main::test();

    say '';

    package main;
    say '[main]';
    say '$x       ' . $x;
    say '$main::x ' . $main::x;
    say '$foo::x  ' . $foo::x;
    say 'test()   ' . test();
}

end();
sub end {
}

sub test {
    return $x;
}
