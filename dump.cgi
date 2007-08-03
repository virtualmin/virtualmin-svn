#!/usr/local/bin/perl
# Actually perform a dump

require './virtualmin-svn-lib.pl';
&ReadParse();
&error_setup($text{'dump_err'});

# Get the domain and repository
$dom = &virtual_server::get_domain($in{'dom'});
&can_edit_domain($dom) || &error($text{'add_edom'});
@reps = &list_reps($dom);
($rep) = grep { $_->{'rep'} eq $in{'rep'} } @reps;
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
	$temp = &transname();
	&open_tempfile(TEMP, ">$temp", 0, 1);
	&close_tempfile(TEMP);
	&set_ownership_permissions($dom->{'uid'}, $dom->{'ugid'}, undef, $temp);
	$err = &dump_rep($dom, $rep, $temp);
	$err && &error($err);
	print "Content-type: application/octet-stream\n\n";
	print &read_file_contents($temp);
	unlink($temp);
	}
else {
	# To the specified file
	&ui_print_header(&virtual_server::domain_in($dom),
			 $text{'dump_title'}, "");
	print &text('dump_doing', "<tt>$in{'file'}</tt>"),"<br>\n";
	$err = &dump_rep($dom, $rep, $in{'file'});
	if ($err) {
		print &text('dump_failed', $err),"<p>\n";
		}
	else {
		@st = stat($in{'file'});
		print &text('dump_done', &nice_size($st[7])),"<p>\n";
		}

	&ui_print_footer("", $text{'index_return'});
	}

