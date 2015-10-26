#!/usr/bin/perl

use strict;
use warnings;

use File::HomeDir;
use File::Spec;
use Irssi;
use POSIX qw(strftime);
use Storable qw(lock_nstore lock_retrieve);

my $file = File::Spec->catfile(File::HomeDir->my_home, '.irssi', 'scripts', 'data', 'seen.dat');

lock_nstore({}, $file) unless -e $file;
my $seen = lock_retrieve($file);

sub seen
{
    my ($server, $data, $nick, $addr, $target) = @_;

    if ($data =~ /^!seen\s*$/) {
        $server->command("msg $target $nick: missing name");
    }
    elsif ($data =~ /^!seen \s+ (\S+)/x) {
        my $name = $1;
        if (exists $seen->{$name} && exists $seen->{$name}{$target}) {
            my ($time, $text) = @{$seen->{$name}{$target}}{qw(time text)};
            my $date_time = strftime '%a %b %e %Y at %H:%M', localtime $time;
            $server->command(qq(msg $target $nick: $name was last seen in $target on $date_time, saying "$text"));
        }
        else {
            $server->command("msg $target $nick: $name has not been seen yet in $target");
        }
    }
    else {
        if ($data =~ /^(.{1,50}(?:\S{1,15}(?=\s|$))?)/g) {
            my $text = $1;
            if ($data =~ /\G\S+/cg) {
                $text .= '...';
            }
            elsif ($data =~ /\G\s+\S+/cg) {
                $text .= ' ...';
            }
            $seen->{$nick}{$target} = {
                time => time(),
                text => $text,
            };
            lock_nstore($seen, $file);
        }
    }
}

Irssi::signal_add('message public', 'seen');
