#!/usr/bin/perl
use strict 'refs';
use warnings FATAL => 'all';
use lib q{lib/};
use experimental qw{switch};
use 5.0140;

################################################## core modules
use Getopt::Long;
use English qw{-no_match_vars};
use Carp;
use Data::Dumper;

################################################## non-core modules
use Readonly;
use File::Util qw{SL};
use FHEM::CLI::Template;

################################################## default settings
Readonly our $VERSION                   => $FHEM::CLI::Template::VERSION;
my $template_vars                       = undef;        # container for template::toolkit
my $files_for_replace                   = undef;        # container for files to replaces

################################################## option handling
GetOptions(
    q{mode|m=s}         => \&FHEM::CLI::Template::set_boilerplate,
    q{name|n=s}         => \&FHEM::CLI::Template::check_module_name,
    q{path|p=s}         => \&FHEM::CLI::Template::set_module_path,
    q{license|l=s}      => \&FHEM::CLI::Template::set_license,
    q{list-licenses}    => \&FHEM::CLI::Template::list_licenses,
    q{package|c=s}      => \&FHEM::CLI::Template::set_package_name,
    q{force!}           => \&FHEM::CLI::Template::set_force_create,
);

# check for module name and populate to $template_vars
if (!FHEM::CLI::Template::get_config(q{module_name})) {
    croak(q{No module name provided, use -n});
}

$template_vars->{name} = FHEM::CLI::Template::get_config(q{module_name});

if (!FHEM::CLI::Template::get_config(q{module_path})) {
    croak(q{No module path provided, use -p});
}

FHEM::CLI::Template::set_config(q{module_real_path},
    join SL, (
        FHEM::CLI::Template::get_config(q{module_path}),
        FHEM::CLI::Template::get_config(q{module_full_name}),
    ),
);

# create necessary configuration and directories
for (FHEM::CLI::Template::get_config(q{boilerplate_mode})) {
    when (qr{(?:package|legacy)}xms) {
        # create path to the package file
        FHEM::CLI::Template::set_config(q{package_file_path},
            join SL, (
                FHEM::CLI::Template::get_config(q{module_real_path}),
                FHEM::CLI::Template::get_config(q{module_full_name}) . q{.pm}
            )
        );

        $files_for_replace = {
            'module_file'   => {
                q{source}   => q{boilerplate} . SL . FHEM::CLI::Template::get_config(q{boilerplate_mode}) . SL . q{XX_Module.pm.tpl},
                q{target}   => FHEM::CLI::Template::get_config(q{package_file_path}),
            }
        };

        if (FHEM::CLI::Template::get_config(q{boilerplate_mode}) eq q{package}) {
            say "package!";
            $template_vars->{package} ={
                q{full_name}    => FHEM::CLI::Template::get_config(q{package_full}),
            } ;
        }
    }

    when (q{cpan}) {
        # create path to the legacy wrapper stub file
        FHEM::CLI::Template::set_config(q{stub_file_path},
            join SL, (
                FHEM::CLI::Template::get_config(q{module_real_path}),
                q{FHEM},
                FHEM::CLI::Template::get_config(q{module_full_name}) . q{.pm}
            )
        );

        # create path to the lib
        if (!scalar FHEM::CLI::Template::get_config(q{package})) {
            croak(q{Mode 'cpan' needs an package name});
        }

        # create path the the package
        FHEM::CLI::Template::set_config(q{package_file_path},
            join q{.}, (
                join( SL, (
                    FHEM::CLI::Template::get_config(q{module_real_path}),
                    q{lib},
                    @{FHEM::CLI::Template::get_config(q{package})},
                )),
                q{pm},
            )
        );

        # create director(ies|y) beyond lib/
        FHEM::CLI::Template::create_dir(FHEM::CLI::Template::get_config(q{package_file_path}));

        # create stub file directory
        FHEM::CLI::Template::create_dir(FHEM::CLI::Template::get_config(q{stub_file_path}));

        $files_for_replace = {
            'module_file'   => {
                q{source}   => q{boilerplate} . SL . FHEM::CLI::Template::get_config(q{boilerplate_mode}) . SL . q{Package.pm.tpl},
                q{target}   => FHEM::CLI::Template::get_config(q{package_file_path}),
            },
            'stub_file'     => {
                q{source}   => q{boilerplate} . SL . FHEM::CLI::Template::get_config(q{boilerplate_mode}) . SL . q{XX_Module.pm.tpl},
                q{target}   => FHEM::CLI::Template::get_config(q{stub_file_path}),
            },
        };
    }
}

# handle license
if (FHEM::CLI::Template::get_config(q{module_license})) {
    $template_vars->{license} = FHEM::CLI::Template::get_license_vars(
        FHEM::CLI::Template::get_config(q{module_license})
    );
}



if ($files_for_replace) {
    my $template_object =  Template->new({
        INTERPOLATE  => 0,
    }) || croak qq{$Template::ERROR};

    # and now, replace for every file
    for my $file (keys %{$files_for_replace}) {
        say Dumper($files_for_replace->{$file});
        $template_object->process(
            $files_for_replace->{$file}{source},
            $template_vars,
            $files_for_replace->{$file}{target}
        ) or croak($template_object->error());
    }
}

say Dumper(FHEM::CLI::Template::get_config());
say Dumper($template_vars);
say Dumper($files_for_replace);

__END__
=pod

=head1 AUTHOR

=head1 LICENSE AND COPYRIGHT

=head1 NAME

=head1 USAGE

=head1 DESCRIPTION

=head1 REQUIRED ARGUMENTS

=head1 OPTIONS

=head1 DIAGNOSTICS

=head1 EXIT STATUS

=head1 CONFIGURATION

=head1 DEPENDENCIES

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=cut
