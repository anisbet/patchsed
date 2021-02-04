#########################################################################
# Makefile for project patchsed
# Created: 2021-01-15
# Copyright (c) Edmonton Public Library 2021
# The Edmonton Public Library respectfully acknowledges that we sit on
# Treaty 6 territory, traditional lands of First Nations and Metis people.
#
# Uses sed scripts to make edits on regular files and files in git repos.
#
#    Copyright (C) 2021  Andrew Nisbet, Edmonton Public Library
# The Edmonton Public Library respectfully acknowledges that we sit on
# Treaty 6 territory, traditional lands of First Nations and Metis people.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA 02110-1301, USA.
#
#      0.0 - Dev.
#########################################################################
PRODUCTION_SERVER=edpl.sirsidynix.net
# PRODUCTION_SERVER=eplapp.library.ualberta.ca
PRODUCTION_SAAS_SERVER=edpl.sirsidynix.net
TEST_SERVER=edpl-t.library.ualberta.ca
USER=sirsi
LOCAL=~/projects/patchsed
APP=patchsed.sh

PRE_BASH=pre-migration_bash.patch.sed
PRE_PERL=pre-migration_perl.patch.sed
POST_PERL=post-migration_perl.patch.sed
PRE_MAKEFILE=pre-migration_Makefile.patch.sed

.PHONY: test production saas local

test: ${APP} ${PRE_PERL} ${PRE_PERL} ${PRE_BASH} 
	cp ${LOCAL}/${APP} ${HOME}
	scp ${LOCAL}/${APP} ${USER}@${TEST_SERVER}:~/
	scp ${LOCAL}/${PRE_PERL} ${USER}@${TEST_SERVER}:~/
	# For testing. This will break perl scripts on edpl-t.
	scp ${LOCAL}/${POST_PERL} ${USER}@${TEST_SERVER}:~/
	scp ${LOCAL}/${PRE_BASH} ${USER}@${TEST_SERVER}:~/
    
local: ${PRE_BASH} ${PRE_MAKEFILE}
	# Can use -b master.
	cp ${LOCAL}/${PRE_MAKEFILE} ${HOME}
	# Especially if the bash_scripts run remotely, but use -bSAAS
	cp ${LOCAL}/${PRE_BASH} ${HOME}
	# but use -bSAAS
	cp ${LOCAL}/${PRE_PERL} ${HOME}
	# but use -bSAAS
	cp ${LOCAL}/${POST_PERL} ${HOME}
	
production: ${APP}  ${PRE_PERL} ${PRE_BASH}
	scp ${LOCAL}/${APP} ${USER}@${PRODUCTION_SERVER}:~/
	scp ${LOCAL}/${PRE_PERL} ${USER}@${PRODUCTION_SERVER}:~/
	scp ${LOCAL}/${PRE_BASH} ${USER}@${PRODUCTION_SERVER}:~/

saas: ${APP}  ${POST_PERL}
	scp ${LOCAL}/${APP} ${USER}@${PRODUCTION_SAAS_SERVER}:~/
	scp ${LOCAL}/${POST_PERL} ${USER}@${PRODUCTION_SAAS_SERVER}:~/