# -----------------------------------------------------------------------------
# Unicode::Japanese
# Unicode::Japanese::PurePerl
# -----------------------------------------------------------------------------
# $Id: Japanese.pm,v 1.22 2007/09/10 07:18:04 hio Exp $
# -----------------------------------------------------------------------------
package Unicode::Japanese::PurePerl;
package Unicode::Japanese;

use strict;
use vars qw($VERSION $PurePerl $xs_loaderror);
$VERSION = '0.43';

# `use bytes' and `use Encode' if on perl-5.8.0 or later.
if( $] >= 5.008 )
{
  my $evalerr;
  {
    local($SIG{__DIE__}) = 'DEFAULT';
    local($@);
    eval 'use bytes;use Encode;';
    $evalerr = $@;
  }
  $evalerr and CORE::die($evalerr);
}

# -----------------------------------------------------------------------------
# import
#
sub import
{
  my $pkg = shift;
  my ($callerpkg) = caller;
  my %exp =
  (
    '&unijp' => \&unijp,
  );
  my @na;
  my @add = (grep{$_ eq ':all'} @_) ? keys %exp : ();
  foreach(@_, @add)
  {
    $_ eq 'PurePerl' and $PurePerl=1, next;
    if( $exp{$_} || $exp{'&'.$_} )
    {
      no strict 'refs';
      (my $name = $_) =~ s/^\W//;
      my $obj = $exp{$_} || $exp{'&'.$_};
      *{$callerpkg.'::'.$name} = $obj;
    }elsif( $_ eq 'no_I18N_Japanese' )
    {
      $^H &= ~0x0f00_0000;
      package Unicode::Japanese::PurePerl;
      $^H &= ~0x0f00_0000;
      package Unicode::Japanese;
      next;
    }
    push(@na,$_);
  }
  if( @na )
  {
    #use Carp;
    #croak("invalid parameter (".join(',',@na).")");
  }
}

# -----------------------------------------------------------------------------
# DESTROY
#
sub DESTROY
{
}

# -----------------------------------------------------------------------------
# load_xs.
#   loading xs-subs.
#   this method is called from new (through new=>_init_table=>load_xs)
#   
sub load_xs
{
  #print STDERR "load_xs\n";
  if( $PurePerl )
  {
    #print STDERR "PurePerl mode\n";
    $xs_loaderror = 'disabled';
    return;
  }
  #print STDERR "XS mode\n";
  
  my $use_xs;
  LoadXS:
  {
    
    #print STDERR "* * bootstrap...\n";
    eval q
    {
      use strict;
      require DynaLoader;
      use vars qw(@ISA);
      @ISA = qw(DynaLoader);
      local($SIG{__DIE__}) = 'DEFAULT';
      Unicode::Japanese->bootstrap($VERSION);
    };
    #print STDERR "* * try done.\n";
    #undef @ISA;
    if( $@ )
    {
      #print STDERR "failed.\n";
      #print STDERR "$@\n";
      $use_xs = 0;
      $xs_loaderror = $@;
      undef $@;
      last LoadXS;
    }
    #print STDERR "succeeded.\n";
    $use_xs = 1;
    eval q
    {
      #print STDERR "over riding _s2u,_u2s\n";
      do_memmap();
      #print STDERR "memmap done\n";
      END{ do_memunmap(); }
      #print STDERR "binding xsubs done.\n";
    };
    if( $@ )
    {
      #print STDERR "error on last part of load XS.\n";
      $xs_loaderror = $@;
      CORE::die($@);
    }

    #print STDERR "done.\n";
  }

  if( $@ )
  {
    $xs_loaderror = $@;
    CORE::die("Cannot Load Unicode::Japanese either XS nor PurePerl\n$@");
  }
  if( !$use_xs )
  {
    #print STDERR "no xs.\n";
    eval q
    {
      sub do_memmap($){}
      sub do_memunmap($){}
    };
  }
  $xs_loaderror = '' if( !defined($xs_loaderror) );
  #print STDERR "load_xs done.\n";
}

# -----------------------------------------------------------------------------
# Unicode::Japanese->new();
# cache for char convert.
# 2bytes.
#  JIS C 6226-1979  \e$@
#  JIS X 0208-1983  \e$B
#  JIS X 0208-1990  \e&@\e$B
#  JIS X 0212-1990  \e$(D
# 1byte.
#  JIS ROMAN  \e(J
#  JIS ROMAN  \e(H
#  ASCII      \e(B
#  JIS KANA   \e(I
# -----------------------------------------------------------------------------
# $unijp = Unicode::Japanese->new([$str,[$icode]]);
# 
sub new
{
  my $pkg = shift;
  my $this = {};

  if( defined($pkg) )
  {
    bless $this, $pkg;
  $this->_init_table;
  }else
  {
    bless $this;
  $this->_init_table;
  }
  
  @_ and $this->set(@_);
  
  $this;
}


# -----------------------------------------------------------------------------
# _got_undefined_subroutine
#   die with message 'undefiend subroutine'.
# 
sub _got_undefined_subroutine
{
  my $subname = pop;
  CORE::die "Undefined subroutine \&$subname called.\n";
}

# -----------------------------------------------------------------------------
# AUTOLOAD
#   AUTOLOAD of Unicode::Japanese.
#   imports PurePerl methods.
# 
AUTOLOAD
{
  # load pure perl subs.
  use vars qw($AUTOLOAD);
  my ($pkg,$subname) = $AUTOLOAD =~ /^(.*)::(\w+)$/
    or got_undefined_subroutine($AUTOLOAD);
  no strict 'refs';
  if(!defined($Unicode::Japanese::xs_loaderror) )
  {
    Unicode::Japanese::PurePerl::_init_table();
    if( defined(&$AUTOLOAD) )
    {
      return &$AUTOLOAD;
    }
  }
  my $ppsubname = "$pkg\:\:PurePerl\:\:$subname";
  my $sub = \&$ppsubname;
  *$AUTOLOAD = $sub; # copy.
  goto &$sub;
}

# -----------------------------------------------------------------------------
# Unicode::Japanese::PurePerl
# -----------------------------------------------------------------------------
package Unicode::Japanese::PurePerl;


use strict;
use vars qw(%CHARCODE %ESC %RE);

use vars qw(@J2S @S2J @S2E @E2S @U2T %T2U %S2U %U2S %SA2U1 %U2SA1 %SA2U2 %U2SA2);

%CHARCODE = (
	     UNDEF_EUC  =>     "\xa2\xae",
	     UNDEF_SJIS =>     "\x81\xac",
	     UNDEF_JIS  =>     "\xa2\xf7",
	     UNDEF_UNICODE  => "\x20\x20",
	 );

%ESC =  (
	 JIS_0208      => "\e\$B",
	 JIS_0212      => "\e\$(D",
	 ASC           => "\e\(B",
	 KANA          => "\e\(I",
	 E_JSKY_START  => "\e\$",
	 E_JSKY_END    => "\x0f",
	 );

%RE =
    (
     ASCII     => '[\x00-\x7f]',
     EUC_0212  => '\x8f[\xa1-\xfe][\xa1-\xfe]',
     EUC_C     => '[\xa1-\xfe][\xa1-\xfe]',
     EUC_KANA  => '\x8e[\xa1-\xdf]',
     JIS_0208  => '\e\$\@|\e\$B|\e&\@\e\$B',
     JIS_0212  => "\e" . '\$\(D',
     JIS_ASC   => "\e" . '\([BJ]',
     JIS_KANA  => "\e" . '\(I',
     SJIS_DBCS => '[\x81-\x9f\xe0-\xef\xfa-\xfc][\x40-\x7e\x80-\xfc]',
     SJIS_KANA => '[\xa1-\xdf]',
     UTF8      => '[\x00-\x7f]|[\xc0-\xdf][\x80-\xbf]|[\xe0-\xef][\x80-\xbf]{2}|[\xf0-\xf7][\x80-\xbf]{3}|[\xf8-\xfb][\x80-\xbf]{4}|[\xfc-\xfd][\x80-\xbf]{5}',
     BOM2_BE    => '\xfe\xff',
     BOM2_LE    => '\xff\xfe',
     BOM4_BE    => '\x00\x00\xfe\xff',
     BOM4_LE    => '\xff\xfe\x00\x00',
     UTF32_BE   => '\x00[\x00-\x10][\x00-\xff]{2}',
     UTF32_LE   => '[\x00-\xff]{2}[\x00-\x10]\x00',
     E_IMODEv1  => '\xf8[\x9f-\xfc]|\xf9[\x40-\x49\x50-\x52\x55-\x57\x5b-\x5e\x72-\x7e\x80-\xb0]',
     E_IMODEv2  => '\xf9[\xb1-\xfc]',
     E_IMODE    => '\xf8[\x9f-\xfc]|\xf9[\x40-\x49\x50-\x52\x55-\x57\x5b-\x5e\x72-\x7e\x80-\xfc]',
     E_JSKY1    => '[EFGOPQ]',
     E_JSKY1v1  => '[EFG]',
     E_JSKY1v2  => '[OPQ]',
     E_JSKY2    => '[\!-z]',
     E_DOTI     => '\xf0[\x40-\x7e\x80-\xfc]|\xf1[\x40-\x7e\x80-\xd6]|\xf2[\x40-\x7e\x80-\xab\xb0-\xd5\xdf-\xfc]|\xf3[\x40-\x7e\x80-\xfa]|\xf4[\x40-\x4f\x80\x84-\x8a\x8c-\x8e\x90\x94-\x96\x98-\x9c\xa0-\xa4\xa8-\xaf\xb4\xb5\xbc-\xbe\xc4\xc5\xc8\xcc]',
     E_JIS_AU   => '[\x75-\x7b][\x21-\x7e]',
     E_SJIS_AU  => '[\xf3\xf4\xf6\xf7][\x40-\xfc]',
     E_ICON_AU_START => '<IMG ICON="',
     E_ICON_AU_END   => '">',
     E_JSKY_START => quotemeta($ESC{E_JSKY_START}),
     E_JSKY_END   => '(?:'.quotemeta($ESC{E_JSKY_END}).'|\z)',
     E_JSKYv1_UTF8 => qr/\xee(?:\x80[\x81-\xbf]|\x81[\x80-\x9a]|\x84[\x81-\xbf]|\x85[\x80-\x9a]|\x88[\x81-\xbf]|\x89[\x80-\x9a])/,
     E_JSKYv2_UTF8 => qr/\xee(?:\x8c[\x81-\xbf]|\x8d[\x80-\x8d]|\x90[\x81-\xbf]|\x91[\x80-\x8c]|\x94[\x81-\xb7])/,
     );

$RE{E_JSKY}     =  $RE{E_JSKY_START}
  . $RE{E_JSKY1} . $RE{E_JSKY2} . '+'
  . $RE{E_JSKY_END};
$RE{E_JSKYv1}     =  $RE{E_JSKY_START}
  . $RE{E_JSKY1v1} . $RE{E_JSKY2} . '+'
  . $RE{E_JSKY_END};
$RE{E_JSKYv2}     =  $RE{E_JSKY_START}
  . $RE{E_JSKY1v2} . $RE{E_JSKY2} . '+'
  . $RE{E_JSKY_END};

our @CHARSET_LIST = qw(
  utf8
  ucs2
  ucs4
  utf16
  
  sjis
  sjis-imode
  sjis-doti
  sjis-jsky
  sjis-icon-au
  cp932
  
  jis
  jis-jsky
  jis-au
  jis-icon-au
  
  euc
  euc-jp
  euc-icon-au
  
  utf8-jsky
  utf8-icon-au
);

use vars qw($s2u_table $u2s_table);
use vars qw($ei2u1 $ei2u2 $ed2u $ej2u1 $ej2u2 $ea2u1 $ea2u2 $ea2u1s $ea2u2s);
use vars qw($eu2i1 $eu2i2 $eu2d $eu2j1 $eu2j2 $eu2a1 $eu2a2 $eu2a1s $eu2a2s);

use vars qw(%_h2zNum %_z2hNum %_h2zAlpha %_z2hAlpha %_h2zSym %_z2hSym %_h2zKanaK %_z2hKanaK %_h2zKanaD %_z2hKanaD %_hira2kata %_kata2hira);



use vars qw($FH $TABLE $HEADLEN $PROGLEN);

# -----------------------------------------------------------------------------
# AUTOLOAD
#   AUTOLOAD of Unicode::Japanese::PurePerl.
#   load PurePerl methods from embeded data.
# 
AUTOLOAD
{
  use strict;
  use vars qw($AUTOLOAD);
  
  #print STDERR "AUTOLOAD... $AUTOLOAD\n";
  
  my $save = $@;
  my @BAK = @_;
  
  my $subname = $AUTOLOAD;
  $subname =~ s/^Unicode\:\:Japanese\:\:(?:PurePerl\:\:)?//;

  #print "subs..\n",join("\n",keys %$TABLE,'');
  
  # check
  if(!defined($TABLE->{$subname}{offset}))
    {
      _init_table();
      if( !defined($TABLE->{$subname}{offset}) )
      {
	if( substr($AUTOLOAD,-9) eq '::DESTROY' )
	{
	  {
	    no strict;
	    *$AUTOLOAD = sub {};
	  }
	  $@ = $save;
	  @_ = @BAK;
	  goto &$AUTOLOAD;
	}
      
        CORE::die "Undefined subroutine \&$AUTOLOAD called.\n";
      }
    }
  if($TABLE->{$subname}{offset} == -1)
    {
      CORE::die "Double loaded \&$AUTOLOAD. It has some error.\n";
    }
  
  seek($FH, $PROGLEN + $HEADLEN + $TABLE->{$subname}{offset}, 0)
    or die "Can't seek $subname. [$!]\n";
  
  my $sub;
  read($FH, $sub, $TABLE->{$subname}{length})
    or die "Can't read $subname. [$!]\n";

  if( $]>=5.008 )
  {
    $sub = 'use bytes;'.$sub;
  }

  CORE::eval(($sub=~/(.*)/s)[0]);
  if ($@)
    {
      CORE::die $@;
    }
  $DB::sub = $AUTOLOAD;	# Now debugger know where we are.
  
  # evaled
  $TABLE->{$subname}{offset} = -1;

  $@ = $save;
  @_ = @BAK;
  goto &$AUTOLOAD;
}

# -----------------------------------------------------------------------------
# Unicode::Japanese::PurePerl->new()
# 
sub new
{
  goto &Unicode::Japanese::new;
}

# -----------------------------------------------------------------------------
# DESTROY
# 
sub DESTROY
{
}

# -----------------------------------------------------------------------------
# gensym
# 
sub gensym {
  package Unicode::Japanese::Symbol;
  no strict;
  $genpkg = "Unicode::Japanese::Symbol::";
  $genseq = 0;
  my $name = "GEN" . $genseq++;
  my $ref = \*{$genpkg . $name};
  delete $$genpkg{$name};
  $ref;
}

# -----------------------------------------------------------------------------
# _init_table
# 
sub _init_table {
  
  if(!defined($HEADLEN))
    {
      $FH = gensym;
      
      my $file = "Unicode/Japanese.pm";
      OPEN:
      {
        if( $INC{$file} )
        {
          open($FH,$INC{$file}) || CORE::die("could not open file [$INC{$file}] for input : $!");
          last OPEN;
        }
        foreach my $path (@INC)
          {
            my $mypath = $path;
            $mypath =~ s#/$##;
            if (-f "$mypath/$file")
              {
                open($FH,"$mypath/$file") || CORE::die("could not open file [$INC{$file}] for input : $!");
                last OPEN;
              }
          }
        CORE::die "Can't find Japanese.pm in \@INC\n";
      }
      binmode($FH);
      
      local($/) = "\n";
      my $line;
      while($line = <$FH>)
	{
	  last if($line =~ m/^__DATA__/);
	}
      $PROGLEN = tell($FH);
      
      read($FH, $HEADLEN, 4)
	or die "Can't read table. [$!]\n";
      $HEADLEN = unpack('N', $HEADLEN);
      read($FH, $TABLE, $HEADLEN)
	or die "Can't seek table. [$!]\n";
      $TABLE =~ /(.*)/s;
      $TABLE = eval(($TABLE=~/(.*)/s)[0]);
      if($@)
	{
	  die "Internal Error. [$@]\n";
	}
      if(!defined($TABLE))
	{
	  die "Internal Error.\n";
	}
      $HEADLEN += 4;

      # load xs.
      Unicode::Japanese::load_xs();
    }
}

# -----------------------------------------------------------------------------
# _getFile
#   load embeded file data.
# 
sub _getFile {
  my $this = shift;

  my $file = shift;

  exists($TABLE->{$file})
    or die "no such file [$file]\n";

  #print STDERR "_getFile($file, $TABLE->{$file}{offset}, $TABLE->{$file}{length})\n";
  seek($FH, $PROGLEN + $HEADLEN + $TABLE->{$file}{offset}, 0)
    or die "Can't seek $file. [$!]\n";
  
  my $data;
  read($FH, $data, $TABLE->{$file}{length})
    or die "Can't read $file. [$!]\n";
  
  $data;
}

# -----------------------------------------------------------------------------
# use_I18N_Japanese
#   copy from I18N::Japanese in jperl-5.5.3
#
sub use_I18N_Japanese
{
  shift;
  if( @_ )
  {
    my $bits = 0;
    foreach( @_ )
    {
      $bits |= 0x1000000 if $_ eq 're';
      $bits |= 0x2000000 if $_ eq 'tr';
      $bits |= 0x4000000 if $_ eq 'format';
      $bits |= 0x8000000 if $_ eq 'string';
    }
    $^H |= $bits;
  }else
  {
    $^H |= 0x0f00_0000;
  }
}

# -----------------------------------------------------------------------------
# no_I18N_Japanese
#   copy from I18N::Japanese in jperl-5.5.3
#
sub no_I18N_Japanese
{
  shift;
  if( @_ )
  {
    my $bits = 0;
    foreach( @_ )
    {
      $bits |= 0x1000000 if $_ eq 're';
      $bits |= 0x2000000 if $_ eq 'tr';
      $bits |= 0x4000000 if $_ eq 'format';
      $bits |= 0x8000000 if $_ eq 'string';
    }
    $^H &= ~$bits;
  }else
  {
    $^H &= ~0x0f00_0000;
  }
}

1;

=encoding utf-8

=head1 NAME

Unicode::Japanese - Japanese Character Encoding Handler


=head1 SYNOPSIS

 use Unicode::Japanese;
 use Unicode::Japanese qw(unijp);
 
 # convert utf8 -> sjis
 
 print Unicode::Japanese->new($str)->sjis;
 print unijp($str)->sjis; # same as avobe.
 
 # convert sjis -> utf8
 
 print Unicode::Japanese->new($str,'sjis')->get;
 
 # convert sjis (imode_EMOJI) -> utf8
 
 print Unicode::Japanese->new($str,'sjis-imode')->get;
 
 # convert ZENKAKU (utf8) -> HANKAKU (utf8)
 
 print Unicode::Japanese->new($str)->z2h->get;

=head1 DESCRIPTION

Module for conversion among Japanese character encodings.


=head2 FEATURES

=over 2

=item *



The instance stores internal strings in UTF-8.


=item *



Supports both XS and Non-XS.
Use XS for high performance,
or No-XS for ease to use (only by copying Japanese.pm).


=item *



Supports conversion between ZENKAKU and HANKAKU.


=item *



Safely handles "EMOJI" of the mobile phones (DoCoMo i-mode, ASTEL dot-i
and J-PHONE J-Sky) by mapping them on Unicode Private Use Area.


=item *



Supports conversion of the same image of EMOJI
between different mobile phone's standard mutually.


=item *



Considers Shift_JIS(SJIS) as MS-CP932.
(Shift_JIS on MS-Windows (MS-SJIS/MS-CP932) differ from
generic Shift_JIS encodings.)


=item *



On converting Unicode to SJIS (and EUC-JP/JIS), those encodings that cannot
be converted to SJIS (except "EMOJI") are escaped in "&#dddd;" format.
"EMOJI" on Unicode Private Use Area is going to be '?'.
When converting strings from Unicode to SJIS of mobile phones,
any characters not up to their standard is going to be '?'


=item *



On perl-5.8.0 and later, setting of utf-8 flag is performed properly.
utf8() method returns utf-8 `bytes' string and
getu() method returns utf-8 `char' string.


get() method returns utf-8 `bytes' string in current release.
in future, the behavior of get() maybe change.


sjis(), jis(), utf8(), etc.. methods return bytes string.
The input of new, set, and a getcode method is not asked about utf8-flaged/bytes.


=back

=head1 METHODS

=over 4

=item $s = Unicode::Japanese->new($str [, $icode [, $encode]])

Creates a new instance of Unicode::Japanese.


If arguments are specified, passes through to set method.


=item unijp($str [, $icode [, $encode]])

Same as Unicode::Janaese->new(...).


=item $s->set($str [, $icode [, $encode]])

=over 2

=item $str: string

=item $icode: character encodings, may be omitted (default = 'utf8')

=item $encode: ASCII encoding, may be omitted.

=back

Set a string in the instance.
If '$icode' is omitted, string is considered as UTF-8.


To specify a encodings, choose from the following;
'auto', 'utf8', 'ucs2', 'ucs4', 'utf16-be', 'utf16-le', 'utf16',
'utf32-be', 'utf32-le', 'utf32', 'jis', 'euc', 'euc-jp',
'sjis', 'cp932', 'sjis-imode', 'sjis-imode1', 'sjis-imode2',
'sjis-doti', 'sjis-doti1', 'sjis-jsky', 'sjis-jsky1', 'sjis-jsky2',
'jis-jsky', 'jis-jsky1', 'jis-jsky2', 'jis-au', 'jis-au1', 'jis-au2',
'sjis-au', 'sjis-au1', 'sjis-au2', 'sjis-icon-au', 'sjis-icon-au1', 'sjis-icon-au2', 
'euc-icon-au', 'euc-icon-au1', 'euc-icon-au2', 'jis-icon-au', 'jis-icon-au1', 'jis-icon-au2',
'utf8-icon-au', 'utf8-icon-au1', 'utf8-icon-au2', 'ascii', 'binary'


For auto encoding detection, you MUST specify 'auto'
so as to call getcode() method automatically.


For ASCII encoding, only 'base64' may be specified.
With it, the string will be decoded before storing.


To decode binary, specify 'binary' as the encoding.


'&#dddd' will be converted to "EMOJI", when specified 'sjis-imode'
or 'sjis-doti'.


In some cases, character encoding detection is 
misleaded because more than one encodings have
same code points.


sjis is returned if a string is valid for both sjis and utf8.
And sjis-au is return if a string is valid for both
sjis-au and sjis-doti.


=item $str = $s->get

=over 2

=item $str: string (UTF-8)

=back

Gets a string with UTF-8.


return `bytes' string in current release,
this behavior will be changed.


utf8() method for `character' string or
getu() method for `bytes' string seems better.


=item $str = $s->getu

=over 2

=item $str: string (UTF-8)

=back

Gets a string with UTF-8.


On perl-5.8.0 and later, return value is with utf-8 flag.


=item $code = $s->getcode($str)

=over 2

=item $str: string

=item $code: character encoding name

=back

Detects the character encodings of I<$str>.


Notice: This method detects B<NOT> encoding of the string in the instance
but I<$str>.


Character encodings are distinguished by the following algorithm:


(In case of PurePerl)


=over 4

=item 1



If BOM of UTF-32 is found, the encoding is utf32.


=item 2



If BOM of UTF-16 is found, the encoding is utf16.


=item 3



If it is in proper UTF-32BE, the encoding is utf32-be.


=item 4



If it is in proper UTF-32LE, the encoding is utf32-le.


=item 5



Without NON-ASCII characters, the encoding is ascii.
(control codes except escape sequences has been included in ASCII)


=item 6



If it includes ISO-2022-JP(JIS) escape sequences, the encoding is jis.


=item 7



If it includes "J-PHONE EMOJI", the encoding is sjis-sky.


=item 8



If it is in proper EUC-JP, the encoding is euc.


=item 9



If it is in proper SJIS, the encoding is sjis.


If it is in proper SJIS and "EMOJI" of au, the encoding is sjis-au.


=item 10



If it is in proper SJIS and "EMOJI" of i-mode, the encoding is sjis-imode.


=item 11



If it is in proper SJIS and "EMOJI" of dot-i,the encoding is sjis-doti.


=item 12



If it is in proper UTF-8, the encoding is utf8.


=item 13



If none above is true, the encoding is unknown.


=back

(In case of XS)


=over 4

=item 1



If BOM of UTF-32 is found, the encoding is utf32.


=item 2



If BOM of UTF-16 is found, the encoding is utf16.


=item 3



String is checked by State Transition if it is applicable
for any listed encodings below. 


