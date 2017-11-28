$(document).ready(function(){
  //color background
  $('.bg-c').spectrum();
  $(window).load(function(){
    //scrollbar
    $('.description').mCustomScrollbar({
     advanced:{updateOnContentResize: true},
     theme: "dark-thin"
    });
  });
});

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
