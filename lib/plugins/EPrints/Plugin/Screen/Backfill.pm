package EPrints::Plugin::Screen::Backfill;

# Abstract Screen

use EPrints::Plugin::Screen::Listing;
@ISA = ( 'EPrints::Plugin::Screen::Listing' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{appears} = [
# appears in the main toolbar:
#		{
#			place => "key_tools",
#			position => 101,
#		},
# appears on User profiles:		
#		{
#			place => "user_view_actions",
#			position => 200,
#		}
	];
	
	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return 0;
}

sub properties_from
{
	my( $self ) = @_;

	my $repo = $self->repository;
	my $dataset = $self->{processor}->{dataset} = $self->dataset;

	$self->SUPER::properties_from;

	# add the search fields here so apply_user_filters() - called in
	# SUPER::from() - will correctly set the value for already set fields
	my $sconf = $self->search_conf;
	foreach my $sfield (@{$sconf->{search_fields}})
	{
		$self->{processor}{search}->add_field(
			%$sfield,
			fields => [map { EPrints::Utils::field_from_config_string($dataset, $_) } @{$sfield->{meta_fields}}],
		);
	}
}

sub from
{
	my( $self ) = @_;

	my $repo = $self->repository;
	my $dataset = $self->{processor}->{dataset} = $self->dataset;

	$self->SUPER::from();	

	my $dataobjid = $repo->param('dataobj');
	if ($dataobjid)
	{
		# sf2 - weirdly this doesn't get applied:
		$self->{processor}{search}->add_field(
			fields => [$dataset->key_field],
			value => $dataobjid,
			match => 'EX',
		);
	}

	my $results = $self->{processor}->{results} = $self->perform_search;
	
	if ($dataobjid)
	{
		my %valid_ids = map { $_ => undef } @{ $results->ids || [] };
		if( exists $valid_ids{$dataobjid} )
		{
			# sf2 - workaround the filter not getting properly applied a few lines above
			# just making sure the requested ID is in the initial retrieved list
			$self->{processor}->{dataobj} = $dataset->dataobj( $dataobjid );
		}
		else
		{
			$self->{processor}->{dataobj} = $results->item(0);
		}
	}

	if( defined(my $component = $self->current_component) )
	{
		$component->update_from_form( $self->{processor} );
		$component->{dataobj}->commit if( defined $component->{dataobj} );
	}
}

# field handled by this screen
sub field
{
	my( $self ) = @_;

	# e.g.
	# return $self->{session}->dataset( 'eprint' )->field( 'title' );
}

sub dataset
{
	my( $self ) = @_;

	# e.g.
	# return $self->{session}->dataset( 'eprint' );
}

sub component_id
{
	my( $self ) = @_;

	# as in InputForm::Component::Field
	return 'Field';
}

sub search_conf
{
	my( $self ) = @_;

	my $dataset = $self->dataset;

        # $dataset->search_config was added in 3.3.11 - if we don't have, use $self->search_config instead
	# and note that can() is a built-in PERL function
        if( $dataset->can( 'search_config' ) )
        {
		return $dataset->search_config( 'advanced' );
        }
        else
        {
		return $self->dataset_search_config( $dataset, 'advanced' );
        }
}

# sf2 - this appeared in EPrints::DataSet in 3.3.11
# call by $self->search_plugin, above
sub dataset_search_config
{
        my( $self, $dataset, $searchid ) = @_;

        my $repo = $self->{repository};

        my $sconf;
        if( $dataset->id eq "archive" )
        {
                $sconf = $repo->config( "search", $searchid );
        }
        if( !defined $sconf )
        {
                $sconf = $repo->config( "datasets", $dataset->id, "search", $searchid );
        }
        if( defined $sconf )
        {
                # backwards compat. when _fulltext_ was a magic field
                foreach my $sfs (@{$sconf->{search_fields}})
                {
                        for(@{$sfs->{meta_fields}})
                        {
                                $_ = "documents" if $_ eq "_fulltext_";
                        }
                }
        }
        elsif( $searchid eq "simple" )
        {
                $sconf = $dataset->_simple_search_config();
        }
        elsif( $searchid eq "advanced" )
        {
                $sconf = $dataset->_advanced_search_config();
        }
        else
        {
                $sconf = {};
        }

        return $sconf;
}

