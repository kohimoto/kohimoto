$(document).ready(function(){
  //color background
  $('.bg-c').spectrum();
  $(window).load(function(){
    //scrollbar
    $('.description').mCustomScrollbar({
     advanced:{updateOnContentResize: true},
     theme: "dark-thin"
    });
    //slider
    $('.flexslider').flexslider();
  });
});
