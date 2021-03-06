#!/usr/local/bin/perl
use strict;
use warnings;
our $module_name;

=head1 delete-svn-repository.pl

Removes an SVN repository from a virtual server.

This command deletes an existing SVN repository associated with some virtual
server. You must supply the C<--domain> parameter followed by the domain name,
and C<--name> followed by the repository name. Deletion includes all files
checked into the repository, so be careful!

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
	$0 = "$pwd/delete-svn-repository.pl";
	require './virtualmin-svn-lib.pl';
	$< == 0 || die "delete-svn-repository must be run as root";
	}
my @OLDARGV = @ARGV;

# Parse command-line args
my ($dname, $rname);
while(@ARGV > 0) {
	my $a = shift(@ARGV);
	if ($a eq "--domain") {
		$dname = shift(@ARGV);
		}
	elsif ($a eq "--name") {
		$rname = shift(@ARGV);
		}
	else {
		&usage();
		}
	}

# Validate parameters
$dname || &usage("Missing --domain parameter");
$rname || &usage("Missing --name parameter");
$rname =~ /^[a-z0-9\.\-\_]+$/i || &usage("Repository name is not valid");

# Get the domain and repo
my $d = &virtual_server::get_domain_by("dom", $dname);
$d || &usage("No domain named $dname found");
$d->{'virtualmin-svn'} || &usage("SVN is not enabled for this domain");
my @reps = &list_reps($d);
my ($rep) = grep { $_->{'rep'} eq $rname } @reps;
$rep || &usage("No repository with the name $rname exists");

# Delete it
my $err = &delete_rep($d, $rep);
if ($err) {
	print "Failed to delete SVN repository : $err\n";
	exit(1);
	}

&virtual_server::virtualmin_api_log(\@OLDARGV, $d);
print "Deleted SVN repository $rname\n";

sub usage
{
print "$_[0]\n\n" if ($_[0]);
print "Deletes an SVN repository owned by some virtual server.\n";
print "\n";
print "virtualmin delete-svn-repository --domain name\n";
print "                                 --name repo-name\n";
exit(1);
}
