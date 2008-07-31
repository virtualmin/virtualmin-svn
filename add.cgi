#!/usr/local/bin/perl
# Create one repository

require './virtualmin-svn-lib.pl';
&ReadParse();

# Validate inputs
&error_setup($text{'add_err'});
$in{'rep'} =~ /^[a-z0-9\.\-\_]+$/i || &error($text{'add_erep'});
$dom = &virtual_server::get_domain($in{'dom'});
&can_edit_domain($dom) || &error($text{'add_edom'});

# Check limit on repositories
if ($access{'max'}) {
	foreach $d (&virtual_server::list_domains()) {
		next if (!$d->{$module_name});
		next if (!&can_edit_domain($d));
		push(@reps, &list_reps($d));
		}
	@reps >= $access{'max'} && &error($text{'index_max'});
	}

# Run the create command
$rep = { 'rep' => $in{'rep'} };
$err = &create_rep($dom, $rep, $in{'type'});
&error("<pre>$err</pre>") if ($err);

if ($in{'ro'}) {
	# Add the anonymous user
	local @users = &list_rep_users($dom, $rep);
	push(@users, { 'user' => '*', 'perms' => 'r' });
	&save_rep_users($dom, $rep, \@users);
	}

&redirect("index.cgi?show=$in{'show'}");

