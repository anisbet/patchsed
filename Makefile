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
TEST_SERVER=edpl-t.library.ualberta.ca
USER=sirsi
LOCAL=~/projects/patchsed
APP=patchsed.sh
.PHONY: test production

test:
	cp ${LOCAL}/${APP} ${HOME}
	scp ${LOCAL}/${APP} ${USER}@${TEST_SERVER}:~/
	
production: ${APP}  
	scp ${LOCAL}/${APP} ${USER}@${PRODUCTION_SERVER}:~/

