#!/usr/bin/perl -I/opt/eprints3/perl_lib

use EPrints;
use strict;

use Data::Dumper;

my $repo = EPrints->new->repository( $ARGV[0] );
die "Usage: $0 [repoid]\n" if !defined $repo;

# need to check they haven't been imported yet?

my %RCUK = (
        "AHRC" => { 
		alt_name => ["Arts and Humanities Research Council"], 
		database => 'http://gtr.rcuk.ac.uk/',
		type => 'gov',
		datestamp => EPrints::Time::get_iso_timestamp(),
		identifier => ['1291772D-DFCE-493A-AEE7-24F7EEAFE0E9'],
		funderid => 9,
	},
        "BBSRC" => { 
		alt_name => ["Biotechnology and Biological Sciences Research Council"], 
		database => 'http://gtr.rcuk.ac.uk/',
		type => 'gov',
		datestamp => EPrints::Time::get_iso_timestamp(),
		identifier => ['2512EF1C-401B-4222-9869-A770D4C5FAC7'],
		funderid => 2,
	},
        "EPSRC" => { 
		alt_name => ["Engineering and Physical Sciences Research Council"],
		database => 'http://gtr.rcuk.ac.uk/',
		type => 'gov',
		datestamp => EPrints::Time::get_iso_timestamp(),
		identifier => ['798CB33D-C79E-4578-83F2-72606407192C'],
		funderid => 4,
	},
        "ESRC" => { 
		alt_name => ["Economic and Social Research Council"],
		database => 'http://gtr.rcuk.ac.uk/',
		type => 'gov',
		datestamp => EPrints::Time::get_iso_timestamp(),
		identifier => ['924BE15C-91F2-4AAD-941A-3F338324B6AE'],
		funderid => 5,
	},
        "MRC" => { 
		alt_name => ["Medical Research Council"],
		database => 'http://gtr.rcuk.ac.uk/',
		type => 'gov',
		datestamp => EPrints::Time::get_iso_timestamp(),
		identifier => ['C008C651-F5B0-4859-A334-5F574AB6B57C'],
	},
        "NERC" => { 
		alt_name => ["Natural Environment Research Council"],
		database => 'http://gtr.rcuk.ac.uk/',
		type => 'gov',
		datestamp => EPrints::Time::get_iso_timestamp(),
		identifier => ['8A03ED41-E67D-4F4A-B5DD-AAFB272B6471'],
		funderid => 8,
	},
        "STFC" => { 
		alt_name => ["Science and Technology Facilities Council"],
		database => 'http://gtr.rcuk.ac.uk/',
		type => 'gov',
		datestamp => EPrints::Time::get_iso_timestamp(),
		identifier => ['D7F4F462-0518-4784-908A-D12633C139B3'],
		funderid => 6,
	},
);

foreach my $name ( keys %RCUK )
{
	#my( $funder ) = &funder_exists( $RCUK{$name}->{identifier} ); 
	
	my $funder = $repo->dataset( 'funder' )->dataobj( delete $RCUK{$name}->{funderid} );

	my $epdata = $RCUK{$name};
	$epdata->{name} = $name;
                     
	my $action;
	if( $funder )
	{
		foreach(keys %$epdata)
		{
			$funder->set_value( $_, $epdata->{$_} );
		}
		$action = 'updated';
	}
	else
	{
		$funder = $repo->dataset('funder')->create_dataobj( $epdata );
		$action = 'created';
	}

	my @all_names;
        push @all_names, $funder->get_value('name');
        foreach my $alt_name ( @{$funder->get_value('alt_name')} )
        {
                push @all_names, $alt_name;
        }
        $funder->set_value( "all_names", \@all_names );
	$funder->commit;	

	$repo->log( "$action funder #".$funder->id. "(".$funder->value( 'name' ).")" );
}

exit;

sub funder_exists
{
	my( $identifier ) = @_;

	return $repo->dataset( 'funder' )->search( identifier => $identifier )->slice(0,1);
}


