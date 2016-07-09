# Defines functions for this feature
use strict;
use warnings;
our (%text, %in, %config);
our $module_name;
our $module_config_directory;

do 'virtualmin-svn-lib.pl';
my $input_name = $module_name;
$input_name =~ s/[^A-Za-z0-9]/_/g;
&load_theme_library();

# feature_name()
# Returns a short name for this feature
sub feature_name
{
return $text{'feat_name'};
}

# feature_losing(&domain)
# Returns a description of what will be deleted when this feature is removed
sub feature_losing
{
return $text{'feat_losing'};
}

# feature_disname(&domain)
# Returns a description of what will be turned off when this feature is disabled
sub feature_disname
{
return $text{'feat_disname'};
}

# feature_label(in-edit-form)
# Returns the name of this feature, as displayed on the domain creation and
# editing form
sub feature_label
{
my ($edit) = @_;
return $edit ? $text{'feat_label2'} : $text{'feat_label'};
}

sub feature_hlink
{
return "label";
}

# feature_check()
# Returns undef if all the needed programs for this feature are installed,
# or an error message if not
sub feature_check
{
my $err = &svn_check();
if (!$err) {
	# Check for htdigest command
	if ($config{'auth'} eq 'Digest') {
		&foreign_require("htaccess-htpasswd", "htaccess-lib.pl");
		if (!$htaccess_htpasswd::htdigest_command) {
			$err = &text('feat_edigest', "<tt>htdigest</tt>");
			}
		}
	}
return $err;
}

# feature_depends(&domain)
# Returns undef if all pre-requisite features for this domain are enabled,
# or an error message if not
sub feature_depends
{
return $_[0]->{'web'} ? undef : $text{'feat_edepweb'};
}

# feature_clash(&domain)
# Returns undef if there is no clash for this domain for this feature, or
# an error message if so
sub feature_clash
{
return undef;
}

# feature_suitable([&parentdom], [&aliasdom], [&subdom])
# Returns 1 if some feature can be used with the specified alias and
# parent domains
sub feature_suitable
{
return $_[1] || $_[2] ? 0 : 1;		# not for alias domains
}

