<?php
// filepath: C:\xampp\htdocs\skonnect-api\attendance.php

header('Content-Type: application/json');

// Database connection
$servername = "localhost";
$username = "root";
$password = ""; // default XAMPP password
$dbname = "skonnect"; // your database name

$conn = new mysqli($servername, $username, $password, $dbname);
if ($conn->connect_error) {
    http_response_code(500);
    echo json_encode(["error" => "Database connection failed"]);
    exit();
}

// Get the POSTed JSON data
$data = json_decode(file_get_contents('php://input'), true);

if (!$data) {
    http_response_code(400);
    echo json_encode(["error" => "Invalid JSON"]);
    exit();
}

// Example: expected fields: id, full_name, etc.
// Adjust these fields to match your QR and table structure
$id = isset($data['id']) ? $conn->real_escape_string($data['id']) : '';
$full_name = isset($data['full_name']) ? $conn->real_escape_string($data['full_name']) : '';
$event_id = isset($data['event_id']) ? $conn->real_escape_string($data['event_id']) : '';
$timestamp = date('Y-m-d H:i:s');

// Insert into attendance table (adjust table/column names as needed)
$sql = "INSERT INTO attendance (user_id, full_name, event_id, timestamp) VALUES ('$id', '$full_name', '$event_id', '$timestamp')";

if ($conn->query($sql) === TRUE) {
    echo json_encode(["success" => true]);
} else {
    http_response_code(500);
    echo json_encode(["error" => $conn->error]);
}

$conn->close();
?>