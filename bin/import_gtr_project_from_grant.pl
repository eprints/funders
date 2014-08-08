#!/usr/bin/perl -I/opt/eprints/eprints3/perl_lib

# EPrints Services/sf2
#
# Gateway to Research data importer from a Grant ID
#


use EPrints;
use JSON;
use LWP::UserAgent;
use URI;
use Getopt::Long;
use strict;

use encoding 'utf8';

my %opt = (
	verbose => 1,
	quiet => 0,
);
GetOptions(\%opt,
	'xml',
	'verbose+',
	'quiet+',
) or die;

my $noise = $opt{verbose} - $opt{quiet};

my $repo = EPrints->new->repository( $ARGV[0], noise => $noise );
die "Usage: $0 repoid\n" if !defined $repo;

# GtR site URL
my $gtr_url = $repo->config( 'gtr', 'url' ) or die( "missing config gtr url" );

my $ua = LWP::UserAgent->new();
my $project_to_epdata = $repo->config( 'gtr', 'project_to_epdata' ) or die( "missing config gtr project_to_epdata" );

$repo->dataset( 'archive' )->search( 
	filters => [ {meta_fields => [qw/ grant_number /], match => 'SET' } ]

)->map( sub {

	my $eprint = $_[2] or return;

	my @cur_projects = @{ $eprint->value( 'projects' ) || [] };
	my %current_project_ids = map { $_ => 1 } grep { defined $_->{id} } @cur_projects;

	my $notes = "";

	my $added = 0;
	my $failed = 0;
	foreach my $value ( @{ $eprint->value( 'grant_number' ) || [] } )
	{
		# split by , and ; and remove trailing/leading white space
		my @grantids = split( /[,;]/, $value );

		foreach my $grantid ( @grantids )
		{
			$grantid =~ s/^\s+//g;
			$grantid =~ s/\s+$//g;
			next if( !EPrints::Utils::is_set( $grantid ) );

			# returns a projectid if it exists in the local DB (whether it existed already or whether it was imported from GtR on-the-fly)
			my $project = &search_gtr_by_grantid( $grantid );

			# push @new_projects, $projectid if( defined $projectid );
			if( defined $project )
			{
				if( !$current_project_ids{$project->id} )
				{
					my $new_project = { id => $project->id };
					$new_project->{title} = $project->value( 'title' ) if( $project->is_set( 'title' ) );
					push @cur_projects, $new_project;
					$added++;
				
					$notes .= "Project imported from grant: $grantid\n";
				}
			}
			else
			{
				$failed++;

                        	$notes .= "Failed to map grant: $grantid\n";

			}
		}
	}
	
	if( $failed )
	{                        
		# also a former field
		if( $eprint->is_set( 'funder' ) )
		{
			$notes .= "Funder: $_\n" for( @{$eprint->value( 'funder' )||[]} );
		}
	}

	if( $failed || $added )
	{
		# to help editors as to tell when what happened
		$eprint->set_value( 'projects_import_note', $notes );
	}

	if( $added )
	{
		$eprint->set_value( 'projects', \@cur_projects );
		$eprint->commit;
	}
} );


exit;


sub search_gtr_by_grantid
{
	my( $grantid ) = @_;

	# exists locally maybe?
	my $list = $repo->dataset( 'project' )->search( filters => [ {meta_fields => [qw/ grant / ], value => $grantid, match => 'EX' } ] );
	if( $list->count == 1 )
	{
		print "Found local match for '$grantid'\n";
		my( $match ) = $list->slice( 0, 1 );
		return $match if( defined $match );
	}
	elsif( $list->count > 1 )
	{
		print "Odd multiple local matches for '$grantid'\n";
		return undef;
	}
	
	# attempt to import the project from GtR
	my $search_url = $gtr_url."/search/project.json?fetchSize=25&selectedSortableField=&selectedSortOrder=&fields=pro.id&term=$grantid";

	my $total_pages;

	print "Searching for '$grantid'\t";

	my $r = $ua->get( $search_url );

	if( $r->is_error )
	{
		if( $r->code == 404 )
		{
			print "No results\n";
		}
		else
		{
			print "Request error: ".$r->status_line."\n";
		}
		return;
	}

	my $json = JSON->new->utf8(1)->decode( $r->content );

	my $results = 0;
	foreach( @{ $json->{resourceHitCount} || [] } )
	{
		next if( $_->{resource} ne 'project' );
		$results = $_->{count};
		last;
	}

	if( "$results" eq "1" )
	{
		# hoo hoo we can import that then...

		return &import_record( $json->{results}->[0]->{projectComposition} );
	}

	return undef;
}


sub import_record
{
	my ( $projectcomp ) = @_;

	my $url = $projectcomp->{project}{url};

	$url .= ".json" unless( $url =~ /\.json$/ );

	warn "GET $url\n" if $noise > 1;

	my $r = $ua->get($url);

	my $json = JSON->new->utf8(1)->decode($r->content);

	my $epdata = &$project_to_epdata($repo, $json->{projectComposition});

	my $dataset = $repo->dataset( 'project' );

	my $dataobj = $dataset->search(
		filters => [
			{ meta_fields => [qw( source )], value => $epdata->{source} }
		]
	)->item(0);

	if( !defined $dataobj )
	{
		$dataobj = $dataset->create_dataobj($epdata);
		print "Imported project #" . $dataobj->id . "\n";
	}

	return $dataobj;
}


