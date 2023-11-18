#!/usr/bin/perl
use strict;
use warnings;

use Path::Tiny; #!!EXPAND
use JSON::PS; #!!EXPAND
use Main; #!!EXPAND

package Hoge;
#line 11 "ciconfig.pl"
Path::Tiny->import (qw(path));
JSON::PS->import (qw(json_bytes2perl perl2json_bytes_for_record));

my $Remove = $ENV{REMOVE_UNUSED};
my $RunGit = $ENV{RUN_GIT};

my $root_path = path (".");
my $input_path = $root_path->child ('config/ci.json');
my $input_bytes = $input_path->slurp;
my $input = json_bytes2perl ($input_bytes);

my $output = Main->generate ($input, $root_path,
                             input_length => (length $input_bytes) + (length $root_path));

for my $name (sort { $a cmp $b } keys %$output) {
  my $path = $root_path->child ($name);
  my $data = $output->{$name};
  if ($data->{json}) {
    $path->parent->mkpath;
    $path->spew (perl2json_bytes_for_record ($data->{json}));
    if ($RunGit) {
      system 'git', 'add', $path;
    }
  } elsif ($data->{touch}) {
    $path->parent->mkpath;
    $path->spew (int (time / (50*24*60*60)));
    if ($RunGit) {
      system 'git', 'add', $path;
    }
  } elsif ($data->{remove}) {
    if ($path->is_file) {
      if ($Remove) {
        $path->remove;
        if ($RunGit) {
          system 'git', 'rm', $path;
        }
      } else {
        warn "File |$path| should be removed.\n";
      }
    }
  }
}

=head1 LICENSE

Copyright 2018-2023 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
