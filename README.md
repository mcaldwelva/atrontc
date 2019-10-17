# atrontc
This is an AudioTron TOC file generator. It is intended to solve two problems: 1) allow the AT to discover music as fast as possible and 2) bypass the limited indexing capabilities of the AT

## Usage
* This script has minimal dependencies and is likely to run wherever you have Perl 5.
* It will only generate a new TOC if files are added since the last TOC file was created, so it can safely run as a cron job.
* It can be customized to combine tags in any way that you find useful.