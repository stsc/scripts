#!/usr/bin/perl

# List differences between DateTime::Format::Natural's tests and examples.

use strict;
use warnings;

use List::MoreUtils qw(any none);

die "Usage: $0 [grammar file] [test files]\n" unless @ARGV >= 2;

my ($grammar_file, @test_files) = @ARGV;

my $get_content = sub
{
    my ($file) = @_;

    open(my $fh, '<', $file) or die "Cannot open $file: $!\n";
    my $content = do { local $/; <$fh> };
    close($fh);

    return $content;
};

my @tests;
foreach my $test_file (@test_files) {
    my @sets = $get_content->($test_file) =~ /^my @\w+? = \(\s+?(.*?)\s+?\)/gms;
    foreach my $set (@sets) {
        foreach my $entry (split /\n/, $set) {
            my ($string) = $entry =~ /\{ \s*? '(.*?)'/x;
            push @tests, { string => $string, file => $test_file };
        }
    }
}

my ($pod) = $get_content->($grammar_file) =~ /=head1 EXAMPLES(.*?)=head1/s;
my @examples = $pod =~ /^ (.*?)$/gm;

foreach my $test (@tests) {
    print "case differs [$test->{file}]: $test->{string}\n"
      if (any { /^\Q$test->{string}\E$/i } @examples and none { $_ eq $test->{string} } @examples);
}
foreach my $test (@tests) {
    print "missing in examples [$test->{file}]: $test->{string}\n"
      if none { /^\Q$test->{string}\E$/i } @examples;
}
foreach my $example (@examples) {
    print "missing in tests [$grammar_file]: $example\n"
      if none { $_->{string} =~ /^\Q$example\E$/i } @tests;
}
