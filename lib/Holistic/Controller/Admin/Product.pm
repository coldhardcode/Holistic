package Holistic::Controller::Admin::Product;

use Moose;

BEGIN { extends 'Holistic::Base::Controller::REST'; }

__PACKAGE__->config(
    actions    => { 'setup' => { PathPart => 'product' } },
    class      => 'Schema::Product',
    rs_key     => 'product_rs',
    object_key => 'product',
    scope      => 'product',
    create_string => 'The project has been created.',
    update_string => 'The project has been updated.',
    error_string  => 'There was an error processing your request, please try again.',

);

sub queue : Chained('object_setup') PathPart('') CaptureArgs(0) { }

no Moose;
__PACKAGE__->meta->make_immutable( inline_constructor => 0 );
