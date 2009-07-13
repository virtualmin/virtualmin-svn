#!/usr/local/bin/perl
# Show current anonymous access setting

require './virtualmin-svn-lib.pl';
&ReadParse();

# Get the domain and repository
$dom = &virtual_server::get_domain($in{'dom'});
&can_edit_domain($dom) || &error($text{'add_edom'});
@reps = &list_reps($dom);
($rep) = grep { $_->{'rep'} eq $in{'rep'} } @reps;
$rep || &error($text{'delete_erep'});

&ui_print_header(&virtual_server::domain_in($dom), $text{'anon_title'}, "");

print &ui_form_start("save_anon.cgi");
print &ui_hidden("dom", $in{'dom'});
print &ui_hidden("rep", $in{'rep'});
print &ui_hidden("show", $in{'show'});
print &ui_table_start($text{'anon_header'}, undef, 2);

print &ui_table_row($text{'email_rep'}, "<tt>$in{'rep'}</tt>");

@users = &list_rep_users($dom, $in{'rep'});
($anon) = grep { $_->{'user'} eq '*' } @users;
print &ui_table_row($text{'anon_anon'},
	&ui_yesno_radio("anon", $anon ? 1 : 0));

$perms = $anon ? $anon->{'perms'} : 'r';
print &ui_table_row($text{'anon_perms'},
	&ui_radio("perms", $perms, [ [ 'r', $text{'anon_r'} ],
				     [ 'rw', $text{'anon_rw'} ] ]));

print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("index.cgi?show=$in{'show'}", $text{'index_return'});

