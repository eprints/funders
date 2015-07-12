#!/usr/bin/perl -I/opt/eprints3/perl_lib

use EPrints;
use strict;
use Data::Dumper;

my $repo = EPrints->new->repository( $ARGV[0] );
die "Usage: $0 [repoid]\n" if !defined $repo;

my $db = $repo->database();
my $ds = $repo->dataset("eprint");
my $last_eprintid = 0;

my $projects_sql = "SELECT * FROM eprint_projects ORDER BY eprintid";
my $projects_query = $db->prepare_select( $projects_sql );
$db->execute( $projects_query, $projects_sql );
my $eprint_project = $projects_query->fetchrow_hashref;
print "Migrating old projects values to historical_projects";
while( defined $eprint_project->{eprintid} )
{
	my $eprint = $ds->dataobj( $eprint_project->{eprintid} );
	my @eprint_historical_projects = ();
	$last_eprintid = $eprint_project->{eprintid};
	while ( defined $eprint_project->{eprintid} && $eprint_project->{eprintid} == $last_eprintid ) 
	{
		push @eprint_historical_projects, $eprint_project->{projects};
		$eprint_project = $projects_query->fetchrow_hashref;
	}
	$last_eprintid = $eprint_project->{eprintid};
	if ( defined $eprint && scalar @eprint_historical_projects > 0 )
	{
		$eprint->set_value( "historical_projects",  \@eprint_historical_projects );
		$eprint->commit;
		print ".";
	}
}
print "Done!\n";
	 
my $funders_sql = "SELECT * FROM eprint_funders ORDER BY eprintid";
my $funders_query = $db->prepare_select( $funders_sql );
$db->execute( $funders_query, $funders_sql );
my $eprint_funder = $funders_query->fetchrow_hashref;
print "Migrating old funders values to historical_funders";
while( defined $eprint_funder->{eprintid} )
{
        my $eprint = $ds->dataobj( $eprint_funder->{eprintid} );
        my @eprint_historical_funders = ();
        $last_eprintid = $eprint_funder->{eprintid};
        while ( defined $eprint_funder->{eprintid} && $eprint_funder->{eprintid} == $last_eprintid )
        {
                push @eprint_historical_funders, $eprint_funder->{funders};
                $eprint_funder = $funders_query->fetchrow_hashref;
        }
	$last_eprintid = $eprint_funder->{eprintid};
        if ( defined $eprint && scalar @eprint_historical_funders > 0 )
        {
		$eprint->set_value( "historical_funders",  \@eprint_historical_funders );
              	$eprint->commit;
		print ".";
        }
}
print "Done!\n";