ascii / euc-jp / sjis / jis / utf8 / utf32-be / utf32-le / sjis-jsky /
sjis-imode / sjis-au / sjis-doti


=item 4



The listed order below is applied for a final determination.


utf32-be / utf32-le / ascii / jis / euc-jp / sjis / sjis-jsky / sjis-imode /
sjis-au / sjis-doti / utf8


=item 5



If none above is true, the encoding is unknown.


=back

Regarding the algorithm, pay attention to the following:


=over 2

=item *



UTF-8 is occasionally detected as SJIS.


=item *



Can NOT detect UCS2 automatically.


=item *



Can detect UTF-16 only when the string has BOM.


=item *



Can detect "EMOJI" when it is stored in binary, not in "&#dddd;"
format. (If only stored in "&#dddd;" format, getcode() will
return incorrect result. In that case, "EMOJI" will be crashed.)


=back

Because each of XS and PurePerl has a different algorithm, A result of
the detection would be possibly different.  In case that the string is
SJIS with escape characters, it would be considered as SJIS on
PurePerl.  However, it can't be detected as S-JIS on XS. This is
because by using Algorithm, the string can't be distinguished between
SJIS and SJIS-Jsky.  This exclusion of escape characters on XS from
the detection is suppose to be the same for EUC-JP.


=item $code = $s->getcodelist($str)

=over 2

=item $str: string

=item $code: character encoding name

=back

Detects the character encodings of I<$str>.


This function returns all acceptable character encodings.


=item $str = $s->conv($ocode, $encode)

This function returns copy of contained string in $ocode encoding.


=over 2

=item $ocode: output character encoding (Choose from 'utf8', 'euc', 'euc-jp', 'jis', 'sjis', 'cp932',
'sjis-imode', 'sjis-imode1', 'sjis-imode2', 'sjis-doti', 'sjis-doti1', 'sjis-jsky', 'sjis-jsky1', 'sjis-jsky2',
'jis-jsky', 'jis-jsky1', 'jis-jsky2', 'jis-au', 'jis-au1', 'jis-au2', 'sjis-au', 'sjis-au1', 'sjis-au2',
'sjis-icon-au', 'sjis-icon-au1', 'sjis-icon-au2', 'euc-icon-au', 'euc-icon-au1', 'euc-icon-au2',
'jis-icon-au', 'jis-icon-au1', 'jis-icon-au2', 'utf8-icon-au', 'utf8-icon-au1', 'utf8-icon-au2',
'ucs2', 'ucs4', 'utf16', 'binary')

Number at end of encoding names means emoji set version.
Larger number is newer set.
No number is same as newest set.
Generally you may use without digits.


=item $encode: encoding, may be omitted.

=item $str: string

=back

Gets a string converted to I<$ocode>.


For ASCII encoding, only 'base64' may be specified. With it, the string
encoded in base64 will be returned.


On perl-5.8.0 and later, return value is not with utf-8 flag, and is 
bytes string.


=item $s->tag2bin

Replaces the substrings "&#dddd;" in the string with the binary entity
they mean.


=item $s->z2h

Converts ZENKAKU to HANKAKU.


=item $s->h2z

Converts HANKAKU to ZENKAKU.


=item $s->hira2kata

Converts HIRAGANA to KATAKANA.


=item $s->kata2hira

Converts KATAKANA to HIRAGANA.


=item $str = $s->jis

$str: string (JIS)


Gets the string converted to ISO-2022-JP(JIS).


=item $str = $s->euc

$str: string (EUC-JP)


Gets the string converted to EUC-JP.


=item $str = $s->utf8

$str: `bytes' string (UTF-8)


Gets the string converted to UTF-8.


On perl-5.8.0 and later, return value is not with utf-8 flag, and is
bytes string.


=item $str = $s->ucs2

$str: string (UCS2)


Gets the string converted to UCS2.


=item $str = $s->ucs4

$str: string (UCS4)


Gets the string converted to UCS4.


=item $str = $s->utf16

$str: string (UTF-16)


Gets the string converted to UTF-16(big-endian).
BOM is not added.


=item $str = $s->sjis

$str: string (SJIS)


Gets the string converted to Shift_JIS(MS-SJIS/MS-CP932).


=item $str = $s->sjis_imode

$str: string (SJIS/imode_EMOJI)


Gets the string converted to SJIS for i-mode.
This method is alias of sjis_imode2.


=item $str = $s->sjis_imode1

$str: string (SJIS/imode_EMOJI)


Gets the string converted to SJIS for i-mode.
$str includes only basic pictgraphs, and is without extended pictgraphs.


=item $str = $s->sjis_imode2

$str: string (SJIS/imode_EMOJI)


Gets the string converted to SJIS for i-mode.
$str includes both basic pictgraphs, and extended ones.


=item $str = $s->sjis_doti

$str: string (SJIS/dot-i_EMOJI)


Gets the string converted to SJIS for dot-i.


=item $str = $s->sjis_jsky

$str: string (SJIS/J-SKY_EMOJI)


Gets the string converted to SJIS for j-sky.
This method is alias of sjis_jsky2 on VERSION 0.15.


=item $str = $s->sjis_jsky1

$str: string (SJIS/J-SKY_EMOJI)


Gets the string converted to SJIS for j-sky.
$str includes from Page 1 to Page 3.


=item $str = $s->sjis_jsky

$str: string (SJIS/J-SKY_EMOJI)


Gets the string converted to SJIS for j-sky.
$str includes from Page 1 to Page 6.


=item $str = $s->sjis_icon_au

$str: string (SJIS/AU-ICON-TAG)


Gets the string converted to SJIS for au.


=item @str = $s->strcut($len)

=over 2

=item $len: number of characters

=item @str: strings

=back

Splits the string by length(I<$len>).


On perl-5.8.0 and later, each element in return array
is with utf-8 flag.


=item $len = $s->strlen

$len: `visual width' of the string


Gets the length of the string. This method has been offered to
substitute for perl build-in length(). ZENKAKU characters are
assumed to have lengths of 2, regardless of the coding being
SJIS or UTF-8.


=item $s->join_csv(@values);

@values: data array


Converts the array to a string in CSV format, then stores into the instance.
In the meantime, adds a newline("\n") at the end of string.


=item @values = $s->split_csv;

@values: data array


Splits the string, accounting it is in CSV format.
Each newline("\n") is removed before split.


on perl-5.8.0 and later, utf-8 flag of return value depends on
icode of set method. if $s contains binary, return value is bytes
too. if $s contains any string, return value is with utf-8 flag.


=back

=head1 DESCRIPTION OF UNICODE MAPPING

Translation is proceedede as follows.


=over 2

=item SJIS

Mapped as MS-CP932. Mapping table in the following URL is used.


ftp://ftp.unicode.org/Public/MAPPINGS/VENDORS/MICSFT/WINDOWS/CP932.TXT


If a character cannot be mapped to SJIS from Unicode,
it will be converted to &#dddd; format.
Pictgraphs are converted to "?";


Also, any unmapped character will be converted into "?" when converting
to SJIS for mobile phones.


=item EUC-JP/JIS

Converted to SJIS and then mapped to Unicode. Any non-SJIS character
in the string will not be mapped correctly.


=item DoCoMo i-mode

Portion of involving "EMOJI" in F800 - F9FF is maapped
 to U+0FF800 - U+0FF9FF.


=item ASTEL dot-i

Portion of involving "EMOJI" in F000 - F4FF is mapped
 to U+0FF000 - U+0FF4FF.


=item J-PHONE J-SKY

"J-SKY EMOJI" are mapped down as follows: "\e\$"(\x1b\x24) escape
sequences, the first byte, the second byte and "\x0f".
With sequential "EMOJI"s of identical first bytes,
it may be compressed by arranging only the second bytes.


4500 - 47FF is mapped to U+0FFB00 - U+0FFDFF, accounting the first
and the second bytes make one EMOJI character.


Unicode::Japanese will compress "J-SKY_EMOJI" automatically when
the first bytes of a sequence of "EMOJI" are identical.


=item AU

Portion of involving "EMOJI" is mapped to U+0FF500 - U+0FF6FF.


=back

=head1 PurePerl mode

   use Unicode::Japanese qw(PurePerl);

If module was loaded with 'PurePerl' keyword,
it works on Non-XS mode.


=head1 BUGS

=over 2

=item *



EUC-JP, JIS strings cannot be converted correctly when they include
non-SJIS characters because they are converted to SJIS before
being converted to UTF-8.


=item *



When using XS, character encoding detection of EUC-JP and
SJIS(included all EMOJI) strings when they include "\e" will
fail. Also, getcode() and all convert method will not work.


=item *



The Japanese.pm file will collapse if sent via ASCII mode of FTP,
as it has a trailing binary data.


=back

=head1 AUTHOR INFORMATION

Copyright 2001-2007
SANO Taku (SAWATARI Mikage) and YAMASHINA Hio.
All right reserved.


This library is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.


=head1 BUGS

Bug reports and comments to: mikage@cpan.org.
Thank you.


Or, report any bugs or feature requests to
C<bug-unicode-japanese at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Unicode-Japanese>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.


    perldoc Unicode::Japanese

You can also look for information at:


=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Unicode-Japanese>


=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Unicode-Japanese>


=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Unicode-Japanese>


=item * Search CPAN

L<http://search.cpan.org/dist/Unicode-Japanese>


=back

=head1 CREDITS

Thanks very much to:


NAKAYAMA Nao


SUGIURA Tatsuki & Debian JP Project


=head1 COPYRIGHT & LICENSE

Copyright 2001-2007
SANO Taku (SAWATARI Mikage) and YAMASHINA Hio,
all rights reserved.


This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.



=cut



