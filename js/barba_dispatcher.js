Barba.Dispatcher.on("newPageReady", function(current, prev, container, raw){
    switch(current.namespace)
  {
    case "slider":
      //-----open nav--------//
      //if menu_show is ,after moved slider remove.
      $('body').removeClass('menu-show');

      $('.js-fullheight').css('height', $(window).height());
      $(window).resize(function(){
      	$('.js-fullheight').css('height', $(window).height());
      });
      $('.open').click(function() {
        if( $('body').hasClass('menu-show') ) {
        } else {
	        $('body').addClass('menu-show');
          $('#fh5co-main-nav > .js-fh5co-nav-toggle').addClass('show');
        }
      });
      $('.close').click(function() {
        if( $('body').hasClass('menu-show') ) {
          $('body').removeClass('menu-show');
        } else {
        }
      });
      //-----hover top--------//
      $('.works_d > img').hover(
        function(){
        //on
          $(this).stop().animate({opacity: 1},1000);
          $(this).css('width', '100%');
          $(this).css('height', '100%');
        },
        function(){
        //outs
          $(this).stop().animate({opacity: 0.5},1000);
        }
      );
      //-----hover foot--------//
      $('.works_foot_img').hover(
        function(){
        //on
        $(this).stop().animate({opacity: 0.4},1000);
        },
        function(){
        //out
        $(this).stop().animate({opacity: 0},1000);
        }
      );

      //-----slick--------//
      $('.slick-slider').slick({
      slidesToShow: 3,
      arrows: false,
      dots: true,
      autoplay: true,
        responsive: [ //レスポンシブの設定
        {
          breakpoint: 480, //ブレークポイント1の値
          settings: { //480px以下では1画像表示
            slidesToShow: 1
          }
        }]
      });

      //-----animated------//
      // Animations
    	var contentWayPoint = function() {
      var i = 0;
    		$('.animate-box').waypoint( function( direction ) {
    			if( direction === 'down' && !$(this.element).hasClass('animated') ) {
    				i++;
    				$(this.element).addClass('item-animate');
    				setTimeout(function(){
    					$('body .animate-box.item-animate').each(function(k){
    						var el = $(this);
    						setTimeout( function () {
    							var effect = el.data('animate-effect');
    							if ( effect === 'fadeIn') {
    								el.addClass('fadeIn animated');
    							} else {
    								el.addClass('fadeInUp animated');
    							}
    							el.removeClass('item-animate');
    						},  k * 600, 'easeInOutExpo' );
    					});
    				}, 600);
    			}
    		} , { offset: '85%' } );
    	};

      //-----scrollbar--------//
      //$('.description').mCustomScrollbar({
      // advanced:{updateOnContentResize: true},
      // theme: "dark-thin"
      //});
      break;
      }
      });
