<?php
/**
 * @package Welcart
 * @subpackage Welcart_Basic
 */

$division = welcart_basic_get_item_division( $post->ID );
switch( $division ) :
case 'data':
	get_template_part( 'wc_templates/wc_item_single_data', get_post_format() );
	break;
case 'service':
	get_template_part( 'wc_templates/wc_item_single_service', get_post_format() );
	break;
default://shipped

//2017.05.24 kohinata tileタグ変更
ob_start();
$header = get_header();
$head_title = usces_the_itemName('return');
$head = ob_get_contents();
$head = preg_replace("/<title>.*<\/title>/","<title>".$head_title." | kirsche</title>",$head);
ob_end_clean();
echo $head;
?>
<h1 class="logo"><a href="/kirsche"><img src="/kirsche/wp-content/themes/welcart_basic/images/logo.png"></a></h1>
<div id="primary" class="site-content">
	<div id="content" role="main">

	<?php if( have_posts() ) : the_post(); ?>

		<article <?php post_class(); ?> id="post-<?php the_ID(); ?>">

			<header class="item-header">
			</header><!-- .item-header -->

			<div class="storycontent">

			<?php usces_remove_filter(); ?>
			<?php usces_the_item(); ?>
			<?php usces_have_skus(); ?>

				<div id="itempage">

					<div id="img-box">

						<div class="itemimg">
							<a href="<?php usces_the_itemImageURL(0); ?>" <?php echo apply_filters( 'usces_itemimg_anchor_rel', NULL ); ?>><?php usces_the_itemImage( 0, 335, 335, $post ); ?></a>
						</div>

						<?php
						$imageid = usces_get_itemSubImageNums();
						if( !empty( $imageid ) ):
						?>
						<div class="itemsubimg">
						<?php foreach( $imageid as $id ) : ?>
							<a href="<?php usces_the_itemImageURL($id); ?>" <?php echo apply_filters( 'usces_itemimg_anchor_rel', NULL ); ?>><?php usces_the_itemImage( $id, 135, 135, $post ); ?></a>
						<?php endforeach; ?>
						</div>
						<?php endif; ?>

					</div><!-- #img-box -->

					<div class="detail-box">
						<h3 class="item-name red"><?php usces_the_itemName(); ?></h3>
						<p class="red"><?php the_title(); ?></p>
						<?php welcart_basic_campaign_message(); ?>
						<div class="item-description">
							<?php the_content(); ?>
						</div>

						<?php if( 'continue' == welcart_basic_get_item_chargingtype( $post->ID ) ) : ?>
						<!-- Charging Type Continue shipped -->
						<div class="field">
							<table class="dlseller">
								<tr><th><?php _e('First Withdrawal Date', 'dlseller'); ?></th><td><?php echo dlseller_first_charging( $post->ID ); ?></td></tr>
								<?php if( 0 < (int)$usces_item['dlseller_interval'] ) : ?>
								<tr><th><?php _e('Contract Period', 'dlseller'); ?></th><td><?php echo $usces_item['dlseller_interval']; ?><?php _e('month (Automatic Updates)', 'welcart_basic'); ?></td></tr>
								<?php endif; ?>
							</table>
						</div>
						<?php endif; ?>

					<div class="item-info">

						<?php if( $item_custom = usces_get_item_custom( $post->ID, 'list', 'return' ) ) : ?>
							<?php echo $item_custom; ?>
						<?php endif; ?>

						<form action="<?php echo USCES_CART_URL; ?>" method="post">

						<?php do { ?>
							<div class="skuform">
								<?php if(0){ if( '' !== usces_the_itemSkuDisp('return') ) : ?>
								<div class="skuname"><?php usces_the_itemSkuDisp(); ?></div>
								<?php endif; }?>

								<?php if( usces_is_options() ) : ?>
								<dl class="item-option">
									<?php while( usces_have_options() ) : ?>
									<dt><?php usces_the_itemOptName(); ?></dt>
									<dd><?php usces_the_itemOption( usces_getItemOptName(), '' ); ?></dd>
									<?php endwhile; ?>
								</dl>
								<?php endif; ?>

								<?php usces_the_itemGpExp(); ?>

								<div class="field">
<?
if(0){
?>
									<div class="zaikostatus"><?php _e('stock status', 'usces'); ?> : <?php usces_the_itemZaikoStatus(); ?></div>
<?
}
?>

									<?php if( 'continue' == welcart_basic_get_item_chargingtype( $post->ID ) ) : ?>
									<div class="frequency"><span class="field_frequency"><?php dlseller_frequency_name($post->ID, 'amount'); ?></span></div>
									<?php endif; ?>

									<div class="field_price red">
									<?php if( usces_the_itemCprice('return') > 0 ) : ?>
										<span class="field_cprice"><?php usces_the_itemCpriceCr(); ?></span>
									<?php endif; ?>
										<?php usces_the_itemPriceCr(); ?> JPY
									</div>
								</div>

								<?php if( !usces_have_zaiko() ) : ?>
								<div class="itemsoldout red"><?php echo apply_filters( 'usces_filters_single_sku_zaiko_message', __('At present we cannot deal with this product.','') ); ?></div>
								<?php else : ?>
								<div class="c-box">
<?
if(0){
?>
									<span class="quantity red"><?php _e('QTY', 'usces'); ?><?php usces_the_itemQuant(); ?><?php usces_the_itemSkuUnit(); ?></span>
<?
}
?>
									<span class="cart-button"><?php usces_the_itemSkuButton( __('Add to cart', 'usces' ), 0 ); ?></span>
								</div>
								<?php endif; ?>
								<div class="error_message"><?php usces_singleitem_error_message( $post->ID, usces_the_itemSku('return') ); ?></div>
							</div><!-- .skuform -->
						<?php } while ( usces_have_skus() ); ?>

							<?php do_action( 'usces_action_single_item_inform' ); ?>
						</form>
						<?php do_action( 'usces_action_single_item_outform' ); ?>

					</div><!-- .item-info -->


					</div><!-- .detail-box -->


					<?php usces_assistance_item( $post->ID, __('An article concerned', 'usces') ); ?>

				</div><!-- #itemspage -->
			</div><!-- .storycontent -->

		</article>

	<?php else: ?>
		<p><?php _e('Sorry, no posts matched your criteria.'); ?></p>
	<?php endif; ?>

	</div><!-- #content -->
