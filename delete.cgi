#!/usr/local/bin/perl
# Delete one repository

require './virtualmin-svn-lib.pl';
&ReadParse();

($repdom) = grep { $_ ne "confirm" } (keys %in);
($repname, $id) = split(/\@/, $repdom);
if ($in{$repdom} eq $text{'delete'}) {
	# Deleting repositories
	$dom = &virtual_server::get_domain($id);
	&can_edit_domain($dom) || &error($text{'add_edom'});

	@reps = &list_reps($dom);
	($rep) = grep { $_->{'rep'} eq $repname } @reps;
	$rep || &error($text{'delete_erep'});
	if ($in{'confirm'}) {
		# Do it!
		&delete_rep($dom, $rep);
		&redirect("");
		}
	else {
		# Ask first
		&ui_print_header(&virtual_server::domain_in($dom),
				 $text{'delete_title'}, "");

		print "<center>\n";
		$size = &disk_usage_kb("$dom->{'home'}/svn/$rep->{'rep'}");
		print &ui_form_start("delete.cgi");
		print &ui_hidden($repdom, $in{$repdom});
		print &text('delete_rusure', "<tt>$repname</tt>",
			    &nice_size($size*1024)),"<p>\n";
		print &ui_form_end([ [ "confirm", $text{'delete_ok'} ] ]);
		print "</center>\n";

		&ui_print_footer("", $text{'index_return'});
		}
	}
elsif ($in{$repdom} eq $text{'index_email'}) {
	# Configuring email
	&redirect("edit_email.cgi?dom=$id&rep=$repname");
	}
else {
	&error($text{'delete_emode'});
	}

