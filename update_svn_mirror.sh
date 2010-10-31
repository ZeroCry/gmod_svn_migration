#!/bin/sh
rsync -avz --compress-level=9 gmod.svn.sourceforge.net::svn/gmod/* svn_backup/
