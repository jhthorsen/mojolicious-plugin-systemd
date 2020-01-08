package Mojolicious::Plugin::Systemd;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::File 'path';
use Mojo::Util qw(trim unquote);

use constant DEBUG => $ENV{MOJO_SYSTEMD_DEBUG} || 0;

has config_map => sub {
  return {
    hypnotoad => {
      accepts            => sub { (SERVER_ACCEPTS            => 0) },
      backlog            => sub { (SERVER_BACKLOG            => 0) },
      clients            => sub { (SERVER_CLIENTS            => 0) },
      graceful_timeout   => sub { (SERVER_GRACEFUL_TIMEOUT   => 0) },
      heartbeat_interval => sub { (SERVER_HEARTBEAT_INTERVAL => 0) },
      heartbeat_timeout  => sub { (SERVER_HEARTBEAT_TIMEOUT  => 0) },
      inactivity_timeout => sub { (SERVER_INACTIVITY_TIMEOUT => 0) },
      listen             => sub { (LISTEN                    => [qr{\s+}]) },
      pid_file           => sub { (SERVER_PID_FILE           => '') },
      proxy              => sub { (SERVER_PROXY              => 0) },
      requests           => sub { (SERVER_REQUESTS           => 0) },
      spare              => sub { (SERVER_SPARE              => 0) },
      upgrade_timeout    => sub { (SERVER_UPGRADE_TIMEOUT    => 0) },
      workers            => sub { (SERVER_WORKERS            => 0) },
    },
  };
};

has env_prefix => 'MOJO';

sub register {
  my ($self, $app, $config) = @_;

  $self->env_prefix($config->{env_prefix}) if $config->{env_prefix};
  $self->_merge_config_map($config->{config_map}, $self->config_map);

  my $file = $config->{unit_file} || $ENV{SYSTEMD_SERVICE_FILE};
  $self->_parse_unit_file($file) if $file or $ENV{XDG_SESSION_ID};
  $self->_config_from_env($app->config, $self->config_map);
}

sub _config_from_env {
  my ($self, $config, $config_map) = @_;

  for my $k (sort keys %$config_map) {
    if (ref $config_map->{$k} eq 'HASH') {
      $self->_config_from_env($config->{$k} ||= {}, $config_map->{$k});
    }
    elsif (ref $config_map->{$k} eq 'CODE') {
      my ($ek, $template) = $config_map->{$k}->();
      $ek = join '_', $self->env_prefix, $ek if $self->env_prefix;
      warn sprintf "[Systemd] config %s=%s\n", $ek, $ENV{$ek} // '' if DEBUG;
      $config->{$k} = $self->_config_val($ENV{$ek}, $template)
        if defined $ENV{$ek};
    }
  }
}

sub _config_val {
  my ($self, $val, $template) = @_;
  return ref $template eq 'ARRAY' ? [split $template->[0], $val] : $val;
}

sub _merge_config_map {
  my ($self, $source, $target) = @_;

  for my $k (sort keys %$source) {
    if (!defined $source->{$k}) {
      delete $target->{$k};
    }
    elsif (ref $source->{$k} eq 'HASH') {
      $self->_merge_config_map($source->{$k}, $target->{$k} ||= {});
    }
    elsif (ref $source->{$k} eq 'CODE') {
      $target->{$k} = $source->{$k};
    }
  }
}

sub _parse_environment_file {
  my ($self, $file) = @_;
  warn sprintf "[Systemd] EnvironmentFile=%s\n", $file if DEBUG;

  my $flag = $file =~ s!^(-)!! ? $1 : '';
  return if $flag eq '-' and !-r $file;

  my $FH = path($file)->open;
  while (<$FH>) {
    $self->_set_environment($1, $2) if /^(\w+)=(.*)/;
  }
}

sub _parse_unit_file {
  my ($self, $file) = @_;

  warn sprintf "[Systemd] SYSTEMD_UNIT_FILE=%s\n", $file if DEBUG;
  my $UNIT = path($file || 'SYSTEMD_UNIT_FILE_MISSING')->open;
  while (<$UNIT>) {
    $self->_set_multiple_environment($1)       if /^\s*\bEnvironment=(.+)/;
    $self->_parse_environment_file(unquote $1) if /^\s*\bEnvironmentFile=(.+)/;
    $self->_unset_multiple_environment($1)     if /^\s*\bUnsetEnvironment=(.+)/;
  }
}

sub _set_environment {
  my ($self, $key, $val) = @_;
  warn sprintf "[Systemd] set %s=%s\n", $key, unquote($val // 'undef') if DEBUG;
  $ENV{$key} = unquote $val;
}

sub _set_multiple_environment {
  my ($self, $str) = @_;

  # "FOO=word1 word2" BAR=word3 "BAZ=$word 5 6" FOO="w=1"
  while ($str =~ m!("[^"]*"|\w+=\S+)!g) {
    my $expr = unquote $1;
    $self->_set_environment($1, $2) if $expr =~ /^(\w+)=(.*)/;
  }
}

sub _unset_multiple_environment {
  my ($self, $str) = @_;

  for my $k (map { trim unquote $_ } grep {length} split /\s+/, $str) {
    warn sprintf "[Systemd] unset %s\n", $k if DEBUG;
    delete $ENV{$k};
  }
}

1;
