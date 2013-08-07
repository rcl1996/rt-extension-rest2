package RTx::REST::Resource::Record::Writable;
use strict;
use warnings;

use Moose::Role;
use namespace::autoclean;
use JSON ();
use RTx::REST::Util qw( deserialize_record );

requires 'record';
requires 'record_class';

sub post_is_create            { 1 }
sub allow_missing_post        { 1 }
sub create_path_after_handler { 1 }
sub create_path {
    $_[0]->record->id || undef
}

sub content_types_accepted { [ {'application/json' => 'from_json'} ] }

sub from_json {
    my $self = shift;
    my $data = deserialize_record(
        $self->record,
        JSON::from_json( $self->request->content ),
    );

    my $method = $self->request->method;
    return $method eq 'PUT'  ? $self->update_resource($data) :
           $method eq 'POST' ? $self->create_resource($data) :
                                                        \501 ;
}

sub update_resource {
    my $self = shift;
    my $data = shift;

    if (not $self->resource_exists) {
        $self->response->body("Resource does not exist; use POST to create");
        return \404;
    }

    # XXX TODO: ->Update doesn't handle roles
    my @results = $self->record->Update(
        ARGSRef       => $data,
        AttributesRef => [ $self->record->WritableAttributes ],
    );
    # XXX TODO: Figure out how to return success/failure?  Core RT::Record's
    # ->Update will need to be replaced or improved.
    $self->response->body( JSON::to_json(\@results) );
    return;
}

sub create_resource {
    my $self = shift;
    my $data = shift;

    if ($self->resource_exists) {
        $self->response->body("Resource already exists; use PUT to update");
        return \409;
    }

    my ($ok, $msg) = $self->record->Create( %$data );
    if ($ok) {
        return;
    } else {
        $self->response->body($msg || "Create failed for unknown reason");
        return \409;
    }
}

1;
