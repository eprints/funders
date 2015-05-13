#
# Funder Dataset
#

# dataset
$c->{datasets}->{funder} = {
 	class => "EPrints::DataObj::Funder",
 	sqlname => "funder",
 	datestamp => "datestamp",
	index => 1,
	order => 1,
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
                        { sub_name => 'name', type => 'text' }
                ],
        },
        reuse => 1
);

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


$c->add_dataset_trigger( "funder", EP_TRIGGER_BEFORE_COMMIT, sub {
	my( %p ) = @_;

        my $changed = $p{changed};
        my $dataobj = $p{dataobj};


        # Generate alt_name_index for record table ordering
        if( $changed->{alt_name} )
	{
		$dataobj->set_value('alt_name_index', $dataobj->render_value('alt_name')->toString());
	}

	# Generate identifier_index for record table ordering
        if( $changed->{identifier} )
        {
                $dataobj->set_value('identifier_index', $dataobj->render_value('identifier')->toString());
        }

	# Generate parents_index for record table ordering
        if( $changed->{parents} )
        {
                $dataobj->set_value('parents_index', $dataobj->render_value('parents')->toString());
        }
} );


