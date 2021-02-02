# Added code to read Symphony environment vars relatively to HOME.
/use strict;/achomp($ENV{'HOME'} = `. ~/.bashrc; echo ~`);\nopen(my $IN, "<", "$ENV{'HOME'}/Unicorn/Config/environ") or die "$0: $! \$ENV{'HOME'}/Unicorn/Config/environ\\n";\nwhile(<$IN>)\n{\n    chomp;\n    my ($key, $value) = split(/=/, $_);\n    $ENV{$key} = "$value";\n}
