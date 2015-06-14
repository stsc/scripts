#!/usr/bin/perl

use strict;
use warnings;
use constant true => 1;

use File::HomeDir;
use File::Spec;
use Irssi;

my $quote_dir = File::Spec->catfile(File::HomeDir->my_home, '.irssi', 'scripts', 'quote');

sub quote
{
    my ($server, $data, $nick, $addr, $target) = @_;

    return unless $data =~ /^[?!]quote/;

    opendir(my $dh, $quote_dir) or die "Cannot open $quote_dir: $!\n";
    my @persons = sort grep !/^\.\.?$/, readdir($dh);
    closedir($dh);

    if ($data =~ /^[?!]quote$/) {
        my $persons = join ', ', @persons;
        $server->command("msg $target !quote random or $persons");
    }
    elsif ($data =~ /^!quote \s+ (\w+)/x) {
        my $person = $1;

        my %persons = map { $_ => true } ('random', @persons);
        return unless $persons{$person};

        my $random = ($person eq 'random') ? $persons[int rand scalar @persons] : undef;
        my $file = File::Spec->catfile($quote_dir, defined $random ? $random : $person);

        open(my $fh, '<', $file) or die "Cannot read $file: $!\n";
        my @quotes = <$fh>;
        close($fh);

        chomp(my $quote = $quotes[int rand scalar @quotes]);

        my $string = defined $random
          ? "msg $target $quote ($random)"
          : "msg $target $quote";
        $server->command($string);
    }
}

Irssi::signal_add('message public', 'quote');
