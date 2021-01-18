#########################################################################
# Makefile for project patchsaas
# Created: 2021-01-15
# Copyright (c) Edmonton Public Library 2021
# The Edmonton Public Library respectfully acknowledges that we sit on
# Treaty 6 territory, traditional lands of First Nations and Metis people.
#
#<one line to give the program's name and a brief idea of what it does.>
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
LOCAL=~/projects/patchsaas/
APP=patchsaas.sh
.PHONY: test

test:
	cp ${APP} ${HOME}
	# cp testscript.sh.orig testscript.sh
    

