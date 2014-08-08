#!/usr/bin/perl -w -I/opt/eprints/eprints3/perl_lib

use EPrints;
use strict;

my $repo = EPrints->new->repository( $ARGV[0] );
die "Usage: $0 [repoid]\n" if !defined $repo;

my %grantids;

$repo->dataset( 'project' )->search()->map( sub {

	my $project = $_[2] or return;

	my $gid = $project->value( 'grant' );

	if( !EPrints::Utils::is_set( $gid ) )
	{
		print "Warning project #".$project->id." has no grant ID\n";
		return;
	}

	if( $grantids{$gid} )
	{
		print "Collision for '$gid' - project #".$project->id." is duplicate? of ".$grantids{$gid}."\n";
	}
	else
	{
		$grantids{$gid} = $project->id;
	}

} );