# feature_setup(&domain)
# Called when this feature is added, with the domain object as a parameter
sub feature_setup
{
&$virtual_server::first_print($text{'setup_dav'});
&virtual_server::obtain_lock_web($_[0]);
my $any;
$any++ if (&add_svn_directives($_[0], $_[0]->{'web_port'}));
$any++ if ($_[0]->{'ssl'} &&
           &add_svn_directives($_[0], $_[0]->{'web_sslport'}));
if (!$any) {
	&$virtual_server::second_print(
		$virtual_server::text{'delete_noapache'});
	}
else {
	# Create needed directories ~/etc/ and ~/svn
	my $passwd_file = &passwd_file($_[0]);
	my $conf_file = &conf_file($_[0]);
	if (!-d "$_[0]->{'home'}/svn") {
		&virtual_server::make_dir_as_domain_user(
			$_[0], "$_[0]->{'home'}/svn", 02755);
		}
	if (!-d "$_[0]->{'home'}/etc") {
		&virtual_server::make_dir_as_domain_user(
			$_[0], "$_[0]->{'home'}/etc", 0755);
		}

	# Create password and configuration files
	if (!-r $passwd_file) {
		&lock_file($passwd_file);
		my $fh = "PASSWD";
		&virtual_server::open_tempfile_as_domain_user(
			$_[0], $fh, ">$passwd_file", 0, 1);
		&virtual_server::close_tempfile_as_domain_user(
			$_[0], $fh);
		&virtual_server::set_permissions_as_domain_user(
			$_[0], 0755, $passwd_file);
		&unlock_file($passwd_file);
		}
	if (!-r $conf_file) {
		&lock_file($conf_file);
		my $fh = "PASSWD";
		&virtual_server::open_tempfile_as_domain_user(
			$_[0], $fh, ">$conf_file", 0, 1);
		&virtual_server::close_tempfile_as_domain_user(
			$_[0], $fh);
		&virtual_server::set_permissions_as_domain_user(
			$_[0], 0755, $conf_file);
		&unlock_file($conf_file);
		}
	&$virtual_server::second_print($virtual_server::text{'setup_done'});
	&virtual_server::register_post_action(\&virtual_server::restart_apache);

	# Grant access to the domain's owner
	my $uinfo;
	if (!$_[0]->{'parent'} &&
	    ($uinfo = &virtual_server::get_domain_owner($_[0]))) {
		&$virtual_server::first_print($text{'setup_svnuser'});
		&foreign_require("htaccess-htpasswd", "htaccess-lib.pl");
		my $un = &virtual_server::remove_userdom(
			$uinfo->{'user'}, $_[0]);
		my $newuser = { 'user' => $un,
				   'enabled' => 1 };
		if ($config{'auth'} eq 'Digest') {
			# Do Digest encryption
			$newuser->{'digest'} = 1;
			$newuser->{'pass'} = $uinfo->{'digest_enc_pass'} ||
				&htaccess_htpasswd::digest_password
					($un, $_[0]->{'dom'}, $_[0]->{'pass'});
			}
		else {
			# Copy Unix crypted pass
			$newuser->{'pass'} = $uinfo->{'pass'};
			}
		&virtual_server::write_as_domain_user($_[0],
			sub { &htaccess_htpasswd::create_user(
				$newuser, $passwd_file) });
		&$virtual_server::second_print(
			$virtual_server::text{'setup_done'});
		}
	}

# Set default limit from template
if (!exists($_[0]->{$module_name."limit"})) {
        my $tmpl = &virtual_server::get_template($_[0]->{'template'});
        $_[0]->{$module_name."limit"} =
                $tmpl->{$module_name."limit"} eq "none" ? "" :
                 $tmpl->{$module_name."limit"};
        }

# Make sure /svn isn't proxied
if (defined(&virtual_server::setup_noproxy_path)) {
	&virtual_server::setup_noproxy_path(
		$_[0], { }, undef, { 'path' => '/svn/' }, 1);
	}

&virtual_server::release_lock_web($_[0]);
}

sub add_svn_directives
{
my ($d, $port) = @_;
my ($virt, $vconf) = &virtual_server::get_apache_virtual($d->{'dom'}, $port);
if ($virt) {
	my $lref = &read_file_lines($virt->{'file'});
	my ($locstart, $locend) =
		&find_svn_lines($lref, $virt->{'line'}, $virt->{'eline'});
	my @lines;
	my $passwd_file = &passwd_file($d);
	my $conf_file = &conf_file($d);
	my $at = $config{'auth'};
	my $auf = $at eq "Digest" && $apache::httpd_modules{'core'} < 2.2 ?
			"AuthDigestFile" : "AuthUserFile";
	my @adp = $at eq "Digest" && $apache::httpd_modules{'core'} >= 2.2 ?
			("AuthDigestProvider file") : ( );
	my @auto;
	@auto = ( "SVNAutoversioning on") if ($config{'auto'});
	my @norewrite;
	if ($apache::httpd_modules{'mod_rewrite'}) {
		@norewrite = ( "RewriteEngine off" );
		}
	if (!$locstart) {
		push(@lines,
			"<Location /svn>",
			"DAV svn",
			@auto,
			"SVNParentPath $d->{'home'}/svn",
			"AuthType $at",
			"AuthName $d->{'dom'}",
			"$auf $passwd_file",
			@adp,
			"Require valid-user",
			"AuthzSVNAccessFile $conf_file",
			"Satisfy Any",
			@norewrite,
			"ErrorDocument 404 default",
		        "</Location>");
		}
	splice(@$lref, $virt->{'eline'}, 0, @lines);
	&flush_file_lines();
	undef(@apache::get_config_cache);
	return 1;
	}
else {
	return 0;
	}
}

