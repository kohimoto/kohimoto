#!/usr/bin/perl
##############################################################################
# MP Form Mail CGI Standard版 Ver5.0.1
# （CGI本体）
# Copyright(C) futomi 2001 - 2007
# http://www.futomi.com/
###############################################################################
use strict;
use lib './lib';
use Jcode;
use MIME::Base64::Perl;
use CGI;
my $q = new CGI;
$| = 1;
my $VERSION = '5.0.0';
# X-Mailerの指定
my $X_MAILER = "MP Form Mail CGI Standard Ver${VERSION} (http://www.futomi.com/)";

#Unicode::Japaneseの動作チェック
my $UJ = 1;
if($] < 5.006) {
	$UJ = 0;
} else {
	eval {require Unicode::Japanese;};
	if($@) {$UJ = 0;}
}

# 設定ファイル読み込み
require './conf/config.cgi';
my %c = &config::get;

# mpconfig.cgiの設定内容のチェック
&ConfCheck(\%c);

# 外部サーバからの利用禁止
&ExternalRequestCheck;

# Base64エンコードテーブル
my $Base64Table = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.
	           'abcdefghijklmnopqrstuvwxyz'.
	           '0123456789+/';

# 指定ホストからのアクセスを除外する
my $host_name = &GetHostName($ENV{'REMOTE_ADDR'});
&RejectHostAccess($host_name);

# sendmailのパスを取得する
if($c{'SENDMAIL'} eq '') {
	$c{'SENDMAIL'} = &MakeSendmailPath;
}
# フォームデータを取得,送信メール本文生成、確認画面用HIDDENタグ生成
my %values = ();
my @hiddens = ();
my $mp_status = $q->param('mp_status');
for my $key (@{$c{'NAMES'}}) {
	my @multi_values = $q->param($key);
	my $multi_values_num = scalar @multi_values;
	my @valid_values;
	for my $value (@multi_values) {
		$value = &UnifyReturnCode($value);
		if($multi_values_num > 1) {
			if($value eq '') {
				next;
			}
		}
		#サイズ制限
		unless($key eq 'attachment') {
			if($c{'MAX_INPUT_CHAR'} && length($value) > $c{'MAX_INPUT_CHAR'}) {
				&ErrorPrint("入力文字は、半角で$c{'MAX_INPUT_CHAR'}文字までです。");
			}
		}
		my $value_for_hidden = &SecureHtml($value);
		my $hidden_tag = "<input type=\"hidden\" name=\"$key\" value=\"$value_for_hidden\">";
		push(@hiddens, $hidden_tag);
		push(@valid_values, $value);
	}
	$values{$key} = join(" ", @valid_values);
}
push(@hiddens, '<input type="hidden" name="mp_status" value="1">');
# タイムスタンプ用の日時文字列を取得
# $Stamp: ログ出力用
# $SendDate: 送信メール用
my($stamp, $send_date) = &GetDate;
$values{'DATE'} = $send_date;
$values{'USERAGENT'} = $ENV{'HTTP_USER_AGENT'};
$values{'REMOTE_ADDR'} = $ENV{'REMOTE_ADDR'};
$values{'REMOTE_HOST'} = $host_name;

# シリアル番号を生成
if($c{'SIRIAL_FLAG'}) {
	my $sirial = &MakeSirial($stamp);
	$values{'sirial'} = $sirial;
	$values{'SIRIAL'} = $sirial;
}

#Safariの文字化けをチェック
if($ENV{'HTTP_USER_AGENT'} =~ /Safari/) {
	&SafariEncodeMistakeCheck(\%values);
}

# 必須項目が選択もしくは入力されているかのチェック
&NecessaryCheck(\%values, $c{'NECESSARY_NAMES'});

# name属性が「mailaddress」のものが存在しなければ、自動返信のフラグをOFFにする。
unless($values{'mailaddress'}) {
	$c{'REPLY_FLAG'} = 0;
}

# フォーム内に、name属性が「mailaddress」のものがあれば、
# 送信元メールアドレスを優先的に設定する。
my $from_flag = 0;
if($values{'mailaddress'} ne '') {
	$c{'FROM'} = $values{'mailaddress'};
	$from_flag = 1;
}

# フォーム内に、name属性が「subject」のものがあれば、
# 送信元メールサブジェクトを優先的に設定する。
if($values{'subject'} ne '') {
	$c{'SUBJECT'} = $values{'subject'};
}

# 添付ファイルが存在すれば 1 がセットされる
my $attach_flag = 0;
if($values{'attachment'} ne '') {
	$attach_flag = 1;
}

