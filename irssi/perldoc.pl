#!/usr/bin/perl

use strict;
use warnings;

use Irssi;
use LWP::Simple;

my $base_url = 'http://perldoc.perl.org';

sub fetch_perldoc
{
    my ($server, $data, $nick, $addr, $target) = @_;

    if ($data =~ /^!perldoc\s*$/) {
        $server->command("msg $target $base_url");
    }
    elsif (my @args = $data =~ /^ (?:(\S+) \s+)? !perldoc \s+ (\S+) \s* $/x) {
        my $item = pop @args;
        my $name = do {
            local $_ = shift @args;
            tr/[:,]//d if defined;
            $_
        };
        (my $path = "$item.html") =~ s{::}{/}g;

        my @urls = (
            ${\join '/', ($base_url, $path)},
            ${\join '/', ($base_url, 'functions', $path)},
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

Irssi::signal_add('message public', 'fetch_perldoc');
