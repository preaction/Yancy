requires "File::Spec::Functions" => "0";
requires "FindBin" => "0";
requires "Mojolicious" => "7.15";
requires "Mojolicious::Plugin::OpenAPI" => "1.22";
requires "Sys::Hostname" => "0";
requires "perl" => "5.010";
requires "Mojo::Pg" => "3.0";
requires "Mojo::SQLite" => "3.0";
requires "Mojo::mysql" => "1.0";

on 'test' => sub {
  requires "ExtUtils::MakeMaker" => "0";
  requires "File::Spec" => "0";
  requires "IO::Handle" => "0";
  requires "IPC::Open3" => "0";
  requires "Test::More" => "1.001005";
};

on 'test' => sub {
  recommends "CPAN::Meta" => "2.120900";
};

on 'configure' => sub {
  requires "ExtUtils::MakeMaker" => "0";
  requires "File::ShareDir::Install" => "0.06";
};
