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

    if ($data =~ /^[?!]quote\s*$/) {
        my $persons = join ', ', @persons;
        $server->command("msg $target !quote random or $persons [/keyword/] | ?quote <person>");
    }
    elsif ($data =~ /^\?quote \s+ (\w+) \s* $/x) {
        my $person = $1;

        my %persons = map { $_ => true } @persons;
        return unless $persons{$person};

        my $file = File::Spec->catfile($quote_dir, $person);
        my $quotes = 0;

        open(my $fh, '<', $file) or die "Cannot read $file: $!\n";
        $quotes++ while <$fh>;
        close($fh);

        my $suffix = ($quotes == 0 || $quotes > 1) ? 's' : '';

        $server->command("msg $target $person: $quotes quote$suffix");
    }
    elsif ($data =~ /^!quote \s+ (\w+) (?:\s+ \/(.+?)\/)? \s* $/x) {
        my $person  = $1;
        my $keyword = $2;

        my %persons = map { $_ => true } ('random', @persons);
        return if !$persons{$person} || ($person eq 'random' && defined $keyword);

        my $random = ($person eq 'random') ? $persons[int rand scalar @persons] : undef;
        my $file = File::Spec->catfile($quote_dir, defined $random ? $random : $person);

        open(my $fh, '<', $file) or die "Cannot read $file: $!\n";
        my @quotes = <$fh>;
        close($fh);

        my @list = defined $keyword ? grep /\Q$keyword\E/i, @quotes : @quotes;
        my $quote = @list ? $list[int rand scalar @list] : 'empty';

        if (defined $quote) {
            chomp $quote;
            my $string = defined $random
              ? "msg $target $quote ($random)"
              : "msg $target $quote";
            $server->command($string);
        }
    }
}

Irssi::signal_add('message public', 'quote');
