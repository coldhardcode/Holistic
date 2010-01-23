#!/usr/bin/env perl
# IMPORTANT: if you delete this file your app will not work as
# expected.  You have been warned.
use inc::Module::Install;

name 'Holistic';
all_from 'lib/Holistic.pm';

requires 'Catalyst::Runtime' => '5.80016';

requires 'Catalyst::Plugin::ConfigLoader';
requires 'Catalyst::Plugin::Static::Simple';
requires 'Catalyst::Plugin::Session';
requires 'Catalyst::Plugin::I18N';
requires 'Catalyst::Plugin::Session::State::Cookie';
requires 'Template::Plugin::Lingua::EN::Inflect';

requires 'Catalyst::Action::RenderView';
requires 'Catalyst::Action::REST';

requires 'Catalyst::Model::DBIC::Schema';

requires 'Catalyst::View::TT';

# Moose
requires 'Moose';
requires 'namespace::autoclean';
requires 'MooseX::Role::Parameterized';

# D:V Stuff
requires 'Data::Verifier';
requires 'Message::Stack';
requires 'Data::Manager';

# DateTime
requires 'DateTime';
requires 'DateTimeX::Easy';
requires 'DateTime::Format::DBI';
requires 'DateTime::Format::SQLite';
requires 'DateTime::Format::DateParse';

# DBIC Components
requires 'DBIx::Class';
requires 'DBIx::Class::TimeStamp';
requires 'DBIx::Class::DynamicDefault';

requires 'YAML';
requires 'YAML::Syck';
requires 'YAML::XS';

requires 'parent';

test_requires 'Test::More' => '0.88';
catalyst;

install_script glob('script/*.pl');
auto_install;
WriteAll;
