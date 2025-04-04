# EPrints Services/sf2
# 
# Gateway to Research plug-in
#
# Allows to import Project, Grant, Funder data from GtR
#

use Data::Dumper;

$c->{gtr} = {

	'url' => 'http://gtr.rcuk.ac.uk/',
	
};

$c->{gtr}->{project_to_epdata} = sub
{
	my ($repo, $projectcomp) = @_;

	my $project = $projectcomp->{project};

	my $epdata = {
		datestamp => EPrints::Time::get_iso_timestamp(),
		title => $project->{title},
		funders_name => [$project->{fund}->{funder}->{name}],
		date_start => $project->{fund}->{start},
		date_end => $project->{fund}->{end},
		amount => $project->{fund}->{valuePounds},
		currency_amount_currency => "gbp",
		currency_amount_major => $project->{fund}->{valuePounds},
		currency_amount_minor => 0,
		database => 'http://gtr.rcuk.ac.uk/',
		source => URI->new($project->{url})->canonical->as_string,
	};

	# old/new Grant ID scheme

	my $grantid = $project->{grantReference};
	my %alt_grantids = ();

	my $ids = $project->{identifier};
	if( scalar( @{ $ids || [] } ) > 1 )
	{
		foreach( @$ids )
		{
			my( $type, $value ) = ( $_->{type}, $_->{value} );
			next if( !(defined $type && defined $value ) );

			if( $type eq 'RES' )
			{
				# keep this as the main Grant ID - as expected by ROS
				if( defined $grantid && $value ne $grantid )
				{
					$alt_grantids{$grantid} = 1;
					$grantid = $value;
				}
				elsif( !defined $grantid )
				{
					$grantid = $value;
				}
			}
			else
			{
				# probably 'RCUK'
				if( $grantid ne $value )
				{
					$alt_grantids{$value} = 1;
				}
			}
		}

		$epdata->{grant} = $grantid;
		$epdata->{alt_grants} = [ keys %alt_grantids ];

		# EPrints->dump( $epdata );
	}

	$epdata->{grant} ||= $grantid;

	if ($project->{fund}{funder})
	{
		my $dataset = $repo->dataset('funder');
		my $funder;

		# Find funder by ID 
		if (my $id = $project->{fund}{funder}{id})
		{
			$funder = $dataset->search(filters => [
				{ meta_fields => [qw( identifier )], value => $id, },
			])->item(0);
		}
		
		# import funder if does not exist... perhaps importing funder from GtR could be a config option
		if( !$funder )
		{
			my $funder_name = $project->{fund}{funder}{name};
			$repo->log( "Importing missing funder '$funder_name'..." );

			$funder = $dataset->create_dataobj( {
				name => $funder_name,
				identifier =>  [$project->{fund}{funder}{id}],
				database => 'http://gtr.rcuk.ac.uk/',
				source => URI->new($project->{fund}{funder}{url})->canonical->as_string,
				datestamp => EPrints::Time::get_iso_timestamp(),
				type => 'gov',	# only public/gov stuff on GtR?	
			} );

		}

		if ($funder)
		{
			$epdata->{funders} = [{
				name => $project->{fund}{funder}{name},
				id => $funder->id,
			}];
		}

		my @all_names;
                push @all_names, $funder->get_value('name');
                foreach my $alt_name ( @{$funder->get_value('alt_name')} )
                {
                        push @all_names, $alt_name;
                }
                $funder->set_value( "all_names", \@all_names );
	}

	my @people;
	foreach my $person ( @{ $projectcomp->{personRole} || [] } )
	{
		my($family, $given);
		if ($person->{surname})
		{
			($family, $given) = @$person{qw( surname firstName )};
			$given .= " ".$person->{otherNames} if $person->{otherNames};
		}
		else
		{
			($family, $given) = reverse split /\s+/, $person->{name}, 2;
		}
		push @people, {
			name => {
				family => $family,
				given => $given,
			},
			role => $person->{role}->[0]->{name},
			id => URI->new($person->{url})->canonical->as_string,
		};
	}

	$epdata->{contributors} = \@people;

	return $epdata;
};

$c->{gtr}->{merge_with_local} = sub
{
        my ($repo) = @_;

	my $projects = $repo->dataset( "project" );

	my $gtr_search = $projects->prepare_search();
	$gtr_search->add_field(
		fields => [
			$projects->field('database')
		],
		value => "http://gtr.rcuk.ac.uk/", #$repo->config( 'gtr', 'url' ),
		match => "EQ",
	);
	my @gtr_projects = $gtr_search->perform_search->get_records();
	print "Number of GtR projects: ". scalar @gtr_projects."\n";

	my $local_search = $projects->prepare_search();
	$local_search->add_field(
		fields => [
			$projects->field('database')
		],
		value => $repo->config( 'gtr', 'local_sources'),
		match => "IN",
	);
	my @local_projects = $local_search->perform_search->get_records();
	print "Number of local projects: ". scalar @local_projects."\n";

	my %local_grants = ();
	for(@local_projects)
	{
	#	print "local project: ".Dumper(%{$_})."\n";
		$local_grants{$_->{grant}} = $_;
	}
	for(@gtr_projects)
	{
		if (defined($local_grants{$_->{grant}}))
		{
			print "Local project for: ".$_->{grant}."\n";
		}
		else
		{
			print "No local project for: ".$_->{grant}."\n";
		}
	}
}
