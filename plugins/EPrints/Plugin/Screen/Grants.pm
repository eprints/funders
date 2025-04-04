package EPrints::Plugin::Screen::Grants;

use EPrints::Plugin::Screen::Backfill;
@ISA = ( 'EPrints::Plugin::Screen::Backfill' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{appears} = [
		{
			place => "key_tools",
			position => 101,
		},
	];
	
	return $self;
}

# Can get to this screen via key_tools or via a User profile (on behalf of)
sub can_be_viewed
{
	my( $self ) = @_;

	my $user = $self->repository->current_user;
	return 0 if !defined $user;

	# regardless of the user being allowed to backfill "on-behalf-of" others,
	# the current user must have the "grants" priv:
	return 0 if( !$self->allow( 'grants' ) );

	my $onbehalfof = $self->{processor}{onbehalfof};
	if( defined $onbehalfof )
	{
		# local look-up if person is allowed?
		# i bet every institution will have different requirements for that....

		my $allow_fn = $self->param( 'allow_on_behalf_of' );
		if( !defined $allow_fn || ref( $allow_fn ) ne 'CODE' )
		{
			return 0;
		}

		my $rc = &$allow_fn( $self, $user, $onbehalfof ) || 0;
		return $rc;
	}

	# user has the 'grant' priv and didn't request any "on-behalf-of" so we're good to go
	return 1;
}

sub properties_from
{
	my( $self ) = @_;
	
	my $onbehalfof = $self->repository->param('userid');

	if( defined $onbehalfof && defined $self->repository->current_user && $onbehalfof ne $self->repository->current_user->get_id )
	{
		$self->{processor}{onbehalfof} = $self->repository->user($onbehalfof);
	}

	$self->SUPER::properties_from;
}

sub perform_search
{
	my ($self) = @_;

	my $user = $self->{processor}{onbehalfof} || $self->{processor}{user};

	my %props = %{$self->{processor}{search}};

	# sf2 - the @filters above is about the top "Filters" section on the Grants page
	# those cannot be added as search_fields because we may retrieve eprints with more than one search_field
	# in which case we'd need to potentially search <filter1 AND ( sf1 OR sf2 )> which eprints cannot do without filters
	my @filters;
	foreach my $sf ($self->{processor}{search}->get_non_filter_searchfields)
	{
		my @meta_fields = @{$sf->get_fields};
		for(@meta_fields)
		{
			# reverse of EPrints::Utils::field_from_config_string
			if ($_->property('join_path')) {
				$_ = join '.', (map { $_->[0]->name } @{$_->property('join_path')}), $_->name;
			}
			else {
				$_ = $_->name;
			}
		}

		next if(!$sf->is_set);

		push @filters, {
			id => $sf->get_id,
			meta_fields => \@meta_fields,
			match => $sf->get_match,
			merge => $sf->get_merge,
			($sf->is_set ? (value => $sf->get_value) : ()),
		};
	}

	$props{filters} = \@filters;
	
	my @search_fields;

	# search for deposited items by default:
	my $filterbyrole = $self->param( 'filter_by_role' );
	$filterbyrole ||= 0;
	my $rolefilter = $self->repository->param('role');
	$rolefilter ||= "nofilter";

	if ( $filterbyrole == 0 || $rolefilter eq "owner" || $rolefilter eq "nofilter" )
	{
		push @search_fields, {
			meta_fields => [qw/ userid /],
			value => $user->id,
			match => 'EX'
		};
	}

	# it is however possible to add extra filters (to search via authorid for instance)
	my %list_filters = %{ $self->param( 'list_filters' ) || {} };

	# "key" is the eprint fieldname, "value" is the user fieldname
	if ( $filterbyrole == 0 || $rolefilter eq "creator" || $rolefilter eq "nofilter" ) 
	{
		foreach my $epfield ( keys %list_filters )
		{
			my $ufield = $list_filters{$epfield};
			next if( !defined $ufield || !$user->exists_and_set( $ufield ) );	
			push @search_fields, {
				meta_fields => [ $epfield ],
				value => $user->value( $ufield ),
				match => 'EX'
			};
		}
	}

	# Hack to ensure no results are returned if no filters are set.
	if ( ! @search_fields )
	{
		push @search_fields, {
                        meta_fields => [qw/ userid /],
                        value => 0,
                        match => 'EX'
                };
	}
	$props{search_fields} = \@search_fields;

	$props{custom_order} = $self->param( "custom_order" );
	$props{custom_order} ||= "-date/title";
	$props{satisfy_all} = 0;
	
	my $ds = $self->{repository}->dataset( 'archive' );
	my $search = $ds->prepare_search( %props );

	return $search->perform_search;
}

sub render_title
{
	my( $self ) = @_;

	return $self->html_phrase( 'title' );
}

