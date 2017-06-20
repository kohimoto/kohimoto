<?
header("Content-Type: text/html;charset=Shift_JIS");
$data= file_get_contents('./form.html'); // シフトJISファイル読み込み
//$str = mb_convert_encoding($data,"utf-8","sjis"); // シフトJISからUTF-8に変換
echo $data; // 文字化けが起きない

?>
