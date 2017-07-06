$(function() {

  $('.bg_top').css('display','none');
  $('.list').css('display','none');
  $('footer').css('display','none');
  var h = $(window).height();
 
  $('#loader-bg ,#loader').height(h).css('display','block');
});
 
$(window).load(function () { //全ての読み込みが完了したら実行
  setTimeout(function(){
    $('#loader-bg').delay(900).fadeOut(800);
    $('#loader').delay(600).fadeOut(300);
  },1000);
  $('.bg_top').css('display','block');
  $('.list').css('display','block');
  $('footer').css('display','block');
});
 
//10秒たったら強制的にロード画面を非表示
$(function(){
  setTimeout('stopload()',10000);
});
 
function stopload(){
  $('#loader-bg').delay(900).fadeOut(800);
  $('#loader').delay(600).fadeOut(300);
}