# render "on behalf of" options?
sub render_top_bar
{
        my( $self ) = @_;

        my $session = $self->{session};
        my $xml = $session->xml;
        my $dataset = $self->{processor}->{dataset};

        my $f = $xml->create_document_fragment;

	# if no on-behalf-of set then;
	# if user has "staff/user_search" > show a "Select user" button > user search
	# if not then return $f

	my $title;
	if( defined $self->{processor}->{onbehalfof} )
	{
		my $reset_link = $session->make_element( 'a', href => $self->{processor}->{url}."?screen=".$self->{processor}->{screenid} );
		my $search_link = $session->make_element( 'a', href => $self->{processor}->{url}."?screen=Staff::UserSearch" );

		$f->appendChild( $self->html_phrase( 'onbehalfof:user', 
			user => $self->{processor}->{onbehalfof}->render_description,
			reset => $reset_link,
			search_users => $search_link,
		) );
	}
	else
	{
		return $f if( !$self->allow( 'staff/user_search' ) );
		my $search_link = $session->make_element( 'a', href => $self->{processor}->{url}."?screen=Staff::UserSearch" );
		$f->appendChild( $self->html_phrase( 'onbehalfof:userquest', search_users => $search_link ) );
	}
        
	my %options = (
                session => $session,
                id => "ep_grants_onbehalfof",
                title => $self->html_phrase( 'onbehalfof:title' ),
                content => $f,
                collapsed => !defined $self->{processor}->{onbehalfof},
        );
        my $box = $session->make_element( "div", style=>"text-align: left" );
        $box->appendChild( EPrints::Box::render( %options ) );
        $f->appendChild( $box );

	# DRN: Filter by Role
	if ( defined $self->param( 'filter_by_role' ) )
	{
		my $rolebaseurl = $self->{processor}->{url}."?screen=".$self->{processor}->{screenid};
		if ( defined $self->repository->param('userid'))
                {
                        $rolebaseurl .= "&userid=" . $self->repository->param('userid');
                }
	        my $rolefilter = $self->repository->param('role');
		$rolefilter ||= "nofilter";	

	        my $rolefilterlist = $session->make_element( 'ul' );
        	my @rolefilters = ( "nofilter", "owner", "creator");
	        foreach my $rf ( @rolefilters ) {
        	        my $rflistitem = $session->make_element( 'li' );
                	my $rflianchor = $session->make_element( 'a',  href => $rolebaseurl . "&role=" . $rf );
	                $rflianchor->appendChild( $self->html_phrase( 'filterbyrole:' . $rf ) );
        	        $rflistitem->appendChild( $rflianchor );
                	$rolefilterlist->appendChild( $rflistitem );
	        }
	
		my $f2 = $xml->create_document_fragment;
	        $f2->appendChild( $self->html_phrase( 'filterbyrole:choose',
       	        	rolefilter => $self->html_phrase( 'filterbyrole:' . $rolefilter ),
                	rolefilterlist => $rolefilterlist
        	) );

		my %options2 = (
        	        session => $session,
                	id => "ep_grants_filterbyrole",
	                title => $self->html_phrase( 'filterbyrole:title', rolefilter => $self->html_phrase( 'filterbyrole:' . $rolefilter ) ),
        	        content => $f2,
                	collapsed => !defined $self->{processor}->{filterbyrole},
	        );
		my $box2 = $session->make_element( "div", style=>"text-align: left" );
        	$box2->appendChild( EPrints::Box::render( %options2 ) );
        
		$f->appendChild( $box2 );
	}
        
        return $f;
}


sub render_search_fields
{       
        my( $self ) = @_;
        
        my $frag = $self->{session}->make_doc_fragment;

	# sf2 - added whitelist to restrict the list of fields to filter with (otherwise the list's quite huge)
	my $whitelist_def = $self->param( "fields_filter_whitelist" );
	my $do_whitelist = defined $whitelist_def && scalar( @$whitelist_def ) > 0;


	my %whitelist_fields = map { $_ => 1 } @{ $whitelist_def || [] };
        
        foreach my $sf ( $self->{processor}->{search}->get_non_filter_searchfields )
        {      
		next if( $do_whitelist && !$whitelist_fields{$sf->get_field->get_name} );
 
                $frag->appendChild( 
                        $self->{session}->render_row_with_help( 
                                help_prefix => $sf->get_form_prefix."_help",
                                help => $sf->render_help,
                                label => $sf->render_name,
                                field => $sf->render,
                                no_toggle => ( $sf->{show_help} eq "always" ),
                                no_help => ( $sf->{show_help} eq "never" ),
                         ) );
        }


        return $frag;
}


sub field
{
	my( $self ) = @_;

	return $self->dataset->field( 'projects' );
}

sub dataset
{
	my( $self ) = @_;

	return $self->{session}->dataset( 'archive' );
}

sub component_id { 'Field::DataobjRef' }

sub hidden_bits
{
	my ($self) = @_;

	return(
		userid => ($self->{processor}{onbehalfof} ? $self->{processor}{onbehalfof}->id : undef),
		$self->SUPER::hidden_bits,
	);
}

sub action_stop
{
        my( $self ) = @_;

        my $return_to = $self->repository->param('return_to');

        if ($return_to && $return_to !~ m/Grant/)
        {
                $self->{processor}->{screenid} = $return_to;
        }
        else
        {
                $self->{processor}->{screenid} = $self->view_screen;
        }
}

1;
