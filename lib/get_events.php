<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST");
header("Access-Control-Allow-Headers: Content-Type");
include 'db.php'; // your DB connection file

if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $res = $conn->query("SELECT * FROM events ORDER BY id DESC");
    $events = [];

    while ($row = $res->fetch_assoc()) {
        $row['image'] = $row['image'] ? 'http://localhost/skonnect-api/uploads/' . $row['image'] : null;
        $events[] = $row;
    }

    echo json_encode($events);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $title = $_POST['title'];
    $desc = $_POST['description'];
    $date = $_POST['date'];
    $time = $_POST['time'];
    $location = $_POST['location'];
    $status = $_POST['status'];

    // Upload image
    $imageName = null;
    if (!empty($_FILES['image']['name'])) {
        $imageName = time() . '_' . basename($_FILES['image']['name']);
        $uploadDir = __DIR__ . '/uploads/';
        move_uploaded_file($_FILES['image']['tmp_name'], $uploadDir . $imageName);
    }

    $stmt = $conn->prepare("INSERT INTO events (title, description, date, time, location, image, status)
                            VALUES (?, ?, ?, ?, ?, ?, ?)");
    $stmt->bind_param("sssssss", $title, $desc, $date, $time, $location, $imageName, $status);
    $stmt->execute();
    $eventId = $stmt->insert_id;

    echo json_encode(['success' => true, 'event_id' => $eventId]);
}