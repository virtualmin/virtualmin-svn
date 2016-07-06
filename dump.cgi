#!/usr/local/bin/perl
# Actually perform a dump
use strict;
use warnings;
our (%text, %in, %config);
our $module_name;

require './virtualmin-svn-lib.pl';
&ReadParse();
&error_setup($text{'dump_err'});
$config{'candump'} || &error($text{'dump_ecannot'});

# Get the domain and repository
my $dom = &virtual_server::get_domain($in{'dom'});
&can_edit_domain($dom) || &error($text{'add_edom'});
my @reps = &list_reps($dom);
my ($rep) = grep { $_->{'rep'} eq $in{'rep'} } @reps;
$rep || &error($text{'delete_erep'});

# Validate inputs
if ($in{'to_def'} == 1) {
	$in{'file'} =~ /\S/ || &error($text{'dump_efile'});
	if ($in{'file'} !~ /^\//) {
		$in{'file'} = "$dom->{'home'}/$in{'file'}";
		}
	}

# Do the dump
if ($in{'to_def'} == 0) {
	# To a temp file
	my $temp = &transname();
	no strict "subs";
	&open_tempfile(TEMP, ">$temp", 0, 1);
	&close_tempfile(TEMP);
	use strict "subs";
	&set_ownership_permissions($dom->{'uid'}, $dom->{'ugid'}, undef, $temp);
	my $err = &dump_rep($dom, $rep, $temp);
	$err && &error($err);
	print "Content-type: application/octet-stream\n\n";
	print &read_file_contents($temp);
	unlink($temp);
	&webmin_log("dump", "repo", $in{'rep'}, { 'dom' => $dom->{'dom'} });
	}
else {
	# To the specified file
	&ui_print_header(&virtual_server::domain_in($dom),
			 $text{'dump_title'}, "");
	print &text('dump_doing', "<tt>$in{'file'}</tt>"),"<br>\n";
	my $err = &dump_rep($dom, $rep, $in{'file'});
	if ($err) {
		print &text('dump_failed', $err),"<p>\n";
		}
	else {
		my @st = stat($in{'file'});
		print &text('dump_done', &nice_size($st[7])),"<p>\n";
		&webmin_log("dump", "repo", $in{'rep'},
			    { 'dom' => $dom->{'dom'} });
		}

	&ui_print_footer("/$module_name/index.cgi?show=$in{'show'}",
			 $text{'index_return'});
	}
