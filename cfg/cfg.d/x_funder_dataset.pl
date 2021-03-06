#
# Funder Dataset
#

# dataset
$c->{datasets}->{funder} = {
 	class => "EPrints::DataObj::Funder",
 	sqlname => "funder",
 	datestamp => "datestamp",
	index => 1,
};

# fields
for(
 	{
		# internal ID
 		name => "funderid",
 		type => "counter",
 		sql_counter => "funderid",
 	},
	{
		# user who created the Funder object
		name => "userid",
		type => "itemref",
		datasetid => "user",
	},
 	{
		# creation date
 		name => "datestamp",
 		type => "time",
 	},
 	{
		# the literal name of the funder (NERC)
 		name => "name",
 		type => "text",
 	},
	{
		# alternative names/spellings (full name etc)
		name => "alt_name",
		type => "text",
		multiple => 1,
		show_in_fieldlist => 0,
	},
	{
		# index for alternative names for sorting funders
		name => "alt_name_index",
		type => "text",
		show_in_html => 0,
	},
	{
                # To provide a search field to search on main and alternate funder names
                name => "all_names",
                type => "text",
                multiple => 1,
                show_in_fieldlist => 0,
		show_in_html => 0,
        },
	{
		# source of the import (gtr etc)
		name => "source",
		type => "url",
	},
	{
		# other identifiers (eg. GtR Unique ID)
		name => "identifier",
		type => "id",
		multiple => 1,
		show_in_fieldlist => 0,
	},
	{
		# index for identifiers for sorting funders
		name => "identifier_index",
                type => "text",
		show_in_html => 0,
	},
	{
		name => "database",
		type => "id",
	},
	{
		# private, governmental 
		name => "type",
		type => "set",
		options => [qw( pri gov )],
	},
	{
		name => "sub_type",
		type => "set",
		options => [qw( rcuk eu other )],
		default_value => 'other'
	},
	{
		name => "open_access_policy",
		type => "url",
	},
	{
		name => "parents",
		type => "id",
		multiple => 1,
		show_in_fieldlist => 0,
	},
	{
		# index for parents for sorting funders
		name => "parents_index",
                type => "text",
		show_in_html => 0,
	},
	{
		# the geoname code (i.e a country) - from Fundref
		name => "geoname",
		type => "url",
	},
	{
		# similar as above for the state/county
		name => "geoname_state",
		type => "url",
	},
	{
		# sf2 - FYI the list of country codes and associated phrases were automatically generated from Geonames.org's data
		name => "country",
		type => "namedset",
		set_name => "country_code",
	},
	{
		# internal id - as used on institution internal databases
		name => 'int_funder_code',
		type => 'id',
	}
)
{
	$c->add_dataset_field('funder', $_, reuse => 1);
}


# class
{
	package EPrints::DataObj::Funder;

	our @ISA = qw( EPrints::DataObj );

	sub funder_with_name
	{
		my ($repo, $name) = @_;

		return $repo->dataset('funder')->search(filters => [
			{ meta_fields => [qw( name )], value => $name, match => 'EX' }
		])->item(0);
	}

	sub get_system_field_info
	{
		my( $class ) = @_;

		return ();
	}

	sub get_dataset_id { 'funder' }

	sub has_owner
	{
		my ($self, $user) = @_;

		return $self->is_set('userid') && $self->value('userid') eq $user->id;
	}
} ### end of package ###


# user roles
push @{$c->{user_roles}->{user}}, qw{
	+funder/export
};

push @{$c->{user_roles}->{admin}}, qw{
        +funder/create
        +funder/details
        +funder/edit
        +funder/view
        +funder/destroy
        +funder/export
};

# back reference to a Funder
$c->add_dataset_field( 'eprint',
        {
                name => "funders",
                type=>"dataobjref",
                datasetid=>"funder",
		multiple => 1,
                fields => [
                        { sub_name => 'name', type => "text" },
                ],
        },
        reuse => 1
);

# So old funder values can be retained and used within the web interfaces
$c->add_dataset_field( 'eprint', { 'name' => 'all_funder_names', 'type' => 'text', 'multiple' => 1, 'input_boxes' => 1, } );

# So old funder values can be retained and used within the web interfaces
$c->add_dataset_field( 'eprint', { 'name' => 'historical_funders', 'type' => 'text', 'multiple' => 1, 'input_boxes' => 1, } );

# fields to search on the UI
$c->{datasets}->{funder}->{search}->{dataobjref} = {
                search_fields => [{
                        id => "q",
                        meta_fields => [qw/ name alt_name /],
                        match => "IN",
                }],
                show_zero_results => 1,
                order_methods => {
                        byid => "funderid",
                },
                default_order => "byid",
};

$c->add_dataset_trigger( "funder", EP_TRIGGER_AFTER_COMMIT, sub {

        my( %f ) = @_;

        # Only run if funder has changed
        return if !defined $f{changed} || !$f{changed} || !$f{changed}->{name};

        my $funder = $f{dataobj};
        my $dataset = $f{repository}->dataset( 'eprint' );

        # Find EPrints associated with a particular funder.  
        # This could get big and it would be good if it could be backgrounded.
        my $search = $dataset->prepare_search();
        $search->add_field(
                fields => [
                        $dataset->field( 'funders_id' )
                ],
                value => $funder->value( 'funderid' ),
                match => "EQ",
        );
        my $eprints = $search->perform_search();
	my $funder_dataset = $f{repository}->dataset( 'funder' );
	
	$eprints->map( sub {
                my $eprint = $_[2] or return;
		my @funders = @{ $eprint->value( 'funders' ) || [] };
                my @all_funder_names;
		my @funders_names;
                foreach my $a_funder (@funders)
                {
                        my $funder = $funder_dataset->dataobj($a_funder->{id});
                        foreach my $funder_name ( @{$funder->value( 'all_names' )} )
                        {
                                push ( @all_funder_names, $funder_name );
                        }
			push @funders_names, $funder->value( 'name' );
                }
		$eprint->set_value( "funders_names", \@funders_names );
                $eprint->set_value( "all_funder_names", \@all_funder_names );
           	$eprint->commit();
               	# Regenerate abstract page
               	$eprint->generate_static();
	});
} );

$c->add_dataset_trigger( "funder", EP_TRIGGER_BEFORE_COMMIT, sub {
	my( %f ) = @_;

        my $funder = $f{dataobj};

        # Generate alt_name_index for record table ordering
	$funder->set_value('alt_name_index', $funder->render_value('alt_name')->toString());

	# Generate identifier_index for record table ordering
        $funder->set_value('identifier_index', $funder->render_value('identifier')->toString());

	# Generate parents_index for record table ordering
        $funder->set_value('parents_index', $funder->render_value('parents')->toString());

	# Merge main and alternate funders names into single field for searching
	my @all_names;	
	push @all_names, $funder->get_value('name');
	foreach my $alt_name ( @{$funder->get_value('alt_name')} ) 
	{
		push @all_names, $alt_name;
	}
	$funder->set_value( "all_names", \@all_names );
} );
