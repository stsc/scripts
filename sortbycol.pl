#!/usr/bin/perl

use strict;
use warnings;
use constant true => 1;

use Getopt::Long qw(:config no_auto_abbrev no_ignore_case);

my $numeric;

{
    my $opts = getopts();
    my $data = parse();

    adjust($opts, $data);
    output($opts, $data);
}

sub getopts
{
    my %opts;

    if (@ARGV) {
        GetOptions(\%opts, 'col=i', 'h|help', 'numeric', 'rx=s', 'reverse', 'skip=i') or usage();
        usage() if $opts{h};

        $numeric = $opts{numeric};
    }

    $opts{col} ||= 1;

    return \%opts;
}

sub usage
{
    print "$0 [ --col=n, -h|--help, --numeric, --rx=regexp, --reverse, --skip=n ]\n";
    exit;
}

sub parse
{
    my %data;

    for (my $cnt = 0; my $line = <>; $cnt++) {
        chomp $line;
        my @chunks = split /\s+/, $line;

        foreach my $i (0 .. $#chunks) {
            push @{$data{cols}[$i]}, [ $cnt, $chunks[$i] ];
        }

        push @{$data{lines}}, [ $line, [ @chunks ] ];
    }

    return \%data;
}

sub adjust
{
    my ($opts, $data) = @_;

    if ($opts->{col} > @{$data->{cols}}) {
        warn "$0: shrinking --col to ${\scalar @{$data->{cols}}}\n";
        $opts->{col} = @{$data->{cols}};
    }

    if (exists $opts->{skip}) {
        $opts->{skip}--;
    }
}

sub output
{
    my ($opts, $data) = @_;

    my $filter = sub { exists $opts->{skip} ? shift->[0] > $opts->{skip} : true };

    my @indexes = map $_->[0],
                  sort by_method
                  grep $filter->($_), @{$data->{cols}[$opts->{col} - 1]};

    @indexes = reverse @indexes if $opts->{reverse};

    foreach my $i (@indexes) {
        if (!defined $opts->{rx} or
             defined $opts->{rx}
               && grep /$opts->{rx}/, @{$data->{lines}[$i]->[1]}
        ) {
            print $data->{lines}[$i]->[0], "\n";
        }
    }
}

sub by_method
{
    no warnings 'numeric';

    $numeric
      ? $a->[1] <=> $b->[1]
      : $a->[1] cmp $b->[1];
}