# feature_modify(&domain, &olddomain)
# Called when a domain with this feature is modified
sub feature_modify
{
if ($_[0]->{'dom'} ne $_[1]->{'dom'}) {
	# Change AuthName in webserver
	&$virtual_server::first_print($text{'save_dav'});
	&virtual_server::obtain_lock_web($_[0]);
        &change_svn_directives($_[0], $_[0]->{'web_port'});
        &change_svn_directives($_[0], $_[0]->{'web_sslport'})
                if ($_[0]->{'ssl'});
	&virtual_server::release_lock_web($_[0]);
	&$virtual_server::second_print($virtual_server::text{'setup_done'});
	}
if ($_[0]->{'pass_set'}) {
	# Change password for domain admin, if he has an SVN account
	my @users = &list_users($_[0]);
	my ($suser) = grep { $_->{'user'} eq $_[0]->{'user'} } @users;
	if ($suser) {
		&$virtual_server::first_print($text{'save_davpass'});
		&lock_file(&passwd_file($_[0]));
		&lock_file(&conf_file($_[0]));
		if ($config{'auth'} eq 'Digest') {
			$suser->{'pass'} = $_[0]->{'digest_enc_pass'} ||
			    &htaccess_htpasswd::digest_password(
			      $_[0]->{'user'}, $_[0]->{'dom'}, $_[0]->{'pass'});
			}
		else {
			$suser->{'pass'} = $_[0]->{'crypt_enc_pass'} ||
			    &htaccess_htpasswd::encrypt_password(
			        $_[0]->{'pass'});
			}
		&virtual_server::write_as_domain_user($_[0],
			sub { &htaccess_htpasswd::modify_user($suser) });
		&unlock_file(&passwd_file($_[0]));
		&unlock_file(&conf_file($_[0]));
		&$virtual_server::second_print(
			$virtual_server::text{'setup_done'});
		}
	}
}

sub change_svn_directives
{
my ($d, $port) = @_;
my $conf = &apache::get_config();
my ($virt, $vconf) = &virtual_server::get_apache_virtual($d->{'dom'}, $port);
return 0 if (!$virt);
my @locs = &apache::find_directive_struct("Location", $vconf);
my ($davloc) = grep { $_->{'words'}->[0] eq "/svn" } @locs;
if ($davloc) {
        my $auth = &apache::find_directive_struct(
                "AuthName", $davloc->{'members'});
        if ($auth) {
                &apache::save_directive("AuthName", [ $d->{'dom'} ],
                                        $davloc->{'members'}, $conf);
                &flush_file_lines();
                }
        return 1;
        }
return 0;
}

# feature_delete(&domain)
# Called when this feature is disabled, or when the domain is being deleted
sub feature_delete
{
&$virtual_server::first_print($text{'delete_dav'});
&virtual_server::obtain_lock_web($_[0]);
my $any;
$any++ if (&remove_svn_directives($_[0], $_[0]->{'web_port'}));
$any++ if ($_[0]->{'ssl'} &&
           &remove_svn_directives($_[0], $_[0]->{'web_sslport'}));
&virtual_server::release_lock_web($_[0]);
if (!$any) {
	&$virtual_server::second_print(
		$virtual_server::text{'delete_noapache'});
	}
else {
	&$virtual_server::second_print($virtual_server::text{'setup_done'});
	&virtual_server::register_post_action(\&virtual_server::restart_apache);

	# Remove negative proxy for /svn
	if (defined(&virtual_server::delete_noproxy_path)) {
		&virtual_server::delete_noproxy_path(
			$_[0], { }, undef, { 'path' => '/svn/' });
		}
	}
}

sub remove_svn_directives
{
my ($d, $port) = @_;
my ($virt, $vconf) = &virtual_server::get_apache_virtual($d->{'dom'}, $port);
if ($virt) {
        my $lref = &read_file_lines($virt->{'file'});
        my ($locstart, $locend) =
                &find_svn_lines($lref, $virt->{'line'}, $virt->{'eline'});
        if ($locstart) {
                splice(@$lref, $locstart, $locend-$locstart+1);
                }
        &flush_file_lines();
        undef(@apache::get_config_cache);
        return 1;
        }
else {
        return 0;
        }
}

# find_svn_lines(&lref, start, end)
sub find_svn_lines
{
my ($locstart, $locend, $i);
for($i=$_[1]; $i<=$_[2]; $i++) {
	if ($_[0]->[$i] =~ /^\s*<Location\s+\/svn>/i && !$locstart) {
		$locstart = $i;
		}
	elsif ($_[0]->[$i] =~ /^\s*<\/Location>/i && $locstart && !$locend) {
		$locend = $i;
		}
	}
return ($locstart, $locend);
}