</div><!-- #primary -->

<!-- #how 'bout this -->
<h2>how 'bout this</h2>	
<div id="primary2" class="site-content">
<div id="content2" role="main">

<?
//2017.05.22 kohinata
$cat = get_the_category();
$cat = $cat[0];
$cat_id = $cat->cat_ID;
query_posts('posts_per_page=3&cat='.$cat_id.'&post_status=publish'); 
?>
<?php if ( 'page' == get_option('show_on_front') ): ?>
	<div class="sof">
	<?php if (have_posts()) : the_post(); ?>
	<article <?php post_class() ?> id="post-<?php the_ID(); ?>">
		<h2 class="entry-title"><?php the_title(); ?></h2>
		<div class="entry-content">
		<?php the_content(); ?>
		</div>
	</article>
	<?php else: ?>
	<p><?php _e('Sorry, no posts matched your criteria.'); ?></p>
	<?php endif; ?>
	</div><!-- .sof -->
	<?php else: ?>
	<section class="front-il cf">
	<?php if( have_posts() ) : ?>
	<?php while( have_posts() ) : the_post(); usces_the_item(); ?>
	<article id="post-<?php the_ID(); ?>" <?php post_class(); ?>>
	<div class="itemimg">
		<a href="<?php the_permalink(); ?>"><?php usces_the_itemImage( 0, 300, 300 ); ?></a>
		<?php welcart_basic_campaign_message(); ?>
	</div>
	<?php if( !usces_have_zaiko_anyone() ) : ?>
	<div class="itemsoldout red"><?php _e('Sold Out', '' ); ?></div>
	<?php endif; ?>
	<div class="itemname"><a href="<?php the_permalink(); ?>"  rel="bookmark" class="red"><?php usces_the_itemName(); ?></a></div>
	<div class="itemprice red"><?php usces_crform( usces_the_firstPrice('return'), false, false ); ?> JPY</div>
	</article>
	<?php endwhile; ?>
	<?php else: ?>
	<p class="no-date"><?php _e('Sorry, no posts matched your criteria.'); ?></p>
	<?php endif; ?>
	</section><!-- .front-il -->
	<?php endif; ?>
</div><!-- #content2 -->
</div><!-- #primary2 -->
<!-- #how 'bout this -->

<div class="button"><a href="/kirsche"><button>Shop</button></a></div>

<?php get_footer(); ?>

<?php endswitch; ?>
