<?php
header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST");
header("Access-Control-Allow-Headers: Content-Type");
require 'db.php'; // should set $conn (mysqli)

// Expect GET: ?subevent_id=...&user_id=...
$subevent_id = isset($_GET['subevent_id']) ? $_GET['subevent_id'] : '';
$user_id = isset($_GET['user_id']) ? $_GET['user_id'] : '';

if (!$subevent_id || !$user_id) {
    echo json_encode(['registered' => false, 'error' => 'Missing parameters']);
    exit;
}

$stmt = $conn->prepare("SELECT id FROM subevent_registrations WHERE subevent_id = ? AND user_id = ?");
if (!$stmt) {
    echo json_encode(['registered' => false, 'error' => 'Prepare failed']);
    exit;
}
$stmt->bind_param("ss", $subevent_id, $user_id);
$stmt->execute();
$stmt->store_result();

$registered = $stmt->num_rows > 0;
echo json_encode(['registered' => $registered]);

$stmt->close();
$conn->close();
?>