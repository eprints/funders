#!/usr/bin/perl -I/opt/eprints3/perl_lib

use EPrints;
use strict;

my $repo = EPrints->new->repository( $ARGV[0] );
die "Usage: $0 [repoid]\n" if !defined $repo;

# sf2 - on EPrints Soton we have "grant_number" (multiple), "funder" (multiple) as free-form text - we need to match them
# to the Project/Funder values (on the separate dataset that is) and fill in eprint.funders and eprint.projects (both
# dataobjref).

$repo->dataset( 'eprint' )->search()->map( sub {

	my( $eprint ) = $_[2];

	return if( !$eprint->is_set( 'grant_number' ) );
		
	my @cur_projects = @{ $eprint->value( 'projects' ) || [] };
	my %cur_project_ids = map { $_->{id} => 1 } @cur_projects;
			
	my $notes = $eprint->is_set( 'projects_import_note' ) ? $eprint->value( 'projects_import_note' )."\n" : "";

	my $done_any = 0;

	foreach my $gn ( @{ $eprint->value( 'grant_number' ) || [] } )
	{
		next if( !EPrints::Utils::is_set( $gn ) );

		my( $project ) = EPrints::DataObj::Project::project_by_grant( $repo, $gn );

		if( defined $project )
		{
		 	next if( $cur_project_ids{$project->id} );

			my $new_project = { id => $project->id };
			$new_project->{title} = $project->value( 'title' ) if( $project->is_set( 'title' ) );

			push @cur_projects, $new_project;
			$done_any++;

			$notes .= "Project imported from grant: $gn\n";

			$repo->log( "Mapped project #".$project->id." ".$project->value( 'title' )." via grant '$gn' on eprint ".$eprint->id );

		}
		else
		{

			$notes .= "Failed to map grant: $gn\n";

			# also a former field
			if( $eprint->is_set( 'funder' ) )
			{
				$notes .= "Funder: $_\n" for( @{$eprint->value( 'funder' )||[]} );
			}
		}
	}

	$eprint->set_value( 'projects', \@cur_projects ) if( $done_any );
	$eprint->set_value( 'projects_import_note', $notes );

	$eprint->commit;
} );

