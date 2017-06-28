$(document).ready(function(){
  $('.bg-c').spectrum();
  $(window).load(function(){
    $('.description').mCustomScrollbar({
     advanced:{updateOnContentResize: true},
     theme: "dark-thin"
    });
    $('.flexslider').flexslider();
  });
});
