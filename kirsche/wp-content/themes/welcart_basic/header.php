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
	<link rel="stylesheet" type="text/css" href="/kirsche/wp-content/themes/welcart_basic/custom.css" media="all">
</head>

<body <?php body_class(); ?>>

	<header id="masthead" class="site-header" role="banner">
		
		<div class="inner cf">

			<?php $heading_tag = ( is_home() || is_front_page() ) ? 'h1' : 'div'; ?>

		<nav id="nav" role="navigation">
		<a href="#" class="nav-toggle nav-toggle active"><i></i></a>
		<div class="table">
		<div class="table-cell">
		<ul>
		<li><a href="#">TOP</a></li>
		<li><a href="#">ABOUT US</a></li>
		<li><a href="#">CONTACT</a></li>
		<li><a href="#">NOTES</a></li>
		</ul>
		</div>
		</div>
		</nav>
		<div class="head_nav">
			<a href="#" class="nav-toggle o-nav-toggle"><i></i></a>
		</div>
			<?php if(! welcart_basic_is_cart_page()): ?>
			
			<div class="snav cf">

				<div class="incart-btn">
					<a href="<?php echo USCES_CART_URL; ?>"><i class="fa fa-shopping-cart"></i><?php if(! defined( 'WCEX_WIDGET_CART' ) ): ?><span class="total-quant"><?php usces_totalquantity_in_cart(); ?></span><?php endif; ?></a>
				</div>
			</div><!-- .snav -->

			<?php endif; ?>
			
		</div><!-- .inner -->
		<div class="message_left message"><a>papyrus</a></div>
		<div class="message_right message"><a>Goods day!</a></div>
		

	</header><!-- #masthead -->

	<?php if( ( is_front_page() || is_home() ) && get_header_image() ): ?>
	<h1 class="logo"><a href="/kirsche"><img src="/kirsche/wp-content/themes/welcart_basic/images/logo.png"></a></h1>
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
