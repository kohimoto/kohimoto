$(function() {
  var h = $(window).height();

  $('#loader-bg ,#loader').height(h).css('display','block');
});

$(window).load(function () { //全ての読み込みが完了したら実行
  setTimeout(function(){
    $('#loader-bg').delay(900).fadeOut(800);
    $('#loader').delay(600).fadeOut(300);
  },1000);
});

//10秒たったら強制的にロード画面を非表示
$(function(){
  setTimeout('stopload()',10000);
});

function stopload(){
  $('#loader-bg').delay(900).fadeOut(800);
  $('#loader').delay(600).fadeOut(300);
}

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
