# rds-instance-from-snapshot
Unconventional, quick and dirty POC app to restore RDS databases from snapshots with minimal settings using Ruby glimmer-dsl-libui as an alternative to the restore-rds-db-from-snapshot Python repo.

### Requirements ###

- Ruby 3.x 

### Notes ###
Currently, the clearing of the databases and snapshots row_data causes logging of the following error when rows are selected in the table:
```
(ruby:750467): Gtk-CRITICAL **: 10:14:44.319: file ../../../gtk/a11y/gtktreeviewaccessible.c: line 343 (set_cell_data): should not be reached
```
