package Holistic::Controller::Admin::Product;

use Moose;

BEGIN { extends 'Holistic::Base::Controller::REST'; }

__PACKAGE__->config(
    actions    => { 'setup' => { PathPart => 'product' } },
    class      => 'Schema::Product',
    rs_key     => 'product_rs',
    object_key => 'product',
);

no Moose;
__PACKAGE__->meta->make_immutable( inline_constructor => 0 );
