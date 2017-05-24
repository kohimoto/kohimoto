<?php
/**
 * @package Welcart
 * @subpackage Welcart_Basic
 */

//2017.05.24 kohinata tileタグ変更
ob_start();
$header = get_header();
$head_title = "Cart Check please!";
$head = ob_get_contents();
$head = preg_replace("/<title>.*<\/title>/","<title>".$head_title." | kirsche</title>",$head);
ob_end_clean();
echo $head;
?>
<h1 class="logo"><a href="/kirsche"><img src="/kirsche/wp-content/themes/welcart_basic/images/logo.png"></a></h1>
<div id="primary" class="site-content">
	<div id="content" class="cart-page" role="main">

	<?php if( have_posts() ) : usces_remove_filter(); ?>

		<article class="post" id="wc_<?php usces_page_name(); ?>">

			<h2>Cart<br> Check please!</h2>

			<div class="cart_navi">
				<ul>
					<li class="current red"><?php _e('Cart',''); ?></li>
					<li class="red"><?php _e('Customer Info',''); ?></li>
					<li class="red"><?php _e('Deli. & Pay.',''); ?></li>
					<li class="red"><?php _e('Confirm',''); ?></li>
				</ul>
			</div>

			<div class="header_explanation">
				<?php do_action( 'usces_action_cart_page_header' ); ?>
			</div><!-- .header_explanation -->

			<div class="error_message"><?php usces_error_message(); ?></div>

			<form action="<?php usces_url('cart'); ?>" method="post" onKeyDown="if(event.keyCode == 13){return false;}">
			<?php if( usces_is_cart() ) : ?>
				<div id="cart">
					<div class="upbutton"><?php _e('Press the `update` button when you change the amount of items.','usces'); ?><button name="upButton" class="s_button" type="submit" value="Change" onclick="return uscesCart.upCart()" />Change</button></div>
					<table cellspacing="0" id="cart_table">
						<thead>
						<tr>
							<th class="thumbnail">Images</th>
							<th class="productname"><?php _e('Name',''); ?></th>
							<th class="quantity"><?php _e('Quantity',''); ?></th>
							<th class="subtotal"><?php _e('Price',''); ?></th>
							<th class="action"></th>
						</tr>
						</thead>
						<tbody>
							<?php usces_get_cart_rows(); ?>
						</tbody>
						<tfoot>
						<tr>
							<th class="thumbnail"></th>
							<th colspan="2" scope="row" class="aright red"><?php _e('Total',''); ?></th>
							<th class="aright amount red"><?php usces_crform(usces_total_price('return'), false, false); ?> JPY</th>
							<th class="action"></th>
						</tr>
						</tfoot>
					</table>
<?
if(0){
?>
					<div class="currency_code"><?php _e('Currency','usces'); ?> : <?php usces_crcode(); ?></div>
<?
}
?>
					<?php if( $usces_gp ) : ?>
					<div class="gp"><img src="<?php bloginfo('template_directory'); ?>/images/gp.gif" alt="<?php _e('Business package discount','usces'); ?>" /><span><?php _e('The price with this mark applys to Business pack discount.','usces'); ?></span></div>
					<?php endif; ?>
				</div><!-- #cart -->
			<?php else : ?>
				<div class="no_cart"><?php _e('There are no items in your cart.',''); ?></div>
			<?php endif; ?>

				<div class="send"><?php usces_get_cart_button(); ?></div>
				<?php do_action( 'usces_action_cart_page_inform' ); ?>
			</form>

			<div class="footer_explanation">
				<?php do_action( 'usces_action_cart_page_footer' ); ?>
			</div><!-- .footer_explanation -->

		</article><!-- .post -->

	<?php else: ?>
		<p><?php _e('Sorry, no posts matched your criteria.'); ?></p>
	<?php endif; ?>

	</div><!-- #content -->
</div><!-- #primary -->

<?php get_footer(); ?>
