use strict;
use warnings;
our $module_name;

do 'virtualmin-svn-lib.pl';

sub cgi_args
{
my ($cgi) = @_;
my ($d) = grep { &virtual_server::can_edit_domain($_) &&
	         $_->{$module_name} } &virtual_server::list_domains();
if ($cgi =~ /^edit_(dump|email|load).cgi$/) {
	return 'none' if (!$d);
	my @reps = &list_reps($d);
	return 'none' if (!@reps);
	return 'dom='.$d->{'id'}.'&rep='.&urlize($reps[0]->{'rep'});
	}
elsif ($cgi eq 'index.cgi') {
	return $d ? 'show='.&urlize($d->{'dom'}) : '';
	}
return undef;
}
