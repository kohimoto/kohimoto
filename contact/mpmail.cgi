#!/usr/bin/perl
##############################################################################
# MP Form Mail CGI Standard�� Ver5.0.1
# �iCGI�{�́j
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
# X-Mailer�̎w��
my $X_MAILER = "MP Form Mail CGI Standard Ver${VERSION} (http://www.futomi.com/)";

#Unicode::Japanese�̓���`�F�b�N
my $UJ = 1;
if($] < 5.006) {
	$UJ = 0;
} else {
	eval {require Unicode::Japanese;};
	if($@) {$UJ = 0;}
}

# �ݒ�t�@�C���ǂݍ���
require './conf/config.cgi';
my %c = &config::get;

# mpconfig.cgi�̐ݒ���e�̃`�F�b�N
&ConfCheck(\%c);

# �O���T�[�o����̗��p�֎~
&ExternalRequestCheck;

# Base64�G���R�[�h�e�[�u��
my $Base64Table = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.
	           'abcdefghijklmnopqrstuvwxyz'.
	           '0123456789+/';

# �w��z�X�g����̃A�N�Z�X�����O����
my $host_name = &GetHostName($ENV{'REMOTE_ADDR'});
&RejectHostAccess($host_name);

# sendmail�̃p�X���擾����
if($c{'SENDMAIL'} eq '') {
	$c{'SENDMAIL'} = &MakeSendmailPath;
}
# �t�H�[���f�[�^���擾,���M���[���{�������A�m�F��ʗpHIDDEN�^�O����
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
		#�T�C�Y����
		unless($key eq 'attachment') {
			if($c{'MAX_INPUT_CHAR'} && length($value) > $c{'MAX_INPUT_CHAR'}) {
				&ErrorPrint("���͕����́A���p��$c{'MAX_INPUT_CHAR'}�����܂łł��B");
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
# �^�C���X�^���v�p�̓�����������擾
# $Stamp: ���O�o�͗p
# $SendDate: ���M���[���p
my($stamp, $send_date) = &GetDate;
$values{'DATE'} = $send_date;
$values{'USERAGENT'} = $ENV{'HTTP_USER_AGENT'};
$values{'REMOTE_ADDR'} = $ENV{'REMOTE_ADDR'};
$values{'REMOTE_HOST'} = $host_name;

# �V���A���ԍ��𐶐�
if($c{'SIRIAL_FLAG'}) {
	my $sirial = &MakeSirial($stamp);
	$values{'sirial'} = $sirial;
	$values{'SIRIAL'} = $sirial;
}

#Safari�̕����������`�F�b�N
if($ENV{'HTTP_USER_AGENT'} =~ /Safari/) {
	&SafariEncodeMistakeCheck(\%values);
}

# �K�{���ڂ��I���������͓��͂���Ă��邩�̃`�F�b�N
&NecessaryCheck(\%values, $c{'NECESSARY_NAMES'});

# name�������umailaddress�v�̂��̂����݂��Ȃ���΁A�����ԐM�̃t���O��OFF�ɂ���B
unless($values{'mailaddress'}) {
	$c{'REPLY_FLAG'} = 0;
}

# �t�H�[�����ɁAname�������umailaddress�v�̂��̂�����΁A
# ���M�����[���A�h���X��D��I�ɐݒ肷��B
my $from_flag = 0;
if($values{'mailaddress'} ne '') {
	$c{'FROM'} = $values{'mailaddress'};
	$from_flag = 1;
}

# �t�H�[�����ɁAname�������usubject�v�̂��̂�����΁A
# ���M�����[���T�u�W�F�N�g��D��I�ɐݒ肷��B
if($values{'subject'} ne '') {
	$c{'SUBJECT'} = $values{'subject'};
}

# �Y�t�t�@�C�������݂���� 1 ���Z�b�g�����
my $attach_flag = 0;
if($values{'attachment'} ne '') {
	$attach_flag = 1;
}

# �Y�t�t�@�C��������΁A�t�@�C�����𒊏o���A
# �e���|�����[�t�@�C���𐶐�����B
my($attach_content_type, $attache_file_name, $attach_file);
if($attach_flag) {
	my $full_file_name = $q->param('attachment');
	$attach_content_type = $q->uploadInfo($full_file_name)->{'Content-Type'};
	my $full_file_name_euc = $full_file_name;		# \ �ŋ�؂肽�����ASJIS�ł͂��܂������Ȃ����߁AEUC�ɕϊ����Ă��� \ �ŕ�������B
	$full_file_name_euc = &CharCodeConvert("$full_file_name_euc", "euc", "sjis");
	my @path_parts = split(/\\/, $full_file_name_euc);
	$attache_file_name = pop(@path_parts);
	$attache_file_name = &CharCodeConvert("$attache_file_name", "sjis", "euc");
	# �g���q�`�F�b�N
	if(scalar @{$c{'EXT_RESTRICT'}}) {
		my @parts = split(/\./, $attache_file_name);
		my $ext = pop(@parts);
		unless(grep(/^$ext$/i, @{$c{'EXT_RESTRICT'}})) {
			&ErrorPrint("�w��̃t�@�C���𑗐M���邱�Ƃ͂ł��܂���B");
		}
	}
	$c{'ATTACHMENT_DIR'} =~ s/\/$//;
	$attach_file = "$c{'ATTACHMENT_DIR'}/${attache_file_name}";
	open(OUTFILE, ">$attach_file") || &ErrorPrint("�Y�t�t�@�C���̃e���|�����[�t�@�C��\[${attach_file}\]�̍쐬�Ɏ��s���܂����B:$!");
	my($bytesread, $buffer);
	while($bytesread=read($full_file_name, $buffer, 1024)) {
		print OUTFILE $buffer;
	}
	close(OUTFILE);
	# �Y�t�t�@�C���T�C�Y�̃`�F�b�N
	my $attach_file_size = -s $attach_file;
	if($attach_file_size > $c{'ATTACHMENT_MAX_SIZE'}) {
		unlink($attach_file);
		&ErrorPrint("$c{'ATTACHMENT_MAX_SIZE'}�o�C�g�ȏ�̃t�@�C���͓Y�t�ł��܂���B");
	}
}

#�m�F��ʕ\��
if($c{'CONFIRM_FLAG'} && $attach_flag == 0 && ! $mp_status) {
	&PrintConfirm($c{'NAMES'}, \%values, \@hiddens);
	exit;
}

# �t�H�[���f�[�^�����O�ɏo��
if($c{'LOGING_FLAG'}) {
	&Loging($c{'NAMES'}, \%values, $stamp);
}

#���[�����M
&MailSend($c{'NAMES'}, \%values, $attach_flag, $attach_file, $attach_content_type);

# �ԐM���[���𑗐M
if($c{'REPLY_FLAG'} && $from_flag) {
	&Reply($c{'NAMES'}, \%values);
}

# �Y�t�t�@�C�����폜����
if($attach_flag && $c{'ATTACHMENT_DEL_FLAG'}) {
	unlink($attach_file);
}

# ���_�C���N�g
&Redirect;

exit;

######################################################################
# �T�u���[�`��
######################################################################

sub SafariEncodeMistakeCheck {
	#?��3�ȏ�A���������ڂ�2���ڈȏ゠�����ꍇ�ɁASafari�����������ۂƂ݂Ȃ��B
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
		&ErrorPrint("�����p�̃u���E�U�[�iSafari�j���瑗�M���ꂽ�f�[�^�́A�����������N�����Ă��܂��B���͉�ʂɖ߂�A�ēǂݍ��݂�������A�ēx�A���͂��ĉ������B");
	}
}

# �K�{���ڂ��I���������͓��͂���Ă��邩�̃`�F�b�N
sub NecessaryCheck {
	my($values_ref, $necessary_names_ref) = @_;
	my @null_names = ();
	for my $name (@$necessary_names_ref) {
		if($values_ref->{$name} eq '') {
			push(@null_names, $name);
		}
	}
	if(@null_names) {
		my $error = '�ȉ��̍��ڂ͕K�{�ł��B<ul>';
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
	#���[���A�h���X�`�F�b�N
	if($values_ref->{'mailaddress'} ne '') {
		unless(&MailAddressCheck($values_ref->{'mailaddress'})) {
			my $disp_name = $c{'NAME_MAP'}->{'mailaddress'};
			if($disp_name eq '') {
				$disp_name = 'mailaddress';
			}
			&ErrorPrint("${disp_name}������������܂���B");
		}
	}
}

sub SpritSjisChars {
	my($string) = @_;
	$_ = $string;
	my @chars = /
		 [\x20-\x7E]             #ASCII����
		|[\xA1-\xDF]             #���p�J�^�J�i
		|[\x81-\x9F][\x40-\xFC]  #2�o�C�g����
		|[\xE0-\xEF][\x40-\xFC]  #2�o�C�g����
	/gox;
	return @chars;
}

sub Redirect {
	if($c{'REDIRECT_METHOD'}) {
		my $html;
		$html .= "<html><head><title>${X_MAILER}</title>\n";
		$html .= "<META HTTP-EQUIV=\"Refresh\" CONTENT=\"0; URL=$c{'REDIRECT_URL'}\">\n";
		$html .= "</head><body>\n";
		$html .= "���܂��]������Ȃ��ꍇ�́A<a href=\"$c{'REDIRECT_URL'}\">������</a>���N���b�N���ĉ������B";
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

# �m�F��ʂ�\������
sub PrintConfirm {
	my($names_ref, $values_ref, $hiddens_ref) = @_;
	# ����CGI��URL����肷��B
	my $cgiurl;
	if($c{'MANUAL_CGIURL'} =~ /^http/) {
		$cgiurl = $c{'MANUAL_CGIURL'};
	} else {
		$cgiurl = &GetCgiUrl;
	}
	#Hidden�^�O����̃X�J���[�ϐ��Ɋi�[����B
	my $hidden = join("\n", @$hiddens_ref);
	#�m�F��ʃe���v���[�g��ǂݎ��
        #kohinata costom
	my $html = &ReadTemplate($c{'TEMP_HEADER_FILE'});
	   $html .= &ReadTemplate($c{'CONFIRM_TEMP_FILE'});
	   $html .= &ReadTemplate($c{'TEMP_FOOTER_FILE'});
	#my $html = &ReadTemplate($c{'CONFIRM_TEMP_FILE'});
	#hidden�^�O��u��
	if($html =~ /\$hidden\$/) {
		$html =~ s/\$hidden\$/$hidden/;
	} else {
		&ErrorPrint("�m�F��ʗp�e���v���[�gHTML�t�@�C�� $c{'CONFIRM_TEMP_FILE'} �ɁA\$hidden\$ ���L�ڂ���Ă���܂���B");
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

# ���[���𑗐M����
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
	# ���b�Z�[�W�����[�h���b�v����
	if($c{'WRAP'} >= 50) {
		$body = &WordWrap($body, $c{'WRAP'}, 1, 1);
	}
	# ���b�Z�[�W��JIS�ɕϊ�
	$body = &CharCodeConvert("$body", "jis", "sjis");
	my($boundary, $base64data);
	if($attach_flag) {
		# ���E���`
		$boundary = &GenerateBoundary($body);
		#�Y�t�t�@�C����Base64�G���R�[�h����
		my $file_size = -s "$attach_file";
		my $file_data;
		open(FILE, "$attach_file") || &ErrorPrint("�Y�t�t�@�C���̃e���|�����[�t�@�C�����I�[�v���o���܂���ł����B: $!");
		sysread FILE, $file_data, $file_size;
		close(FILE);
		$base64data = MIME::Base64::Perl::encode_base64($file_data);
	}
	# �T�u�W�F�N�g���ɁA�t�H�[�����͒l�ϊ��w���q������Εϊ�����B
	for my $key (keys %$values_ref) {
		$c{'SUBJECT'} =~ s/\$$key\$/$values_ref->{$key}/g;
	}
	# ���[���^�C�g����Base64 B�G���R�[�h
	$c{'SUBJECT'} = &EncodeSubject($c{'SUBJECT'});

	# ���[�����M
	my $sendmail_opt = ' -t';
	if($c{'SENDMAIL_OPT_oi'}) {
		$sendmail_opt .= ' -oi';
	}
	if($c{'SENDMAIL_OPT_f'}) {
		$sendmail_opt .= " -f'$c{'FROM'}'";
	}
	open(SENDMAIL, "|$c{'SENDMAIL'}${sendmail_opt}") || &ErrorPrint("���[�����M�Ɏ��s���܂��� : $!");
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
		$body = "�y�V���A���ԍ��z\n";
		$body .= "$values_ref->{'sirial'}\n\n";
	}
	for my $name (@$names_ref) {
		if($c{'NAME_MAP'}->{$name}) {
			$body .= "�y$c{'NAME_MAP'}->{$name}�z\n";
		} else {
			$body .= "�y$name�z\n";
		}
		$body .= "$values_ref->{$name}\n";
		$body .= "\n";

	}
	$body .= "\n";
	# ���M�ҏ������[���{���ɒǉ�
	my $host_name = &GetHostName($ENV{'REMOTE_ADDR'});

	$body .= "�y���M�ҏ��z\n";
	$body .= "  �E�u���E�U�[      : $values_ref->{'USERAGENT'}\n";
	$body .= "  �E���M��IP�A�h���X: $values_ref->{'REMOTE_ADDR'}\n";
	$body .= "  �E���M���z�X�g��  : $values_ref->{'REMOTE_HOST'}\n";
	$body .= "  �E���M����        : $values_ref->{'DATE'}\n";

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


# �t�H�[���f�[�^�����O�ɏo��
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
			$value =~ s/ /�@/g;;	#���p�X�y�[�X��S�p�X�y�[�X�ɕϊ�
		} elsif($c{'DELIMITER'} == 3) {
			$value =~ s/\t//g;
		} else {
			$value =~ s/,/�C/g;	#���p�J���}��S�p�J���}�ɕϊ�
		}
		$part .= "$value";
		$part = &UnifyReturnCode($part);	#���s�R�[�h���u\n�v�ɓ��ꂷ��
		$part =~ s/\n/<br>/g;				#���s�R�[�h��<br>�ɕϊ�����
		push(@log_parts, $part);
	}
	#��؂蕶�����`
	my $delimiter_char;
	if($c{'DELIMITER'} == 2) {
		$delimiter_char = ' ';
	} elsif($c{'DELIMITER'} == 3) {
		$delimiter_char = "\t";
	} else {
		$delimiter_char = ",";
	}
	#���O�̍s�𐶐�
	my $log_line = join("$delimiter_char", @log_parts);
	#���O�t�@�C�����I�[�v�����A���b�N����
	open(LOGFILE, ">>$c{'LOGFILE'}") || &ErrorPrint("���O�t�@�C�� $c{'LOGFILE'} �������I�[�v���ł��܂���ł����B�F $!");
	if(my $lock_result = &Lock(*LOGFILE)) {
		&ErrorPrint("�����A���ݍ����Ă���܂��B���΂炭���Ă��炨�������������B: $lock_result");;
	}
	#�s�����O�ɏo��
	print LOGFILE "$log_line\n";
	close(LOGFILE);
}


# �ԐM���[���𑗐M����
sub Reply {
	my($names_ref, $values_ref) = @_;
	# �e���v���[�g�t�@�C���̕������ $template�Ɋi�[����
	my $template = &ReadTemplate($c{'REPLY_TEMP_FILE'});
	# �����ϊ�
	for my $key (@$names_ref) {
		$template =~ s/\$$key\$/$values_ref->{$key}/g;
	}

	$template =~ s/\$USERAGENT\$/$values_ref->{'USERAGENT'}/g;
	$template =~ s/\$REMOTE_ADDR\$/$values_ref->{'REMOTE_ADDR'}/g;
	$template =~ s/\$REMOTE_HOST\$/$values_ref->{'REMOTE_HOST'}/g;
	$template =~ s/\$DATE\$/$values_ref->{'DATE'}/g;
	$template =~ s/\$SIRIAL\$/$values_ref->{'SIRIAL'}/ig;

	# ���b�Z�[�W�̉��s�R�[�h�𓝈ꂷ��
	$template = &UnifyReturnCode($template);

	# ���b�Z�[�W�����[�h���b�v����
	if($c{'WRAP'} >= 50) {
		$template = &WordWrap($template, $c{'WRAP'}, 1, 1);
	}
	# ���[�����M�̂��߂ɁA���b�Z�[�W��JIS�ɕϊ�
	$template = &CharCodeConvert("$template", "jis", "sjis");
	# �T�u�W�F�N�g���ɁA�t�H�[�����͒l�ϊ��w���q������Εϊ�����B
	for my $key (keys %$values_ref) {
		$c{'SUBJECT_FOR_REPLY'} =~ s/\$$key\$/$values_ref->{$key}/g;
	}
	# �T�u�W�F�N�g��Base64 B�G���R�[�h
	$c{'SUBJECT_FOR_REPLY'} = &EncodeSubject($c{'SUBJECT_FOR_REPLY'});
	# From�s���G���R�[�h
	my $from_line = $c{'FROM_ADDR_FOR_REPLY'};
	if($c{'SENDER_NAME_FOR_REPLY'}) {
		$from_line = &EncodeFrom($c{'SENDER_NAME_FOR_REPLY'}, $c{'FROM_ADDR_FOR_REPLY'});
	}
	# �ԐM���[�����M
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
	open(SENDMAIL, "|$c{'SENDMAIL'}${sendmail_opt}") || &ErrorPrint("�����ԐM���[���𑗐M�ł��܂���ł����B: $!");
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

# From�s���G���R�[�h
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
		&ErrorPrint2("�e���v���[�g�t�@�C�� $c{'ERROR_TEMP_FILE'} ������܂���B: $!");
	}
###### kohinata

	unless(-e $c{'TEMP_HEADER_FILE'}) {
		&ErrorPrint2("�e���v���[�g�t�@�C�� $c{'TEMP_HEADER_FILE'} ������܂���B: $!");
	}
	unless(-e $c{'TEMP_FOOTER_FILE'}) {
		&ErrorPrint2("�e���v���[�g�t�@�C�� $c{'TEMP_FOOTER_FILE'} ������܂���B: $!");
	}

######


	my $size = -s $c{'ERROR_TEMP_FILE'};
	if(!open(FILE, "$c{'ERROR_TEMP_FILE'}")) {
		&ErrorPrint2("�e���v���[�g�t�@�C�� <tt>$c{'ERROR_TEMP_FILE'}</tt> ���I�[�v���ł��܂���ł����B : $!");
		exit;
	}
	binmode(FILE);
	my $html;
	sysread(FILE, $html, $size);
	close(FILE);
###### kohinata
	my $size_h = -s $c{'TEMP_HEADER_FILE'};
	if(!open(FILE_h, "$c{'TEMP_HEADER_FILE'}")) {
		&ErrorPrint2("�e���v���[�g�t�@�C�� <tt>$c{'TEMP_HEADER_FILE'}</tt> ���I�[�v���ł��܂���ł����B : $!");
		exit;
	}
	binmode(FILE_h);
	my $html_h;
	sysread(FILE_h, $html_h, $size_h);
	close(FILE_h);

	my $size_f = -s $c{'TEMP_FOOTER_FILE'};
	if(!open(FILE_f, "$c{'TEMP_FOOTER_FILE'}")) {
		&ErrorPrint2("�e���v���[�g�t�@�C�� <tt>$c{'TEMP_FOOTER_FILE'}</tt> ���I�[�v���ł��܂���ł����B : $!");
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

# ���݂̃^�C���X�^���v��Ԃ�
sub GetDate {
	my($sec, $min, $hour, $mday, $mon, $year, $wday) = gmtime(time + 32400);
	$year += 1900;
	$mon += 1;
	$mon = sprintf("%02d", $mon);
	$mday = sprintf("%02d", $mday);
	$hour = sprintf("%02d", $hour);
	$min = sprintf("%02d", $min);
	$sec = sprintf("%02d", $sec);
	my @weekdays = ('��', '��', '��', '��', '��', '��', '�y');
	my $disp_stamp = "$year�N$mon��$mday���i$weekdays[$wday]�j $hour:$min:$sec";
	my $stamp = $year.$mon.$mday.$hour.$min.$sec;
	return $stamp,$disp_stamp;
}

# �V���A���ԍ��𐶐�����
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

# ���s�R�[�h�� \n �ɓ���
sub UnifyReturnCode {
	my($string) = @_;
	$string =~ s/\x0D\x0A/\n/g;
	$string =~ s/\x0D/\n/g;
	$string =~ s/\x0A/\n/g;
	return $string;
}

# MIME Multipart�p�̋��E�𐶐�
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

#���[���T�u�W�F�N�g��Base64 B�G���R�[�h
sub EncodeSubject {
	my($string) = @_;
	#����ASCII�����݂̂������ꍇ�ɂ́A�����ϊ������ɕԂ�
	unless($string =~ /[^\x20-\x7E]/) {
		return $string;
	}
	#���p�J�i��S�p�ɕϊ�
	$string = &kana_h2z_sjis($string);
	#�ȉ��A��ASCII�������܂܂�Ă����ꍇ�̏���
	#Shif-JIS�̕�������ꕶ�����������A�z��Ɋi�[����
	my @chars = $string =~ /
		 [\x20-\x7E]             #ASCII����
		|[\xA1-\xDF]             #���p�J�^�J�i
		|[\x81-\x9F][\x40-\xFC]  #2�o�C�g����
		|[\xE0-\xEF][\x40-\xFC]  #2�o�C�g����
	/gox;
	#JIS�ɕϊ����G���R�[�h����76byte�ȓ��ɂȂ�悤�ɁA�����𕪊�
	#����B�ꕶ���������ĕϊ���̃o�C�g�������ς����Ă����B
	#�w�b�_�[��"Subject: ", "=?ISO-2022-JP?B?", "?="���������ŕK
	#�v�Ȃ��߁A���̕������������āA�G���R�[�h��̃o�C�g���́A49
	#�o�C�g�ȓ��łȂ���΂����Ȃ��B�G���R�[�h����ƁA�T�C�Y��4/3
	#�ɑ�����̂ŁA�t�Z���āAJIS�R�[�h�̕�����36�o�C�g�ȓ��łȂ�
	#��΂����Ȃ��B�������A�p�b�f�B���O���l������ƁA����ɁA2�o
	#�C�g�����āA34�o�C�g�ȓ��łȂ���΂����Ȃ��B
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

	#�s�ɕ�������JIS�R�[�h�̕������A���ꂼ��Base64�G���R�[�h����
	#�w�b�_�[�ɂ���B
	for(my $i=0;$i<@lines;$i++) {
		my $encoded_word;
		$encoded_word .= "=?ISO-2022-JP?B?";
		$encoded_word .= MIME::Base64::Perl::encode_base64($lines[$i], "");
		$encoded_word .= "?=";
		$lines[$i] = $encoded_word;
	}
	#���s�Ɣ��p�X�y�[�X�Ō���
	my $header = join("\n ", @lines);
	#�w�b�_�[��Ԃ�
	return $header;
}

sub MailAddressCheck {
	my($mail) = @_;
	#�`�F�b�N�P�i�s�K�؂ȕ������`�F�b�N�j
	if($mail =~ /[^a-zA-Z0-9\@\.\-\_]/) {
		return 0;
	}
	#�`�F�b�N�Q�i@�}�[�N�̃`�F�b�N�j
	#"@"�̐��𐔂��܂��B��ȊO�������ꍇ�ɂ́A0��Ԃ��܂��B
	my $at_num = 0;
	while($mail =~ /\@/g) {
		$at_num ++;
	}
	if($at_num != 1) {
		return 0;
	}
	#�`�F�b�N�R�i�A�J�E���g�A�h���C���̑��݂��`�F�b�N�j
	my($acnt, $domain) = split(/\@/, $mail);
	if($acnt eq '' || $domain eq '') {
		return 0;
	}
	#�`�F�b�N�S�i�h���C���̃h�b�g���`�F�b�N�j
	#�h�b�g�̐��𐔂��܂��B0�������ꍇ�ɂ́A0��Ԃ��܂��B
	my $dot_num = 0;
	while($domain =~ /\./g) {
		$dot_num ++;
	}
	if($dot_num == 0) {
		return 0;
	}
	#�`�F�b�N�T�i�h���C���̊e�p�[�c���`�F�b�N�j
	#�擪�Ƀh�b�g���Ȃ����Ƃ��`�F�b�N
	if($domain =~ /^\./) {
		return 0;
	}
	#�Ō�Ƀh�b�g���Ȃ����Ƃ��`�F�b�N
	if($domain =~ /\.$/) {
		return 0;
	}
	#�h�b�g��2�ȏ㑱���Ă��Ȃ������`�F�b�N
	if($domain =~ /\.\./) {
		return 0;
	}
	#�`�F�b�N�U�iTLD�̃`�F�b�N�j
	my @domain_parts = split(/\./, $domain);
	my $tld = pop @domain_parts;
	if($tld =~ /[^a-zA-Z]/) {
		return 0;
	}
	#���ׂẴ`�F�b�N���ʂ����̂ŁA���̃��[���A�h���X�͓K�؂ł���B
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
		&ErrorPrint("���[�����M��A�h���X�̐ݒ�����ĉ������B: \$c{'MAILTO'}");
	}
	unless($ref->{'REDIRECT_URL'}) {
		&ErrorPrint("���_�C���N�g��URL�̐ݒ�����ĉ������B: \$c{'REDIRECT_URL'}");
	}
	if($ref->{'REPLY_FLAG'}) {
		unless($ref->{'FROM_ADDR_FOR_REPLY'}) {
			&ErrorPrint("�����ԐM���[���ݒ肪ON�̏ꍇ�ɂ́A�K���u�����ԐM���[���p���M�����[���A�h���X�v��ݒ肵�Ă��������B : \$c{'FROM_ADDR_FOR_REPLY'}");
		}
		unless($ref->{'SUBJECT_FOR_REPLY'}) {
			&ErrorPrint("�����ԐM���[���ݒ肪ON�̏ꍇ�ɂ́A�K���u�����ԐM���[���p�T�u�W�F�N�g�v��ݒ肵�Ă��������B : \$c{'SUBJECT_FOR_REPLY'}");
		}
	}
	if($ref->{'SENDMAIL'} ne '') {
		unless(-e $ref->{'SENDMAIL'}) {
			&ErrorPrint("sendmail�Ɏw�肵���p�X $ref->{'SENDMAIL'} ���Ԉ���Ă��܂��B: \$c{'SENDMAIL'}");
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
			&ErrorPrint("�s���ȃT�[�o����̃��N�G�X�g�ł��B");
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
			if($Reject =~ /[^0-9\.]/) {	# �z�X�g���w��̏ꍇ
				if($HostName =~ /$Reject$/) {
					$RejectFlag = 1;
					last;
				}
			} else {	# IP�A�h���X�w��̏ꍇ
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
	#�s���֑�����
	my @non_head_chars = ('�A', '�B', '�C', '�D', '�E', '�H', '�I', '�J', '�K', '�R', '�S', '�T', '�U', '�X', '�[', '�j', '�n', '�p', '�v', '�x', '!', ')', ',', '.', ':', ';', '?', ']', '}', '�', '�', '�', '�', '�', '�', '�');
	#�s���֑�����
	my @non_end_chars = ('�i', '�m', '�o', '�u', '�w', '(', '[', '{', '�');
	#�������[�h���b�v�t���O
	#0:�s��Ȃ��A1:�s��
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
						 [\x20-\x7E]             #ASCII����
						|[\xA1-\xDF]             #���p�J�^�J�i
						|[\x81-\x9F][\x40-\xFC]  #2�o�C�g����
						|[\xE0-\xEF][\x40-\xFC]  #2�o�C�g����
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
		&ErrorPrint("�e���v���[�g�t�@�C�� $disp_file ���I�[�v���ł��܂���ł����B: $!");
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
		&ErrorPrint("sendmail�̃p�X�������擾�ł��܂���ł����B�ݒ�t�@�C���ɖ����I�Ɏw�肵�ĉ������B");
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
		$str =~ s/\xef\xbd\x9e/\xe3\x80\x9c/g;	#�`��ϊ�
		$str =~ s/\xef\xbc\x8d/\xe2\x88\x92/g;	#�|��ϊ�
		&Jcode::convert(\$str, $to, $from);
	}
	return $str;
}
