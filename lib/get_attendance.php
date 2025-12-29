<?php
// filepath: C:\xampp\htdocs\skonnect-api\get_attendance.php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST");
header("Access-Control-Allow-Headers: Content-Type");
header('Content-Type: application/json');
$servername = "localhost";
$username = "root";
$password = "";
$dbname = "skonnect";
$conn = new mysqli($servername, $username, $password, $dbname);
if ($conn->connect_error) {
    http_response_code(500);
    echo json_encode(["error" => "Database connection failed"]);
    exit();
}

$event_title = isset($_GET['event_title']) ? $conn->real_escape_string($_GET['event_title']) : '';
if ($event_title === '') {
    http_response_code(400);
    echo json_encode(["error" => "Missing event_title"]);
    exit();
}

// Get event_id from title
$result = $conn->query("SELECT id FROM events WHERE title='$event_title' LIMIT 1");
if (!$result || !$result->num_rows) {
    http_response_code(404);
    echo json_encode(["error" => "Event not found"]);
    exit();
}
$row = $result->fetch_assoc();
$event_id = $row['id'];

// Get attendance records
$attendance = [];
$res = $conn->query("SELECT id, user_id, full_name, event_id FROM attendance WHERE event_id='$event_id'");
while ($row = $res->fetch_assoc()) {
    $attendance[] = $row;
}
echo json_encode($attendance);
$conn->close();
?>