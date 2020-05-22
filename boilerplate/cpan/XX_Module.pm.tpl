## no critic
=for JFTR

    It's absolute nonsense to use Perl::Critic for legacy modules
    if you are really interested in such messages, use --force for perlcritic

=cut
[% IF license %]
=for LICENSE

    SPDX-License-Identifier: [% license.id %]

    [% license.name %]
    <[% license.uri %]>

    [% license.text %]

=cut
[% END %]
# $Id$

use lib q{./lib};
use warnings FATAL => 'all';
use strict;
use [% package.full_name %];
use English q{-no_match_vars};

sub [% name %]_Initialize {
    return [% package.full_name %](@ARG);
}

1;

