# PowerShell script to test push notifications
# Usage: .\test_notification.ps1

# Set your Supabase credentials
$SUPABASE_URL = "https://cuuuncuhqweyiyduzfiz.supabase.co"
$ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN1dXVuY3VocXdleWl5ZHV6Zml6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIzMzA1MDYsImV4cCI6MjA3NzkwNjUwNn0.xDAVoZQ72R7baaa2wdddl7AveH5_B_uTe1I7kY6QFGo"

Write-Host "=== Testing Yield Notification ===" -ForegroundColor Cyan
Write-Host ""

# Test yield notification
$body = @{
    yield_id = 1
    vehicle_id = 1
    yield_amount = 1000
    yield_type = "Amount"
    applied_date = "2024-01-01"
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri "$SUPABASE_URL/functions/v1/send-yield-notification" `
        -Method Post `
        -Headers @{
            "Authorization" = "Bearer $ANON_KEY"
            "Content-Type" = "application/json"
        } `
        -Body $body
    
    Write-Host "Response: $($response | ConvertTo-Json)" -ForegroundColor Green
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host "Response: $($_.Exception.Response)" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Testing Transaction Notification ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Note: Replace USER_UID with your actual user ID from device_tokens table" -ForegroundColor Yellow
Write-Host ""

# Test transaction notification (replace USER_UID with your actual user ID)
$body2 = @{
    transaction_id = 1
    user_uid = "YOUR_USER_ID_HERE"
    status = "verified"
    transaction_type_id = 1
    amount = 500
    vehicle_id = 1
} | ConvertTo-Json

Write-Host "To test transaction notification, uncomment the code below and replace USER_UID" -ForegroundColor Yellow
# try {
#     $response2 = Invoke-RestMethod -Uri "$SUPABASE_URL/functions/v1/send-transaction-notification" `
#         -Method Post `
#         -Headers @{
#             "Authorization" = "Bearer $ANON_KEY"
#             "Content-Type" = "application/json"
#         } `
#         -Body $body2
#     
#     Write-Host "Response: $($response2 | ConvertTo-Json)" -ForegroundColor Green
# } catch {
#     Write-Host "Error: $_" -ForegroundColor Red
# }

