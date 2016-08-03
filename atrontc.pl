#!/usr/bin/perl
use File::Find;
use MP3::Tag;
use Encode qw( encode decode );

my $share = "/mnt/array1/pub";
my $folder = "music";
my $toc = "atrontc.vtc";

%songs = ( );

sub find_music {
    # parse file name
    my $path = decode('utf-8', $_);
    my($dir, $file, $ext) = ($path =~ m"^(.*/)(.*)(\.mp3|\.m3u|\.wma|\.wav)$");
    return if $ext eq '';

    # create a new song
    $dir =~ tr/\//\\/;
    my $key = $file . $ext . $dir;

    $songs{$key}{DIR} = $dir;
    $songs{$key}{FILE} = $file . $ext;

    # generate MP3::Tag entry
    if ($ext eq '.mp3' ) {
	# read tags from file if possible
        my $mp3 = MP3::Tag->new($_);
        $mp3->get_tags();
        my $tags = $mp3->{ID3v2} if exists $mp3->{ID3v2};

        # use file name if no tag
        $songs{$key}{TIT2} = $tags->title() || $file;

        # get album name
        $songs{$key}{TALB} = $tags->album();

        # use first genre
        $songs{$key}{TCON} = (split(/;/, $tags->genre()))[0];

        # combine disc with track number to ensure proper order on AT
        $songs{$key}{TRCK} = (split(/\//, $tags->get_frame('TPOS')))[0] . sprintf('%02d', (split(/\//, $tags->track()))[0]);

        # select the most representative artist for the track
        my $artists = $tags->get_frame('TPE2') . ';' . $tags->get_frame('TPE1');
        if ($genre eq "Classical") {
            $artists = $tags->get_frame('TCOM') . ';' . $artists
        }
        foreach $item (split(/;/, $artists)) {
	    if ($item ne '' && $item !~ /^Vario/) {
		$songs{$key}{TPE1} = $item;
                last;
            }
        }
    }

    # generate Audio::WMA entry
    if ($ext eq '.wma' ) {
        $songs{$key}{TIT2} = $file;
    }

    # generate Audio::Wav entry
    if ($ext eq '.wav' ) {
        $songs{$key}{TIT2} = $file;
    }

    # generate M3U entry
    if ($ext eq '.m3u' ) {
        $songs{$key}{TIT2} = $file;
    }
}

sub gen_toc {
    open(TOC, '>:encoding(cp1252)', $toc)
      || die "Can't open TOC for writing: $!";

    foreach my $key (sort keys %songs) {
        print TOC "SONG\nFILE=$songs{$key}{FILE}\nDIR =$songs{$key}{DIR}\nTIT2=$songs{$key}{TIT2}\n";
        print TOC "TALB=$songs{$key}{TALB}\n" if ($songs{$key}{TALB});
        print TOC "TPE1=$songs{$key}{TPE1}\n" if ($songs{$key}{TPE1});
        print TOC "TCON=$songs{$key}{TCON}\n" if ($songs{$key}{TCON});
        print TOC "TRCK=$songs{$key}{TRCK}\n" if ($songs{$key}{TRCK});
        print TOC "END \n";
    }
    print TOC "[End TOC]\n\r";

    close(TOC);
}

# look for changed files
chdir $share;
if ((! -e $toc) || `find $folder -newer $toc|wc -l` + 0) {
    find({ wanted=>\&find_music, no_chdir=>1 }, $folder);
    gen_toc();
}
