<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST");
header("Access-Control-Allow-Headers: Content-Type");
header('Content-Type: application/json');
require 'db.php'; // should set $conn (mysqli)

// Read JSON body
$input = json_decode(file_get_contents('php://input'), true);
$subevent_id = $input['subevent_id'] ?? '';
$user_id = $input['user_id'] ?? '';
$full_name = $input['full_name'] ?? '';

if (!$subevent_id || !$user_id) {
    echo json_encode(['success' => false, 'message' => 'Missing parameters']);
    exit;
}

// 1) Check registration in subevent_registrations
$chk = $conn->prepare("SELECT id FROM subevent_registrations WHERE subevent_id = ? AND user_id = ?");
if (!$chk) {
    echo json_encode(['success' => false, 'message' => 'Prepare failed (registration check)']);
    exit;
}
$chk->bind_param("ss", $subevent_id, $user_id);
$chk->execute();
$chk->store_result();
if ($chk->num_rows === 0) {
    echo json_encode(['success' => false, 'message' => 'User is not registered for this subevent']);
    $chk->close();
    $conn->close();
    exit;
}
$chk->close();

// 2) Prevent double attendance
$dup = $conn->prepare("SELECT id FROM subevent_attendance WHERE subevent_id = ? AND user_id = ?");
if (!$dup) {
    echo json_encode(['success' => false, 'message' => 'Prepare failed (duplicate check)']);
    exit;
}
$dup->bind_param("ss", $subevent_id, $user_id);
$dup->execute();
$dup->store_result();
if ($dup->num_rows > 0) {
    echo json_encode(['success' => false, 'message' => 'Attendance already recorded for this user and subevent']);
    $dup->close();
    $conn->close();
    exit;
}
$dup->close();

// 3) Insert attendance
$ins = $conn->prepare("INSERT INTO subevent_attendance (user_id, full_name, subevent_id, attended_at) VALUES (?, ?, ?, NOW())");
if (!$ins) {
    echo json_encode(['success' => false, 'message' => 'Prepare failed (insert)']);
    exit;
}
$ins->bind_param("sss", $user_id, $full_name, $subevent_id);
$ok = $ins->execute();
if ($ok) {
    echo json_encode(['success' => true, 'message' => 'Attendance recorded']);
} else {
    echo json_encode(['success' => false, 'message' => 'Failed to record attendance']);
}
$ins->close();
$conn->close();
?>