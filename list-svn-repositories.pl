#!/usr/local/bin/perl
use strict;
use warnings;
our $module_name;

=head1 list-svn-repositories.pl

Lists all repositories associated with some virtual server.

This command outputs a table of all SVN repositories owned by some virtual
server, identified by the C<--domain> flag. You an also switch to a more
easily parsed format with the C<--multiline> flag, or get just a list of
repository names with the C<--name-only> flag.

=cut

package virtualmin_svn;
my $pwd;
if (!$module_name) {
	no warnings "once";
	$main::no_acl_check++;
	use warnings "once";
	$ENV{'WEBMIN_CONFIG'} ||= "/etc/webmin";
	$ENV{'WEBMIN_VAR'} ||= "/var/webmin";
        if ($0 =~ /^(.*)\/[^\/]+$/) {
                chdir($pwd = $1);
                }
        else {
                chop($pwd = `pwd`);
                }
	$0 = "$pwd/list-svn-repositories.pl";
	require './virtualmin-svn-lib.pl';
	$< == 0 || die "list-svn-repositories.pl must be run as root";
	}

# Parse command-line args
my ($multi, $nameonly, $dname);
while(@ARGV > 0) {
	my $a = shift(@ARGV);
	if ($a eq "--multiline") {
		$multi = 1;
		}
	elsif ($a eq "--name-only") {
		$nameonly = 1;
		}
	elsif ($a eq "--domain") {
		$dname = shift(@ARGV);
		}
	else {
		&usage();
		}
	}

# Get the domain and repos
$dname || &usage("Missing --domain parameter");
my $d = &virtual_server::get_domain_by("dom", $dname);
$d || &usage("No domain named $dname found");
$d->{'virtualmin-svn'} || &usage("SVN is not enabled for this domain");
my @reps = &list_reps($d);

if ($nameonly) {
	# Output only repo names
	foreach my $r (@reps) {
		print $r->{'rep'},"\n";
		}
	}
elsif ($multi) {
	# Output full details
	foreach my $r (@reps) {
		print $r->{'rep'},"\n";
		print "  Directory: $r->{'dir'}\n";
		foreach my $u (&list_rep_users($d, $r->{'rep'})) {
			print "  User: $u->{'user'} $u->{'perms'}\n";
			}
		}
	}
else {
	# Output table
	my $fmt = "%-20.20s %-58.58s\n";
	printf $fmt, "Repository", "Directory";
	printf $fmt, ("-" x 20), ("-" x 58);
	foreach my $r (@reps) {
		printf $fmt, $r->{'rep'}, $r->{'dir'};
		}
	}

sub usage
{
print "$_[0]\n\n" if ($_[0]);
print "Lists the SVN repositories for some virtual server.\n";
print "\n";
print "virtualmin list-svn-repositories [--multiline | --name-only]\n";
print "                                  --domain name\n";
exit(1);
}
