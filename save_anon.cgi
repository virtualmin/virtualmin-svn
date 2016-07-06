#!/usr/local/bin/perl
# Save the anonymous access settings for a repository
use strict;
use warnings;
our (%text, %in);

require './virtualmin-svn-lib.pl';
&ReadParse();
&error_setup($text{'anon_err'});

# Get the domain and repository
my $dom = &virtual_server::get_domain($in{'dom'});
&can_edit_domain($dom) || &error($text{'add_edom'});
my @reps = &list_reps($dom);
my ($rep) = grep { $_->{'rep'} eq $in{'rep'} } @reps;
$rep || &error($text{'delete_erep'});

# Get the anonymous user
my @users = &list_rep_users($dom, $in{'rep'});
my ($anon) = grep { $_->{'user'} eq '*' } @users;

# Create, update or delete
if ($anon && !$in{'anon'}) {
	@users = grep { $_ ne $anon } @users;
	}
elsif (!$anon && $in{'anon'}) {
	push(@users, { 'user' => '*', 'perms' => $in{'perms'} });
	}
elsif ($anon && $in{'anon'}) {
	$anon->{'perms'} = $in{'perms'};
	}
&save_rep_users($dom, $rep, \@users);
&webmin_log("anon", "repo", $in{'rep'}, { 'dom' => $dom->{'dom'} });

&redirect("index.cgi?show=$in{'show'}");
