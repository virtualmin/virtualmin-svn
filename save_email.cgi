#!/usr/local/bin/perl
# Save the email settings for a repository

require './virtualmin-svn-lib.pl';
&ReadParse();
&error_setup($text{'email_err'});
$config{'canemail'} || &error($text{'email_ecannot'});

# Get the domain and repository
$dom = &virtual_server::get_domain($in{'dom'});
&can_edit_domain($dom) || &error($text{'add_edom'});
@reps = &list_reps($dom);
($rep) = grep { $_->{'rep'} eq $in{'rep'} } @reps;
$rep || &error($text{'delete_erep'});

# Save settings
$in{'email_def'} || $in{'email'} =~ /\S/ || &error($text{'email_eemail'});
&save_repository_email($dom, $rep, $in{'email_def'} ? undef : $in{'email'});

&redirect("");

