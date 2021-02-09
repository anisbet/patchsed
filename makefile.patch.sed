# Comment out old host name and add new host name. Change all Makefile instances of /s/sirsi to '~'.
s/[A-Z_]*=eplapp.library.ualberta.ca/&\n# &/
s/eplapp.library.ualberta.ca/edpl.sirsidynix.net/
s:/s/sirsi:~:g