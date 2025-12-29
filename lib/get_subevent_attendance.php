<?php
<?php
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

$subevent_id = isset($_GET['subevent_id']) ? $conn->real_escape_string($_GET['subevent_id']) : '';
if (!$subevent_id) {
    http_response_code(400);
    echo json_encode(["error" => "Missing subevent_id"]);
    exit();
}

// Get attendance records for this subevent
$sql = "SELECT sa.id, sa.user_id, sa.full_name, sa.subevent_id, sa.attended_at 
        FROM subevent_attendance sa
        WHERE sa.subevent_id = ?
        ORDER BY sa.attended_at DESC";

$stmt = $conn->prepare($sql);
$stmt->bind_param("s", $subevent_id);
$stmt->execute();
$result = $stmt->get_result();

$attendance = [];
while ($row = $result->fetch_assoc()) {
    $attendance[] = $row;
}

echo json_encode($attendance);

$stmt->close();
$conn->close();
?>