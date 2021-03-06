#!/usr/local/bin/perl
# Load an SVN repository
use strict;
use warnings;
our (%text, %in, %config);

require './virtualmin-svn-lib.pl';
&ReadParseMime();
&error_setup($text{'load_err'});
$config{'canload'} || &error($text{'load_ecannot'});

# Get the domain and repository
my $dom = &virtual_server::get_domain($in{'dom'});
&can_edit_domain($dom) || &error($text{'add_edom'});
my @reps = &list_reps($dom);
my ($rep) = grep { $_->{'rep'} eq $in{'rep'} } @reps;
$rep || &error($text{'delete_erep'});

# Validate inputs and get the file
my $dumpfile;
if ($in{'from_def'} == 1) {
	# Local file
	$in{'file'} =~ /\S/ || &error($text{'load_efile'});
	if ($in{'file'} !~ /^\//) {
		$in{'file'} = "$dom->{'home'}/$in{'file'}";
		}
	$dumpfile = $in{'file'};
	-r $dumpfile || &error($text{'load_efile2'});
	}
else {
	# Uploaded file
	$in{'upload'} || &error($text{'load_eupload'});
	$dumpfile = &transname();
	no strict "subs";
	&open_tempfile(DUMP, ">$dumpfile", 0, 1);
	&print_tempfile(DUMP, $in{'upload'});
	&close_tempfile(DUMP);
	use strict "subs";
	&set_ownership_permissions($dom->{'uid'}, $dom->{'ugid'},
				   undef, $dumpfile);
	}

# Do the restore
&ui_print_header(&virtual_server::domain_in($dom), $text{'load_title'}, "");
print &text('load_doing', "<tt>$in{'file'}</tt>"),"<br>\n";
my $err = &load_rep($dom, $rep, $dumpfile);
if ($err) {
	print &text('load_failed', $err),"<p>\n";
	}
else {
	print $text{'load_done'},"<p>\n";
	&webmin_log("load", "repo", $in{'rep'}, { 'dom' => $dom->{'dom'} });
	}

&ui_print_footer("index.cgi?show=$in{'show'}", $text{'index_return'});
