#!/usr/local/bin/perl
# Show the current email settings for a repository
use strict;
use warnings;
our (%text, %in, %config);

require './virtualmin-svn-lib.pl';
&ReadParse();
$config{'cannotify'} || &error($text{'email_ecannot'});

# Get the domain and repository
my $dom = &virtual_server::get_domain($in{'dom'});
&can_edit_domain($dom) || &error($text{'add_edom'});
my @reps = &list_reps($dom);
my ($rep) = grep { $_->{'rep'} eq $in{'rep'} } @reps;
$rep || &error($text{'delete_erep'});

&ui_print_header(&virtual_server::domain_in($dom), $text{'email_title'}, "");

print &ui_form_start("save_email.cgi");
print &ui_hidden("dom", $in{'dom'});
print &ui_hidden("rep", $in{'rep'});
print &ui_hidden("show", $in{'show'});
print &ui_table_start($text{'email_header'}, undef, 2);

print &ui_table_row($text{'email_rep'}, "<tt>$in{'rep'}</tt>");

my $email = &get_repository_email($dom, $rep);
print &ui_table_row($text{'email_email'},
		    &ui_opt_textbox("email", $email, 50,
				    $text{'email_none'}, $text{'email_send'}));

print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("index.cgi?show=$in{'show'}", $text{'index_return'});
