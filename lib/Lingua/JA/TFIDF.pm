package Lingua::JA::TFIDF;

use strict;
use warnings;
use List::MoreUtils qw(any);
use Storable qw(retrieve nstore);
use base qw(Lingua::JA::TFIDF::Base);
use Lingua::JA::TFIDF::Result;
use Lingua::JA::TFIDF::Fetcher;

__PACKAGE__->mk_accessors($_) for qw( _df_data ng_word _fetcher);

our $VERSION = '0.00001';

my $N = 25000000000;

sub new {
    my $class = shift;
    my %args  = @_;
    my $self  = $class->SUPER::new( \%args );
}

sub tfidf {
    my $self = shift;
    my $text = shift;
    my $data = $self->_calc_tf( \$text );
    $self->_calc_idf($data);
    return Lingua::JA::TFIDF::Result->new($data);
}

sub tf {
    my $self = shift;
    my $text = shift;
    my $data = $self->_calc_tf( \$text );
    return Lingua::JA::TFIDF::Result->new($data);
}

sub _calc_tf {
    my $self     = shift;
    my $text_ref = shift;
    $$text_ref =~ s/\r\n//g;
    $$text_ref =~ s/\n//g;
    $$text_ref =~ s/'//g;
    $$text_ref =~ s/"//g;
    $$text_ref =~ s/|//g;
    my $cmd =
        'echo \''
      . $$text_ref
      . '\' | mecab -b 100000 --node-format="%m\t%H\n" --unk-format="%m\t%H\tUNK\n"';
    my $data;

    for (`$cmd`) {
        chomp $_;
        my ( $word, $info, $unknown ) = split( /\t/, $_, 3 );
        next if !$info;
        if ( $info =~ /名詞/ ) {
            next if $info =~ /数|非自立|語幹|代名詞|接尾/;
            next if any { $word eq $_ } @{ $self->_ng_word };
            $data->{$word}->{tf}++;
            $data->{$word}->{unknown} = 1 if $unknown;
        }
    }
    return $data;
}

sub _calc_idf {
    my $self    = shift;
    my $data    = shift;
    my $df_data = $self->df_data;
    my ( $df_sum, $df_num, $unknown );
    while ( my ( $word, $ref ) = each(%$data) ) {
        my $tf = $ref->{tf};
        my $df = $df_data->{$word};
        if ($df) {
            $df_sum += $df;
            $df_num++;
            $data->{$word}->{df}    = $df;
            $data->{$word}->{tfidf} = $tf * log( $N / $df );
        }
        else {
            $unknown->{$word}->{td} = $tf;
        }
    }
    while ( my ( $word, $tf ) = each %$unknown ) {
        my $tf = $data->{$word}->{tf};

        my $df;
        if ( $self->config->{fetch_df} ) {
            $df = $self->fetcher->fetch($word);
            if ($df) {
                $df_data->{$word} = $df;
            }
            nstore( $df_data, $self->config->{df_file} )
              if $self->config->{fetch_df_save};
        }
        else {
            if ( !$df_sum ) {
                $df = $N;
            }
            else {
                $df = int( $df_sum / $df_num );
            }
        }
        $data->{$word}->{df}      = $df;
        $data->{$word}->{tfidf}   = $tf * log( $N / $df );
        $data->{$word}->{unknown} = 1;
    }
    return $data;
}

sub _ng_word {
    my $self = shift;
    $self->ng_word or sub {
        my @ng = (
            '(',
            ')',
            '#',
            ',',
            '"',
            "'",
            '`',
            qw(! $ % & * + - . / : ; < = > ? @ [ \ ] ^ _ { | } ~),
            qw(人 秒 分 時 日 月 年 円 ドル),
            qw(一 二 三 四 五 六 七 八 九 十 百 千 万 億 兆),
            qw(↑ ↓ ← → ⇒ ⇔ ＼ ＾ ｀ ヽ),
            qw(a any the who he she i to and in you is you str this ago about and new as of for if or it have by into at on an are were was be my am your we them there their from all its),
            qw(a b c d e f g h i j k l m n o p q r s t u v w x y z),
            qw(A B C D E F G H I J K L M N O P Q R S T U V W X Y Z),
        );
        $self->ng_word( \@ng );
      }
      ->();
}

sub df_data {
    my $self = shift;
    $self->_df_data or sub {
        unless ( $self->config->{df_file} ) {
            my $path = $INC{'Lingua/JA/TFIDF.pm'};
            $path =~ s/.pm//;
            $path .= '/df.st';
            $self->config->{df_file} = $path;
        }
        $self->_df_data( retrieve( $self->config->{df_file} ) );
      }
      ->();
}

sub fetcher {
    my $self = shift;
    $self->_fetcher or sub {
        $self->_fetcher(
            Lingua::JA::TFIDF::Fetcher->new( %{ $self->config } ) );
      }
      ->();
}

1;
__END__

=head1 NAME

Lingua::JA::TFIDF - TFIDF Calculator based on MeCab.

=head1 SYNOPSIS

  use Lingua::JA::TFIDF;
  use Data::Dumper;

  my $calc   = Lingua::JA::TFIDF->new(%config);

  # calculate TFIDF and return a result object.
  my $result = $$calc->tfidf;
  print Dumper $result->list;

  # or calculate just TF 
  print Dumper $calc->tf->list;

  # dump the result object.
  print Dumper $result->dump

=head1 DESCRIPTION

* This software is still in alpha release * 

Lingua::JA::TFIDF is TFIDF Calculator based on MeCab.
It has DF(Document Frequency) data set that was fetched from Yahoo Search API, beforehand.

=head1 METHODS

=head2 new(%config)

Instantiates a new Lingua::JA::TFIDF object. Takes the following parameters (optional).

  my $calc = Lingua::JA::TFIDF->new(
    df_file         => 'my_df_file',           # default is undef
    ng_word         => \@original_ngword,      # default is undef
    fetch_df        => 1,                      # default is undef
    fetch_df_save   => 'my_df_file',           # default is undef
    LWP_UserAgent   => \%lwp_useragent_config, # default is undef
    XML_TreePP      => \%xml_treepp_config,    # default is undef
    yahoo_api_appid => $myid,                  # default is undef
  );

=head2 tfidf($text); 

Calculates TFIDF score.
If the text includes unknown words, Document Frequency score of unknown words are replaced the average score of known words.
If you set TRUE value to fetch_df parameter on constructor, the calculator fetches the unknown word from Yahoo Search API. 


=head2 tf($text);

Calculates TF score.

=head2 ng_word 

Accessor method.
You can replace ngword.

=head2 df_data 

Inncer accessor method.

=head2 fetcher 

Inncer accessor method.

=head1 AUTHOR

Takeshi Miki E<lt>miki@cpan.orgE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO


=cut
