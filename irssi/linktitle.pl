#!/usr/bin/perl

use strict;
use warnings;

use Irssi;
use HTML::Entities;
use HTTP::Size;
use LWP::UserAgent;

sub fetch_url_title
{
    my ($server, $data, $nick, $addr, $target) = @_;
    return unless $data =~ /\bhttp:/;

    my @ignores = (
       qr{^GitHub\d+$},
       qr{^uribot$},
    );
    foreach my $ignore (@ignores) {
        return if $nick =~ $ignore;
    }

    my $scrub_whitespace = sub
    {
        my ($data) = @_;
        $$data =~ s/^\s*//;
        $$data =~ s/\s*$//;
    };
    $scrub_whitespace->(\$data);

    my @urls = grep /^http:/, split /\s+/, $data;

    my @exclusions = (
       qr{^http://(?:www\.)?perlpunks\.de},
       qr{^http://(?:board|wiki|www)\.perl-community\.de},
    );
    foreach my $exclude (@exclusions) {
        for (my $i = 0; $i < @urls; $i++) {
            if ($urls[$i] =~ $exclude) {
                splice(@urls, $i--, 1);
            }
        }
    }

    foreach my $url (@urls) {
        next unless my $size = HTTP::Size::get_size($url);
        next if int($size / 1024) > 512;
        my $response = LWP::UserAgent->new->get($url);
        if ($response->is_success && $response->headers->content_is_text) {
            my $content = $response->content;
            my ($title) = $content =~ m{<title.*?>(.*?)</title>}is;
            if (defined $title && $title =~ /\S/) {
                $scrub_whitespace->(\$title);
                $title =~ s/[\r\n]/ /g;
                decode_entities($title);
                $server->command("msg $target [ $title ]");
                Irssi::print("url title for $target");
            }
            elsif ($content =~ m{<title.*?>\s*</title>}) {
                $server->command("msg $target [ Untitled document ]");
                Irssi::print("empty url title for $target");
            }
        }
    }
}

Irssi::signal_add('message public', 'fetch_url_title');