# 添付ファイルがあれば、ファイル名を抽出し、
# テンポラリーファイルを生成する。
my($attach_content_type, $attache_file_name, $attach_file);
if($attach_flag) {
	my $full_file_name = $q->param('attachment');
	$attach_content_type = $q->uploadInfo($full_file_name)->{'Content-Type'};
	my $full_file_name_euc = $full_file_name;		# \ で区切りたいが、SJISではうまくいかないため、EUCに変換してから \ で分割する。
	$full_file_name_euc = &CharCodeConvert("$full_file_name_euc", "euc", "sjis");
	my @path_parts = split(/\\/, $full_file_name_euc);
	$attache_file_name = pop(@path_parts);
	$attache_file_name = &CharCodeConvert("$attache_file_name", "sjis", "euc");
	# 拡張子チェック
	if(scalar @{$c{'EXT_RESTRICT'}}) {
		my @parts = split(/\./, $attache_file_name);
		my $ext = pop(@parts);
		unless(grep(/^$ext$/i, @{$c{'EXT_RESTRICT'}})) {
			&ErrorPrint("指定のファイルを送信することはできません。");
		}
	}
	$c{'ATTACHMENT_DIR'} =~ s/\/$//;
	$attach_file = "$c{'ATTACHMENT_DIR'}/${attache_file_name}";
	open(OUTFILE, ">$attach_file") || &ErrorPrint("添付ファイルのテンポラリーファイル\[${attach_file}\]の作成に失敗しました。:$!");
	my($bytesread, $buffer);
	while($bytesread=read($full_file_name, $buffer, 1024)) {
		print OUTFILE $buffer;
	}
	close(OUTFILE);
	# 添付ファイルサイズのチェック
	my $attach_file_size = -s $attach_file;
	if($attach_file_size > $c{'ATTACHMENT_MAX_SIZE'}) {
		unlink($attach_file);
		&ErrorPrint("$c{'ATTACHMENT_MAX_SIZE'}バイト以上のファイルは添付できません。");
	}
}

#確認画面表示
if($c{'CONFIRM_FLAG'} && $attach_flag == 0 && ! $mp_status) {
	&PrintConfirm($c{'NAMES'}, \%values, \@hiddens);
	exit;
}

# フォームデータをログに出力
if($c{'LOGING_FLAG'}) {
	&Loging($c{'NAMES'}, \%values, $stamp);
}

#メール送信
&MailSend($c{'NAMES'}, \%values, $attach_flag, $attach_file, $attach_content_type);

# 返信メールを送信
if($c{'REPLY_FLAG'} && $from_flag) {
	&Reply($c{'NAMES'}, \%values);
}

# 添付ファイルを削除する
if($attach_flag && $c{'ATTACHMENT_DEL_FLAG'}) {
	unlink($attach_file);
}

# リダイレクト
&Redirect;

exit;

######################################################################
# サブルーチン
######################################################################

sub SafariEncodeMistakeCheck {
	#?が3つ以上連続した項目が2項目以上あった場合に、Safari文字化け現象とみなす。
	my($values_ref) = @_;
	my $count = 0;
	for my $key (keys %{$values_ref}) {
		my $value = $values_ref->{$key};
		if($value =~ /[^\x20-\x7E]/) {
			next;
		}
		if($value =~ /\?{3}/) {
			$count ++;
		}
	}
	if($count >= 2) {
		&ErrorPrint("ご利用のブラウザー（Safari）から送信されたデータは、文字化けを起こしています。入力画面に戻り、再読み込みをした後、再度、入力して下さい。");
	}
}

# 必須項目が選択もしくは入力されているかのチェック
sub NecessaryCheck {
	my($values_ref, $necessary_names_ref) = @_;
	my @null_names = ();
	for my $name (@$necessary_names_ref) {
		if($values_ref->{$name} eq '') {
			push(@null_names, $name);
		}
	}
	if(@null_names) {
		my $error = '以下の項目は必須です。<ul>';
		for my $name (@null_names) {
			my $disp_name = $c{'NAME_MAP'}->{$name};
			if($disp_name eq '') {
				$disp_name = $name;
			}
			$error .= "<li>${disp_name}</li>";
		}
		$error .= '</ul>';
		&ErrorPrint($error);
	}
	#メールアドレスチェック
	if($values_ref->{'mailaddress'} ne '') {
		unless(&MailAddressCheck($values_ref->{'mailaddress'})) {
			my $disp_name = $c{'NAME_MAP'}->{'mailaddress'};
			if($disp_name eq '') {
				$disp_name = 'mailaddress';
			}
			&ErrorPrint("${disp_name}が正しくありません。");
		}
	}
}

sub SpritSjisChars {
	my($string) = @_;
	$_ = $string;
	my @chars = /
		 [\x20-\x7E]             #ASCII文字
		|[\xA1-\xDF]             #半角カタカナ
		|[\x81-\x9F][\x40-\xFC]  #2バイト文字
		|[\xE0-\xEF][\x40-\xFC]  #2バイト文字
	/gox;
	return @chars;
}

sub Redirect {
	if($c{'REDIRECT_METHOD'}) {
		my $html;
		$html .= "<html><head><title>${X_MAILER}</title>\n";
		$html .= "<META HTTP-EQUIV=\"Refresh\" CONTENT=\"0; URL=$c{'REDIRECT_URL'}\">\n";
		$html .= "</head><body>\n";
		$html .= "うまく転送されない場合は、<a href=\"$c{'REDIRECT_URL'}\">こちら</a>をクリックして下さい。";
		$html .= "</body></html>";
		my $content_length = length($html);
		print "Content-Length: $content_length\n";
		print "Content-Type: text/html; charset=Shift_JIS\n";
		print "\n";
		print $html;
		exit;
	} else {
		print "Location: $c{'REDIRECT_URL'}\n\n";
		exit;
	}
}

