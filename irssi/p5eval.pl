#!/usr/bin/perl
#
# Copyright (c) 2012-2013 Steven Schubiger
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

use strict;
use warnings;
use constant false => 0;

use File::Basename qw(fileparse);
use File::Copy qw(move);
use File::Spec::Functions ':ALL';
use File::Temp qw(tempfile);
use IPC::Open3 qw(open3);
use Irssi;
use Symbol qw(gensym);

my $VERSION = '0.04';

#-----------------------
# Start of configuration
#-----------------------

my $perl      = '/home/sts/perl-5.18.0/bin/perl';
my $jail      = 'jail';
my $user_name = 'p5eval';
my $timeout   = 5;
my $source    = 'http://refcnt.org/~sts/code/p5eval.pl';

#---------------------
# End of configuration
#---------------------

sub process_perl_code
{
    my ($server, $data, $nick, $addr, $target) = @_;
    return unless $data =~ /^p5eval[,:]\s+(.+)$/;

    my $user = $1;

    if ($user eq 'source') {
        $server->command("msg $target $nick: $source");
        return;
    }

    Irssi::print("perl code for $target");

    my $limit = 1024 ** 2 * 75;

    my $eval_dir = catfile(tmpdir(), $user_name);

    mkdir $eval_dir unless -e $eval_dir;
    chdir $eval_dir or die "Cannot chdir to $eval_dir: $!";

    my ($source_fh, $source_file) = tempfile("$user_name-XXXX", DIR => $eval_dir, SUFFIX => '.pl');

    my $uid = getpwnam($user_name) or die "getpwnam of $user_name failed";
    my $gid = getgrnam($user_name) or die "getgrnam of $user_name failed";

    my $jail_path = catfile($eval_dir, $jail);

    mkdir $jail_path unless -e $jail_path;

    chown $uid, $gid, $jail_path or die "chown of $jail_path failed";
    chmod 0700,       $jail_path or die "chmod of $jail_path failed";

    my $script = fileparse($source_file);

    my $jail_script = catfile($jail_path, $script);

    move($source_file, $jail_script) or die "Cannot move $source_file to $jail_path: $!";

    chown $uid, $gid, $jail_script or die "chown of $jail_script failed";
    chmod 0700,       $jail_script or die "chmod of $jail_script failed";

    my $code = <<"EOC";
no strict;
no warnings;
package main;
# START
# system
use charnames ':full';
use BSD::Resource;
use Data::Dumper;
use PerlIO;
use POSIX;
use Scalar::Util;
# user
use 5.010;
use Encode;
use List::Util;
use List::MoreUtils;
# END
setrlimit(RLIMIT_CPU, 10, 10); # preload
\$Data::Dumper::Indent    = 0;
\$Data::Dumper::Quotekeys = 0;
\$Data::Dumper::Terse     = 1;
\$Data::Dumper::Useqq     = 1;
chdir  "$jail_path" or die "chdir to $jail_path failed";
chroot "$jail_path" or die "chroot to $jail_path failed";
POSIX::setuid($uid);
POSIX::setgid($gid);
setrlimit(RLIMIT_DATA,  $limit, $limit) &&
setrlimit(RLIMIT_STACK, $limit, $limit) &&
setrlimit(RLIMIT_NPROC, 1, 1)           &&
setrlimit(RLIMIT_NOFILE, 10, 10)        &&
setrlimit(RLIMIT_OFILE, 10, 10)         &&
setrlimit(RLIMIT_OPEN_MAX, 10, 10)      &&
setrlimit(RLIMIT_LOCKS, 0, 0)           &&
setrlimit(RLIMIT_AS,   $limit, $limit)  &&
setrlimit(RLIMIT_VMEM, $limit, $limit)  &&
setrlimit(RLIMIT_MEMLOCK, 100, 100)     &&
setrlimit(RLIMIT_CPU, 10, 10)           or die "setrlimit failed: \$!";
close(STDIN);
local \$\@;
sub evaluate {
    local \@INC = '/lib';
    local \$\\;
    local \$_;
    my \$code = do { local \$/; <DATA> };
    close *DATA;
    return eval \$code;
}
my \$result = evaluate();
my \$eval_error = \$\@;
select STDOUT;
binmode STDOUT, ':encoding(utf8)';
if (\$eval_error) {
    \$eval_error =~ s/\\n(?!\$)/; /g;
    print "ERROR: \$eval_error";
}
else {
    print ref \$result ? Dumper(\$result) : \$result;
}
EOC
    print {$source_fh} <<"EOT";
$code
__DATA__
$user
EOT
    my $pid = fork();

    die 'fork failed' unless defined $pid;

    if ($pid == 0) {
        my $program_pid;

        local $SIG{ALRM} = sub {
            $server->command("msg $target $nick: interrupting, taking more than $timeout second(s)");
            kill 9, $program_pid;
        };

        my $out = gensym;

        alarm $timeout;

        $program_pid = open3(gensym, $out, false, $perl, '-T', $jail_script);
        waitpid($program_pid, 0);

        alarm 0;

        foreach my $stream (map uc, qw(stdin stdout stderr)) {
            close($stream);
        }

        my $output = do { local $/; <$out> };

        unlink $jail_script;

        if (length $output) {
            $server->command("msg $target $nick: $output");
        }
        else {
            $server->command("msg $target $nick: No output");
        }

        exit;
    }
    else {
        waitpid($pid, 0);
    }
}

Irssi::signal_add('message public', 'process_perl_code');