# feature_webmin(&domain)
# Returns a list of webmin module names and ACL hash references to be set for
# the Webmin user when this feature is enabled
sub feature_webmin
{
my @doms = map { $_->{'dom'} } grep { $_->{$module_name} } @{$_[1]};
if (@doms) {
	return ( [ $module_name,
		   { 'dom' => join(" ", @doms),
		     'max' => $_[0]->{$module_name.'limit'},
		     'noconfig' => 1 } ] );
	}
else {
	return ( );
	}
}

# feature_limits_input(&domain)
# Returns HTML for editing limits related to this plugin
sub feature_limits_input
{
my ($d) = @_;
return undef if (!$d->{$module_name});
return &ui_table_row(&hlink($text{'limits_max'}, "limits_max"),
	&ui_opt_textbox($input_name."limit", $d->{$module_name."limit"},
			4, $virtual_server::text{'form_unlimit'},
			   $virtual_server::text{'form_atmost'}));
}

# feature_limits_parse(&domain, &in)
# Updates the domain with limit inputs generated by feature_limits_input
sub feature_limits_parse
{
my ($d, $in) = @_;
return undef if (!$d->{$module_name});
if ($in->{$input_name."limit_def"}) {
	delete($d->{$module_name."limit"});
	}
else {
	$in->{$input_name."limit"} =~ /^\d+$/ || return $text{'limit_emax'};
	$d->{$module_name."limit"} = $in->{$input_name."limit"};
	}
return undef;
}

# feature_links(&domain)
# Returns an array of link objects for webmin modules for this feature
sub feature_links
{
my ($d) = @_;
return ( { 'mod' => $module_name,
	   'desc' => $text{'links_link'},
	   'page' => 'index.cgi?show='.$d->{'dom'},
	   'cat' => 'services',
          } );
}

sub feature_modules
{
return ( [ $module_name, $text{'feat_module'} ] );
}

# feature_backup(&domain, file, &opts, &all-opts)
# Copy the SVN password file, config file and repositories for the domain
sub feature_backup
{
my ($d, $file, $opts) = @_;
&$virtual_server::first_print($text{'feat_backup'});

# Copy actual repositories
my $tar = &virtual_server::get_tar_command();
my $temp = &transname();
my $out = &backquote_command("cd ".quotemeta("$d->{'home'}/svn")." && ".
				"$tar cf ".quotemeta($temp)." . 2>&1");
if ($?) {
	&$virtual_server::second_print(&text('feat_tar', "<pre>$out</pre>"));
	return 0;
	}
&virtual_server::copy_write_as_domain_user($d, $temp, $file);
&unlink_file($temp);

# Copy users file
my $pfile = &passwd_file($_[0]);
if (!-r $pfile) {
	&$virtual_server::second_print($text{'feat_nopfile'});
	return 0;
	}
&virtual_server::copy_write_as_domain_user($d, $pfile, $file."_users");

# Copy config file
my $cfile = &conf_file($_[0]);
if (!-r $cfile) {
	&$virtual_server::second_print($text{'feat_nopfile'});
	return 0;
	}
&virtual_server::copy_write_as_domain_user($d, $cfile, $file."_config");

&$virtual_server::second_print($virtual_server::text{'setup_done'});
return 1;
}

