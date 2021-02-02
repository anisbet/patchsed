# Change all non-she-bang /s/sirsi to $ENV{'HOME'}. Added code to read Symphony environment vars relatively to HOME.
2,$ s:/s/sirsi:$ENV{'HOME'}:g
/use strict;/achomp($ENV{'HOME'} = `. ~/.bashrc; echo ~`);\nopen(my $IN, "<", "$ENV{'HOME'}/Unicorn/Config/environ") or die "$0: $! \$ENV{'HOME'}/Unicorn/Config/environ\\n";\nwhile(<$IN>)\n{\n    chomp;\n    my ($key, $value) = split(/=/, $_);\n    $ENV{$key} = "$value";\n}
