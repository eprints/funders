#!/usr/bin/perl

use FindBin;
use lib "$FindBin::Bin/../../../../perl_lib";

use EPrints;
use LWP::UserAgent;
use Getopt::Long;
use File::Temp;
use strict;

our $XSLT = "$FindBin::Bin/fundref2epxml.xsl";
our $SOURCE = 'http://dx.doi.org/10.13039/fundref_registry';

use encoding 'utf8';

my %opt = (
);
GetOptions(\%opt,
	'xml',
) or die;

my $repo = EPrints->new->repository( $ARGV[0] );
die "Usage: $0 [options] <repoid> [source]\n" if !defined $repo;

my $dataset = $repo->dataset('funder');

my $ua = LWP::UserAgent->new;
$ua->from($repo->config('adminemail'));

my $tmpdir = File::Temp->newdir;

my $r = $ua->get(($ARGV[1] || $SOURCE),
	':content_file' => "$tmpdir/fundref.xml",
);
die $r->status_line if !$r->is_success;

open(my $fh, "-|", 'xsltproc', $XSLT, "$tmpdir/fundref.xml");

my $handler = EPrints::CLIProcessor->new(
	epdata_to_dataobj => \&epdata_to_dataobj,
);

my $plugin = $repo->plugin('Import::XML',
	Handler => $handler,
);
print "<?xml version='1.0'?>\n<funders>\n" if $opt{xml};
$plugin->input_fh(
	fh => $fh,
	dataset => $dataset,
);

print "</funders>\n" if $opt{xml};

sub epdata_to_dataobj
{
	my ($epdata) = @_;

	my $dataobj;
	if (!defined $dataobj && $epdata->{source})
	{
		$dataobj = $dataset->search(filters => [
			{ meta_fields => [qw( source )], value => $epdata->{source}, }
		])->item(0);
	}
	if (!defined $dataobj && $epdata->{name})
	{
		$dataobj = $dataset->search(filters => [
			{ meta_fields => [qw( name )], value => $epdata->{name}, match => 'EX', }
		])->item(0);
	}

	if (defined $dataobj)
	{
		$dataobj->update($epdata);
	}
	elsif ($opt{xml} || $opt{dump})
	{
		$dataobj = $dataset->make_dataobj($epdata);
	}
	else
	{
		$dataobj = $dataset->create_dataobj($epdata);
		my @all_names;
                push @all_names, $dataobj->get_value('name');
                foreach my $alt_name ( @{$dataobj->get_value('alt_name')} )
                {
                        push @all_names, $alt_name;
                }
                $dataobj->set_value( "all_names", \@all_names );

	}

	if ($opt{xml})
	{
		print $repo->xml->to_string($dataobj->to_xml, indent => 1);
	}
	elsif ($opt{dump})
	{
		EPrints->dump($dataobj->get_data);
	}
	else
	{
		$dataobj->commit;
		print $dataobj->id;
	}
	print "\n";

	return $dataobj->id ? $dataobj : undef;
}
