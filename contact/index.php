<?
header("Content-Type: text/html;charset=Shift_JIS");
$head_c = file_get_contents("../header.html");
$head = preg_replace("/<title>.*<\/title>/","<title>KOHIMOTO | CONTACT</title>",$head_c);
echo $head;
$data= file_get_contents('./form.html'); // シフトJISファイル読み込み
echo $data; // 文字化けが起きない
include_once("../footer.html");
?>
