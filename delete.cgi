#!/usr/local/bin/perl
# Delete one repository

require './virtualmin-svn-lib.pl';
&ReadParse();

($repdom) = (keys %in);
($repname, $id) = split(/\@/, $repdom);
$dom = &virtual_server::get_domain($id);
&can_edit_domain($dom) || &error($text{'add_edom'});

@reps = &list_reps($dom);
($rep) = grep { $_->{'rep'} eq $repname } @reps;
$rep || &error($text{'delete_erep'});
&delete_rep($dom, $rep);

&redirect("");

