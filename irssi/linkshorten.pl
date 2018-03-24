#!/usr/bin/perl

use strict;
use warnings;

use Irssi;
use URI::Find;
use WWW::Shorten::TinyURL qw(makeashorterlink);

sub shorten_url
{
    my ($server, $data, $nick, $addr, $target) = @_;

    my @urls;
    my $finder = URI::Find->new(sub {
        push @urls, shift;
    });
    $finder->find(\$data);
    return unless @urls;

    my @shortened;
    foreach my $url (@urls) {
        next unless length $url > 78;
        push @shortened, makeashorterlink($url);
    }                  # hack
    @shortened = map { s{^http(?=://)}{https}; $_ } grep defined, @shortened;
    return unless @shortened;

    my $output = (@shortened > 1)
      ? join ' ', @shortened
      : $shortened[0];

    $server->command("msg $target $output");
}

Irssi::signal_add('message public', 'shorten_url');