# feature_restore(&domain, file, &opts, &all-opts)
# Called to restore this feature for the domain from the given file
sub feature_restore
{
my ($d, $file, $opts) = @_;
&$virtual_server::first_print($text{'feat_restore'});

# Extract tar file of repositories (deleting old ones first)
my $tar = &virtual_server::get_tar_command();
&execute_command("rm -rf ".quotemeta("$d->{'home'}/svn")."/*");
my ($out, $ex) = &virtual_server::run_as_domain_user($d,
	"cd ".quotemeta("$d->{'home'}/svn")." && $tar xf ".quotemeta($file)." 2>&1");
if ($ex) {
	&$virtual_server::second_print(&text('feat_untar', "<pre>$out</pre>"));
	return 0;
	}

# Copy users file
my $pfile = &passwd_file($d);
(my $ok, $out) = &virtual_server::copy_source_dest_as_domain_user(
    		$d, $file."_users", $pfile);
if (!$ok) {
	&$virtual_server::second_print(&text('feat_copypfile2', $out));
	return 0;
	}

# Copy config file
my $cfile = &conf_file($d);
($ok, $out) = &virtual_server::copy_source_dest_as_domain_user(
		$d, $file."_config", $cfile);
if (!$ok) {
	&$virtual_server::second_print(&text('feat_copycfile2', $out));
	return 0;
	}

# Fix repo permissions
foreach my $rep (&list_reps($d)) {
	&set_rep_permissions($d, $rep);
	}

&$virtual_server::second_print($virtual_server::text{'setup_done'});
return 1;
}

sub feature_backup_name
{
return $text{'feat_backup_name'};
}

# feature_validate(&domain)
# Checks if this feature is properly setup for the virtual server, and returns
# an error message if any problem is found
sub feature_validate
{
my ($d) = @_;
my $passwd_file = &passwd_file($d);
-r $passwd_file || return &text('feat_evalidatefile', "<tt>$passwd_file</tt>");
my $conf_file = &conf_file($d);
-r $conf_file || return &text('feat_evalidateconf', "<tt>$conf_file</tt>");
my ($virt, $vconf) = &virtual_server::get_apache_virtual($d->{'dom'});
$virt || return &virtual_server::text('validate_eweb', $d->{'dom'});
my $lref = &read_file_lines($virt->{'file'});
my ($locstart, $locend) =
        &find_svn_lines($lref, $virt->{'line'}, $virt->{'eline'});
$locstart || return &text('feat_evalidateloc');
return undef;
}

# mailbox_inputs(&user, new, &domain)
# Returns HTML for additional inputs on the mailbox form. These should be
# formatted to appear inside a table.
sub mailbox_inputs
{
my ($user, $new, $dom) = @_;
return undef if (!$dom || !$dom->{$module_name});
my $un = &virtual_server::remove_userdom($user->{'user'}, $dom);
my $suser;
if (!$new) {
	my @users = &list_users($dom);
	($suser) = grep { $_->{'user'} eq $un } @users;
	}
$main::ui_table_cols = 2;
my @reps = &list_reps($dom);
my (@rwreps, @roreps);
foreach my $r (@reps) {
	my @rusers = &list_rep_users($dom, $r->{'rep'});
	my ($ruser) = grep { $_->{'user'} eq $un } @rusers;
	if ($ruser && $ruser->{'perms'} eq 'rw') {
		push(@rwreps, $r->{'rep'});
		}
	elsif ($ruser && $ruser->{'perms'} eq 'r') {
		push(@roreps, $r->{'rep'});
		}
	}
my %defs;
&read_file("$module_config_directory/defaults.$dom->{'id'}", \%defs);
if (!$suser && !@rwreps) {
	# Use default repositories
	@rwreps = split(/\s+/, $defs{'reps'});
	}
@rwreps = sort { $a cmp $b } @rwreps;
@roreps = sort { $a cmp $b } @roreps;
@reps = sort { $a->{'rep'} cmp $b->{'rep'} } @reps;
my @inputs = ( $input_name."_rwreps_opts", $input_name."_rwreps_vals",
		  $input_name."_rwreps_add", $input_name."_rwreps_remove",
		  $input_name."_roreps_opts", $input_name."_roreps_vals",
		  $input_name."_roreps_add", $input_name."_roreps_remove", );
my $hasuser = $suser || $new && $defs{'svn'};
my $dis = $hasuser ? 0 : 1;
if (&get_webmin_version() < 1.501) {
	# Only Webmin 1.501 and later support disabling multi-select properly
	$dis = 0;
	@inputs = ( );
	}
my $jsenable = &js_disable_inputs([ ], \@inputs, "onClick");
my $jsdisable = &js_disable_inputs(\@inputs, [ ], "onClick");
return &ui_table_row(&hlink($text{'mail_svn'}, "svn"),
		     &ui_radio($input_name, $hasuser ? 1 : 0,
			       [ [ 1, $text{'yes'}, $jsenable ],
				 [ 0, $text{'no'}, $jsdisable ] ])).
       &ui_table_row(&hlink($text{'mail_reps'}, "reps"),
		     &ui_multi_select(
			$input_name."_rwreps",
			[ map { [ $_, $_ ] } @rwreps ],
			[ map { [ $_->{'rep'}, $_->{'rep'} ] } @reps ],
			3, 0, $hasuser ? 0 : 1,
			$text{'mail_repsopts'}, $text{'mail_repsin'})).
       &ui_table_row(&hlink($text{'mail_roreps'}, "roreps"),
		     &ui_multi_select(
			$input_name."_roreps",
			[ map { [ $_, $_ ] } @roreps ],
			[ map { [ $_->{'rep'}, $_->{'rep'} ] } @reps ],
			3, 0, $dis,
			$text{'mail_repsopts'}, $text{'mail_repsin'}));
}

