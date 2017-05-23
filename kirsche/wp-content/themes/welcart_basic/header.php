<?php
/**
 * @package Welcart
 * @subpackage Welcart_Basic
 */
?>
<!DOCTYPE html>
<html <?php language_attributes(); ?>>

<head>
	<meta charset="<?php bloginfo( 'charset' ); ?>" />
	<meta name="viewport" content="width=device-width, user-scalable=no">
	<meta name="format-detection" content="telephone=no"/>

	<?php wp_head(); ?>
</head>

<body <?php body_class(); ?>>

	<header id="masthead" class="site-header" role="banner">
		
		<div class="inner cf">

			<?php $heading_tag = ( is_home() || is_front_page() ) ? 'h1' : 'div'; ?>
			<<?php echo $heading_tag; ?> class="site-title"><a href="<?php echo esc_url( home_url( '/' ) ); ?>" title="<?php echo esc_attr( get_bloginfo( 'name', 'display' ) ); ?>" rel="home"><?php bloginfo( 'name' ); ?></a></<?php echo $heading_tag; ?>>

			<?php if(! welcart_basic_is_cart_page()): ?>
			
			<div class="snav cf">

				<div class="incart-btn">
					<a href="<?php echo USCES_CART_URL; ?>"><i class="fa fa-shopping-cart"><span><?php _e('In the cart', 'usces') ?></span></i><?php if(! defined( 'WCEX_WIDGET_CART' ) ): ?><span class="total-quant"><?php usces_totalquantity_in_cart(); ?></span><?php endif; ?></a>
				</div>
			</div><!-- .snav -->

			<?php endif; ?>
			
		</div><!-- .inner -->

		

	</header><!-- #masthead -->

	<?php if( ( is_front_page() || is_home() ) && get_header_image() ): ?>
	<div class="main-image">
		<img src="<?php header_image(); ?>" width="<?php echo get_custom_header()->width; ?>" height="<?php echo get_custom_header()->height; ?>" alt="<?php bloginfo('name'); ?>">
	</div><!-- main-image -->
	<?php endif; ?>
	
	<?php 
		if( is_front_page() || is_home() || welcart_basic_is_cart_page() || welcart_basic_is_member_page() ) {
			$class = 'one-column';	
		}else {
			$class = 'two-column right-set';
		};
	?>
	
	<div id="main" class="wrapper <?php echo $class;?>">
