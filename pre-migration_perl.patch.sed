# Added code to read Symphony environment vars relatively to HOME. Comment out lines that assign ENV values set by Unicorn/Config/environ.
2,$ s/^\$ENV{/# \$ENV{/
/use strict;/achomp($ENV{'HOME'} = `. ~/.bashrc; echo ~`);\nopen(my $IN, "<", "$ENV{'HOME'}/Unicorn/Config/environ") or die "$0: $! \$ENV{'HOME'}/Unicorn/Config/environ\\n";\nwhile(<$IN>)\n{\n    chomp;\n    my ($key, $value) = split(/=/, $_);\n    $ENV{$key} = "$value";\n}\nclose($IN);
# Change '/s/sirsi' to '~', but not on she-bang.
2,$ s:/s/sirsi:~:g