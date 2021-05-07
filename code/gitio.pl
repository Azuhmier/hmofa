#!/usr/bin/env perl
use warnings;
use strict;
use diagnostics;

my $url = shift @ARGV;
my $output = `curl -s -i https://git.io -F "url=${url}" \\
  | grep Location | sed -n 's/Location: \\(.*\\)/\\1/p' | tr -d '\\n' | tee /dev/tty | tr -d '\\r\\n' | pbcopy`;
print $output, "\n";
