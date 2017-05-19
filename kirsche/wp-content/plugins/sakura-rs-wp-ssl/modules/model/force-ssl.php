<?php
/**
 * Sakura htaccess generate class
 *
 * @package Sakura_Ssl
 * @author wokamoto <wokamoto@digitalcube.jp>
 *         hideokamoto <hide.okamoto@digitalcube.jp>
 **/

if ( ! defined( 'ABSPATH' ) ) {
	exit; // Exit if accessed directly.
}

/**
 * Update htaccess class
 *
 * @class Force_ssl_sakura
 **/
class Force_ssl_sakura {
	const HTACCESS_MARKER = 'Force SSL for SAKURA';
	const HTACCESS_REWRITE_RULE = array(
		'# RewriteしてもHTTPS環境変数を有効にする',
		'SetEnvIf REDIRECT_HTTPS (.*) HTTPS=$1',
		'',
		'# 常時HTTPS化(HTTPSが無効な場合リダイレクト)',
		'<IfModule mod_rewrite.c>',
		'RewriteEngine on',
		'RewriteCond %{ENV:HTTPS} !on',
		'RewriteCond %{REQUEST_URI} !^/wp-cron.php$',
		'RewriteRule .* https://%{HTTP_HOST}%{REQUEST_URI} [R=301,L]',
		'</IfModule>',
		);
	const HTACCESS_REWRITE_RULE_NO_SNI = array(
		'# 常時HTTPS化(HTTPSが無効な場合リダイレクト)',
		'<IfModule mod_rewrite.c>',
		'RewriteEngine on',
		'RewriteCond %{HTTPS} !on',
		'RewriteRule .* https://%{HTTP_HOST}%{REQUEST_URI} [R=301,L]',
		'</IfModule>',
		);

	/**
	 * Get htaccess file path
	 *
	 * @access private
	 * @return string|boolean htaccess file path
	 * @since 0.1.0
	 **/
	private function htaccess_file() {
		$home_path = get_home_path();
		$htaccess_file = $home_path . '.htaccess';
		if ( ( ! file_exists( $htaccess_file ) && is_writable( $home_path ) ) || is_writable( $htaccess_file ) ) {
			return $htaccess_file;
		} else {
			return new WP_Error( 'Sakura SSL update Error', '.htaccessの書き込み権限がありません。書き込み権限を設定してから再度実行してください。' );
		}
	}

	/**
	 * Remove force ssl setting into .htaccess
	 *
	 * @access public
	 * @param string $htaccess_file .htaccess file path.
	 * @param string $ssl_type ssl type.
	 * @since 0.1.0
	 **/
	public function insert_htaccess_rule( $htaccess_file, $ssl_type ) {
		switch ( $ssl_type ) {
			case 'no_sni':
				$htaccess_template = self::HTACCESS_REWRITE_RULE_NO_SNI;
				break;

			case 'sni':
				$htaccess_template = self::HTACCESS_REWRITE_RULE;
				break;

			default:
				return new WP_Error( 'Sakura SSL type Error', "Type:{$ssl_type} is invalid type." );
				break;
		}
		return insert_with_markers( $htaccess_file, self::HTACCESS_MARKER, $htaccess_template );
	}

	/**
	 * Remove force ssl setting into .htaccess
	 *
	 * @access private
	 * @param string $htaccess_file .htaccess file path.
	 * @return boolean result
	 * @since 0.1.0
	 **/
	private function _remove_htaccess_rule( $htaccess_file ) {
		$result = false;
		if ( $htaccess_rewrite_rules = extract_from_markers( $htaccess_file, self::HTACCESS_MARKER ) ) {
			$start_marker = '# BEGIN ' . self::HTACCESS_MARKER;
			$end_marker   = '# END ' . self::HTACCESS_MARKER;
			$htaccess_rewrite_rule =
				$start_marker . "\n" .
				implode( "\n", $htaccess_rewrite_rules ) . "\n" .
				$end_marker;
			if ( $fp = fopen( $htaccess_file, 'r+' ) ) {
				flock( $fp, LOCK_EX );
				$lines = array();
				while ( ! feof( $fp ) ) {
					$lines[] = rtrim( fgets( $fp ), "\r\n" );
				}
				$org_file_date = implode( "\n", $lines );
				$new_file_data = str_replace( $htaccess_rewrite_rule, '', $org_file_date );
				if ( $new_file_data !== $org_file_date ) {
					fseek( $fp, 0 );
					if ( $bytes = fwrite( $fp, trim( $new_file_data ) ) ) {
						ftruncate( $fp, ftell( $fp ) );
					}
					fflush( $fp );
					$result = (bool) $bytes;
				}
				flock( $fp, LOCK_UN );
				fclose( $fp );
			}
		}
		return $result;
	}

