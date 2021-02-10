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
PRODUCTION_SERVER=eplapp.library.ualberta.ca
PRODUCTION_SAAS_SERVER=edpl.sirsidynix.net
TEST_SERVER=edpl-t.library.ualberta.ca
USER=sirsi
LOCAL=~/projects/patchsed
APP=patchsed.sh

SAAS_CHANGES=all_scripts.patch.ilsdev1.edpl.sed
PERL_CHANGES=perl.patch.all_servers.sed

.PHONY: test production saas local

test: ${APP} ${PERL_CHANGES} ${SAAS_CHANGES}
	cp ${LOCAL}/${APP} ${HOME}
	cp ${LOCAL}/${PERL_CHANGES} ${HOME}
	cp ${LOCAL}/${SAAS_CHANGES} ${HOME}
	scp ${LOCAL}/${APP} ${USER}@${TEST_SERVER}:~/
	scp ${LOCAL}/${PERL_CHANGES} ${USER}@${TEST_SERVER}:~/

local: ${APP}
	cp ${LOCAL}/${APP} ${HOME}
	cp ${LOCAL}/${PERL_CHANGES} ${HOME}
	cp ${LOCAL}/${SAAS_CHANGES} ${HOME}
    
eplapp: ${APP} ${PERL_CHANGES}
	scp ${LOCAL}/${APP} ${USER}@${PRODUCTION_SERVER}:~/
	scp ${LOCAL}/${PERL_CHANGES} ${USER}@${PRODUCTION_SERVER}:~/

edpl: ${APP} ${PERL_CHANGES} ${SAAS_CHANGES}
	scp ${LOCAL}/${APP} ${USER}@${PRODUCTION_SAAS_SERVER}:~/
	scp ${LOCAL}/${SAAS_CHANGES} ${USER}@${PRODUCTION_SAAS_SERVER}:~/
	scp ${LOCAL}/${PERL_CHANGES} ${USER}@${PRODUCTION_SAAS_SERVER}:~/
	