#!/usr/bin/perl

use strict;
use warnings;

use DateTime;
use DateTime::TimeZone;
use Irssi;

sub get_time
{
    my ($server, $data, $nick, $addr, $target) = @_;
    return unless $data =~ /^[?!]time\b/;

    if ($data =~ /^\?time (?:\s+ (\S+))? \s* $/x) {
        my $arg = $1;
        if (defined $arg) {
            if (length $arg == 2) {
                my @names = DateTime::TimeZone->names_in_country($arg);
                if (@names) {
                    my $names = join ', ', @names;
                    $server->command("msg $target $nick: $names");
                }
                else {
                    $server->command("msg $target $nick: invalid country");
                }
            }
            else {
                my @names = DateTime::TimeZone->names_in_category($arg);
                if (@names) {
                    my $names = join ', ', @names;
                    $server->command("msg $target $nick: $names");
                }
                else {
                    $server->command("msg $target $nick: invalid category");
                }
            }
        }
        else {
            my $categories = join ', ', DateTime::TimeZone->categories;
            $server->command("msg $target $nick: $categories");
        }
    }
    elsif ($data =~ /^!time (?:\s+ (\S+))? \s* $/x) {
        my $tz = $1 || 'UTC';
        if (DateTime::TimeZone->is_valid_name($tz)) {
            my $dt = DateTime->now(time_zone => $tz);
            my $time = $dt->strftime('%a, %Y-%m-%d at %H:%M:%S');
            $server->command("msg $target $nick: $time [$tz]");
        }
        else {
            $server->command("msg $target $nick: invalid time zone");
        }
    }
}

Irssi::signal_add('message public', 'get_time');
