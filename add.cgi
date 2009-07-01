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

@repousers = &list_rep_users($dom, $rep);
if ($in{'ro'}) {
	# Add the anonymous user
	push(@repousers, { 'user' => '*', 'perms' => 'r' });
	}

# Grant selected users
@grants = split(/\r?\n/, $in{'users'});
%already = map { $_->{'user'}, $_ } &list_users($dom);
@domusers = &virtual_server::list_domain_users($dom, 0, 1, 1, 1);

foreach $uname (@grants) {
	if (!$already{$uname}) {
		# Need to create the user
		($domuser) = grep { &virtual_server::remove_userdom(
				      $_->{'user'}, $dom) eq $uname } @domusers;
		next if (!$domuser);
		local $newuser = { 'user' => $uname,
				   'enabled' => 1 };
		&set_user_password($newuser, $domuser, $dom);
		&virtual_server::write_as_domain_user($dom,
			sub { &htaccess_htpasswd::create_user(
				$newuser, &passwd_file($dom)) });
		&virtual_server::set_permissions_as_domain_user(
			$dom, 0755, &passwd_file($dom));
		}
	# Add to this repo
	push(@repousers, { 'user' => $uname,
			   'perms' => 'rw' });
	}
&save_rep_users($dom, $rep, \@repousers);

&redirect("index.cgi?show=$in{'show'}");

