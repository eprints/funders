#
# Project Dataset
#

# dataset
$c->{datasets}->{project} = {
 	class => "EPrints::DataObj::Project",
 	sqlname => "project",
 	datestamp => "datestamp",
	index => 1,
};

# fields
for(
 	{
		# internal ID
 		name => "projectid",
 		type => "counter",
 		sql_counter => "projectid",
		import => 0,
 	},
	{
		# user who created the Project object
		name => "userid",
		type => "itemref",
		datasetid => "user",
	},
 	{
		# creation date
 		name => "datestamp",
 		type => "timestamp",
 	},
 	{
		# project title
 		name => "title",
 		type => "text",
 	},
	{
		# the (main) grant id
		name => "grant",
		type => "id",
		text_index => 1
	},
	{
		name => "date_start",
		type => "date",
	},
	{
		name => "date_end",
		type => "date",
	},
	{
		# TODO a general implementation needs amount + currency - cf. APC implementation
		name => "amount",
		type => "int",
		render_value => sub {

			my( $session , $field , $value ) = @_;

			if( !defined $value ) { return $session->make_doc_fragment; }

			my $display = $value || 0;
			return $session->make_text($display) if( $display lt 1000 );

			if( $value =~ /^\d+$/ )
			{
				my $d = $value;
				my $human = "";
				while( $d =~ s/(\d{3})$// )
				{
					$human = ( $d ? ",$1" : "$1" ).$human;
				}

				$human = $d.$human if( $d );
				$display = $human;
			}
			
			my $currency_prefix = "£";
                        my $currency_suffix = "";
                        if ($session->{lang}->has_phrase("currencies_prefix_default")) {
  	                     $currency_prefix = $session->phrase("currencies_prefix_default");
                        }
                        if ($session->{lang}->has_phrase("currencies_suffix_default")) {
                              my $currency_suffix = " (" . $session->phrase("currencies_suffix_default") . ")";
                        }
                        return $session->make_text( "$currency_prefix$display$currency_suffix" );
		},
 
	},
	{
		name => "currency_amount",
		type => "compound",
		fields => [
                        {
				sub_name=>"currency",
			        type=>"namedset", 
				set_name=>"currencies",
				required=>1, 
				input_rows=>1,
                        },
                        {
                                sub_name => 'major',
                                type => 'int',
				input_cols => 8,
			},
			{
				sub_name => 'minor',
                                type => 'int',
				render_input => sub {
					my ( $self, $session, $value, $dataset, $staff, $hidden_fields, $obj, $basename )  = @_;
                                        if( !defined $value || length($value) == 0 ) { $value = "00"; }
                                        elsif( length($value) == 1 ) { $value = $value . "0"; }
					my $input_field = $session->render_input_field(
						class => "ep_form_text ep_project_currency_amount_minor",
						name => "c1_currency_amount_minor",
						value => $value,
						maxlength => 2,
						style => "width: 20px;",
						onkeypress => 'onkeypress="return EPJS_block_enter( event )',
					);
					my $frag = $session->make_doc_fragment;
					$frag->appendChild( $session->make_text(". "));
					$frag->appendChild( $input_field );
					return $frag;
				},
			},
		],
		render_value => sub {
			my( $session , $field , $value ) = @_;

                        if( !defined $value ) { return $session->make_doc_fragment; }
			if( $value->{major} =~ /^\d+$/ and length($value->{major}) > 3 )
                        {
                        	my $d = $value->{major};
                                my $human = "";
                                while( $d =~ s/(\d{3})$// )
                                {
                                	$human = ( $d ? ",$1" : "$1" ).$human;
                                }

                                $human = $d.$human if( $d );
                                $value->{major} = $human;
			}
			
			if( !defined $value->{minor} || length($value->{minor}) == 0 ) { $value->{minor} = "00"; }
			elsif( length($value->{minor}) == 1 ) { $value->{minor} = $value->{minor} . "0"; }
			elsif( length($value->{minor}) > 2 ) {
				my $rounding = "0.".substr($value->{minor}, 2);
                       		my $value->{minor} = substr($value->{minor}, 0, 2);
                               	if ($rounding >= 0.5) { $value->{minor}++; }
                        }
		 	my $currency_prefix = $session->phrase("currencies_prefix_".$value->{currency});
			my $currency_suffix = " (" . $session->phrase("currencies_suffix_".$value->{currency}) . ")";
                        my $display =  $currency_prefix . $value->{major} . "." . $value->{minor} . $currency_suffix || "";
                        return $session->make_text($display);
 		},	
	},
	{
		# the source URL of that project (eg. gtr's url if imported from gtr)
		name => "source",
		type => "url",
		text_index => 0,
	},
	{
		# gtr, elsevier, rioxx 
		name => "database",
		type => "id",
		text_index => 0,
	},
	{
		# 'role' should be a namedset (P.I. etc, cf GtR)
		name => 'contributors',
		type => 'compound',
		multiple => 1,
		fields => [
			{
				sub_name => 'role',
				type => 'text',
				text_index => 0,
			},
			{
				sub_name => 'name',
				type => 'name',
			},
			{
				sub_name => 'id',
				type => 'id',
				text_index => 0,
			},
		]
	},	
	{
		# Alternative grant id's
		name => "alt_grants",
		type => "id",
		multiple => 1,
		text_index => 1
	},
	{
		# an optional internal ID as used on other internal systems (eg Agresso)
		name => "int_project_code",
		type => "id",
	},
)
{
	$c->add_dataset_field('project', $_, reuse => 1);
}

# linking Funders to Projects
$c->add_dataset_field('project', {
	name => 'funders',
	type => 'dataobjref',
	datasetid => 'funder',
	fields => [
		{ sub_name => 'name', type => 'text', },
	],
	multiple => 1,
}, reuse => 1);


# class
{

 package EPrints::DataObj::Project;

 our @ISA = qw( EPrints::DataObj );

 sub get_system_field_info
 {
	my( $class ) = @_;

	return ();
 }

 # my( $project ) = EPrints::DataObj::Project::project_by_grant( $repo, $grant_number );
 sub project_by_grant
 {
	my( $repo, $grant ) = @_;

	return $repo->dataset( 'project' )->search( 
		search_fields => [ { meta_fields => [ 'grant' ], value => uc($grant), match => 'EX' } ]
	)->slice(0,1);
 }


 sub get_dataset_id { 'project' }

 sub has_owner
 {
	 my ($self, $user) = @_;

	 return $self->is_set('userid') && $self->value('userid') eq $user->id;
 }

 sub get_control_url
 {
	 my ($self) = @_;

	 my $url = $self->repository->current_url(
	 	host => 1,
		path => 'cgi',
		'users/home'
	);
	 $url->query_form(
	 	screen => 'Workflow::View',
		dataset => $self->get_dataset_id,
		dataobj => $self->id,
	);
	 return $url;
 }
} ### end of package ###


# fields to search on the UI
$c->{datasets}->{project}->{search}->{dataobjref} = {
                search_fields => [{
                        id => "q",
                        meta_fields => [qw/ title grant contributors_name funders_name alt_grants /],
                        match => "IN",
                }],
                show_zero_results => 1,
                order_methods => {
                        byid => "projectid",
                },
                default_order => "byid",
};

push @{$c->{user_roles}->{user}}, qw{
	+project/export
};

push @{$c->{user_roles}->{admin}}, qw{
	+project/create
        +project/details
        +project/edit
        +project/view
        +project/destroy
        +project/export
};

$c->add_dataset_trigger( "eprint", EP_TRIGGER_BEFORE_COMMIT, sub {

	my( %p ) = @_;

	my $changed = $p{changed};
	my $dataobj = $p{dataobj};

	# set funders field from project field
	
	if( $changed->{projects_id} || $changed->{funders} )
	{
		my $new_projects_id = $dataobj->value( 'projects_id' );

		my @projects_titles;
		my @projects_grants;
		my @funders;
		EPrints::List->new( 
			repository => $dataobj->repository,
			dataset => $dataobj->repository->dataset( 'project' ),
			ids => $new_projects_id
		)->map( sub {
			
			my $project = $_[2] or return;
			
			# cache the funders to the 'eprint' data-obj
			foreach my $funder (@{ $project->value( 'funders' ) || [] }) {
				push @funders, $funder;
			}
			push ( @projects_titles, $project->value( 'title' ) );
			push ( @projects_grants, $project->value( 'grant' ) );
		} );		 
			
		$dataobj->set_value( "projects_title", \@projects_titles );
		$dataobj->set_value( "projects_grant", \@projects_grants );
		$dataobj->set_value( "funders", \@funders );
		my $funder_dataset = $p{repository}->dataset( "funder" );
		my @funders_names = map { 
                        my $funder = $funder_dataset->dataobj($_->{id});
                        $funder->get_value( 'name' ); 
                } @funders;
		$dataobj->set_value( "funders_name", \@funders_names );
		
	}

} );

$c->add_dataset_trigger( "project", EP_TRIGGER_AFTER_COMMIT, sub {

        my( %p ) = @_;

	# Only run if project has changed
	return if !defined $p{changed} || !$p{changed};

	my $project = $p{dataobj};
	my $dataset = $p{repository}->dataset( 'eprint' );

	# Find EPrints associated with a particular project.  
	# This could get big and it would be good if it could be backgrounded.
	my $search = $dataset->prepare_search();
	$search->add_field(
		fields => [
			$dataset->field('projects_id')
		],
		value => $project->value( 'projectid' ),
		match => "EQ",
	);
	my $eprints = $search->perform_search();
	my $project_dataset = $p{repository}->dataset( "project" );
	my $funder_dataset = $p{repository}->dataset( "funder" );
        $eprints->map( sub {
		my $eprint = $_[2] or return;
		my @projects = @{ $eprint->value( 'projects' ) || [] };
		# Update project titles for search
		if ( $p{changed}->{title} ) {
			my @projects_titles;
			@projects_titles = map {
				my $eprint_project = $project_dataset->dataobj($_->{id});
                	        $eprint_project->get_value( 'title' );
			} @projects;
			$eprint->set_value( "projects_title", \@projects_titles );
		}
		# Update project grants for search
		if ( $p{changed}->{grant} ) {
                       	my @projects_grants;
			@projects_grants = map {
                                my $eprint_project = $project_dataset->dataobj($_);
                                $eprint_project->get_value( '' );
                       	} @projects;
			$eprint->set_value( "project_grants", \@projects_grants );
                }
		# Update funders and funders names for search
		my @funders = @{ $project->value( 'funders' ) || [] };
		my @funders_names = map {
			my $funder = $funder_dataset->dataobj($_->{id});
			$funder->get_value( 'name' );
		} @funders;
		# Update funders so before commit EPrint trigger above is run when EPrint is committed
		$eprint->set_value( "funders", \@funders );
		$eprint->set_value( "funders_name", \@funders_names );
		$eprint->commit();
		# Regenerate abstract page
		$eprint->generate_static();
	});
} );			

$c->add_dataset_trigger( "project", EP_TRIGGER_BEFORE_COMMIT, sub {

        my( %p ) = @_;

        my $changed = $p{changed};
        my $project = $p{dataobj};

        if( $changed->{currency_amount_currency} || $changed->{currency_amount_major} || $changed->{currency_amount_minor} )
	{
		my $rounding = "0." . $project->value( 'currency_amount_minor' );
		if ($rounding >= 0.5) 
		{ 
			my $rounded = $project->value( 'currency_amount_major' ) + 1;
			$project->set_value( "amount", $rounded ); 
		}
		else { $project->set_value( "amount", $project->value( 'currency_amount_major' ) ); }
	}
} );

# Browse view for Funders/Projects
push @{$c->{browse_views}}, {

	id => "funders",
	menus => [
		{
			fields => [ "funders_name" ],
			allow_null => 0,
			new_column_at => [10,10],
		}
	],
	order => "projects_title/-date",
	variations => [
		"projects_title"
	],
};

# linking projects to eprint objects
$c->add_dataset_field( 'eprint',
	{
		name => "projects",
		type=>"dataobjref",
		datasetid=>"project",
		multiple => 1,
		fields => [
			{ sub_name => 'title', type => 'text' },
			{ sub_name => 'grant', type => 'text' }
		],
	},
	reuse => 1
);

# Field to allow users to specify there is no funding behind an EPrint
$c->add_dataset_field( 'eprint', { name => "nofunding", type => "boolean" } );

# Dield to allow users to describe why they have not added a project or could not find it.
$c->add_dataset_field( 'eprint', { name => "unknown_project", type => "longtext" } );

# Field to ask users to confim they have acknowledged funders
$c->add_dataset_field( 'eprint', { name => "funders_acknowledged", type => "set", input_style => "radio", required => 1, options => [ 'yes', 'no', 'no_funders' ] } );


# Back-fill screens

$c->{plugins}{'Screen::Backfill'}{params}{disable} = 0;
$c->{plugins}{'Screen::Grants'}{params}{disable} = 0;
$c->{plugins}{'Screen::UserGrants'}{params}{disable} = 0;
$c->{plugins}{'InputForm::Surround::LocalNone'}{params}{disable} = 0;

# if you want to order the list with your own criterion: (default: -date/title)
# $c->{plugins}{'Screen::Grants'}{params}{custom_order} = "-date/title";

# by default Backfill (therefore Grants) will show the items owned by the user (eprint.userid == user.userid)
# so you may add extra filters to retrieve extra publications (say if you have a authorid in use)
# format: EPrint field (should EX match => ) User field
# note that the different fitlers are OR'ed (satisfy_all => 0)
# note that the filter is applied ONLY if the field exists and is_set for the given user
$c->{plugins}{'Screen::Grants'}{params}{list_filters} = {
	"contributors_id" => "ep_person_id"
};

$c->{plugins}{'Screen::Grants'}{params}{fields_filter_whitelist} = [qw/ type date /];

# a custom method to decide if the current user is allowed to back-fill Grants on behalf of user "$onbehalf"
# note that the current user MUST have the "grants" privilege regarless of the returned value of the function below
# function must return 0 or 1 to deny or allow respectively
#
$c->{plugins}{'Screen::Grants'}{params}{allow_on_behalf_of} = sub {

	my( $screen, $current_user, $onbehalf ) = @_;

	# For the Uni of Soton, anyone who is an editor, a power editor or an admin can back-fill grants of behalf of anyone
	my $type = $current_user->value( 'usertype' ) || '';
	
	my %valid_types = map { $_ => 1 } ( 'admin', 'editor' );

	if( $valid_types{$type} )
	{
		return 1;
	}

	return 0;
};

# This is the button on the user profile linking back to the Grants screen 
$c->{plugins}{'Screen::UserGrants'}{params}{allow_on_behalf_of} = $c->{plugins}{'Screen::Grants'}{params}{allow_on_behalf_of};

# This disables by default filter by role for grants backfill
$c->{plugins}{'Screen::Grants'}{params}{filter_by_role} = undef;


# added staff/user_search, user_view to editors so they can search for users (to backfill grants on behalf of)
push @{$c->{user_roles}->{editor}}, qw{
	+staff/user_search
	+user/view
	+grants
};

# admins should already have staff/user_search & user/view
push @{$c->{user_roles}->{admin}}, qw{
	+grants
};