# mailbox_validate(&user, &olduser, &in, new, &domain)
# Validates inputs generated by mailbox_inputs, and returns either undef on
# success or an error message
sub mailbox_validate
{
my ($user, $olduser, $in, $new, $dom) = @_;
return undef if (!$dom || !$dom->{$module_name});
if ($in->{$input_name}) {
	my @users = &list_users($dom);
	my $un = &virtual_server::remove_userdom($user->{'user'}, $dom);
	my $oun = &virtual_server::remove_userdom($olduser->{'user'}, $dom);
	my ($suser) = grep { $_->{'user'} eq $oun } @users;

	# Make sure SVN user doesn't clash
	if ($new || $user->{'user'} ne $olduser->{'user'}) {
		my ($clash) = grep { $_->{'user'} eq $un } @users;
		return &text('mail_clash', $un) if ($clash);
		}

        # Make sure a password is given if needed
        if (!defined($user->{'plainpass'}) &&
            !$user->{'pass_digest'} &&
	    !$suser &&
            $user->{'user'} ne $dom->{'user'} &&
            $config{'auth'} eq 'Digest') {
                return $text{'mail_pass'};
                }

	# Make sure rw and ro repos don't clash
	my @rwreps = split(/\r?\n/, $in->{$input_name."_rwreps"});
	my @roreps = split(/\r?\n/, $in->{$input_name."_roreps"});
	foreach my $r (@rwreps) {
		&indexof($r, @roreps) < 0 || return &text('mail_repoclash', $r);
		}
	}
return undef;
}

