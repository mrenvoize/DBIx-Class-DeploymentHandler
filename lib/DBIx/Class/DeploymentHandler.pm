package DBIx::Class::DeploymentHandler;

use Moose;
use Method::Signatures::Simple;
require DBIx::Class::Schema;    # loaded for type constraint
require DBIx::Class::ResultSet; # loaded for type constraint
use Carp::Clan '^DBIx::Class::DeploymentHandler';

with 'DBIx::Class::DeploymentHandler::WithSqltDeployMethod';
with 'DBIx::Class::DeploymentHandler::WithDatabaseToSchemaVersions';

BEGIN {
  use Moose::Util::TypeConstraints;
  subtype 'DBIx::Class::DeploymentHandler::Databases'
    => as 'ArrayRef[Str]';

  coerce 'DBIx::Class::DeploymentHandler::Databases'
    => from 'Str'
    => via { [$_] };
  no Moose::Util::TypeConstraints;
}

has schema => (
  isa      => 'DBIx::Class::Schema',
  is       => 'ro',
  required => 1,
);

has upgrade_directory => ( # configuration
  isa      => 'Str',
  is       => 'ro',
  required => 1,
  default  => 'sql',
);

has backup_directory => ( # configuration
  isa => 'Str',
  is  => 'ro',
  predicate  => 'has_backup_directory',
);

has do_backup => ( # configuration
  isa     => 'Bool',
  is      => 'ro',
  default => undef,
);

has version_rs => (
  isa        => 'DBIx::Class::ResultSet',
  is         => 'ro',
  lazy_build => 1, # builder comes from another role...
                   # which is... probably not how we want it
  handles    => [qw( is_installed )],
);

has to_version => ( # configuration
  is         => 'ro',
  lazy_build => 1, # builder comes from another role...
                   # which is... probably not how we want it
);

has databases => ( # configuration
  coerce  => 1,
  isa     => 'DBIx::Class::DeploymentHandler::Databases',
  is      => 'ro',
  default => sub { [qw( MySQL SQLite PostgreSQL )] },
);

has sqltargs => ( # configuration
  isa => 'HashRef',
  is  => 'ro',
  default => sub { {} },
);

method install {
  carp 'Install not possible as versions table already exists in database'
    if $self->is_installed;

  my $new_version = $self->to_version;

  if ($new_version) {
    $self->_deploy;

    $self->version_rs->create({
      version     => $new_version,
      # ddl         => $ddl,
      # upgrade_sql => $upgrade_sql,
    });
  }
}

sub upgrade {
  while ( my $version_list = $_[0]->next_version_set ) {
    $_[0]->_upgrade_single_step($version_list);
  }
}

method backup { $self->storage->backup($self->backup_directory) }

__PACKAGE__->meta->make_immutable;

1;

__END__

vim: ts=2 sw=2 expandtab
