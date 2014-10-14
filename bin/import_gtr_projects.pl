#!/usr/bin/perl -I/opt/eprints3/perl_lib

# EPrints Services/sf2
#
# Gateway to Research data importer
#
# which data to import may be specified in cfg.d/x_gtr.pl
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
die "Usage: $0 [repoid]\n" if !defined $repo;

# GtR site URL
my $gtr_url = $repo->config( 'gtr', 'url' ) or die( "missing config gtr url" );

# Which organisation's data to import
my @gtr_orgs = @{ $repo->config( 'gtr', 'data-import' ) || [] };

die( "No data to import" ) if( !scalar( @gtr_orgs ) );
	
# How to transform a GtR Project data structure into an EPrints one
my $project_to_epdata = $repo->config( 'gtr', 'project_to_epdata' ) or die( "missing config gtr project_to_epdata" );

my $ua = LWP::UserAgent->new();

print "<?xml version='1.0'?>\n<projects>\n" if $opt{xml};

foreach my $gtr_org_id ( @gtr_orgs )
{
	&import_from_gtr( $gtr_org_id );
}

print "</projects>\n" if $opt{xml};

exit;



sub import_from_gtr
{
	my( $gtr_org_id ) = @_;

	my $project_url = $gtr_url."/organisation/$gtr_org_id.json";

	my $total_pages;
	my $page = 1;

	do {
		warn "GET $project_url?page=$page\n" if $noise > 1;

		my $r = $ua->get( $project_url."?page=$page" );

		if( $r->is_error )
		{
			die( $r->content );
		}

		if( !defined $total_pages )
		{
			$total_pages = $r->header( 'Link-Pages' );
		}

		if( !defined $total_pages )
		{
			print STDERR "Failed to find the number of pages... no records?\n";
			last;
		}

		$page++;

		my $json = JSON->new->utf8(1)->decode( $r->content );

		foreach my $result (@{$json->{organisationOverview}{projectSearchResult}{results}||[]})
		{
			&import_record( $result->{projectComposition} );
		}

	} while( $page < $total_pages );
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

	if ($opt{xml})
	{
		my $dataobj = $dataset->make_dataobj($epdata);
		print $dataobj->to_xml->toString(1);
		print "\n";
		return;
	}

	my $dataobj = $dataset->search(
		filters => [
			{ meta_fields => [qw( source )], value => $epdata->{source} }
		]
	)->item(0);

	if (defined $dataobj) {
		$dataobj->update($epdata);
		$dataobj->commit;
		print "Updated project #" . $dataobj->id . "\n";
	}
	else {
		$dataobj = $dataset->create_dataobj($epdata);
		print "Imported project #" . $dataobj->id . "\n";
	}

}