# we can't use this mechanism because it doesn't support multi-field style
# search fields (e.g. creators/editors)
sub show_columns
{
	return [];
}

sub current_component
{
	my( $self ) = @_;

	return $self->{processor}->{component} if( defined $self->{processor}->{component} );

	my $session = $self->{session};
	my $prefix = $session->param( 'component' );

	my $dataset = $self->{processor}{dataset} or return undef;
	my $dataobj = $self->{processor}{dataobj} or return undef;

	$self->{processor}->{component} = $self->get_component( $prefix, $dataobj );

	return $self->{processor}->{component};
}

sub get_component
{
	my( $self, $prefix, $dataobj ) = @_;

	my $session = $self->{session};

	my $field = $self->field() or return undef;

	my %args = ( 'ref' => $field->name );
	
	foreach( 'input_lookup_url', 'input_lookup_params' )
	{
		$args{$_} = $field->property( $_ ) if( $field->property( $_ ) );
	}

	# <component><field ref="title" ...>
	my $xml_config = $session->xml->create_data_element(
		'component',
		[
			[ 'field', undef, %args ]
		],
		autocommit => "yes",
	);

	my %opts = (
		session => $session,
		processor => $self->{processor},
		collapse => 0,
		no_help => 1,
		no_toggle => 1,
		surround => 'LocalNone',
		prefix => $prefix,
		dataobj => $dataobj,
		dataset => $dataobj->dataset,
		xml_config => $xml_config,
	);

	$session->xml->dispose($xml_config);

	return $session->plugin( "InputForm::Component::".$self->component_id, %opts );
}

sub wishes_to_export
{
	my( $self ) = @_;

	return $self->current_component->wishes_to_export($self->{processor})
		if $self->current_component;

	return $self->SUPER::wishes_to_export;
}

sub export_mimetype
{
	my( $self ) = @_;

	return $self->current_component->export_mimetype($self->{processor})
		if $self->current_component;

	return $self->SUPER::export_mimetype;
}

sub export
{
	my( $self ) = @_;

	return $self->current_component->export($self->{processor})
		if $self->current_component;

	return $self->SUPER::export;
}

sub redirect_to_me_url
{
	my( $self ) = @_;

	return undef if $self->current_component;

	return $self->SUPER::redirect_to_me_url;
}


sub render_title
{
	my( $self ) = @_;

	if( !defined $self->{processor}->{dataset} )
	{
		$self->{processor}->{dataset} = $self->dataset;
	}

	return $self->SUPER::render_title;
}

sub render
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $list = $self->{processor}{results};

	my $chunk = $session->make_doc_fragment;

	if( $session->get_lang->has_phrase( $self->html_phrase_id( 'blurb' ) ) )
	{
		$chunk->appendChild( $self->html_phrase( 'blurb' ) );
	}

	$chunk->appendChild( $self->render_top_bar() );

	$chunk->appendChild( $self->render_filters() );

	$chunk->appendChild( $self->render_items( $list ) );

	return $chunk;
}

sub render_items
{
	my( $self, $list ) = @_;

	my $session = $self->{session};
	my $chunk = $session->make_doc_fragment;
	my $xhtml = $session->xhtml;
	my $prefix = 1;

	my $search = $self->{processor}->{search};
	my $exp;
	if( !$search->is_blank )
	{
		$exp = $search->serialise;
	}

	# Paginate list
	my %opts = (
		params => {
			screen => $self->get_subtype,
			exp => $exp,
			$self->hidden_bits
		},

		container => $session->make_doc_fragment,

		render_result => sub {
			my( undef, $eprint) = @_;

			my $compo = $self->get_component( 'c'.$prefix++, $eprint );
			return $session->make_doc_fragment if !defined $compo;

			my $div = $session->make_element( 'div', class => 'ep_backfill_item' );
			$div->appendChild( $eprint->render_citation_link );

			my $form = $div->appendChild( $self->render_form );
			$div->appendChild( $form );

			$form->appendChild($xhtml->hidden_field(exp => $exp));
			$form->appendChild($xhtml->hidden_field(component => $compo->{prefix}));
			$form->appendChild($xhtml->hidden_field(dataobj => $eprint->id));

			$form->appendChild( $compo->render() );

			return $div;
		},
	);
	
	$chunk->appendChild( EPrints::Paginate::Columns->paginate_list( $session, "_backfill", $list, %opts ) );

	return $chunk;
}

1;
