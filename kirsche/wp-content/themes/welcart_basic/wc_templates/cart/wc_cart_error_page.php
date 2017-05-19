<?php
/**
 * @package Welcart
 * @subpackage Welcart_Basic
 */

get_header();
?>
<div id="primary" class="site-content">
	<div id="content" class="cart-page" role="main">

	<?php if( have_posts() ) : usces_remove_filter(); ?>

		<article class="post" id="wc_<?php usces_page_name(); ?>">

			<h1 class="cart_page_title"><?php _e('An unidentified error has occurred.'); ?></h1>

			<div id="error-page">

				<h2><?php _e('ERROR:'); ?></h2>
				<div class="post">
					<p><?php _e('Your order has not been completed', 'usces'); ?></p>
					<p>(error <?php esc_html_e( urldecode($_REQUEST['acting_return']) ); ?>)</p>
					<?php uesces_get_error_settlement(); ?>
				</div><!-- .post -->

			</div><!-- #error-page -->

		</article><!-- .post -->

	<?php else: ?>
		<p><?php _e('Sorry, no posts matched your criteria.'); ?></p>
	<?php endif; ?>

	</div><!-- #content -->
</div><!-- #primary -->

<?php get_footer(); ?>
