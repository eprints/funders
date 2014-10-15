# EPrints Services/sf2
# 
# Gateway to Research plug-in
#
# Allows to import Project, Grant, Funder data from GtR
#

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
