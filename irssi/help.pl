#!/usr/bin/perl

use strict;
use warnings;

use Irssi;

my $bot_name = 'AL-76';
my $source = 'https://github.com/stsc/scripts/tree/master/irssi';

sub help
{
    my ($server, $data, $nick, $addr, $target) = @_;
    return unless $data =~ /^\Q$bot_name\E(?:\s*[,:])?\s+/g;

    if ($data =~ /\G (?:\?+|help) \s* $/cgix) {
        my $commands = join ', ', split /\n/, <<'EOT';
<abbrev> is <explanation>
forget <abbrev>
<abbrev>[?]
list
!cpan <distname>
!jobs [<many>]
!perldoc <item>
!quote random or <person> [/keyword/]
?quote <person> (mtime|total)
!seen <nickname>
EOT
        $server->command("msg $target Usage: $commands");
    }
    elsif ($data =~ /\G source \s* $/cgix) {
        $server->command("msg $target $source");
    }
}

Irssi::signal_add('message public', 'help');