__DATA__
  �{'joinCsv'=>{'length'=>939,'offset'=>0},'_decodeBase64'=>{'length'=>609,'offset'=>939},'z2hNum'=>{'length'=>284,'offset'=>1548},'_utf16le_utf16'=>{'length'=>179,'offset'=>3074},'kata2hira'=>{'length'=>1242,'offset'=>1832},'jcode/emoji2/ea2u.dat'=>{'length'=>1320,'offset'=>372970},'_u2ai2'=>{'length'=>1062,'offset'=>3253},'z2hAlpha'=>{'length'=>836,'offset'=>4315},'_ucs4_utf8'=>{'length'=>936,'offset'=>5151},'h2zSym'=>{'length'=>316,'offset'=>6087},'utf8_icon_au1'=>{'length'=>73,'offset'=>6403},'h2z'=>{'length'=>114,'offset'=>6476},'jcode/emoji2/ea2u2s.dat'=>{'length'=>4096,'offset'=>430826},'sjis'=>{'length'=>177,'offset'=>6590},'euc_icon_au2'=>{'length'=>98,'offset'=>6767},'_u2si1'=>{'length'=>1619,'offset'=>6865},'_sj2u1'=>{'length'=>1144,'offset'=>8484},'euc_icon_au'=>{'length'=>97,'offset'=>9956},'tag2bin'=>{'length'=>328,'offset'=>9628},'z2hSym'=>{'length'=>596,'offset'=>10053},'ucs2'=>{'length'=>183,'offset'=>10649},'jis_au2'=>{'length'=>80,'offset'=>10832},'jcode/emoji2/ei2u2.dat'=>{'length'=>2048,'offset'=>244970},'_si2u1'=>{'length'=>1228,'offset'=>10912},'_utf8_utf16'=>{'length'=>950,'offset'=>12140},'jis_icon_au1'=>{'length'=>98,'offset'=>13090},'sjis_icon_au1'=>{'length'=>86,'offset'=>13188},'sjis_jsky2'=>{'length'=>70,'offset'=>13274},'jcode/emoji2/ei2u.dat'=>{'length'=>2048,'offset'=>226538},'getcode'=>{'length'=>2026,'offset'=>13344},'_j2s2'=>{'length'=>469,'offset'=>15370},'jcode/emoji2/ea2us.dat'=>{'length'=>4096,'offset'=>410346},'sjis_au2'=>{'length'=>95,'offset'=>15839},'h2zKanaD'=>{'length'=>810,'offset'=>15934},'sjis_imode1'=>{'length'=>71,'offset'=>16744},'eucjp'=>{'length'=>32,'offset'=>16815},'utf8'=>{'length'=>187,'offset'=>16847},'_s2e'=>{'length'=>244,'offset'=>17034},'jcode/emoji2/ea2u2.dat'=>{'length'=>3288,'offset'=>390674},'utf8_jsky'=>{'length'=>189,'offset'=>17278},'_uj2u2'=>{'length'=>874,'offset'=>17467},'utf8_jsky1'=>{'length'=>70,'offset'=>18341},'jcode/emoji2/eu2a2.dat'=>{'length'=>16384,'offset'=>393962},'jcode/s2u.dat'=>{'length'=>48573,'offset'=>177965},'conv'=>{'length'=>3663,'offset'=>18411},'_utf16be_utf16'=>{'length'=>71,'offset'=>22074},'jcode/emoji2/eu2j.dat'=>{'length'=>40960,'offset'=>266474},'hira2kata'=>{'length'=>1242,'offset'=>22145},'splitCsvu'=>{'length'=>197,'offset'=>23387},'sjis_doti1'=>{'length'=>69,'offset'=>23584},'_s2j'=>{'length'=>272,'offset'=>23653},'_sa2j2'=>{'length'=>384,'offset'=>23925},'_j2sa'=>{'length'=>179,'offset'=>24309},'sjis_au1'=>{'length'=>95,'offset'=>24488},'join_csv'=>{'length'=>29,'offset'=>24583},'_ai2u1'=>{'length'=>458,'offset'=>24612},'jcode/emoji2/eu2as.dat'=>{'length'=>16384,'offset'=>414442},'_s2u'=>{'length'=>988,'offset'=>25070},'jis_jsky1'=>{'length'=>82,'offset'=>26058},'jis_icon_au2'=>{'length'=>98,'offset'=>26140},'_j2sa3'=>{'length'=>434,'offset'=>26238},'sjis_jsky'=>{'length'=>189,'offset'=>26672},'_u2uj2'=>{'length'=>788,'offset'=>26861},'jis'=>{'length'=>179,'offset'=>27649},'jis_au1'=>{'length'=>80,'offset'=>27828},'_utf8_ucs4'=>{'length'=>1149,'offset'=>27908},'get'=>{'length'=>162,'offset'=>29057},'z2h'=>{'length'=>114,'offset'=>29219},'getu'=>{'length'=>266,'offset'=>29333},'_loadConvTable'=>{'length'=>18009,'offset'=>29599},'unijp'=>{'length'=>137,'offset'=>47608},'_u2uj1'=>{'length'=>806,'offset'=>47745},'jcode/emoji2/eu2a2s.dat'=>{'length'=>16384,'offset'=>434922},'_u2ja1'=>{'length'=>1639,'offset'=>48551},'_j2s'=>{'length'=>177,'offset'=>50190},'utf16'=>{'length'=>187,'offset'=>50367},'utf8_jsky2'=>{'length'=>70,'offset'=>50554},'_u2ai1'=>{'length'=>1203,'offset'=>50624},'sjis_icon_au2'=>{'length'=>86,'offset'=>51827},'_u2si2'=>{'length'=>1620,'offset'=>51913},'jcode/emoji2/eu2i.dat'=>{'length'=>16384,'offset'=>228586},'splitCsv'=>{'length'=>350,'offset'=>53533},'jcode/emoji2/eu2i2.dat'=>{'length'=>16384,'offset'=>247018},'sjis_jsky1'=>{'length'=>70,'offset'=>53883},'_s2j3'=>{'length'=>355,'offset'=>53953},'_sa2u1'=>{'length'=>1137,'offset'=>54308},'_u2s'=>{'length'=>2320,'offset'=>55445},'_sa2j3'=>{'length'=>455,'offset'=>57765},'_utf16_utf8'=>{'length'=>769,'offset'=>58220},'h2zNum'=>{'length'=>174,'offset'=>58989},'h2zKanaK'=>{'length'=>979,'offset'=>59163},'strlen'=>{'length'=>360,'offset'=>60142},'strcutu'=>{'length'=>195,'offset'=>60502},'sjis_imode2'=>{'length'=>71,'offset'=>60697},'_validate_utf8'=>{'length'=>855,'offset'=>60768},'jcode/emoji2/eu2a.dat'=>{'length'=>16384,'offset'=>374290},'set'=>{'length'=>5325,'offset'=>61623},'_ucs2_utf8'=>{'length'=>549,'offset'=>66948},'_utf16_utf16'=>{'length'=>300,'offset'=>67497},'h2zAlpha'=>{'length'=>264,'offset'=>67797},'z2hKanaK'=>{'length'=>979,'offset'=>68061},'getcodelist'=>{'length'=>2241,'offset'=>69040},'_sj2u2'=>{'length'=>1503,'offset'=>71281},'jcode/emoji2/ed2u.dat'=>{'length'=>5120,'offset'=>351466},'jis_icon_au'=>{'length'=>97,'offset'=>72784},'_utf32_ucs4'=>{'length'=>312,'offset'=>72881},'_ai2u2'=>{'length'=>410,'offset'=>73193},'utf8_icon_au2'=>{'length'=>73,'offset'=>73603},'_uj2u1'=>{'length'=>600,'offset'=>73676},'_sa2j'=>{'length'=>174,'offset'=>74276},'h2zKana'=>{'length'=>185,'offset'=>74450},'z2hKana'=>{'length'=>89,'offset'=>74635},'_si2u2'=>{'length'=>1227,'offset'=>74724},'_u2sj1'=>{'length'=>1772,'offset'=>75951},'_u2sj2'=>{'length'=>1794,'offset'=>77723},'utf8_icon_au'=>{'length'=>72,'offset'=>79517},'jis_jsky2'=>{'length'=>82,'offset'=>79589},'sjis_doti'=>{'length'=>188,'offset'=>79671},'_e2s'=>{'length'=>202,'offset'=>79859},'jcode/emoji2/ej2u2.dat'=>{'length'=>3072,'offset'=>307434},'euc'=>{'length'=>175,'offset'=>80061},'_j2s3'=>{'length'=>337,'offset'=>80236},'jcode/emoji2/ej2u.dat'=>{'length'=>3072,'offset'=>263402},'_j2sa2'=>{'length'=>446,'offset'=>80573},'ucs4'=>{'length'=>183,'offset'=>81019},'_sd2u'=>{'length'=>1221,'offset'=>81202},'_u2ja2'=>{'length'=>1640,'offset'=>82423},'_s2e2'=>{'length'=>446,'offset'=>84063},'z2hKanaD'=>{'length'=>498,'offset'=>84509},'_u2sd'=>{'length'=>1615,'offset'=>85007},'sjis_au'=>{'length'=>94,'offset'=>86622},'jcode/emoji2/eu2j2.dat'=>{'length'=>40960,'offset'=>310506},'jcode/emoji2/eu2d.dat'=>{'length'=>16384,'offset'=>356586},'jcode/u2s.dat'=>{'length'=>85504,'offset'=>92461},'_utf8_ucs2'=>{'length'=>755,'offset'=>86716},'euc_icon_au1'=>{'length'=>98,'offset'=>87471},'jis_au'=>{'length'=>195,'offset'=>87569},'_utf32le_ucs4'=>{'length'=>178,'offset'=>87764},'sjis_imode'=>{'length'=>192,'offset'=>87942},'_e2s2'=>{'length'=>535,'offset'=>88134},'_s2j2'=>{'length'=>377,'offset'=>88669},'_encodeBase64'=>{'length'=>741,'offset'=>89046},'validate_utf8'=>{'length'=>129,'offset'=>89787},'sjis_icon_au'=>{'length'=>85,'offset'=>89916},'split_csv'=>{'length'=>131,'offset'=>90001},'_sa2u2'=>{'length'=>1138,'offset'=>90132},'jis_jsky'=>{'length'=>200,'offset'=>91270},'strcut'=>{'length'=>888,'offset'=>91470},'cp932'=>{'length'=>33,'offset'=>92358},'_utf32be_ucs4'=>{'length'=>70,'offset'=>92391}}sub joinCsv {
  my $this = shift;
  my $list;
  
  if(ref($_[0]) eq 'ARRAY')
    {
      $list = shift;
      if( $]>=5.008 )
      {
	$list = [ @$list ];
	foreach(@$list)
	{
	  defined($_) and Encode::_utf8_off($_);
	}
      }
    }
  elsif(!ref($_[0]))
    {
      $list = [ @_ ];
      if( $]>=5.008 )
      {
	foreach(@$list)
	{
	  defined($_) and Encode::_utf8_off($_);
	}
      }
    }
  else
    {
      my $ref = ref($_[0]);
      die "String->joinCsv, Param[1] is not ARRAY/ARRRAY-ref. [$ref]\n";
    }
      
  my $text;
  if( $^W && grep{!defined($_)}@$list )
  {
    $_[0] && $list eq $_[0] and $list = [@$list];
    foreach(@$list)
    {
      defined($_) and next;
      warn "Use of uninitialized value in Unicode::Japanese::joinCsv";
      $_ = "";
    }
  }
  $text = join ',', map {defined($_) ? (s/"/""/g or /[\r\n,]/) ? qq("$_") : $_ : ""} @$list;

  $this->{str} = $text."\n";
  $this->{icode} = 'binary';

  $this;
}
sub _decodeBase64
{
  local($^W) = 0; # unpack("u",...) gives bogus warning in 5.00[123]

  my $this = shift;
  my $str = shift;
  my $res = "";

  $str =~ tr|A-Za-z0-9+=/||cd;            # remove non-base64 chars
  if (length($str) % 4)
    {
      warn("Length of base64 data not a multiple of 4");
    }
  $str =~ s/=+$//;                        # remove padding
  $str =~ tr|A-Za-z0-9+/| -_|;            # convert to uuencoded format
  while ($str =~ /(.{1,60})/gs)
    {
      my $len = chr(32 + length($1)*3/4); # compute length byte
      $res .= unpack("u", $len . $1 );    # uudecode
    }
  $res;
}
sub z2hNum {
  my $this = shift;

  if(!defined(%_z2hNum))
    {
      $this->_loadConvTable;
    }

  $this->{str} =~ s/(\xef\xbc\x90|\xef\xbc\x91|\xef\xbc\x92|\xef\xbc\x93|\xef\xbc\x94|\xef\xbc\x95|\xef\xbc\x96|\xef\xbc\x97|\xef\xbc\x98|\xef\xbc\x99)/$_z2hNum{$1}/eg;
  
  $this;
}
sub kata2hira {
  my $this = shift;

  if(!defined(%_kata2hira))
    {
      $this->_loadConvTable;
    }

  $this->{str} =~ s/(\xe3\x82\xa1|\xe3\x82\xa2|\xe3\x82\xa3|\xe3\x82\xa4|\xe3\x82\xa5|\xe3\x82\xa6|\xe3\x82\xa7|\xe3\x82\xa8|\xe3\x82\xa9|\xe3\x82\xaa|\xe3\x82\xab|\xe3\x82\xac|\xe3\x82\xad|\xe3\x82\xae|\xe3\x82\xaf|\xe3\x82\xb0|\xe3\x82\xb1|\xe3\x82\xb2|\xe3\x82\xb3|\xe3\x82\xb4|\xe3\x82\xb5|\xe3\x82\xb6|\xe3\x82\xb7|\xe3\x82\xb8|\xe3\x82\xb9|\xe3\x82\xba|\xe3\x82\xbb|\xe3\x82\xbc|\xe3\x82\xbd|\xe3\x82\xbe|\xe3\x82\xbf|\xe3\x83\x80|\xe3\x83\x81|\xe3\x83\x82|\xe3\x83\x83|\xe3\x83\x84|\xe3\x83\x85|\xe3\x83\x86|\xe3\x83\x87|\xe3\x83\x88|\xe3\x83\x89|\xe3\x83\x8a|\xe3\x83\x8b|\xe3\x83\x8c|\xe3\x83\x8d|\xe3\x83\x8e|\xe3\x83\x8f|\xe3\x83\x90|\xe3\x83\x91|\xe3\x83\x92|\xe3\x83\x93|\xe3\x83\x94|\xe3\x83\x95|\xe3\x83\x96|\xe3\x83\x97|\xe3\x83\x98|\xe3\x83\x99|\xe3\x83\x9a|\xe3\x83\x9b|\xe3\x83\x9c|\xe3\x83\x9d|\xe3\x83\x9e|\xe3\x83\x9f|\xe3\x83\xa0|\xe3\x83\xa1|\xe3\x83\xa2|\xe3\x83\xa3|\xe3\x83\xa4|\xe3\x83\xa5|\xe3\x83\xa6|\xe3\x83\xa7|\xe3\x83\xa8|\xe3\x83\xa9|\xe3\x83\xaa|\xe3\x83\xab|\xe3\x83\xac|\xe3\x83\xad|\xe3\x83\xae|\xe3\x83\xaf|\xe3\x83\xb0|\xe3\x83\xb1|\xe3\x83\xb2|\xe3\x83\xb3)/$_kata2hira{$1}/eg;
  
  $this;
}
sub _utf16le_utf16 {
  my $this = shift;
  my $str = shift;

  my $result = '';
  foreach my $ch (unpack('v*', $str))
    {
      $result .= pack('n', $ch);
    }
  
  $result;
}
sub _u2ai2 {
  my $this = shift;
  my $str = shift;
  
  if(!defined($str))
    {
      return '';
    }
  
  if(!defined($eu2a2))
    {
      $eu2a2 = $this->_getFile('jcode/emoji2/eu2a2.dat');
    }

  my $c1;
  my $c2;
  my $c3;
  my $c4;
  my $c5;
  my $c6;
  my $c;
  my $d;
  my $ch;
  $str =~ s/([\xc0-\xdf][\x80-\xbf]|[\xe0-\xef][\x80-\xbf]{2}|[\xf0-\xf7][\x80-\xbf]{3}|[\xf8-\xfb][\x80-\xbf]{4}|[\xfc-\xfd][\x80-\xbf]{5})|([^\x00-\x7f])/
    defined($2) ? '?' :
    ((length($1) == 1) ? $1 :
     (length($1) == 2) ? $1 :
     (length($1) == 3) ? $1 :
     (length($1) == 4) ? (
			  ($c1,$c2,$c3,$c4) = unpack("C4", $1),
			  $ch = (($c1 & 0x07)<<18)|(($c2 & 0x3F)<<12)|
			  (($c3 & 0x3f) << 6)|($c4 & 0x3F),
			  (
			   ($ch >= 0x0fe000 and $ch <= 0x0fffff) ?
			   (
			    $c = substr($eu2a2, ($ch - 0x0fe000) * 2, 2),
			    $d = unpack('n', $c),
			    $c =~ tr,\0,,d,
			    ($d <= 0x0336) ? $RE{E_ICON_AU_START} . $d . $RE{E_ICON_AU_END} :
			    ($c eq '') ? '?' : $c
			   ) :
			   '?'
			  )
			 ) :
     '?'
    )
      /eg;
  
  $str;
}
sub z2hAlpha {
  my $this = shift;

  if(!defined(%_z2hAlpha))
    {
      $this->_loadConvTable;
    }

  $this->{str} =~ s/(\xef\xbc\xa1|\xef\xbc\xa2|\xef\xbc\xa3|\xef\xbc\xa4|\xef\xbc\xa5|\xef\xbc\xa6|\xef\xbc\xa7|\xef\xbc\xa8|\xef\xbc\xa9|\xef\xbc\xaa|\xef\xbc\xab|\xef\xbc\xac|\xef\xbc\xad|\xef\xbc\xae|\xef\xbc\xaf|\xef\xbc\xb0|\xef\xbc\xb1|\xef\xbc\xb2|\xef\xbc\xb3|\xef\xbc\xb4|\xef\xbc\xb5|\xef\xbc\xb6|\xef\xbc\xb7|\xef\xbc\xb8|\xef\xbc\xb9|\xef\xbc\xba|\xef\xbd\x81|\xef\xbd\x82|\xef\xbd\x83|\xef\xbd\x84|\xef\xbd\x85|\xef\xbd\x86|\xef\xbd\x87|\xef\xbd\x88|\xef\xbd\x89|\xef\xbd\x8a|\xef\xbd\x8b|\xef\xbd\x8c|\xef\xbd\x8d|\xef\xbd\x8e|\xef\xbd\x8f|\xef\xbd\x90|\xef\xbd\x91|\xef\xbd\x92|\xef\xbd\x93|\xef\xbd\x94|\xef\xbd\x95|\xef\xbd\x96|\xef\xbd\x97|\xef\xbd\x98|\xef\xbd\x99|\xef\xbd\x9a)/$_z2hAlpha{$1}/eg;
  
  $this;
}
sub _ucs4_utf8 {
  my $this = shift;
  my $str = shift;
  
  if(!defined($str))
    {
      return '';
    }
  
  my $result = '';
  for my $uc (unpack("N*", $str))
    {
      $result .= ($uc < 0x80) ? chr($uc) :
	($uc < 0x800) ? chr(0xC0 | ($uc >> 6)) . chr(0x80 | ($uc & 0x3F)) :
	  ($uc < 0x10000) ? chr(0xE0 | ($uc >> 12)) . chr(0x80 | (($uc >> 6) & 0x3F)) . chr(0x80 | ($uc & 0x3F)) :
	    ($uc < 0x200000) ? chr(0xF0 | ($uc >> 18)) . chr(0x80 | (($uc >> 12) & 0x3F)) . chr(0x80 | (($uc >> 6) & 0x3F)) . chr(0x80 | ($uc & 0x3F)) :
	      ($uc < 0x4000000) ? chr(0xF8 | ($uc >> 24)) . chr(0x80 | (($uc >> 18) & 0x3F)) . chr(0x80 | (($uc >> 12) & 0x3F)) . chr(0x80 | (($uc >> 6) & 0x3F)) . chr(0x80 | ($uc & 0x3F)) :
		chr(0xFC | ($uc >> 30)) . chr(0x80 | (($uc >> 24) & 0x3F)) . chr(0x80 | (($uc >> 18) & 0x3F)) . chr(0x80 | (($uc >> 12) & 0x3F)) . chr(0x80 | (($uc >> 6) & 0x3F)) . chr(0x80 | ($uc & 0x3F));
    }
  
  $result;
}
sub h2zSym {
  my $this = shift;

  if(!defined(%_h2zSym))
    {
      $this->_loadConvTable;
    }

  $this->{str} =~ s/(\x20|\x21|\x22|\x23|\x24|\x25|\x26|\x27|\x28|\x29|\x2a|\x2b|\x2c|\x2d|\x2e|\x2f|\x3a|\x3b|\x3c|\x3d|\x3e|\x3f|\x40|\x5b|\x5c|\x5d|\x5e|_|\x60|\x7b|\x7c|\x7d|\x7e)/$_h2zSym{$1}/eg;
  
  $this;
}
sub utf8_icon_au1
{
  my $this = shift;
  $this->_u2ai1($this->{str});
}
sub h2z {
  my $this = shift;

  $this->h2zKana;
  $this->h2zNum;
  $this->h2zAlpha;
  $this->h2zSym;

  $this;
}
# -----------------------------------------------------------------------------
# $bytes_sjis = $unijp->sjis();
# 
sub sjis
{
  my $this = shift;
  $this->_u2s($this->{str});
}
sub euc_icon_au2
{
  my $this = shift;
  $this->_s2e($this->_u2s($this->_u2ai2($this->{str})));
}
sub _u2si1 {
  my $this = shift;
  my $str = shift;

  if(!defined($str))
    {
      return '';
    }
  
  if(!defined($u2s_table))
    {
      $u2s_table = $this->_getFile('jcode/u2s.dat');
    }

  if(!defined($eu2i1))
    {
      $eu2i1 = $this->_getFile('jcode/emoji2/eu2i.dat');
    }

  my $c1;
  my $c2;
  my $c3;
  my $c4;
  my $c5;
  my $c6;
  my $c;
  my $ch;
  $str =~ s/([\xc0-\xdf][\x80-\xbf]|[\xe0-\xef][\x80-\xbf]{2}|[\xf0-\xf7][\x80-\xbf]{3}|[\xf8-\xfb][\x80-\xbf]{4}|[\xfc-\xfd][\x80-\xbf]{5})|([^\x00-\x7f])/
    defined($2) ? '?' :
    ((length($1) == 1) ? $1 :
     (length($1) == 2) ? (
			  ($c1,$c2) = unpack("C2", $1),
			  $ch = (($c1 & 0x1F)<<6)|($c2 & 0x3F),
			  $c = substr($u2s_table, $ch * 2, 2),
			  ($c eq "\0\0") ? '?' : $c
			 ) :
     (length($1) == 3) ? (
			  ($c1,$c2,$c3) = unpack("C3", $1),
			  $ch = (($c1 & 0x0F)<<12)|(($c2 & 0x3F)<<6)|($c3 & 0x3F),
			  (
			   ($ch <= 0x9fff) ?
			   $c = substr($u2s_table, $ch * 2, 2) :
			   ($ch >= 0xf900 and $ch <= 0xffff) ?
			   (
			    $c = substr($u2s_table, ($ch - 0xf900 + 0xa000) * 2, 2),
			    (($c =~ tr,\0,,d)==2 and $c = "\0\0"),
			   ) :
			   (
			    $c = '?'
			   )
			  ),
			  ($c eq "\0\0") ? '?' : $c
			 ) :
     (length($1) == 4) ? (
			  ($c1,$c2,$c3,$c4) = unpack("C4", $1),
			  $ch = (($c1 & 0x07)<<18)|(($c2 & 0x3F)<<12)|
			  (($c3 & 0x3f) << 6)|($c4 & 0x3F),
			  (
			   ($ch >= 0x0fe000 and $ch <= 0x0fffff) ?
			   (
			    $c = substr($eu2i1, ($ch - 0x0fe000) * 2, 2),
			    $c =~ tr,\0,,d,
			    ($c eq '') ? '?' : $c
			   ) :
			   '?'
			  )
			 ) :
     '?'
    )
      /eg;
  $str;
  
}
sub _sj2u1 {
  my $this = shift;
  my $str = shift;

  if(!defined($str))
    {
      return '';
    }
  
  if(!defined($s2u_table))
    {
      $s2u_table = $this->_getFile('jcode/s2u.dat');
    }

  if(!defined($ej2u1))
    {
      $ej2u1 = $this->_getFile('jcode/emoji2/ej2u.dat');
    }

  my $l;
  my $j1;
  my $uc;
  $str =~ s/($RE{SJIS_KANA}|$RE{SJIS_DBCS}|$RE{E_JSKYv1}|[\x80-\xff])/
    (length($1) <= 2) ? 
      (
       $l = (unpack('n', $1) or unpack('C', $1)),
       (
	($l >= 0xa1 and $l <= 0xdf)     ?
	(
	 $uc = substr($s2u_table, ($l - 0xa1) * 3, 3),
	 $uc =~ tr,\0,,d,
	 $uc
	) :
	($l >= 0x8100 and $l <= 0x9fff) ?
	(
	 $uc = substr($s2u_table, ($l - 0x8100 + 0x3f) * 3, 3),
	 $uc =~ tr,\0,,d,
	 $uc
	) :
	($l >= 0xe000 and $l <= 0xffff) ?
	(
	 $uc = substr($s2u_table, ($l - 0xe000 + 0x1f3f) * 3, 3),
	 $uc =~ tr,\0,,d,
	 $uc
	) :
	($l < 0x80) ?
	chr($l) :
	'?'
       )
      ) :
	(
         $l = $1,
	 $l =~ s,^$RE{E_JSKY_START}($RE{E_JSKY1v1}),,o,
	 $j1 = $1,
	 $uc = '',
	 $l =~ s!($RE{E_JSKY2})!$uc .= substr($ej2u1, (unpack('n', $j1 . $1) - 0x4500) * 4, 4), ''!ego,
	 $uc =~ tr,\0,,d,
	 $uc
	)
  /eg;
  
  $str;
  
}
# -----------------------------------------------------------------------------
# tag2bin
#
sub tag2bin {
  my $this = shift;

  $this->{str} =~ s/\&(\#\d+|\#x[a-f0-9A-F]+);/
    (substr($1, 1, 1) eq 'x') ? $this->_ucs4_utf8(pack('N', hex(substr($1, 2)))) :
      $this->_ucs4_utf8(pack('N', substr($1, 1)))
	/eg;
  
  $this;
}
sub euc_icon_au
{
  my $this = shift;
  $this->_s2e($this->_u2s($this->_u2ai2($this->{str})));
}
sub z2hSym {
  my $this = shift;

  if(!defined(%_z2hSym))
    {
      $this->_loadConvTable;
    }

  $this->{str} =~ s/(\xe3\x80\x80|\xef\xbc\x8c|\xef\xbc\x8e|\xef\xbc\x9a|\xef\xbc\x9b|\xef\xbc\x9f|\xef\xbc\x81|\xef\xbd\x80|\xef\xbc\xbe|\xef\xbc\xbf|\xef\xbc\x8f|\xef\xbd\x9e|\xef\xbd\x9c|\xe2\x80\x99|\xe2\x80\x9d|\xef\xbc\x88|\xef\xbc\x89|\xef\xbc\xbb|\xef\xbc\xbd|\xef\xbd\x9b|\xef\xbd\x9d|\xef\xbc\x8b|\xef\xbc\x8d|\xef\xbc\x9d|\xef\xbc\x9c|\xef\xbc\x9e|\xef\xbf\xa5|\xef\xbc\x84|\xef\xbc\x85|\xef\xbc\x83|\xef\xbc\x86|\xef\xbc\x8a|\xef\xbc\xa0|\xe3\x80\x9c)/$_z2hSym{$1}/eg;
  
  $this;
}
# -----------------------------------------------------------------------------
# $bytes_ucs2 = $unijp->ucs2();
# 
sub ucs2
{
  my $this = shift;
  $this->_utf8_ucs2($this->{str});
}
sub jis_au2
{
  my $this = shift;
  $this->_s2j($this->_u2ja2($this->{str}));
}
sub _si2u1 {
  my $this = shift;
  my $str = shift;

  if(!defined($str))
    {
      return '';
    }
  
  if(!defined($s2u_table))
    {
      $s2u_table = $this->_getFile('jcode/s2u.dat');
    }

  if(!defined($ei2u1))
    {
      $ei2u1 = $this->_getFile('jcode/emoji2/ei2u.dat');
    }

  $str =~ s/(\&\#(\d+);)/
    ($2 >= 0xf800 and $2 <= 0xf9ff) ? pack('n', $2) : $1
      /eg;
  
  my $l;
  my $uc;
  $str =~ s/($RE{SJIS_KANA}|$RE{SJIS_DBCS}|$RE{E_IMODEv1}|[\x80-\xff])/
    $S2U{$1}
      or ($S2U{$1} =
	  (
	   $l = (unpack('n', $1) or unpack('C', $1)),
	   (
	    ($l >= 0xa1 and $l <= 0xdf)     ?
	    (
	     $uc = substr($s2u_table, ($l - 0xa1) * 3, 3),
	     $uc =~ tr,\0,,d,
	     $uc
	    ) :
	    ($l >= 0x8100 and $l <= 0x9fff) ?
	    (
	     $uc = substr($s2u_table, ($l - 0x8100 + 0x3f) * 3, 3),
	     $uc =~ tr,\0,,d,
	     $uc
	    ) :
	    ($l >= 0xf800 and $l <= 0xf9ff) ?
	    (
	     $uc = substr($ei2u1, ($l - 0xf800) * 4, 4),
	     $uc =~ tr,\0,,d,
	     $uc
	    ) :
	    ($l >= 0xe000 and $l <= 0xffff) ?
	    (
	     $uc = substr($s2u_table, ($l - 0xe000 + 0x1f3f) * 3, 3),
	     $uc =~ tr,\0,,d,
	     $uc
	    ) :
	    ($l < 0x80) ?
	    chr($l) :
	    '?'
	   )
	  )
	 )/eg;
  
  $str;
  
}
sub _utf8_utf16 {
  my $this = shift;
  my $str = shift;
  
  if(!defined($str))
    {
      return '';
    }

  my $c1;
  my $c2;
  my $c3;
  my $c4;
  my $uc;
  $str =~ s/([\x00-\x7f]|[\xc0-\xdf][\x80-\xbf]|[\xe0-\xef][\x80-\xbf]{2}|[\xf0-\xf7][\x80-\xbf]{3}|[\xf8-\xfb][\x80-\xbf]{4}|[\xfc-\xfd][\x80-\xbf]{5})/
    $T2U{$1}
      or ($T2U{$1}
	  = ((length($1) == 1) ? pack("n", unpack("C", $1)) :
	     (length($1) == 2) ? (($c1,$c2) = unpack("C2", $1),
				  pack("n", (($c1 & 0x1F)<<6)|($c2 & 0x3F))) :
	     (length($1) == 3) ? (($c1,$c2,$c3) = unpack("C3", $1),
				  pack("n", (($c1 & 0x0F)<<12)|(($c2 & 0x3F)<<6)|($c3 & 0x3F))) :
	     (length($1) == 4) ? (($c1,$c2,$c3,$c4) = unpack("C4", $1),
				  ($uc = ((($c1 & 0x07) << 18)|(($c2 & 0x3F) << 12)|
					  (($c3 & 0x3f) << 6)|($c4 & 0x3F)) - 0x10000),
				  (($uc < 0x100000) ? pack("nn", (($uc >> 10) | 0xd800), (($uc & 0x3ff) | 0xdc00)) : "\0?")) :
	     "\0?")
	 );
  /eg;
  $str;
}
sub jis_icon_au1
{
  my $this = shift;
  $this->_s2j($this->_u2s($this->_u2ai1($this->{str})));
}
sub sjis_icon_au1
{
  my $this = shift;
  $this->_u2s($this->_u2ai1($this->{str}));
}
sub sjis_jsky2
{
  my $this = shift;
  $this->_u2sj2($this->{str});
}
# -----------------------------------------------------------------------------
# $code = Unicode::Japanese->getcode($str);
# 
sub getcode {
  my $this = shift;
  my $str = shift;

  if( $]>=5.008 )
  {
    Encode::_utf8_off($str);
  }
  
  my $l = length($str);
  
  if((($l % 4) == 0)
     and ($str =~ m/^(?:$RE{BOM4_BE}|$RE{BOM4_LE})/o))
    {
      return 'utf32';
    }
  if((($l % 2) == 0)
     and ($str =~ m/^(?:$RE{BOM2_BE}|$RE{BOM2_LE})/o))
    {
      return 'utf16';
    }

  my $str2;
  
  if(($l % 4) == 0)
    {
      $str2 = $str;
      1 while($str2 =~ s/^(?:$RE{UTF32_BE})//o);
      if($str2 eq '')
	{
	  return 'utf32-be';
	}
      
      $str2 = $str;
      1 while($str2 =~ s/^(?:$RE{UTF32_LE})//o);
      if($str2 eq '')
	{
	  return 'utf32-le';
	}
    }
  
  if($str !~ m/[\e\x80-\xff]/)
    {
      return 'ascii';
    }

  if($str =~ m/$RE{JIS_0208}|$RE{JIS_0212}|$RE{JIS_ASC}|$RE{JIS_KANA}/o)
    {
      if($str =~ m/(?:$RE{JIS_0208})(?:[^\e]{2})*$RE{E_JIS_AU}/o)
	{
	  return 'jis-au';
	}
      elsif($str =~ m/(?:$RE{E_JSKY})/o)
	{
	  return 'jis-jsky';
	}
      else
	{
	  return 'jis';
	}
    }

  if($str =~ m/(?:$RE{E_JSKY})/o)
    {
      return 'sjis-jsky';
    }

  $str2 = $str;
  1 while($str2 =~ s/^(?:$RE{ASCII}|$RE{EUC_0212}|$RE{EUC_KANA}|$RE{EUC_C})//o);
  if($str2 eq '')
    {
      return 'euc';
    }

  $str2 = $str;
  1 while($str2 =~ s/^(?:$RE{ASCII}|$RE{SJIS_DBCS}|$RE{SJIS_KANA})//o);
  if($str2 eq '')
    {
      return 'sjis';
    }
  if($str =~ m/^(?:$RE{E_SJIS_AU})/o)
    {
      return 'sjis-au';
    }


  my $str3;
  $str3 = $str2;
  1 while($str3 =~ s/^(?:$RE{ASCII}|$RE{SJIS_DBCS}|$RE{SJIS_KANA}|$RE{E_IMODE})//o);
  if($str3 eq '')
    {
      return 'sjis-imode';
    }

  $str3 = $str2;
  1 while($str3 =~ s/^(?:$RE{ASCII}|$RE{SJIS_DBCS}|$RE{SJIS_KANA}|$RE{E_DOTI})//o);
  if($str3 eq '')
    {
      return 'sjis-doti';
    }

  $str2 = $str;
  1 while($str2 =~ s/^(?:$RE{UTF8})//o);
  if($str2 eq '')
    {
      return 'utf8';
    }

  return 'unknown';
}
sub _j2s2 {
  my $this = shift;
  my $esc = shift;
  my $str = shift;

  if($esc eq $ESC{JIS_0212})
    {
      $str =~ s/../$CHARCODE{UNDEF_SJIS}/g;
    }
  elsif($esc !~ m/^$RE{JIS_ASC}/)
    {
      $str =~ s{([\x21-\x7e]+)}{
        my $str = $1;
        $str =~ tr/\x21-\x7e/\xa1-\xfe/;
        if($esc =~ m/^$RE{JIS_0208}/)
	  {
	    $str =~ s/($RE{EUC_C})/
	      $J2S[unpack('n', $1)] or $this->_j2s3($1)
	        /geo;
	  }
	$str;
      }e;
    }
  
  $str;
}
sub sjis_au2
{
  my $this = shift;
  $this->_j2sa($this->_s2j($this->_u2ja2($this->{str})));
}
sub h2zKanaD {
  my $this = shift;

  if(!defined(%_h2zKanaD))
    {
      $this->_loadConvTable;
    }

  $this->{str} =~ s/(\xef\xbd\xb3\xef\xbe\x9e|\xef\xbd\xb6\xef\xbe\x9e|\xef\xbd\xb7\xef\xbe\x9e|\xef\xbd\xb8\xef\xbe\x9e|\xef\xbd\xb9\xef\xbe\x9e|\xef\xbd\xba\xef\xbe\x9e|\xef\xbd\xbb\xef\xbe\x9e|\xef\xbd\xbc\xef\xbe\x9e|\xef\xbd\xbd\xef\xbe\x9e|\xef\xbd\xbe\xef\xbe\x9e|\xef\xbd\xbf\xef\xbe\x9e|\xef\xbe\x80\xef\xbe\x9e|\xef\xbe\x81\xef\xbe\x9e|\xef\xbe\x82\xef\xbe\x9e|\xef\xbe\x83\xef\xbe\x9e|\xef\xbe\x84\xef\xbe\x9e|\xef\xbe\x8a\xef\xbe\x9e|\xef\xbe\x8a\xef\xbe\x9f|\xef\xbe\x8b\xef\xbe\x9e|\xef\xbe\x8b\xef\xbe\x9f|\xef\xbe\x8c\xef\xbe\x9e|\xef\xbe\x8c\xef\xbe\x9f|\xef\xbe\x8d\xef\xbe\x9e|\xef\xbe\x8d\xef\xbe\x9f|\xef\xbe\x8e\xef\xbe\x9e|\xef\xbe\x8e\xef\xbe\x9f)/$_h2zKanaD{$1}/eg;
  
  $this;
}
sub sjis_imode1
{
  my $this = shift;
  $this->_u2si1($this->{str});
}
sub eucjp
{
  shift->euc(@_);
}
# -----------------------------------------------------------------------------
# $bytes_utf8 = $unijp->utf8();
# 
sub utf8
{
  my $this = shift;
  $this->_validate_utf8($this->{str});
}
sub _s2e {
  my $this = shift;
  my $str = shift;
  
  if( $]>=5.008 )
  {
    Encode::_utf8_off($str);
  }

  $str =~ s/($RE{SJIS_DBCS}|$RE{SJIS_KANA})/
    $S2E[unpack('n', $1) or unpack('C', $1)] or $this->_s2e2($1)
      /geo;
  
  $str;
}
# -----------------------------------------------------------------------------
# $bytes_utf8 = $unijp->utf8_jsky();
# 
sub utf8_jsky
{
  my $this = shift;
  $this->_u2uj2($this->{str});
}
# utf8-jsky2 => utf8.
sub _uj2u2 {
  my $this = shift;
  my $str = shift;

  if(!defined($str))
  {
    return '';
  }
  
  if(!defined($s2u_table))
  {
    $s2u_table = $this->_getFile('jcode/s2u.dat');
  }

  if(!defined($ej2u1))
  {
    $ej2u1 = $this->_getFile('jcode/emoji2/ej2u.dat');
  }
  if(!defined($ej2u2))
  {
    $ej2u2 = $this->_getFile('jcode/emoji2/ej2u2.dat');
  }

  $str = $this->_validate_utf8($str);
  
  my @umap = (0x200, 0x000, 0x100);
  $str =~ s{($RE{E_JSKYv1_UTF8}+)}{
    join('',
      map{
        my $l = $_ - 0xe000;
        substr($ej2u1, ($umap[$l/256]+($l&255)+0x20) * 4, 4);
      } unpack("n*", $this->_utf8_ucs2($1))
    )
  }geo;
  $str =~ s{($RE{E_JSKYv2_UTF8}+)}{
    join('',
      map{
        my $l = $_ - 0xe300 + 0x20;
        substr($ej2u2, $l * 4, 4);
      } unpack("n*", $this->_utf8_ucs2($1))
    )
  }geo;
  
  $str;
  
}
sub utf8_jsky1
{
  my $this = shift;
  $this->_u2uj1($this->{str});
}
# -----------------------------------------------------------------------------
# $bytes_str = $unijp->conv($ocode,[$encode]);
# 
sub conv {
  my $this = shift;
  my $ocode = shift;
  my $encode = shift;
  my (@option) = @_;

  my $res;
  if(!defined($ocode))
    {
      use Carp;
      croak(qq(String->conv, Param[1] is undef.));
    }
  elsif($ocode eq 'utf8')
    {
      $res = $this->utf8;
    }
  elsif($ocode eq 'euc' || $ocode eq 'euc-jp' )
    {
      $res = $this->euc;
    }
  elsif($ocode eq 'jis')
    {
      $res = $this->jis;
    }
  elsif($ocode eq 'sjis' || $ocode eq 'cp932')
    {
      $res = $this->sjis;
    }
  elsif($ocode eq 'sjis-imode')
    {
      $res = $this->sjis_imode;
    }
  elsif($ocode eq 'sjis-imode1')
    {
      $res = $this->sjis_imode1;
    }
  elsif($ocode eq 'sjis-imode2')
    {
      $res = $this->sjis_imode2;
    }
  elsif($ocode eq 'sjis-doti')
    {
      $res = $this->sjis_doti;
    }
  elsif($ocode eq 'sjis-doti1')
    {
      $res = $this->sjis_doti;
    }
  elsif($ocode eq 'sjis-jsky')
    {
      $res = $this->sjis_jsky;
    }
  elsif($ocode eq 'sjis-jsky1')
    {
      $res = $this->sjis_jsky1;
    }
  elsif($ocode eq 'sjis-jsky2')
    {
      $res = $this->sjis_jsky2;
    }
  elsif($ocode eq 'jis-jsky')
    {
      $res = $this->jis_jsky;
    }
  elsif($ocode eq 'jis-jsky1')
    {
      $res = $this->jis_jsky1;
    }
  elsif($ocode eq 'jis-jsky2')
    {
      $res = $this->jis_jsky2;
    }
  elsif($ocode eq 'utf8-jsky')
    {
      $res = $this->utf8_jsky;
    }
  elsif($ocode eq 'utf8-jsky1')
    {
      $res = $this->utf8_jsky1;
    }
  elsif($ocode eq 'utf8-jsky2')
    {
      $res = $this->utf8_jsky2;
    }
  elsif($ocode eq 'jis-au')
    {
      $res = $this->jis_au2;
    }
  elsif($ocode eq 'jis-au1')
    {
      $res = $this->jis_au1;
    }
  elsif($ocode eq 'jis-au2')
    {
      $res = $this->jis_au2;
    }
  elsif($ocode eq 'sjis-au')
    {
      $res = $this->sjis_au2;
    }
  elsif($ocode eq 'sjis-au1')
    {
      $res = $this->sjis_au1;
    }
  elsif($ocode eq 'sjis-au2')
    {
      $res = $this->sjis_au2;
    }
  elsif($ocode eq 'sjis-icon-au')
    {
      $res = $this->sjis_icon_au2;
    }
  elsif($ocode eq 'sjis-icon-au1')
    {
      $res = $this->sjis_icon_au1;
    }
  elsif($ocode eq 'sjis-icon-au2')
    {
      $res = $this->sjis_icon_au2;
    }
  elsif($ocode eq 'jis-icon-au')
    {
      $res = $this->jis_icon_au2;
    }
  elsif($ocode eq 'jis-icon-au1')
    {
      $res = $this->jis_icon_au1;
    }
  elsif($ocode eq 'jis-icon-au2')
    {
      $res = $this->jis_icon_au2;
    }
  elsif($ocode eq 'euc-icon-au')
    {
      $res = $this->euc_icon_au2;
    }
  elsif($ocode eq 'euc-icon-au1')
    {
      $res = $this->euc_icon_au1;
    }
  elsif($ocode eq 'euc-icon-au2')
    {
      $res = $this->euc_icon_au2;
    }
  elsif($ocode eq 'utf8-icon-au')
    {
      $res = $this->utf8_icon_au2;
    }
  elsif($ocode eq 'utf8-icon-au1')
    {
      $res = $this->utf8_icon_au1;
    }
  elsif($ocode eq 'utf8-icon-au2')
    {
      $res = $this->utf8_icon_au2;
    }
  elsif($ocode eq 'ucs2')
    {
      $res = $this->ucs2;
    }
  elsif($ocode eq 'ucs4')
    {
      $res = $this->ucs4;
    }
  elsif($ocode eq 'utf16')
    {
      $res = $this->utf16;
    }
  elsif($ocode eq 'binary')
    {
      $res = $this->{str};
    }
  else
    {
      use Carp;
      croak(qq(String->conv, Param[1] "$ocode" is error.));
    }

  if(defined($encode))
    {
      if($encode eq 'base64')
	{
	  $res = $this->_encodeBase64($res, @option);
	}
      else
	{
	  use Carp;
	  croak(qq(String->conv, Param[2] "$encode" encode name error.));
	}
    }

  $res;
}
sub _utf16be_utf16 {
  my $this = shift;
  my $str = shift;

  $str;
}
sub hira2kata {
  my $this = shift;

  if(!defined(%_hira2kata))
    {
      $this->_loadConvTable;
    }

  $this->{str} =~ s/(\xe3\x81\x81|\xe3\x81\x82|\xe3\x81\x83|\xe3\x81\x84|\xe3\x81\x85|\xe3\x81\x86|\xe3\x81\x87|\xe3\x81\x88|\xe3\x81\x89|\xe3\x81\x8a|\xe3\x81\x8b|\xe3\x81\x8c|\xe3\x81\x8d|\xe3\x81\x8e|\xe3\x81\x8f|\xe3\x81\x90|\xe3\x81\x91|\xe3\x81\x92|\xe3\x81\x93|\xe3\x81\x94|\xe3\x81\x95|\xe3\x81\x96|\xe3\x81\x97|\xe3\x81\x98|\xe3\x81\x99|\xe3\x81\x9a|\xe3\x81\x9b|\xe3\x81\x9c|\xe3\x81\x9d|\xe3\x81\x9e|\xe3\x81\x9f|\xe3\x81\xa0|\xe3\x81\xa1|\xe3\x81\xa2|\xe3\x81\xa3|\xe3\x81\xa4|\xe3\x81\xa5|\xe3\x81\xa6|\xe3\x81\xa7|\xe3\x81\xa8|\xe3\x81\xa9|\xe3\x81\xaa|\xe3\x81\xab|\xe3\x81\xac|\xe3\x81\xad|\xe3\x81\xae|\xe3\x81\xaf|\xe3\x81\xb0|\xe3\x81\xb1|\xe3\x81\xb2|\xe3\x81\xb3|\xe3\x81\xb4|\xe3\x81\xb5|\xe3\x81\xb6|\xe3\x81\xb7|\xe3\x81\xb8|\xe3\x81\xb9|\xe3\x81\xba|\xe3\x81\xbb|\xe3\x81\xbc|\xe3\x81\xbd|\xe3\x81\xbe|\xe3\x81\xbf|\xe3\x82\x80|\xe3\x82\x81|\xe3\x82\x82|\xe3\x82\x83|\xe3\x82\x84|\xe3\x82\x85|\xe3\x82\x86|\xe3\x82\x87|\xe3\x82\x88|\xe3\x82\x89|\xe3\x82\x8a|\xe3\x82\x8b|\xe3\x82\x8c|\xe3\x82\x8d|\xe3\x82\x8e|\xe3\x82\x8f|\xe3\x82\x90|\xe3\x82\x91|\xe3\x82\x92|\xe3\x82\x93)/$_hira2kata{$1}/eg;
  
  $this;
}
sub splitCsvu
{
  my $this = shift;
  my $result = &splitCsv;
  
  if( $]>=5.008 && $this->{icode} ne 'binary' )
  {
    foreach(@$result)
    {
      Encode::_utf8_on($_);
    }
  }

  $result;
}
sub sjis_doti1
{
  my $this = shift;
  $this->_u2sd($this->{str});
}
# -----------------------------------------------------------------------------
# conversion methods (private).
# 
sub _s2j {
  my $this = shift;
  my $str = shift;

  $str =~ s/((?:$RE{SJIS_DBCS}|$RE{SJIS_KANA})+)/
    $this->_s2j2($1) . $ESC{ASC}
      /geo;

  $str;
}
sub _sa2j2 {
  my $this = shift;
  my $str = shift;

  $str =~ s/((?:$RE{SJIS_DBCS}|$RE{E_SJIS_AU})+|(?:$RE{SJIS_KANA})+)/
    my $s = $1;
  if($s =~ m,^$RE{SJIS_KANA},o)
    {
      $s =~ tr,\xa1-\xdf,\x21-\x5f,;
      $ESC{KANA} . $s
    }
  else
    {
      $s =~ s!($RE{SJIS_DBCS}|$RE{E_SJIS_AU})!
	$this->_sa2j3($1)
	  !geo;
      $ESC{JIS_0208} . $s;
    }
  /geo;
  
  $str;
}
sub _j2sa {
  my $this = shift;
  my $str = shift;

  $str =~ s/($RE{JIS_0208}|$RE{JIS_0212}|$RE{JIS_ASC}|$RE{JIS_KANA})([^\e]*)/
    $this->_j2sa2($1, $2)
      /geo;

  $str;
}
sub sjis_au1
{
  my $this = shift;
  $this->_j2sa($this->_s2j($this->_u2ja1($this->{str})));
}
sub join_csv {
  &joinCsv;
}
# utf8���<IMG ICON="">ʸ����AU��ʸ�������ɤ��Ѵ�
sub _ai2u1 {
  my $this = shift;
  my $str = shift;
  
  if(!defined($str))
    {
      return '';
    }
  
  if(!defined($ea2u1))
    {
      $ea2u1 = $this->_getFile('jcode/emoji2/ea2u.dat');
    }

  my $c;
  $str =~ s/$RE{E_ICON_AU_START}(\d+)$RE{E_ICON_AU_END}/
    ($1 > 0 and $1 <= 0x14a) ?
      ($c = substr($ea2u1, ($1-1) * 4, 4), $c =~ tr,\0,,d, ($c eq '') ? '?' : $c) :
	'?'
    /ige;

  $str;
}
# -----------------------------------------------------------------------------
# sjis/��ʸ�� => utf8
# 
sub _s2u {
  my $this = shift;
  my $str = shift;

  if(!defined($str))
    {
      return '';
    }
  
  if(!defined($s2u_table))
    {
      $s2u_table = $this->_getFile('jcode/s2u.dat');
    }

  my $l;
  my $uc;
  $str =~ s/($RE{SJIS_KANA}|$RE{SJIS_DBCS}|[\x80-\xff])/
    $S2U{$1}
      or ($S2U{$1} =
	  (
	   $l = (unpack('n', $1) or unpack('C', $1)),
	   (
	    ($l >= 0xa1 and $l <= 0xdf)     ?
	    (
	     $uc = substr($s2u_table, ($l - 0xa1) * 3, 3),
	     $uc =~ tr,\0,,d,
	     $uc
	    ) :
	    ($l >= 0x8100 and $l <= 0x9fff) ?
	    (
	     $uc = substr($s2u_table, ($l - 0x8100 + 0x3f) * 3, 3),
	     $uc =~ tr,\0,,d,
	     $uc
	    ) :
	    ($l >= 0xe000 and $l <= 0xfcff) ?
	    (
	     $uc = substr($s2u_table, ($l - 0xe000 + 0x1f3f) * 3, 3),
	     $uc =~ tr,\0,,d,
	     $uc
	    ) :
	    ($l < 0x80) ?
	    chr($l) :
	    '?'
	   )
	  )
	 )/eg;
  
  $str;
  
}
sub jis_jsky1
{
  my $this = shift;
  $this->_s2j($this->_u2sj1($this->{str}));
}
sub jis_icon_au2
{
  my $this = shift;
  $this->_s2j($this->_u2s($this->_u2ai2($this->{str})));
}
sub _j2sa3 {
  my $this = shift;
  my $c = shift;

  my ($c1, $c2) = unpack('CC', $c);
  if ($c1 % 2)
    {
      $c1 = ($c1>>1) + ($c1 < 0xdf ? 0x31 : 0x71);
      $c2 -= 0x60 + ($c2 < 0xe0);
    }
  else
    {
      $c1 = ($c1>>1) + ($c1 < 0xdf ? 0x30 : 0x70);
      $c2 -= 2;
    }
  $c1 = 0xf6 if($c1 == 0xeb);
  $c1 = 0xf7 if($c1 == 0xec);
  $c1 = 0xf3 if($c1 == 0xed);
  $c1 = 0xf4 if($c1 == 0xee);
  
  pack('CC', $c1, $c2);
}
# -----------------------------------------------------------------------------
# $bytes_jsky = $unijp->sjis_jsky();
# 
sub sjis_jsky
{
  my $this = shift;
  $this->_u2sj2($this->{str});
}
sub _u2uj2
{
  my $this = shift;
  
  if(!defined($eu2j2))
  {
    $eu2j2 = $this->_getFile('jcode/emoji2/eu2j2.dat');
  }
  
  my $str = $this->_validate_utf8($this->{str});
  
  $str =~ s{([\xf0-\xf7][\x80-\xbf]{3})}{
    my ($c1,$c2,$c3,$c4) = unpack("C4", $1);
    my $ch = (($c1 & 0x07)<<18) | (($c2 & 0x3F)<<12) |
             (($c3 & 0x3f)<< 6) | ($c4 & 0x3F);
    if( 0x0fe000 <= $ch && $ch <= 0x0fffff )
    {
      my $c = substr($eu2j2, ($ch - 0x0fe000) * 5, 5);
      $c =~ tr,\0,,d;
      $c eq '' and $c = '?';
      if( $c =~ /^\e\$([GEFOPQ])(.)\x0f/ )
      {
        my ($j1,$j2) = ($1,$2);
        $j1 =~ tr/GEFOPQ/\xe0-\xe5/;
        $j2 =~ tr/!-z/\x01-\x5a/;
        $c = $this->_ucs2_utf8($j1.$j2);
      }
      $c;
    }else
    {
      '?';
    }
  }ge;
  $str;
}
# -----------------------------------------------------------------------------
# $bytes_iso2022jp = $unijp->jis();
# 
sub jis
{
  my $this = shift;
  $this->_s2j($this->sjis);
}
sub jis_au1
{
  my $this = shift;
  $this->_s2j($this->_u2ja1($this->{str}));
}
sub _utf8_ucs4 {
  my $this = shift;
  my $str = shift;
  
  if(!defined($str))
    {
      return '';
    }

  my $c1;
  my $c2;
  my $c3;
  my $c4;
  my $c5;
  my $c6;
  $str =~ s/([\x00-\x7f]|[\xc0-\xdf][\x80-\xbf]|[\xe0-\xef][\x80-\xbf]{2}|[\xf0-\xf7][\x80-\xbf]{3}|[\xf8-\xfb][\x80-\xbf]{4}|[\xfc-\xfd][\x80-\xbf]{5}|(.))/
    defined($2) ? "\0\0\0$2" : 
    (length($1) == 1) ? pack("N", unpack("C", $1)) :
    (length($1) == 2) ? 
      do {
        ($c1,$c2) = unpack("C2", $1);
        my $n = (($c1 & 0x1F) << 6)|($c2 & 0x3F);
        pack("N", $n>=0x80 ? $n : unpack("C",'?'));
      } :
    (length($1) == 3) ?
      do {
        ($c1,$c2,$c3) = unpack("C3", $1);
        my $n = (($c1 & 0x0F) << 12)|(($c2 & 0x3F) << 6)| ($c3 & 0x3F);
        pack("N", $n>=0x800 ? $n : unpack("C",'?'));
      } :
    (length($1) == 4) ?
      do {
        ($c1,$c2,$c3,$c4) = unpack("C4", $1);
        my $n = (($c1 & 0x07) << 18)|(($c2 & 0x3F) << 12)|
                           (($c3 & 0x3f) << 6)|($c4 & 0x3F);
        pack("N", ($n>=0x010000 && $n<=0x10FFFF) ? $n : unpack("C",'?'));
      } :
      pack("N", unpack("C",'?'))
    /eg;

  $str;
}
# -----------------------------------------------------------------------------
# $bytes_utf8 = $unijp->get();
# 
sub get {
  my $this = shift;
  $this->{str};
}
sub z2h {
  my $this = shift;

  $this->z2hKana;
  $this->z2hNum;
  $this->z2hAlpha;
  $this->z2hSym;

  $this;
}
# -----------------------------------------------------------------------------
# $chars_utf8 = $unijp->getu();
# 
sub getu {
  my $this = shift;
  my $str = $this->{str};
  if( $]>=5.008 && $this->{icode} ne 'binary' )
  {
    Encode::_utf8_on($str);
  }
  $str;
}
sub _loadConvTable {


%_h2zNum = (
		"0" => "\xef\xbc\x90", "1" => "\xef\xbc\x91", 
		"2" => "\xef\xbc\x92", "3" => "\xef\xbc\x93", 
		"4" => "\xef\xbc\x94", "5" => "\xef\xbc\x95", 
		"6" => "\xef\xbc\x96", "7" => "\xef\xbc\x97", 
		"8" => "\xef\xbc\x98", "9" => "\xef\xbc\x99", 
		
);



%_z2hNum = (
		"\xef\xbc\x90" => "0", "\xef\xbc\x91" => "1", 
		"\xef\xbc\x92" => "2", "\xef\xbc\x93" => "3", 
		"\xef\xbc\x94" => "4", "\xef\xbc\x95" => "5", 
		"\xef\xbc\x96" => "6", "\xef\xbc\x97" => "7", 
		"\xef\xbc\x98" => "8", "\xef\xbc\x99" => "9", 
		
);



%_h2zAlpha = (
		"A" => "\xef\xbc\xa1", "B" => "\xef\xbc\xa2", 
		"C" => "\xef\xbc\xa3", "D" => "\xef\xbc\xa4", 
		"E" => "\xef\xbc\xa5", "F" => "\xef\xbc\xa6", 
		"G" => "\xef\xbc\xa7", "H" => "\xef\xbc\xa8", 
		"I" => "\xef\xbc\xa9", "J" => "\xef\xbc\xaa", 
		"K" => "\xef\xbc\xab", "L" => "\xef\xbc\xac", 
		"M" => "\xef\xbc\xad", "N" => "\xef\xbc\xae", 
		"O" => "\xef\xbc\xaf", "P" => "\xef\xbc\xb0", 
		"Q" => "\xef\xbc\xb1", "R" => "\xef\xbc\xb2", 
		"S" => "\xef\xbc\xb3", "T" => "\xef\xbc\xb4", 
		"U" => "\xef\xbc\xb5", "V" => "\xef\xbc\xb6", 
		"W" => "\xef\xbc\xb7", "X" => "\xef\xbc\xb8", 
		"Y" => "\xef\xbc\xb9", "Z" => "\xef\xbc\xba", 
		"a" => "\xef\xbd\x81", "b" => "\xef\xbd\x82", 
		"c" => "\xef\xbd\x83", "d" => "\xef\xbd\x84", 
		"e" => "\xef\xbd\x85", "f" => "\xef\xbd\x86", 
		"g" => "\xef\xbd\x87", "h" => "\xef\xbd\x88", 
		"i" => "\xef\xbd\x89", "j" => "\xef\xbd\x8a", 
		"k" => "\xef\xbd\x8b", "l" => "\xef\xbd\x8c", 
		"m" => "\xef\xbd\x8d", "n" => "\xef\xbd\x8e", 
		"o" => "\xef\xbd\x8f", "p" => "\xef\xbd\x90", 
		"q" => "\xef\xbd\x91", "r" => "\xef\xbd\x92", 
		"s" => "\xef\xbd\x93", "t" => "\xef\xbd\x94", 
		"u" => "\xef\xbd\x95", "v" => "\xef\xbd\x96", 
		"w" => "\xef\xbd\x97", "x" => "\xef\xbd\x98", 
		"y" => "\xef\xbd\x99", "z" => "\xef\xbd\x9a", 
		
);



%_z2hAlpha = (
		"\xef\xbc\xa1" => "A", "\xef\xbc\xa2" => "B", 
		"\xef\xbc\xa3" => "C", "\xef\xbc\xa4" => "D", 
		"\xef\xbc\xa5" => "E", "\xef\xbc\xa6" => "F", 
		"\xef\xbc\xa7" => "G", "\xef\xbc\xa8" => "H", 
		"\xef\xbc\xa9" => "I", "\xef\xbc\xaa" => "J", 
		"\xef\xbc\xab" => "K", "\xef\xbc\xac" => "L", 
		"\xef\xbc\xad" => "M", "\xef\xbc\xae" => "N", 
		"\xef\xbc\xaf" => "O", "\xef\xbc\xb0" => "P", 
		"\xef\xbc\xb1" => "Q", "\xef\xbc\xb2" => "R", 
		"\xef\xbc\xb3" => "S", "\xef\xbc\xb4" => "T", 
		"\xef\xbc\xb5" => "U", "\xef\xbc\xb6" => "V", 
		"\xef\xbc\xb7" => "W", "\xef\xbc\xb8" => "X", 
		"\xef\xbc\xb9" => "Y", "\xef\xbc\xba" => "Z", 
		"\xef\xbd\x81" => "a", "\xef\xbd\x82" => "b", 
		"\xef\xbd\x83" => "c", "\xef\xbd\x84" => "d", 
		"\xef\xbd\x85" => "e", "\xef\xbd\x86" => "f", 
		"\xef\xbd\x87" => "g", "\xef\xbd\x88" => "h", 
		"\xef\xbd\x89" => "i", "\xef\xbd\x8a" => "j", 
		"\xef\xbd\x8b" => "k", "\xef\xbd\x8c" => "l", 
		"\xef\xbd\x8d" => "m", "\xef\xbd\x8e" => "n", 
		"\xef\xbd\x8f" => "o", "\xef\xbd\x90" => "p", 
		"\xef\xbd\x91" => "q", "\xef\xbd\x92" => "r", 
		"\xef\xbd\x93" => "s", "\xef\xbd\x94" => "t", 
		"\xef\xbd\x95" => "u", "\xef\xbd\x96" => "v", 
		"\xef\xbd\x97" => "w", "\xef\xbd\x98" => "x", 
		"\xef\xbd\x99" => "y", "\xef\xbd\x9a" => "z", 
		
);



%_h2zSym = (
		"\x20" => "\xe3\x80\x80", "\x21" => "\xef\xbc\x81", 
		"\x22" => "\xe2\x80\x9d", "\x23" => "\xef\xbc\x83", 
		"\x24" => "\xef\xbc\x84", "\x25" => "\xef\xbc\x85", 
		"\x26" => "\xef\xbc\x86", "\x27" => "\xe2\x80\x99", 
		"\x28" => "\xef\xbc\x88", "\x29" => "\xef\xbc\x89", 
		"\x2a" => "\xef\xbc\x8a", "\x2b" => "\xef\xbc\x8b", 
		"\x2c" => "\xef\xbc\x8c", "\x2d" => "\xef\xbc\x8d", 
		"\x2e" => "\xef\xbc\x8e", "\x2f" => "\xef\xbc\x8f", 
		"\x3a" => "\xef\xbc\x9a", "\x3b" => "\xef\xbc\x9b", 
		"\x3c" => "\xef\xbc\x9c", "\x3d" => "\xef\xbc\x9d", 
		"\x3e" => "\xef\xbc\x9e", "\x3f" => "\xef\xbc\x9f", 
		"\x40" => "\xef\xbc\xa0", "\x5b" => "\xef\xbc\xbb", 
		"\x5c" => "\xef\xbf\xa5", "\x5d" => "\xef\xbc\xbd", 
		"\x5e" => "\xef\xbc\xbe", "_" => "\xef\xbc\xbf", 
		"\x60" => "\xef\xbd\x80", "\x7b" => "\xef\xbd\x9b", 
		"\x7c" => "\xef\xbd\x9c", "\x7d" => "\xef\xbd\x9d", 
		"\x7e" => "\xef\xbd\x9e", 
);



%_z2hSym = (
		"\xe3\x80\x80" => "\x20", "\xef\xbc\x8c" => "\x2c", 
		"\xef\xbc\x8e" => "\x2e", "\xef\xbc\x9a" => "\x3a", 
		"\xef\xbc\x9b" => "\x3b", "\xef\xbc\x9f" => "\x3f", 
		"\xef\xbc\x81" => "\x21", "\xef\xbd\x80" => "\x60", 
		"\xef\xbc\xbe" => "\x5e", "\xef\xbc\xbf" => "_", 
		"\xef\xbc\x8f" => "\x2f", "\xef\xbd\x9e" => "\x7e", 
		"\xef\xbd\x9c" => "\x7c", "\xe2\x80\x99" => "\x27", 
		"\xe2\x80\x9d" => "\x22", "\xef\xbc\x88" => "\x28", 
		"\xef\xbc\x89" => "\x29", "\xef\xbc\xbb" => "\x5b", 
		"\xef\xbc\xbd" => "\x5d", "\xef\xbd\x9b" => "\x7b", 
		"\xef\xbd\x9d" => "\x7d", "\xef\xbc\x8b" => "\x2b", 
		"\xef\xbc\x8d" => "\x2d", "\xef\xbc\x9d" => "\x3d", 
		"\xef\xbc\x9c" => "\x3c", "\xef\xbc\x9e" => "\x3e", 
		"\xef\xbf\xa5" => "\x5c", "\xef\xbc\x84" => "\x24", 
		"\xef\xbc\x85" => "\x25", "\xef\xbc\x83" => "\x23", 
		"\xef\xbc\x86" => "\x26", "\xef\xbc\x8a" => "\x2a", 
		"\xef\xbc\xa0" => "\x40", "\xe3\x80\x9c" => "\x7e", 
		
);



%_h2zKanaK = (
		"\xef\xbd\xa1" => "\xe3\x80\x82", "\xef\xbd\xa2" => "\xe3\x80\x8c", 
		"\xef\xbd\xa3" => "\xe3\x80\x8d", "\xef\xbd\xa4" => "\xe3\x80\x81", 
		"\xef\xbd\xa5" => "\xe3\x83\xbb", "\xef\xbd\xa6" => "\xe3\x83\xb2", 
		"\xef\xbd\xa7" => "\xe3\x82\xa1", "\xef\xbd\xa8" => "\xe3\x82\xa3", 
		"\xef\xbd\xa9" => "\xe3\x82\xa5", "\xef\xbd\xaa" => "\xe3\x82\xa7", 
		"\xef\xbd\xab" => "\xe3\x82\xa9", "\xef\xbd\xac" => "\xe3\x83\xa3", 
		"\xef\xbd\xad" => "\xe3\x83\xa5", "\xef\xbd\xae" => "\xe3\x83\xa7", 
		"\xef\xbd\xaf" => "\xe3\x83\x83", "\xef\xbd\xb0" => "\xe3\x83\xbc", 
		"\xef\xbd\xb1" => "\xe3\x82\xa2", "\xef\xbd\xb2" => "\xe3\x82\xa4", 
		"\xef\xbd\xb3" => "\xe3\x82\xa6", "\xef\xbd\xb4" => "\xe3\x82\xa8", 
		"\xef\xbd\xb5" => "\xe3\x82\xaa", "\xef\xbd\xb6" => "\xe3\x82\xab", 
		"\xef\xbd\xb7" => "\xe3\x82\xad", "\xef\xbd\xb8" => "\xe3\x82\xaf", 
		"\xef\xbd\xb9" => "\xe3\x82\xb1", "\xef\xbd\xba" => "\xe3\x82\xb3", 
		"\xef\xbd\xbb" => "\xe3\x82\xb5", "\xef\xbd\xbc" => "\xe3\x82\xb7", 
		"\xef\xbd\xbd" => "\xe3\x82\xb9", "\xef\xbd\xbe" => "\xe3\x82\xbb", 
		"\xef\xbd\xbf" => "\xe3\x82\xbd", "\xef\xbe\x80" => "\xe3\x82\xbf", 
		"\xef\xbe\x81" => "\xe3\x83\x81", "\xef\xbe\x82" => "\xe3\x83\x84", 
		"\xef\xbe\x83" => "\xe3\x83\x86", "\xef\xbe\x84" => "\xe3\x83\x88", 
		"\xef\xbe\x85" => "\xe3\x83\x8a", "\xef\xbe\x86" => "\xe3\x83\x8b", 
		"\xef\xbe\x87" => "\xe3\x83\x8c", "\xef\xbe\x88" => "\xe3\x83\x8d", 
		"\xef\xbe\x89" => "\xe3\x83\x8e", "\xef\xbe\x8a" => "\xe3\x83\x8f", 
		"\xef\xbe\x8b" => "\xe3\x83\x92", "\xef\xbe\x8c" => "\xe3\x83\x95", 
		"\xef\xbe\x8d" => "\xe3\x83\x98", "\xef\xbe\x8e" => "\xe3\x83\x9b", 
		"\xef\xbe\x8f" => "\xe3\x83\x9e", "\xef\xbe\x90" => "\xe3\x83\x9f", 
		"\xef\xbe\x91" => "\xe3\x83\xa0", "\xef\xbe\x92" => "\xe3\x83\xa1", 
		"\xef\xbe\x93" => "\xe3\x83\xa2", "\xef\xbe\x94" => "\xe3\x83\xa4", 
		"\xef\xbe\x95" => "\xe3\x83\xa6", "\xef\xbe\x96" => "\xe3\x83\xa8", 
		"\xef\xbe\x97" => "\xe3\x83\xa9", "\xef\xbe\x98" => "\xe3\x83\xaa", 
		"\xef\xbe\x99" => "\xe3\x83\xab", "\xef\xbe\x9a" => "\xe3\x83\xac", 
		"\xef\xbe\x9b" => "\xe3\x83\xad", "\xef\xbe\x9c" => "\xe3\x83\xaf", 
		"\xef\xbe\x9d" => "\xe3\x83\xb3", "\xef\xbe\x9e" => "\xe3\x82\x9b", 
		"\xef\xbe\x9f" => "\xe3\x82\x9c", 
);



%_z2hKanaK = (
		"\xe3\x80\x81" => "\xef\xbd\xa4", "\xe3\x80\x82" => "\xef\xbd\xa1", 
		"\xe3\x83\xbb" => "\xef\xbd\xa5", "\xe3\x82\x9b" => "\xef\xbe\x9e", 
		"\xe3\x82\x9c" => "\xef\xbe\x9f", "\xe3\x83\xbc" => "\xef\xbd\xb0", 
		"\xe3\x80\x8c" => "\xef\xbd\xa2", "\xe3\x80\x8d" => "\xef\xbd\xa3", 
		"\xe3\x82\xa1" => "\xef\xbd\xa7", "\xe3\x82\xa2" => "\xef\xbd\xb1", 
		"\xe3\x82\xa3" => "\xef\xbd\xa8", "\xe3\x82\xa4" => "\xef\xbd\xb2", 
		"\xe3\x82\xa5" => "\xef\xbd\xa9", "\xe3\x82\xa6" => "\xef\xbd\xb3", 
		"\xe3\x82\xa7" => "\xef\xbd\xaa", "\xe3\x82\xa8" => "\xef\xbd\xb4", 
		"\xe3\x82\xa9" => "\xef\xbd\xab", "\xe3\x82\xaa" => "\xef\xbd\xb5", 
		"\xe3\x82\xab" => "\xef\xbd\xb6", "\xe3\x82\xad" => "\xef\xbd\xb7", 
		"\xe3\x82\xaf" => "\xef\xbd\xb8", "\xe3\x82\xb1" => "\xef\xbd\xb9", 
		"\xe3\x82\xb3" => "\xef\xbd\xba", "\xe3\x82\xb5" => "\xef\xbd\xbb", 
		"\xe3\x82\xb7" => "\xef\xbd\xbc", "\xe3\x82\xb9" => "\xef\xbd\xbd", 
		"\xe3\x82\xbb" => "\xef\xbd\xbe", "\xe3\x82\xbd" => "\xef\xbd\xbf", 
		"\xe3\x82\xbf" => "\xef\xbe\x80", "\xe3\x83\x81" => "\xef\xbe\x81", 
		"\xe3\x83\x83" => "\xef\xbd\xaf", "\xe3\x83\x84" => "\xef\xbe\x82", 
		"\xe3\x83\x86" => "\xef\xbe\x83", "\xe3\x83\x88" => "\xef\xbe\x84", 
		"\xe3\x83\x8a" => "\xef\xbe\x85", "\xe3\x83\x8b" => "\xef\xbe\x86", 
		"\xe3\x83\x8c" => "\xef\xbe\x87", "\xe3\x83\x8d" => "\xef\xbe\x88", 
		"\xe3\x83\x8e" => "\xef\xbe\x89", "\xe3\x83\x8f" => "\xef\xbe\x8a", 
		"\xe3\x83\x92" => "\xef\xbe\x8b", "\xe3\x83\x95" => "\xef\xbe\x8c", 
		"\xe3\x83\x98" => "\xef\xbe\x8d", "\xe3\x83\x9b" => "\xef\xbe\x8e", 
		"\xe3\x83\x9e" => "\xef\xbe\x8f", "\xe3\x83\x9f" => "\xef\xbe\x90", 
		"\xe3\x83\xa0" => "\xef\xbe\x91", "\xe3\x83\xa1" => "\xef\xbe\x92", 
		"\xe3\x83\xa2" => "\xef\xbe\x93", "\xe3\x83\xa3" => "\xef\xbd\xac", 
		"\xe3\x83\xa4" => "\xef\xbe\x94", "\xe3\x83\xa5" => "\xef\xbd\xad", 
		"\xe3\x83\xa6" => "\xef\xbe\x95", "\xe3\x83\xa7" => "\xef\xbd\xae", 
		"\xe3\x83\xa8" => "\xef\xbe\x96", "\xe3\x83\xa9" => "\xef\xbe\x97", 
		"\xe3\x83\xaa" => "\xef\xbe\x98", "\xe3\x83\xab" => "\xef\xbe\x99", 
		"\xe3\x83\xac" => "\xef\xbe\x9a", "\xe3\x83\xad" => "\xef\xbe\x9b", 
		"\xe3\x83\xaf" => "\xef\xbe\x9c", "\xe3\x83\xb2" => "\xef\xbd\xa6", 
		"\xe3\x83\xb3" => "\xef\xbe\x9d", 
);



%_h2zKanaD = (
		"\xef\xbd\xb3\xef\xbe\x9e" => "\xe3\x83\xb4", "\xef\xbd\xb6\xef\xbe\x9e" => "\xe3\x82\xac", 
		"\xef\xbd\xb7\xef\xbe\x9e" => "\xe3\x82\xae", "\xef\xbd\xb8\xef\xbe\x9e" => "\xe3\x82\xb0", 
		"\xef\xbd\xb9\xef\xbe\x9e" => "\xe3\x82\xb2", "\xef\xbd\xba\xef\xbe\x9e" => "\xe3\x82\xb4", 
		"\xef\xbd\xbb\xef\xbe\x9e" => "\xe3\x82\xb6", "\xef\xbd\xbc\xef\xbe\x9e" => "\xe3\x82\xb8", 
		"\xef\xbd\xbd\xef\xbe\x9e" => "\xe3\x82\xba", "\xef\xbd\xbe\xef\xbe\x9e" => "\xe3\x82\xbc", 
		"\xef\xbd\xbf\xef\xbe\x9e" => "\xe3\x82\xbe", "\xef\xbe\x80\xef\xbe\x9e" => "\xe3\x83\x80", 
		"\xef\xbe\x81\xef\xbe\x9e" => "\xe3\x83\x82", "\xef\xbe\x82\xef\xbe\x9e" => "\xe3\x83\x85", 
		"\xef\xbe\x83\xef\xbe\x9e" => "\xe3\x83\x87", "\xef\xbe\x84\xef\xbe\x9e" => "\xe3\x83\x89", 
		"\xef\xbe\x8a\xef\xbe\x9e" => "\xe3\x83\x90", "\xef\xbe\x8a\xef\xbe\x9f" => "\xe3\x83\x91", 
		"\xef\xbe\x8b\xef\xbe\x9e" => "\xe3\x83\x93", "\xef\xbe\x8b\xef\xbe\x9f" => "\xe3\x83\x94", 
		"\xef\xbe\x8c\xef\xbe\x9e" => "\xe3\x83\x96", "\xef\xbe\x8c\xef\xbe\x9f" => "\xe3\x83\x97", 
		"\xef\xbe\x8d\xef\xbe\x9e" => "\xe3\x83\x99", "\xef\xbe\x8d\xef\xbe\x9f" => "\xe3\x83\x9a", 
		"\xef\xbe\x8e\xef\xbe\x9e" => "\xe3\x83\x9c", "\xef\xbe\x8e\xef\xbe\x9f" => "\xe3\x83\x9d", 
		
);



%_z2hKanaD = (
		"\xe3\x82\xac" => "\xef\xbd\xb6\xef\xbe\x9e", "\xe3\x82\xae" => "\xef\xbd\xb7\xef\xbe\x9e", 
		"\xe3\x82\xb0" => "\xef\xbd\xb8\xef\xbe\x9e", "\xe3\x82\xb2" => "\xef\xbd\xb9\xef\xbe\x9e", 
		"\xe3\x82\xb4" => "\xef\xbd\xba\xef\xbe\x9e", "\xe3\x82\xb6" => "\xef\xbd\xbb\xef\xbe\x9e", 
		"\xe3\x82\xb8" => "\xef\xbd\xbc\xef\xbe\x9e", "\xe3\x82\xba" => "\xef\xbd\xbd\xef\xbe\x9e", 
		"\xe3\x82\xbc" => "\xef\xbd\xbe\xef\xbe\x9e", "\xe3\x82\xbe" => "\xef\xbd\xbf\xef\xbe\x9e", 
		"\xe3\x83\x80" => "\xef\xbe\x80\xef\xbe\x9e", "\xe3\x83\x82" => "\xef\xbe\x81\xef\xbe\x9e", 
		"\xe3\x83\x85" => "\xef\xbe\x82\xef\xbe\x9e", "\xe3\x83\x87" => "\xef\xbe\x83\xef\xbe\x9e", 
		"\xe3\x83\x89" => "\xef\xbe\x84\xef\xbe\x9e", "\xe3\x83\x90" => "\xef\xbe\x8a\xef\xbe\x9e", 
		"\xe3\x83\x91" => "\xef\xbe\x8a\xef\xbe\x9f", "\xe3\x83\x93" => "\xef\xbe\x8b\xef\xbe\x9e", 
		"\xe3\x83\x94" => "\xef\xbe\x8b\xef\xbe\x9f", "\xe3\x83\x96" => "\xef\xbe\x8c\xef\xbe\x9e", 
		"\xe3\x83\x97" => "\xef\xbe\x8c\xef\xbe\x9f", "\xe3\x83\x99" => "\xef\xbe\x8d\xef\xbe\x9e", 
		"\xe3\x83\x9a" => "\xef\xbe\x8d\xef\xbe\x9f", "\xe3\x83\x9c" => "\xef\xbe\x8e\xef\xbe\x9e", 
		"\xe3\x83\x9d" => "\xef\xbe\x8e\xef\xbe\x9f", "\xe3\x83\xb4" => "\xef\xbd\xb3\xef\xbe\x9e", 
		
);



%_hira2kata = (
		"\xe3\x81\x81" => "\xe3\x82\xa1", "\xe3\x81\x82" => "\xe3\x82\xa2", 
		"\xe3\x81\x83" => "\xe3\x82\xa3", "\xe3\x81\x84" => "\xe3\x82\xa4", 
		"\xe3\x81\x85" => "\xe3\x82\xa5", "\xe3\x81\x86" => "\xe3\x82\xa6", 
		"\xe3\x81\x87" => "\xe3\x82\xa7", "\xe3\x81\x88" => "\xe3\x82\xa8", 
		"\xe3\x81\x89" => "\xe3\x82\xa9", "\xe3\x81\x8a" => "\xe3\x82\xaa", 
		"\xe3\x81\x8b" => "\xe3\x82\xab", "\xe3\x81\x8c" => "\xe3\x82\xac", 
		"\xe3\x81\x8d" => "\xe3\x82\xad", "\xe3\x81\x8e" => "\xe3\x82\xae", 
		"\xe3\x81\x8f" => "\xe3\x82\xaf", "\xe3\x81\x90" => "\xe3\x82\xb0", 
		"\xe3\x81\x91" => "\xe3\x82\xb1", "\xe3\x81\x92" => "\xe3\x82\xb2", 
		"\xe3\x81\x93" => "\xe3\x82\xb3", "\xe3\x81\x94" => "\xe3\x82\xb4", 
		"\xe3\x81\x95" => "\xe3\x82\xb5", "\xe3\x81\x96" => "\xe3\x82\xb6", 
		"\xe3\x81\x97" => "\xe3\x82\xb7", "\xe3\x81\x98" => "\xe3\x82\xb8", 
		"\xe3\x81\x99" => "\xe3\x82\xb9", "\xe3\x81\x9a" => "\xe3\x82\xba", 
		"\xe3\x81\x9b" => "\xe3\x82\xbb", "\xe3\x81\x9c" => "\xe3\x82\xbc", 
		"\xe3\x81\x9d" => "\xe3\x82\xbd", "\xe3\x81\x9e" => "\xe3\x82\xbe", 
		"\xe3\x81\x9f" => "\xe3\x82\xbf", "\xe3\x81\xa0" => "\xe3\x83\x80", 
		"\xe3\x81\xa1" => "\xe3\x83\x81", "\xe3\x81\xa2" => "\xe3\x83\x82", 
		"\xe3\x81\xa3" => "\xe3\x83\x83", "\xe3\x81\xa4" => "\xe3\x83\x84", 
		"\xe3\x81\xa5" => "\xe3\x83\x85", "\xe3\x81\xa6" => "\xe3\x83\x86", 
		"\xe3\x81\xa7" => "\xe3\x83\x87", "\xe3\x81\xa8" => "\xe3\x83\x88", 
		"\xe3\x81\xa9" => "\xe3\x83\x89", "\xe3\x81\xaa" => "\xe3\x83\x8a", 
		"\xe3\x81\xab" => "\xe3\x83\x8b", "\xe3\x81\xac" => "\xe3\x83\x8c", 
		"\xe3\x81\xad" => "\xe3\x83\x8d", "\xe3\x81\xae" => "\xe3\x83\x8e", 
		"\xe3\x81\xaf" => "\xe3\x83\x8f", "\xe3\x81\xb0" => "\xe3\x83\x90", 
		"\xe3\x81\xb1" => "\xe3\x83\x91", "\xe3\x81\xb2" => "\xe3\x83\x92", 
		"\xe3\x81\xb3" => "\xe3\x83\x93", "\xe3\x81\xb4" => "\xe3\x83\x94", 
		"\xe3\x81\xb5" => "\xe3\x83\x95", "\xe3\x81\xb6" => "\xe3\x83\x96", 
		"\xe3\x81\xb7" => "\xe3\x83\x97", "\xe3\x81\xb8" => "\xe3\x83\x98", 
		"\xe3\x81\xb9" => "\xe3\x83\x99", "\xe3\x81\xba" => "\xe3\x83\x9a", 
		"\xe3\x81\xbb" => "\xe3\x83\x9b", "\xe3\x81\xbc" => "\xe3\x83\x9c", 
		"\xe3\x81\xbd" => "\xe3\x83\x9d", "\xe3\x81\xbe" => "\xe3\x83\x9e", 
		"\xe3\x81\xbf" => "\xe3\x83\x9f", "\xe3\x82\x80" => "\xe3\x83\xa0", 
		"\xe3\x82\x81" => "\xe3\x83\xa1", "\xe3\x82\x82" => "\xe3\x83\xa2", 
		"\xe3\x82\x83" => "\xe3\x83\xa3", "\xe3\x82\x84" => "\xe3\x83\xa4", 
		"\xe3\x82\x85" => "\xe3\x83\xa5", "\xe3\x82\x86" => "\xe3\x83\xa6", 
		"\xe3\x82\x87" => "\xe3\x83\xa7", "\xe3\x82\x88" => "\xe3\x83\xa8", 
		"\xe3\x82\x89" => "\xe3\x83\xa9", "\xe3\x82\x8a" => "\xe3\x83\xaa", 
		"\xe3\x82\x8b" => "\xe3\x83\xab", "\xe3\x82\x8c" => "\xe3\x83\xac", 
		"\xe3\x82\x8d" => "\xe3\x83\xad", "\xe3\x82\x8e" => "\xe3\x83\xae", 
		"\xe3\x82\x8f" => "\xe3\x83\xaf", "\xe3\x82\x90" => "\xe3\x83\xb0", 
		"\xe3\x82\x91" => "\xe3\x83\xb1", "\xe3\x82\x92" => "\xe3\x83\xb2", 
		"\xe3\x82\x93" => "\xe3\x83\xb3", 
);



%_kata2hira = (
		"\xe3\x82\xa1" => "\xe3\x81\x81", "\xe3\x82\xa2" => "\xe3\x81\x82", 
		"\xe3\x82\xa3" => "\xe3\x81\x83", "\xe3\x82\xa4" => "\xe3\x81\x84", 
		"\xe3\x82\xa5" => "\xe3\x81\x85", "\xe3\x82\xa6" => "\xe3\x81\x86", 
		"\xe3\x82\xa7" => "\xe3\x81\x87", "\xe3\x82\xa8" => "\xe3\x81\x88", 
		"\xe3\x82\xa9" => "\xe3\x81\x89", "\xe3\x82\xaa" => "\xe3\x81\x8a", 
		"\xe3\x82\xab" => "\xe3\x81\x8b", "\xe3\x82\xac" => "\xe3\x81\x8c", 
		"\xe3\x82\xad" => "\xe3\x81\x8d", "\xe3\x82\xae" => "\xe3\x81\x8e", 
		"\xe3\x82\xaf" => "\xe3\x81\x8f", "\xe3\x82\xb0" => "\xe3\x81\x90", 
		"\xe3\x82\xb1" => "\xe3\x81\x91", "\xe3\x82\xb2" => "\xe3\x81\x92", 
		"\xe3\x82\xb3" => "\xe3\x81\x93", "\xe3\x82\xb4" => "\xe3\x81\x94", 
		"\xe3\x82\xb5" => "\xe3\x81\x95", "\xe3\x82\xb6" => "\xe3\x81\x96", 
		"\xe3\x82\xb7" => "\xe3\x81\x97", "\xe3\x82\xb8" => "\xe3\x81\x98", 
		"\xe3\x82\xb9" => "\xe3\x81\x99", "\xe3\x82\xba" => "\xe3\x81\x9a", 
		"\xe3\x82\xbb" => "\xe3\x81\x9b", "\xe3\x82\xbc" => "\xe3\x81\x9c", 
		"\xe3\x82\xbd" => "\xe3\x81\x9d", "\xe3\x82\xbe" => "\xe3\x81\x9e", 
		"\xe3\x82\xbf" => "\xe3\x81\x9f", "\xe3\x83\x80" => "\xe3\x81\xa0", 
		"\xe3\x83\x81" => "\xe3\x81\xa1", "\xe3\x83\x82" => "\xe3\x81\xa2", 
		"\xe3\x83\x83" => "\xe3\x81\xa3", "\xe3\x83\x84" => "\xe3\x81\xa4", 
		"\xe3\x83\x85" => "\xe3\x81\xa5", "\xe3\x83\x86" => "\xe3\x81\xa6", 
		"\xe3\x83\x87" => "\xe3\x81\xa7", "\xe3\x83\x88" => "\xe3\x81\xa8", 
		"\xe3\x83\x89" => "\xe3\x81\xa9", "\xe3\x83\x8a" => "\xe3\x81\xaa", 
		"\xe3\x83\x8b" => "\xe3\x81\xab", "\xe3\x83\x8c" => "\xe3\x81\xac", 
		"\xe3\x83\x8d" => "\xe3\x81\xad", "\xe3\x83\x8e" => "\xe3\x81\xae", 
		"\xe3\x83\x8f" => "\xe3\x81\xaf", "\xe3\x83\x90" => "\xe3\x81\xb0", 
		"\xe3\x83\x91" => "\xe3\x81\xb1", "\xe3\x83\x92" => "\xe3\x81\xb2", 
		"\xe3\x83\x93" => "\xe3\x81\xb3", "\xe3\x83\x94" => "\xe3\x81\xb4", 
		"\xe3\x83\x95" => "\xe3\x81\xb5", "\xe3\x83\x96" => "\xe3\x81\xb6", 
		"\xe3\x83\x97" => "\xe3\x81\xb7", "\xe3\x83\x98" => "\xe3\x81\xb8", 
		"\xe3\x83\x99" => "\xe3\x81\xb9", "\xe3\x83\x9a" => "\xe3\x81\xba", 
		"\xe3\x83\x9b" => "\xe3\x81\xbb", "\xe3\x83\x9c" => "\xe3\x81\xbc", 
		"\xe3\x83\x9d" => "\xe3\x81\xbd", "\xe3\x83\x9e" => "\xe3\x81\xbe", 
		"\xe3\x83\x9f" => "\xe3\x81\xbf", "\xe3\x83\xa0" => "\xe3\x82\x80", 
		"\xe3\x83\xa1" => "\xe3\x82\x81", "\xe3\x83\xa2" => "\xe3\x82\x82", 
		"\xe3\x83\xa3" => "\xe3\x82\x83", "\xe3\x83\xa4" => "\xe3\x82\x84", 
		"\xe3\x83\xa5" => "\xe3\x82\x85", "\xe3\x83\xa6" => "\xe3\x82\x86", 
		"\xe3\x83\xa7" => "\xe3\x82\x87", "\xe3\x83\xa8" => "\xe3\x82\x88", 
		"\xe3\x83\xa9" => "\xe3\x82\x89", "\xe3\x83\xaa" => "\xe3\x82\x8a", 
		"\xe3\x83\xab" => "\xe3\x82\x8b", "\xe3\x83\xac" => "\xe3\x82\x8c", 
		"\xe3\x83\xad" => "\xe3\x82\x8d", "\xe3\x83\xae" => "\xe3\x82\x8e", 
		"\xe3\x83\xaf" => "\xe3\x82\x8f", "\xe3\x83\xb0" => "\xe3\x82\x90", 
		"\xe3\x83\xb1" => "\xe3\x82\x91", "\xe3\x83\xb2" => "\xe3\x82\x92", 
		"\xe3\x83\xb3" => "\xe3\x82\x93", 
);


}
# -----------------------------------------------------------------------------
# unijp();
#
sub unijp
{
  Unicode::Japanese->new(@_);
}
# utf8 => utf8-jsky2
sub _u2uj1
{
  my $this = shift;
  
  if(!defined($eu2j1))
  {
    $eu2j2 = $this->_getFile('jcode/emoji2/eu2j2.dat');
  }
  
  my $str = $this->_validate_utf8($this->{str});
  
  $str =~ s{([\xf0-\xf7][\x80-\xbf]{3})}{
    my ($c1,$c2,$c3,$c4) = unpack("C4", $1);
    my $ch = (($c1 & 0x07)<<18) | (($c2 & 0x3F)<<12) |
             (($c3 & 0x3f)<< 6) | ($c4 & 0x3F);
    if( 0x0fe000 <= $ch && $ch <= 0x0fffff )
    {
      my $c = substr($eu2j1, ($ch - 0x0fe000) * 5, 5);
      $c =~ tr,\0,,d;
      $c eq '' and $c = '?';
      if( $c =~ /^\e\$([GEFOPQ])(.)\x0f/ )
      {
        my ($j1,$j2) = ($1,$2);
        $j1 =~ tr/GEF/\xe0-\xe5/;
        $j2 =~ tr/!-z/\x01-\x5a/;
        $c = $this->_ucs2_utf8($j1.$j2);
      }
      $c;
    }else
    {
      '?';
    }
  }ge;
  $str;
}
# utf8 -> jis-au1
sub _u2ja1 {
  my $this = shift;
  my $str = shift;

  if(!defined($str))
    {
      return '';
    }
  
  if(!defined($u2s_table))
    {
      $u2s_table = $this->_getFile('jcode/u2s.dat');
    }

  if(!defined($eu2a1s))
    {
      $eu2a1s = $this->_getFile('jcode/emoji2/eu2as.dat');
    }

  my $c1;
  my $c2;
  my $c3;
  my $c4;
  my $c5;
  my $c6;
  my $c;
  my $ch;
  $str =~ s/([\xc0-\xdf][\x80-\xbf]|[\xe0-\xef][\x80-\xbf]{2}|[\xf0-\xf7][\x80-\xbf]{3}|[\xf8-\xfb][\x80-\xbf]{4}|[\xfc-\xfd][\x80-\xbf]{5})|([^\x00-\x7f])/
    defined($2) ? '?' :
    ((length($1) == 1) ? $1 :
     (length($1) == 2) ? (
			  ($c1,$c2) = unpack("C2", $1),
			  $ch = (($c1 & 0x1F)<<6)|($c2 & 0x3F),
			  $c = substr($u2s_table, $ch * 2, 2),
			  ($c eq "\0\0") ? '?' : $c
			 ) :
     (length($1) == 3) ? (
			  ($c1,$c2,$c3) = unpack("C3", $1),
			  $ch = (($c1 & 0x0F)<<12)|(($c2 & 0x3F)<<6)|($c3 & 0x3F),
			  (
			   ($ch <= 0x9fff) ?
			   $c = substr($u2s_table, $ch * 2, 2) :
			   ($ch >= 0xf900 and $ch <= 0xffff) ?
			   (
			    $c = substr($u2s_table, ($ch - 0xf900 + 0xa000) * 2, 2),
			    (($c =~ tr,\0,,d)==2 and $c = "\0\0"),
			   ) :
			   (
			    $c = '?'
			   )
			  ),
			  ($c eq "\0\0") ? '?' : $c
			 ) :
     (length($1) == 4) ? (
			  ($c1,$c2,$c3,$c4) = unpack("C4", $1),
			  $ch = (($c1 & 0x07)<<18)|(($c2 & 0x3F)<<12)|
			  (($c3 & 0x3f) << 6)|($c4 & 0x3F),
			  (
			   ($ch >= 0x0fe000 and $ch <= 0x0fffff) ?
			   (
			    $c = substr($eu2a1s, ($ch - 0x0fe000) * 2, 2),
			    $c =~ tr,\0,,d,
			    ($c eq '') ? '?' : $c
			   ) :
			   '?'
			  )
			 ) :
     '?'
    )
      /eg;

  $str;
}
sub _j2s {
  my $this = shift;
  my $str = shift;

  $str =~ s/($RE{JIS_0208}|$RE{JIS_0212}|$RE{JIS_ASC}|$RE{JIS_KANA})([^\e]*)/
    $this->_j2s2($1, $2)
      /geo;

  $str;
}
# -----------------------------------------------------------------------------
# $bytes_utf16 = $unijp->utf16();
# 
sub utf16
{
  my $this = shift;
  $this->_utf8_utf16($this->{str});
}
sub utf8_jsky2
{
  my $this = shift;
  $this->_u2uj2($this->{str});
}
# -----------------------------------------------------------------------------
# AU��ʸ�������Ѵ�
# 
# utf8���AU��ʸ����<IMG ICON="">���Ѵ�
sub _u2ai1 {
  my $this = shift;
  my $str = shift;
  
  if(!defined($str))
    {
      return '';
    }
  
  if(!defined($eu2a1))
    {
      $eu2a1 = $this->_getFile('jcode/emoji2/eu2a.dat');
    }

  my $c1;
  my $c2;
  my $c3;
  my $c4;
  my $c5;
  my $c6;
  my $c;
  my $d;
  my $ch;
  $str =~ s/([\xc0-\xdf][\x80-\xbf]|[\xe0-\xef][\x80-\xbf]{2}|[\xf0-\xf7][\x80-\xbf]{3}|[\xf8-\xfb][\x80-\xbf]{4}|[\xfc-\xfd][\x80-\xbf]{5})|([^\x00-\x7f])/
    defined($2) ? '?' :
    ((length($1) == 1) ? $1 :
     (length($1) == 2) ? $1 :
     (length($1) == 3) ? $1 :
     (length($1) == 4) ? (
			  ($c1,$c2,$c3,$c4) = unpack("C4", $1),
			  $ch = (($c1 & 0x07)<<18)|(($c2 & 0x3F)<<12)|
			  (($c3 & 0x3f) << 6)|($c4 & 0x3F),
			  (
			   ($ch >= 0x0fe000 and $ch <= 0x0fffff) ?
			   (
			    $c = substr($eu2a1, ($ch - 0x0fe000) * 2, 2),
			    $d = unpack('n', $c),
			    $c =~ tr,\0,,d,
			    ($d <= 0x0336) ? $RE{E_ICON_AU_START} . $d . $RE{E_ICON_AU_END} :
			    ($c eq '') ? '?' : $c
			   ) :
			   '?'
			  )
			 ) :
     '?'
    )
      /eg;
  
  $str;
}
sub sjis_icon_au2
{
  my $this = shift;
  $this->_u2s($this->_u2ai2($this->{str}));
}
sub _u2si2 {
  my $this = shift;
  my $str = shift;

  if(!defined($str))
    {
      return '';
    }
  
  if(!defined($u2s_table))
    {
      $u2s_table = $this->_getFile('jcode/u2s.dat');
    }

  if(!defined($eu2i2))
    {
      $eu2i2 = $this->_getFile('jcode/emoji2/eu2i2.dat');
    }

  my $c1;
  my $c2;
  my $c3;
  my $c4;
  my $c5;
  my $c6;
  my $c;
  my $ch;
  $str =~ s/([\xc0-\xdf][\x80-\xbf]|[\xe0-\xef][\x80-\xbf]{2}|[\xf0-\xf7][\x80-\xbf]{3}|[\xf8-\xfb][\x80-\xbf]{4}|[\xfc-\xfd][\x80-\xbf]{5})|([^\x00-\x7f])/
    defined($2) ? '?' :
    ((length($1) == 1) ? $1 :
     (length($1) == 2) ? (
			  ($c1,$c2) = unpack("C2", $1),
			  $ch = (($c1 & 0x1F)<<6)|($c2 & 0x3F),
			  $c = substr($u2s_table, $ch * 2, 2),
			  ($c eq "\0\0") ? '?' : $c
			 ) :
     (length($1) == 3) ? (
			  ($c1,$c2,$c3) = unpack("C3", $1),
			  $ch = (($c1 & 0x0F)<<12)|(($c2 & 0x3F)<<6)|($c3 & 0x3F),
			  (
			   ($ch <= 0x9fff) ?
			   $c = substr($u2s_table, $ch * 2, 2) :
			   ($ch >= 0xf900 and $ch <= 0xffff) ?
			   (
			    $c = substr($u2s_table, ($ch - 0xf900 + 0xa000) * 2, 2),
			    (($c =~ tr,\0,,d)==2 and $c = "\0\0"),
			   ) :
			   (
			    $c = '?'
			   )
			  ),
			  ($c eq "\0\0") ? '?' : $c
			 ) :
     (length($1) == 4) ? (
			  ($c1,$c2,$c3,$c4) = unpack("C4", $1),
			  $ch = (($c1 & 0x07)<<18)|(($c2 & 0x3F)<<12)|
			  (($c3 & 0x3f) << 6)|($c4 & 0x3F),
			  (
			   ($ch >= 0x0fe000 and $ch <= 0x0fffff) ?
			   (
			    $c = substr($eu2i2, ($ch - 0x0fe000) * 2, 2),
			    $c =~ tr,\0,,d,
			    ($c eq '') ? '?' : $c
			   ) :
			   '?'
			  )
			 ) :
     '?'
    )
      /eg;
  $str;
  
}
sub splitCsv {
  my $this = shift;
  my $text = $this->{str};
  my @field;
  
  chomp($text);

  while ($text =~ m/"([^"\\]*(?:(?:\\.|\"\")[^"\\]*)*)",?|([^,]+),?|,/g) {
    my $field = defined($1) ? $1 : (defined($2) ? $2 : '');
    $field =~ s/["\\]"/"/g;
    push(@field, $field);
  }
  push(@field, '')        if($text =~ m/,$/);
  
  \@field;
}
sub sjis_jsky1
{
  my $this = shift;
  $this->_u2sj1($this->{str});
}
sub _s2j3 {
  my $this = shift;
  my $c = shift;

  my ($c1, $c2) = unpack('CC', $c);
  if (0x9f <= $c2)
    {
      $c1 = $c1 * 2 - ($c1 >= 0xe0 ? 0xe0 : 0x60);
      $c2 += 2;
    }
  else
    {
      $c1 = $c1 * 2 - ($c1 >= 0xe0 ? 0xe1 : 0x61);
      $c2 += 0x60 + ($c2 < 0x7f);
    }
  
  $S2J[unpack('n', $c)] = pack('CC', $c1 - 0x80, $c2 - 0x80);
}
# sjis-au1 => utf8
sub _sa2u1 {
  my $this = shift;
  my $str = shift;

  if(!defined($str))
    {
      return '';
    }
  
  if(!defined($s2u_table))
    {
      $s2u_table = $this->_getFile('jcode/s2u.dat');
    }

  if(!defined($ea2u1s))
  {
    $ea2u1s = $this->_getFile('jcode/emoji2/ea2us.dat');
  }

  my $l;
  my $uc;
  $str =~ s/($RE{SJIS_KANA}|$RE{SJIS_DBCS}|[\x80-\xff])/
    $SA2U1{$1}
      or ($SA2U1{$1} =
	  (
	   $l = (unpack('n', $1) or unpack('C', $1)),
	   (
	    ($l >= 0xa1 and $l <= 0xdf)     ?
	    (
	     $uc = substr($s2u_table, ($l - 0xa1) * 3, 3),
	     $uc =~ tr,\0,,d,
	     $uc
	    ) :
	    ($l >= 0x8100 and $l <= 0x9fff) ?
	    (
	     $uc = substr($s2u_table, ($l - 0x8100 + 0x3f) * 3, 3),
	     $uc =~ tr,\0,,d,
	     $uc
	    ) :
	    ($l >= 0xeb00 and $l <= 0xeeff) ?
	    (
	     $uc = substr($ea2u1s, ($l - 0xeb00) * 4, 4),
	     $uc =~ tr,\0,,d,
	     $uc
	    ) :
	    ($l >= 0xe000 and $l <= 0xfcff) ?
	    (
	     $uc = substr($s2u_table, ($l - 0xe000 + 0x1f3f) * 3, 3),
	     $uc =~ tr,\0,,d,
	     $uc
	    ) :
	    ($l < 0x80) ?
	    chr($l) :
	    '?'
	   )
	  )
	 )/eg;
  
  $str;
  
}
# -----------------------------------------------------------------------------
# utf8 ==> sjis/��ʸ��
#
sub _u2s {
  my $this = shift;
  my $str = shift;
  
  if(!defined($str))
    {
      return '';
    }

  if(!defined($u2s_table))
    {
      $u2s_table = $this->_getFile('jcode/u2s.dat');
    }

  my $c1;
  my $c2;
  my $c3;
  my $c4;
  my $c5;
  my $c6;
  my $c;
  my $ch;
  $str =~ s/([\xc0-\xdf][\x80-\xbf]|[\xe0-\xef][\x80-\xbf]{2}|[\xf0-\xf7][\x80-\xbf]{3}|[\xf8-\xfb][\x80-\xbf]{4}|[\xfc-\xfd][\x80-\xbf]{5})|([^\x00-\x7f])/
    defined($2) ? '?' : (
    $U2S{$1}
      or ($U2S{$1}
	  = ((length($1) == 1) ? $1 :
	     (length($1) == 2) ? (
				  ($c1,$c2) = unpack("C2", $1),
				  $ch = (($c1 & 0x1F)<<6)|($c2 & 0x3F),
				  $c = substr($u2s_table, $ch * 2, 2),
				  # UTF-3�Х���(U+0x80-U+07FF)����sjis-1�Х��ȤؤΥޥåԥ󥰤Ϥʤ��Τ�\0������ɬ�פϤʤ�
				  $ch<0x80 ? '?' : ($c eq "\0\0") ? '&#' . $ch . ';' : $c
				 ) :
	     (length($1) == 3) ? (
				  ($c1,$c2,$c3) = unpack("C3", $1),
				  $ch = (($c1 & 0x0F)<<12)|(($c2 & 0x3F)<<6)|($c3 & 0x3F),
				  (
				   ($ch <= 0x9fff) ?
				   $c = substr($u2s_table, $ch * 2, 2) :
				   ($ch >= 0xf900 and $ch <= 0xffff) ?
				   (
				    $c = substr($u2s_table, ($ch - 0xf900 + 0xa000) * 2, 2),
				    (($c =~ tr,\0,,d)==2 and $c = "\0\0"),
				   ) :
				   (
				    $c = '&#' . $ch . ';'
				   )
				  ),
				  $ch<0x0800 ? '?' : ($c eq "\0\0") ? '&#' . $ch . ';' : $c
				 ) :
	     (length($1) == 4) ? (
				  ($c1,$c2,$c3,$c4) = unpack("C4", $1),
				  $ch = (($c1 & 0x07)<<18)|(($c2 & 0x3F)<<12)|
				  (($c3 & 0x3f) << 6)|($c4 & 0x3F),
				  (
				   $ch <0x01_0000 ? '?' :
				   ($ch >= 0x0fe000 and $ch <= 0x0fffff) ?
				   '?'
				   : '&#' . $ch . ';'
				  )
				 ) :
	     (length($1) == 5) ? (($c1,$c2,$c3,$c4,$c5) = unpack("C5", $1),
				  $ch = (($c1 & 0x03) << 24)|(($c2 & 0x3F) << 18)|
				  (($c3 & 0x3f) << 12)|(($c4 & 0x3f) << 6)|
				  ($c5 & 0x3F),
				  $ch<0x20_0000 ? '?' : '&#' . $ch . ';'
				 ) :
	                         (
				  ($c1,$c2,$c3,$c4,$c5,$c6) = unpack("C6", $1),
				  $ch = (($c1 & 0x03) << 30)|(($c2 & 0x3F) << 24)|
				  (($c3 & 0x3f) << 18)|(($c4 & 0x3f) << 12)|
				  (($c5 & 0x3f) << 6)|($c6 & 0x3F),
				  $ch<0x0400_0000 ? '?' : '&#' . $ch . ';'
				 )
	    )
	 )
			 )
	/eg;
  $str;
  
}
sub _sa2j3 {
  my $this = shift;
  my $c = shift;

  my ($c1, $c2) = unpack('CC', $c);
  $c1 = 0xeb if($c1 == 0xf6);
  $c1 = 0xec if($c1 == 0xf7);
  $c1 = 0xed if($c1 == 0xf3);
  $c1 = 0xee if($c1 == 0xf4);
  
  if (0x9f <= $c2)
    {
      $c1 = $c1 * 2 - ($c1 >= 0xe0 ? 0xe0 : 0x60);
      $c2 += 2;
    }
  else
    {
      $c1 = $c1 * 2 - ($c1 >= 0xe0 ? 0xe1 : 0x61);
      $c2 += 0x60 + ($c2 < 0x7f);
    }
  
  pack('CC', $c1 - 0x80, $c2 - 0x80);
}
sub _utf16_utf8 {
  my $this = shift;
  my $str = shift;
  
  if(!defined($str))
    {
      return '';
    }
  
  my $result = '';
  my $sa;
  foreach my $uc (unpack("n*", $str))
    {
      ($uc >= 0xd800 and $uc <= 0xdbff and $sa = $uc and next);
      
      ($uc >= 0xdc00 and $uc <= 0xdfff and ($uc = ((($sa - 0xd800) << 10)|($uc - 0xdc00))+0x10000));
      
      $result .= $U2T[$uc] ? $U2T[$uc] :
	($U2T[$uc] = ($uc < 0x80) ? chr($uc) :
	 ($uc < 0x800) ? chr(0xC0 | ($uc >> 6)) . chr(0x80 | ($uc & 0x3F)) :
	 ($uc < 0x10000) ? chr(0xE0 | ($uc >> 12)) . chr(0x80 | (($uc >> 6) & 0x3F)) . chr(0x80 | ($uc & 0x3F)) :
	 chr(0xF0 | ($uc >> 18)) . chr(0x80 | (($uc >> 12) & 0x3F)) . chr(0x80 | (($uc >> 6) & 0x3F)) . chr(0x80 | ($uc & 0x3F)));
    }
  
  $result;
}
sub h2zNum {
  my $this = shift;

  if(!defined(%_h2zNum))
    {
      $this->_loadConvTable;
    }

  $this->{str} =~ s/(0|1|2|3|4|5|6|7|8|9)/$_h2zNum{$1}/eg;
  
  $this;
}
sub h2zKanaK {
  my $this = shift;

  if(!defined(%_h2zKanaK))
    {
      $this->_loadConvTable;
    }

  $this->{str} =~ s/(\xef\xbd\xa1|\xef\xbd\xa2|\xef\xbd\xa3|\xef\xbd\xa4|\xef\xbd\xa5|\xef\xbd\xa6|\xef\xbd\xa7|\xef\xbd\xa8|\xef\xbd\xa9|\xef\xbd\xaa|\xef\xbd\xab|\xef\xbd\xac|\xef\xbd\xad|\xef\xbd\xae|\xef\xbd\xaf|\xef\xbd\xb0|\xef\xbd\xb1|\xef\xbd\xb2|\xef\xbd\xb3|\xef\xbd\xb4|\xef\xbd\xb5|\xef\xbd\xb6|\xef\xbd\xb7|\xef\xbd\xb8|\xef\xbd\xb9|\xef\xbd\xba|\xef\xbd\xbb|\xef\xbd\xbc|\xef\xbd\xbd|\xef\xbd\xbe|\xef\xbd\xbf|\xef\xbe\x80|\xef\xbe\x81|\xef\xbe\x82|\xef\xbe\x83|\xef\xbe\x84|\xef\xbe\x85|\xef\xbe\x86|\xef\xbe\x87|\xef\xbe\x88|\xef\xbe\x89|\xef\xbe\x8a|\xef\xbe\x8b|\xef\xbe\x8c|\xef\xbe\x8d|\xef\xbe\x8e|\xef\xbe\x8f|\xef\xbe\x90|\xef\xbe\x91|\xef\xbe\x92|\xef\xbe\x93|\xef\xbe\x94|\xef\xbe\x95|\xef\xbe\x96|\xef\xbe\x97|\xef\xbe\x98|\xef\xbe\x99|\xef\xbe\x9a|\xef\xbe\x9b|\xef\xbe\x9c|\xef\xbe\x9d|\xef\xbe\x9e|\xef\xbe\x9f)/$_h2zKanaK{$1}/eg;
  
  $this;
}
sub strlen {
  my $this = shift;
  
  my $ch_re = '[\x00-\x7f]|[\xc0-\xdf][\x80-\xbf]|[\xe0-\xef][\x80-\xbf]{2}|[\xf0-\xf7][\x80-\xbf]{3}|[\xf8-\xfb][\x80-\xbf]{4}|[\xfc-\xfd][\x80-\xbf]{5}';
  my $length = 0;

  foreach my $c(split(/($ch_re)/,$this->{str})) {
    next if(length($c) == 0);
    $length += ((length($c) >= 3) ? 2 : 1);
  }

  return $length;
}
sub strcutu
{
  my $this = shift;
  my $result = &strcut;
  
  if( $]>=5.008 && $this->{icode} ne 'binary' )
  {
    foreach(@$result)
    {
      Encode::_utf8_on($_);
    }
  }
  
  $result;
}
sub sjis_imode2
{
  my $this = shift;
  $this->_u2si2($this->{str});
}
sub _validate_utf8
{
  my $pkg = shift;
  my $str = shift;
  
  # Ŭ�ڤǤʤ�Ĺ���˥��󥳡��ɤ���Ƥ���
  # ʸ���� ? ���֤�����.
  defined($str) and $str =~ s{
     # 2 bytes char which is restricted 1 byte.
     #
     [\xc0-\xc1] [\x80-\xbf]   
    |
     # 3 bytes char which is restricted <= 2 bytes.
     #
     \xe0        [\x80-\x9f] [\x80-\xbf]
    |
     # 4 bytes char which is restricted <= 3 bytes.
     #
     \xf0        [\x80-\x8f] [\x80-\xbf] [\x80-\xbf]
    |
     # > U+10FFFF (4byte)
     #
     \xf4        [\x90-\xbf] [\x80-\xbf] [\x80-\xbf]
    |[\xf5-\xf7] [\x80-\xbf] [\x80-\xbf] [\x80-\xbf]
    |
     # > U+10FFFF (5byte)
     #
     [\xf8-\xfb] [\x80-\xbf] [\x80-\xbf] [\x80-\xbf] [\x80-\xbf]
    |
     # > U+10FFFF (6byte)
     #
     [\xfc-\xfd] [\x80-\xbf] [\x80-\xbf] [\x80-\xbf] [\x80-\xbf] [\x80-\xbf]
  }{?}xg;
  $str;
}
# -----------------------------------------------------------------------------
# $unijp->set($str,[$icode,[$encode]]);
# 
sub set
{
  my $this = shift;
  my $str = shift;
  my $icode = shift;
  my $encode = shift;

  if(ref($str))
    {
      die "String->set, Param[1] is Ref.\n";
    }
  if(ref($icode))
    {
      die "String->set, Param[2] is Ref.\n";
    }
  if(ref($encode))
    {
      die "String->set, Param[3] is Ref.\n";
    }

  if( $]>=5.008 )
  {
    Encode::_utf8_off($str);
  }
  
  if(defined($encode))
    {
      if($encode eq 'base64')
	{
	  $str = $this->_decodeBase64($str);
	}
      else
	{
	  die "String->set, Param[3] encode name error.\n";
	}
    }

  if(!defined($icode))
    { # omitted then 'utf8'
      $this->{str} = $this->_validate_utf8($str);
      $this->{icode} = 'utf8';
    }
  else
    {
      $icode = lc($icode);
      if($icode eq 'auto')
	{
	  $icode = $this->getcode($str);
	  if($icode eq 'unknown')
	    {
	      $icode = 'binary';
	    }
	}

      if($icode eq 'utf8')
	{
	  $this->{str} = $this->_validate_utf8($str);
	}
      elsif($icode eq 'ucs2')
	{
	  $this->{str} = $this->_ucs2_utf8($str);
	}
      elsif($icode eq 'ucs4')
	{
	  $this->{str} = $this->_ucs4_utf8($str);
	}
      elsif($icode eq 'utf16-be')
	{
	  $this->{str} = $this->_utf16_utf8($this->_utf16be_utf16($str));
	}
      elsif($icode eq 'utf16-le')
	{
	  $this->{str} = $this->_utf16_utf8($this->_utf16le_utf16($str));
	}
      elsif($icode eq 'utf16')
	{
	  $this->{str} = $this->_utf16_utf8($this->_utf16_utf16($str));
	}
      elsif($icode eq 'utf32-be')
	{
	  $this->{str} = $this->_ucs4_utf8($this->_utf32be_ucs4($str));
	}
      elsif($icode eq 'utf32-le')
	{
	  $this->{str} = $this->_ucs4_utf8($this->_utf32le_ucs4($str));
	}
      elsif($icode eq 'utf32')
	{
	  $this->{str} = $this->_ucs4_utf8($this->_utf32_ucs4($str));
	}
      elsif($icode eq 'jis')
	{
	  $this->{str} = $this->_s2u($this->_j2s($str));
	}
      elsif($icode eq 'euc' || $icode eq 'euc-jp')
	{
	  $this->{str} = $this->_s2u($this->_e2s($str));
	}
      elsif($icode eq 'sjis' || $icode eq 'cp932')
	{
	  $this->{str} = $this->_s2u($str);
	}
      elsif($icode eq 'sjis-imode')
	{
	  $this->{str} = $this->_si2u2($str);
	}
      elsif($icode eq 'sjis-imode1')
	{
	  $this->{str} = $this->_si2u1($str);
	}
      elsif($icode eq 'sjis-imode2')
	{
	  $this->{str} = $this->_si2u2($str);
	}
      elsif($icode eq 'sjis-doti')
	{
	  $this->{str} = $this->_sd2u($str);
	}
      elsif($icode eq 'sjis-doti1')
	{
	  $this->{str} = $this->_sd2u($str);
	}
      elsif($icode eq 'sjis-jsky')
	{
	  $this->{str} = $this->_sj2u2($str);
	}
      elsif($icode eq 'sjis-jsky1')
	{
	  $this->{str} = $this->_sj2u1($str);
	}
      elsif($icode eq 'sjis-jsky2')
	{
	  $this->{str} = $this->_sj2u2($str);
	}
      elsif($icode eq 'jis-jsky')
	{
	  $this->{str} = $this->_sj2u2($this->_j2s($str));
	}
      elsif($icode eq 'jis-jsky1')
	{
	  $this->{str} = $this->_sj2u1($this->_j2s($str));
	}
      elsif($icode eq 'jis-jsky2')
	{
	  $this->{str} = $this->_sj2u2($this->_j2s($str));
	}
      elsif($icode eq 'utf8-jsky')
	{
	  $this->{str} = $this->_uj2u2($str);
	}
      elsif($icode eq 'utf8-jsky1')
	{
	  $this->{str} = $this->_uj2u1($str);
	}
      elsif($icode eq 'utf8-jsky2')
	{
	  $this->{str} = $this->_uj2u2($str);
	}
      elsif($icode eq 'jis-au')
	{
	  $this->{str} = $this->_sa2u2($this->_j2s($str));
	}
      elsif($icode eq 'jis-au1')
	{
	  $this->{str} = $this->_sa2u1($this->_j2s($str));
	}
      elsif($icode eq 'jis-au2')
	{
	  $this->{str} = $this->_sa2u2($this->_j2s($str));
	}
      elsif($icode eq 'sjis-au')
	{
	  $this->{str} = $this->_sa2u2($this->_j2s($this->_sa2j($str)));
	}
      elsif($icode eq 'sjis-au1')
	{
	  $this->{str} = $this->_sa2u1($this->_j2s($this->_sa2j($str)));
	}
      elsif($icode eq 'sjis-au2')
	{
	  $this->{str} = $this->_sa2u2($this->_j2s($this->_sa2j($str)));
	}
      elsif($icode eq 'sjis-icon-au')
	{
	  $this->{str} = $this->_ai2u2($this->_s2u($str));
	}
      elsif($icode eq 'sjis-icon-au1')
	{
	  $this->{str} = $this->_ai2u1($this->_s2u($str));
	}
      elsif($icode eq 'sjis-icon-au2')
	{
	  $this->{str} = $this->_ai2u2($this->_s2u($str));
	}
      elsif($icode eq 'euc-icon-au')
	{
	  $this->{str} = $this->_ai2u2($this->_s2u($this->_e2s($str)));
	}
      elsif($icode eq 'euc-icon-au1')
	{
	  $this->{str} = $this->_ai2u1($this->_s2u($this->_e2s($str)));
	}
      elsif($icode eq 'euc-icon-au2')
	{
	  $this->{str} = $this->_ai2u2($this->_s2u($this->_e2s($str)));
	}
      elsif($icode eq 'jis-icon-au')
	{
	  $this->{str} = $this->_ai2u2($this->_s2u($this->_j2s($str)));
	}
      elsif($icode eq 'jis-icon-au1')
	{
	  $this->{str} = $this->_ai2u1($this->_s2u($this->_j2s($str)));
	}
      elsif($icode eq 'jis-icon-au2')
	{
	  $this->{str} = $this->_ai2u2($this->_s2u($this->_j2s($str)));
	}
      elsif($icode eq 'utf8-icon-au')
	{
	  $this->{str} = $this->_ai2u2($str);
	}
      elsif($icode eq 'utf8-icon-au1')
	{
	  $this->{str} = $this->_ai2u1($str);
	}
      elsif($icode eq 'utf8-icon-au2')
	{
	  $this->{str} = $this->_ai2u2($str);
	}
      elsif($icode eq 'ascii')
	{
	  $this->{str} = $str;
	}
      elsif($icode eq 'binary')
	{
	  $this->{str} = $str;
	}
      else
	{
	  use Carp;
	  croak "icode error [$icode]";
	}
      $this->{icode} = $icode;
    }

  $this;
}
# -----------------------------------------------------------------------------
# Unicode �� ����Ѵ�
# 
sub _ucs2_utf8 {
  my $this = shift;
  my $str = shift;
  
  if(!defined($str))
    {
      return '';
    }
  
  my $result = '';
  for my $uc (unpack("n*", $str))
    {
      $result .= $U2T[$uc] ? $U2T[$uc] :
	($U2T[$uc] = ($uc < 0x80) ? chr($uc) :
	  ($uc < 0x800) ? chr(0xC0 | ($uc >> 6)) . chr(0x80 | ($uc & 0x3F)) :
	    chr(0xE0 | ($uc >> 12)) . chr(0x80 | (($uc >> 6) & 0x3F)) .
	      chr(0x80 | ($uc & 0x3F)));
    }
  
  $result;
}
sub _utf16_utf16 {
  my $this = shift;
  my $str = shift;

  if($str =~ s/^\xfe\xff//)
    {
      $str = $this->_utf16be_utf16($str);
    }
  elsif($str =~ s/^\xff\xfe//)
    {
      $str = $this->_utf16le_utf16($str);
    }
  else
    {
      $str = $this->_utf16be_utf16($str);
    }
  
  $str;
}
sub h2zAlpha {
  my $this = shift;

  if(!defined(%_h2zAlpha))
    {
      $this->_loadConvTable;
    }

  $this->{str} =~ s/(A|B|C|D|E|F|G|H|I|J|K|L|M|N|O|P|Q|R|S|T|U|V|W|X|Y|Z|a|b|c|d|e|f|g|h|i|j|k|l|m|n|o|p|q|r|s|t|u|v|w|x|y|z)/$_h2zAlpha{$1}/eg;
  
  $this;
}
sub z2hKanaK {
  my $this = shift;

  if(!defined(%_z2hKanaK))
    {
      $this->_loadConvTable;
    }

  $this->{str} =~ s/(\xe3\x80\x81|\xe3\x80\x82|\xe3\x83\xbb|\xe3\x82\x9b|\xe3\x82\x9c|\xe3\x83\xbc|\xe3\x80\x8c|\xe3\x80\x8d|\xe3\x82\xa1|\xe3\x82\xa2|\xe3\x82\xa3|\xe3\x82\xa4|\xe3\x82\xa5|\xe3\x82\xa6|\xe3\x82\xa7|\xe3\x82\xa8|\xe3\x82\xa9|\xe3\x82\xaa|\xe3\x82\xab|\xe3\x82\xad|\xe3\x82\xaf|\xe3\x82\xb1|\xe3\x82\xb3|\xe3\x82\xb5|\xe3\x82\xb7|\xe3\x82\xb9|\xe3\x82\xbb|\xe3\x82\xbd|\xe3\x82\xbf|\xe3\x83\x81|\xe3\x83\x83|\xe3\x83\x84|\xe3\x83\x86|\xe3\x83\x88|\xe3\x83\x8a|\xe3\x83\x8b|\xe3\x83\x8c|\xe3\x83\x8d|\xe3\x83\x8e|\xe3\x83\x8f|\xe3\x83\x92|\xe3\x83\x95|\xe3\x83\x98|\xe3\x83\x9b|\xe3\x83\x9e|\xe3\x83\x9f|\xe3\x83\xa0|\xe3\x83\xa1|\xe3\x83\xa2|\xe3\x83\xa3|\xe3\x83\xa4|\xe3\x83\xa5|\xe3\x83\xa6|\xe3\x83\xa7|\xe3\x83\xa8|\xe3\x83\xa9|\xe3\x83\xaa|\xe3\x83\xab|\xe3\x83\xac|\xe3\x83\xad|\xe3\x83\xaf|\xe3\x83\xb2|\xe3\x83\xb3)/$_z2hKanaK{$1}/eg;
  
  $this;
}
# -----------------------------------------------------------------------------
# @codelist = Unicode::Japanese->getcodelist($str);
# 
sub getcodelist {
  my $this = shift;
  my $str = shift;
  my @codelist;
  
  if( $]>=5.008 )
  {
    Encode::_utf8_off($str);
  }
  
  my $l = length($str);
  
  if((($l % 4) == 0)
     and ($str =~ m/^(?:$RE{BOM4_BE}|$RE{BOM4_LE})/o))
    {
      push(@codelist, 'utf32');
    }
  if((($l % 2) == 0)
     and ($str =~ m/^(?:$RE{BOM2_BE}|$RE{BOM2_LE})/o))
    {
      push(@codelist, 'utf16');
    }

  my $str2;
  
  if(($l % 4) == 0)
    {
      $str2 = $str;
      1 while($str2 =~ s/^(?:$RE{UTF32_BE})//o);
      if($str2 eq '')
	{
	  push(@codelist, 'utf32-be');
	}
      
      $str2 = $str;
      1 while($str2 =~ s/^(?:$RE{UTF32_LE})//o);
      if($str2 eq '')
	{
	  push(@codelist, 'utf32-le');
	}
    }
  
  if($str !~ m/[\e\x80-\xff]/)
    {
      push(@codelist, 'ascii');
    }

  if($str =~ m/$RE{JIS_0208}|$RE{JIS_0212}|$RE{JIS_ASC}|$RE{JIS_KANA}/o)
    {
      if($str =~ m/(?:$RE{JIS_0208})(?:[^\e]{2})*$RE{E_JIS_AU}/o)
	{
	  push(@codelist, 'jis-au');
	}
      elsif($str =~ m/(?:$RE{E_JSKY})/o)
	{
	  push(@codelist, 'jis-jsky');
	}
      else
	{
	  push(@codelist, 'jis');
	}
    }

  if($str =~ m/(?:$RE{E_JSKY})/o)
    {
      push(@codelist, 'sjis-jsky');
    }

  $str2 = $str;
  1 while($str2 =~ s/^(?:$RE{ASCII}|$RE{EUC_0212}|$RE{EUC_KANA}|$RE{EUC_C})//o);
  if($str2 eq '')
    {
      push(@codelist, 'euc');
    }

  $str2 = $str;
  1 while($str2 =~ s/^(?:$RE{ASCII}|$RE{SJIS_DBCS}|$RE{SJIS_KANA})//o);
  if($str2 eq '')
    {
      push(@codelist, 'sjis');
    }
  if($str =~ m/^(?:$RE{E_SJIS_AU})/o)
    {
      push(@codelist, 'sjis-au');
    }

  my $str3;
  $str3 = $str2;
  1 while($str3 =~ s/^(?:$RE{ASCII}|$RE{SJIS_DBCS}|$RE{SJIS_KANA}|$RE{E_IMODE})//o);
  if($str3 eq '')
    {
      push(@codelist, 'sjis-imode');
    }

  $str3 = $str2;
  1 while($str3 =~ s/^(?:$RE{ASCII}|$RE{SJIS_DBCS}|$RE{SJIS_KANA}|$RE{E_DOTI})//o);
  if($str3 eq '')
    {
      push(@codelist, 'sjis-doti');
    }

  $str2 = $str;
  1 while($str2 =~ s/^(?:$RE{UTF8})//o);
  if($str2 eq '')
    {
      push(@codelist, 'utf8');
    }

  @codelist or push(@codelist, 'unknown');
  @codelist;
}
sub _sj2u2 {
  my $this = shift;
  my $str = shift;

  if(!defined($str))
    {
      return '';
    }
  
  if(!defined($s2u_table))
    {
      $s2u_table = $this->_getFile('jcode/s2u.dat');
    }

  if(!defined($ej2u1))
  {
    $ej2u1 = $this->_getFile('jcode/emoji2/ej2u.dat');
  }
  if(!defined($ej2u2))
  {
    $ej2u2 = $this->_getFile('jcode/emoji2/ej2u2.dat');
  }

  my $l;
  my $j1;
  my $uc;
  $str =~ s/($RE{SJIS_KANA}|$RE{SJIS_DBCS}|$RE{E_JSKY}|[\x80-\xff])/
    (length($1) <= 2) ? 
      (
       $l = (unpack('n', $1) or unpack('C', $1)),
       (
	($l >= 0xa1 and $l <= 0xdf)     ?
	(
	 $uc = substr($s2u_table, ($l - 0xa1) * 3, 3),
	 $uc =~ tr,\0,,d,
	 $uc
	) :
	($l >= 0x8100 and $l <= 0x9fff) ?
	(
	 $uc = substr($s2u_table, ($l - 0x8100 + 0x3f) * 3, 3),
	 $uc =~ tr,\0,,d,
	 $uc
	) :
	($l >= 0xe000 and $l <= 0xffff) ?
	(
	 $uc = substr($s2u_table, ($l - 0xe000 + 0x1f3f) * 3, 3),
	 $uc =~ tr,\0,,d,
	 $uc
	) :
	($l < 0x80) ?
	chr($l) :
	'?'
       )
      ) :
	(
         $l = $1,
         ( $l =~ s,^$RE{E_JSKY_START}($RE{E_JSKY1v1}),,o
	   ?
	   (
	    $j1 = $1,
	    $uc = '',
	    $l =~ s!($RE{E_JSKY2})!$uc .= substr($ej2u1, (unpack('n', $j1 . $1) - 0x4500) * 4, 4), ''!ego,
	    $uc =~ tr,\0,,d,
	    $uc
	    )
	   :
	   (
	    $l =~ s,^$RE{E_JSKY_START}($RE{E_JSKY1v2}),,o,
	    $j1 = $1,
	    $uc = '',
	    $l =~ s!($RE{E_JSKY2})!$uc .= substr($ej2u2, (unpack('n', $j1 . $1) - 0x4f00) * 4, 4), ''!ego,
	    $uc =~ tr,\0,,d,
	    $uc
	    )
	   )
	)
  /eg;
  
  $str;
  
}
sub jis_icon_au
{
  my $this = shift;
  $this->_s2j($this->_u2s($this->_u2ai2($this->{str})));
}
sub _utf32_ucs4 {
  my $this = shift;
  my $str = shift;

  if($str =~ s/^\x00\x00\xfe\xff//)
    {
      $str = $this->_utf32be_ucs4($str);
    }
  elsif($str =~ s/^\xff\xfe\x00\x00//)
    {
      $str = $this->_utf32le_ucs4($str);
    }
  else
    {
      $str = $this->_utf32be_ucs4($str);
    }
  
  $str;
}
sub _ai2u2 {
  my $this = shift;
  my $str = shift;
  
  if(!defined($str))
    {
      return '';
    }
  
  if(!defined($ea2u2))
    {
      $ea2u2 = $this->_getFile('jcode/emoji2/ea2u2.dat');
    }

  my $c;
  $str =~ s/$RE{E_ICON_AU_START}(\d+)$RE{E_ICON_AU_END}/
    ($1 > 0 and $1 <= 0x0336) ?
      ($c = substr($ea2u2, ($1-1) * 4, 4), $c =~ tr,\0,,d, ($c eq '') ? '?' : $c) :
	'?'
    /ige;

  $str;
}
sub utf8_icon_au2
{
  my $this = shift;
  $this->_u2ai2($this->{str});
}
# utf8-jsky1 => utf8.
sub _uj2u1 {
  my $this = shift;
  my $str = shift;

  if(!defined($str))
  {
    return '';
  }
  
  if(!defined($s2u_table))
  {
    $s2u_table = $this->_getFile('jcode/s2u.dat');
  }

  if(!defined($ej2u1))
  {
    $ej2u1 = $this->_getFile('jcode/emoji2/ej2u.dat');
  }

  $str = $this->_validate_utf8($str);
  
  my @umap = (0x200, 0x000, 0x100);
  $str =~ s{($RE{E_JSKYv1_UTF8}+)}{
    join('',
      map{
        my $l = $_ - 0xe000 + 0x20;
        substr($ej2u1, ($umap[$l/256]+($l&255)) * 4, 4);
      } unpack("n*", $this->_utf8_ucs2($1))
    )
  }geo;
  
  $str;
  
}
sub _sa2j {
  my $this = shift;
  my $str = shift;

  $str =~ s/((?:$RE{SJIS_DBCS}|$RE{E_SJIS_AU}|$RE{SJIS_KANA})+)/
    $this->_sa2j2($1) . $ESC{ASC}
      /geo;

  $str;
}
# -----------------------------------------------------------------------------
# h2z/z2h Kana
# 
sub h2zKana
{
  my $this = shift;

  $this->h2zKanaD;
  $this->h2zKanaK;
  
  $this;
}
sub z2hKana
{
  my $this = shift;
  
  $this->z2hKanaD;
  $this->z2hKanaK;
  
  $this;
}
sub _si2u2 {
  my $this = shift;
  my $str = shift;

  if(!defined($str))
    {
      return '';
    }
  
  if(!defined($s2u_table))
    {
      $s2u_table = $this->_getFile('jcode/s2u.dat');
    }

  if(!defined($ei2u2))
    {
      $ei2u2 = $this->_getFile('jcode/emoji2/ei2u2.dat');
    }

  $str =~ s/(\&\#(\d+);)/
    ($2 >= 0xf800 and $2 <= 0xf9ff) ? pack('n', $2) : $1
      /eg;
  
  my $l;
  my $uc;
  $str =~ s/($RE{SJIS_KANA}|$RE{SJIS_DBCS}|$RE{E_IMODE}|[\x80-\xff])/
    $S2U{$1}
      or ($S2U{$1} =
	  (
	   $l = (unpack('n', $1) or unpack('C', $1)),
	   (
	    ($l >= 0xa1 and $l <= 0xdf)     ?
	    (
	     $uc = substr($s2u_table, ($l - 0xa1) * 3, 3),
	     $uc =~ tr,\0,,d,
	     $uc
	    ) :
	    ($l >= 0x8100 and $l <= 0x9fff) ?
	    (
	     $uc = substr($s2u_table, ($l - 0x8100 + 0x3f) * 3, 3),
	     $uc =~ tr,\0,,d,
	     $uc
	    ) :
	    ($l >= 0xf800 and $l <= 0xf9ff) ?
	    (
	     $uc = substr($ei2u2, ($l - 0xf800) * 4, 4),
	     $uc =~ tr,\0,,d,
	     $uc
	    ) :
	    ($l >= 0xe000 and $l <= 0xffff) ?
	    (
	     $uc = substr($s2u_table, ($l - 0xe000 + 0x1f3f) * 3, 3),
	     $uc =~ tr,\0,,d,
	     $uc
	    ) :
	    ($l < 0x80) ?
	    chr($l) :
	    '?'
	   )
	  )
	 )/eg;
  
  $str;
  
}
sub _u2sj1 {
  my $this = shift;
  my $str = shift;

  if(!defined($str))
    {
      return '';
    }
  
  if(!defined($u2s_table))
    {
      $u2s_table = $this->_getFile('jcode/u2s.dat');
    }

  if(!defined($eu2j1))
    {
      $eu2j1 = $this->_getFile('jcode/emoji2/eu2j.dat');
    }

  my $c1;
  my $c2;
  my $c3;
  my $c4;
  my $c5;
  my $c6;
  my $c;
  my $ch;
  $str =~ s/([\xc0-\xdf][\x80-\xbf]|[\xe0-\xef][\x80-\xbf]{2}|[\xf0-\xf7][\x80-\xbf]{3}|[\xf8-\xfb][\x80-\xbf]{4}|[\xfc-\xfd][\x80-\xbf]{5})|([^\x00-\x7f])/
    defined($2) ? '?' :
    ((length($1) == 1) ? $1 :
     (length($1) == 2) ? (
			  ($c1,$c2) = unpack("C2", $1),
			  $ch = (($c1 & 0x1F)<<6)|($c2 & 0x3F),
			  $c = substr($u2s_table, $ch * 2, 2),
			  ($c eq "\0\0") ? '?' : $c
			 ) :
     (length($1) == 3) ? (
			  ($c1,$c2,$c3) = unpack("C3", $1),
			  $ch = (($c1 & 0x0F)<<12)|(($c2 & 0x3F)<<6)|($c3 & 0x3F),
			  (
			   ($ch <= 0x9fff) ?
			   $c = substr($u2s_table, $ch * 2, 2) :
			   ($ch >= 0xf900 and $ch <= 0xffff) ?
			   (
			    $c = substr($u2s_table, ($ch - 0xf900 + 0xa000) * 2, 2),
			    (($c =~ tr,\0,,d)==2 and $c = "\0\0"),
			   ) :
			   (
			    $c = '?'
			   )
			  ),
			  ($c eq "\0\0") ? '?' : $c
			 ) :
     (length($1) == 4) ? (
			  ($c1,$c2,$c3,$c4) = unpack("C4", $1),
			  $ch = (($c1 & 0x07)<<18)|(($c2 & 0x3F)<<12)|
			  (($c3 & 0x3f) << 6)|($c4 & 0x3F),
			  (
			   ($ch >= 0x0fe000 and $ch <= 0x0fffff) ?
			   (
			    $c = substr($eu2j1, ($ch - 0x0fe000) * 5, 5),
			    $c =~ tr,\0,,d,
			    ($c eq '') ? '?' : $c
			   ) :
			   '?'
			  )
			 ) :
     '?'
    )
      /eg;

  1 while($str =~ s/($RE{E_JSKY_START})($RE{E_JSKY1})($RE{E_JSKY2}+)$RE{E_JSKY_END}$RE{E_JSKY_START}\2($RE{E_JSKY2})($RE{E_JSKY_END})/$1$2$3$4$5/o);
  
  $str;
  
}
# utf8 => utf8-jsky1
sub _u2sj2 {
  my $this = shift;
  my $str = shift;

  if(!defined($str))
    {
      return '';
    }
  
  if(!defined($u2s_table))
    {
      $u2s_table = $this->_getFile('jcode/u2s.dat');
    }

  if(!defined($eu2j2))
    {
      $eu2j2 = $this->_getFile('jcode/emoji2/eu2j2.dat');
    }

  my $c1;
  my $c2;
  my $c3;
  my $c4;
  my $c5;
  my $c6;
  my $c;
  my $ch;
  $str =~ s/([\xc0-\xdf][\x80-\xbf]|[\xe0-\xef][\x80-\xbf]{2}|[\xf0-\xf7][\x80-\xbf]{3}|[\xf8-\xfb][\x80-\xbf]{4}|[\xfc-\xfd][\x80-\xbf]{5})|([^\x00-\x7f])/
    defined($2) ? '?' :
    ((length($1) == 1) ? $1 :
     (length($1) == 2) ? (
			  ($c1,$c2) = unpack("C2", $1),
			  $ch = (($c1 & 0x1F)<<6)|($c2 & 0x3F),
			  $c = substr($u2s_table, $ch * 2, 2),
			  ($c eq "\0\0") ? '?' : $c
			 ) :
     (length($1) == 3) ? (
			  ($c1,$c2,$c3) = unpack("C3", $1),
			  $ch = (($c1 & 0x0F)<<12)|(($c2 & 0x3F)<<6)|($c3 & 0x3F),
			  (
			   ($ch <= 0x9fff) ?
			   $c = substr($u2s_table, $ch * 2, 2) :
			   ($ch >= 0xf900 and $ch <= 0xffff) ?
			   (
			    $c = substr($u2s_table, ($ch - 0xf900 + 0xa000) * 2, 2),
			    (($c =~ tr,\0,,d)==2 and $c = "\0\0"),
			   ) :
			   (
			    $c = '?'
			   )
			  ),
			  ($c eq "\0\0") ? '?' : $c
			 ) :
     (length($1) == 4) ? (
			  ($c1,$c2,$c3,$c4) = unpack("C4", $1),
			  $ch = (($c1 & 0x07)<<18)|(($c2 & 0x3F)<<12)|
			  (($c3 & 0x3f) << 6)|($c4 & 0x3F),
			  (
			   ($ch >= 0x0fe000 and $ch <= 0x0fffff) ?
			   (
			    $c = substr($eu2j2, ($ch - 0x0fe000) * 5, 5),
			    $c =~ tr,\0,,d,
			    ($c eq '') ? '?' : $c
			   ) :
			   '?'
			  )
			 ) :
     '?'
    )
      /eg;

  1 while($str =~ s/($RE{E_JSKY_START})($RE{E_JSKY1})($RE{E_JSKY2}+)$RE{E_JSKY_END}$RE{E_JSKY_START}\2($RE{E_JSKY2})($RE{E_JSKY_END})/$1$2$3$4$5/o);
  
  $str;
  
}
sub utf8_icon_au
{
  my $this = shift;
  $this->_u2ai2($this->{str});
}
sub jis_jsky2
{
  my $this = shift;
  $this->_s2j($this->_u2sj2($this->{str}));
}
# -----------------------------------------------------------------------------
# $bytes_doti = $unijp->sjis_doti();
# 
sub sjis_doti
{
  my $this = shift;
  $this->_u2sd($this->{str});
}
sub _e2s {
  my $this = shift;
  my $str = shift;

  $str =~ s/($RE{EUC_KANA}|$RE{EUC_0212}|$RE{EUC_C})/
    $E2S[unpack('n', $1) or unpack('N', "\0" . $1)] or $this->_e2s2($1)
      /geo;
  
  $str;
}
# -----------------------------------------------------------------------------
# $bytes_eucjp = $unijp->euc();
# 
sub euc
{
  my $this = shift;
  $this->_s2e($this->sjis);
}
sub _j2s3 {
  my $this = shift;
  my $c = shift;

  my ($c1, $c2) = unpack('CC', $c);
  if ($c1 % 2)
    {
      $c1 = ($c1>>1) + ($c1 < 0xdf ? 0x31 : 0x71);
      $c2 -= 0x60 + ($c2 < 0xe0);
    }
  else
    {
      $c1 = ($c1>>1) + ($c1 < 0xdf ? 0x30 : 0x70);
      $c2 -= 2;
    }
  
  $J2S[unpack('n', $c)] = pack('CC', $c1, $c2);
}
sub _j2sa2 {
  my $this = shift;
  my $esc = shift;
  my $str = shift;

  if($esc eq $ESC{JIS_0212})
    {
      $str =~ s/../$CHARCODE{UNDEF_SJIS}/g;
    }
  elsif($esc !~ m/^$RE{JIS_ASC}/)
    {
      $str =~ s{([\x21-\x7e]+)}{
        my $str = $1;
        $str =~ tr/\x21-\x7e/\xa1-\xfe/;
        if($esc =~ m/^$RE{JIS_0208}/)
	  {
	    $str =~ s/($RE{EUC_C})/
	      $this->_j2sa3($1)
	        /geo;
	  }
	$str;
      }e;
    }
  
  $str;
}
# -----------------------------------------------------------------------------
# $bytes_ucs4 = $unijp->ucs4();
# 
sub ucs4
{
  my $this = shift;
  $this->_utf8_ucs4($this->{str});
}
sub _sd2u {
  my $this = shift;
  my $str = shift;

  if(!defined($str))
    {
      return '';
    }
  
  if(!defined($s2u_table))
    {
      $s2u_table = $this->_getFile('jcode/s2u.dat');
    }

  if(!defined($ed2u))
    {
      $ed2u = $this->_getFile('jcode/emoji2/ed2u.dat');
    }

  $str =~ s/(\&\#(\d+);)/
    ($2 >= 0xf000 and $2 <= 0xf4ff) ? pack('n', $2) : $1
      /eg;
  
  my $l;
  my $uc;
  $str =~ s/($RE{SJIS_KANA}|$RE{SJIS_DBCS}|$RE{E_DOTI}|[\x80-\xff])/
    $S2U{$1}
      or ($S2U{$1} =
	  (
	   $l = (unpack('n', $1) or unpack('C', $1)),
	   (
	    ($l >= 0xa1 and $l <= 0xdf)     ?
	    (
	     $uc = substr($s2u_table, ($l - 0xa1) * 3, 3),
	     $uc =~ tr,\0,,d,
	     $uc
	    ) :
	    ($l >= 0x8100 and $l <= 0x9fff) ?
	    (
	     $uc = substr($s2u_table, ($l - 0x8100 + 0x3f) * 3, 3),
	     $uc =~ tr,\0,,d,
	     $uc
	    ) :
	    ($l >= 0xf000 and $l <= 0xf4ff) ?
	    (
	     $uc = substr($ed2u, ($l - 0xf000) * 4, 4),
	     $uc =~ tr,\0,,d,
	     $uc
	    ) :
	    ($l >= 0xe000 and $l <= 0xffff) ?
	    (
	     $uc = substr($s2u_table, ($l - 0xe000 + 0x1f3f) * 3, 3),
	     $uc =~ tr,\0,,d,
	     $uc
	    ) :
	    ($l < 0x80) ?
	    chr($l) :
	    '?'
	   )
	  )
	 )/eg;
  
  $str;
  
}
# utf8 -> jis-au2
sub _u2ja2 {
  my $this = shift;
  my $str = shift;

  if(!defined($str))
    {
      return '';
    }
  
  if(!defined($u2s_table))
    {
      $u2s_table = $this->_getFile('jcode/u2s.dat');
    }

  if(!defined($eu2a2s))
    {
      $eu2a2s = $this->_getFile('jcode/emoji2/eu2a2s.dat');
    }

  my $c1;
  my $c2;
  my $c3;
  my $c4;
  my $c5;
  my $c6;
  my $c;
  my $ch;
  $str =~ s/([\xc0-\xdf][\x80-\xbf]|[\xe0-\xef][\x80-\xbf]{2}|[\xf0-\xf7][\x80-\xbf]{3}|[\xf8-\xfb][\x80-\xbf]{4}|[\xfc-\xfd][\x80-\xbf]{5})|([^\x00-\x7f])/
    defined($2) ? '?' :
    ((length($1) == 1) ? $1 :
     (length($1) == 2) ? (
			  ($c1,$c2) = unpack("C2", $1),
			  $ch = (($c1 & 0x1F)<<6)|($c2 & 0x3F),
			  $c = substr($u2s_table, $ch * 2, 2),
			  ($c eq "\0\0") ? '?' : $c
			 ) :
     (length($1) == 3) ? (
			  ($c1,$c2,$c3) = unpack("C3", $1),
			  $ch = (($c1 & 0x0F)<<12)|(($c2 & 0x3F)<<6)|($c3 & 0x3F),
			  (
			   ($ch <= 0x9fff) ?
			   $c = substr($u2s_table, $ch * 2, 2) :
			   ($ch >= 0xf900 and $ch <= 0xffff) ?
			   (
			    $c = substr($u2s_table, ($ch - 0xf900 + 0xa000) * 2, 2),
			    (($c =~ tr,\0,,d)==2 and $c = "\0\0"),
			   ) :
			   (
			    $c = '?'
			   )
			  ),
			  ($c eq "\0\0") ? '?' : $c
			 ) :
     (length($1) == 4) ? (
			  ($c1,$c2,$c3,$c4) = unpack("C4", $1),
			  $ch = (($c1 & 0x07)<<18)|(($c2 & 0x3F)<<12)|
			  (($c3 & 0x3f) << 6)|($c4 & 0x3F),
			  (
			   ($ch >= 0x0fe000 and $ch <= 0x0fffff) ?
			   (
			    $c = substr($eu2a2s, ($ch - 0x0fe000) * 2, 2),
			    $c =~ tr,\0,,d,
			    ($c eq '') ? '?' : $c
			   ) :
			   '?'
			  )
			 ) :
     '?'
    )
      /eg;

  $str;
}
sub _s2e2 {
  my $this = shift;
  my $c = shift;
  
  my ($c1, $c2) = unpack('CC', $c);
  if (0xa1 <= $c1 && $c1 <= 0xdf)
    {
      $c2 = $c1;
      $c1 = 0x8e;
    }
  elsif (0x9f <= $c2)
    {
      $c1 = $c1 * 2 - ($c1 >= 0xe0 ? 0xe0 : 0x60);
      $c2 += 2;
    }
  else
    {
      $c1 = $c1 * 2 - ($c1 >= 0xe0 ? 0xe1 : 0x61);
      $c2 += 0x60 + ($c2 < 0x7f);
    }
  
  $S2E[unpack('n', $c) or unpack('C', $1)] = pack('CC', $c1, $c2);
}
sub z2hKanaD {
  my $this = shift;

  if(!defined(%_z2hKanaD))
    {
      $this->_loadConvTable;
    }

  $this->{str} =~ s/(\xe3\x82\xac|\xe3\x82\xae|\xe3\x82\xb0|\xe3\x82\xb2|\xe3\x82\xb4|\xe3\x82\xb6|\xe3\x82\xb8|\xe3\x82\xba|\xe3\x82\xbc|\xe3\x82\xbe|\xe3\x83\x80|\xe3\x83\x82|\xe3\x83\x85|\xe3\x83\x87|\xe3\x83\x89|\xe3\x83\x90|\xe3\x83\x91|\xe3\x83\x93|\xe3\x83\x94|\xe3\x83\x96|\xe3\x83\x97|\xe3\x83\x99|\xe3\x83\x9a|\xe3\x83\x9c|\xe3\x83\x9d|\xe3\x83\xb4)/$_z2hKanaD{$1}/eg;
  
  $this;
}
sub _u2sd {
  my $this = shift;
  my $str = shift;

  if(!defined($str))
    {
      return '';
    }
  
  if(!defined($u2s_table))
    {
      $u2s_table = $this->_getFile('jcode/u2s.dat');
    }

  if(!defined($eu2d))
    {
      $eu2d = $this->_getFile('jcode/emoji2/eu2d.dat');
    }

  my $c1;
  my $c2;
  my $c3;
  my $c4;
  my $c5;
  my $c6;
  my $c;
  my $ch;
  $str =~ s/([\xc0-\xdf][\x80-\xbf]|[\xe0-\xef][\x80-\xbf]{2}|[\xf0-\xf7][\x80-\xbf]{3}|[\xf8-\xfb][\x80-\xbf]{4}|[\xfc-\xfd][\x80-\xbf]{5})|([^\x00-\x7f])/
    defined($2) ? '?' :
    ((length($1) == 1) ? $1 :
     (length($1) == 2) ? (
			  ($c1,$c2) = unpack("C2", $1),
			  $ch = (($c1 & 0x1F)<<6)|($c2 & 0x3F),
			  $c = substr($u2s_table, $ch * 2, 2),
			  ($c eq "\0\0") ? '?' : $c
			 ) :
     (length($1) == 3) ? (
			  ($c1,$c2,$c3) = unpack("C3", $1),
			  $ch = (($c1 & 0x0F)<<12)|(($c2 & 0x3F)<<6)|($c3 & 0x3F),
			  (
			   ($ch <= 0x9fff) ?
			   $c = substr($u2s_table, $ch * 2, 2) :
			   ($ch >= 0xf900 and $ch <= 0xffff) ?
			   (
			    $c = substr($u2s_table, ($ch - 0xf900 + 0xa000) * 2, 2),
			    (($c =~ tr,\0,,d)==2 and $c = "\0\0"),
			   ) :
			   (
			    $c = '?'
			   )
			  ),
			  ($c eq "\0\0") ? '?' : $c
			 ) :
     (length($1) == 4) ? (
			  ($c1,$c2,$c3,$c4) = unpack("C4", $1),
			  $ch = (($c1 & 0x07)<<18)|(($c2 & 0x3F)<<12)|
			  (($c3 & 0x3f) << 6)|($c4 & 0x3F),
			  (
			   ($ch >= 0x0fe000 and $ch <= 0x0fffff) ?
			   (
			    $c = substr($eu2d, ($ch - 0x0fe000) * 2, 2),
			    $c =~ tr,\0,,d,
			    ($c eq '') ? '?' : $c
			   ) :
			   '?'
			  )
			 ) :
     '?'
    )
      /eg;
  $str;
  
}
sub sjis_au
{
  my $this = shift;
  $this->_j2sa($this->_s2j($this->_u2ja2($this->{str})));
}
sub _utf8_ucs2 {
  my $this = shift;
  my $str = shift;
  
  if(!defined($str))
    {
      return '';
    }

  my $c1;
  my $c2;
  my $c3;
  my $ch;
  $str =~ s/([\xc0-\xdf][\x80-\xbf]|[\xe0-\xef][\x80-\xbf]{2}|[\xf0-\xf7][\x80-\xbf]{3}|[\xf8-\xfb][\x80-\xbf]{4}|[\xfc-\xfd][\x80-\xbf]{5}|.)/
    defined($2)?"\0?":
    $T2U{$1}
      or ($T2U{$1}
	  = ((length($1) == 1) ? pack("n", unpack("C", $1)) :
	     (length($1) == 2) ? (($c1,$c2) = unpack("C2", $1),
				  $ch = (($c1 & 0x1F)<<6)|($c2 & 0x3F),
				  $ch<0x80 ? "\0?" : pack("n", $ch)
				  ) :
	     (length($1) == 3) ? (($c1,$c2,$c3) = unpack("C3", $1),
				  $ch = (($c1 & 0x0F)<<12)|(($c2 & 0x3F)<<6)|($c3 & 0x3F),
				  $ch<0x0800 ? "\0?" : pack("n", $ch)
				  ) : "\0?"))
	/eg;
  $str;
}
sub euc_icon_au1
{
  my $this = shift;
  $this->_s2e($this->_u2s($this->_u2ai1($this->{str})));
}
# -----------------------------------------------------------------------------
# $bytes_au = $unijp->jis_au1();
# 
sub jis_au
{
  my $this = shift;
  $this->_s2j($this->_u2ja2($this->{str}));
}
sub _utf32le_ucs4 {
  my $this = shift;
  my $str = shift;

  my $result = '';
  foreach my $ch (unpack('V*', $str))
    {
      $result .= pack('N', $ch);
    }
  
  $result;
}
# -----------------------------------------------------------------------------
# $bytes_imode = $unijp->sjis_imode();
# 
sub sjis_imode
{
  my $this = shift;
  $this->_u2si2($this->{str});
}
sub _e2s2 {
  my $this = shift;
  my $c = shift;

  my ($c1, $c2) = unpack('CC', $c);
  if ($c1 == 0x8e)
    {		# SS2
      $E2S[unpack('n', $c)] = chr($c2);
    }
  elsif ($c1 == 0x8f)
    {	# SS3
      $E2S[unpack('N', "\0" . $c)] = $CHARCODE{UNDEF_SJIS};
    }
  else
    {			#SS1 or X0208
      if ($c1 % 2)
	{
	  $c1 = ($c1>>1) + ($c1 < 0xdf ? 0x31 : 0x71);
	  $c2 -= 0x60 + ($c2 < 0xe0);
	}
      else
	{
	  $c1 = ($c1>>1) + ($c1 < 0xdf ? 0x30 : 0x70);
	  $c2 -= 2;
	}
      $E2S[unpack('n', $c)] = pack('CC', $c1, $c2);
    }
}
sub _s2j2 {
  my $this = shift;
  my $str = shift;

  $str =~ s/((?:$RE{SJIS_DBCS})+|(?:$RE{SJIS_KANA})+)/
    my $s = $1;
  if($s =~ m,^$RE{SJIS_KANA},o)
    {
      $s =~ tr,\xa1-\xdf,\x21-\x5f,;
      $ESC{KANA} . $s
    }
  else
    {
      $s =~ s!($RE{SJIS_DBCS})!
	$S2J[unpack('n', $1)] or $this->_s2j3($1)
	  !geo;
      $ESC{JIS_0208} . $s;
    }
  /geo;
  
  $str;
}
# -----------------------------------------------------------------------------
# encode/decode
sub _encodeBase64
{
  my $this = shift;
  my $str = shift;
  my $eol = shift;
  my $res = "";
  
  $eol = "\n" unless defined $eol;
  pos($str) = 0;                          # ensure start at the beginning
  while ($str =~ /(.{1,45})/gs)
    {
      $res .= substr(pack('u', $1), 1);
      chop($res);
    }
  $res =~ tr|` -_|AA-Za-z0-9+/|;               # `# help emacs
  # fix padding at the end
  my $padding = (3 - length($str) % 3) % 3;
  $res =~ s/.{$padding}$/'=' x $padding/e if $padding;
  # break encoded string into lines of no more than 76 characters each
  if (length $eol)
    {
      $res =~ s/(.{1,76})/$1$eol/g;
    }
  $res;
}
sub validate_utf8
{
  # my $safer_utf8 = Unicode::Japanese->validate_utf8($utf8_str);
  #
  $_[0]->_validate_utf8(@_[1..$#_]);
}
sub sjis_icon_au
{
  my $this = shift;
  $this->_u2s($this->_u2ai2($this->{str}));
}
# -----------------------------------------------------------------------------
# split/join Csv
# 
sub split_csv {
  &splitCsv;
}
# sjis-au2 => utf8
sub _sa2u2 {
  my $this = shift;
  my $str = shift;

  if(!defined($str))
    {
      return '';
    }
  
  if(!defined($s2u_table))
    {
      $s2u_table = $this->_getFile('jcode/s2u.dat');
    }

  if(!defined($ea2u2s))
  {
    $ea2u2s = $this->_getFile('jcode/emoji2/ea2u2s.dat');
  }

  my $l;
  my $uc;
  $str =~ s/($RE{SJIS_KANA}|$RE{SJIS_DBCS}|[\x80-\xff])/
    $SA2U2{$1}
      or ($SA2U2{$1} =
	  (
	   $l = (unpack('n', $1) or unpack('C', $1)),
	   (
	    ($l >= 0xa1 and $l <= 0xdf)     ?
	    (
	     $uc = substr($s2u_table, ($l - 0xa1) * 3, 3),
	     $uc =~ tr,\0,,d,
	     $uc
	    ) :
	    ($l >= 0x8100 and $l <= 0x9fff) ?
	    (
	     $uc = substr($s2u_table, ($l - 0x8100 + 0x3f) * 3, 3),
	     $uc =~ tr,\0,,d,
	     $uc
	    ) :
	    ($l >= 0xeb00 and $l <= 0xeeff) ?
	    (
	     $uc = substr($ea2u2s, ($l - 0xeb00) * 4, 4),
	     $uc =~ tr,\0,,d,
	     $uc
	    ) :
	    ($l >= 0xe000 and $l <= 0xfcff) ?
	    (
	     $uc = substr($s2u_table, ($l - 0xe000 + 0x1f3f) * 3, 3),
	     $uc =~ tr,\0,,d,
	     $uc
	    ) :
	    ($l < 0x80) ?
	    chr($l) :
	    '?'
	   )
	  )
	 )/eg;
  
  $str;
  
}
# -----------------------------------------------------------------------------
# $bytes_jsky = $unijp->jis_jsky();
# 
sub jis_jsky
{
  my $this = shift;
  $this->_s2j($this->_u2sj2($this->{str}));
}
# -----------------------------------------------------------------------------
# strcut, strlen
# 
sub strcut
{
  my $this = shift;
  my $cutlen = shift;
  
  if(ref($cutlen))
    {
      die "String->strcut, Param[1] is Ref.\n";
    }
  if($cutlen =~ m/\D/)
    {
      die "String->strcut, Param[1] must be NUMERIC.\n";
    }
  
  my $ch_re = '[\x00-\x7f]|[\xc0-\xdf][\x80-\xbf]|[\xe0-\xef][\x80-\xbf]{2}|[\xf0-\xf7][\x80-\xbf]{3}|[\xf8-\xfb][\x80-\xbf]{4}|[\xfc-\xfd][\x80-\xbf]{5}';
  
  my $result;
  my $line = '';
  my $linelength = 0;

  foreach my $c (split(/($ch_re)/, $this->{str}))
    {
      next if(length($c) == 0);
      if($linelength + (length($c) >= 3 ? 2 : 1) > $cutlen)
	{
	  $line ne '' and push(@$result, $line);
	  $line = '';
	  $linelength = 0;
	}
      $linelength += (length($c) >= 3 ? 2 : 1);
      $line .= $c;
    }
  push(@$result, $line);

  $result;
}
sub cp932
{
  shift->sjis(@_);
}
sub _utf32be_ucs4 {
  my $this = shift;
  my $str = shift;

  $str;
}
          	 
   
   

? ? ? ? ? ?  L?  S? ? ? VS? ? ? ? ? ? ? ? ? ? ? ? ? ? ?  �? ? ? ���TID����w�c? ? ? ? ? ? ? ? ? ? ? ? �j? ? ? ? ? ? ? ? ? ? ?  3 3 3 3 3 3? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? # D? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ?  K? ? ? ? ? ? ?  �? ? ? ? ? ? ? ��? ? ? ? ? ? ? ?  �? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ?  �?  �? ? ? ? ? ? ? ? �`�a�nAB? ? ? ? !?!!�`? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ?  l? ? ? ? ? ? ? ? ? ? ? ? ? ?  l? ? ?  3 N? ? ? ��? ? ? ? ? ?  l? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? E � � � � � � � � � �1112 � � � � � � � � � ��c�Z���x�N�E�Ȏw �`�����}�����őS�n��? ?  �? ?  � �?  J?  � � � � � � � � � �?  � � � �?  � �? ? ? ?  � q  �? ? ? ?  �? ? ? ? ? ? ?  P 2? ? ? ?  } � �?  � � � �?  � � �? ?  A 4 ] �? ? ? !? ? ?  �?  n? ? ? ? ?  �?  �? ? ? ? ?  - �3 �2?  �?  � � � � �? ? ? ?  �? ? ?  � � , k _ � ?   ? ? ?  � �? ? ?@ 3
 3;? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? <:!!!?? ? ? ? # 5? ? ? ? ? ? ? ? ? ? ? ?  |? ? ? ? ? ?  S?  t?  H � � U �?  �? ?  �?  . ^ M � ? &? ,?  �?  [ a � h �? ? ?  l w C 1 p? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? (? ? ? ? ? ?  H  x �? ?  {? ? ? ? ? ?  �? $ W 
? G? #? ?  M? ?  !?!!? J�`�`F? ? ? ? '?  � 0?  ? ?  � �?  H 9 �?  ? ? ? 
? ? ? ? NG � Q 6? ?  R �֋󍇖���? ? ? ?  5 � q? ? ?  � � � �? ? ? ?  N � �? ?  � � ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ?  �?  � �
?  �?  �? ?  M 5?  �( w? ?  L �?  �
   


 3;? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? <:��? ? ? ? W 5�? ? ? ? ? ? ? %? ? � |? �? �? ?  S?  t?  H � � U �?  �Q?  �?  . ^ M � R&? ,a �?  [ a � h �w? & l w C 1 p? T�? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? (? ? ? ? ? b H  x �? d {? ? ��? � �? $ W 
�G�W? �?  M? � ��? J�`�F? ? ? ? '% � 0?  Q& � �b H 9 �� ? ? _? ]? ? ? ? NG � Q 6? ' R ������()y*V 5 � q��+ � � � ��M�?  N � �? . � � ^? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ?  �?  � �]^_ �` �ab M 5c �( w? de �f �