requires "Digest" => "0";
requires "Exporter" => "0";
requires "File::Spec::Functions" => "0";
requires "FindBin" => "0";
requires "JSON::Validator" => "3.02";
requires "Mojolicious" => "7.79";
requires "Mojolicious::Plugin::OpenAPI" => "2.08";
requires "Role::Tiny" => "2.000001";
requires "Scalar::Util" => "0";
requires "Sys::Hostname" => "0";
requires "Text::Balanced" => "0";
requires "perl" => "5.014";

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
