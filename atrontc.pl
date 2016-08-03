#!/usr/bin/perl
use File::Find;
use File::Basename;
use MP3::Tag;
use Encode qw( encode decode );

my $base = "/mnt/array1/pub";
my $folder = "music";
my $toc = "atrontc.vtc";

sub find_music {
    # parse file name
    my($file, $dir, $ext) = fileparse(decode('utf-8', $_), qr/\.[^.]*/);
    $dir =~ tr/\//\\/;
    $ext = lc($ext);

    # generate MP3::Tag entry
    if ($ext eq '.mp3' ) {
	# read tags from file if possible
        my $mp3 = MP3::Tag->new($_);
        $mp3->get_tags();
        my $tags = $mp3->{ID3v2} if exists $mp3->{ID3v2};

        # use file name if no tag
        my $title = $tags->title() || $file;

        # use No Album if no tag
        my $album = $tags->album() || 'No Album';

        # use No Genre if no tag
        my $genre = (split(/;/, $tags->genre()))[0] || 'No Genre';

        # combine disc with track number to ensure proper order on AT
        my $track = (split(/\//, $tags->get_frame('TPOS')))[0] . sprintf('%02d', (split(/\//, $tags->track()))[0]) + 0;

        # select the most representative artist for the track
        my $artist;
        my $artists = $tags->get_frame('TPE2') . ';' . $tags->get_frame('TPE1') . ';No Artist';
        if ($genre eq "Classical") {
            $artists = $tags->get_frame('TCOM') . ';' . $artists
        }
        foreach $item (split(/;/, $artists)) {
	    if ($item ne '' && $item !~ /^Vario/) {
		$artist = $item;
                last;
            }
        }

        # add this TOC entry
        print TOC "SONG\nFILE=$file$ext\nDIR =$dir\nTIT2=$title\nTALB=$album\nTPE1=$artist\nTCON=$genre\nTRCK=$track\nEND \n";
    }

    # generate Audio::WMA entry
    if ($ext eq '.wma' ) {
        my $title = $file;
        my $album = 'No Album';
        my $genre = 'No Genre';
        my $track = 0;
        my $artist = 'No Artist';

        # add this TOC entry
        print TOC "SONG\nFILE=$file$ext\nDIR =$dir\nTIT2=$title\nTALB=$album\nTPE1=$artist\nTCON=$genre\nTRCK=$track\nEND \n";
    }

    # generate Audio::Wav entry
    if ($ext eq '.wav' ) {
        my $title = $file;
        my $album = 'No Album';
        my $genre = 'No Genre';
        my $track = 0;
        my $artist = 'No Artist';

        # add this TOC entry
        print TOC "SONG\nFILE=$file$ext\nDIR =$dir\nTIT2=$title\nTALB=$album\nTPE1=$artist\nTCON=$genre\nTRCK=$track\nEND \n";
    }

    # generate M3U entry
    if ($ext eq '.m3u' ) {
        my $title = $file;

        # add this TOC entry
        print TOC "SONG\nFILE=$file$ext\nDIR =$dir\nTIT2=$title\nEND \n";
    }
}

# look for changed files
chdir $base;
if ((! -e $toc) || `find $folder -newer $toc|wc -l` + 0) {
    open(TOC, '>:encoding(cp1252)', $toc)
      || die "Can't open TOC for writing: $!";

    find({ wanted=>\&find_music, no_chdir=>1 }, $folder);
    print TOC "[End TOC]\n\r";

    close(TOC);
}