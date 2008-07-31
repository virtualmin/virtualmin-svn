#!/usr/local/bin/perl
# Show all repositories for this user

require './virtualmin-svn-lib.pl';
&ReadParse();
if ($in{'show'}) {
	$showd = &virtual_server::get_domain_by("dom", $in{'show'});
	$showd || &error($text{'index_eshow'});
	}
&ui_print_header($showd ? &virtual_server::domain_in($showd) : undef,
		 $text{'index_title'}, "", undef, 1, 1);

# Check if subversion is installed
$err = &svn_check();
if ($err) {
	&ui_print_endpage($err);
	}

# Check if plugin is enabled
if (&indexof($module_name, @virtual_server::plugins) < 0) {
	if (&virtual_server::can_edit_templates()) {
		$cgi = $virtual_server::module_info{'version'} >= 3.47 ?
			"edit_newfeatures.cgi" : "edit_newplugins.cgi";
		&ui_print_endpage(&text('index_eplugin',
			"../virtual-server/$cgi"));
		}
	else {
		&ui_print_endpage($text{'index_eplugin2'});
		}
	}

# Show repositories for Virtualmin domains visible to the current user
foreach $d ($in{'show'} ? ( $showd ) : &virtual_server::list_domains()) {
	$domcount++;
	next if (!&can_edit_domain($d));
	$accesscount++;
	next if (!$d->{$module_name});
	$svncount++;
	push(@reps, &list_reps($d));
	push(@mydoms, $d);
	}
if (!@mydoms) {
	&ui_print_endpage(!$domcount ? $text{'index_edoms2'} :
			  !$accesscount ? $text{'index_edoms'} :
					  $text{'index_edoms3'});
	}

# Build table of repositories
@table = ( );
foreach $r (@reps) {
	$dom = $r->{'dom'}->{'dom'};
	@actions = (
		&ui_submit($text{'delete'},
			   $r->{'rep'}."\@".$r->{'dom'}->{'id'}),
		);
	if ($config{'cannotify'}) {
		push(@actions, &ui_submit($text{'index_email'},
			   $r->{'rep'}."\@".$r->{'dom'}->{'id'}));
		}
	push(@actions, &ui_submit($text{'index_perms'},
			   $r->{'rep'}."\@".$r->{'dom'}->{'id'}));
	if ($config{'candump'}) {
		push(@actions, &ui_submit($text{'index_dump'},
			   $r->{'rep'}."\@".$r->{'dom'}->{'id'}));
		}
	if ($config{'canload'}) {
		push(@actions, &ui_submit($text{'index_load'},
			   $r->{'rep'}."\@".$r->{'dom'}->{'id'}));
		}
	push(@table, [ $r->{'rep'}, $dom, $r->{'dir'}, join(" ", @actions) ]);
	}

# Show table of repos
if ($access{'max'} && $access{'max'} > @reps) {
	print "<b>",&text('index_canadd0', $access{'max'}-@reps),
	      "</b><p>\n";
	}
print &ui_form_columns_table(
	"delete.cgi",
	undef,
	0,
	undef,
	[ [ 'show', $in{'show'} ] ],
	[ $text{'index_rep'}, $text{'index_dom'},
	  $text{'index_dir'}, $text{'index_action'} ],
	100,
	\@table,
	undef,
	0,
	undef,
	$text{'index_none'});

if ($access{'max'} && @reps >= $access{'max'}) {
	# Cannot add any more
	print $text{'index_max'},"<br>\n";
	}
else {
	# Show form to add a repository
	print &ui_form_start("add.cgi");
	print &ui_hidden("show", $in{'show'});
	print &ui_table_start($text{'index_header'}, undef, 2, [ "width=30%" ]);
	print &ui_table_row($text{'index_rep'},
			    &ui_textbox("rep", undef, 20), 1);
	print &ui_table_row($text{'index_dom'},
		    &ui_select("dom", undef,
			[ map { [ $_->{'id'}, $_->{'dom'} ] } @mydoms ]));
	if (&supports_fs_type()) {
		print &ui_table_row($text{'index_type'},
				    &ui_select("type", "fsfs",
					    [ [ "fsfs", "Versioned Filesystem (FSFS)" ],
					      [ "bdb", "Berkeley DB" ] ]));
		}
	print &ui_table_row($text{'index_ro'},
			    &ui_yesno_radio("ro", 0));
	print &ui_table_end();
	print &ui_submit($text{'create'});
	print &ui_form_end();
	}

&ui_print_footer("/", $text{'index'});

