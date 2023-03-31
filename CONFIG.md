# Configuration file

## Format

Command | arg1 | arg2 | arg3

## Contexts

Head: first lines, without delimiter

Content: first HEAD command

Section: every checking group. Starts with command HEAD and ends in next HEAD command or in the end of file

## Commands

| Context | Key         | Description                                                                                    | Args | Arg 1    | Arg 2          | Arg 3                      |
| ------- | ----------- | ---------------------------------------------------------------------------------------------- | ---- | -------- | -------------- | -------------------------- |
| Head    | OUTDIR      | Directory where to put generated files                                                         | 1    | path     |                |                            |
| Head    | TITLE       | Page title                                                                                     | 1    | text     |                |                            |
| Head    | TEMPLATE    | Template/theme name                                                                            | 1    | dir name |                |                            |
| Head    | BOT         | Group to send messave via bot | 2 | text service | text group | |
| Content | HEAD        | Open a new section, with this title                                                            | 1    | text     |                |                            |
| Section | HOST        | Check status via ping (ICMP)                                                                   | 1    | text     | IP or hostname |                            |
| Section | WEB         | Check HTTP status                                                                              | 3    | text     | URL            | int - expected status code |
| Section | PORT        | Check TCP port                                                                                 | 3    | text     | IP or hostname | int - port number          |
| Head    | 1HOSTGROOUP | Create a section with all hosts in a NH1 hostgroup for ping test                               | 2    | text     | Group name     |                            |
| Head    | 1HGPORT     | Create a section with all hosts in a NH1 hostgroup for port checking (same port for all hosts) | 3    | text     | Group name     | Port number                |