# mailbox_save(&user, &olduser, &in, new, &domain)
# Updates the user based on inputs generated by mailbox_inputs
sub mailbox_save
{
my ($user, $olduser, $in, $new, $dom) = @_;
return undef if (!$dom || !$dom->{$module_name});
&foreign_require("htaccess-htpasswd", "htaccess-lib.pl");
my @users = &list_users($dom);
my $suser;
my $un = &virtual_server::remove_userdom($user->{'user'}, $dom);
my $oun = &virtual_server::remove_userdom($olduser->{'user'}, $dom);
my $rv;

&lock_file(&passwd_file($dom));
&lock_file(&conf_file($dom));
if (!$new) {
	($suser) = grep { $_->{'user'} eq $oun } @users;
	}
if ($in->{$input_name} && !$suser) {
	# Add the user
	my $newuser = { 'user' => $un,
			   'enabled' => 1 };
	&set_user_password($newuser, $user, $dom);
	&virtual_server::write_as_domain_user($dom,
		sub { &htaccess_htpasswd::create_user(
			$newuser, &passwd_file($dom)) });
	&virtual_server::set_permissions_as_domain_user(
		$dom, 0755, &passwd_file($dom));
	$rv = 1;
	}
elsif (!$in->{$input_name} && $suser) {
	# Delete the user
	&virtual_server::write_as_domain_user($dom,
		sub { &htaccess_htpasswd::delete_user($suser) });
	$rv = 0;
	}
elsif ($in->{$input_name} && $suser) {
	# Update the user
	$suser->{'user'} = $un;
	if ($user->{'passmode'} == 3) {
		if ($config{'auth'} eq 'Digest') {
			$suser->{'pass'} = $user->{'pass_digest'} ||
			    &htaccess_htpasswd::digest_password(
				$un, $dom->{'dom'}, $user->{'plainpass'});
			}
		else {
			$suser->{'pass'} = $user->{'pass_crypt'} ||
					   $user->{'pass'};
			}
		}
	&virtual_server::write_as_domain_user($dom,
		sub { &htaccess_htpasswd::modify_user($suser) });
	$rv = 1;
	}
&unlock_file(&passwd_file($dom));
&unlock_file(&conf_file($dom));

# Update list of repositories user has access to
my %canrwreps = map { $_, 1 } split(/\r?\n/, $in->{$input_name."_rwreps"});
my %canroreps = map { $_, 1 } split(/\r?\n/, $in->{$input_name."_roreps"});
if (!$in->{$input_name}) {
	%canrwreps = ( );
	%canroreps = ( );
	}
foreach my $r (&list_reps($dom)) {
	my @rusers = &list_rep_users($dom, $r->{'rep'});
	my ($ruser) = grep { $_->{'user'} eq $oun } @rusers;
	@rusers = grep { $_ ne $ruser } @rusers;
	if ($canrwreps{$r->{'rep'}}) {
		push(@rusers, { 'user' => $un,
				'perms' => 'rw' });
		}
	elsif ($canroreps{$r->{'rep'}}) {
		push(@rusers, { 'user' => $un,
				'perms' => 'r' });
		}
	if ($ruser || $canrwreps{$r->{'rep'}} || $canroreps{$r->{'rep'}}) {
		# Only save if user was there before or is now
		&save_rep_users($dom, $r, \@rusers);
		}
	}

return $rv;
}

# mailbox_modify(&user, &old, &domain)
sub mailbox_modify
{
my ($user, $olduser, $dom) = @_;
return undef if (!$dom || !$dom->{$module_name});
&foreign_require("htaccess-htpasswd", "htaccess-lib.pl");
my @users = &list_users($dom);
my $un = &virtual_server::remove_userdom($user->{'user'}, $dom);
my $oun = &virtual_server::remove_userdom($olduser->{'user'}, $dom);
my ($suser) = grep { $_->{'user'} eq $oun } @users;
return undef if (!$suser);

&lock_file(&passwd_file($dom));
&lock_file(&conf_file($dom));

if ($un ne $oun && $suser) {
	# User was re-named
	$suser->{'user'} = $un;
	&htaccess_htpasswd::modify_user($suser);
	foreach my $r (&list_reps($dom)) {
		my @rusers = &list_rep_users($dom, $r->{'rep'});
		my ($ruser) = grep { $_->{'user'} eq $oun } @rusers;
		if ($ruser) {
			$ruser->{'user'} = $un;
			&save_rep_users($dom, $r, \@rusers);
			}
		}
	}

if ($user->{'passmode'} == 3) {
	# Password was changed
	if ($config{'auth'} eq 'Digest') {
		$suser->{'pass'} = $user->{'pass_digest'} ||
		    &htaccess_htpasswd::digest_password(
			$un, $dom->{'dom'}, $user->{'plainpass'});
		}
	else {
		$suser->{'pass'} = $user->{'pass_crypt'} ||
		    &htaccess_htpasswd::encrypt_password(
			$user->{'plainpass'});
		}
	&virtual_server::write_as_domain_user($dom,
		sub { &htaccess_htpasswd::modify_user($suser) });
	}

&unlock_file(&passwd_file($dom));
&unlock_file(&conf_file($dom));
}

