<?php
/**
 * @package Welcart
 * @subpackage Welcart_Basic
 */

get_header();
?>
<h1 class="logo"><a href="/kirsche"><img src="/kirsche/wp-content/themes/welcart_basic/images/logo.png"></a></h1>
<div id="primary" class="site-content">
	<div id="content" class="cart-page" role="main">

	<?php if( have_posts() ) : usces_remove_filter(); ?>

		<article class="post" id="wc_<?php usces_page_name(); ?>">

			<h2 class="cart_page_title">Cart<br> Check please!</h2>

			<div class="cart_navi">
				<ul>
					<li class="current"><?php _e('Cart',''); ?></li>
					<li><?php _e('Customer Info',''); ?></li>
					<li><?php _e('Deli. & Pay.',''); ?></li>
					<li><?php _e('Confirm',''); ?></li>
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
							<th scope="row" class="num">No.</th>
							<th class="thumbnail"> </th>
							<th class="productname"><?php _e('Name',''); ?></th>
							<th class="unitprice"><?php _e('Unit price',''); ?></th>
							<th class="quantity"><?php _e('Quantity',''); ?></th>
							<th class="subtotal"><?php _e('Price',''); ?></th>
							<th class="stock"><?php _e('Stock status',''); ?></th>
							<th class="action"></th>
						</tr>
						</thead>
						<tbody>
							<?php usces_get_cart_rows(); ?>
						</tbody>
						<tfoot>
						<tr>
							<th class="num"></th>
							<th class="thumbnail"></th>
							<th colspan="3" scope="row" class="aright"><?php _e('Total',''); ?></th>
							<th class="aright amount"><?php usces_crform(usces_total_price('return'), true, false); ?></th>
							<th class="stock"></th>
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
