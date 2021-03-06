#!/usr/local/bin/perl
# Delete one repository
use strict;
use warnings;
our (%text, %in);

require './virtualmin-svn-lib.pl';
&ReadParse();

# Get the domain and repository
my ($repdom) = grep { $_ ne "confirm" && $_ ne "show" } (keys %in);
my ($repname, $id) = split(/\@/, $repdom);
my $dom = &virtual_server::get_domain($id);
&can_edit_domain($dom) || &error($text{'add_edom'});
my @reps = &list_reps($dom);
my ($rep) = grep { $_->{'rep'} eq $repname } @reps;
$rep || &error($text{'delete_erep'});

my $button = $in{$repdom};
if ($button eq &entities_to_ascii($text{'delete'})) {
	# Deleting repositories
	if ($in{'confirm'}) {
		# Do it!
		&delete_rep($dom, $rep);
		&webmin_log("delete", "repo", $repname,
			    { 'dom' => $dom->{'dom'} });
		&redirect("index.cgi?show=$in{'show'}");
		}
	else {
		# Ask first
		&ui_print_header(&virtual_server::domain_in($dom),
				 $text{'delete_title'}, "");

		print "<center>\n";
		my $size = &disk_usage_kb("$dom->{'home'}/svn/$rep->{'rep'}");
		print &ui_form_start("delete.cgi");
		print &ui_hidden($repdom, $in{$repdom});
		print &ui_hidden("show", $in{'show'});
		print &text('delete_rusure', "<tt>$repname</tt>",
			    &nice_size($size*1024)),"<p>\n";
		print &ui_form_end([ [ "confirm", $text{'delete_ok'} ] ]);
		print "</center>\n";

		&ui_print_footer("index.cgi?show=$in{'show'}",
				 $text{'index_return'});
		}
	}
elsif ($button eq &entities_to_ascii($text{'index_email'})) {
	# Configuring email
	&redirect("edit_email.cgi?dom=$id&rep=$repname&show=$in{'show'}");
	}
elsif ($button eq &entities_to_ascii($text{'index_dump'})) {
	# Dumping repository
	&redirect("edit_dump.cgi?dom=$id&rep=$repname&show=$in{'show'}");
	}
elsif ($button eq &entities_to_ascii($text{'index_load'})) {
	# Loading repository
	&redirect("edit_load.cgi?dom=$id&rep=$repname&show=$in{'show'}");
	}
elsif ($button eq &entities_to_ascii($text{'index_perms'})) {
	# Set permissions back to Apache user
	&ui_print_header(&virtual_server::domain_in($dom),
			 $text{'perms_title'}, "");

	print &text('perms_doing', "<tt>$rep->{'dir'}</tt>"),"<br>\n";
	&set_rep_permissions($dom, $rep);
	print $text{'perms_done'},"<p>\n";

	&webmin_log("fix", "repo", $repname, { 'dom' => $dom->{'dom'} });
	&ui_print_footer("index.cgi?show=$in{'show'}", $text{'index_return'});
	}
elsif ($button eq &entities_to_ascii($text{'index_anon'})) {
	# Anonymous access form
	&redirect("edit_anon.cgi?dom=$id&rep=$repname&show=$in{'show'}");
	}
else {
	&error($text{'delete_emode'});
	}
