#!/usr/bin/perl -I/opt/eprints3/perl_lib

# EPrints Services/drn
#
# Reading AAM data importer
#
# which data to import may be specified in cfg.d/x_aam.pl
#


use EPrints;
use LWP::UserAgent;
use URI;
use Getopt::Long;
use Text::CSV;

use Data::Dumper;

my $repo = EPrints->new->repository( $ARGV[0] );
my $file = $ARGV[1];
die "Usage: $0 [repoid] [aam_csv_file]\n" if !defined $repo || !defined $file;

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

my $repo = EPrints->new->repository( $ARGV[0] );
my $file = $ARGV[1];
die "Usage: $0 [repoid] [aam_csv_file]\n" if !defined $repo || !defined $file;

die( "AAM CSV file does not exist" ) if( ! -f $file );

# How to transform an AAM Project data structure into an EPrints one
my $project_to_epdata = $repo->config( 'aam', 'project_to_epdata' ) or die( "missing config aam project_to_epdata" );
my @projects = parse_aam_csv( $file );

my $ua = LWP::UserAgent->new();

print "<?xml version='1.0'?>\n<projects>\n" if $opt{xml};

foreach my $project ( @projects )
{
	&import_record( $project );
}

print "</projects>\n" if $opt{xml};

sub parse_aam_csv 
{
	my ( $file ) = @_;

	open(my $data, "<:encoding(utf8)", $file) or die "Could not open '$file' $!\n";
	my $csv = Text::CSV->new({ sep_char => ',' });
	
	my $line = <$data>;
	chomp $line;
	my @fieldnames;
	if ($csv->parse($line))
	{
        	@fieldnames = $csv->fields();
	}

	my @rows;
	while ($line = <$data>)
	{
        	chomp $line;
       	 	if ($csv->parse($line)) 
		{
                	my @fields = $csv->fields();
                	my %namedfields;
                	my $f = 0;
                	foreach my $field (@fields)
                	{
                        	$namedfields{$fieldnames[$f++]} = $field;
                	}
                	push @rows, \%namedfields;
        	}
        	else 
		{
                	warn "Line could not be parsed: $line\n";
			warn "Error: ".$csv->error_diag()."\n";
        	}
	}
	return @rows;
}

sub import_record
{
	my ( $project ) = @_;

	my $epdata = &$project_to_epdata($repo, $project);

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
			{ meta_fields => [qw( grant )], value => $epdata->{grant} }
		]
	)->item(0);

	if (defined $dataobj) {
		my @project_contributors = $epdata->{contributors}[0];
		foreach my $existing_contributor ( @{$dataobj->get_value('contributors')} ) 
		{
			push @project_contributors, $existing_contributor;
		}
		$epdata->{contributors} = \@project_contributors;
		my $existing_project_title =  $dataobj->get_value('title');
		if ( ! $epdata->{title} eq $existing_project_title ) 
		{
			warn "Existing project name '$existing_project_title' does not match AAM project name '".$epdata->{title}."'\n";
		}
		$dataobj->update($epdata);
		$dataobj->commit;
		print "Updated project #" . $dataobj->id . "\n";
	}
	else {
		$dataobj = $dataset->create_dataobj($epdata);
		$dataobj->commit; # ensure triggers are run
		print "Imported project #" . $dataobj->id . "\n";
	}
}


