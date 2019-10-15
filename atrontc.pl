#!/usr/bin/perl
use File::Find;
use File::Basename;
use Encode qw( encode decode );

# file share root & music folder
my $share = '/mnt/array1/pub';
my $folder = 'music';

# AudioTron login
my $host = 'atron';
my $user = 'atron';
my $pass = 'atronpass';

my $toc = 'atrontc.vtc';
@file_types = qw(.mp3 .m3u .wma .wav);
%songs = ( );


# read ID3 string
my @enc_types = qw( iso-8859-1 UTF-16 UTF-16BE utf8 );
sub readId3Str {
    my ($fh, $count) = @_;

    # encoding type
    read($fh, my $enc, 1);
    $enc = unpack('C', $enc);

    # string value
    read($fh, my $ret, $count - 1);
    $ret = decode($enc_types[$enc], $ret);
    $ret =~ s/[ \x00]+$//;

    return $ret;
}


# read ID3 integer
sub readId3Int {
    my ($fh, $size, $count) = @_;
    my $ret = 0;

    for (my $i = 0; $i < $count; $i++) {
        read($fh, my $c, 1);
        $ret = ($ret << $size) | unpack('C', $c);
    }

    return $ret;
}


# read ID3 tags
sub readId3Tags {
    my ($file) = @_;

    my %tags = ( );
    my $data;

    open(my $fh, '<:raw', $file);

    read($fh, $data, 3);
    return if $data ne 'ID3';

    # major version
    read($fh, $data, 1);
    my $ver = unpack('C', $data);

    # minor version and flags
    read($fh, $data, 2);

    # header size
    my $header_end = tell($fh) + readId3Int($fh, 7, 4);

    # search through tags
    do {
        my $tag;
        my $tag_size;

        if ($ver >= 3) {
            # get id
            read($fh, $tag, 4);

            # get size
            $tag_size = readId3Int($fh, 8, 4);

            # skip flags
            read($fh, $data, 2);
        } else {
            # get id
            read($rh, $tag, 3);

            # get size
            $tag_size = readId3Int($fh, 8, 3);
        }

        # map tag to our structure
        if ($tag eq 'TIT2' || $tag eq 'TT2') {
            $tags{Title} = readId3Str($fh, $tag_size);
        } elsif ($tag eq 'TALB' || $tag eq 'TAL') {
            $tags{Album} = readId3Str($fh, $tag_size);
        } elsif ($tag eq 'TYER' || $tag eq 'TYE') {
            $tags{Year} = readId3Str($fh, $tag_size);
        } elsif ($tag eq 'TCON' || $tag eq 'TCO') {
            $tags{Genre} = readId3Str($fh, $tag_size);
        } elsif ($tag eq 'TPOS' || $tag eq 'TPA') {
            $tags{Disc} = readId3Str($fh, $tag_size);
        } elsif ($tag eq 'TRCK' || $tag eq 'TRK') {
            $tags{Track} = readId3Str($fh, $tag_size);
        } elsif ($tag eq 'TPE1' || $tag eq 'TP1') {
            $tags{TrackArtist} = readId3Str($fh, $tag_size);
        } elsif ($tag eq 'TPE2' || $tag eq 'TP2') {
            $tags{AlbumArtist} = readId3Str($fh, $tag_size);
        } elsif ($tag eq 'TCOM' || $tag eq 'TCM') {
            $tags{Composer} = readId3Str($fh, $tag_size);
        } else {
            seek($fh, tell($fh) + $tag_size, SEEK_SET);
        }
    } while ($tag_size ne 0 && tell($fh) < $header_end);

    close ($fh);
    return %tags;
}


# read ASF string
sub readAsfStr {
    my ($fh, $count) = @_;

    read($fh, my $ret, $count);
    $ret = decode('UTF-16LE', $ret);
    $ret =~ s/[ \x00]+$//;

    return $ret;
}


