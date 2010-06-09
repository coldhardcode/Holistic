#!/usr/bin/env perl
# IMPORTANT: if you delete this file your app will not work as
# expected.  You have been warned.
use inc::Module::Install;

name 'Holistic';
all_from 'lib/Holistic.pm';

requires 'Catalyst::Runtime' => '5.80020';

requires 'Catalyst::Plugin::ConfigLoader';
requires 'Catalyst::Plugin::Static::Simple';
requires 'Catalyst::Plugin::Session';
requires 'Catalyst::Plugin::Session::Store::FastMmap';
requires 'Catalyst::Plugin::Session::State::Cookie';
requires 'Catalyst::Plugin::Unicode::Encoding';
requires 'Catalyst::Plugin::I18N';
requires 'Catalyst::Plugin::Params::Nested';

requires 'Catalyst::Plugin::Authentication';
requires 'Catalyst::Plugin::Cache';
requires 'Cache::FastMmap';
requires 'Net::API::RPX';

requires 'Template::Plugin::HTML::Strip';
requires 'Template::Plugin::Lingua::EN::Inflect';
requires 'Template::Plugin::Number::Format';
requires 'Template::Plugin::Time::Duration';
requires 'Template::Plugin::JSON';

requires 'Catalyst::Authentication::Credential::HTTP';
requires 'Catalyst::Authentication::Store::DBIx::Class';

requires 'Catalyst::Action::RenderView';
requires 'Catalyst::Action::REST';

requires 'Catalyst::Model::Adaptor';
requires 'Catalyst::Model::DBIC::Schema';

requires 'Catalyst::View::TT';
requires 'Catalyst::View::Graphics::Primitive';

# Moose
requires 'Moose';
requires 'namespace::autoclean';
requires 'MooseX::Method::Signatures';
requires 'MooseX::Role::Parameterized';
requires 'MooseX::UndefTolerant';

# D:V Stuff
requires 'Data::Verifier';
requires 'Message::Stack';
requires 'Data::Manager';

# Search
requires 'Data::SearchEngine';
requires 'Hash::Merge';
requires 'Search::QueryParser';

# DateTime
requires 'DateTime';
requires 'DateTimeX::Easy';
requires 'DateTime::Format::DBI';
requires 'DateTime::Format::DateParse';
requires 'DateTime::Format::SQLite';
requires 'MooseX::Types::DateTime';

# DBIC Components
requires 'DBIx::Class' => '0.08119';
requires 'DBIx::Class::TimeStamp';
requires 'DBIx::Class::DynamicDefault';
requires 'DBIx::Class::Ordered';
requires 'DBIx::Class::EncodedColumn';
requires 'DBIx::Class::Tree';

# Pretty baubels
requires 'Chart::Clicker';
requires 'Graphics::Color';
requires 'HTTP::BrowserDetect';

# Random Stuff
requires 'Lingua::EN::Words2Nums';

requires 'Time::HiRes';

requires 'YAML';
requires 'YAML::Syck';
requires 'YAML::XS';

requires 'parent';

test_requires 'Test::More' => '0.88';
test_requires 'String::Random';
test_requires 'Text::Lorem' => '0.3';
catalyst;

install_script glob('script/*.pl');
auto_install;
WriteAll;
