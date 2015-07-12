# EPrints Services/drn
# 
# Reading AAM plug-in
#
# Allows to import Project information from Reading AAM to be imported
#

use Data::Dumper;

$c->{aam}->{primary_funder_database} = "http://www.crossref.org/fundref/";

$c->{aam}->{honorifics} = \( 'dr', 'miss', 'mr', 'mrs', 'ms', 'prof' );

$c->{aam}->{funder_mappings} = {};

$c->{aam}->{project_to_epdata} = sub
{
	my ($repo, $project) = @_;

	my $start_date = $project->{"Actual Start Date"};
	$start_date =~ s/([0-9]{2})\/([0-9]{2})\/([0-9]{4})/$3-$2-$1/;
	my $end_date = $project->{"Actual End Date"};
        $end_date =~ s/([0-9]{2})\/([0-9]{2})\/([0-9]{4})/$3-$2-$1/;
        my $amount = $project->{"Total Awarded Value"};
        $amount =~ s/[£,]//g;
        my @amountbits = split('\.', $amount);
        $amountbits[1] = 0 if ! defined $amountbits[1];
	my $grant = $project->{"External Reference"};
	if ($grant eq "")
	{
		$grant = $project->{"Project Code"};
	}
        my $epdata = {
		datestamp => EPrints::Time::get_iso_timestamp(),
                title => $project->{"Project Title"},
		grant => $grant,
		int_project_code => $project->{"Project Code"},
		date_start => $start_date,
		date_end => $end_date,
                amount => $amount,
                currency_amount_currency => "gbp",
                currency_amount_major => $amountbits[0],
                currency_amount_minor => $amountbits[1],
                database => $c->{aam}->{'data-source-id'},
		source => $project->{"File Reference"}
        };

	if (defined $project->{"First Funder Name"} && length $project->{"First Funder Name"} > 0)
	{
		my $funder_name = $project->{"First Funder Name"};
		$epdata->{funder_name} = [$funder_name];
		my $dataset = $repo->dataset('funder');
		my $funder;

		# Find funder by name
		my $old_funder_name = "UNSET";
		if ( defined $c->{aam}->{funder_mappings}{$funder_name} ) 
		{
			$old_funder_name = $funder_name;
			$funder_name = $c->{aam}->{funder_mappings}{$funder_name};
		}
		$funder = $dataset->search(filters => [
			{ meta_fields => [qw( all_names )], value => $funder_name, },
			{ meta_fields => [qw( database )], value => $c->{aam}->{primary_funder_database}, },
		])->item(0);

		if( !defined $funder )
                {
			warn "Could not find funder '$funder_name' under ".$c->{aam}->{primary_funder_database}." for project '".$project->{"Project Title"}."'\n";
			$funder = $dataset->search(filters => [
	                       { meta_fields => [qw( all_names )], value => $funder_name, },
                	])->item(0);
		}

		if( !defined $funder )
		{
			warn "Could not find funder '$funder_name' at all for project '".$project->{"Project Title"}."'\n";
		}
		else
		{
			$epdata->{funders} = [{
				name => $funder_name,
				all_names => [ $funder_name ],
				id => $funder->id,
			}];
		}
	}
	else
	{
		warn "No funder name for project '".$project->{"Project Title"}."'\n";
	}

	my @ll_name_bits = split(" ",$project->{"P.I. Name"});
	my ($family, $given, $honorific) = undef;
	if (scalar @ll_name_bits > 2 )
	{
		warn "Local lead name '".$project->{'P.I. Name'}."' may have not have been accurately added to project '".$project->{'Project Title'}."'.\n";
		my $lc_middle = lc($ll_name_bits[1]);
		if ( grep /$lc_middle/ , \$c->{aam}->{honorifics} )
		{
			$honorific = $ll_name_bits[1];
			$given = $ll_name_bits[2];
			$family = $ll_name_bits[0];
		}
		else
		{
			$family = $ll_name_bits[0] . " " . $ll_name_bits[1];
			$given = $ll_name_bits[2];
		}
	}
	elsif (scalar @ll_name_bits < 2 )
	{
		warn "Local lead name '".$project->{'P.I. Name'}."' may have not have been accurately added to project '".$project->{'Project Title'}."'.\n";
		$family = $ll_name_bits[0];
	}
	else
	{
		$given = $ll_name_bits[1];
                $family = $ll_name_bits[0];
	}
		
	my $local_lead = {
		name => {
                	family => $family,
                        given => $given,
			honourific => $honorific, # Seem EPrints spells honorific with a u
                },
                role => "LOCAL_LEAD_INVESTIGATOR",
                id => $project->{"P.I. Code"},
	};

	$epdata->{contributors} = [$local_lead];

	return $epdata;
};
