#!/usr/local/bin/perl
# Show a form for loading a repository

require './virtualmin-svn-lib.pl';
&ReadParse();
&error_setup($text{'load_err'});
$config{'canload'} || &error($text{'load_ecannot'});

# Get the domain and repository
$dom = &virtual_server::get_domain($in{'dom'});
&can_edit_domain($dom) || &error($text{'add_edom'});
@reps = &list_reps($dom);
($rep) = grep { $_->{'rep'} eq $in{'rep'} } @reps;
$rep || &error($text{'delete_erep'});

&ui_print_header(&virtual_server::domain_in($dom), $text{'load_title'}, "");

print $text{'load_desc'},"<p>\n";

print &ui_form_start("load.cgi", "form-data");
print &ui_hidden("dom", $in{'dom'});
print &ui_hidden("rep", $in{'rep'});
print &ui_table_start($text{'load_header'}, undef, 2, [ "width=30%" ]);

print &ui_table_row($text{'email_rep'}, "<tt>$in{'rep'}</tt>");

print &ui_table_row($text{'load_from'},
	&ui_radio("from_def", 0,
		[ [ 0, &text('load_browser', &ui_upload("upload"))."<br>" ],
		  [ 1, &text('load_file', &ui_textbox("file", undef, 40).
				&file_chooser_button("file")) ] ]));


print &ui_table_end();
print &ui_form_end([ [ undef, $text{'load_ok'} ] ]);

&ui_print_footer("", $text{'index_return'});

