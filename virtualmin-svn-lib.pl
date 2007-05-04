
do '../web-lib.pl';
&init_config();
do '../ui-lib.pl';
&foreign_require("virtual-server", "virtual-server-lib.pl");
$config{'auth'} ||= "Basic";
%access = &get_module_acl();

sub can_edit_domain
{
return &virtual_server::can_edit_domain($_[0]);
}

# list_reps(&domain)
# Returns a list of all repositories in some domain
sub list_reps
{
local (@rv, $f);
opendir(DIR, "$_[0]->{'home'}/svn");
while($f = readdir(DIR)) {
	if ($f ne "." && $f ne "..") {
		push(@rv, { 'dom' => $_[0],
			    'rep' => $f,
			    'dir' => "$_[0]->{'home'}/svn/$f" });
		}
	}
closedir(DIR);
return @rv;
}

sub svn_check
{
return &text('feat_echeck', "<tt>$config{'svnadmin'}</tt>")
	if (!&has_command($config{'svnadmin'}));
return undef;
}

# list_rep_users(&domain, rep)
# Returns a list of all users with access to some repository
sub list_rep_users
{
local $lref = &read_file_lines(&conf_file($_[0]));
local (@rv, $inrep, $l);
foreach $l (@$lref) {
	if ($l =~ /^\s*\[(.*):\/\S*\]/) {
		$inrep = $1;
		}
	elsif ($l =~ /^\s*(\S+)\s*=\s*(\S+)/) {
		push(@rv, { 'user' => $1,
			    'perms' => $2 }) if ($inrep eq $_[1]);
		}
	}
return @rv;
}

# save_rep_users(&domain, &rep, &users)
sub save_rep_users
{
local ($dom, $rep, $users) = @_;
local $lref = &read_file_lines(&conf_file($_[0]));
local ($start, $end) = &rep_users_lines($dom, $rep, $lref);
local @lines = ( "[$rep->{'rep'}:/]",
		 map { "$_->{'user'} = $_->{'perms'}" } @$users );
if (defined($start)) {
	splice(@$lref, $start, $end-$start+1, @lines);
	}
else {
	push(@$lref, @lines);
	}
&flush_file_lines();
}

# rep_users_lines(&domain, &rep, &lref)
sub rep_users_lines
{
local ($dom, $rep, $lref) = @_;
local ($start, $end, $l, $inrep);
local $lnum = 0;
foreach $l (@$lref) {
	if ($l =~ /^\s*\[(.*):\/\S*\]/) {
		if ($1 eq $rep->{'rep'}) {
			$start = $end = $lnum;
			$inrep = 1;
			}
		else {
			$inrep = 0;
			}
		}
	elsif ($l =~ /^\s*(\S+)\s*=\s*(\S+)/ && $inrep) {
		$end = $lnum;
		}
	$lnum++;
	}
return ($start, $end);
}

# create_rep(&domain, &rep, type)
# Create a repository directory and perms file entry
sub create_rep
{
local ($dom, $rep, $type) = @_;
$rep->{'dir'} = "$dom->{'home'}/svn/$rep->{'rep'}";
local $qdir = quotemeta($rep->{'dir'});
if (&supports_fs_type()) {
	$out = &backquote_logged("svnadmin create --fs-type $type $qdir 2>&1");
	}
else {
	$out = &backquote_logged("svnadmin create $qdir 2>&1");
	}
if ($?) {
	return $out;
	}
local $webuser;
if (defined(&virtual_server::get_apache_user)) {
	$webuser = &virtual_server::get_apache_user($dom);
	}
else {
	foreach my $u ("httpd", "apache", "www", "nobody") {
		if (defined(getpwnam($u))) {
			$webuser = $u;
			last;
			}
		}
	}
local @uinfo = getpwnam($webuser);
&system_logged("chown -R $uinfo[2]:$uinfo[3] $qdir");
&system_logged("chmod -R 770 $qdir");

local $lref = &read_file_lines(&conf_file($dom));
local ($start, $end) = &rep_users_lines($dom, $rep, $lref);
if (!defined($start)) {
	push(@$lref, "[$rep->{'rep'}:/]");
	&flush_file_lines();
	}
}

