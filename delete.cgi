#!/usr/local/bin/perl
# Delete one repository

require './virtualmin-svn-lib.pl';
&ReadParse();

# Get the domain and repository
($repdom) = grep { $_ ne "confirm" } (keys %in);
($repname, $id) = split(/\@/, $repdom);
$dom = &virtual_server::get_domain($id);
&can_edit_domain($dom) || &error($text{'add_edom'});
@reps = &list_reps($dom);
($rep) = grep { $_->{'rep'} eq $repname } @reps;
$rep || &error($text{'delete_erep'});

if ($in{$repdom} eq $text{'delete'}) {
	# Deleting repositories
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
elsif ($in{$repdom} eq $text{'index_perms'}) {
	# Set permissions back to Apache user
	&ui_print_header(&virtual_server::domain_in($dom),
			 $text{'perms_title'}, "");
	
	print &text('perms_doing', "<tt>$rep->{'dir'}</tt>"),"<br>\n";
	&set_rep_permissions($dom, $rep);
	print $text{'perms_done'},"<p>\n";

	&ui_print_footer("", $text{'index_return'});
	}
else {
	&error($text{'delete_emode'});
	}

