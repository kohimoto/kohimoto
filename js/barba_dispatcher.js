Barba.Dispatcher.on("newPageReady", function(current, prev, container, raw){
    switch(current.namespace)
  {
    case "slider":
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


      break;

  }
});