	/**
	 * Update WordPress settings
	 *
	 * @access public
	 * @param string $ssl_type ssl type.
	 * @since 0.1.0
	 **/
	public function activate( $ssl_type ) {
		$htaccess_file = $this->htaccess_file();
		if ( is_wp_error( $htaccess_file ) ) {
			return $htaccess_file;
		}
		if ( ! got_mod_rewrite() ) {
			return new WP_Error( 'Sakura SSL update Error', '.htaccessの書き込み権限がありません。書き込み権限を設定してから再度実行してください。');
		}
		$this->insert_htaccess_rule( $htaccess_file, $ssl_type );
		update_option( Sakura_Base::SAKURA_FORCE_SSL, true );
		$login_url = wp_login_url();
		$pattern = '%http://%';
		$replacement = 'https://';
		$login_url = preg_replace( $pattern, $replacement, $login_url );
		wp_safe_redirect( $login_url );
		wp_logout();
		return true;
	}

	/**
	 * Replace WordPress settings
	 *
	 * @access public
	 * @since 0.1.0
	 **/
	public function unforce_ssl() {
		$htaccess_file = $this->htaccess_file();
		if ( $htaccess_file ) {
			$this->_remove_htaccess_rule( $htaccess_file );
			delete_option( Sakura_Base::SAKURA_FORCE_SSL );
			wp_logout();
		}
	}

	/**
	 * Replace http schema as https
	 *
	 * @param string $content WordPress content.
	 * @return string
	 * @since 0.1.0
	 * @access public
	 **/
	public function replace_urls( $content ) {
		$options = get_option( Sakura_Base::SAKURA_FORCE_SSL );
		if ( ! $options ) {
			return $content;
		}
		if ( empty( $content ) ) {
			return $content;
		}
		$home_url = set_url_scheme( get_home_url(), 'http' );
		$pattern = "%{$home_url}%";
		$replacement = set_url_scheme( $home_url, 'https' );
		$content = preg_replace( $pattern, $replacement, $content );
		return $content;
	}

	/**
	 * Replace home url
	 *
	 * @access public
	 * @since 0.1.0
	 * @param string $url Url.
	 * @return string
	 **/
	public function replace_home_url( $url ) {
		return set_url_scheme( $url, 'https' );
	}

	/**
	 * Replace home url
	 *
	 * @access public
	 * @since 0.1.0
	 **/
	public function replace_options() {
		$options = get_option( Sakura_Base::SAKURA_FORCE_SSL );
		if ( ! $options ) {
			return;
		}
		$options = array(
			'siteurl',
			'home',
		);
		foreach ( $options as $option ) {
			add_filter( "option_{$option}", array( $this, 'replace_home_url' ) );
		}
	}

	/**
	 * Replace link by Link Filters
	 * https://codex.wordpress.org/Plugin_API/Filter_Reference#Link_Filters
	 *
	 * @access public
	 * @since 0.1.0
	 **/
	public function replace_link_hooks() {
		$options = get_option( Sakura_Base::SAKURA_FORCE_SSL );
		if ( ! $options ) {
			return;
		}
		$hooks = array(
			'attachment_link',
			'author_feed_link',
			'author_link',
			'comment_reply_link',
			'day_link',
			'feed_link',
			'get_comment_author_link',
			'get_comment_author_url_link',
			'month_link',
			'page_link',
			'post_link',
			'post_type_link',
			'the_permalink',
			'year_link',
			'tag_link',
			'term_link',
			'bloginfo_url',
			'lostpassword_url',
			'wp_get_attachment_url',
			'wp_get_attachment_thumb_url',
			'wp_nav_menu',
			'the_excerpt',
			'the_content',
			'login_url',
			'logout_url',
			'register_url',
			'admin_url',
		);
		foreach ( $hooks as $hook ) {
			add_filter( $hook, array( $this, 'replace_urls' ) );
		}
	}
}
