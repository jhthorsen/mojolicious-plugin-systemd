# NAME

Mojolicious::Plugin::Systemd - Configure your app from within systemd service file

# SYNOPSIS

## Example application

    package MyApp;
    use Mojo::Base "Mojolicious";
    sub startup {
      my $app = shift;
      $app->plugin("Systemd");
    }

## Example systemd unit file

    [Unit]
    Description=MyApp service
    After=network.target

    [Service]
    Environment=SYSTEMD_SERVICE_FILE=/etc/systemd/system/my_app.service
    Environment=MOJO_SERVER_PID_FILE=/var/run/my_app.pid
    Environment=MYAPP_HOME=/var/my_app
    EnvironmentFile=-/etc/default/my_app

    User=www
    Type=forking
    PIDFile=/var/run/my_app.pid
    ExecStart=/path/to/hypnotoad /home/myapp/script/my_app
    ExecReload=/path/to/hypnotoad /home/myapp/script/my_app
    KillMode=process
    SyslogIdentifier=my_app

    [Install]
    WantedBy=multi-user.target

# DESCRIPTION

[Mojolicious::Plugin::Systemd](https://metacpan.org/pod/Mojolicious::Plugin::Systemd) is a [Mojolicious](https://metacpan.org/pod/Mojolicious) plugin that allows your
application to read configuration from a Systemd service (unit) file.

It works by parsing the `Environment`, `EnvironmentFile` and
`UnsetEnvironment` statements in the service file and inject those environment
variables into your application. This is especially useful if your application
is run by [Mojo::Server::Hypnotoad](https://metacpan.org/pod/Mojo::Server::Hypnotoad), since you cannot "inject" environment
variables into a running application, meaning `SOME_VAR` below won't change
anything in your already started application:

    $ SOME_VAR=42 /path/to/hypnotoad /home/sri/myapp/script/my_app

See [http://manpages.ubuntu.com/manpages/cosmic/man5/systemd.exec.5.html#environment](http://manpages.ubuntu.com/manpages/cosmic/man5/systemd.exec.5.html#environment)
for more information about `Environment`, `EnvironmentFile` and `UnsetEnvironment`.

# ATTRIBUTES

## config\_map

    $hash_ref = $self->config_map;

Returns a structure for how ["config" in Mojolicious](https://metacpan.org/pod/Mojolicious#config) can be set from environment
variables. By default the environment variables below are supported:

    $app->config->{hypnotoad}{accepts}            = $ENV{MOJO_SERVER_ACCEPTS}
    $app->config->{hypnotoad}{backlog}            = $ENV{MOJO_SERVER_BACKLOG}
    $app->config->{hypnotoad}{clients}            = $ENV{MOJO_SERVER_CLIENTS}
    $app->config->{hypnotoad}{graceful_timeout}   = $ENV{MOJO_SERVER_GRACEFUL_TIMEOUT}
    $app->config->{hypnotoad}{heartbeat_interval} = $ENV{MOJO_SERVER_HEARTBEAT_INTERVAL}
    $app->config->{hypnotoad}{heartbeat_timeout}  = $ENV{MOJO_SERVER_HEARTBEAT_TIMEOUT}
    $app->config->{hypnotoad}{inactivity_timeout} = $ENV{MOJO_SERVER_INACTIVITY_TIMEOUT}
    $app->config->{hypnotoad}{listen}             = [split /\s+/, $ENV{MOJO_LISTEN}];
    $app->config->{hypnotoad}{pid_file}           = $ENV{MOJO_SERVER_PID_FILE}
    $app->config->{hypnotoad}{proxy}              = $ENV{MOJO_SERVER_PROXY}
    $app->config->{hypnotoad}{requests}           = $ENV{MOJO_SERVER_REQUESTS}
    $app->config->{hypnotoad}{spare}              = $ENV{MOJO_SERVER_SPARE}
    $app->config->{hypnotoad}{upgrade_timeout}    = $ENV{MOJO_SERVER_UPGRADE_TIMEOUT}
    $app->config->{hypnotoad}{workers}            = $ENV{MOJO_SERVER_WORKERS}

# METHODS

## register

    $app->plugin("Systemd");
    $app->plugin("Systemd" => {config_map => {...}, service_file => "..."});

Used to register the plugin in your application. The following options are
otional:

- config\_map

    The `config_map` must be a hash-ref and will be _merged_ with the
    ["config\_map"](#config_map) attribute. Example:

        $app->plugin(Systemd => {
          config_map => {
            # Add your own custom environment variables. The empty quotes means
            # that the environment variable should be read as a string.
            database => {
              url => sub { (MYAPP_DB_URL => "") },
            },
            hypnotoad => {
              # Remove support for the default MOJO_SERVER_ACCEPTS environment
              # variable
              accepts => undef,

              # Change the environment variable from MOJO_LISTEN and
              # the regexp to split the environment variable into a list
              listen  => sub { (MYAPP_LISTEN => [qr{[,\s]}]) },
            }
          }
        });

- service\_file

    Defaults to the environment variable `SYSTEMD_SERVICE_FILE` and _is_ required
    if `XDG_SESSION_ID` is set. Must be a full path to where your service file is
    located. See ["Example systemd unit file"](#example-systemd-unit-file) for example.

# AUTHOR

Jan Henning Thorsen

# COPYRIGHT AND LICENSE

Copyright (C) 2019, Jan Henning Thorsen.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

# SEE ALSO

[Mojolicious](https://metacpan.org/pod/Mojolicious), [Mojolicious::Plugin::Syslog](https://metacpan.org/pod/Mojolicious::Plugin::Syslog).