# read ASF tags
my $ASF_Header_Object = "\x30\x26\xB2\x75\x8E\x66\xCF\x11\xA6\xD9\x00\xAA\x00\x62\xCE\x6C";
my $ASF_Content_Description_Object = "\x33\x26\xB2\x75\x8E\x66\xCF\x11\xA6\xD9\x00\xAA\x00\x62\xCE\x6C";
my $ASF_Extended_Content_Description_Object = "\x40\xA4\xD0\xD2\x07\xE3\xD2\x11\x97\xF0\x00\xA0\xC9\x5E\xA8\x50";
sub readAsfTags {
    my ($file) = @_;

    my %tags = ( );
    my $data;

    open(my $fh, '<:raw', $file);

    # Object ID
    read($fh, $data, 16);
    return if $data ne $ASF_Header_Object;

    # Object Size
    seek($fh, tell($fh) + 8, SEEK_SET);

    # Number of Header Objects
    read($fh, $data, 4);
    my $object_count = unpack('V', $data);

    # Reserved Bytes
    seek($fh, tell($fh) + 2, SEEK_SET);

    # for each object
    while ($object_count-- > 0) {
        # Object ID
        read($fh, my $guid, 16);

        # Object Size
        read($fh, $data, 4);
        my $next_object = tell($fh) - 20 + unpack('V', $data);
        seek($fh, tell($fh) + 4, SEEK_SET);

        # check object type
        if ($guid eq $ASF_Content_Description_Object) {
            # Title Length
            read($fh, $data, 2);
            my $title_size = unpack('v', $data);

            # Author Length
            read($fh, $data, 2);
            my $artist_size = unpack('v', $data);

            # Copyright + Description + Rating Length
            seek($fh, tell($fh) + 6, SEEK_SET);

            # Title
            $tags{Title} = readAsfStr($fh, $title_size);

            # Author
            $tags{TrackArtist} = readAsfStr($fh, $artist_size);
        } elsif ($guid eq $ASF_Extended_Content_Description_Object) {
            # Content Descriptors Count
            read($fh, $data, 2);
            my $tag_count = unpack('v', $data);

            while ($tag_count-- > 0) {
                #Descriptor Name Length
                read($fh, $data, 2);
                my $name_size = unpack('v', $data);

                # Descriptor Name
                my $tag = readAsfStr($fh, $name_size);

                # Value Data Type
                seek($fh, tell($fh) + 2, SEEK_SET);

                # Descriptor Value Length
                read($fh, $data, 2);
                my $value_size = unpack('v', $data);

                # Descriptor Value
                if ($tag eq 'WM/AlbumTitle') {
                    $tags{Album} = readAsfStr($fh, $value_size);
                } elsif ($tag eq 'WM/Year') {
                    $tags{Year} = readAsfStr($fh, $value_size);
                } elsif ($tag eq 'WM/Genre') {
                    $tags{Genre} = readAsfStr($fh, $value_size);
                } elsif ($tag eq 'WM/PartOfSet') {
                    $tags{Disc} = readAsfStr($fh, $value_size);
                } elsif ($tag eq 'WM/TrackNumber') {
                    $tags{Track} = readAsfStr($fh, $value_size);
                } elsif ($tag eq 'WM/AlbumArtist') {
                    $tags{AlbumArtist} = readAsfStr($fh, $value_size);
                } elsif ($tag eq 'WM/Composer') {
                    $tags{Composer} = readAsfStr($fh, $value_size);
                } else {
                    seek($fh, tell($fh) + $value_size, SEEK_SET);
                }
            }
        }

        seek($fh, $next_object, SEEK_SET);
    }

    close ($fh);
    return %tags;
}


# add track information to collection
sub find_music {
    # parse file name
    my($file, $dir, $ext) = fileparse(decode('UTF-8', $_), @file_types);
    return if $ext eq '';

    # create a new song
    my $key = $file . $ext . $dir;

    $dir =~ tr/\//\\/;
    $songs{$key}{DIR} = $dir;
    $songs{$key}{FILE} = $file . $ext;
    $ext = lc $ext;

    my %tags;
    if ($ext eq '.mp3' ) {
        %tags = readId3Tags($_);
    } elsif ($ext eq '.wma' ) {
        %tags = readAsfTags($_);
    }

    # use file name if no tag
    $songs{$key}{TIT2} = $tags{Title} || $file;

    # combine album title with year as uniquifier
    $songs{$key}{TALB} = $tags{Album};
    $songs{$key}{TALB} .= ' (' . $tags{Year} . ')' if ($tags{Year} ne ''&& $tags{Album} ne '');

    # use first genre
    $songs{$key}{TCON} = (split(/;/, $tags{Genre}))[0];

    # combine disc with track number to ensure proper order on AT
    $songs{$key}{TRCK} = sprintf('%d%02d', $tags{Disc}, $tags{Track});

    # select the most representative artist for the track
    my $artists = $tags{AlbumArtist} . ';' . $tags{TrackArtist};
    if ($genre eq "Classical") {
         $artists = $tags{Composer} . ';' . $artists
    }
    foreach $item (split(/;/, $artists)) {
        if ($item ne '' && $item !~ /^Vario/) {
            $songs{$key}{TPE1} = $item;
            last;
        }
    }
}

# generate sorted TOC file
sub gen_toc() {
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
    $time = time;
    fileparse_set_fstype('MSWin32');
    find({ wanted=>\&find_music, no_chdir=>1 }, $folder);
    gen_toc();
    utime $time, $time, $toc;

    # update AudioTron
    `wget http://${host}/goform/CheckNewFilesForm --user=${user} --password=${pass} --quiet`
}
