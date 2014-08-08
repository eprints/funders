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

			return $session->make_text( "£$display" );
		}
 
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
	
	if( $changed->{projects_id} )
	{
		my $new_projects_id = $dataobj->value( 'projects_id' );

		my @funders_id;
		my @funders;

		EPrints::List->new( 
			repository => $dataobj->repository,
			dataset => $dataobj->repository->dataset( 'project' ),
			ids => $new_projects_id
		)->map( sub {
			
			my $project = $_[2] or return;

			# cache the funders to the 'eprint' data-obj
			@funders = @{ $project->value( 'funders' ) || [] };

		} );		 

		$dataobj->set_value( "funders", \@funders );
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
			{ sub_name => 'title', type => 'text' }
		],
	},
	reuse => 1
);


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


