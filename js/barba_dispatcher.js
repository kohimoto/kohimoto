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
        //out
          $(this).stop().animate({opacity: 0},1000);
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

      //-----hover background--------//
      $('.description').mCustomScrollbar({
       advanced:{updateOnContentResize: true},
       theme: "dark-thin"
      });

      //-----hover slider--------//
      $(window).load(function(){
        $('.flexslider').flexslider();
      });

      break;

  }
});
