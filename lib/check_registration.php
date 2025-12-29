<?php
header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST");
header("Access-Control-Allow-Headers: Content-Type");
require 'db.php';

$event_id = isset($_GET['event_id']) ? $_GET['event_id'] : '';
$user_id = isset($_GET['user_id']) ? $_GET['user_id'] : '';

if (!$event_id || !$user_id) {
    echo json_encode(['registered' => false, 'error' => 'Missing parameters']);
    exit;
}

// First get the user's email using user_id
$stmt = $conn->prepare("SELECT email FROM youth_users WHERE id = ?");
$stmt->bind_param("s", $user_id);
$stmt->execute();
$result = $stmt->get_result();
$user = $result->fetch_assoc();
$stmt->close();

if (!$user || !isset($user['email'])) {
    echo json_encode(['registered' => false, 'error' => 'User not found']);
    exit;
}

$user_email = $user['email'];

// Then check if user has any form responses for this event
$stmt = $conn->prepare("SELECT DISTINCT event_id FROM event_form_responses WHERE event_id = ? AND user_email = ? LIMIT 1");
$stmt->bind_param("ss", $event_id, $user_email);
$stmt->execute();
$result = $stmt->get_result();

$is_registered = $result->num_rows > 0;
echo json_encode(['registered' => $is_registered]);

$stmt->close();
$conn->close();
?>