# 確認画面を表示する
sub PrintConfirm {
	my($names_ref, $values_ref, $hiddens_ref) = @_;
	# このCGIのURLを特定する。
	my $cgiurl;
	if($c{'MANUAL_CGIURL'} =~ /^http/) {
		$cgiurl = $c{'MANUAL_CGIURL'};
	} else {
		$cgiurl = &GetCgiUrl;
	}
	#Hiddenタグを一つのスカラー変数に格納する。
	my $hidden = join("\n", @$hiddens_ref);
	#確認画面テンプレートを読み取る
        #kohinata costom
	my $html = &ReadTemplate($c{'TEMP_HEADER_FILE'});
	   $html .= &ReadTemplate($c{'CONFIRM_TEMP_FILE'});
	   $html .= &ReadTemplate($c{'TEMP_FOOTER_FILE'});
	#my $html = &ReadTemplate($c{'CONFIRM_TEMP_FILE'});
	#hiddenタグを置換
	if($html =~ /\$hidden\$/) {
		$html =~ s/\$hidden\$/$hidden/;
	} else {
		&ErrorPrint("確認画面用テンプレートHTMLファイル $c{'CONFIRM_TEMP_FILE'} に、\$hidden\$ が記載されておりません。");
	}
	$html =~ s/\$cgiurl\$/$cgiurl/;
	for my $name (@$names_ref) {
		my $disp_values = $values_ref->{$name};
		$disp_values = &SecureHtml($disp_values);
		if($disp_values eq '') {
			$disp_values = '&nbsp;';
		} else {
			$disp_values =~ s/\n/<br>\n/g;
		}
		$html =~ s/\$$name\$/$disp_values/g;
	}
	my $content_length = length($html);
	print "Content-Length: $content_length\n";
	print "Content-Type: text/html; charset=Shift_JIS\n";
	print "\n";
	print $html;
	exit;
}

