package FHEM::CLI::Template;
################################################## pragmas
use strict;
use warnings FATAL => 'all';
use 5.0140;

################################################## core modules
use English qw{-no_match_vars};
use Carp;
use List::Util;
use File::Find;
use File::Basename;
use File::Path;
use File::Slurp;
use Text::Wrap;
use Data::Dumper;

################################################## non-core modules
use Template;
use Readonly;
use JSON::MaybeXS;
use File::Util qw{SL};

################################################## default settings
Readonly our $VERSION                   => q{0.0.1};
Readonly our $DEFAULT_BOILERPLATE       => q{cpan};
Readonly our @VALID_BOILERPLATE_MODES   => qw{legacy cpan package};
Readonly our $LICENSE_DIR               => q{licenses};
Readonly our $LICENSE_FILE_EXT          => q{.json};
Readonly our $WRAP_COLUMNS              => 80;
Readonly our $WRAP_LICENSE_SEPARATOR    => qq{\n\t};

################################################## package global variables
my $config = {
    q{boilerplate_mode}     => $DEFAULT_BOILERPLATE,
    q{module_name}          => undef,
    q{module_full_name}     => undef,
    q{module_path}          => undef,
    q{module_license}       => undef,
    q{force_create}         => 0,
    q{module_real_path}     => undef,
    q{magic_number}         => undef,
    q{package}              => undef,
    q{package_full}         => undef,
    q{package_file_path}    => undef,
    q{stub_file_path}       => undef,
};

################################################## helper

sub get_config {
    my $config_key = shift || undef;

    if ($config_key && !defined $config->{$config_key}) {
        carp(qq{$config_key is not set in \$config})           # not a ref, just an escape
    }

    if ($config_key) {
        return $config->{$config_key};
    }

    return $config;
}

sub set_config {
    my $config_key = shift;
    my $config_value = shift;
    $config->{$config_key} = $config_value;
    return;
}

sub set_force_create {
    my $arg_name            = shift;
    my $arg_value           = shift;
    $config->{force_create} = $arg_value;
    return;
}

sub get_licenses {
    my @available_licenses;

    my $wanted = sub {
        push @available_licenses, basename($ARG, qq{$LICENSE_FILE_EXT});
    };

    find($wanted, $LICENSE_DIR);

    return @available_licenses;
}

sub check_module_name {
    my $arg_name    = shift;
    my $arg_value =  shift;

    #todo   Check module name sanity
    # extract the @#$%&! magic number
    if ($arg_value =~ qr{ ^(?<magic_number>\d{2})_(?<module_name>.+)$ }xms) {
        $config->{magic_number}     = $LAST_PAREN_MATCH{magic_number};
        $config->{module_name}      = $LAST_PAREN_MATCH{module_name};
        $config->{module_full_name} = $arg_value;
        return;
    }

    croak(qq{$arg_value doesn't look like a valid FHEM module name});
}

sub set_boilerplate {
    my $arg_name    = shift;
    my $arg_value   = shift;

    if ( !List::Util::any { $ARG eq $arg_value } @VALID_BOILERPLATE_MODES ) {
        croak(qq{$arg_value is not a valid choice for 'mode'. Choose one of: @VALID_BOILERPLATE_MODES} );
    }

    $config->{boilerplate_mode} = $arg_value;
    return;
}

sub set_module_path {
    my $arg_name    = shift;
    my $arg_value   = shift;

    if (!-d qq{$arg_value}) {
        croak(qq{Directory '$arg_value' does not exist})
    }

    if (!-w qq{$arg_value}) {
        croak(qq{$arg_value is not writeable for user id $UID});
    }

    $config->{module_path} = $arg_value;
    say Dumper($config->{module_path});
    return;
}

sub set_license {
    my $attr_name = shift;
    my $attr_val = shift;

    if (!List::Util::any { $attr_val eq $ARG }  get_licenses() ) {
        croak(qq{$attr_val is not a known license});
    }

    $config->{module_license} = $attr_val;
    return;
}

sub list_licenses {
    for my $license ( sort(get_licenses())) {
        say $license;
    }
    exit 0;
}

sub get_license_vars {
    my $license_id = shift;

    # build path to the license
    my $license_path = join( SL,
        $FHEM::CLI::Template::LICENSE_DIR,
        $license_id,
    ) . $FHEM::CLI::Template::LICENSE_FILE_EXT;

    if (!-e qq{$license_path}) {
        croak(qq{License $license_id chosen, but not available at $license_path});
    }

    my $license;
    my $license_eval = eval { $license = decode_json(read_file($license_path)) };

    if (!$license_eval) {
        croak(qq{$EVAL_ERROR});
    }

    # set (local) config for Text::Wrap
    # there is no other way to do it ATM, so silence Perl::Critic for a second
    ## no critic (Variables::ProhibitPackageVars)
    local $Text::Wrap::columns    =   $WRAP_COLUMNS;
    local $Text::Wrap::separator  =   $WRAP_LICENSE_SEPARATOR;
    ## use critic

    return {
        'id'    => $license_id,
        'name'  => $license->{name},
        'text'  => wrap(q{}, q{}, $license->{licenseText}),
        'uri'   => $license->{url},
    };

}

sub set_package_name {
    my $attr_name = shift;
    my $attr_val  = shift;
    $config->{package_full} = $attr_val;
    $config->{package} = [split qr{::}xms, $attr_val];
    return;
}

sub create_dir {
    my $dir = shift;

    # remove a file if supplied, we only want to create a directory
    $dir = dirname($dir);

    # croak/carp if directory alreday exists
    croak(qq{$dir already exists}) if(!$config->{force_create});
    carp(qq{$dir already exists, but ignored because of --force}) if($config->{force_create});

    # create recursive with make_path(), built-in mkdir does not support it
    my $make_path_error;                        # save error messages
    my @created_dirs = File::Path::make_path($dir, {
        q{verbose}  => 1,
        q{error}    => \$make_path_error,
    });

    # warn if no directory was created
    if (scalar @created_dirs == 0) {
        carp(qq{$dir was not created});
    }

    # and croak if errors happened
    if ($make_path_error && @{$make_path_error}){
        croak("1 @{$make_path_error}");
    }

    return;
}

1;

__END__