# mailbox_delete(&user, &domain)
# Removes any extra features for this user
sub mailbox_delete
{
my ($user, $dom) = @_;
return undef if (!$dom || !$dom->{$module_name});
&foreign_require("htaccess-htpasswd", "htaccess-lib.pl");

&lock_file(&passwd_file($dom));
&lock_file(&conf_file($dom));

my @users = &list_users($dom);
my $un = &virtual_server::remove_userdom($user->{'user'}, $dom);
my ($suser) = grep { $_->{'user'} eq $un } @users;
if ($suser) {
	&virtual_server::write_as_domain_user($dom,
		sub { &htaccess_htpasswd::delete_user($suser) });
	}

# Remove from all repositories
foreach my $r (&list_reps($dom)) {
	my @rusers = &list_rep_users($dom, $r->{'rep'});
	my ($ruser) = grep { $_->{'user'} eq $un } @rusers;
	my @newrusers = grep { $_ ne $ruser } @rusers;
	if (@newrusers != @rusers) {
		&save_rep_users($dom, $r, \@newrusers);
		}
	}

&unlock_file(&passwd_file($dom));
&unlock_file(&conf_file($dom));
}

# mailbox_header(&domain)
# Returns a column header for the user display, or undef for none
my @column_users; # Sniffy.
sub mailbox_header
{
if ($_[0]->{$module_name}) {
	@column_users = &list_users($_[0]);
	return $text{'mail_header'};
	}
else {
	return undef;
	}
}

# mailbox_column(&user, &domain)
# Returns the text to display in the column for some user
sub mailbox_column
{
my ($user, $dom) = @_;
my $un = &virtual_server::remove_userdom($user->{'user'}, $dom);
my ($duser) = grep { $_->{'user'} eq $un } @column_users;
return $duser ? $text{'yes'} : $text{'no'};
}

# mailbox_defaults_inputs(&defs, &domain)
# Returns HTML for editing defaults for plugin-related settings for new
# users in this virtual server
sub mailbox_defaults_inputs
{
my ($defs, $dom) = @_;
if ($dom->{$module_name}) {
	my %defs;
	&read_file("$module_config_directory/defaults.$dom->{'id'}", \%defs);
	my @reps = &list_reps($dom);
	return &ui_table_row($text{'mail_svn'},
		&ui_yesno_radio($input_name, int($defs{'svn'})))."\n".
	       &ui_table_row($text{'mail_reps'},
		     &ui_select($input_name."_reps",
				[ split(/\s+/, $defs{'reps'}) ],
				[ map { [ $_->{'rep'}, $_->{'rep'} ] } @reps ],
				3, 1));
	}
}

# mailbox_defaults_parse(&defs, &domain, &in)
# Parses the inputs created by mailbox_defaults_inputs, and updates a config
# file internal to this module to store them
sub mailbox_defaults_parse
{
my ($defs, $dom, $in) = @_;
if ($dom->{$module_name}) {
	my %defs;
	&read_file("$module_config_directory/defaults.$dom->{'id'}", \%defs);
	$defs{'svn'} = $in->{$input_name};
	$defs{'reps'} = join(" ", split(/\0/, $in->{$input_name."_reps"}));
	&write_file("$module_config_directory/defaults.$dom->{'id'}", \%defs);
	}
}

# template_input(&template)
# Returns HTML for editing per-template options for this plugin
sub template_input
{
my ($tmpl) = @_;
my $v = $tmpl->{$module_name."limit"};
$v = "none" if (!defined($v) && $tmpl->{'default'});
return &ui_table_row($text{'tmpl_limit'},
        &ui_radio($input_name."_mode",
                  $v eq "" ? 0 : $v eq "none" ? 1 : 2,
                  [ $tmpl->{'default'} ? ( ) : ( [ 0, $text{'default'} ] ),
                    [ 1, $text{'tmpl_unlimit'} ],
                    [ 2, $text{'tmpl_atmost'} ] ])."\n".
        &ui_textbox($input_name, $v eq "none" ? undef : $v, 10));
}

# template_parse(&template, &in)
# Updates the given template object by parsing the inputs generated by
# template_input. All template fields must start with the module name.
sub template_parse
{
my ($tmpl, $in) = @_;
if ($in->{$input_name.'_mode'} == 0) {
        $tmpl->{$module_name."limit"} = "";
        }
elsif ($in->{$input_name.'_mode'} == 1) {
        $tmpl->{$module_name."limit"} = "none";
        }
else {
        $in->{$input_name} =~ /^\d+$/ || &error($text{'tmpl_elimit'});
        $tmpl->{$module_name."limit"} = $in->{$input_name};
        }
}

1;
