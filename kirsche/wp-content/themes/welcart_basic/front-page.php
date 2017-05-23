<?php get_header(); ?>
	<h2>More about the shop</h2>	
	<div class="button"><button>About us</button></div>
	<h2>Take a look!</h2>	

	<div id="primary" class="site-content">
		<div id="content" role="main">
		
		<?
		//2017.05.22 kohinata
		query_posts('posts_per_page=-1&cat=2&post_status=publish'); 
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
							<div class="itemsoldout"><?php _e('Sold Out', 'usces' ); ?></div>
							<?php endif; ?>
							<div class="itemname"><a href="<?php the_permalink(); ?>"  rel="bookmark"><?php usces_the_itemName(); ?></a></div>
							<div class="itemprice"><?php usces_crform( usces_the_firstPrice('return'), true, false ); ?><?php usces_guid_tax(); ?></div>
						
						</article>
					
					<?php endwhile; ?>
					
				<?php else: ?>
					
					<p class="no-date"><?php _e('Sorry, no posts matched your criteria.'); ?></p>
				
				<?php endif; ?>
			
			</section><!-- .front-il -->

		<?php endif; ?>
				
		</div><!-- #content -->
	</div><!-- #primary -->


<?php get_sidebar('home'); ?>
<?php get_footer(); ?>
