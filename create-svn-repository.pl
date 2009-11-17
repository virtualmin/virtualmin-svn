#!/usr/local/bin/perl

=head1 create-svn-repository.pl

Adds a new SVN repository to a virtual server.

This command creates a new SVN repository associated with some virtual server.
You must supply the C<--domain> parameter followed by the domain name, and
C<--name> followed by a repository name. You can also enable anonymous read
access to the new repository by default with the C<--anonymous> flag.

=cut

package virtualmin_svn;
if (!$module_name) {
	$main::no_acl_check++;
	$ENV{'WEBMIN_CONFIG'} ||= "/etc/webmin";
	$ENV{'WEBMIN_VAR'} ||= "/var/webmin";
	if ($0 =~ /^(.*)\/[^\/]+$/) {
		chdir($pwd = $1);
		}
	else {
		chop($pwd = `pwd`);
		}
	$0 = "$pwd/create-svn-repository.pl";
	require './virtualmin-svn-lib.pl';
	$< == 0 || die "create-svn-repository must be run as root";
	}
@OLDARGV = @ARGV;

# Parse command-line args
$type = "fsfs";
while(@ARGV > 0) {
	local $a = shift(@ARGV);
	if ($a eq "--domain") {
		$dname = shift(@ARGV);
		}
	elsif ($a eq "--name") {
		$rname = shift(@ARGV);
		}
	elsif ($a eq "--bdb") {
		$type = "bdb";
		}
	elsif ($a eq "--anonymous") {
		$anonymous = 1;
		}
	else {
		&usage();
		}
	}

# Validate parameters
$dname || &usage("Missing --domain parameter");
$rname || &usage("Missing --name parameter");
$rname =~ /^[a-z0-9\.\-\_]+$/i || &usage("Repository name is not valid");

# Get the domain and repos
$d = &virtual_server::get_domain_by("dom", $dname);
$d || &usage("No domain named $dname found");
$d->{'virtualmin-svn'} || &usage("SVN is not enabled for this domain");
@reps = &list_reps($d);
($clash) = grep { $_->{'rep'} eq $rname } @reps;
$clash && &usage("A repository with the same name already exists");

# Create it
$rep = { 'rep' => $rname };
$err = &create_rep($d, $rep, $type);
if ($err) {
	print "Failed to create SVN repository : $err\n";
	exit(1);
	}

# Add the anonymous user
if ($anonymous) {
	@repousers = &list_rep_users($d, $rep);
	push(@repousers, { 'user' => '*', 'perms' => 'r' });
	&save_rep_users($d, $rep, \@repousers);
	}

&virtual_server::virtualmin_api_log(\@OLDARGV, $d);
print "Created SVN repository $rname\n";

sub usage
{
print "$_[0]\n\n" if ($_[0]);
print "Creates an SVN repository owned by some virtual server.\n";
print "\n";
print "virtualmin create-svn-repository --domain name\n";
print "                                 --name repo-name\n";
print "                                [--bdb]\n";
print "                                [--anonymous]\n";
exit(1);
}

