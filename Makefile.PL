use inc::Module::Install;

&replace_perl_path;

name 'Lingua-JA-TFIDF';
all_from 'lib/Lingua/JA/TFIDF.pm';

requires('List::MoreUtils');
requires('Storable');
requires('Class::Accessor::Fast');
requires('Class::Data::Inheritable');
requires('LWP::UserAgent');
requires('XML::TreePP');
requires('Carp');
requires('HTML::Feature');
build_requires 'Test::More';
use_test_base;
auto_install;

install_script('script/tfidf');
WriteAll;

sub replace_perl_path {
    my $perl_path = `which perl`;
    open(SCRIPT, "+<script/tfidf");
    my @code = <SCRIPT>;
    return if $code[0] =~ /^#!/;
    seek(SCRIPT,0,0);
    print SCRIPT '#!' . $perl_path . "\n";
    for(@code){
        print SCRIPT $_;
    }
    truncate(SCRIPT,tell);
    close(SCRIPT);
}