# delete_rep(&domain, &rep)
# Delete a repository directory and perms file entry
sub delete_rep
{
local ($dom, $rep) = @_;
&system_logged("rm -rf ".quotemeta("$dom->{'home'}/svn/$rep->{'rep'}"));
local $lref = &read_file_lines(&conf_file($dom));
local ($start, $end) = &rep_users_lines($dom, $rep, $lref);
if (defined($start)) {
	splice(@$lref, $start, $end-$start+1);
	&flush_file_lines();
	}
}

sub supports_fs_type
{
local $out = &backquote_command("$config{'svnadmin'} help create 2>&1", 1);
return $out =~ /\-\-fs\-type/;
}

# passwd_file(&domain)
sub passwd_file
{
if ($config{'passfile'}) {
	return "$_[0]->{'home'}/$config{'passfile'}";
	}
else {
	return "$_[0]->{'home'}/etc/svn.basic.passwd";
	}
}

sub conf_file
{
return "$_[0]->{'home'}/etc/svn-access.conf";
}

# list_users(&domain)
sub list_users
{
local $users;
&foreign_require("htaccess-htpasswd", "htaccess-lib.pl");
if ($config{'auth'} eq 'Digest') {
	$users = &htaccess_htpasswd::list_digest_users(&passwd_file($_[0]));
	}
else {
	$users = &htaccess_htpasswd::list_users(&passwd_file($_[0]));
	}
return @$users;
}

# get_repository_email(&domain, &rep)
# Returns the email address to notify when changes to some repo are committed
sub get_repository_email
{
local ($dom, $rep) = @_;
local $pc = "$dom->{'home'}/svn/$rep->{'rep'}/hooks/post-commit";
local $lref = &read_file_lines($pc);
local ($prog, $email);
foreach my $l (@$lref) {
	if ($l =~ /^\s*EMAIL="(.*)"/) {
		$email = $1;
		}
	elsif ($l =~ /^\S+\/commit-email.pl.*\$EMAIL/ &&
	       $l !~ /^\#/) {
		$prog = 1;
		}
	}
return $prog && $email ? $email : undef;
}

# save_repository_email(&domain, &rep, email)
# Updates the email address to notify when changes to some repo are committed
sub save_repository_email
{
local ($dom, $rep, $email) = @_;
local $pc = "$dom->{'home'}/svn/$rep->{'rep'}/hooks/post-commit";
local $lref = &read_file_lines($pc);
if (!@$lref && $email) {
	# Create initial file
	push(@$lref, "#!/bin/sh",
		     "EMAIL=\"$email\"",
		     "REPOS=\"\$1\"",
		     "REV=\"\$2\"",
		     "$module_root_directory/commit-email.pl --from $dom->{'emailto'} -s \"SubVersion commit\" \"\$REPOS\" \"\$REV\" \"\$EMAIL\"");
	&flush_file_lines($pc);
	&set_ownership_permissions($d->{'uid'}, $d->{'gid'}, 0755, $pc);
	}
elsif (@$lref && $email) {
	# Just update email, and comment in program
	foreach my $l (@$lref) {
		if ($l =~ /^\s*EMAIL="(.*)"/) {
			$l = "EMAIL=\"$email\"";
			}
		elsif ($l =~ /^#\S+\/commit-email.pl/) {
			$l =~ s/^#//;
			}
		}
	&flush_file_lines($pc);
	}
elsif (@$lref && !$email) {
	# Comment out the program
	foreach my $l (@$lref) {
		if ($l =~ /^\S+\/commit-email.pl.*\$EMAIL/ && $l !~ /^\#/) {
			$l = "#$l";
			}
		}
	&flush_file_lines($pc);
	}
}

1;