# メールを送信する
sub MailSend {
	my($names_ref, $values_ref, $attach_flag, $attach_file, $attach_content_type) = @_;
	my @names = @$names_ref;
	my %values = %$values_ref;
	my $body;
	if($c{'FORMAT_CUSTOM_FLAG'}) {
		$body = &MakeCustomizeMailBody(\@names, \%values);
	} else {
		$body = &MakeRegularMailBody(\@names, \%values);
	}
	# メッセージをワードラップする
	if($c{'WRAP'} >= 50) {
		$body = &WordWrap($body, $c{'WRAP'}, 1, 1);
	}
	# メッセージをJISに変換
	$body = &CharCodeConvert("$body", "jis", "sjis");
	my($boundary, $base64data);
	if($attach_flag) {
		# 境界を定義
		$boundary = &GenerateBoundary($body);
		#添付ファイルをBase64エンコードする
		my $file_size = -s "$attach_file";
		my $file_data;
		open(FILE, "$attach_file") || &ErrorPrint("添付ファイルのテンポラリーファイルをオープン出来ませんでした。: $!");
		sysread FILE, $file_data, $file_size;
		close(FILE);
		$base64data = MIME::Base64::Perl::encode_base64($file_data);
	}
	# サブジェクト内に、フォーム入力値変換指示子があれば変換する。
	for my $key (keys %$values_ref) {
		$c{'SUBJECT'} =~ s/\$$key\$/$values_ref->{$key}/g;
	}
	# メールタイトルをBase64 Bエンコード
	$c{'SUBJECT'} = &EncodeSubject($c{'SUBJECT'});

	# メール送信
	my $sendmail_opt = ' -t';
	if($c{'SENDMAIL_OPT_oi'}) {
		$sendmail_opt .= ' -oi';
	}
	if($c{'SENDMAIL_OPT_f'}) {
		$sendmail_opt .= " -f'$c{'FROM'}'";
	}
	open(SENDMAIL, "|$c{'SENDMAIL'}${sendmail_opt}") || &ErrorPrint("メール送信に失敗しました : $!");
	print SENDMAIL "To: $c{'MAILTO'}\n";
	print SENDMAIL "From: $c{'FROM'}\n";
	print SENDMAIL "Subject: $c{'SUBJECT'}\n";
	print SENDMAIL "X-Mailer: $X_MAILER\n";
	print SENDMAIL "MIME-Version: 1.0\n";
	if($attach_flag) {
		print SENDMAIL 'Content-Type: multipart/mixed;',"\n";
		print SENDMAIL "	boundary=\"$boundary\"\n";
		print SENDMAIL "Content-Transfer-Encoding: 7bit\n";
		print SENDMAIL "\n";
		print SENDMAIL "--$boundary\n";
	}
	print SENDMAIL "Content-Type: text/plain\; charset=iso-2022-jp\n";
	print SENDMAIL "Content-Transfer-Encoding: 7bit\n";
	print SENDMAIL "\n";
	print SENDMAIL "$body\n";
	print SENDMAIL "\n";
	if($attach_flag) {
		my @parts = split(/\//, $attach_file);
		my $file_name = pop @parts;
		$file_name = &EncodeSubject($file_name);
		print SENDMAIL "--$boundary\n";
		print SENDMAIL "Content-Type: $attach_content_type; name=\"$file_name\"\n";
		print SENDMAIL "Content-Disposition: attachment;\n";
		print SENDMAIL " filename=\"$file_name\"\n";
		print SENDMAIL "Content-Transfer-Encoding: base64\n";
		print SENDMAIL "\n";
		print SENDMAIL "$base64data\n";
		print SENDMAIL "\n";
		print SENDMAIL "--$boundary--";
	}
	close(SENDMAIL);
}

sub MakeRegularMailBody {
	my($names_ref, $values_ref) = @_;
	my $body;
	if($c{'SIRIAL_FLAG'}) {
		$body = "【シリアル番号】\n";
		$body .= "$values_ref->{'sirial'}\n\n";
	}
	for my $name (@$names_ref) {
		if($c{'NAME_MAP'}->{$name}) {
			$body .= "【$c{'NAME_MAP'}->{$name}】\n";
		} else {
			$body .= "【$name】\n";
		}
		$body .= "$values_ref->{$name}\n";
		$body .= "\n";

	}
	$body .= "\n";
	# 送信者情報をメール本文に追加
	my $host_name = &GetHostName($ENV{'REMOTE_ADDR'});

	$body .= "【送信者情報】\n";
	$body .= "  ・ブラウザー      : $values_ref->{'USERAGENT'}\n";
	$body .= "  ・送信元IPアドレス: $values_ref->{'REMOTE_ADDR'}\n";
	$body .= "  ・送信元ホスト名  : $values_ref->{'REMOTE_HOST'}\n";
	$body .= "  ・送信日時        : $values_ref->{'DATE'}\n";

	return $body;
}

sub MakeCustomizeMailBody {
	my($names_ref, $values_ref) = @_;
	my $template = &ReadTemplate($c{'MAIL_TEMP_FILE'});
	for my $key (@$names_ref) {
		$template =~ s/\$$key\$/$values_ref->{$key}/g;
	}
	$template =~ s/\$USERAGENT\$/$values_ref->{'USERAGENT'}/g;
	$template =~ s/\$REMOTE_ADDR\$/$values_ref->{'REMOTE_ADDR'}/g;
	$template =~ s/\$REMOTE_HOST\$/$values_ref->{'REMOTE_HOST'}/g;
	$template =~ s/\$DATE\$/$values_ref->{'DATE'}/g;
	$template =~ s/\$SIRIAL\$/$values_ref->{'SIRIAL'}/ig;
	$template = &UnifyReturnCode($template);
	return $template;
}


# フォームデータをログに出力
sub Loging {
	my($names_ref, $values_ref, $time_stamp) = @_;
	my @log_parts;
	push(@log_parts, "${time_stamp}");;
	if($c{'SIRIAL_FLAG'}) {
		push(@log_parts, "$values{'SIRIAL'}");
	}
	for my $key (@$names_ref) {
		my $part;
		if($c{'LOG_FORMAT'}) {$part .= "${key}=";}
		my $value = $values_ref->{$key};
		if($c{'DELIMITER'} == 2) {
			$value =~ s/ /　/g;;	#半角スペースを全角スペースに変換
		} elsif($c{'DELIMITER'} == 3) {
			$value =~ s/\t//g;
		} else {
			$value =~ s/,/，/g;	#半角カンマを全角カンマに変換
		}
		$part .= "$value";
		$part = &UnifyReturnCode($part);	#改行コードを「\n」に統一する
		$part =~ s/\n/<br>/g;				#改行コードを<br>に変換する
		push(@log_parts, $part);
	}
	#区切り文字を定義
	my $delimiter_char;
	if($c{'DELIMITER'} == 2) {
		$delimiter_char = ' ';
	} elsif($c{'DELIMITER'} == 3) {
		$delimiter_char = "\t";
	} else {
		$delimiter_char = ",";
	}
	#ログの行を生成
	my $log_line = join("$delimiter_char", @log_parts);
	#ログファイルをオープンし、ロックする
	open(LOGFILE, ">>$c{'LOGFILE'}") || &ErrorPrint("ログファイル $c{'LOGFILE'} を書込オープンできませんでした。： $!");
	if(my $lock_result = &Lock(*LOGFILE)) {
		&ErrorPrint("只今、込み合っております。しばらくしてからお試しください。: $lock_result");;
	}
	#行をログに出力
	print LOGFILE "$log_line\n";
	close(LOGFILE);
}


# 返信メールを送信する
sub Reply {
	my($names_ref, $values_ref) = @_;
	# テンプレートファイルの文字列を $templateに格納する
	my $template = &ReadTemplate($c{'REPLY_TEMP_FILE'});
	# 文字変換
	for my $key (@$names_ref) {
		$template =~ s/\$$key\$/$values_ref->{$key}/g;
	}

	$template =~ s/\$USERAGENT\$/$values_ref->{'USERAGENT'}/g;
	$template =~ s/\$REMOTE_ADDR\$/$values_ref->{'REMOTE_ADDR'}/g;
	$template =~ s/\$REMOTE_HOST\$/$values_ref->{'REMOTE_HOST'}/g;
	$template =~ s/\$DATE\$/$values_ref->{'DATE'}/g;
	$template =~ s/\$SIRIAL\$/$values_ref->{'SIRIAL'}/ig;

	# メッセージの改行コードを統一する
	$template = &UnifyReturnCode($template);

	# メッセージをワードラップする
	if($c{'WRAP'} >= 50) {
		$template = &WordWrap($template, $c{'WRAP'}, 1, 1);
	}
	# メール送信のために、メッセージをJISに変換
	$template = &CharCodeConvert("$template", "jis", "sjis");
	# サブジェクト内に、フォーム入力値変換指示子があれば変換する。
	for my $key (keys %$values_ref) {
		$c{'SUBJECT_FOR_REPLY'} =~ s/\$$key\$/$values_ref->{$key}/g;
	}
	# サブジェクトをBase64 Bエンコード
	$c{'SUBJECT_FOR_REPLY'} = &EncodeSubject($c{'SUBJECT_FOR_REPLY'});
	# From行をエンコード
	my $from_line = $c{'FROM_ADDR_FOR_REPLY'};
	if($c{'SENDER_NAME_FOR_REPLY'}) {
		$from_line = &EncodeFrom($c{'SENDER_NAME_FOR_REPLY'}, $c{'FROM_ADDR_FOR_REPLY'});
	}
	# 返信メール送信
	my $sendmail_opt = ' -t';
	if($c{'SENDMAIL_OPT_oi'}) {
		$sendmail_opt .= ' -oi';
	}
	if($c{'SENDMAIL_OPT_f'}) {
		if($c{'ERRORS_TO'}) {
			$sendmail_opt .= " -f'$c{'ERRORS_TO'}'";
		} else {
			$sendmail_opt .= " -f'$c{'FROM_ADDR_FOR_REPLY'}'";
		}
	}
	open(SENDMAIL, "|$c{'SENDMAIL'}${sendmail_opt}") || &ErrorPrint("自動返信メールを送信できませんでした。: $!");
	if($c{'ERRORS_TO'} ne '') {
		print SENDMAIL "Return-Path: $c{'ERRORS_TO'}\n";
	}
	print SENDMAIL "To: $c{'FROM'}\n";
	print SENDMAIL "From: $from_line\n";
	print SENDMAIL "Subject: $c{'SUBJECT_FOR_REPLY'}\n";
	print SENDMAIL "X-Mailer: $X_MAILER\n";
	print SENDMAIL "MIME-Version: 1.0\n";
	print SENDMAIL "Content-Type: text/plain\; charset=iso-2022-jp\n";
	print SENDMAIL "Content-Transfer-Encoding: 7bit\n";
	print SENDMAIL "\n";
	print SENDMAIL "$template";
	close(SENDMAIL);
}

# From行をエンコード
sub EncodeFrom {
	my($str, $from_addr) = @_;
	my $enc_str = &EncodeSubject($str);
	my @lines = split(/\n/, $enc_str);
	my $tmp = pop(@lines);
	if(length($tmp) + length($from_addr) + 3 > 75) {
		$enc_str .= "\n";
	}
	$enc_str .= " <${from_addr}>";
	return $enc_str;
}

sub ErrorPrint {
	my($msg) = @_;
	unless(-e $c{'ERROR_TEMP_FILE'}) {
		&ErrorPrint2("テンプレートファイル $c{'ERROR_TEMP_FILE'} がありません。: $!");
	}
###### kohinata

	unless(-e $c{'TEMP_HEADER_FILE'}) {
		&ErrorPrint2("テンプレートファイル $c{'TEMP_HEADER_FILE'} がありません。: $!");
	}
	unless(-e $c{'TEMP_FOOTER_FILE'}) {
		&ErrorPrint2("テンプレートファイル $c{'TEMP_FOOTER_FILE'} がありません。: $!");
	}

######


	my $size = -s $c{'ERROR_TEMP_FILE'};
	if(!open(FILE, "$c{'ERROR_TEMP_FILE'}")) {
		&ErrorPrint2("テンプレートファイル <tt>$c{'ERROR_TEMP_FILE'}</tt> をオープンできませんでした。 : $!");
		exit;
	}
	binmode(FILE);
	my $html;
	sysread(FILE, $html, $size);
	close(FILE);
###### kohinata
	my $size_h = -s $c{'TEMP_HEADER_FILE'};
	if(!open(FILE_h, "$c{'TEMP_HEADER_FILE'}")) {
		&ErrorPrint2("テンプレートファイル <tt>$c{'TEMP_HEADER_FILE'}</tt> をオープンできませんでした。 : $!");
		exit;
	}
	binmode(FILE_h);
	my $html_h;
	sysread(FILE_h, $html_h, $size_h);
	close(FILE_h);

	my $size_f = -s $c{'TEMP_FOOTER_FILE'};
	if(!open(FILE_f, "$c{'TEMP_FOOTER_FILE'}")) {
		&ErrorPrint2("テンプレートファイル <tt>$c{'TEMP_FOOTER_FILE'}</tt> をオープンできませんでした。 : $!");
		exit;
	}
	binmode(FILE_f);
	my $html_f;
	sysread(FILE_f, $html_f, $size_f);
	close(FILE_f);
######
	$html =~ s/\$ERROR\$/$msg/gi;
###### kohinata
	$html_h =~ s/\$ERROR\$/$msg/gi;
	$html_f =~ s/\$ERROR\$/$msg/gi;
######
	my $content_length = length($html);
###### kohinata
	    $content_length += length($html_h);
	    $content_length += length($html_f);
######
	print "Content-Length: $content_length\n";
	print "Content-Type: text/html; charset=Shift_JIS\n";
	print "\n";
	print $html_h; #kohinata
	print $html;
	print $html_f; #kohinata
	exit;
}

sub ErrorPrint2 {
	my($msg) = @_;
	my $content_length = length($msg);
	print "Content-Length: $content_length\n";
	print "Content-Type: text/plain; charset=Shift_JIS\n";
	print "\n";
	print $msg;
	exit;
}

# 現在のタイムスタンプを返す
sub GetDate {
	my($sec, $min, $hour, $mday, $mon, $year, $wday) = gmtime(time + 32400);
	$year += 1900;
	$mon += 1;
	$mon = sprintf("%02d", $mon);
	$mday = sprintf("%02d", $mday);
	$hour = sprintf("%02d", $hour);
	$min = sprintf("%02d", $min);
	$sec = sprintf("%02d", $sec);
	my @weekdays = ('日', '月', '火', '水', '木', '金', '土');
	my $disp_stamp = "$year年$mon月$mday日（$weekdays[$wday]） $hour:$min:$sec";
	my $stamp = $year.$mon.$mday.$hour.$min.$sec;
	return $stamp,$disp_stamp;
}

# シリアル番号を生成する
sub MakeSirial {
	my($stamp) = @_;
	my $sirial = "${stamp}-";
	my @IpAddr = split(/\./, $ENV{'REMOTE_ADDR'});
	for my $part (@IpAddr) {
		$part = sprintf("%03d", $part);
		$sirial .= $part;
	}
	return $sirial;
}

sub GetHostName {
	my($ip_address) = @_;
	my @addr = split(/\./, $ip_address);
	my $packed_addr = pack("C4", $addr[0], $addr[1], $addr[2], $addr[3]);
	my($name, $aliases, $addrtype, $length, @addrs);
	($name, $aliases, $addrtype, $length, @addrs) = gethostbyaddr($packed_addr, 2);
	return $name;
}

# 改行コードを \n に統一
sub UnifyReturnCode {
	my($string) = @_;
	$string =~ s/\x0D\x0A/\n/g;
	$string =~ s/\x0D/\n/g;
	$string =~ s/\x0A/\n/g;
	return $string;
}

# MIME Multipart用の境界を生成
sub GenerateBoundary {
	my($BodyString) = @_;
	my(@Lines) = split(/\n/, $BodyString);
	my($Boundary, $Buff, $i, $Line);
	my($Flag) = 1;
	while($Flag) {
		$Boundary = '';
		for ($i=0;$i<20;$i++) {
			if($i % 5 == 0 && $i != 0) {$Boundary .= '_';}
			srand;
			$Boundary .= substr($Base64Table, int(rand(60)), 1);
		}
		$Boundary .= '_'.time;
		$Flag = 0;
		for $Line (@Lines) {
			if($Line =~ /$Boundary/) {$Flag = 1; last;}
		}
	}
	return $Boundary;
}

#メールサブジェクトをBase64 Bエンコード
sub EncodeSubject {
	my($string) = @_;
	#もしASCII文字のみだった場合には、何も変換せずに返す
	unless($string =~ /[^\x20-\x7E]/) {
		return $string;
	}
	#半角カナを全角に変換
	$string = &kana_h2z_sjis($string);
	#以下、非ASCII文字が含まれていた場合の処理
	#Shif-JISの文字列を一文字ずつ分割し、配列に格納する
	my @chars = $string =~ /
		 [\x20-\x7E]             #ASCII文字
		|[\xA1-\xDF]             #半角カタカナ
		|[\x81-\x9F][\x40-\xFC]  #2バイト文字
		|[\xE0-\xEF][\x40-\xFC]  #2バイト文字
	/gox;
	#JISに変換しエンコードして76byte以内になるように、文字を分割
	#する。一文字ずつ加えて変換後のバイト数を見積もっていく。
	#ヘッダーの"Subject: ", "=?ISO-2022-JP?B?", "?="が無条件で必
	#要なため、その分を差し引いて、エンコード後のバイト数は、49
	#バイト以内でなければいけない。エンコードすると、サイズは4/3
	#に増えるので、逆算して、JISコードの文字で36バイト以内でなけ
	#ればいけない。しかし、パッディングを考慮すると、さらに、2バ
	#イト引いて、34バイト以内でなければいけない。
	my(@lines, $line, $jis_line);
	for my $char (@chars) {
		$line .= $char;
		$jis_line = $line;
		$jis_line = &CharCodeConvert("$jis_line", "jis", "sjis");
		if(length($jis_line) > 30) {
			push(@lines, $jis_line);
			$line = '';
			$jis_line = '';
		}
	}
	if(length($jis_line)) {
		push(@lines, $jis_line);
	}

	#行に分割したJISコードの文字を、それぞれBase64エンコードして
	#ヘッダーにする。
	for(my $i=0;$i<@lines;$i++) {
		my $encoded_word;
		$encoded_word .= "=?ISO-2022-JP?B?";
		$encoded_word .= MIME::Base64::Perl::encode_base64($lines[$i], "");
		$encoded_word .= "?=";
		$lines[$i] = $encoded_word;
	}
	#改行と半角スペースで結合
	my $header = join("\n ", @lines);
	#ヘッダーを返す
	return $header;
}

sub MailAddressCheck {
	my($mail) = @_;
	#チェック１（不適切な文字をチェック）
	if($mail =~ /[^a-zA-Z0-9\@\.\-\_]/) {
		return 0;
	}
	#チェック２（@マークのチェック）
	#"@"の数を数えます。一つ以外だった場合には、0を返します。
	my $at_num = 0;
	while($mail =~ /\@/g) {
		$at_num ++;
	}
	if($at_num != 1) {
		return 0;
	}
	#チェック３（アカウント、ドメインの存在をチェック）
	my($acnt, $domain) = split(/\@/, $mail);
	if($acnt eq '' || $domain eq '') {
		return 0;
	}
	#チェック４（ドメインのドットをチェック）
	#ドットの数を数えます。0個だった場合には、0を返します。
	my $dot_num = 0;
	while($domain =~ /\./g) {
		$dot_num ++;
	}
	if($dot_num == 0) {
		return 0;
	}
	#チェック５（ドメインの各パーツをチェック）
	#先頭にドットがないことをチェック
	if($domain =~ /^\./) {
		return 0;
	}
	#最後にドットがないことをチェック
	if($domain =~ /\.$/) {
		return 0;
	}
	#ドットが2つ以上続いていないかをチェック
	if($domain =~ /\.\./) {
		return 0;
	}
	#チェック６（TLDのチェック）
	my @domain_parts = split(/\./, $domain);
	my $tld = pop @domain_parts;
	if($tld =~ /[^a-zA-Z]/) {
		return 0;
	}
	#すべてのチェックが通ったので、このメールアドレスは適切である。
	return 1;
}

sub Lock {
	local(*FILE) = @_;
	eval{flock(FILE, 2)};
	if($@) {
		return $!;
	} else {
		return '';
	}
}

sub GetRemoteHost {
	my($remote_host);
	if($ENV{'REMOTE_HOST'} =~ /[^0-9\.]/) {
		$remote_host = $ENV{'REMOTE_HOST'};
	} else {
		my(@addr) = split(/\./, $ENV{'REMOTE_ADDR'});
		my($packed_addr) = pack("C4", $addr[0], $addr[1], $addr[2], $addr[3]);
		my($aliases, $addrtype, $length, @addrs);
		($remote_host, $aliases, $addrtype, $length, @addrs) = gethostbyaddr($packed_addr, 2);
		unless($remote_host) {
			$remote_host = $ENV{'REMOTE_ADDR'};
		}
	}
	return $remote_host;
}

sub ConfCheck {
	my($ref) = @_;
	unless($ref->{'MAILTO'}) {
		&ErrorPrint("メール送信先アドレスの設定をして下さい。: \$c{'MAILTO'}");
	}
	unless($ref->{'REDIRECT_URL'}) {
		&ErrorPrint("リダイレクト先URLの設定をして下さい。: \$c{'REDIRECT_URL'}");
	}
	if($ref->{'REPLY_FLAG'}) {
		unless($ref->{'FROM_ADDR_FOR_REPLY'}) {
			&ErrorPrint("自動返信メール設定がONの場合には、必ず「自動返信メール用送信元メールアドレス」を設定してください。 : \$c{'FROM_ADDR_FOR_REPLY'}");
		}
		unless($ref->{'SUBJECT_FOR_REPLY'}) {
			&ErrorPrint("自動返信メール設定がONの場合には、必ず「自動返信メール用サブジェクト」を設定してください。 : \$c{'SUBJECT_FOR_REPLY'}");
		}
	}
	if($ref->{'SENDMAIL'} ne '') {
		unless(-e $ref->{'SENDMAIL'}) {
			&ErrorPrint("sendmailに指定したパス $ref->{'SENDMAIL'} が間違っています。: \$c{'SENDMAIL'}");
		}
	}
}

sub ExternalRequestCheck {
	my $url;
	if(scalar @{$c{'ALLOW_FROM_URLS'}}) {
		my $flag = 0;
		for $url (@{$c{'ALLOW_FROM_URLS'}}) {
			if($ENV{'HTTP_REFERER'} =~ /^$url/) {
				$flag = 1;
			}
		}
		unless($flag) {
			&ErrorPrint("不正なサーバからのリクエストです。");
		}
	}
}

sub GetCgiUrl {
	my @url_parts = split(/\//, $ENV{'SCRIPT_NAME'});
	my $script_filename = pop @url_parts;
	return $script_filename;
}

sub RejectHostAccess {
	my($HostName) = @_;
	my($Reject);
	my $RejectFlag = 0;
	if(scalar @{$c{'REJECT_HOSTS'}}) {
		for $Reject (@{$c{'REJECT_HOSTS'}}) {
			if($Reject =~ /[^0-9\.]/) {	# ホスト名指定の場合
				if($HostName =~ /$Reject$/) {
					$RejectFlag = 1;
					last;
				}
			} else {	# IPアドレス指定の場合
				if($ENV{'REMOTE_ADDR'} =~ /^$Reject/) {
					$RejectFlag = 1;
					last;
				}
			}
		}
		if($RejectFlag) {
			&ErrorPrint($c{'REJECT_ERR_MSG'});
			exit;
		}
	}
}


sub WordWrap {
	my($string, $fold_len, $european_wordwrap_flag, $kinsoku_flag) = @_;
	#行頭禁則文字
	my @non_head_chars = ('、', '。', '，', '．', '・', '？', '！', '゛', '゜', 'ヽ', 'ヾ', 'ゝ', 'ゞ', '々', 'ー', '）', '］', '｝', '」', '』', '!', ')', ',', '.', ':', ';', '?', ']', '}', '｡', '｣', '､', '･', 'ｰ', 'ﾞ', 'ﾟ');
	#行末禁則文字
	my @non_end_chars = ('（', '［', '｛', '「', '『', '(', '[', '{', '｢');
	#欧文ワードラップフラグ
	#0:行わない、1:行う
	#my $european_wordwrap_flag = 1;

	my @wraped_lines;
	my @lines = split(/\n/, $string);
	for my $line (@lines) {
		if(length($line) <= $fold_len) {
			push(@wraped_lines, $line);
			next;
		}
		$_ = $line;
		my @words = /
			(?>[\x21-\x7E]+\x20)
			|(?>[\x21-\x7E]+)
			|(?>[\xA1-\xDF]+\x20)
			|(?>[\xA1-\xDF]+)
			|(?>(?>[\x81-\x9F][\x40-\xFC]|[\xE0-\xEF][\x40-\xFC])+\x20)
			|(?>(?>[\x81-\x9F][\x40-\xFC]|[\xE0-\xEF][\x40-\xFC])+)
			|(?>\x20+)
		/gox;

		my $wraped_line;
		my $wraped_line_len;
		for my $word (@words) {
			my $word_len = length($word);
			if($wraped_line_len + $word_len < $fold_len) {
				$wraped_line .= $word;
				$wraped_line_len += $word_len;
			} elsif($wraped_line_len + $word_len == $fold_len) {
				push(@wraped_lines, "${wraped_line}${word}");
				$wraped_line = '';
				$wraped_line_len = 0;
			} else {
				if($european_wordwrap_flag && $word !~ /[^\x20-\x7E]/ && $word_len < $fold_len) {
					push(@wraped_lines, "${wraped_line}");
					$wraped_line = $word;
					$wraped_line_len = $word_len;
				} else {
					$_ = $word;
					my @chars = /
						 [\x20-\x7E]             #ASCII文字
						|[\xA1-\xDF]             #半角カタカナ
						|[\x81-\x9F][\x40-\xFC]  #2バイト文字
						|[\xE0-\xEF][\x40-\xFC]  #2バイト文字
					/gox;
					for my $char (@chars) {
						if($kinsoku_flag && $wraped_line_len == 0 && grep(/^\Q$char\E$/, @non_head_chars)) {
							my $line_num = scalar @wraped_lines;
							$wraped_lines[$line_num - 1] .= $char;
							next;
						}
						my $char_len = length($char);
						if($wraped_line_len + $char_len < $fold_len) {
							$wraped_line .= $char;
							$wraped_line_len += $char_len;
						} elsif($wraped_line_len + $char_len == $fold_len) {
							if($kinsoku_flag && grep(/^\Q$char\E$/, @non_end_chars)) {
								push(@wraped_lines, "${wraped_line}");
								$wraped_line = $char;
								$wraped_line_len = $char_len;
							} else {
								push(@wraped_lines, "${wraped_line}${char}");
								$wraped_line = '';
								$wraped_line_len = 0;
							}
						} else {
							my($line_end_char) = $wraped_line =~ /(
								[\x21-\x7E]
								|[\xA1-\xDF]
								|[\x81-\x9F][\x40-\xFC]
								|[\xE0-\xEF][\x40-\xFC]
							)$/ox;
							if($kinsoku_flag && grep(/^\Q$char\E$/, @non_head_chars)) {
								push(@wraped_lines, "${wraped_line}${char}");
								$wraped_line = '';
								$wraped_line_len = 0;
							} elsif($kinsoku_flag && grep(/^\Q$line_end_char\E$/, @non_end_chars)) {
								$wraped_line =~ s/\Q${line_end_char}\E$//;
								push(@wraped_lines, "${wraped_line}");
								$wraped_line = "${line_end_char}${char}";
								$wraped_line_len = length($wraped_line);
							} else {
								push(@wraped_lines, "${wraped_line}");
								$wraped_line = $char;
								$wraped_line_len = $char_len;
							}
						}
					}
				}
			}
		}
		if($wraped_line ne '') {
			push(@wraped_lines, "${wraped_line}");
		}
	}
	my $wraped_string = join("\n", @wraped_lines);
	return $wraped_string;
}

sub SecureHtml {
	my($html) = @_;
	$html =~ s/\&amp;/\&/g;
	$html =~ s/\&/&amp;/g;
	$html =~ s/\"/&quot;/g;
	$html =~ s/</&lt;/g;
	$html =~ s/>/&gt;/g;
	return $html;
}


sub ReadTemplate {
	my($file) = @_;
	my $size = -s $file;
	if(!open(FILE, "$file")) {
		my $disp_file = &SecureHtml($file);
		&ErrorPrint("テンプレートファイル $disp_file をオープンできませんでした。: $!");
	}
	binmode(FILE);	# For Windows
	my $str;
	sysread(FILE, $str, $size);
	close(FILE);
	$str = &UnifyReturnCode($str);
	return $str;
}

sub GetCommandPath {
	my($command) = @_;
	my @pathes;
	if($command eq '') {return @pathes;}
	if($^O =~ /MSWin32/i) {
		return @pathes;
	}
	my @whereis_list = ('whereis', '/usr/bin/whereis', '/usr/ucb/whereis');
	for my $whereis (@whereis_list) {
		my $res = `$whereis $command`;
		if($res eq '') {
			next;
		} else {
			my @locations = split(/\s/, $res);
			for my $path (@locations) {
				if($path =~ /$command$/) {
					push(@pathes, $path);
				}
			}
			last;
		}
	}
	my $num = scalar @pathes;
	unless($num) {
		my $path = `which $command`;
		if($path =~ /$command$/) {
			push(@pathes, $path);
		}
	}
	return @pathes;
}

sub MakeSendmailPath {
	my $path;
	($path) = &GetCommandPath('sendmail');
	if($path eq '') {
		&ErrorPrint("sendmailのパスを自動取得できませんでした。設定ファイルに明示的に指定して下さい。");
	}
	return $path;
}

sub kana_h2z_sjis {
	my($str) = @_;
	if($UJ) {
		$str = Unicode::Japanese->new($str, "sjis")->h2zKana->conv("sjis");
	} else {
		my $j = Jcode->new();
		$j->set($str, 'sjis');
		$str = $j->h2z->sjis;
	}
	return $str;
}

sub CharCodeConvert {
	my($str, $to, $from) = @_;
	if($UJ) {
		$str = Unicode::Japanese->new($str, $from)->conv($to);
	} else {
		$str =~ s/\xef\xbd\x9e/\xe3\x80\x9c/g;	#～を変換
		$str =~ s/\xef\xbc\x8d/\xe2\x88\x92/g;	#－を変換
		&Jcode::convert(\$str, $to, $from);
	}
	return $str;
}
