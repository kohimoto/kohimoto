$('body').removeClass('menu-show');
Barba.Dispatcher.on("newPageReady", function(current, prev, container, raw){
    switch(current.namespace)
  {
    case "slider":
alert("hey!!");
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
      $('.flexslider').flexslider();

      //-----open nav--------//
      //if menu_show is ,after moved slider remove.
      $('body').removeClass('menu-show');

      $('.js-fullheight').css('height', $(window).height());
      $(window).resize(function(){
      	$('.js-fullheight').css('height', $(window).height());
      });
      $('.js-fh5co-nav-toggle').on('click', function(event) {
alert("start");
        if( $('body').hasClass('menu-show') ) {
alert("i have!");
          $('body').removeClass('menu-show');
alert("11");
        } else {
alert("don't have!");
	  $('body').addClass('menu-show');
alert("22");
            setTimeout(function(){
              $('#fh5co-main-nav > .js-fh5co-nav-toggle').addClass('show');
            }, 900);
        }
      });



      break;

  }
});
