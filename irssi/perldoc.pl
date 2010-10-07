#!/usr/bin/perl

use strict;
use warnings;

use Irssi;
use LWP::Simple;

sub fetch_perldoc_url
{
    my ($server, $data, $nick, $addr, $target) = @_;

    my $base = 'http://perldoc.perl.org';

    if ($data eq '!perldoc') {
        $server->command("msg $target $base");
    }
    elsif (my @args = $data =~ /^(?:(\S+?) \s+?)? !perldoc \s+? (\S+)/x) {
        my $item = pop @args;
        my $name = do {
            local $_ = shift @args;
            tr/[:,]//d if defined;
            $_
        };
        (my $path = "$item.html") =~ s{::}{/}g;

        my @urls = (
            ${\join '/', ($base, $path)},
            ${\join '/', ($base, 'functions', $path)},
        );
        my $link;
        foreach my $url (@urls) {
            if (get($url)) {
                $link = $url;
                last;
            }
        }

        if (defined $link) {
            my $string = defined $name
              ? "msg $target $name: $link"
              : "msg $target $link";
            $server->command($string);
        }
    }
}

Irssi::signal_add('message public', 'fetch_perldoc_url');
