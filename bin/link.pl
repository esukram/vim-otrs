#!/usr/bin/perl -w

use strict;
use warnings;

use File::Find;
use File::Path;

use utf8;

my %cmds = (
    'cd' => 'cd',
    'git' => 'git',
);

my %git_sub_cmds = (
    'get_root' => 'rev-parse --show-cdup',
    'get_submodules' => 'submodule',
);

my @root_files = qw(LICENSE README .gitmodules);
my @root_directories = qw(.git bin);

# get relative path in git repo
my $git_root = `$cmds{git} $git_sub_cmds{get_root}`;
die "An git error occured!" if $? != 0;
chomp $git_root;

# change to root directory
if ($git_root) {
    system $cmds{cd}, $git_root;
}

# get submodules
my @submodules = ();
open(my $fh_submodules,
    "-|:encoding(UTF-8)",
     "$cmds{git} $git_sub_cmds{get_submodules}"
) or die "Unable";

while (my $submodule = <$fh_submodules>) {
    chomp $submodule;
    $submodule =~ m{\A(-|\s+)([a-z0-9]+)\s*(.+)\z}xms;
    push @submodules, $3;
}
close $fh_submodules;

# get directories and files of submodules
my @submodules_entries = ();
for my $submodule (@submodules) {
    my %submodule_entry = ();

    $submodule_entry{'name'}      = $submodule;
    $submodule_entry{'directory'} = get_submodule_directories($submodule);
    $submodule_entry{'files'}     = get_submodule_files($submodule);

    push @submodules_entries, {%submodule_entry};
}

# get all directories in root of repo
my @repo_root = glob '*';

# strip out static directories
@repo_root =  grep {
    my $directory = $_;
    !grep { $directory eq $_ } @root_directories
} @repo_root;

# strip out static files
@repo_root =  grep {
    my $directory = $_;
    !grep { $directory eq $_ } @root_files
} @repo_root;

# strip out submodules
@repo_root =  grep {
    my $directory = $_;
    !grep { $directory eq $_->{name} } @submodules_entries
} @repo_root;

# delete files or directories
map {
    if (-f $_) {
        unlink $_;
    }
    elsif (-d $_) {
        rmtree $_;
    }
} @repo_root;

# create directories and symlinks
link_submodule(\@submodules_entries);

# return true
exit(0);


########
# subs #
########
sub get_submodule_directories {
    my $submodule = shift;

    my @directories = ();
    my $find_dir = sub {
        return if -f $_;
        return if $File::Find::name =~ m{/\.git(|/)}xms;
        push @directories, $File::Find::name;
    };
    find $find_dir, $submodule;

    return \@directories;
} # end get_submodule_directories

sub get_submodule_files {
    my $submodule = shift;

    my @files = ();
    my $find_files = sub {
        return if -d $_;
        return if $File::Find::name =~ m{/\.git(|/)}xms;
        push @files, $File::Find::name;
    };
    find $find_files, $submodule;

    return \@files;
} # end get_submodule_files

sub link_submodule {
    my $submodules = shift;

    for my $submodule (@$submodules) {
        # create directories
        map {
            my $submodule_directory = $_;
            $submodule_directory =~ s{$submodule->{name}/}{}xms;
            mkpath($submodule_directory) if !-d $submodule_directory;
        } @{ $submodule->{directory} };

        # create symlinks
        map {
            my $submodule_file = $_;
            my $symlink_target = $_;
            $symlink_target =~ s{$submodule->{name}/}{}xms;
            symlink $submodule_file, $symlink_target if !-e $symlink_target;
        } @{ $submodule->{files} };
    }
} # end link_submodule
